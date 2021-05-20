/* Copyright © 2021, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
SPDX-License-Identifier: Apache-2.0 */

/*********************/
/* Macro Definitions */
/*********************/

/* This file defines several macro functions used in mockup_inmate_data.sas and inmate_pattern_matching.sas */

%macro sampleSentenceLen(colToUse);
   x=rand("Uniform",0,1);
   _i_=1;
   do while(^done);
      set sentenceDistribution point=_i_ end=done;
      if x LT &colToUse then do;
         leave;
      end;
      _i_=_i_+1;
   end;
   sentenceYears = years;
%mend sampleSentenceLen;

%macro addUniqueID(dataSet, idVarname);
   data &dataSet;
      set &dataSet;
      &idVarname = _n_ + (_threadid_ * 1E4);
   run;
%mend addUniqueID;

%macro makeNodesFromLinks(nodeType, linkTableName);
   proc sql;
      create table &nodeType.s as
      select distinct &nodeType.Id
      from &linkTableName;
   quit;
%mend makeNodesFromLinks;

%macro assignRandomNames(
   inData,
   outData,
   firstNamesFile="&LOCAL_DATA_DIR/male_first_names.txt",
   numFirstNames=1000,
   lastNamesFile="&LOCAL_DATA_DIR/last_names.txt",
   numLastNames=1000
);
   data _firstNames_;
      length firstName $12;
      infile &firstNamesFile;
      input firstName;
   run;
   data _lastNames_;
      length lastName $12;
      infile &lastNamesFile;
      input lastName;
   run;
   data &outData;
      call streaminit( &RANDOM_SEED );
      set &inData;
      x=rand("Integer", 1, &numFirstNames);
      set _firstNames_ point=x;
      x=rand("Integer", 1, 1000);
      set _lastNames_ point=x;
      drop x;
   run;
%mend assignRandomNames;

%macro UploadAndSaveData(dataset);
data mycas.&dataset; set &dataset; run;
   proc cas noqueue;
      table.save /
         table="&dataset"
         name="&dataset..sas7bdat"
         replace=true
         ;
      run;
   quit;
%mend UploadAndSaveData;

%macro LoadData(dataset);
   table.loadTable result = r / 
      casout={name="&dataset", replace=true}
      path="&dataset..sas7bdat"
      ;
   run;
%mend LoadData;


%macro checkForDataFiles();
%global FOUND;
proc cas noqueue;
   table.fileInfo result = r /;
   found = 0;
   do fname over r.FileInfo[,'Name'];
      found = found + (fname ='inmates.sas7bdat');
      found = found + (fname ='cells.sas7bdat');
      found = found + (fname ='sections.sas7bdat');
      found = found + (fname ='prisons.sas7bdat');
      found = found + (fname ='regions.sas7bdat');
      found = found + (fname ='inmatecell.sas7bdat');
      found = found + (fname ='cellsection.sas7bdat');
      found = found + (fname ='sectionprison.sas7bdat');
      found = found + (fname ='prisonregion.sas7bdat');
   end;
   print(found = 9);
   symput('FOUND', (found || ''));
quit;
%mend checkForDataFiles;


%macro GetValue(mac=, item=);
   %let prs = %sysfunc(prxparse(m/\b&item=/i));
   %if %sysfunc(prxmatch(&prs, &&&mac)) %then %do;
      %let prs = %sysfunc(prxparse(s/.*\b&item=([^ ]+).*/$1/i));
      %let return_val = %sysfunc(prxchange(&prs, 1, &&&mac));
      &return_val
   %end;
   %else %do;
      %put ERROR: Cannot find &item!;
        .
   %end;
%mend GetValue;


%macro visualizeQuery(fileRoot, queryKey=_NULL_, layout=dot);
   
   data mycas.LinksInQuery;
   %if %QUOTE(&queryKey) = _NULL_ %then %do;
      set mycas.linksQ;
   %end;
   %else %do;
      set mycas.linksQ(where=(queryKey=&queryKey));
   %end;
   run;
   data mycas.NodesInQuery;
   %if %QUOTE(&queryKey) = _NULL_ %then %do;
      set mycas.nodesQ;
   %end;
   %else %do;
      set mycas.nodesQ(where=(queryKey=&queryKey));
   %end;
      length label $40;
      by node;
      nodeLen = length(node);
      if      type EQ 'INMATE'   then color='1';
      else if type EQ 'CELL'     then color='2';
      else if type EQ 'SECTION'  then color='3';
      if      type EQ 'INMATE'
      and not missing(firstName) then label=CATX('\n',firstName,lastName);
      else                           label=node;
   run;
   proc sort out=nodesinQuery data=mycas.NodesinQuery;
      by descending node;
   run;
   
   proc sort out=linksinQuery data=mycas.LinksinQuery;
      by from to;
   run;
   
   data _NULL_;
      file "&_SASPROGRAMFILE/../../dot/&fileRoot..dot";
   %graph2dot(
      nodes=nodesinQuery,
      links=linksinQuery,
      nodesAttrs="colorscheme=paired8, style=filled, color=black, fixedSize=true, width=1.4, height=.8",
      nodeAttrs="fillcolor=color, label=label",
      graphAttrs="layout=&layout",
      directed=1
   );
   run;
%mend visualizeQuery;

%macro visualizeMatches(fileRoot, queryKey=_NULL_, num=&numMatches, layout=dot);
   
   %do selectedMatch=1 %to &num;
   data mycas.LinksInMatch;
   %if %QUOTE(&queryKey) = _NULL_ %then %do;
      set mycas.outMatchLinks(where=(match=&selectedMatch));
   %end;
   %else %do;
      set mycas.outMatchLinks(where=(queryKey=&queryKey and match=&selectedMatch));
   %end;
      length label $40;
      by from to;
      if start EQ . then label = "";
      else do;
         label = CATS(
            "[",
            put(start,DATETIME9.),
            ",",
            put(end,DATETIME9.),
            "]"
         );
      end;
   run;
   data mycas.NodesInMatch;
   %if %QUOTE(&queryKey) = _NULL_ %then %do;
      set mycas.outMatchNodes(where=(match=&selectedMatch));
   %end;
   %else %do;
      set mycas.outMatchNodes(where=(queryKey=&queryKey and match=&selectedMatch));
   %end;
      length label $40;
      by node;
      nodeLen = length(node);
      if      type EQ 'INMATE'  then color='1';
      else if type EQ 'CELL'    then color='2';
      else if type EQ 'SECTION' then color='3';
      if      type EQ 'INMATE'  then label=CATX('\n',firstName,lastName);
      else                           label=substr(node,nodeLen-5);
   run;
   proc sort out=nodesInMatch data=mycas.NodesInMatch;
      by descending nodeQ;
   run;
   
   proc sort out=linksInMatch data=mycas.LinksInMatch;
      by from to;
   run;
   
    %let FILE_N = %EVAL(&selectedMatch);
   data _NULL_;
      file "&_SASPROGRAMFILE/../../dot/&fileRoot._&FILE_N..dot";
   %graph2dot(
      nodes=nodesInMatch,
      links=linksInMatch,
      nodesAttrs="colorscheme=paired8, style=filled, color=black, fixedSize=true, width=1.4, height=.8",
      nodeAttrs="fillcolor=color, label=label",
      linkAttrs="label=label",
      graphAttrs="layout=&layout",
      directed=1
   );
   run;
   %end;
%mend visualizeMatches;


%macro loadGraph();
   %if (%symexist(graphId)) %then %do;
      proc cas;
         network.unloadGraph result=r /
            display={excludeAll=TRUE} graph = &graphId;
      run;
      %symdel graphId;
   %end;
   proc cas;
      network.loadGraph result=r /
         display={excludeAll=TRUE}
         direction = "directed"
         links = {name="links"} 
         linksVar = {vars={"start", "end"}}
         nodes = {name="nodes"}
         nodesVar = {vars={"type", "firstName", "lastName"}};
      run;
      symput('graphId',(string)r.graph);
      print r;
   quit;
   %global graphId;
%mend loadGraph;


%macro FCMPActionLoad(append=false);
   loadactionset "fcmpact";
   setSessOpt{cmplib="casuser.myRoutines"}; run;
   fcmpact.addRoutines /
      appendTable = &append,
      saveTable = true,
      funcTable = {name="myRoutines", caslib="casuser", replace=true},
      package = "myPackage",
      routineCode = myFilter;
   run;
%mend FCMPActionLoad;


%macro joinNodeInfo(outputTable, nodesTable, outputKey, nodesKey, outputVarName, nodesExpr);
   proc fedsql sessref=mySession;
      create table &outputTable {options replace=true} as
      select &NodesExpr as &outputVarName, a.*
      from &outputTable as a
      join &nodesTable as b
      on a.&outputKey = b.&nodesKey
      ;
   quit;
%mend joinNodeInfo;


%macro createInmateLinks();
data mycas.inmatePairs;
   merge mycas.outMatchNodes(where=(nodeQ="inmate1") rename=(node=from))
         mycas.outMatchNodes(where=(nodeQ="inmate2") rename=(node=to))
         mycas.outMatchNodes(where=(nodeQ="cell") rename=(node=cell))
         mycas.outMatchLinks(keep=match start end rename=(start=start_ end=end_));
   by match;
   format start end datetime20.;
   retain start1 end1;
   if first.match then do;
      start1 = start_;
      end1 = end_;
   end;
   else do;
      start2 = start_;
      end2 = end_;
      start = max(start1, start2);
      end = min(end1, end2);
      duration = end-start;
      output;
   end;
   keep from to cell start end duration;
run;
%mend createInmateLinks;


%macro createCliqueLinks();
   proc fedsql sessref=mySession;
      create table inmateCliqueLinks {options replace=true} as
      select a.clique, a.node as "from", b.node as "to", c.cell, c.start, c.end, c.duration
      from inmateCliques as a
      join inmateCliques as b
      on a.clique = b.clique and a.node < b.node
      left join inmatePairs as c
      on a.node = c.from and b.node = c.to;
   quit;
%mend createCliqueLinks;


%macro visualizeCliques(fileRoot, num=&numMatches, layout=dot);
   
   %do selectedMatch=1 %to &num;
   data mycas.LinksInMatch;
      set mycas.inmateCliqueLinks(where=(clique=&selectedMatch));
      length label $50;
      by from to;
      if start EQ . then label = "";
      else do;
         cellLen = length(cell);
         label = CATS(
            "Cell:",
            substr(cell,cellLen-5),
            "[",
            put(start,DATETIME9.),
            ",",
            put(end,DATETIME9.),
            "]"
         );
      end;
   run;
   data mycas.NodesInMatch;
      set mycas.inmateCliques(where=(clique=&selectedMatch));
      by node;
      nodeLen = length(node);
      color='1';
   run;
   proc sort out=nodesInMatch data=mycas.NodesInMatch;
      by descending node;
   run;
   
   proc sort out=linksInMatch data=mycas.LinksInMatch;
      by from to;
   run;
   
    %let FILE_N = %EVAL(&selectedMatch);
   data _NULL_;
      file "&_SASPROGRAMFILE/../../dot/&fileRoot._&FILE_N..dot";
   %graph2dot(
      nodes=nodesInMatch,
      links=linksInMatch,
      nodesAttrs="colorscheme=paired8, style=filled, color=black, fixedSize=true, width=1.4, height=.8",
      nodeAttrs="fillcolor=color, label=name",
      linkAttrs="label=label",
      graphAttrs="layout=&layout",
      directed=0
   );
   run;
   %end;
%mend visualizeCliques;


%macro unloadGraph();
   %global graphId;
   %if (%symexist(graphId)) %then %do;
      proc cas;
         network.unloadGraph result=r /
            display={excludeAll=TRUE} graph = &graphId;
      run;
      %symdel graphId;
   %end;
%mend unloadGraph;


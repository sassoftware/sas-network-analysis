/* Copyright © 2021, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
SPDX-License-Identifier: Apache-2.0 */

/***
   This macro converts a graph specified by nodes and/or links table to
   graphViz format. Invoke graph2dot within a data step as shown in 
   visualization_ex.sas to write the graphViz output to a file.
***/
%macro graph2dot(
   nodes=_NULL_,
   links=_NULL_,
   nodesNode="node",
   linksFrom="from",
   linksTo="to",
   nodeAttrs="",
   linkAttrs="",
   directed=0,
   graphAttrs="",
   nodesAttrs="",
   linksAttrs="",
   nodesColorBy=_UNSUPPORTED_,
   linksColorBy=_UNSUPPORTED_,
   sort=_UNSUPPORTED_
);
   length line $1000 kv lhs rhs nodeId fromId toId $100
          nodeVarType attrVarType $1;
   if &directed then do;
      put "digraph G {";
      linkSep = " -> ";
   end;
   else do;
      put "graph G {";
      linkSep = " -- ";
   end;

   /** Replace graphAttrs commas with semicolons **/
   if find(&graphAttrs,';') EQ 0 
      AND find(&graphAttrs,',') NE 0 then do;
      graphAttrs = translate(&graphAttrs, ';', ',');
   end;
   else do;
      graphAttrs = &graphAttrs;
   end;

   /** Replace graphAttrs single quotes with double quotes **/
   if find(graphAttrs,'"') EQ 0 
      AND find(graphAttrs,"'") NE 0 then do;
      graphAttrs = translate(graphAttrs, '"', "'");
   end;


   /** Write graph attributes **/
   line = graphAttrs;
   put line;
   /** Write global node attributes **/
   if &nodesAttrs NE "" then do;
      line = "node[" || &nodesAttrs. || "]";
      put line;
   end;
   /** Write global link attributes **/
   if &linksAttrs NE "" then do;
      line = "edge[" || &linksAttrs. || "]";
      put line;
   end;

   /** Write nodes and per-node attributes **/
   if "&nodes." NE "_NULL_" then do;
      dsid=open("&nodes.") ;
      nodeVarNum=varnum(dsid, &nodesNode);
      nodeVarType=vartype(dsid, nodeVarNum);
      do while(fetch(dsid)=0);
         if nodeVarType EQ 'N' then nodeId=getvarn(dsid,nodeVarNum);
         else nodeId=getvarc(dsid,nodeVarNum);
         line=quote(strip(nodeId));
      
         nodeAttrs=&nodeAttrs;
         if nodeAttrs NE "" then do;
            /* Per-node attributes */
            line = CATS(line,"[");
            nAttr=countw(nodeAttrs,',');
            do i=1 to nAttr;
               kv=scan(nodeAttrs, i, ',');
               lhs = scan(kv, 1, '=');
               rhs = scan(kv, 2, '=');
               attrVarNum=varnum(dsid, rhs);
               attrVarType=vartype(dsid, attrVarNum);
               if attrVarType EQ 'N' then rhs=getvarn(dsid,attrVarNum);
               else rhs=getvarc(dsid,attrVarNum);
               line = CATS(line,lhs,' = "',rhs,'"');
               if i LT nAttr then line = CATS(line,",");
            end;
            line = CATS(line,"]");
         end;

         put line;
      end;

      dsid=close(dsid);
   end;

   /** Write links and per-link attributes **/ 
   if "&links." NE "_NULL_" then do;
      dsid=open("&links.") ;
      fromVarNum=varnum(dsid, &linksFrom);
      toVarNum=varnum(dsid, &linksTo);
      nodeVarType=vartype(dsid, fromVarNum);
      do while(fetch(dsid)=0);
         if nodeVarType EQ 'N' then do;
            fromId=getvarn(dsid,fromVarNum);
            toId=getvarn(dsid,toVarNum);
         end;
         else do;
            fromId=getvarc(dsid,fromVarNum);
            toId=getvarc(dsid,toVarNum);
         end;
         line=quote(strip(fromId)) || linkSep || quote(strip(toId));

         linkAttrs=&linkAttrs;
         if linkAttrs NE "" then do;
            /* Per-link attributes */
            line = CATS(line,"[");
            nAttr=countw(linkAttrs,',');
            do i=1 to nAttr;
               kv=scan(linkAttrs, i, ',');
               lhs = scan(kv, 1, '=');
               rhs = scan(kv, 2, '=');
               attrVarNum=varnum(dsid, rhs);
               attrVarType=vartype(dsid, attrVarNum);
               if attrVarType EQ 'N' then rhs=getvarn(dsid,attrVarNum);
               else rhs=getvarc(dsid,attrVarNum);
               line = CATS(line,lhs,' = "',rhs,'"');
               if i LT nAttr then line = CATS(line,",");
            end;
            line = CATS(line,"]");
         end;

         put line;
      end;
      dsid=close(dsid);
   end;

   put "}";

%mend;


%macro highlightSubgraph(
   fname,
   nodes,
   links,
   nodesSubset,
   linksSubset,
   nodesSubsetWhere,
   linksSubsetWhere,
   nodesNode="node",
   linksFrom="from",
   linksTo="to",
   nodeAttrs="",
   linkAttrs="",
   nodesAttrs="",
   linksAttrs="",
   induced=0,
   graphAttrs="",
   directed=0);
%let highlightColor = 'blue';
%let defaultColor = 'black';
%let highlightThickness = 3;
%let defaultThickness = 1;


data mycas._NodesHighlightSubgraph_;
   length color $5;
   merge &nodes &nodesSubset(in=inSubset where=(&nodesSubsetWhere));
   by node;
   if inSubset then do;
      highlighted=1;
      color = &highlightColor;
      thickness = &highlightThickness;
   end;
   else do;
      highlighted=0;
      color = &defaultColor;
      thickness = &defaultThickness;
   end;
run;

%if &induced %then %do;
   data mycas._LinksHighlightSubgraph_;
      length color $5;
      set &links;
      if _n_ = 1 then do;
         declare hash h0(dataset:'_NodesHighlightSubgraph_');
            h0.defineKey('node');
            h0.defineData('highlighted');
            h0.defineDone();
      end;

      /* length highlighted; */
      highlighted = 0;
      node = from;
      rc0 = h0.find();
      includeMe = highlighted;

      highlighted = 0;
      node = to;
      rc0 = h0.find();
      includeMe = includeMe*highlighted;

      if includeMe then do;
         highlighted = 1;
         color = &highlightColor;
         thickness = &highlightThickness;
      end;
      else do;
         color = &defaultColor;
         thickness = &defaultThickness;
      end;

      drop highlighted node rc0 includeMe;
   run;
%end;
%else %do;
   data mycas._LinksHighlightSubgraph_;
      length color $5;
      
      length color $5;
      merge &links &linksSubset(in=inSubset where=(&linksSubsetWhere));
      by from to;
      if inSubset then do;
         highlighted=1;
         color = &highlightColor;
         thickness = &highlightThickness;
      end;
      else do;
         highlighted=0;
         color = &defaultColor;
         thickness = &defaultThickness;
      end;
   run;
%end;
proc sort out=_NodesHighlightSubgraph_ data=mycas._NodesHighlightSubgraph_;
   by node;
run;

proc sort out=_LinksHighlightSubgraph_ data=mycas._LinksHighlightSubgraph_;
   by from to;
run;

data _NULL_;
   file "&_SASPROGRAMFILE/../../dot/&fname..dot";
%graph2dot(
   nodes=_NodesHighlightSubgraph_,
   links=_LinksHighlightSubgraph_,
   %if &nodesAttrs="" %then %do;
   nodesAttrs="colorscheme=paired8, color=black",
   %end;
   %else %do;
   nodesAttrs="colorscheme=paired8, color=black, %sysfunc(dequote(&nodesAttrs))",
   %end;
   linksAttrs=&linksAttrs,
   %if &nodeAttrs="" %then %do;
   nodeAttrs="color=color, penwidth=thickness",
   %end;
   %else %do;
   nodeAttrs="color=color, penwidth=thickness, %sysfunc(dequote(&nodeAttrs))",
   %end;
   %if &linkAttrs="" %then %do;
   linkAttrs="color=color, penwidth=thickness",
   %end;
   %else %do;
   linkAttrs="color=color, penwidth=thickness, %sysfunc(dequote(&linkAttrs))",
   %end;
   graphAttrs=&graphAttrs,
   directed=&directed
);
run;
%mend;

%macro highlightInducedSubgraph(
   fname,
   links,
   nodes,
   nodesSubset,
   nodesSubsetWhere,
   nodesNode="node",
   linksFrom="from",
   linksTo="to",
   nodeAttrs="",
   linkAttrs="",
   nodesAttrs="",
   linksAttrs="",
   graphAttrs="",
   directed=0);
   %highlightSubgraph(
      &fname,
      &links,
      &nodes,
      &nodesSubset,
      _NULL_,
      &nodesSubsetWhere,
      _NULL,
      nodesNode=&nodesNode,
      linksFrom=&linksFrom,
      linksTo=&linksTo,
      nodeAttrs=&nodeAttrs,
      linkAttrs=&linkAttrs,
      nodesAttrs=&nodesAttrs,
      linksAttrs=&linksAttrs,
      induced=1,
      graphAttrs=&graphAttrs,
      directed=&directed
   );


%mend;
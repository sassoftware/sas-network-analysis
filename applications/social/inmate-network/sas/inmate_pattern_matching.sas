/* Copyright © 2021, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
SPDX-License-Identifier: Apache-2.0 */

%let _COMMON_REPO_ROOT=&_SASPROGRAMFILE/../../../../../common;
%INCLUDE "&_COMMON_REPO_ROOT/sas/cas_connection.sas";
%INCLUDE "&_COMMON_REPO_ROOT/sas/visualization.sas";
%INCLUDE "&_SASPROGRAMFILE/../helper_macros.sas";


/******************/
/* CAS Connection */
/******************/

%reconnect();


/*************/
/* Load Data */
/*************/
%checkForDataFiles();

/* If all nine required mockup data files exist, load them. Otherwise, run the mockup script. */

%if "&FOUND"="9" %then %do;
proc cas noqueue;
   %LoadData(inmates);
   %LoadData(cells);
   %LoadData(sections);
   %LoadData(prisons);
   %LoadData(regions);
   %LoadData(inmateSentences);
   %LoadData(inmateCell);
   %LoadData(cellSection);
   %LoadData(sectionPrison);
   %LoadData(prisonRegion);
quit;
%end;
%else %do;
   %INCLUDE "&_SASPROGRAMFILE/../mockup_inmate_data.sas";
%end;

/*************************/
/* Define and Load Graph */
/*************************/

/* Define the Nodes Table */
data mycas.nodes;
   length node $12 type $12;
   format node $12.;
   set mycas.inmates(rename=(inmateId=node)) indsname=dsn
       mycas.cells(rename=(cellId=node)) indsname=dsn
       mycas.sections(rename=(sectionId=node)) indsname=dsn
       mycas.prisons(rename=(prisonId=node)) indsname=dsn
       mycas.regions(rename=(regionId=node)) indsname=dsn;
   type = scan(dsn, 2, ".");
   type = substr(type, 1, length(type)-1);
   keep node type firstName lastName numSentences;
run;

/* Define the Links Table */
data mycas.links;
   length from $12 to $12;
   format from $12. to $12.;
   set mycas.inmateCell(rename=(inmateId=from cellId=to))
       mycas.cellSection(rename=(cellId=from sectionId=to))
       mycas.sectionPrison(rename=(sectionId=from prisonId=to))
       mycas.prisonRegion(rename=(prisonId=from regionId=to))
   ;
   keep from to sentenceId start end;
run;

/* Load an in-memory copy of this directed graph */
%loadGraph();


/************************/
/* PatternMatch Queries */
/************************/

/** Example 1**/
/* Find inmates that shared a cell with fictional mob boss Jett Mccormick */


/* Define the Nodes Query Table */
/* This table includes the nodes for desired pattern: two inmates, and once cell */
/* One of the inmates will be specified as Jett Mccormick */
data mycas.nodesQ;
   infile datalines dsd;
   length node $12 type $12 firstName $12 lastName $12;
   input node $ type $ firstName $ lastName $;
   datalines;
mobBoss, INMATE, Jett, Mccormick
inmate2, INMATE, , 
cell, CELL, , 
;
/* Define the Links Query Table */
/* This table includes the links for desired pattern: both inmates were assigned to the cell */
data mycas.linksQ;
   infile datalines dsd;
   length from $12 to $12;
   input from $ to $;
   datalines;
mobBoss, cell
inmate2, cell
;

/* Define FCMP Functions */
proc cas;
   source myFilter;
      function hasOverlap(start[*], end[*]);
         /* Time range overlap detection function */
         /* This function will be reused in the link pair filter of each example */
         intervalTotal = MAX(end[1],end[2]) - MIN(start[1],start[2]);
         interval1 = end[1]-start[1];
         interval2 = end[2]-start[2];
         return (interval1 + interval2 GT intervalTotal);
      endsub;
      function myLinkPairFilter1(start[*], end[*]);
         /* Filter to keep only matches with some time overlap between cell occupancy */
         return (hasOverlap(start, end));
      endsub;
   endsource;
   %FCMPActionLoad(append=false);
quit;

proc network
   graph            = &graphId
   nodesQuery       = mycas.nodesQ
   linksQuery       = mycas.linksQ;
   nodesQueryVar
      vars          = (type firstName lastName);
   patternMatch
      LinkPairFilter = myLinkPairFilter1(l.start, l.end)
      outMatchNodes = mycas.OutMatchNodes
      outMatchLinks = mycas.OutMatchLinks
      maxMatches    = 100;
run;
%let numMatches = %GetValue(mac=_network_,item=num_matches);

%joinNodeInfo(outMatchLinks, inmates, from, inmateId, name, (firstName || ' ' || lastName));

title "Inmates Sharing a cell with Jett Mccormick";
proc print data=mycas.outMatchLinks noobs label;
   by match to;
   label from="inmateId" to="cellId";
run;
title;


/*****************************************/
/* Query and Matches Found Visualization */
/*****************************************/


%visualizeQuery(query_1);
%visualizeMatches(query_1_match);


/** Example 2: **/
/* Find inmates in the same section as Jett Mccormick */

/* Define the Nodes Query Table */
/* This table includes the nodes for two desired patterns:*/
/* A: two inmates, sharing both cell and section */
/* B: two inmates, in different cells, but same section */
/* One of the inmates will be specified as Jett Mccormick */
data mycas.nodesQ;
   infile datalines dsd;
   length querykey $2 node $12 type $12 firstName $12 lastName $12;
   input querykey $ node $ type $ firstName $ lastName $;
   datalines;
A, mobBoss, INMATE, Jett, Mccormick
A, inmate2, INMATE, , 
A, cell, CELL, , 
A, section, SECTION, ,
B, mobBoss, INMATE, Jett, Mccormick
B, inmate2, INMATE, , 
B, cell1, CELL, , 
B, cell2, CELL, ,
B, section, SECTION, ,
;
/* Define the Links Query Table */
/* This table includes the links for two desired patterns: */
/* A: two inmates, sharing both cell and section */
/* B: two inmates, in different cells, but same section */
data mycas.linksQ;
   infile datalines dsd;
   length querykey $2 from $12 to $12;
   input querykey $ from $ to $;
   datalines;
A, mobBoss, cell
A, inmate2, cell
A, cell, section
B, mobBoss, cell1
B, inmate2, cell2
B, cell1, section
B, cell2, section
;

/** Define FCMP Functions **/
proc cas;
   source myFilter;
      function myLinkPairFilter2(start[*], end[*]);
         /* Filter to keep only matches with some time overlap between cell occupancy */
         /* Add if statement logic to ignore section-cell links, which have no time stamps */
         if(start[1] NE . AND start[2] NE .) then
            return (hasOverlap(start, end));
         return (1);
      endsub;
   endsource;
   %FCMPActionLoad(append=true);
quit;

proc network
   graph            = &graphId
   nodesQuery       = mycas.nodesQ
   linksQuery       = mycas.linksQ;
   nodesQueryVar
      vars          = (type firstName lastName);
   patternMatch
      LinkPairFilter= myLinkPairFilter2(l.start, l.end)
      outMatchNodes = mycas.OutMatchNodes
      outMatchLinks = mycas.OutMatchLinks
      queryKey      = querykey
      maxMatches    = 1000;
run;

proc sort data=mycas.outMatchNodes out=outMatchNodes; by queryKey match type nodeQ;
title "Inmates in same Section at same time as Jett Mccormick";
proc print 
   data=outMatchNodes(where=
      (
         (type="INMATE" OR nodeQ="section")
         AND (match LE 3)
      ));
   by querykey match;
run;
title;


%visualizeQuery(query_2A, queryKey="A");
%visualizeQuery(query_2B, queryKey="B");

%let numMatches = 3;
%visualizeMatches(query_2A_match, queryKey="A");
%visualizeMatches(query_2B_match, queryKey="B");

/** Example 3: **/
/* Find "cliques" of cell-sharing inmates */

/* In this example, we are interested in triples of inmates who */
/* each shared a cell with the others at some point. */
/* The query graph construction is complex, since this could happen in */
/* one of four different topologies, described below. */

/* See example 4 for a cleaner approach to solve the same problem using the clique algorithm. */

/* Define the Nodes Query Table */
/* This table includes the nodes for four desired patterns:*/
/* 0: three inmates, each pair sharing one of three different cells */
/* 1: three inmates, each pair sharing one of two different cells */
/* 2: three inmates, each pair sharing the same cell at different times, two inmates have multiple stays */
/* 3: three inmates, each pair sharing the same cell at different times, one inmate has multiple stays */
/* the variable 'ordering' is inserted to break symmetry and reject isomorphic permutations of the same solution. */
data mycas.nodesQ;
   infile datalines dsd;
   length querykey $2 node $12 type $12;
   input querykey $ node $ type $ ordering;
   datalines;
0, inmate1, INMATE,1
0, inmate2, INMATE,2
0, inmate3, INMATE,3
0, cellA, CELL,.
0, cellB, CELL,.
0, cellC, CELL,.
1, inmate1, INMATE,1
1, inmate2, INMATE,2
1, inmate3, INMATE,.
1, cellA, CELL,.
1, cellB, CELL,.
2, inmate1, INMATE,1
2, inmate2, INMATE,2
2, inmate3, INMATE,.
2, cellA, CELL,.
3, inmate1, INMATE,1
3, inmate2, INMATE,2
3, inmate3, INMATE,.
3, cellA, CELL,.
;

/* Define the Links Query Table */
/* This table includes the links for four desired patterns:*/
/* 0: three inmates, each pair sharing one of three different cells */
/* 1: three inmates, each pair sharing one of two different cells */
/* 2: three inmates, each pair sharing the same cell at different times, two inmates have multiple stays */
/* 3: three inmates, each pair sharing the same cell at different times, one inmate has multiple stays */
/* the variable 'constrain' is inserted to indicate link pairs for which overlap should be enforced. */
/* overlap will be enforced for two links only if the bitwise representation has at least one common high bit. */
data mycas.linksQ;
   infile datalines dsd;
   length querykey $2 from $12 to $12;
   input querykey $ from $ to $ constrain;
   datalines;
0, inmate1, cellA,1
0, inmate2, cellA,1
0, inmate2, cellB,2
0, inmate3, cellB,2
0, inmate3, cellC,4
0, inmate1, cellC,4
1, inmate1, cellA,1
1, inmate2, cellA,2
1, inmate3, cellA,3
1, inmate1, cellB,4
1, inmate2, cellB,4
2, inmate1, cellA,1
2, inmate2, cellA,1
2, inmate2, cellA,2
2, inmate3, cellA,2
2, inmate3, cellA,3
3, inmate1, cellA,5
3, inmate2, cellA,6
3, inmate3, cellA,1
3, inmate3, cellA,2
;

/** Define FCMP Functions **/
proc cas;
   source myFilter;
      function myLinkPairFilter3(from[*] $, start[*], end[*], constrain[*]);
         /* Filter to keep only matches with some time overlap between cell occupancy */
         /* Add if statement logic to enforce only the necessary inmate-cell link pairs */
         if(BAND(constrain[1], constrain[2]) GT 0 AND from[1] LT from[2]) then
            return (hasOverlap(start, end));
         return (1);
      endsub;
      function myNodePairFilter3(node[*] $, ordering[*]);
         /* Filter to keep only one match for each set of isomorphic permutations */
         if(ordering[1] EQ . OR ordering[2] EQ .) then return (1);
         if(ordering[1] LT ordering[2]) then
            return (node[1] LT node[2]);
         return (1);
      endsub;
   endsource;
   %FCMPActionLoad(append=true);
quit;

proc network
   graph            = &graphId
   nodesQuery       = mycas.nodesQ
   linksQuery       = mycas.linksQ;
   nodesQueryVar
      vars          = (type ordering)
      varsMatch     = (type);
   linksQueryVar
      vars          = (constrain)
      varsMatch     = ();
   patternMatch
      LinkPairFilter= myLinkPairFilter3(l.from, l.start, l.end, lQ.constrain)
      nodePairFilter= myNodePairFilter3(n.node, nQ.ordering)
      outMatchNodes = mycas.OutMatchNodes
      outMatchLinks = mycas.OutMatchLinks
      queryKey      = querykey
      maxMatches    = 1000;
run;

title "Cliques of Inmates: Method 1";
proc print data=mycas.outMatchLinks(obs=50); by querykey match; run;
proc print data=mycas.outMatchNodes(obs=50); by querykey match; run;
title;

%visualizeQuery(query_3_0, queryKey="0");
%visualizeQuery(query_3_1, queryKey="1");
%visualizeQuery(query_3_2, queryKey="2");
%visualizeQuery(query_3_3, queryKey="3");
%visualizeMatches(query_3_0_match, queryKey="0", num=1, layout=sfdp);
%visualizeMatches(query_3_1_match, queryKey="1", num=3, layout=sfdp);
%visualizeMatches(query_3_3_match, queryKey="3", num=3, layout=sfdp);


/** Example 4: **/
/* Find "cliques" using patternMatch (preprocess) + clique */
/* An alternative approach to arrive at the answer of Example 3 */

/* Define the Nodes Query Table */
/* This table includes the nodes for the desired pattern:*/
/* Two inmates sharing the same cell */
data mycas.nodesQ;
   infile datalines dsd;
   length node $12 type $12;
   input node $ type $ ordering;
   datalines;
inmate1, INMATE,1
inmate2, INMATE,2
cell, CELL,.
;
/* Define the Links Query Table */
/* This table includes the links for the desired pattern:*/
/* Two inmates sharing the same cell */
data mycas.linksQ;
   infile datalines dsd;
   length from $12 to $12;
   input from $ to $;
   datalines;
inmate1, cell
inmate2, cell
;

/** Define FCMP Functions **/
proc cas;
   source myFilter;
      function myLinkPairFilter4(start[*], end[*]);
         /* Filter to keep only matches with some time overlap between cell occupancy */
         return (hasOverlap(start, end));
      endsub;
      function myNodePairFilter4(node[*] $, ordering[*]);
         /* Filter to keep only one match for each set of isomorphic permutations */
         if(ordering[1] EQ . OR ordering[2] EQ .) then return (1);
         if(ordering[1] LT ordering[2]) then
            return (node[1] LT node[2]);
         return (1);
      endsub;
   endsource;
   %FCMPActionLoad(append=true);
quit;

proc network
   graph            = &graphId
   nodesQuery       = mycas.nodesQ
   linksQuery       = mycas.linksQ;
   nodesQueryVar
      vars          = (type ordering)
      varsMatch     = (type);
   patternMatch
      LinkPairFilter= myLinkPairFilter4(l.start, l.end)
      nodePairFilter= myNodePairFilter4(n.node, nQ.ordering)
      outMatchNodes = mycas.outMatchNodes
      outMatchLinks = mycas.outMatchLinks
      maxMatches    = 100000;
run;

%createInmateLinks();

proc network
   links            = mycas.inmatePairs;
   clique
      out           = mycas.inmateCliques
      minSize       = 3
      maxSize       = 3
      maxCliques    = ALL;
      ;
run;


%createCliqueLinks();

%joinNodeInfo(inmateCliques, inmates, node, inmateId, name, (TRIM(firstName) || '\n' || TRIM(lastName)));

%visualizeQuery(query_4);
%visualizeCliques(query_4_match, num=7, layout=sfdp);

proc sort data=mycas.inmateCliques out=inmateCliques; by clique node; run;
title "Cliques of Inmates: Method 2";
proc print data=inmateCliques(obs=50);
   by clique;
   label node="InmateId";
run;
title;

proc cas;
   %unloadGraph();
quit;



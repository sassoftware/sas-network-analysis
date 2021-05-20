/* Copyright © 2021, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
SPDX-License-Identifier: Apache-2.0 */

%let _COMMON_REPO_ROOT=&_SASPROGRAMFILE/../../../../common;
%INCLUDE "&_COMMON_REPO_ROOT/sas/cas_connection.sas";
%INCLUDE "&_COMMON_REPO_ROOT/sas/visualization.sas";

%reconnect();

/************************************************/
/* Ex 1: Maximal Cliques of an Undirected Graph */
/************************************************/

/*
This section illustrates the use of the clique algorithm on the undirected graph G.

The undirected graph G can be represented by the following links data table, mycas.LinkSetIn:
*/

data mycas.LinkSetIn;
   input from $ to $ @@;
   datalines;
0 1  0 2  0 3  0 4  0 5
0 6  1 2  1 3  1 4  2 3
2 4  2 5  2 6  2 7  2 8
3 4  5 6  7 8  8 9
;

/*
The following statements calculate the maximal cliques, output the results in the data table mycas.Cliques, and use the FEDSQL procedure as a convenient way to create a data table (mycas.CliqueSizes) of clique sizes:
*/

proc network
   links         = mycas.LinkSetIn
   outNodes      = mycas.NodeSetIn;
   clique
      out        = mycas.Cliques
      maxCliques = all;
run;

proc fedsql sessref=mySession;
   create table CliqueSizes as
   select clique, count(*) as size
   from Cliques
   group by clique;
quit;

data _NULL_;
   file "&_SASPROGRAMFILE/../../dot/algo_ex1_0.dot";
%graph2dot(
   graphAttrs="layout=sfdp, overlap=prism, overlap_scaling=-5",
   links=mycas.LinkSetIn
);
run;

%let nodes=mycas.NodeSetIn;
%let links=mycas.LinkSetIn;
%let nodesSub=mycas.Cliques;

%macro highlightSubgraphs(num);
%do selected=1 %to &num;
%highlightInducedSubgraph(
   algo_ex1_&selected,
   &nodes,
   &links,
   &nodesSub,
   clique EQ &selected,
   graphAttrs="layout=sfdp, overlap=prism, overlap_scaling=-5"
);
%end;
%mend;

%highlightSubgraphs(4);

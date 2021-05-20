/* Copyright © 2021, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
SPDX-License-Identifier: Apache-2.0 */

%let _COMMON_REPO_ROOT=&_SASPROGRAMFILE/../../../../common;
%INCLUDE "&_COMMON_REPO_ROOT/sas/cas_connection.sas";
%INCLUDE "&_COMMON_REPO_ROOT/sas/visualization.sas";

%reconnect();

/***************************************************/
/* Ex 1: Path Enumeration for One Source-Sink Pair */
/***************************************************/

/*
This section illustrates the use of the clique algorithm on the undirected graph G.

The directed graph G can be represented by the following links data table, mycas.LinkSetIn:
*/

data mycas.LinkSetIn;
   input from $ to $ weight @@;
   datalines;
A B 1  A E 1  B C 1  C A 6  C D 1
D E 3  D F 1  E B 1  E C 4  F E 1
E A 1
;

/*
The following statements find all paths between node D and node A whose path link weight is less than or equal to 10:
*/

proc network
   direction         = directed
   links             = mycas.LinkSetIn
   outNodes          = mycas.NodeSetIn;
   path
      source         = D
      sink           = A
      maxLinkWeight  = 10
      outPathsLinks  = mycas.PathLinks
      outPathsNodes  = mycas.PathNodes;
run;


proc sort out=NodeSetIn data=mycas.NodeSetIn;
   by node;
run;

proc sort out=LinkSetIn data=mycas.LinkSetIn;
   by from to;
run;

data _NULL_;
   file "&_SASPROGRAMFILE/../../dot/algo_ex1_0.dot";
%graph2dot(
   linkAttrs="label=weight",
   graphAttrs="layout=dot, overlap=prism, overlap_scaling=-5",
   directed=1,
   nodes=NodeSetIn,
   links=LinkSetIn
);
run;

%let nodes=mycas.NodeSetIn;
%let links=mycas.LinkSetIn;
%let nodesSub=mycas.PathNodes;
%let linksSub=mycas.PathLinks;

%macro highlightSubgraphs(num);
%do selected=1 %to &num;
%highlightSubgraph(
   algo_ex1_&selected,
   &nodes,
   &links,
   &nodesSub,
   &linksSub,
   path EQ &selected,
   path EQ &selected,
   linkAttrs="label=weight",
   graphAttrs="layout=dot",
   directed=1);
%end;
%mend;

%highlightSubgraphs(3);

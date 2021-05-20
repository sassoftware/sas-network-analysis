/* Copyright © 2021, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
SPDX-License-Identifier: Apache-2.0 */

%let _COMMON_REPO_ROOT=&_SASPROGRAMFILE/../../../../common;
%INCLUDE "&_COMMON_REPO_ROOT/sas/cas_connection.sas";
%INCLUDE "&_COMMON_REPO_ROOT/sas/visualization.sas";

%reconnect();

/****************************************************/
/* Ex 1: Community Detection on an Undirected Graph */
/****************************************************/

/*
This section illustrates the use of the community detection algorithm on the undirected graph G.

The undirected graph G can be represented by the following links data table, mycas.LinkSetIn:
*/

data mycas.LinkSetIn;
   input from $ to $ @@;
   datalines;
A B  A F  A G  B C  B D
B E  C D  E F  G I  G H
H I
;

/*
The following statements perform community detection and output the results in the specified data tables. The Louvain algorithm is used by default because no value is specified for the ALGORITHM= option.
*/

proc network
   links              = mycas.LinkSetIn
   outNodes           = mycas.NodeSetOut;
   community
      resolutionList  = 1.0 0.5
      outLevel        = mycas.CommLevelOut
      outCommunity    = mycas.CommOut
      outOverlap      = mycas.CommOverlapOut
      outCommLinks    = mycas.CommLinksOut;
run;


data _NULL_;
   file "&_SASPROGRAMFILE/../../dot/algo_ex1_0.dot";
%graph2dot(
   graphAttrs="layout=sfdp, overlap=prism, overlap_scaling=-5",
   links=mycas.LinkSetIn
);
run;


data _NULL_;
   file "&_SASPROGRAMFILE/../../dot/algo_ex1_1.dot";
%graph2dot(
   nodesAttrs="colorscheme=accent4, style=filled",
   nodeAttrs="color=community_1",
   graphAttrs="layout=sfdp, overlap=prism, overlap_scaling=-5",
   nodes=mycas.NodeSetOut,
   links=mycas.LinkSetIn
);
run;


data _NULL_;
   file "/r/ge.unx.sas.com/vol/vol110/u11/brrees/code/sas-network-analysis/algorithms/community/dot/algo_ex1_2.dot";
%graph2dot(
   nodesAttrs="colorscheme=accent4, style=filled",
   nodeAttrs="color=community_2",
   graphAttrs="layout=sfdp, overlap=prism, overlap_scaling=-5",
   directed=0,
   nodes=mycas.NodeSetOut,
   links=mycas.LinkSetIn
);
run;



/**********************************************/
/* Ex 2: Fixing Nodes for Community Detection */
/**********************************************/

/*
This section continues the example in the section Community Detection on an Undirected Graph and illustrates fixing nodes together for community detection on the graph shown in Figure 65. Suppose you want to fix nodes A and B in the same community, nodes C and D in the same community, and nodes H and I in the same community. In order to do this, you must specify a nodes data table that has a variable that defines these fixed groups. The following DATA step creates the nodes data table:
*/

data mycas.NodeSetIn;
   input node $ fixGroup @@;
   datalines;
A 1  B 1
C 2  D 2
H 3  I 3
;

/*
The following statements perform community detection by using fixed node groups:
*/

proc network
   nodes             = mycas.NodeSetIn
   links             = mycas.LinkSetIn
   outNodes          = mycas.NodeSetOut;
   community
      resolutionList = 1.0
      fix            = fixGroup;
run;


data _NULL_;
   file "/r/ge.unx.sas.com/vol/vol110/u11/brrees/code/sas-network-analysis/algorithms/community/dot/algo_ex2_0.dot";
%graph2dot(
   nodesAttrs="colorscheme=accent4, style=filled",
   nodeAttrs="color=community_1",
   graphAttrs="layout=sfdp, overlap=prism, overlap_scaling=-5",
   directed=0,
   nodes=mycas.NodeSetOut,
   links=mycas.LinkSetIn
);
run;


/* Copyright © 2021, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
SPDX-License-Identifier: Apache-2.0 */

%let _COMMON_REPO_ROOT=&_SASPROGRAMFILE/../../../../common;
%INCLUDE "&_COMMON_REPO_ROOT/sas/cas_connection.sas";
%INCLUDE "&_COMMON_REPO_ROOT/sas/visualization.sas";

%reconnect();

/*************************************************************/
/* Ex 1: Network Projection on an Undirected Bipartite Graph */
/*************************************************************/

/*
This section illustrates the use of the network projection algorithm on the bipartite graph G.

The bipartite graph G can be represented by the following links data table, mycas.LinkSetIn:
*/

data mycas.LinkSetIn;
   input from $ to $ @@;
   datalines;
A 1  A 2  A 3
B 1  B 2  B 4  B 5
C 2  C 3  C 4  C 5
D 3  D 5
E 4  E 5  E 6
;

/*
In order to identify the partition of each node, you must also specify a nodes data table, mycas.NodeSetIn, which you can create by using the following DATA step:
*/
data mycas.NodeSetIn;
   input node $ partitionFlag @@;
   datalines;
A 1  B 1  C 1  D 1  E 1
1 0  2 0  3 0  4 0  5 0  6 0
;

/*
The following statements find the projection of the network onto nodes A through E, which have a partition flag equal to 1.
*/

proc network
   links                 = mycas.LinkSetIn
   nodes                 = mycas.NodeSetIn;
   projection
      partition          = partitionFlag
      outProjectionLinks = mycas.ProjLinkSetOut
      commonNeighbors    = true;
run;


data _NULL_;
   file "&_SASPROGRAMFILE/../../dot/algo_ex1_0.dot";
%graph2dot(
   graphAttrs="layout=dot, overlap=prism, overlap_scaling=-5",
   links=mycas.LinkSetIn
);
run;


data _NULL_;
   file "&_SASPROGRAMFILE/../../dot/algo_ex1_1.dot";
%graph2dot(
   nodesAttrs="shape=circle,fixedsize=true,width=.6",
   linkAttrs="label=commonNeighbors",
   graphAttrs="layout=circo, start=6",
   links=mycas.ProjLinkSetOut
);
run;



/**********************************************************/
/* Ex 2: Network Projection of a Directed Bipartite Graph */
/**********************************************************/

/*
This section provides additional examples to illustrate the three ways to define projection on a graph with directed links. The following DATA step creates the nodes data table:
*/

data mycas.NodeSetIn;
   input node $ partitionFlag @@;
   datalines;
0 0  1 0  A 1  B 1  C 1  D 1
;

/* The following DATA step creates the links data table: */
data mycas.LinkSetIn;
   input from $ to $ @@;
   datalines;
1 B  1 C  A 0  A 1  D 0
;

/*
The following statements find the projection of the network onto nodes A through D via their out-neighbors:
*/

proc network
   direction             = directed
   links                 = mycas.LinkSetIn
   nodes                 = mycas.NodeSetIn;
   projection
      directedMethod     = converging
      partition          = partitionFlag
      outProjectionLinks = mycas.ProjLinkSetOut1
      commonNeighbors    = true;
run;

/*
The following statements find the projection of the network onto nodes A through D via their in-neighbors:
*/

proc network
   direction             = directed
   links                 = mycas.LinkSetIn
   nodes                 = mycas.NodeSetIn;
   projection
      directedMethod     = diverging
      partition          = partitionFlag
      outProjectionLinks = mycas.ProjLinkSetOut2
      commonNeighbors    = true;
run;

/*
The following statements find the projection of the network onto nodes A through D via directed paths of length 2:
*/

proc network
   direction             = directed
   links                 = mycas.LinkSetIn
   nodes                 = mycas.NodeSetIn;
   projection
      directedMethod     = transitive
      partition          = partitionFlag
      outProjectionLinks = mycas.ProjLinkSetOut3
      commonNeighbors    = true;
run;



data _NULL_;
   file "&_SASPROGRAMFILE/../../dot/algo_ex2_0.dot";
%graph2dot(
   graphAttrs="layout=dot, overlap=prism, overlap_scaling=-5",
   links=mycas.LinkSetIn,
   directed=1
);
run;


data _NULL_;
   file "&_SASPROGRAMFILE/../../dot/algo_ex2_1.dot";
%graph2dot(
   nodesAttrs="shape=circle,fixedsize=true,width=.6",
   linkAttrs="label=commonNeighbors",
   graphAttrs="layout=neato, start=6",
   links=mycas.ProjLinkSetOut1
);
run;


data _NULL_;
   file "&_SASPROGRAMFILE/../../dot/algo_ex2_2.dot";
%graph2dot(
   nodesAttrs="shape=circle,fixedsize=true,width=.6",
   linkAttrs="label=commonNeighbors",
   graphAttrs="layout=neato, start=6",
   links=mycas.ProjLinkSetOut2
);
run;


data _NULL_;
   file "&_SASPROGRAMFILE/../../dot/algo_ex2_3.dot";
%graph2dot(
   nodesAttrs="shape=circle,fixedsize=true,width=.6",
   linkAttrs="label=commonNeighbors",
   graphAttrs="layout=neato, start=6",
   links=mycas.ProjLinkSetOut3,
   directed=1
);
run;


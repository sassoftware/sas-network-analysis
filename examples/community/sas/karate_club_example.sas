/* Copyright © 2021, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
SPDX-License-Identifier: Apache-2.0 */

%let _COMMON_REPO_ROOT=&_SASPROGRAMFILE/../../../../common;
%INCLUDE "&_COMMON_REPO_ROOT/sas/cas_connection.sas";
%INCLUDE "&_COMMON_REPO_ROOT/sas/visualization.sas";

%reconnect();
/*
This example uses Zachary’s Karate Club data (Zachary 1977), which describes social network friendships between 34 members of a karate club at a US university in the 1970s. This is one of the standard publicly available data tables for testing community detection algorithms. It contains 34 nodes and 78 links. The graph is shown in karate_club_0.png.
*/

data mycas.LinkSetIn;
   input from to @@;
   datalines;
 0  9   0 10   0 14   0 15   0 16   0 19   0 20   0 21
 0 23   0 24   0 27   0 28   0 29   0 30   0 31   0 32
 0 33   2  1   3  1   3  2   4  1   4  2   4  3   5  1
 6  1   7  1   7  5   7  6   8  1   8  2   8  3   8  4
 9  1   9  3  10  3  11  1  11  5  11  6  12  1  13  1
13  4  14  1  14  2  14  3  14  4  17  6  17  7  18  1
18  2  20  1  20  2  22  1  22  2  26 24  26 25  28  3
28 24  28 25  29  3  30 24  30 27  31  2  31  9  32  1
32 25  32 26  32 29  33  3  33  9  33 15  33 16  33 19
33 21  33 23  33 24  33 30  33 31  33 32
;

proc network
   links             = mycas.LinkSetIn
   outNodes          = mycas.NodeSetOut;
   community
      resolutionList = 1.0 0.5
      outLevel       = mycas.CommLevelOut
      outCommunity   = mycas.CommOut
      outOverlap     = mycas.CommOverlapOut
      outCommLinks   = mycas.CommLinksOut;
run;

data _NULL_;
   file "&_SASPROGRAMFILE/../../dot/karate_club_0.dot";
%graph2dot(
   graphAttrs="layout=sfdp; overlap=prism; overlap_scaling=-5",
   directed=0,
   nodes=mycas.NodeSetOut,
   links=mycas.LinkSetIn
);
run;


data _NULL_;
   file "&_SASPROGRAMFILE/../../dot/karate_club_1.dot";
%graph2dot(
   nodesAttrs="colorscheme=accent4, style=filled",
   nodeAttrs="color=community_1",
   graphAttrs="layout=sfdp; overlap=prism; overlap_scaling=-5",
   directed=0,
   nodes=mycas.NodeSetOut,
   links=mycas.LinkSetIn
);
run;


data _NULL_;
   file "&_SASPROGRAMFILE/../../dot/karate_club_2.dot";
%graph2dot(
   nodesAttrs="colorscheme=accent4, style=filled",
   nodeAttrs="color=community_2",
   graphAttrs="layout=sfdp; overlap=prism; overlap_scaling=-5",
   directed=0,
   nodes=mycas.NodeSetOut,
   links=mycas.LinkSetIn
);
run;


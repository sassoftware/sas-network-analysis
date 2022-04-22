/* Copyright © 2021, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
SPDX-License-Identifier: Apache-2.0 */

%let _COMMON_REPO_ROOT=&_SASPROGRAMFILE/../../../../common;
%INCLUDE "&_COMMON_REPO_ROOT/sas/cas_connection.sas";
%INCLUDE "&_COMMON_REPO_ROOT/sas/visualization.sas";

%reconnect(caslib=myData, datasubdir=data/snap/amazon/);
/*
This notebook demonstrates how to compute the network projection of the Amazon
Movies and TV reviews data set, which you can download from 
https://nijianmo.github.io/amazon/index.html#subsets.

Be warned: this is a large input graph and it is recommended to run this
example on a multiple machine computing cluster.
*/


/*** Define the Input Graph ***/
/* In the following links data, we load the links in the bipartite network from a csv file. */
proc cas;
   table.loadTable /
      caslib="myData"
      path="Movies_and_TV.csv",
      casout={name="links", replace=true}
      importOptions={
         fileType="CSV",
         getNames=false,
         vars={
            {name="from", type="CHAR", length=16},
            {name="to", type="CHAR", length=16},
            {name="rating", type="DOUBLE"},
            {name="timestamp", type="DOUBLE"}
         }
      }
   ;
/*** Create the Nodes Table ***/
/*
 In this example, the pairs of products that were reviewed by the same
 user are of interest. The PROJECTION statement requires a nodes data
 table with a column that indicates which nodes are users and which
 nodes are products. You can use the following statements to generate
 the nodes data table (which has an identifier variable called node
 and a partition variable called partitionFlag).

 Since we want to infer links between pairs of products, we need to
 assign a partition value of 1 for product nodes and 0 for user nodes.
*/
   fedSql.execDirect /
      query='
         create table nodesUser {options replace=True}  as
         select distinct a.from as "node", 0 as "partitionFlag"
         from links as a;
      '
   ;
   fedSql.execDirect /
      query='
         create table nodesProduct {options replace=True}  as
         select distinct a.to as "node", 1 as "partitionFlag"
         from links as a;
      '
   ;
   datastep.runCode /
      code='
         data nodes;
               set nodesUser nodesProduct;
         run;
      '
   ;

/*** Run the Projection Algorithm ***/
   network.projection /
      links              = {name= "links"},
      nodes              = {name= "nodes"},
      outProjectionLinks = {name= "links_out",
                           replace=True,
                           where="commonNeighbors >= 5"},
      partition          = "partitionFlag",
      commonNeighbors    = true,
      nThreads           = 4
    ;
quit;

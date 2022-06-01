/* Copyright © 2021, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
SPDX-License-Identifier: Apache-2.0 */

/********************************/
/* Unsupervised identification */
/* of disease and drug compound */
/* similarity                   */
/********************************/

/***
   This demo is based on the dataset available from
   https://github.com/hetio/hetionet
***/


/***
   Hetionet is a knowledge graph that encodes known information
   in biology and medicine.
   
   The data model consists of various node and link types.
   
   The goal of this demo is to predict disease resemblance
   and compound resemblance using an unsupervised approach.
   
   All the "resembles" links between Disease node pairs and
   Compound node pairs in the data set are considered
   unknown for the sake of this demo. The task is to
   predict these links based on the other information in 
   the network.
   
   This task is considered unsupervised, because none of
   the links to be predicted are made available to the
   model during training.

   This type of unsupervised analysis could be useful in a
   drug repurposing study: one could identify plausible
   candidates for a clinical trial based on the following:
   - which compounds are most similar to a compound X that
     is known to be an effective treatment of disease Y?
   - which compounds are known to be effective in treating
     the diseases that are most similar to disease Y?
***/

%let _COMMON_REPO_ROOT=&_SASPROGRAMFILE/../../../../../common;
%INCLUDE "&_COMMON_REPO_ROOT/sas/cas_connection.sas";
%INCLUDE "&_COMMON_REPO_ROOT/sas/visualization.sas";

/******************/
/* CAS Connection */
/******************/
%put "&CAS_SERVER_HOST";
%reconnect();

/******************/
/* Parameters     */
/******************/
/* Select Analysis Type */
%let keepType=Disease; /* Compound | Disease */

/*********************/
/* Macro Definitions */
/*********************/
%macro project(nodes, links, fromNodeType, toNodeType, linkType, outNodes, outLinks, appendLinks=);
/*
   This macro performs a projection that infers links between two nodes based on the common 
   neighborhoods of those nodes.

   Assumption: Links of the &linkType type express a bipartite subgraph of the graph represented by
   the &nodes and &links tables.

   Parameters:
   nodes - the name of the nodes table. Assumes the "type" column identifies the node type
   links - the name of the links table. Assumes the "type" column identifies the link type
   fromNodeType - the node type of the primary partition. Output will be inferred links between pairs of nodes of this type
   toNodeType - the node type of the secondary partition. Output inferred links will be based on common neighbors of this type
   linkType - the link type to utilize. Output will be based only upon input graph links of this type
   outNodes - the output table that gives the list of nodes (they will all be of &fromNodeType)
   outLinks - the output table that gives the inferred links. Link strength can be quantified using the 
              adamicAdar, cosine, jaccard, and commonNeighbors similarity scores
*/

   proc cas;
      network.projection /
         links       = {name="&links", where="type EQ &linkType"}
         nodes       = {name="&nodes"
            computedVars = {"partitionFlag"} /* Specifies the node roles in projection */
            computedVarsProgram=
               "if type = '&fromNodeType'
               then partitionFlag = 1;
               else if type = '&toNodeType' 
               then partitionFlag = 0;
               else partitionFlag = .;"
         }
         nodesVar    = {vars={"name", "type"}}
         partition = "partitionFlag"
         outProjectionLinks = {name="outLinks_", replace=true}
         outProjectionNodes = {name="&outNodes", replace=true}
         /* Output weighting column options */
         adamicAdar = true
         cosine = true
         jaccard = true
         commonNeighbors = true
      ;
   quit;

   /* Copy/Append inferred links to &outLinks */
   data mycas.&outLinks;
      set &appendLinks mycas.outLinks_(in=newLink);
      length type VARCHAR(34);
      if newLink then do;
         type = "SAME " || "&linkType";
      end;
   run;
%mend;

/***************************************/
/* Read in the Knowledge Graph         */
/***************************************/
/* point a caslib to the data directory */
proc cas;
   table.addcaslib result = r / activeOnAdd=false caslib="hetionet" datasource={srctype="path"} path="&CAS_SERVER_DATADIR"; run;
quit;
/* read the two delimited files */
proc cas;
   table.loadTable /
      caslib="hetionet"
      path="hetionet-v1.0-nodes.tsv"
      casout={name="nodes", replace=true}
      importOptions={ fileType="CSV", delimiter="\t",
         vars={
            {name="node", type="CHAR", length=48},
            {name="name", type="CHAR", length=64},
            {name="type", type="CHAR", length=24}
         }
      }
   ;
   table.loadTable /
      caslib="hetionet"
      path="hetionet-v1.0-edges.sif"
      casout={name="links", replace=true}
      importOptions={ fileType="CSV", delimiter="\t",
         vars={
            {name="from", type="CHAR", length=48},
            {name="type", type="CHAR", length=24},
            {name="to", type="CHAR", length=48}
         }
      }
   ;
quit;

/***************************************/
/* Inspect Data Model                  */
/***************************************/
proc fedsql sessref=mySession;
   select type, count(*)
   from nodes
   group by type
   ;
quit;
proc fedsql sessref=mySession;
   select type, count(*)
   from links
   group by type
   ;
quit;
  
/***************************************/
/* Hide Ground Truth                   */
/***************************************/
data mycas.linksTrain;
   set mycas.links;
   if type ne "DrD" and type ne "CrC";
run;
/* Verify that there are no 'resembles' links */
proc fedsql sessref=mySession;
   select type, count(*)
   from linksTrain
   group by type
   ;
quit;
            
/***************************************/
/* Projections                         */
/***************************************/

%if "&keepType"="Disease" %then %do;
%let resemblesLinkType=DrD;
%let FETCH_CUTOFF_WEIGHT = 0.0;
%project(nodes, linksTrain, &keepType, Compound, 'CtD', projNodes, projLinks, appendLinks=);
%project(nodes, linksTrain, &keepType, Compound, 'CpD', projNodes, projLinks, appendLinks=mycas.projLinks);
%project(nodes, linksTrain, &keepType, Gene, 'DdG', projNodes, projLinks, appendLinks=mycas.projLinks);
%project(nodes, linksTrain, &keepType, Gene, 'DuG', projNodes, projLinks, appendLinks=mycas.projLinks);
%project(nodes, linksTrain, &keepType, Gene, 'DaG', projNodes, projLinks, appendLinks=mycas.projLinks);
%project(nodes, linksTrain, &keepType, Anatomy, 'DlA', projNodes, projLinks, appendLinks=mycas.projLinks);
%project(nodes, linksTrain, &keepType, Symptom, 'DpS', projNodes, projLinks, appendLinks=mycas.projLinks);
%end;
%if "&keepType"="Compound" %then %do;
%let resemblesLinkType=CrC;
%let FETCH_CUTOFF_WEIGHT = 0.1;
%project(nodes, linksTrain, &keepType, Disease, 'CtD', projNodes, projLinks, appendLinks=);
%project(nodes, linksTrain, &keepType, Disease, 'CpD', projNodes, projLinks, appendLinks=mycas.projLinks);
%project(nodes, linksTrain, &keepType, Gene, 'CdG', projNodes, projLinks, appendLinks=mycas.projLinks);
%project(nodes, linksTrain, &keepType, Gene, 'CuG', projNodes, projLinks, appendLinks=mycas.projLinks);
%project(nodes, linksTrain, &keepType, Gene, 'CbG', projNodes, projLinks, appendLinks=mycas.projLinks);
%project(nodes, linksTrain, &keepType, Pharmacologic Class, 'PCiC', projNodes, projLinks, appendLinks=mycas.projLinks);
%project(nodes, linksTrain, &keepType, Side Effect, 'CcSE', projNodes, projLinks, appendLinks=mycas.projLinks);
%end;

/***************************/
/* Join Nodes Data         */
/***************************/
proc fedsql sessref=mySession;
   create table projLinksJoined {options replace=true} as
   select a.from, a.to, b.name as "fromName", c.name as "toName", a.adamicAdar, a.type, a.jaccard, a.cosine, a.commonNeighbors
   from projLinks a
   join nodes b
   on a.from = b.node
   join nodes c
   on a.to = c.node
   ;
quit;

proc fedsql sessref=mySession;
   create table projLinksGrouped {options replace=true} as
   select MIN(a.from) as "from",
          MIN(a.to) as "to",
          fromName, toName,
          SUM(adamicAdar) as "adamicAdarSum",
          SUM(jaccard) as "jaccardSum",
          SUM(cosine) as "cosineSum",
          sum(commonNeighbors) as "commonNeighborsSum",
          POWER(SUM(adamicAdar)*SUM(jaccard)*SUM(cosine)*sum(commonNeighbors),0.25) as "weight"
   from projLinksJoined as a
   group by fromName, toName
   ;
quit;

/***************************************/
/* Scale weights from 0 to 1           */
/***************************************/
proc cas;
   aggregation.aggregate result=r /
      table={
         name="projLinksGrouped"
      },
      varSpecs={
         {name="weight", summarySubset={"MAX", "MIN"}}
      }
   ;
   shift = 0;
   scale = (1.0-shift)/(r['AggStatistics.Var1'][1]['Max']-r['AggStatistics.Var1'][1]['Min']);
   
   datapreprocess.transform /
      copyAllVars=True
      table={name="projLinksGrouped"}
      casout={name="projLinksScaled", replace=true}
      requestPackages={{
         inputs={"weight"}
         function={
            method="SCALESHIFT"
            arguments={
               otherArguments={scale,shift}
               shiftPositive=0
            }
         }
      }}
   ;
quit;

data mycas.projLinksScaled;
   set mycas.projLinksScaled(drop=weight);
run;


/***************************************/
/* Evaluation                          */
/***************************************/
/* Gather the ground truth links */
data mycas.linksRes;
   set mycas.links(where=(type="&resemblesLinkType"));
   if to < from then do;
      temp=to;
      to=from;
      from=temp;
   end;
   drop temp;
run;

/* Use a right join to mark which inferred links from
   projLinksScaled are also ground truth links.
*/
proc fedsql sessref=mySession;
   create table linksResJoinedR {options replace=true} as
   select a.*, b._TR1_weight as "weight", c.name as "fromName", d.name as "toName"
   from linksRes a
   right join projLinksScaled b
   on a.from = b.from and a.to = b.to
   left join nodes c
   on b.from = c.node
   left join nodes d
   on b.to = d.node
   where b._TR1_weight > &FETCH_CUTOFF_WEIGHT /* Subset to manage table size */
   ;
quit;

/* Mark the correctly identified links as "hits" */
data linkPrediction;
   set mycas.linksResJoinedR;
   if type ne "" then hit=1;
   else hit=0;
run;

/* Sort by descending weight (prediction strength) */
proc sort data=linkPrediction;
   by descending weight;
run;

%macro hits(n);
   data linkPrediction&n;
      set linkPrediction(obs=&n);
   run;
   proc sql;
      select SUM(hit) as hitsAt&n into :hits&n
      from linkPrediction&n;
   quit;
%mend;

/* Display number of hits in the top 10, 100, and 1000 */
%hits(10);
%hits(100);
%hits(1000);

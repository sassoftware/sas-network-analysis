/* Copyright © 2021, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
SPDX-License-Identifier: Apache-2.0 */

%let _COMMON_REPO_ROOT=&_SASPROGRAMFILE/../../../../common;
%INCLUDE "&_COMMON_REPO_ROOT/sas/cas_connection.sas";
%INCLUDE "&_COMMON_REPO_ROOT/sas/visualization.sas";

%reconnect();
/*
This example solves a recommendation problem that links similar ingredients 
together based on recipe data. By using the PROJECTION statement, you can
find pairs of ingredients that occur together in one or more recipes. In the
data table mycas.LinkSetRecipesIn, the inclusion of ingredients in recipes
is organized into a bipartite network G.
*/


data mycas.LinkSetRecipesIn;
   infile datalines dsd flowover;
   length Recipe $20. Ingredient1-Ingredient13 $20.;
   input Recipe $ Ingredient1-Ingredient13 $;
   array ingredient Ingredient1 -- Ingredient13;
   from = Recipe;
   do over ingredient;
      if missing(ingredient) then leave;
      to = Ingredient;
      output;
   end;
   keep from to;
   datalines;
Spag Sauce,      Tomato,Garlic,Salt,Onion,TomatoPaste,OliveOil
                 Oregano,Parsley, , , , ,
Spag Meat Sauce, Tomato,Garlic,Salt,Onion,TomatoPaste,OliveOil
                 Celery,GreenPepper,BayLeaf,GroundBeef,Carrot
                 PorkSausage,RedPepper
Eggplant Relish, Garlic,Salt,Onion,TomatoPaste,OliveOil,Eggplant
                 GreenOlives,Capers,Sugar, , , ,
Creole Sauce,    Tomato,Salt,Onion,TomatoPaste,OliveOil,Celery
                 Broth,GreenPepper,BlackPepper,Paprika,Thyme
                 WorcestershireSauce,
Salsa,           Tomato,Garlic,Salt,Onion,Cilantro,Tomatillo
                 JalapenoPepper,Lime, , , , ,
Enchilada Sauce, Tomato,Broth,Cumin,Flour,BrownSugar,ChiliPowder
                 CayennePepper,Oil, , , , ,
;

/*
In this example, the numbers of common neighbors (recipe nodes) between
ingredient node pairs are of interest. The PROJECTION statement requires
a nodes data table with a column that indicates which nodes are recipes
and which nodes are ingredients. You can use the following statements to
generate the nodes data table mycas.NodeSetRecipesIn (which has a single
variable called node):
*/

proc network
   links    = mycas.LinkSetRecipesIn
   outNodes = mycas.NodeSetRecipesIn;
run;

/*
Since we want to infer links between pairs of ingredients, we need
to assign a partition value of 1 for ingredient nodes and 0 for
recipe nodes.

Define a script to determine partition value, 0 or 1, at run time.:
*/
filename pscript '/tmp/_partitionscript_';
data _null_;
    file pscript;
    put "if(node in (
            'Spag Sauce'
            'Spag Meat Sauce'
            'Eggplant Relish'
            'Creole Sauce'
            'Salsa'
            'Enchilada Sauce'
            )) then partition = 0;
         else partition = 1;";
run;

/* Run the projection algorithm */
proc network
   nodes = mycas.NodeSetRecipesIn(script=pscript tempnames=(partition))
   links = mycas.LinkSetRecipesIn;
   projection
      partition          = partition
      commonNeighbors    = true
      outProjectionLinks = mycas.ProjectionLinkSetOut
      outNeighborsList   = mycas.ProjectionListOut;
run;

/* Print the results */
/* Show projected links with at least 3 neighbors in common */
proc sort 
   data=mycas.ProjectionLinkSetOut (where=(commonNeighbors GE 3))
   out = projectedLinks;
   by descending commonNeighbors from to;
run;
proc print data=projectedLinks
   (where=(commonNeighbors GE 3))
   noobs;
run;

/* Show recipes that contain both Garlic and OliveOil */
proc print data=mycas.ProjectionListOut
   (where=(from = 'Garlic' and to = 'OliveOil'))
   noobs;
run;
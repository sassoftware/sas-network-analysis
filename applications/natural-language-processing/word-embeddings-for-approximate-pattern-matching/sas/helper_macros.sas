/* Copyright © 2021, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
SPDX-License-Identifier: Apache-2.0 */


/** Macro Definitions **/

/* Generate expressions for fcmp variable lists */
/*
varsCommaN      = n.vec_1,nQ.vec_1,n.vec_2,nQ.vec_2,...
varsDotProductN = n.vec_1*nQ.vec_1+n.vec_2*nQ.vec_2+...
*/
data _null_;
   length varsCommaN varsDotProductN VARCHAR(32767);
   varsCommaN      = '';
   varsDotProductN = '';
   do i = 1 to &nDim;
     varsCommaN     = catx(',',varsCommaN,     cats('n.vec_', i,',nQ.vec_',i));
     varsDotProductN= catx('+',varsDotProductN,cats('n.vec_', i,'*nQ.vec_',i));
   end;
   call symput('varsCommaN',      trim(varsCommaN));
   call symput('varsDotProductN', trim(varsDotProductN));
run;

/* FCMPActionLoad() is used to register the user-defined FCMP functions in CAS */
%macro FCMPActionLoad(append=false);
   loadactionset "fcmpact";
   setSessOpt{cmplib="casuser.myRoutines"}; run;
   fcmpact.addRoutines /
      appendTable = &append,
      saveTable = true,
      funcTable = {name="myRoutines", caslib="casuser", replace=true},
      package = "myPackage",
      routineCode = myFilters;
   run;
%mend FCMPActionLoad;


/* GetValue() is used to grab the value of a field in _NETWORK_ result macro variable */
%macro GetValue(mac=, item=);
   %let prs = %sysfunc(prxparse(m/\b&item=/i));
   %if %sysfunc(prxmatch(&prs, &&&mac)) %then %do;
      %let prs = %sysfunc(prxparse(s/.*\b&item=([^ ]+).*/$1/i));
      %let return_val = %sysfunc(prxchange(&prs, 1, &&&mac));
      &return_val
   %end;
   %else %do;
      %put ERROR: Cannot find &item!;
        .
   %end;
%mend GetValue;


/* visualizeMatches() produces a graphViz visualization of the whole graph */
/* for each match, highlighting the nodes and links within that match */
%macro visualizeMatches();
%let highlightColor='blue';
%let highlightThickness=3;

%do selectedMatch=1 %to &numMatches;
data mycas.LinksPurchaseHighlighted;
   merge mycas.LinksPurchase
         mycas.outMatchLinks(in=inMatch where=(match=&selectedMatch));
   by from to;
   if inMatch then do;
      color=&highlightColor;
      thickness=&highlightThickness;
   end;
run;
data mycas.NodesPurchaseHighlighted;
   merge mycas.NodesPurchase
         mycas.outMatchNodes(in=inMatch where=(match=&selectedMatch));
   by node;
   if inMatch then do;
      pencolor=&highlightColor;
      thickness=&highlightThickness;
   end;
run;
proc sort out=nodesPurchaseHighlighted data=mycas.NodesPurchaseHighlighted;
   by descending node;
run;

proc sort out=linksPurchaseHighlighted data=mycas.LinksPurchaseHighlighted;
   by from to;
run;

 %let FILE_N = %EVAL(1 + &selectedMatch);
data _NULL_;
   file "&_SASPROGRAMFILE/../../dot/approximate_patternmatch_&FILE_N..dot";
%graph2dot(
   nodes=nodesPurchaseHighlighted,
   links=linksPurchaseHighlighted,
   nodesAttrs="colorscheme=paired8, style=filled, color=black",
   nodeAttrs="fillcolor=color, label=label, color=pencolor, penwidth=thickness",
   linkAttrs="color=color, penwidth=thickness",
   graphAttrs="layout=sfdp, overlap=prism, overlap_scaling=-3",
   directed=1
);
run;
%end;
%mend visualizeMatches;

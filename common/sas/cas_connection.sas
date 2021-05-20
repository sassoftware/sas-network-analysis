/* Copyright © 2021, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
SPDX-License-Identifier: Apache-2.0 */

/*************************************/
/* Parse Environment Properties File */
/*************************************/
data _NULL_;
   length line $120;
   infile "&_COMMON_REPO_ROOT/conf/environment.txt";
   input line $;
   call symput(scan(line, 1, '=', 't'), scan(line, 2, '=', 't'));
run;

%put CAS_SERVER_HOST="&CAS_SERVER_HOST";
%put CAS_SERVER_PORT="&CAS_SERVER_PORT";

/******************/
/* CAS Connection */
/******************/
%macro reconnect(host=&CAS_SERVER_HOST, port=&CAS_SERVER_PORT, sessionName=mySession, timeout=1800);
   %terminateAll();
   
   /** Connect to the Cas Server **/
   options cashost="&host" casport=&port;
   cas &sessionName sessopts=(caslib=casuser timeout=&timeout locale="en_US");
   libname mycas cas sessref=&sessionName caslib="CASUSER";
%mend;

%macro terminateAll();
   cas _ALL_ terminate ;
   %if (%symexist(graphId)) %then %do;
      %symdel graphId;
   %end;
%mend;

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
%put CAS_SERVER_DATADIR="&CAS_SERVER_DATADIR";

/******************/
/* CAS Connection */
/******************/
%macro reconnect(host=&CAS_SERVER_HOST, port=&CAS_SERVER_PORT, datadir=&CAS_SERVER_DATADIR, datasubdir=, caslib=CASUSER, sessionName=mySession, timeout=1800);
   %terminateAll();
   
   /** Connect to the Cas Server **/
   options cashost="&host" casport=&port;
   cas &sessionName sessopts=(caslib=casuser timeout=&timeout locale="en_US");
   %if "&CASLIB"="CASUSER" %then %do;
      libname mycas cas sessref=&sessionName caslib="CASUSER";
   %end;
   %else %do;
      %let path=&CAS_SERVER_DATADIR&datasubdir;
      proc cas;
         addcaslib  /
            activeOnAdd=true caslib="&CASLIB"
            datasource={srctype="path"}
            path="&path";
         run;
      quit;
      libname mycas cas sessref=&sessionName caslib="&CASLIB";
   %end;
%mend;

%macro terminateAll();
   cas _ALL_ terminate ;
   %if (%symexist(graphId)) %then %do;
      %symdel graphId;
   %end;
%mend;

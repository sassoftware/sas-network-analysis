/* Copyright © 2021, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
SPDX-License-Identifier: Apache-2.0 */

/****************************/
/* Fraud Rings in Bank Data */
/****************************/

/***
   This demo is based on the blog post "Finding Fraud Part Two Revised"
   by Max De Marzi:
   https://maxdemarzi.com/2020/03/20/finding-fraud-part-two-revised/amp/
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
%let RANDOM_SEED = 999;     /* The initial random number generator seed */ 
%let DEMO_SIZE   = 1000000; /* The number of users to create */
%let MAX_DOLLARS = 10000;   /* Randomize account balances on [0,MAX_DOLLARS] */

/***
   Reciprocal collision frequency for SSN, phone number, and address
   Lower value means demographic item is more frequently shared accross users
***/
%let RECIPR_COLL_FREQ_SSN   = 500; /* Roughly 0.1% will be duplicate SSN */
%let RECIPR_COLL_FREQ_PHONE = 50;  /* Roughly 1% will be duplicate phone numbers */
%let RECIPR_COLL_FREQ_ADDR  = 5;   /* Roughly 10% will be duplicate addresses */

/*********************/
/* Macro Definitions */
/*********************/
/*** This macro splits up DATA step work among multiple threads ***/
%macro assignRowsToThread(n=&DEMO_SIZE);
   start = floor((_threadId_-1)/_nThreads_*&n) + 1;
   end = floor(_threadId_/_nThreads_*&n);
%mend;

/***
   This macro produces a graphviz visualization file for a given connected
   component
***/
%macro displayCc(cc, num);
%put "Doing display for connected component &num: &cc";
data mycas.nodesComp;
   set mycas.nodesOut(where=(concomp EQ &cc));
run;

data mycas.nodesHead;
   merge mycas.nodesComp(IN=inComp rename=(node=id))
         mycas.nodes;
   by id;
   if inComp;
run;


data mycas.linksHead;
   merge mycas.nodesComp(IN=inFrom rename=(node=from))
         mycas.links(IN=inLinks);
   by from;
   if inFrom and inLinks;
run;

%let graphAttrs="layout=sfdp, overlap=prism, overlap_scaling=-5, labelloc='t', label='Connected Component &cc.', fontsize=30";

data _NULL_;
   file "&_SASPROGRAMFILE/../../dot/fraud_ring_demo_&num..dot";
%graph2dot(
   nodes=mycas.nodesHead,
   links=mycas.linksHead,
   nodesNode="id",
   nodesAttrs="colorscheme=accent8, style=filled, color=black",
   nodeAttrs="fillcolor=color, label=label",
   graphAttrs=&graphAttrs,
   directed=1
);
run;
%mend;

/***************************************/
/* Read Lists of Names from text files */
/***************************************/
/*** There are 1000 female names in the text file ***/
data femaleNames;
   infile "&_SASPROGRAMFILE/../../data/female_first_names.txt";
   length firstName $12 gender $8;
   input firstName $;
   gender='female';
run;

proc print data=femaleNames(obs=10); run;

/*** And 1000 male names ***/
data maleNames;
   infile "&_SASPROGRAMFILE/../../data/male_first_names.txt";
   length firstName $12 gender $8;
   input firstName $;
   gender='male';
run;

proc print data=maleNames(obs=10); run;

/*** To be combined with 1000 last names ***/
data lastNames;
   infile "&_SASPROGRAMFILE/../../data/last_names.txt";
   length lastName $12;
   input lastName $;
run;

proc print data=lastNames(obs=10); run;

data firstNames;
   set femaleNames maleNames;
run;


/******************/
/* Create Users   */
/******************/
/***
   First, generate the users. You can do this by creating IDs in the 
   range 1-1M. Then, we arbitrarily assign a first and last name to
   each user. 
***/
data users;
   %assignRowsToThread();
   length type $16;
   type="User";
   do id=start to end;
      output;
   end;
   keep type id;
run;
data users;
   call streaminit( &RANDOM_SEED );
   set users;
   x=rand("Integer", 1, 2000);
   set firstNames point=x;
   x=rand("Integer", 1, 1000);
   set lastNames point=x;
   drop x;
run;
proc print data=users(obs=10); run;


/**************************************************/
/* Create Checking/Savings/Loan/Credit Accounts   */
/**************************************************/
/***
   Now, generate the banking accounts. The four types created here
   are Checking, Savings, Unsecured Loan, and Credit Card. 
***/
data accounts;
   call streaminit( &RANDOM_SEED+1 );
   %assignRowsToThread();
   length type $16;
   type="Checking";
   do number=start to end;
      id = number + &DEMO_SIZE;
      balance = rand("Integer", 1, &MAX_DOLLARS*100) / 100.0;
      output;
   end;
   type="Savings";
   do number=start to end;
      id = number + &DEMO_SIZE*2;
      balance = rand("Integer", 1, &MAX_DOLLARS*100) / 100.0;
      output;
   end;
   do i=start to end;
      if i LE &DEMO_SIZE/2 then do;
         number = i;
         type="Unsecured Loan";
      end;
      else do;
         number = 4111111111111111 + i;
         type="Credit Card";
      end;
      id = i + &DEMO_SIZE*3;
      balance = rand("Integer", 1, &MAX_DOLLARS*100) / 100.0;
      output;
   end;
   keep id type number balance;
run;
proc print data=accounts(obs=10 where=(type="Credit Card")); run;



/*******************************/
/* Create USER/ACCOUNT Links   */
/*******************************/
/***
   Next, you can link users to accounts using the handy unique serial ID that
   is given to each user and account. 
***/
proc sql;
   create table userAccounts as
   select a.id as from, b.id as to, "HAS_ACCOUNT" as type
   from users as a
   join accounts as b
   on a.id = MOD(b.id-1,&DEMO_SIZE)+1;
   ;
quit;
proc print data=userAccounts(obs=10); run;



/***********************************/
/* Create Identification Numbers   */
/***********************************/
/***
   Now, using randomization, we assingn every user an "almost" unique SSN. 
***/
data identification;
   call streaminit( &RANDOM_SEED+2 );
   %assignRowsToThread();
   length type $16;
   type="SSN";
   do i=start to end;
      number = rand("Integer", 1,
         &DEMO_SIZE*&RECIPR_COLL_FREQ_SSN)
         + &DEMO_SIZE*100;
      id = i + &DEMO_SIZE*4;
      output;
   end;
run;
proc print data=identification(obs=10); run;
proc sql;
   select count (distinct number) from identification;
quit;

/**************************************/
/* Create USER/IDENTIFICATION Links   */
/**************************************/
/***
   Next, you can link users to SSN identification nodes. 
   Using group by here, we can achieve the desired amount of id duplication.
***/
proc sql;
   create table userIdentification as
   select a.id as from, MIN(b.id) as to, "HAS_ID" as type, b.number
   from users as a
   join identification as b
   on a.id = MOD(b.id-1,&DEMO_SIZE)+1
   group by number;
   ;
quit;
data userIdentification;
   set userIdentification(drop=number);
run;
proc print data=userIdentification(obs=10); run;


/**************************/
/* Create Phone Numbers   */
/**************************/
/***
   Treat phone numbers the same way as SSN, only with more frequent
   duplication.
***/
data phone;
   call streaminit( &RANDOM_SEED+3 );
   %assignRowsToThread();
   length type $16;
   type="Phone";
   do i=start to end;
      number = rand("Integer", 1,
         &DEMO_SIZE*&RECIPR_COLL_FREQ_PHONE)+5550000000;
      id = i + &DEMO_SIZE*5;
      output;
   end;
run;
proc print data=phone(obs=10); run;
proc sql;
   select count (distinct number) from phone;
quit;

/*****************************/
/* Create USER/PHONE Links   */
/*****************************/
proc sql;
   create table userPhone as
   select a.id as from, MIN(b.id) as to, "HAS_PHONE" as type, b.number
   from users as a
   join phone as b
   on a.id = MOD(b.id-1,&DEMO_SIZE)+1
   group by number;
   ;
quit;
data userPhone;
   set userPhone(drop=number);
run;
proc print data=userPhone(obs=10); run;



/**************************/
/* Create Addresses       */
/**************************/
/***
   Likewise for mailing addresses.
   Here, you can also use data step arrays to randomize some street names.
***/
data address;
   call streaminit( &RANDOM_SEED+4 );
   array cities{18} $20 _TEMPORARY_
      ("Chicago", "Aurora","Rockford","Joliet",
      "Naperville","Springfield", "Peoria", "Elgin", 
      "Waukegan", "Champaign", "Bloomington", "Decatur", 
      "Evanston", "Wheaton", "Belleville", "Urbana", 
      "Quincy", "Rock Island");
   array directions{26} $10 _TEMPORARY_
      ("North ", "South ", "East ", "West ", "SouthWest ", 
       "SouthEast ", "NorthWest ", "NorthEast ",
       "","","","","","","","",""
       "","","","","","","","","");
   array streets1{15} $10 _TEMPORARY_
      ("Main", "Park", "Oak", "Pine", "Maple", "Cedar", "Elm", 
      "Washington", "Lake", "Hill", "First", "Second", 
      "Third", "Fourth", "Fifth");
   array streets2{19} $10 _TEMPORARY_
      ("Drive", "Lane","Avenue", "Way", "Circle", "Square", 
      "Court", "Road", "Alley", "Fork","Grove", "Heights", 
      "Landing", "Path", "Route", "Trail", "Cove", "Loop",
      "Bend");
   %assignRowsToThread();
   length type $16 line1 line2 $40;
   type="Address";
   do i=start to end;
      number = rand("Integer", 1,
         &DEMO_SIZE*&RECIPR_COLL_FREQ_ADDR);
      street1 = streets1[MOD(number-1, dim(streets1))+1];
      street2 = streets2[MOD(number-1, dim(streets2))+1];
      dir = directions[MOD(number-1, dim(directions))+1];
      line1 = CATX(' ',(MOD(number-1,99999)+1),dir,street1,street2);
      city = cities[MOD(number-1, dim(cities))+1];
      state = "IL";
      zip = 60400 + MOD(number, dim(cities));
      line2 = CATX(' ',CATS(city,','), state, zip);
      id = i + &DEMO_SIZE*6;
      output;
   end;
   keep id type line1 line2 city state zip number;
run;
proc print data=address(obs=10); run;
proc sql;
   select count (distinct line1) from address;
quit;


/*****************************/
/* Create USER/ADDRESS Links */
/*****************************/
proc sql;
   create table userAddress as
   select a.id as from, MIN(b.id) as to, "HAS_ADDRESS" as type, b.number
   from users as a
   join address as b
   on a.id = MOD(b.id-1,&DEMO_SIZE)+1
   group by number;
quit;
data userAddress;
   set userAddress(drop=number);
run;
proc print data=userAddress(obs=10); run;


/*****************************/
/* Combine nodes and links   */
/*****************************/
data nodes;
   length color $8 label $80;
   set users accounts identification phone address;
   if      type EQ 'User' then color='1';
   else if type EQ 'Checking'   then color='2';
   else if type EQ 'Savings' then color='2';
   else if type EQ 'Unsecured Loan'   then color='3';
   else if type EQ 'Credit Card'  then color='4';
   else if type EQ 'SSN'  then color='5';
   else if type EQ 'Phone'  then color='6';
   else if type EQ 'Address'  then color='7';
   else                         color='white';
   if type EQ 'User' then
      label = CATS(firstName,'\n',lastName);
   else if type EQ 'Address' then
      label = CATS(line1,'\n',line2);
   else
      label = type; 
run;

data links;
   set userAccounts userIdentification userPhone userAddress;
   label = type;
run;

proc sort data=nodes;
   by id;
run;

proc sort data=links;
   by from to;
run;

data linksHead;
   set links(obs=12);
run;
proc sort out=linksHeadFrom data=linksHead(keep=from rename=(from=id));
   by id;
run;
proc sort out=linksHeadTo   data=linksHead(keep=to   rename=(  to=id));
   by id;
run;
data nodesHead;
   merge nodes
         linksHeadFrom(IN=inFrom)
         linksHeadTo(IN=inTo);
   by id;
   if inFrom or inTo;
run;
proc print data=nodesHead; run;

data _NULL_;
   file "&_SASPROGRAMFILE/../../dot/fraud_ring_demo_0.dot";
%graph2dot(
   nodes=nodesHead,
   links=linksHead,
   nodesNode="id",
   nodesAttrs="colorscheme=accent8, style=filled, color=black",
   nodeAttrs="fillcolor=color, label=label",
   linkAttrs="label=label",
   graphAttrs="layout=fdp, overlap=prism, overlap_scaling=-5",
   directed=1
);
run;


/************************/
/* Upload tables to CAS */
/************************/
data mycas.nodes; set nodes; run;
data mycas.links; set links; run;
/*************************************/
/* Find Largest Connected Components */
/*************************************/
proc network
   links    = mycas.links
   outNodes = mycas.nodesOut;
   connectedComponents
      out=mycas.concomp
   ;
run;

proc print data=mycas.concomp(obs=10); by descending nodes; run;

proc sql outobs=4 nowarn;
   select concomp into :cc1-:cc4
   from mycas.concomp
   order by nodes desc
   ;
quit;
%put &cc1;
%put &cc2;
%put &cc3;
%put &cc4;

%displayCc(&cc1, 1);
%displayCc(&cc2, 2);
%displayCc(&cc3, 3);
%displayCc(&cc4, 4);


/********************************/
/* Find Instances of Shared SSN */
/********************************/
data mycas.LinksQuery;
   length from 8 to 8 type $16;
   input from  to  type $;
   datalines;
1 3 HAS_ID
2 3 HAS_ID
;

proc network
   direction          = directed
   links              = mycas.links
   linksQuery         = mycas.LinksQuery
   nodes              = mycas.nodesOut
   ;
   nodesVar      vars = (concomp);
   linksVar      vars = (type);
   linksQueryVar vars = (type);
   patternMatch
      outMatchNodes   = mycas.OutMatchNodes
      outMatchLinks   = mycas.OutMatchLinks
   ;
run;

proc sql outobs=4 nowarn;
   select distinct a.concomp into :cc_ssn1-:cc_ssn4
   from mycas.outMatchNodes as a
   left join mycas.concomp as b
   on a.concomp = b.concomp
   order by b.nodes desc;
   ;
quit;
%put %QUOTE(abc);

%displayCc(&cc_ssn1, 5);
%displayCc(&cc_ssn2, 6);
%displayCc(&cc_ssn3, 7);
%displayCc(&cc_ssn4, 8);


/********************************/
/* Visualize the Query Graph    */
/********************************/
data mycas.NodesQuery;
   length id 8 type $16 color $8 label $80;
   input id  type $;
   if      type EQ 'User' then color='1';
   else if type EQ 'SSN'  then color='5';
   if id EQ 1 then label = 'Person1';
   else if id EQ 2 then label = 'Person2';
   else label = type;
   datalines;
1 User
2 User
3 SSN
;
data _NULL_;
   file "&_SASPROGRAMFILE/../../dot/fraud_ring_demo_9.dot";
%graph2dot(
   nodes=mycas.NodesQuery,
   links=mycas.LinksQuery,
   nodesNode="id",
   nodesAttrs="colorscheme=accent8, style=filled, color=black",
   nodeAttrs="fillcolor=color, label=label",
   linkAttrs="label=type",
   graphAttrs="layout=fdp, overlap=prism, overlap_scaling=-5",
   directed=1
);
run;

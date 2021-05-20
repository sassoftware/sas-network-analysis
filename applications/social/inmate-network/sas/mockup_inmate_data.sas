/* Copyright © 2021, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
SPDX-License-Identifier: Apache-2.0 */

%let _COMMON_REPO_ROOT=&_SASPROGRAMFILE/../../../../../common;
%INCLUDE "&_COMMON_REPO_ROOT/sas/cas_connection.sas";
%INCLUDE "&_SASPROGRAMFILE/../helper_macros.sas";


/******************/
/* CAS Connection */
/******************/

%reconnect();

/*********************/
/* Mockup Parameters */
/*********************/
%let LOCAL_DATA_DIR=&_SASPROGRAMFILE/../../data;

%let RANDOM_SEED=123;
%let DAY_SECS=86400;
%let YEAR_DAYS=365.25;
%let N_REGIONS=5;
%let INMATES_PER_CELL=2;
%let CELLS_PER_SECTION=30;
%let SECTIONS_PER_PRISON=30;
%let INMATE_POP=40000;
%let RECIDIVISM_RATE=0.5;
%let MIGRATION_RATE=0.25;
%let SIMULATION_START='01JAN2001:00:00:00'dt;
%let SIMULATION_END='01JAN2021:00:00:00'dt;

%let STACK_CAPACITY=999;

data sentenceDistribution;
   input years firstTimeCumulative repeatCumulative;
   datalines;
0.5   .01   .02
1.0   .02   .03
2.0   .04   .08
4.0   .20   .40
5.0   .24   .60
8.0   .52   .80
10    .62   .86
20    .80   .94
30    .87   .96
50    .92   .98
100   1.0   1.0
;
options printerpath=svg nodate nonumber papersize=('3.75in','3.75in');
ods printer file="&_SASPROGRAMFILE/../../svg/mockup_inmate_data_0.svg" NEWFILE=PAGE;
proc print data=sentenceDistribution; run;
ods printer close;    


/***************/
/* Data Mockup */
/***************/

/* Mockup Inmate Sentence Data */
data inmateSentences;
   call streaminit( &RANDOM_SEED );
   retain sentenceId inmateId region sentenceStart sentenceEnd;
   format sentenceStart sentenceEnd datetime20.;
   nInmates=0;
   do i=1 to &INMATE_POP;
      nInmates = nInmates + 1;
      inmateId='I' || put(nInmates,z5.);
      region=rand("Integer", 1, &N_REGIONS);
      %sampleSentenceLen(firstTimeCumulative);
      sentenceDays = floor(sentenceYears*&YEAR_DAYS);
      daysServed = rand("Integer", 0, sentenceDays);
      sentenceStart = &SIMULATION_START-&DAY_SECS*daysServed;
      sentenceEnd = sentenceStart + &DAY_SECS*sentenceDays;
      output;

      j=1;
      do while(sentenceEnd LT &SIMULATION_END AND j LT 3);
         j = j + 1;
         x=rand("Uniform",0,1);
         if(x < &RECIDIVISM_RATE) then do;
            /* Repeat offender */
            x=rand("Uniform",0,1);
            if(x < &MIGRATION_RATE) then do;
               /* Migrate to another region */
               region=mod(region + rand("Integer", 1, 4)-1,
                          &N_REGIONS)+1;
            end;
            gapDays = floor(rand('poisson', &N_REGIONS-1)*&YEAR_DAYS);
         end;
         else do;
            /* New inmate */
            nInmates = nInmates + 1;
            inmateId='I' || put(nInmates,z5.);
            region=rand("Integer", 1, &N_REGIONS);
            gapDays = 1;
         end;

         %sampleSentenceLen(repeatCumulative);
         sentenceDays = floor(sentenceYears*&YEAR_DAYS);
         sentenceStart = sentenceEnd+&DAY_SECS*gapDays;
         sentenceEnd = sentenceStart + &DAY_SECS*sentenceDays;
         output;
      end;
   end;

   keep inmateId region sentenceStart sentenceEnd sentenceYears;
   stop;
run;
%addUniqueId(inmateSentences,sentenceId);

proc sort data=inmateSentences out=inmateSentencesByStart;
   by sentenceStart;
run;
proc sort data=inmateSentences out=inmateSentencesByEnd;
   by sentenceEnd;
run;

data _NULL_;
   if 0 then set inmateSentencesByStart nobs=n;
   call symputx('nrows',n);
   stop;
run;
%put nobs=&nrows;

/* Assign Inmates to cells/sections/prisons */
data inmateCell(keep = inmateId cellId sentenceId start end)
     cellSection(keep = cellId SectionId)
     sectionPrison(keep = sectionId prisonId)
     prisonRegion(keep = prisonId regionId);
   retain inmateId sentenceId cellId sectionId prisonId regionId;
   format start end progress datetime20.;
   length sentenceId 8;
   length region 8;
   length cellId $12 sectionId $9 prisonId $6 regionId $3;
   array inmate{&N_REGIONS} i1-i&N_REGIONS (&N_REGIONS*1);
   array cell{&N_REGIONS} c1-c&N_REGIONS (&N_REGIONS*1);
   array section{&N_REGIONS} s1-s&N_REGIONS (&N_REGIONS*1);
   array prison{&N_REGIONS} p1-p&N_REGIONS (&N_REGIONS*1);

   array stack{&STACK_CAPACITY, &N_REGIONS, 3} $12 _TEMPORARY_;
   array stackPos{&N_REGIONS} z1-z&N_REGIONS (&N_REGIONS*0);

   do region=1 to &N_REGIONS;
      regionId ='R' || put(region,z2.);
      prisonId ='R' || put(region,z2.) || 'P' || put(prison{region},z2.);
      sectionId='R' || put(region,z2.) || 'P' || put(prison{region},z2.) || 'S' || put(section{region},z2.);
      cellId   ='R' || put(region,z2.) || 'P' || put(prison{region},z2.) || 'S' || put(section{region},z2.) || 'C' || put(cell{region},z2.);

      output prisonRegion;
      output sectionPrison;
   end;

   if _N_ = 1 then do;
      declare hash h();
      rc = h.defineKey('sentenceId', 'region');
      rc = h.defineData('cellId', 'sectionId', 'prisonId');
      rc = h.defineDone();
   end;

   progress = 0;
   _j_=1;
   do _i_=1 to &nrows;
      set inmateSentencesByEnd point=_j_;
      do while(sentenceEnd LT progress);
         /* remove inmate from cell */
         h.find();
         if stackPos{region} LT &STACK_CAPACITY then do;
            stackPos{region} = stackPos{region} + 1;
            stack{stackPos{region}, region, 1} = prisonId;
            stack{stackPos{region}, region, 2} = sectionId;
            stack{stackPos{region}, region, 3} = cellId;
         end;
         _j_ = _j_ + 1;
         set inmateSentencesByEnd point=_j_;
      end;
      set inmateSentencesByStart point=_i_;
      
      regionId ='R' || put(region,z2.);
      
      /* place next inmate */
      if stackPos{region} GT 0 then do;
         /* take the first empty cell from the stack */
         prisonId = stack{stackPos{region}, region, 1};
         sectionId = stack{stackPos{region}, region, 2};
         cellId = stack{stackPos{region}, region, 3};
         stackPos{region} = stackPos{region} - 1;
      end;
      else do;
         prisonId ='R' || put(region,z2.) || 'P' || put(prison{region},z2.);
         sectionId='R' || put(region,z2.) || 'P' || put(prison{region},z2.) || 'S' || put(section{region},z2.);
         cellId   ='R' || put(region,z2.) || 'P' || put(prison{region},z2.) || 'S' || put(section{region},z2.) || 'C' || put(cell{region},z2.);

         if cell{region} GT &CELLS_PER_SECTION then do;
            cell{region} = 1;
            inmate{region} = inmate{region} + 1;
            if inmate{region} GT &INMATES_PER_CELL then do;
               cell{region} = 1;
               inmate{region} = 1;
               section{region} = section{region} + 1;
               if section{region} GT &SECTIONS_PER_PRISON then do;
                  section{region} = 1;
                  prison{region} = prison{region} + 1;
                  prisonId='R' || put(region,z2.) || 'P' || put(prison{region},z2.);
                  output prisonRegion;
               end;
               sectionId='R' || put(region,z2.) || 'P' || put(prison{region},z2.) || 'S' || put(section{region},z2.);
               output sectionPrison;
            end;
         end;
         cellId='R' || put(region,z2.) || 'P' || put(prison{region},z2.) || 'S' || put(section{region},z2.) || 'C' || put(cell{region},z2.);
         if (inmate{region} EQ 1) then output cellSection;
         cell{region} = cell{region} + 1;
      end;
      start=sentenceStart;
      end=sentenceEnd;
      output inmateCell;
      h.add();
      progress = sentenceStart;
   end;
   put "Time = " progress;
   stop;
run;

/* Make node tables */
proc sql;
   create table inmates as
   select inmateId, count(distinct sentenceId) as numSentences 
   from inmateCell
   group by inmateId;
quit;
%makeNodesFromLinks(cell, cellSection);
%makeNodesFromLinks(section, sectionPrison);
%makeNodesFromLinks(prison, prisonRegion);
%makeNodesFromLinks(region, prisonRegion);

/* Add first and last names */
%assignRandomNames(inmates, inmates);

%UploadAndSaveData(inmates);
%UploadAndSaveData(cells);
%UploadAndSaveData(sections);
%UploadAndSaveData(prisons);
%UploadAndSaveData(regions);
%UploadAndSaveData(inmateSentences);
%UploadAndSaveData(inmateCell);
%UploadAndSaveData(cellSection);
%UploadAndSaveData(sectionPrison);
%UploadAndSaveData(prisonRegion);

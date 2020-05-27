/*REXX*/
/* Input file : SMF extract sorted */
/* This programs processes one Date/Lpar/SSID a time            */
/* (at least in mode summary to calculate the accumulation)     */
/* Decode  smf 101 records - written by Nguyen Duc Tuan */
/*            Release 1.1  4 Jan 2016                   */
/*            Release 1.2  11 Feb 16 add numeric digits */
/*            Release 1.3  15 Jul 16 Possible to report a specific */
/*                         ConnType (CICS, BATCH ..)               */
/*                         z/OS 2.1 Read directly SMF records      */
/*            Release 1.4  27 Jul 16 Commits, ABort, Start time    */
/*            Release 1.5  07 Sep 16 Bug : Distributed Header not  */
/*                         displayed in some cases                 */
/*            Release 2.0  07 Sep 18 Bugs correction - DRDA records*/
/*                         not selected                            */
/*            Release 3.0  15 Jun2018 Package info                 */
/*            Release 3.1  18 Oct2018 Select records by BP Usage   */
/*            Release 3.2  07022019 RIDs figures                   */
/*            Release 3.5  20/06/19 Add waits                      */
/*-----------------------------------------------------------------*/
/* summary='Y'  produce report aggregated by plan,jobname, conntype*/
/*              in dataset &HLQ.REPORTAS (short report)            */
/* ConnSel='ALL' or CICS, BATCH, DRDA, ... any supported value     */
/*              set by this program in function DSNDQWHC           */
/* SmfOrig='B' Raw SMF dataset in input (from z/OS 2.1), allows    */
/*             to read several SMF concatenated datasets in input  */
/*             Otherwise the program expects a sorted SMF dataset  */
/*             as seen with JCL101                                 */
/* BPSel corresponds to the BPID as coded internally in DB2        */
/*             (example : 80 for BP32K)                            */
/* BPValSel Minimum value pg BP Page Updates to select             */
/*          This can be change in section DSNDQBAC:                */
/*-----------------------------------------------------------------*/
summary='N'
arg ssid hlq SmfOrig ConnSel CorridSel PackFlag BPSel BPValSel
say 'PackFlag'  PackFlag
if PackFlag='P' then PackFlag=1
  else  PackFlag=0
if ConnSel='' then ConnSel='ALL'
if CorridSel=''   then CorridSel='ALL'
 
say 'Processing for Subsys' ssid
say 'Package processing flag' PackFlag
 
if SmfOrig <> 'B' then
do
    /* Input file : SMF extract sorted */
    oufl = hlq !! '.SMFEXTA.OUT'
    address TSO
    "ALLOC DD(INP) DS('"oufl"')    SHR REU bufno(20)"
end
Sequence = 0
/* Report dataset on output */
oufl = "'" !! hlq !! '.reportA.' !! ssid !!'.A'Sequence"'"
say oufl
X=OUTTRAP(TMP.)
  "DELETE" oufl "PURGE"
X=OUTTRAP(OFF)
 
"ALLOC FI(OUFL) DA("oufl") NEW CATALOG REUSE" ,
"LRECL(900) RECFM(V B) TRACKS SPACE(1000,900)"
rcalloc = rc
if rcalloc <> 0 then Do
     say "**********************************************"
     say "   Error allocating report file" rcalloc
     say "   Abnormal end  "
     say "**********************************************"
     Exit 8
end
 
/* Report dataset on output : package */
if PackFlag     then
do
    oufl2= "'" !! hlq !! '.reportK.' !! ssid !! "'"
    say oufl2
    X=OUTTRAP(TMP.)
      "DELETE" oufl2 "PURGE"
    X=OUTTRAP(OFF)
 
    "ALLOC FI(OUFL2) DA("oufl2") NEW CATALOG REUSE" ,
    "LRECL(120) RECFM(V B) TRACKS SPACE(1000,900)"
    rcalloc = rc
    if rcalloc <> 0 then Do
         say "**********************************************"
         say "   Error allocating report package file" rcalloc
         say "   Abnormal end  "
         say "**********************************************"
         Exit 8
    end
end
 
if summary='Y' then do
  oufl = "'" !! hlq !! '.reportAS' !! "'"
X=OUTTRAP(TMP.)
  "DELETE" oufl "PURGE"
X=OUTTRAP(OFF)
  "ALLOC FI(OUFS) DA("oufl") NEW CATALOG REUSE" ,
  "LRECL(800) RECFM(V B) TRACKS SPACE(300,300)"
  rcalloc = rc
  if rcalloc <> 0 then Do
       say "**********************************************"
       say "   Error allocating report summary file" rcalloc
       say "   Abnormal end  "
       say "**********************************************"
       Exit 8
  end
end /* if summary */
 
/* compteurs input/output */
nbr_ifcid=0
NbSsid=0
old_hnt=0    /* old header next type */
reco= 0
reck= 0
reci= 0
recs= 0
rupture = 0
/* init valeurs rupture */
if summary = 'Y' then call init_sum
 
Call Write_Header
 
/* START PROCESSING */
Do Forever
  /* LECTURE record SMF UN PAR UN */
  "EXECIO 1 DISKR INP"
  IF RC > 0 THEN DO
            rcalloc=rc
            if rc = 2 then
              do
                  SAY 'End of SMF dataset - input records' reci
                  if summary='Y' then call write_summary
              end
            else
              say 'Erreur de lecture fichier SMF' rc
            LEAVE /* sortir de la boucle Do Forever */
  END
  PARSE PULL InpRec
  reci = reci+1
  ofs = 1
  CALL DSNDQWAS /* SMF Common header for accounting */
  /* From SDSNMACS(DSNDQWAS) : */
  /* If IFCID 003 : (DB2 SUBTYPE 0 ACCOUNTING RECORD SECTION MAPPING)
         DSNDQWA0
         DSNDQWHS
         DSNDQWAC
         DSNDQXST
         DSNDQBAC
         (...) */
  /* If IFCID 239 : (DB2 SUBTYPE 1 ACCOUNTING RECORD SECTION MAPPING
                 OVERFLOW PACKAGE/DBRM ACCOUNTING INFORMATION)
         DSNDQWA1
         DSNDQWHS
         DSNDQPKG
         DSNDQPAC
         DSNDQXPK
         DSNDQBAC
         DSNDQTXA
               */
  IF SM101RTY = 101 & SM101SSI = ssid   then
  DO
    recs=recs+1  /* compteurs records smf101*/
    /* Process by SMF101 subtype */
    /* The beginning is different */
    if sm101stf = 0  then
    do
          Call Process_Plan
          if result = 4 then iterate
    end
    else /* subtype = 1*/
    do
        /*if PackFlag=1 & RecSel = 1 then */
          if PackFlag                then
          do
              Call Process_Pack
              /* conntype not selected */
              if result = 4 then iterate
          end
          else iterate
      end
    /* Common processing for Plan and packages */
    Select
         When ifcid = 3  then
              do
                 /* general accounting data */
                 CALL DSNDQWAC
         /*      if rollup='1' then iterate */
                 /* sql stats */
                 if QWA01R2O > 0 then do
                            ofs = QWA01R2O - 3 /* -4+1 */
                            CALL DSNDQXST
                           end
                        else do
                        /* pas de donn�es sql*/
                           selects   =0
                           inserts   =0
                           updates   =0
                           deletes   =0
                           opens     =0
                           fetchs    =0
                        end
                 /* s'il existe des donnees buffer, les chercher*/
                 if QWA01R3O > 0 then do
                            ofs = QWA01R3O - 3 /* -4+1 */
                            CALL DSNDQBAC
                           end
                        else do
                        /* pas de donn�es buffer manager */
                           getp      =0
                           bufupd    =0
                           syncio    =0
                           syncwr    =0
                           sprfreq   =0
                           lprfreq   =0
                           dprfreq   =0
                           PgRdPrf   =0
                        end
                 if QWA01RCO > 0 then do
                            ofs = QWA01RCO - 3
                            CALL DSNDQWAX
                           end
                  else do
                     QWAXALOG=0
                     QWAXAWDR=0
                     QWAXAWCL=0
                     QWAXAWAR=0
                     QWAXOCSE=0
                     QWAXSLSE=0
                     QWAXDSSE=0
                     QWAXOTSE=0
                     QWAXAWFC=0
                     QWAXIXLT=0
 
                  end
              end /* end when ifcid=3*/
              /* ifcid 239 already processed in Process_Pack */
         Otherwise
              do
                 nop
              end
    end   /* select */
    /* on part du principe que ifcid03 est le record accounting */
    /* maitre , a voir si on commence a traiter les autres      */
 /* if ifcid=3 & RecSel = 1  then */
    if ifcid=3               then
    do
         CALL WRITE_REPORT
    end
  END /*    IF SM101RTY = 101  */
END /* Do forever */
"EXECIO 0 DISKW OUFS (STEM INL. FINIS"
"EXECIO 0 DISKW OUFL (STEM INL. FINIS"
"EXECIO 0 DISKW OUFL2(STEM INL. FINIS"
"EXECIO 0 DISKR INP (STEM INL. FINIS"
"FREE DD(INP)"
"FREE DD(OUFL)"
"FREE DD(OUFl2)"
"FREE DD(OUFS)"
/* report ifcid read */
call report_ifcid
/* report SMF records read by ssid */
call ReportSMFDs
Say 'Output records Plan: ' reco + Sequence * 1000000
Say 'Output records Package: ' reck
EXIT rcalloc
 
 
/* decode smf header */
DSNDQWAS:
   ofs = ofs + 1
   /* SM100RTY DS XL1 RECORD TYPE X'64' OR 101 */
   SM101RTY = C2D(SUBSTR(InpRec,ofs,1))
   if sm101rty <> 101 then return;
   ofs = ofs + 1
 
   /* SM101TME DS XL4 TIME SMF MOVED RECORD */
   SM101TME = C2D(SUBSTR(InpRec,ofs,4))
   ofs = ofs + 4
   CALL GET_FMT_TIME
   field    = C2X(SUBSTR(InpRec,ofs,4))
     parse value field with 1 . 2 c 3 yy 5 ddd 8 .
   /*if (c = 0) then
       yyyy = '19'!!yy
     else
       yyyy = '20'!!yy */
   sm101dte    = '20'yy!!'.'!!ddd
   ofs = ofs + 4
   /* smf id */
   sm101sid = SUBSTR(InpRec,ofs,4)
   ofs = ofs + 4
   /* SM101SSI DS CL4 SSID         */
   sm101ssi = SUBSTR(InpRec,ofs,4)
   ofs = ofs + 4
   /* Count   ssid met in this SMF data set */
   i01=1
   do while i01 <= NbSsid
       if sm101ssi = SsidList.i01 then
       do
           SsidCount.i01 = SsidCount.i01 + 1
           leave
       end
       i01=i01+1
   end
   if i01 >  NbSsid   then /* this ssid is not recorded yet */
    do
        NbSsid=NbSsid+1
        SsidList.NbSsid=sm101ssi
        SsidCount.NbSsid=1
    end
   /* SM101STF DS XL2 SMF record subtype */
   sm101stf = c2d(SUBSTR(InpRec,ofs,2))
   ofs = ofs + 6
   /* TOTAL LENGTH = 28 */
   RETURN
 
DSNDQWA0: /* MAP SELF-DEFINING SECT IFCID 003 */
  /* QWA01PSO DS AL4 ofs TO THE PRODUCT SECTION */
  QWA01PSO = C2D(SUBSTR(InpRec,ofs,4))
  ofs = ofs + 8
  /* QWA01R1O DS AL4 ofs TO THE ACCOUNTING SECTION */
  /* DSNDQWAC ACCOUNTING SECTION */
  QWA01R1O = C2D(SUBSTR(InpRec,ofs,4))
  ofs = ofs + 8 /* 4+2+2 */
  /* DSNDQXST RDS DATA : NB selects ... */
  QWA01R2O = C2D(SUBSTR(InpRec,ofs,4))
  ofs = ofs + 8 /* 4+2+2 */
  /* DSNDQBAC Buffer manager  */
  QWA01R3O = C2D(SUBSTR(InpRec,ofs,4))
  ofs = ofs +6
  nb_pools = C2D(SUBSTR(InpRec,ofs,2))
  ofs = ofs +2
  /* DSNDQTXA Lock manager  */
  ofs = ofs +8
  /* DSNDQLAC DDF ==> to be implemented wait for DBAT */
  ofs = ofs +8
  /* DSNDQMDA  DDF ProductInfo ... */
  ofs = ofs +8
  /* DSNDQIFA IFI ==> to be implemented Time spent in IFI */
  ofs = ofs +8
  /* DSNDQWAR Rollup acct info */
  ofs = ofs +8
  /* DSNDQBGA GroupBuffer */
  ofs = ofs +8
  /* DSNDQTGA Global Locking */
  ofs = ofs +8
  /* DSNDQWDA DataSharing (pas encore utilise) */
  ofs = ofs +8
  /* DSNDQWAX Acctg overflow Others wait */
  QWA01RCO = C2D(SUBSTR(InpRec,ofs,4))
  ofs = ofs +8
  /* DSNDQ8AC Accelerator acctg */
  /*ofs = ofs + 96        */
  RETURN
 
DSNDQWA1: /* MAP SELF-DEFINING SECT IFCID 239 */
  /* QWA01PSO DS AL4 ofs TO THE PRODUCT SECTION */
  /* Attention Varying length usage check macro for parsing details */
  QWA11PSO = C2D(SUBSTR(InpRec,ofs,4))
  ofs = ofs + 8
  /* QWA11R1O points to DSNDQPKG */
  QWA11R1O = C2D(SUBSTR(InpRec,ofs,4))
  ofs = ofs +4
  QWA11R1L = C2D(SUBSTR(InpRec,ofs,2))
  ofs = ofs +2
  QWA11R1N = C2D(SUBSTR(InpRec,ofs,2))
  ofs = ofs +2
  /* QWA11R2O points to DSNDQPAC */
  QWA11R2O = C2D(SUBSTR(InpRec,ofs,4))
  ofs = ofs +4
  QWA11R2L = C2D(SUBSTR(InpRec,ofs,2))
  ofs = ofs +2
  QWA11R2N = C2D(SUBSTR(InpRec,ofs,2))
  /* ofs = ofs + 8 /* 4+2+2 */
  /* DSNDQXPK number of SQL Selects , inserts ... */
  QWA11R3O = C2D(SUBSTR(InpRec,ofs,4))
  ofs = ofs +8
  /* DSNDQBAC Buffer pool stats  */
  QWA11R4O = C2D(SUBSTR(InpRec,ofs,4))
  ofs = ofs +8
  /* DSNDQTXA Lock manager  */
  */
  return
 
/* product section std header  */
DSNDQWHS:
  QWHSLEN = C2D(SUBSTR(InpRec,ofs,2))
  ofs = ofs + 4
  /*  QWHSIID DS XL2 IFCID */
  IFCID   = C2D(SUBSTR(InpRec,ofs,2))
  ofs = ofs + 3
  /* record  ifcid in this smf data */
  call record_ifcid
  /* release number C1=V12 B1=V11*/
  QWHSRN = C2X(SUBSTR(InpRec,ofs,1))
  ofs = ofs + 1
  /* ACE Address    */
  QWHSACE= C2X(SUBSTR(InpRec,ofs,4))
  ofs = ofs + 4
  QWHSSSID = SUBSTR(InpRec,ofs,4)
  ofs = ofs + 74
  /*v11 */
  if QWHSRN = 'B1' then return
  /*v12 */
  /* Modification level*/
  QWHS_MOD_LVL=SUBSTR(InpRec,ofs,10)
  ofs = ofs + 30
  RETURN
 
/* correlation header */
DSNDQWHC:
  ofs_corr=ofs
  QWHCLEN = C2D(SUBSTR(InpRec,ofs,2))
  ofs = ofs + 2
  QWHCTYP = C2D(SUBSTR(InpRec,ofs,1))
  ofs = ofs + 2
  /* authid */
  QWHCAID      = SUBSTR(InpRec,ofs,8)
  ofs = ofs + 8
  QWHCCV  = SUBSTR(InpRec,ofs,12)
  ofs = ofs + 12
  /* Correlation ID selection */
  if CorridSel <> 'ALL' & CorridSel <> qwhccv then return 4
  /* QWHCCN DS CL8 CONNECTION NAME */
  QWHCCN = SUBSTR(InpRec,ofs,8)
  ofs = ofs + 8
  /* QWHCPLAN DS CL8 PLAN NAME */
  QWHCPLAN = SUBSTR(InpRec,ofs,8)
  ofs = ofs + 8
  /* QWHCOPID  initial  authid */
  QWHCOPID  = SUBSTR(InpRec,ofs,8)
  ofs = ofs + 8
  /* QWHCATYP  Type de connection*/
  QWHCATYP  = C2D(SUBSTR(InpRec,ofs,4))
      Select
           When QWHCATYP  = 4  Then do
                                        conntype='CICS'
                                    end
           When QWHCATYP  = 2  Then do
                                        conntype='DB2CALL'
                /* direct call inside program (used by software ..)*/
                /* example BMC utilities  - CAF */
                                    end
           When QWHCATYP  = 1  Then do
                                        conntype='BATCH'
                                    end
           When QWHCATYP  = 3  Then do
                                        conntype='DL1'
                /* PGM=DFSRRC00,PARM='DLI,...' */
                                    end
           When QWHCATYP  = 5  Then do
                                        conntype='IMSBMP'
                                    end
           When QWHCATYP  = 6  Then do
                                        conntype='IMSMPP'
                                    end
           When QWHCATYP  = 8  Then do
                                        conntype='DRDA'
                                    end
           When QWHCATYP  = 9  Then do
                                        conntype='IMSCTR'
                    /* not seen */
                                    end
           When QWHCATYP  = 10 Then do
                                        conntype='IMSTRANBMP'
                    /* not seen */
                                    end
           When QWHCATYP  = 11 Then do
                                        conntype='DB2UTIL'
                                    end
           When QWHCATYP  = 12 Then do
                                        conntype='RRSAF'
                    /* not seen */
                                    end
           Otherwise      say 'QWHCATYP' QWHCATYP 'not processed'
      end   /* select */
 
  /* Connection Type selection */
  if ConnSel <> 'ALL' & ConnSel <> Conntype then
       return 4
 
  if conntype = 'CICS' ! conntype = 'DRDA' ! conntype = 'IMSMPP'
    then jobn= QWHCCN
    else jobn = QWHCCV
 
  ofs = ofs + 28
  if conntype =  'DRDA' then
  do
    /* QWHCEUID  end userid */
    QWHCEUID  = SUBSTR(InpRec,ofs,16)
    ofs = ofs + 48
    /* QWHCEUWN  user workstation name */
    QWHCEUWN  = SUBSTR(InpRec,ofs,18)
  end
  else do
    QWHCEUID  = ''
    QWHCEUWN  = ''
  end
  RETURN 0
 
 
DSNDQWHD: /* MAP distributed header */
    ofs= ofs_header            + 4 /* skip len + type */
    /* requester location */
    QWHDRQNM = SUBSTR(InpRec,ofs,16)
    ofs= ofs + 24
    QWHDSVNM = SUBSTR(InpRec,ofs,16)
    ofs= ofs + 16
    QWHDPRID = SUBSTR(InpRec,ofs,8)
  return
 
DSNDQPAC: /* MAP package ACCOUNTING DATA SECTION */
  NUMERIC DIGITS 30
  ofs = ofs +20
  /* Collection ID */
  QPACCOLN = SUBSTR(InpRec,ofs,8) /* limited to 8 chars */
  ofs = ofs +18
  /* Package name  */
  QPACPKID = SUBSTR(InpRec,ofs,8) /*limited to 8 chars */
/* say QPACPKID
  if strip(QPACPKID) <> 'PG0HG2' then return 4
  say 'suis la' */
  ofs = ofs +18 + 8
  /* SQL COUNT     */
  QPACSQLC = c2d(SUBSTR(InpRec,ofs,4))
  ofs = ofs +20
  /* Elapsed */
  QPACSCT = C2x(SUBSTR(InpRec,ofs,8)) /*CONVERT INTO HEX VALUE*/
  ofs = ofs + 24
  QPACSCT = x2d(SUBSTR(QPACSCT,1,13)) /*ELIMINATE 1.5 BYTES */
  PkElapseTot  = ( QPACSCT) /1000000
  /* QPACEJST DS XL8 ENDING TCB CPU TIME IN ALL ENVIRONMENTS */
  QPACTJST = C2X(SUBSTR(InpRec,ofs,8)) /*CONVERT INTO HEX VALUE*/
  ofs = ofs + 8
  QPACTJST = X2D(SUBSTR(QPACTJST,1,13)) /*ELIMINATE 1.5 BYTES */
  packtcb  =  QPACTJST /1000000
  return
DSNDQWAC: /* MAP ACCOUNTING DATA SECTION */
  /* QWACBSC DS XL8 CLASS 1 BEGINNING STORE CLOCK VALUE*/
  NUMERIC DIGITS 30
  /* transform to local time value */
  Clock = c2x(SUBSTR(InpRec,ofs,8))
  call STCK2Local Clock
  ThdStart= LocalTime
  QWACBSC = C2X(SUBSTR(InpRec,ofs,8)) /*CONVERT INTO HEX VALUE*/
  QWACBSC = x2d(SUBSTR(QWACBSC,1,13)) /*ELIMINATE 1.5 BYTES */
  ofs = ofs + 8
  /* QWACESC DS XL8 CLASS 1 ENDING STORE CLOCK VALU */
  QWACESC = C2X(SUBSTR(InpRec,ofs,8)) /*CONVERT INTO HEX VALUE */
  QWACESC = X2D(SUBSTR(QWACESC,1,13)) /*ELIMINATE 1.5 BYTES */
  ofs = ofs + 8
  ELAPSED_TIME = ( QWACESC - QWACBSC ) /1000000
  if elapsed_time < 0 then
      do
         elapsed_time = QWACESC / 1000000
      end
  /* QWACBJST DS XL8 BEGINNING TCB CPU TIME FROM MVS (CLASS 1)*/
  QWACBJST = C2X(SUBSTR(InpRec,ofs,8)) /*CONVERT INTO HEX VALUE*/
  QWACBJST = X2D(SUBSTR(QWACBJST,1,13)) /*ELIMINATE 1.5 BYTES */
  ofs = ofs + 8
  /* QWACEJST DS XL8 ENDING TCB CPU TIME IN ALL ENVIRONMENTS */
  QWACEJST = C2X(SUBSTR(InpRec,ofs,8)) /*CONVERT INTO HEX VALUE*/
  QWACEJST = X2D(SUBSTR(QWACEJST,1,13)) /*ELIMINATE 1.5 BYTES */
  TCB_TIME = (QWACEJST - QWACBJST)/1000000
  /* Reason why Accounting cut
  QWACRINV=X2D(SUBSTR(InpRec,ofs,4)
  say 'QWACRINV' QWACRINV */
  ofs = ofs + 44
  QWACCOMM=C2D(SUBSTR(InpRec,ofs,4))
  ofs = ofs + 4
  QWACABRT=C2D(SUBSTR(InpRec,ofs,4))
  ofs = ofs + 4
  /* QWACASCT DB2 elapsed cl2 elapsed*/
  /* attention : this is stck time , not local time ! */
  QWACASCT = C2X(SUBSTR(InpRec,ofs,8))
  ofs=ofs + 8
  QWACASCT = X2D(SUBSTR(QWACASCT,1,13))
  QWACASCT  = QWACASCT/1000000
  /* QWACAJST DB2 CPU en stck value */
  /* attention : this is stck time , not local time ! */
  QWACAJST = C2X(SUBSTR(InpRec,ofs,8))
  ofs=ofs + 8
  QWACAJST = X2D(SUBSTR(QWACAJST,1,13))
  QWACAJST  = QWACAJST/1000000
  /* Skip next 8   bytes */
  ofs=ofs + 8
  /* Wait I/O */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  ofs=ofs + 8
  QWACAWTI=x_time(time8)
  /* Wait local locks */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  ofs=ofs + 8 + 8
  QWACAWTL=x_time(time8)
  /* Wait other Read */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  ofs=ofs + 8
  QWACAWTR=x_time(time8)
  /* Wait other write*/
  time8=c2x(SUBSTR(InpRec,ofs,8))
  ofs=ofs + 8
  QWACAWTW=x_time(time8)
  /* Wait synch exec unit switch */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  ofs=ofs + 8
  QWACAWTE=x_time(time8)
  /* Wait latch */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  ofs=ofs + 32
  QWACAWLH=x_time(time8)
  /* Wait write IO log  */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  QWACAWLG=x_time(time8)
  ofs=ofs + 12
  /* Wait LOB materialization */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  QWACALBW=x_time(time8)
  ofs=ofs + 12
  /* Wait Accel      */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  QWACAACW=x_time(time8)
  ofs=ofs + 8
  /* Wait page latch      */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  QWACAWTP=x_time(time8)
  ofs=ofs + 16
  /* Wait messages to others members */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  QWACAWTG=x_time(time8)
  /* Wait global locks  */
  ofs=ofs + 8
  time8=c2x(SUBSTR(InpRec,ofs,8))
  QWACAWTJ=x_time(time8)
  /* Wait time to proccess SP        */
  ofs=ofs + 16
  time8=c2x(SUBSTR(InpRec,ofs,8))
  QWACSPCP=x_time(time8)
  /* Wait time to proccess SQL in SP */
  ofs=ofs + 8
  time8=c2x(SUBSTR(InpRec,ofs,8))
  QWACSPTT=x_time(time8)
  /* Wait TCB for SP */
  ofs=ofs + 12
  time8=c2x(SUBSTR(InpRec,ofs,8))
  QWACCAST=x_time(time8)
  ofs=ofs + 12
  /* Rollup  */
  QWACPCNT=c2d(SUBSTR(InpRec,ofs,4))
  ofs=ofs + 4
  QWACPACE=c2x(SUBSTR(InpRec,ofs,4))
  ofs=ofs + 16
  /* log records */
  QWACLRN  = C2D(SUBSTR(InpRec,ofs,4))
  ofs=ofs + 4
  /* log bytes written */
  QWACLRAB = C2D(SUBSTR(InpRec,ofs,8))
  /* DB2PTASK*/
  select
    when QWACPACE = QWHSACE & QWACPCNT > 0    then DB2PTASK='ROLL'
    when QWACPACE = '00000000' & QWACPCNT > 0 then DB2PTASK='PARENT'
    when QWACPACE > '00000000' then DB2PTASK='CHILD'
    otherwise DB2PTASK=' '
  end
  ofs=ofs + 8
  /* CPU1  UDF */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  QWACUDCP=x_time(time8)
  ofs=ofs + 8
  /* CPU2  UDF */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  QWACUDTT=x_time(time8)
  ofs=ofs + 12
  /* Wait TcB UDF */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  QWACUDST=x_time(time8)
  ofs=ofs + 8
  /* Elap     UDF */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  QWACUDEA=x_time(time8)
  ofs=ofs + 8
  /* Elap     UDF2*/
  time8=c2x(SUBSTR(InpRec,ofs,8))
  QWACUDEB=x_time(time8)
  ofs=ofs + 8
  /* Cpu trigger*/
  time8=c2x(SUBSTR(InpRec,ofs,8))
  QWACTRTT=x_time(time8)
  ofs=ofs + 8
  /* Elaptrigger*/
  time8=c2x(SUBSTR(InpRec,ofs,8))
  QWACTRET=x_time(time8)
  ofs=ofs + 24
  /* Elap SP*/
  time8=c2x(SUBSTR(InpRec,ofs,8))
  QWACSPEA=x_time(time8)
  ofs=ofs + 8
  /* Elap SP2*/
  time8=c2x(SUBSTR(InpRec,ofs,8))
  QWACSPEB=x_time(time8)
  ofs=ofs + 8
  /* cpu  Trig */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  QWACTRTE=x_time(time8)
  ofs=ofs + 8
  /* Elap Trig */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  QWACTREE=x_time(time8)
  RETURN
/* buffer manager data */
DSNDQBAC:
numeric digits 15
  i = 0
  getp=0
  bufupd=0
  syncio=0
  syncwr=0
  sprfreq=0
  lprfreq=0
  dprfreq=0
  PgRdPrf=0
  If BPsel = '' ! BPSel='N' then
         RecSel=1 /* Don't select  for output, default */
  else RecSel=0
 
  do until i= nb_pools
     i = i+1
     QBACPID   = C2D(SUBSTR(InpRec,ofs,4))
     ofs=ofs + 4
     /* Get page */
     QBACGET   = C2D(SUBSTR(InpRec,ofs,4))
     ofs=ofs + 4
     getp = getp+QBACGET
     /* Buffer page updates */
     QBACSWS   = C2D(SUBSTR(InpRec,ofs,4))
     BufUpd = BufUpd +QBACSWS
     ofs = ofs + 8
     /* Sync reads */
     QBACRIO   = C2D(SUBSTR(InpRec,ofs,4))
     syncio = syncio+QBACRIO
     ofs = ofs + 4
     /* Seq prefetchs  */
     QBACSEQ   = C2D(SUBSTR(InpRec,ofs,4))
     sprfreq = sprfreq+QBACSEQ
     ofs = ofs + 4
     /* Immediate writes , happens only if Immed Write Threshold
        reached (97.5% of pages in use ) */
     QBACIMW   = C2D(SUBSTR(InpRec,ofs,4))
     syncwr  = syncwr + QBACIMW
     ofs = ofs + 4
     /* List prefetchs */
     QBACLPF   = C2D(SUBSTR(InpRec,ofs,4))
     lprfreq = lprfreq+QBACLPF
     ofs = ofs + 4
     /* Dyn prefetchs */
     QBACDPF   = C2D(SUBSTR(InpRec,ofs,4))
     dprfreq = dprfreq+QBACDPF
     ofs = ofs + 24
     /* Async pages read by prefetch */
     QBACSIO   = C2D(SUBSTR(InpRec,ofs,4))
     PgRdPrf = PgRdPrf+QBACSIO
     ofs = ofs + 8
 
    /* Select data to report */
 
 
    if  QBACPID = BPSel  then
    do
        /* Customize here the code to select the record */
        /* Here, i select by number of updates  */
        if  QBACSWS >= BPValSel then
         do
            /* Record OK for output */
            RecSel=1
            Say run_fmt_time strip(qwhccv,'T'),
            'Pool Id:'QBACPID 'GP:'QBACGET 'Upd:'QBACSWS,
            'Sync:'QBACRIO 'Lprf:'QBACLPF,
            'DPrf' QBACDPF 'PgReadPrf:'QBACSIO
         end
    end
  end /* nb_pools */
 
  return
/* Others accounting data */
DSNDQWAX:
numeric digits 15
  /* Wait ARCHIVE LOG MODE(QUIESCE) */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  ofs=ofs + 16
  QWAXALOG=x_time(time8)
  /* Wait time for DRAIN LOCK */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  ofs=ofs + 8
  QWAXAWDR=x_time(time8)
  /* Wait time for Claim before Drain */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  ofs=ofs + 8
  QWAXAWCL=x_time(time8)
  ofs=ofs + 4
  /* Wait time for Read Logs */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  ofs=ofs + 8
  QWAXAWAR=x_time(time8)
  ofs=ofs + 4
  /* Wait time for Unit Switch Open Close HSM Recall */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  ofs=ofs + 8
  QWAXOCSE=x_time(time8)
  /* Wait time syslgrnx */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  ofs=ofs + 8
  QWAXSLSE=x_time(time8)
  /* Wait time for dataset*/
  time8=c2x(SUBSTR(InpRec,ofs,8))
  ofs=ofs + 8
  QWAXDSSE=x_time(time8)
  /* Wait time for others Synchronous Unit Switch */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  ofs=ofs + 24
  QWAXOTSE=x_time(time8)
  /* Wait time for Force At Commit */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  ofs=ofs + 16
  QWAXAWFC=x_time(time8)
  /* Wait time for Asynch GBP request */
  time8=c2x(SUBSTR(InpRec,ofs,8))
  QWAXIXLT=x_time(time8)
 
  return
/* sql statements  */
DSNDQXST:
   selects   =0
   inserts   =0
   updates   =0
   deletes   =0
   opens     =0
   fetchs    =0
   calls     =0
   incrbnds  =0
   callsAb   =0
   ofs=ofs + 4
   eye_catch = SUBSTR(InpRec,ofs,4)
   if eye_catch <> 'QXST' then
           do
              say 'QXST eye catcher not found at record' reci,
                  ' ofs' ofs
              exit 8
           end
   ofs=ofs + 4
   selects   = C2D(SUBSTR(InpRec,ofs,8))
   ofs=ofs + 8
   inserts   = C2D(SUBSTR(InpRec,ofs,8))
   ofs=ofs + 8
   updates   = C2D(SUBSTR(InpRec,ofs,8))
   ofs=ofs + 8
   deletes   = C2D(SUBSTR(InpRec,ofs,8))
   ofs=ofs + 24
   opens     = C2D(SUBSTR(InpRec,ofs,8))
   ofs=ofs + 136 /* 17*8*/
   fetchs    = C2D(SUBSTR(InpRec,ofs,8))
   ofs=ofs + 64 /* 8*8 */
   incrbnds  = C2D(SUBSTR(InpRec,ofs,8))  /*QXINCRB*/
   ofs=ofs + 40  /*  5*8*/
   QXMIAP    = C2D(SUBSTR(InpRec,ofs,8))  /*RID    */
   ofs=ofs + 8
   QXNSMIAP  = C2D(SUBSTR(InpRec,ofs,8))  /*NoRid No storage*/
   ofs=ofs + 8
   QXMRMIAP  = C2D(SUBSTR(InpRec,ofs,8))  /*NoRid Internal Limit*/
   ofs=ofs + 144 /* 18*8*/
   calls     = C2D(SUBSTR(InpRec,ofs,8))
   ofs=ofs + 8
   callsab   = C2D(SUBSTR(InpRec,ofs,8))
   ofs=ofs + 56
   reopts    = C2D(SUBSTR(InpRec,ofs,8))
   ofs=ofs + 464
   rowsftc   = C2D(SUBSTR(InpRec,ofs,8))
   ofs=ofs + 8
   rowsins   = C2D(SUBSTR(InpRec,ofs,8))
   ofs=ofs + 8
   rowsupd   = C2D(SUBSTR(InpRec,ofs,8))
   ofs=ofs + 8
   rowsdel   = C2D(SUBSTR(InpRec,ofs,8))
   ofs=ofs + 80
   Rid2WrkfOvf  = C2D(SUBSTR(InpRec,ofs,8)) /*QXWFRIDS*/
   ofs=ofs + 8
   Rid2WrkfLim  = C2D(SUBSTR(InpRec,ofs,8))
   ofs=ofs + 8
  return
 
GET_FMT_TIME:
  RUN_HH = SM101TME % 360000
  RUN_HH = RIGHT(RUN_HH,2,'0')
  RUN_MIN = SM101TME % 6000 - RUN_HH*60
  RUN_MIN = RIGHT(RUN_MIN,2,'0')
  RUN_SEC = SM101TME % 100 - RUN_HH *3600 - RUN_MIN*60
  RUN_SEC = RIGHT(RUN_SEC,2,'0')
  RUN_FMT_TIME = RUN_HH!!':'!!RUN_MIN!!':'!!RUN_SEC
RETURN
 
write_header:
  say 'file ' oufl     ' will be produced'
  queue "Lpar,Ssid,Date,ThdEnd,RunHr,RunMn,ThdStart,",
        "TransCnt,QWHSACE,QWACPACE,",
        "PTASK,Authid,Corrid,Tran,Connid,Plan,",
        "OrigPrimAuth,Conntype,Cl1Elap,Cl1Cpu,Cl2El,Cl2Cpu,",
        "NotAcct,PctNotAcc,PctWait,",
        "Commit,Abort,LogRec,LogBytes,",
        "WaitIO,WtLock,WtOthRd,WtOthWr,",
        "WtSync,WtLatch,",
        "WtWrLog,WtLob,WtAcc,WtPgLatch,WtMsg,WtGlLock,",
        "CpuSP1,CpuSP2,WtTcbSP,",
        "Cpu1UDF,Cpu2UDF,WtTcbUDF,",
        "El1UDF,El2UDF,CpuTrig,ElapTrig,",
        "El1SP,El2SP,CpuTrig,ElapTrig,",
        "ElArc,ElDrain,ElClaim,ElIOLog,ElOpDS,ElSysLgx,",
        "ElDefDS,ElOthUS,",
        "ElForceCom,ElAsynGBP,",
        "Getp,SyncIo,BufUpd,SyncWr,SPrfReq,LPrfReq,DPrfReq,",
        "PgRdPrf,",
        "Sels,Ins,Upd,Del,Open,Fetch,IncBnd,reopts,",
        "Rid,NoRidStor,NoRidLim,",
        "CallSp,CallSpAb,",
        "Rowsftc,RowsIns,RowsUpd,RowsDel,RID2WrkfOvf,Rid2WrkfLim,",
        "ReqLoc,SrvName,SrvProdId,WrkSUser,WrkSNam"
 
  "EXECIO" queued() "DISKW OUFL"
 
  if summary='Y' then
  do
    say 'file ' oufs     ' will be produced'
    queue "Lpar,Ssid,Date,Hour,Plan,Jobn,",
           "Conntype,Occ,Cl1Cpu,Cl2Cpu,",
           "Getp,SyncIo,BufUpd,SyncWr,SPrfReq,LPrfReq,DPrfReq,",
           "PgRdPrf,",
           "Selects,Inserts,Updates,Deletes,Opens,Fetchs",
 
    "EXECIO" queued() "DISKW OUFs"
  end
 
  if PackFlag=1  then
  do
    say 'file ' oufl2    ' will be produced'
    queue "Lpar,Ssid,Date,Time,Corrid,Plan,Coll,Pack,",
           "SqlCnt,Elapse,Cpu,Conntype"
 
    "EXECIO" queued() "DISKW OUFl2"
  end
 
  return
 
WRITE_REPORT:
    reco= reco+ 1
    if reco > 1000000 then do
       reco =1
       Sequence = Sequence+1
       call SwitchFile
    end
    if conntype='CICS' then
       tranid = substr(qwhccv,5,4)
    else tranid = ' '
    /* Not accounted = elapse db2 - cpu db2 - total waits */
    Totwait=,
      QWACAWTI+QWACAWTL+QWACAWTR+QWACAWTW+QWACAWTE+QWACAWLH+,
      QWACAWLG+QWACALBW+QWACAACW+QWACAWTP+QWACAWTG+QWACAWTJ+,
      QWAXALOG+QWAXAWDR+QWAXAWCL+QWAXAWAR+QWAXOCSE+QWAXDSSE+,
      QWAXOTSE+QWAXAWFC+QWAXIXLT+QWAXSLSE
 
 
    NotAccount= QWACASCT-QWACAJST- TotWait
    If NotAccount < 0 then NotAccount=0
    /* Pourcent elapse in Not Account */
    If  QWACASCT = 0 then  PctNotAccount = 0
    else
        PctNotAccount= NotAccount/QWACASCT*100
    /* Pourcent elapse in Wait        */
    if totwait > QWACASCT then PctWait = -1
    else
    do
        If  QWACASCT = 0 then  PctWait = 0
        else
        PctWait      = TotWait/QWACASCT*100
    end
    /* Rows in excel format */
      queue sm101sid !! ',' !! sm101ssi !! ','  ,
      !! sm101dte !! ','   ,
      !! run_fmt_time !! ','   ,
      !! run_hh !! ','   ,
      !! run_min !! ','   ,
      !! ThdStart     !! ','   ,
      !! QWACPCNT     !! ','   ,
      !! '"' !! QWHSACE !! '"'     !! ','   ,
      !! '"' !! QWACPACE!! '"'     !! ','   ,
      !! DB2PTASK     !! ','   ,
      !! strip(QWHCAID,'T')           !! ','   ,
      !! strip(qwhccv,'T')            !! ','   ,  /* CORRID*/
      !! tranid                       !! ','   ,  /* Tran name */
      !! strip(qwhccn,'T')            !! ','   ,
      !! strip(qwhcplan,'T')          !! ','   ,
      !! strip(qwhcopid,'T')          !! ','   ,
      !! conntype          !! ','   ,
      !! elapsed_time     !! ','   , /* cl1 elapsed*/
      !! tcb_time  !! ','   ,    /*cl1cpu*/
      !! QWACASCT  !! ','   ,    /*cl2 elap */
      !! QWACAJST  !! ','   ,    /*cl2cpu*/
      !! NotAccount!! ','   ,
      !! strip(format(PctNotAccount,3,1))!! ','   ,
      !! strip(format(PctWait,3,1))!! ','   ,
      !! QWACCOMM  !! ','   ,    /*commits*/
      !! QWACABRT  !! ','   ,    /*abort*/
      !! QWACLRN   !! ','   ,    /*log records*/
      !! QWACLRAB  !! ','   ,    /*log bytes  */
      !! strip(format(QWACAWTI,9,5))!! ',' , /*wait io*/
      !! strip(format(QWACAWTL,9,5))!! ',' , /*wait locks */
      !! strip(format(QWACAWTR,9,5))!! ',' , /*wait oth. read */
      !! strip(format(QWACAWTW,9,5))!! ',' , /*wait oth write */
      !! strip(format(QWACAWTE,9,5))!! ',' , /*wait sync*/
      !! strip(format(QWACAWLH,9,5))!! ',' , /*wait latch */
      !! strip(format(QWACAWLG,9,5))!! ',' , /*wait IO log */
      !! strip(format(QWACALBW,9,5))!! ',' , /*wait lob */
      !! strip(format(QWACAACW,9,5))!! ',' , /*wait accelerator*/
      !! strip(format(QWACAWTP,9,5))!! ',' , /*wait page latch */
      !! strip(format(QWACAWTG,9,5))!!',' , /*wait messages other members */
      !! strip(format(QWACAWTJ,9,5))!! ',' , /*wait global locks */
      !! strip(format(QWACSPCP,9,5))!! ',' , /*wait SP */
      !! strip(format(QWACSPTT,9,5))!! ',' , /*wait SP 2 */
      !! strip(format(QWACCAST,9,5))!! ',' , /*wait SP 3 */
      !! strip(format(QWACUDCP,9,5))!! ',' , /*wait SP 3 */
      !! strip(format(QWACUDTT,9,5))!! ',' , /*wait SP 3 */
      !! strip(format(QWACUDST,9,5))!! ',' , /*wait SP 3 */
      !! strip(format(QWACUDEA,9,5))!!',' , /*wait SP 3 */
      !! strip(format(QWACUDEB,9,5))!! ',' , /*wait SP 3 */
      !! strip(format(QWACTRTT,9,5))!! ',' , /*wait SP 3 */
      !! strip(format(QWACTRET,9,5))!! ',' , /*wait SP 3 */
      !! strip(format(QWACSPEA,9,5))!! ',' , /*wait SP 3 */
      !! strip(format(QWACSPEB,9,5))!! ',' , /*wait SP 3 */
      !! strip(format(QWACTRTE,9,5))!! ',' , /*wait SP 3 */
      !! strip(format(QWACTREE,9,5))!! ',' , /*wait SP 3 */
      !! strip(format(QWAXALOG,9,5))!! ',' ,
      !! strip(format(QWAXAWDR,9,5))!! ',' ,
      !! strip(format(QWAXAWCL,9,5))!! ',' ,
      !! strip(format(QWAXAWAR,9,5))!! ',' ,
      !! strip(format(QWAXOCSE,9,5))!! ',' ,
      !! strip(format(QWAXSLSE,9,5))!! ',' ,
      !! strip(format(QWAXDSSE,9,5))!! ',' ,
      !! strip(format(QWAXOTSE,9,5))!! ',' ,
      !! strip(format(QWAXAWFC,9,5))!! ',' ,
      !! strip(format(QWACTREE,9,5))!! ',' ,
      !! getp      !! ','   ,
      !! syncio    !! ','   ,
      !! BufUpd    !! ','   ,
      !! syncwr    !! ','   ,
      !! sprfreq   !! ','   ,
      !! lprfreq   !! ','   ,
      !! dprfreq   !! ','   ,
      !! PgRdPrf   !! ','   ,
      !! selects   !! ','   ,
      !! inserts   !! ','   ,
      !! updates   !! ','   ,
      !! deletes   !! ','   ,
      !! opens     !! ','   ,
      !! fetchs    !! ','   ,
      !! IncrBnds  !! ','   ,
      !! reopts    !! ','   ,
      !! QXMIAP    !! ','   ,
      !! QXNSMIAP  !! ','   ,
      !! QXMRMIAP  !! ','   ,
      !! Calls     !! ','   ,
      !! CallsAb   !! ','   ,
      !! RowsFtc   !! ',' RowsIns!! ',' RowsUpd !! ',',
      !! RowsDel   !! ',' Rid2WrkfOvf !! ',' Rid2WrkfLim !! ',',
      !! strip(QWHDRQNM,'T')  !! ','   ,
      !! strip(QWHDSVNM,'T')   !! ','   ,
      !! strip(QWHDPRID,'T')   !! ','   ,
      !! strip(QWHCEUID,'T')   !! ','   ,
      !! strip(QWHCEUWN,'T')
 
     "EXECIO" queued() "DISKW OUFL"
 
   if QWHDRQNM > '' then do
    /*  say 'ddf:' QWHDRQNM QWHDPRID qwhccv */
   end
   if summary='Y' then call process_summary
return
 
WRITEK_REPORT:
    reck= reck+ 1
    /*rows in excel format */
    queue sm101sid !! ',' !! sm101ssi !! ','  ,
    !! sm101dte !! ','   ,
    !! run_fmt_time !! ','   ,
    !! strip(qwhccv,'T')            !! ','   ,  /* CORRID*/
    !! strip(qwhcplan,'T')          !! ','   ,
    !! strip(QPACCOLN,'T')           !! ','   ,
    !! strip(QPACPKID,'T')           !! ','   ,
    !! QPACSQLC                      !! ','   ,
    !! PkElapseTot                   !! ','   ,
    !! packtcb !! ','   ,
    !! conntype
 
   "EXECIO" queued() "DISKW OUFL2"
 
return
 
process_summary:
   hour = left(run_fmt_time,2)
   /* pas de rupture pour le 1er record lu */
   if rupture = 0
   then do
       rupture=1
       occ=0
       s_hour=hour
       s_qwhcplan=qwhcplan
       s_jobn=jobn
       s_conntype=conntype
   end
/* say 'test rupture'  reci */
/* say s_hour hour          */
/* say s_qwhcplan qwhcplan  */
/* say s_jobn jobn          */
/* say s_conntype conntype  */
   /* detection rupture,declenche ecriture*/
   if   hour <>  s_hour   ! ,
        conntype <> s_conntype ! ,
   strip(qwhcplan)!!strip(jobn) <> strip(s_qwhcplan)!!strip(s_jobn)
   then do
       call write_summary
       sm_tcb_time  =  tcb_time
       sm_QWACAJST  =  QWACAJST
       sm_getp      =  getp
       sm_BufUpd    =  BufUpd
       sm_syncio    =  syncio
       sm_syncwr    =  syncwr
       sm_sprfreq   =  sprfreq
       sm_lprfreq   =  lprfreq
       sm_dprfreq   =  dprfreq
       sm_PgRdPrf   =  PgRdPrf
       sm_selects   =  selects
       sm_inserts   =  inserts
       sm_updates   =  updates
       sm_deletes   =  deletes
       sm_opens     =  opens
       sm_fetchs    =  fetchs
       occ=1
 
   end
   /*pas de rupture , on accumule les valeurs */
   else do
          sm_tcb_time  =  tcb_time + sm_tcb_time
          sm_QWACAJST  =  QWACAJST + sm_QWACAJST
          sm_getp      =  getp     + sm_getp
          sm_BufUpd    =  BufUpd   + sm_BufUpd
          sm_syncio    =  syncio   + sm_syncio
          sm_syncwr    =  syncwr   + sm_syncwr
          sm_sprfreq   =  sprfreq  + sm_sprfreq
          sm_lprfreq   =  lprfreq  + sm_lprfreq
          sm_dprfreq   =  dprfreq  + sm_dprfreq
          sm_PgRdPrf  =  PgRdPrf  + sm_PgRdPrf
          sm_selects   =  selects  + sm_selects
          sm_inserts   =  inserts  + sm_inserts
          sm_updates   =  updates  + sm_updates
          sm_deletes   =  deletes  + sm_deletes
          sm_opens     =  opens    + sm_opens
          sm_fetchs    =  fetchs   + sm_fetchs
          occ = occ + 1
   end/*pas de rupture , on accumule les valeurs */
 
   /* dans tous les cas , on sauvegarde les valeurs */
   /*s_sm101sid = sm101sid  */
   /*s_sm101ssi = sm101ssi  */
   /*s_sm101dte = sm101dte  */
   hour = left(run_fmt_time,2)
   s_hour = hour
   s_run_fmt_time = run_fmt_time
   s_qwhccv = qwhccv
   s_qwhccn = qwhccn
   s_qwhcplan =  qwhcplan
   s_conntype = conntype
   s_jobn  =jobn
 
   return
 
write_summary:
     queue sm101sid !! ',' !! sm101ssi !! ','  ,
     !! sm101dte !! ','   ,
     !! s_hour !! ','   ,
     !! s_qwhcplan               !! ','   ,
     !! s_jobn                !! ','   ,
     !! s_conntype          !! ','   ,
     !! occ                 !! ','   ,
     !! sm_tcb_time  !! ','   ,
     !! sm_QWACAJST  !! ','   ,    /*cl2cpu*/
     !! sm_getp      !! ','   ,
     !! sm_syncio    !! ','   ,
     !! sm_BufUpd    !! ','   ,
     !! sm_syncwr    !! ','   ,
     !! sm_sprfreq   !! ','   ,
     !! sm_lprfreq   !! ','   ,
     !! sm_dprfreq   !! ','   ,
     !! sm_PgRdPrf   !! ','   ,
     !! sm_selects   !! ','   ,
     !! sm_inserts   !! ','   ,
     !! sm_updates   !! ','   ,
     !! sm_deletes   !! ','   ,
     !! sm_opens     !! ','   ,
     !! sm_fetchs
 
    "EXECIO" queued() "DISKW OUFS"
   return
 
init_sum:
   sm_tcb_time = 0
   sm_QWACAJST = 0
   sm_getp     = 0
   sm_BufUpd   = 0
   sm_syncio   = 0
   sm_syncwr   = 0
   sm_sprfreq  = 0
   sm_lprfreq  = 0
   sm_dprfreq  = 0
   sm_PgRdPrf  = 0
   sm_selects   =0
   sm_inserts   =0
   sm_updates   =0
   sm_deletes   =0
   sm_opens     =0
   sm_fetchs    =0
   return
 
STCK2Local:
    /* Store Clock Value Time to Local Time */
    arg clock
    clock = SPACE(clock,0)
    cvt     = C2X(STORAGE(10,4))
    cvttz_p = D2X(X2D(cvt) + X2D(130))
    tzo     = STORAGE(cvttz_p,4)
    tzo     = C2D(tzo,4)*1.048576
    tzo     = (tzo+.5)%1
    ndigits = MAX(6,1.2*LENGTH(clock)+1)%1
    Numeric Digits ndigits
    clock   = x2d(clock)*1.048576 / 16**(LENGTH(clock)-8)
    clock   = clock + tzo
    If clock < 0  Then Parse Value 0      0     ,
                             With  clock  tzo
    seconds = clock // (24*60*60)
    hours   = RIGHT( seconds %3600    ,2,'0')
    minutes = RIGHT((seconds//3600)%60,2,'0')
    seconds = substr(TRANSLATE(FORMAT(seconds//60,2),'0',' '),1,2)
    /* t1      = y'/'m'/'d hours':'minutes':'seconds   */
    LocalTime=  hours':'minutes':'seconds
    return
record_ifcid:
   found=0
   do i = 1 to nbr_ifcid
      if ifcid_st.i = ifcid then
         do
            found=1
            ifcid_count.i=ifcid_count.i+1
            leave
         end
   end
   /* not found : add new ifcid to list*/
   if found=0 then
      do
         nbr_ifcid = nbr_ifcid + 1
         ifcid_st.nbr_ifcid = ifcid
         ifcid_count.nbr_ifcid = 1
      end
   return
report_ifcid:
  say ' '
  say 'List of IFCIDS read in this SMF file :' nbr_ifcid
  say 'IFCID/Description/Count'
  do i=1 to nbr_ifcid
      Select
           When ifcid_st.i = 03 then
                      ifcid_desc='Gen. Accounting data - processed'
           When ifcid_st.i = 04 then
                      ifcid_desc='Trace stop'
           When ifcid_st.i = 05 then
                      ifcid_desc='Trace stop'
           When ifcid_st.i = 22 then
                      ifcid_desc='Mini Bind'
           When ifcid_st.i = 53 then
                      ifcid_desc='SQL Desc/Comm/Rollb/Remote Stmt'
           When ifcid_st.i = 58 then
                      ifcid_desc='End SQL'
           When ifcid_st.i = 59 then
                      ifcid_desc='Start Fetch'
           When ifcid_st.i = 63 then
                      ifcid_desc='SQL text'
           When ifcid_st.i = 64 then
                      ifcid_desc='Prepare Start'
           When ifcid_st.i = 65 then
                      ifcid_desc='Open cursor'
           When ifcid_st.i = 66 then
                      ifcid_desc='Close cursor'
           When ifcid_st.i = 90 then
                      ifcid_desc='Start Command'
           When ifcid_st.i = 95 then
                      ifcid_desc='Sort start'
           When ifcid_st.i = 96 then
                      ifcid_desc='Sort stop'
           When ifcid_st.i = 105 then
                      ifcid_desc='DBDID OBID translat'
           When ifcid_st.i = 106 then
                      ifcid_desc='System init parms'
           When ifcid_st.i = 112 then
                      ifcid_desc='Thread alloc'
           When ifcid_st.i = 172 then
                      ifcid_desc='DeadLock, timeout'
           When ifcid_st.i = 173 then
                      ifcid_desc='CL2 time'
           When ifcid_st.i = 177 then
                      ifcid_desc='Pkg alloc'
           When ifcid_st.i = 196 then
                      ifcid_desc='Timeout data'
           When ifcid_st.i = 239 then
                      ifcid_desc='Package Accounting data'
           When ifcid_st.i = 254 then
                      ifcid_desc='CF structure cache stats'
           When ifcid_st.i = 258 then
                      ifcid_desc='Dataset extend activity'
           When ifcid_st.i = 313 then
                      ifcid_desc='Uncomm. UR'
           When ifcid_st.i = 337 then
                      ifcid_desc='Lock Escalation'
           When ifcid_st.i = 350 then
                      ifcid_desc='SQL text'
           When ifcid_st.i = 401 then
                      ifcid_desc='Static SQL stats'
           otherwise do
                      ifcid_desc='Unknow'
                      say 'Unknow ifcid'  ifcid_st.i
                     end
 
      end   /* select */
     say ifcid_st.i  ifcid_desc ifcid_count.i
   end /* end do */
   say ' '
   return
x_time:
  arg time8
  time8    = X2D(SUBSTR(time8,1,13))
  time8     = time8/1000000
  return time8
Process_plan:
   CALL DSNDQWA0 /* MAP SELF-DEFINING SECT */
   ofs = QWA01PSO - 3 /* -4+1 */
   CALL DSNDQWHS /* MAP product section STANDARD HEADER */
   CALL DSNDQWHC /* MAP CORRELATED HEADER, just after the standard*/
              /* header Product Section */
 
   /* Selection on Corrid  */
   /* result is set in subroutine DSNDQWHC */
   /* select to report only some type of records */
   if result = 4 then return 4
   /* Check all hearder type and process if possible */
   /* Header type : QWHSTYP */
   /*     1                  ..STANDARD HEADER         */
   /*     2                  ..CORRELATION HEADER      */
   /*     4                  ..TRACE HEADER            */
   /*     8                  ..CPU HEADER              */
   /*     16                 ..DISTRIBUTED HEADER      */
   /*     32                 ..DATA SHARING HEADER     */
   ofs_header_next= ofs_corr+QWHCLEN
   /*init requester location */
   QWHDRQNM=''
   QWHDSVNM=''
   QWHDPRID =''
   /* ---------------------------------------*/
   Do while ofs_header_next     > 0
       temp=ofs_header_next+2 /*skip len*/
       header_next_type= C2D(SUBSTR(InpRec,temp,1))
       ofs_header = ofs_header_next
       ofs_header_next=ofs_header_next+ ,
          C2D(SUBSTR(InpRec,ofs_header_next,2))
       Select
            When header_next_type=16 then
                 do
                    /* distributed header */
                    CALL DSNDQWHD
                 end
            When header_next_type=64 then
                 do
                   /*  no more headers behind*/
                    ofs_header_next=0
                 end
            Otherwise
       end   /* select */
   end /* Do until */
   /* pointeur vers accounting section DSNDQWAC */
   ofs = QWA01R1O - 3 /* -4+1 */
return
 
Process_Pack:
   CALL DSNDQWA1 /* SELF DEFINING SECTION MACRO FOR  IFCID 239 */
   ofs = QWA11PSO - 3 /* -4+1 */
   CALL DSNDQWHS /* MAP product section STANDARD HEADER */
   CALL DSNDQWHC /* Correlation header */
   if result = 4 then return 4  /* conntype not selected */
   /*
   /* pointer  to   accounting section DSNDQPKG */
   ofs = QWA11R1O - 3 /* -4+1 */
                       /* Parsing details given in macro DSNDQWA1 */
   /*   DSNDQPKG macro */
   QPKGPKGN = c2d(substr(InpRec,ofs,2))
   */
 
   /* Read IMPORTANT PARSING INFORMATION in SDSNMACS(DSNDQWA1)*/
   /* to know how to parse a a varying length repeating group */
   /* Pointer  to   accounting section DSNDQPAC */
   ofs = QWA11R2O - 3 /* -4+1 */
   ofsMemb = ofs /* offset of the first data section <len><data>*/
   i =1
   do until i > QWA11R2N
        lenPAC = c2d(substr(InpRec,ofsMemb,2))
        ofs = ofsMemb+2 /* go to the data part*/
        call DSNDQPAC
        if result = 4 then return 4  /* record not selected */
        CALL WRITEK_REPORT
        ofsMemb = ofsMemb + lenPAC +2 /* check macro QWA1 for expl.*/
        i=i+1
   end
return
DecodeBPID:
        /* decode BPID to BP name */
        Select
             When j >='0'   & j <= '50'    Then BPNm = 'BP'j
             When j >='100' & j <= '109'   Then do
                                                  k    = j-100
                                                  BPNm = 'BP8K'k
                                                end
             When j >='120' & j <= '129'   Then do
                                                  k    = j-120
                                                  BPNm = 'BP16K'k
                                                end
             When j >='80'  & j <= '89'    Then do
                                                  k    = j-80
                                                  BPNm = 'BP32K'k
                                                end
             Otherwise do
                         say 'Buffer pool ID ??? 'j
                         BPNm = '?'j
                       end
        end
return
ReportSMFDs:
    Say 'SMF records read by Subsystem:'
    do i01=1 to NbSsid
      Say '    -' SsidList.i01 ':' SsidCount.i01
    end
    return
Switchfile:
  "EXECIO 0 DISKW OUFL (STEM INL. FINIS"
  "FREE DD(OUFL)"
  oufl = "'" !! hlq !! '.reportA.' !! ssid !!'.A'Sequence"'"
  Say 'Switch to' oufl
  X=OUTTRAP(TMP.)
  "DELETE" oufl "PURGE"
  X=OUTTRAP(OFF)
 
  "ALLOC FI(OUFL) DA("oufl") NEW CATALOG REUSE" ,
  "LRECL(900) RECFM(V B) TRACKS SPACE(1000,900)"
   return

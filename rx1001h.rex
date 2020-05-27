/*REXX*/
/****************************************************************/
/*   DB2 STATS AGGREGATED BY HOUR                               */
/****************************************************************/
/****************************************************************/
/* Updates history:                                             */
/* 26/02/2018 Bugs correction                                   */
/* 05/02/2018 Check DBDPool space avaibility                    */
/* 22/01/2018 More checks Prefetch Qty, Workfiles ..            */
/* 25/09/2018 Update RealUsedbyDB2 calculation                  */
/* 08/01/2019 GBP stats                                         */
/* 02/04/2020 More stats (QXRFMIAP)                             */
/****************************************************************/
numeric digits 15
arg OPT OPT2
DispAll=0      /* send alerts without filtering */
ssid=''
Already_here=0
sm100dte0='none'
if OPT = '' then lpar = MVSVAR(SYSNAME)
else   lpar = OPT
LparId=MVSVAR(SYMDEF,'LPARNAME')
/* Lpar with Bpool AutoSize implemented */
/* Lparnumerique = IPO4 IPO3 ZPR1 ZDV1  */
LpAuto='XX10 DD20 IPO3 IPO4 ZDV1 ZPR1 DEV'
LpDev="DEV  SYSA SYSB SYSK SYSQ SYSR PFH1 "!!,
      "PPR3 PPR4 PPR2 "!!,
      "ZDV1 ZSY1 ZSY2 "!!,
      "IPO1 IPOA IPO2 IPO3 "!!,
      "DJ02 "!!,
      "DD20 "!!,
      "OSET MVST OSJB "!!,
      "SYST ZTEC SUD2 SUD3"
clnt=''
select
   when wordpos(lpar,'SUD2 SUDB SUDM',
     ' PROD SUDM SUDF SUD1 PACI SUD3') > 0 then  clnt='CAAGIS'
   when substr(lpar,1,2)='LI' then clnt='LCL'
   otherwise
end
temX=0 /* just open new one time */
ReportFlag=9 /* Report in LOGW - default is NO */
Call SetDb2ToStart
/* Lpar = dev ou prod ? */
lparprod=0; LparAutoSize=0
if wordpos(Lpar,LpDev) = 0 then LparProd=1
if wordpos(Lpar,LpAuto) > 0 ! clnt='CAAGIS' then LparAutoSize=1
hlq='SYSTMP.DBDC.DB2'
vsm='Y'    /*virtual storage monitoring Yes/No*/
 
/* Start processing unit for one SSID */
 
Start_Pgm:
 
 
/* init compteurs divers */
call init_var
 
/* START PROCESSING */
DO FOREVER
  /* read SMF record one by one   */
  "EXECIO 1 DISKR INP"
  IF RC > 0 THEN DO
            if rc =  2 then
               do
               /* SAY 'End of input SMF file rc=' RC*/
                  rcalloc = rc
               end
               else do
                  SAY 'Error while reading SMF file rc=' RC
                  rcalloc = 8
               end
            leave
  END
  PARSE PULL InpRec
  reci=reci+1
  Ofs = 1
  /* Decode SMF header */
  CALL DSNDQWST
  /* process only smf100 */
  IF (SM100RTY = 100    ) THEN
  DO
    if ope = 0 then call CrOutput /* do the first time only */
    if  sm100ssi <> ssid then iterate
    /*sauvegarde offset_self car on le reutilise */
    Ofs_selfdef= Ofs
    /* on va sur le self def. section pour aller vers prod section*/
    Ofs = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs - 3
    /* Process Product section*/
    CALL DSNDQWHS
    Ofs=Ofs_selfdef
    /* ifcid 1 must start the stats group */
    if   ifcid1_seen = 0 then
    do
      if   ifcid =  1 then ifcid1_seen = 1
      else iterate
      /* 'bypass' ifcid  */
    end
    recs=recs+1
    /* format date and  time when record is selected*/
    CALL GET_FMT_TIME
    /* record SMF records period   */
    if min_date > sm100dte     then min_date=sm100dte
    if Max_date < sm100dte     then Max_date=sm100dte
 
    Select
         When ifcid     = 1  Then do
                                      CALL DSNDQWS0
                                      Ofs = QWS00PSO - 3
                                  end
         When ifcid     = 2  Then do
                                      CALL DSNDQWS1
                                      Ofs = QWS10PSO - 3
                                  end
         When ifcid     = 225 Then do
                                      CALL QW0225
                                      Ofs = QWS10PSO - 3
                                  end
         Otherwise      do
                  /* add line here to avoid excessive displays */
                          if  ifcid = 202 then nop
                          else
                              if  ifcid = 230 then nop
                          else
                              say 'ifcid=' ifcid
                        end
    end   /* select */
 
    /*write report quand on a fait le tour des ifcids */
    if ifcid = 1 & recs > 1 then
       do
          call ifcid_diff
          /* on bypass le 1er record qui comprend les totaux*/
          if reco > 0 then Call write_report
          else reco = 1
       end
    else
    do
         if ifcid = 1 & recs = 1 then
         do
              Old_Mstrtcb =       Mstrtcb
              Old_MstrSrb =       MstrSrb
              Old_MstrpSRB=       MstrpSRB
              Old_MstrpSRB_Ziip = MstrpSRB_Ziip
              Old_dbm1Tcb =       dbm1Tcb
              Old_dbm1srb =       dbm1srb
              Old_dbm1pSRB=       dbm1pSRB
              Old_dbm1pSRB_Ziip = dbm1pSRB_Ziip
              Old_irlmTcb =       irlmTcb
              Old_irlmsrb =       irlmsrb
              Old_irlmpSRB=       irlmpSRB
              Old_irlmpSRB_Ziip = irlmpSRB_Ziip
              Old_distTcb =       distTcb
              Old_distsrb =       distsrb
              Old_distpSRB=       distpSRB
              Old_distpSRB_Ziip = distpSRB_Ziip
         end
    end
  END /*    IF SM100RTY = 100  */
END /* END DO FOREVER */
/* flush pending report (only at eof ) */
RFlush=1
if recs > 0 then
do
    call write_summary
    "EXECIO 0 DISKW OUFL ( FINIS"
    rcwrite = rc
    if rcwrite<> 0 then Do
       say "**********************************************"
       say "   Error writting OUFL file: " rcwrite
       say "   Abnormal end   "
       say "**********************************************"
       Exit 8
    end
    "EXECIO 0 DISKR INP (STEM INL. FINIS"
    /* Free REPORTS dataset */
    "FREE DD(OUFL)"
 
    call DisplayHighRandWk /* display High Random in WK */
    call DisplayPref /* Display Prefetch Quantity found */
    call DisplayDynStats /* Display Dynamic Stats */
end
 
/*-------------------------------------------------*/
/* F20 End of program display counters and figures */
/*-------------------------------------------------*/
call DisplayVStor
/* Report Max IO observed */
ReportFlag=1
MsgType='END'
rec.1= ''
call LOGW
ReportFlag=9
rec.1= 'Input records =' reci
call LOGW
ReportFlag=9
if recs<10 then say 'Input SMF file not relevant for this subsys !!!'
rec.1= 'Selected records =' recs
call LOGW
ReportFlag=9
rec.1=  'Output records=' reco
call LOGW
ReportFlag=9
rec.1= 'SMF period : ' min_date "/" Max_date MinTime  "/" Run_fmt_time
call LOGW
if reco > 0 & MaxReads > 60000 then do
  ReportFlag=1
  rec.1=lpar ssid 'Max IO/s =' format(MaxReads/60,6,0) ,
     TranslateBP(MaxReadsBP),
     'Getp/s' format(MaxReadsGP/60,10,0) 'at 'MaxReadsHr
  call logw
end
/*
if lpar = 'SUD2' then
         call SUD2_report_bp_usage
*/
/* externalise all messages */
call FlushLog
/* Close and Deallocate output dataset */
"EXECIO 0 DISKW OUFw  (FINIS"
"FREE DD(OUFW)"
"EXECIO 0 DISKW OUFws (FINIS"
"FREE DD(OUFWs)"
if lpar = 'IPO4' then
   do
         /* process DSNI now */
         if ssid = 'DSNI' then /* avoid forever loop */
         do
              say 'End processing for IPO4'
         end
         else
         do
              ssid = 'DSNI'
              call raz_data
              signal start_pgm
         end
   end
 
if lpar = 'SUD2' then
   do
         if ssid = 'DBAP' then
         do
              ssid = 'DB2A'
              call raz_data
              signal start_pgm
         end
         if ssid = 'DB2A' then
         do
              ssid = 'DB2C'
              call raz_data
              signal start_pgm
         end
         if ssid = 'DB2C' then
         do
              ssid = 'DB2D'
              call raz_data
              signal start_pgm
         end
         if ssid = 'DB2D' then
         do
              ssid = 'DB2G'
              call raz_data
              signal start_pgm
         end
         if ssid = 'DB2G' then
         do
              ssid = 'DB2I'
              call raz_data
              signal start_pgm
         end
         if ssid = 'DB2I' then
         do
              ssid = 'DB2P'
              call raz_data
              signal start_pgm
         end
         if ssid = 'DB2P' then
         do
              ssid = 'DB2R'
              call raz_data
              signal start_pgm
         end
         if ssid = 'DB2R' then
         do
              ssid = 'DFEI'
              call raz_data
              signal start_pgm
         end
         if ssid = 'DFEI' then
         do
              ssid = 'DFLI'
              call raz_data
              signal start_pgm
         end
         if ssid = 'DFLI' then
         do
              ssid = 'DPEI'
              call raz_data
              signal start_pgm
         end
         if ssid = 'DPEI' then
         do
              ssid = 'DPLI'
              call raz_data
              signal start_pgm
         end
         if ssid = 'DPLI' then
         do
              ssid = 'DQE3'
              call raz_data
              signal start_pgm
         end
         if ssid = 'DQE3' then
         do
              ssid = 'DRC2'
              call raz_data
              signal start_pgm
         end
         if ssid = 'DRC2' then
         do
              say 'All DB2 of SUD2 processed - Ending'
         end
   end
 
if lpar = 'PROD' then
   do
         if ssid = 'DB2A' then
         do
              ssid = 'DB2C'
              call raz_data
              signal start_pgm
         end
         if ssid = 'DB2C' then
         do
              say 'All DB2 of PROD processed - Ending'
         end
   end
 
if lpar = 'SUDB' then
   do
         if ssid = 'DB2I' then
         do
              ssid = 'DB2V'
              call raz_data
              signal start_pgm
         end
         if ssid = 'DB2V' then
         do
              say 'All DB2 of SUDB processed - Ending'
         end
   end
 
if lpar = 'SUDF' then
   do
         if ssid = 'DB2Q' then
         do
              ssid = 'DB2G'
              call raz_data
              signal start_pgm
         end
         if ssid = 'DB2G' then
         do
              ssid = 'DPD3'
              call raz_data
              signal start_pgm
         end
         if ssid = 'DPD3' then
         do
              ssid = 'DPE3'
              call raz_data
              signal start_pgm
         end
         if ssid = 'DPE3' then
         do
              say 'All DB2 of SUDF processed - Ending'
         end
   end
 
if lpar = 'SUDM' then
   do
         if ssid = 'DBPR' then
         do
              ssid = 'DBAP'
              call raz_data
              signal start_pgm
         end
         if ssid = 'DBAP' then
         do
              say 'All DB2 of SUDM processed - Ending'
         end
   end
if lpar = 'OSET' then
   do
         if ssid = 'DB2T' then
         do
              ssid = 'D2FT'
              call raz_data
              signal start_pgm
         end
         if ssid = 'D2FT' then
         do
              ssid = 'D2FK'
              call raz_data
              signal start_pgm
         end
         if ssid = 'D2FK' then
         do
              ssid = 'D2GT'
              call raz_data
              signal start_pgm
         end
         if ssid = 'D2GT' then
         do
              ssid = 'D2LT'
              call raz_data
              signal start_pgm
         end
         if ssid = 'D2GT' then
         do
              ssid = 'D2LT'
              call raz_data
              signal start_pgm
         end
         if ssid = 'D2LT' then
         do
              ssid = 'D2JK'
              call raz_data
              signal start_pgm
         end
         if ssid = 'DJKT' then
         do
              ssid = 'D2GK'
              call raz_data
              signal start_pgm
         end
         if ssid = 'D2GK' then
         do
              ssid = 'D2LK'
              call raz_data
              signal start_pgm
         end
         if ssid = 'D2LK' then
         do
              say 'All DB2 of OSET processed - Ending'
         end
   end
if lpar = 'OSJB' then
   do
         if ssid = 'D2GH' then
         do
              ssid = 'D2JC'
              call raz_data
              signal start_pgm
         end
         if ssid = 'D2JC' then
         do
              ssid = 'D2FH'
              call raz_data
              signal start_pgm
         end
         if ssid = 'D2FH' then
         do
              ssid = 'D2JH'
              call raz_data
              signal start_pgm
         end
         if ssid = 'D2JH' then
         do
              ssid = 'D2LH'
              call raz_data
              signal start_pgm
         end
         if ssid = 'D2LH' then
         do
              say 'All DB2 of OSJB processed - Ending'
         end
   end
 
if lpar = 'ZPR1' then
   do
         /* process DSNH now */
         if ssid = 'DB2E' then /* avoid forever loop */
         do
              ssid = 'DB2H'
              call raz_data
              signal start_pgm
         end
         else
         do
              if ssid = 'DB2H' then
              do
                   ssid = 'DB2I'
                   call raz_data
                   signal start_pgm
              end
              else
              do
                   /* je suis la parce que ssid = 'DB2I'*/
                   say 'Tous les DB2 de ZPR1 sont traités'
              end
         end
   end
if lpar = 'ZDV1' then
   do
         /* process DSNH now */
         if ssid = 'DB2J' then /* avoid forever loop */
         do
              ssid = 'DB2R'
              call raz_data
              signal start_pgm
         end
         else
         do
              if ssid = 'DB2R' then
              do
                   ssid = 'DB2T'
                   call raz_data
                   signal start_pgm
              end
              else
                   /* je suis la parce que ssid = 'DB2I'*/
                   say 'Tous les DB2 de ZDV1 sont traités'
         end
   end
if lpar = 'DD20' then
   do
         /* process DSNH now */
         if ssid = 'DB2C' then /* avoid forever loop */
         do
              ssid = 'DB2Z'
              call raz_data
              signal start_pgm
         end
         else
              do
                   /* je suis la parce que ssid = 'DB2I'*/
                   say 'Tous les DB2 de DD20 sont traités'
              end
   end
if lpar = 'IPO1' then
   do
         if ssid = 'DSNA' then /* avoid forever loop */
         do
              ssid = 'DSN1'
              call raz_data
              signal start_pgm
         end
         else
              say 'Tous les DB2 de IPO1 sont traités'
   end
if lpar = 'IPO3' then
   do
         if ssid = 'DSN3' then /* avoid forever loop */
         do
              ssid = 'DSND'
              call raz_data
              signal start_pgm
         end
         else do
              if ssid = 'DSND' then
              do
                   ssid = 'DSN4'
                   call raz_data
                   signal start_pgm
              end
              else
                   say 'Tous les DB2 de IPO3 sont traités'
         end
   end
if lpar = 'DEV'  then do
       select
            when ssid = 'DBD1' then do
              ssid = 'DBD2'
              call raz_data
              signal start_pgm
            end
            when ssid = 'DBST' then do
              ssid = 'DBTB'
              call raz_data
              signal start_pgm
            end
            when ssid  = 'DBD2' then do
              ssid = 'DB2L'
              call raz_data
              signal start_pgm
            end
            when ssid  = 'DB2L' then do
              ssid = 'DB2P'
              call raz_data
              signal start_pgm
            end
            when ssid  = 'DB2P' then
                     say 'Tous les DB2 de DEV sont traités'
            otherwise
       end
end /* end DEV */
if lpar = 'I083'  then do
       select
            when ssid = 'DBST' then do
              ssid = 'DBTB'
              call raz_data
              signal start_pgm
            end
            when ssid  = 'DBTB' then
                     say 'Tous les DB2 de I083 sont traités'
            otherwise
       end
end /* end DEV */
"FREE DD(INP)"
if lpar = 'SUD2' then
do
  "EXECIO 0 DISKW OUFs2 (FINIS"
  "FREE DD(OUFs2)"
end
Say 'End of program'
EXIT rcalloc
 
/*---------------------------------------*/
/* End of program body- Routines section */
/*---------------------------------------*/
 
/* MAP SELF-DEFINING SECT IFCID 001 LG = 112 */
DSNDQWS0:
  /*  OFFSET TO THE PRODUCT SECTION */
  QWS00PSO = C2D(SUBSTR(InpRec,Ofs,4))
  Ofs = Ofs + 4
  QWS00PSL = C2D(SUBSTR(InpRec,Ofs,2))
  Ofs = Ofs + 2
  QWS00PSN = C2D(SUBSTR(InpRec,Ofs,2))
  Ofs = Ofs + 2
  /*  OFFSET TO THE DATA SECTION MAPPED BY DSNDQWSA CPU TIME */
  QWS00R1O = C2D(SUBSTR(InpRec,Ofs,4))
  Ofs = Ofs + 4
  QWS00R1L =  C2D(SUBSTR(InpRec,Ofs,2))
  Ofs = Ofs + 2
  QWS00R1N =  C2D(SUBSTR(InpRec,Ofs,2))
  Ofs = Ofs + 2
  save_Ofs = Ofs
  /* controle de coherence */
  if  QWS00R1N  > 4 then
      do
           say 'QWS00R1N is not equal to 4, abnormal end ' QWS00R1N
           exit 8
      end
  /* Load offset to DSNDQWSA section - decode DB2 stc cpu section */
  Ofs= QWS00R1O - 3
  /* init DIST pas toujours pr§sent */
  DISTTcb      = 0
  DISTSrb      = 0
  DISTpSRB     = 0
  DISTpSRB_Ziip= 0
  i=0
  do until i= QWS00R1N
         i = i+ 1
         call DSNDQWSA
  end
 
  /*restore offset */
  Ofs = save_Ofs
 
  /*  OFFSET TO THE DATA SECTION MAPPED BY DSNDQWSB STATS COUNTERS*/
  /*  INSTRUMENTATION STATISTICS DATA ABOUT OUTPUT DESTINATION */
  QWS00R2O = C2D(SUBSTR(InpRec,Ofs,4))
  Ofs = Ofs + 8
  /*  OFFSET TO THE DATA SECTION MAPPED BY DSNDQWSC */
  /*  IFCIDS RECORDED TO STATISTICS */
  QWS00R3O = C2D(SUBSTR(InpRec,Ofs,4))
  Ofs = Ofs + 8
  /*  OFFSET TO THE DATA SECTION MAPPED BY DSNDQ3ST */
  /*  Subsytem services fields */
  /*  SIGNON, IDEN, COMMITS, ABORTS ...*/
  QWS00R4O = C2D(SUBSTR(InpRec,Ofs,4))
  Ofs = Ofs + 8
  save_Ofs = Ofs
  Ofs = QWS00R4O - 3
  call DSNDQ3ST
  Ofs = save_Ofs
  /*  OFFSET TO THE DATA SECTION MAPPED BY DSNDQ9ST QWS00R5O*/
  Ofs = Ofs + 8
  /*  OFFSET TO THE DATA SECTION MAPPED BY DSNDQWSD */
  /*  CHECKPOINT INFO, IFI COUNT    ...*/
  QWS00R6O = C2D(SUBSTR(InpRec,Ofs,4))
  Ofs = Ofs + 8
  save_Ofs = Ofs
  Ofs = QWS00R6O - 3
  call DSNDQWSD
  Ofs = save_Ofs
  /*  OFFSET TO THE DATA SECTION MAPPED BY DSNDQVLS */
  /*  LATCH COUNTS       QWS00R7O   ...*/
  Ofs = Ofs + 8
  /*  OFFSET TO THE DATA SECTION MAPPED BY DSNDQVAS */
  /*  ASMC STATS NBRE DE SUSPENSIONS ..QWS00R8O */
  Ofs = Ofs + 8
  /*  OFFSET TO THE DATA SECTION MAPPED BY DSNDQSST */
  /*  STORAGE MANAGER QWS00R9O */
  Ofs = Ofs + 8
  /*  OFFSET TO THE DATA SECTION MAPPED BY DSNDQLST */
  /*  DDF STATS BY LOCATION QWS00RAO*/
  Ofs = Ofs + 8
  /*  OFFSET TO THE DATA SECTION MAPPED BY DSNDQJST */
  /*  LOG MANAGER   QWS00RBO*/
  QWS00RBO = C2D(SUBSTR(InpRec,Ofs,4))
  Ofs = Ofs + 8
  save_Ofs = Ofs
  Ofs = QWS00RBO - 3
  call DSNDQJST
  Ofs = save_Ofs
  /*  OFFSET TO THE DATA SECTION MAPPED BY DSNDQDST */
  /*  DBAT STATS            */
  QWS00RCO = C2D(SUBSTR(InpRec,Ofs,4))
  Ofs = Ofs + 8
  save_Ofs = Ofs
  Ofs = QWS00RCO - 3
  call DSNDQDST
  Ofs = save_Ofs
  /*  OFFSET TO THE DATA SECTION MAPPED BY DSNDQWOS */
  /*  ZOS STATS   QWS00RDO  */
  Ofs = Ofs + 8
  /* LG = 112 = 14 SECTIONS * 8 */
 
  Return
 
DSNDQXST:
    /*************************************************/
    /*  RDS STATISTICS BLOCK  DSNDQXST               */
    /*************************************************/
    /* Fields from IFCID002 : cumulative */
    /* calculate difference between interval */
    Ofs=Ofs+4
    /* eye catcher */
    eyec     = SUBSTR(InpRec,Ofs,4)
    if ( eyec     <> 'QXST' ) then
                  do
                      eyec = SUBSTR(InpRec,1,100)
                      say 'DSNDQXST eye catcher not met, error'
                      exit(8)
                  end
    Ofs     =  Ofs + 300
    /*---*/
    /*#RID List failed No storage */
    QXNSMIAP = C2D(SUBSTR(InpRec,Ofs,8))
    Ofs     =  Ofs + 8
    /*# Failed Limit exceeded */
    QXMRMIAP = C2D(SUBSTR(InpRec,Ofs,8))
    Ofs     =  Ofs + 248
    /*# Short Prepare */
    QXSTFND  = C2D(SUBSTR(InpRec,Ofs,8))
    Ofs     =  Ofs + 8
    /*# Full Prepare */
    QXSTNFND  = C2D(SUBSTR(InpRec,Ofs,8))
    Ofs     =  Ofs + 8
    /*# Implicit Prepare = FULL prepare */
    QXSTIPRP  = C2D(SUBSTR(InpRec,Ofs,8))
    Ofs     =  Ofs + 8
    /*# Avoided  Prepare */
    QXSTNPRP  = C2D(SUBSTR(InpRec,Ofs,8))
    Ofs     =  Ofs + 8
    /*# Stmt discarded - MAXKEEPD */
    QXSTDEXP  = C2D(SUBSTR(InpRec,Ofs,8))
    Ofs     =  Ofs + 496
    /* (...) */
    /*# RID list Overflowed to Workfile No storage in RIDPOOL */
    QXWFRIDS = C2D(SUBSTR(InpRec,Ofs,8))
    Ofs     =  Ofs + 8
    /*# RID list overflowed to wKk Limit Exceeded   */
    QXWFRIDT = C2D(SUBSTR(InpRec,Ofs,8))
    Ofs     =  Ofs + 8
    /*# RID list append for a hybrid join was interrupt No Storage*/
    QXHJINCS = C2D(SUBSTR(InpRec,Ofs,8))
    Ofs     =  Ofs + 8
    /*# RID list append for a hybrid join Limit exceeded*/
    QXHJINCT = C2D(SUBSTR(InpRec,Ofs,8))
    Ofs     =  Ofs + 136
    /*# IWF not created for sparse index NO storage */
    QXSISTOR = C2D(SUBSTR(InpRec,Ofs,8))
    if  QWHSRN < 'C1' then do /*v11 */
      QXRWSINSRTDAlg1=0
      QXRWSINSRTDAlg2=0
      QXRFMIAP=0
      return
    end
    Ofs     =  Ofs + 32
    /*# Insert Algorithm 1 */
    QXRWSINSRTDAlg1=C2D(SUBSTR(InpRec,Ofs,8))
    Ofs     =  Ofs + 8
    /*# Insert Algorithm 2 */
    QXRWSINSRTDAlg2=C2D(SUBSTR(InpRec,Ofs,8))
    Ofs     =  Ofs + 120
    /*# MIAP not used RID List could not be used */
    QXRFMIAP=C2D(SUBSTR(InpRec,Ofs,8))
return
 
QW0225:
numeric digits 15
       Ofs_save=Ofs /* sauvergarde Offset debut data section*/
       /* offset= offset of self definition section*/
       /* offset= offset + 8 : bypass pointer to Product  Section*/
       /* offset_d = offset de la data section */
       Ofs=Ofs+4+2+2 /*pointer to data section 1*/
       /*take the contents pointed by the offset */
       Ofs_d= C2D(SUBSTR(InpRec,Ofs,4))
 
       /* -------------- */
       /* data section 1 */
       /* -------------- */
       /* Data section 1 = 2 parts, DBM1 and DIST */
 
       /* offset to dbm1 */
       Ofs_d=Ofs_d -3
       Ofs=Ofs+4
 
    /* say 'offs sect1'  offset_d */
       /* len of data section 1 : it will be repeated :*/
       /* One for DBM1 and one for DIST */
       len=      C2D(SUBSTR(InpRec,Ofs,2))
       Ofs=Ofs+2
       rep=      C2D(SUBSTR(InpRec,Ofs,2))
       Ofs=Ofs+2
    /* say 'len' len
       say 'rep' rep */
 
       /* offset to DIST */
       Ofs_d2=Ofs_d+len
 
    /* say 'offs sect2'  offset_d2 */
 
       QW0225AN =(SUBSTR(InpRec,Ofs_d,4))
       if  QW0225AN <> 'DBM1' then
       do
           say 'W0225 - Mapping error'
           exit 8
       end
    /***********************************/
    /* Processing DBM1 storage section */
    /***********************************/
       if  QW0225AN =  'DBM1' & vsm ='Y'  then
       do
           Ofs_d=Ofs_d+4
           /* extended region size */
           QW0225RG = C2D(SUBSTR(InpRec,Ofs_d,4))
           Ofs_d=Ofs_d+12
           QW0225EL = C2D(SUBSTR(InpRec,Ofs_d,4))
           Ofs_d=Ofs_d+4
           QW0225EH = C2D(SUBSTR(InpRec,Ofs_d,4))
           Ofs_d=Ofs_d+12
           /* storage reserved fo must complete */
           /* before V10 depends on CTHREAD and MaxDBAT zparm*/
           QW0225CR = C2D(SUBSTR(InpRec,Ofs_d,4))
           Ofs_d=Ofs_d+4
           /* storage reserved for open/close datasets */
           /* depends on DSMax value */
           QW0225MV = C2D(SUBSTR(InpRec,Ofs_d,4))
           Ofs_d=Ofs_d+4
           QW0225SO = C2D(SUBSTR(InpRec,Ofs_d,4))
           Ofs_d=Ofs_d+4
           QW0225GS = C2D(SUBSTR(InpRec,Ofs_d,4))
           Ofs_d=Ofs_d+8
           QW0225VR = C2D(SUBSTR(InpRec,Ofs_d,4))
           Ofs_d=Ofs_d+4
           QW0225FX = C2D(SUBSTR(InpRec,Ofs_d,4))
           Ofs_d=Ofs_d+4
           QW0225GM = C2D(SUBSTR(InpRec,Ofs_d,4))
           Ofs_d=Ofs_d+4
           /* 31 bit storage available */
           QW0225AV = C2D(SUBSTR(InpRec,Ofs_d,4))
           Ofs_d=Ofs_d+40
           QW0225RL_dbm1 = C2D(SUBSTR(InpRec,Ofs_d,8))
           /* 225RL = Real stor. frame used by the Address Space*/
           /*    this includes bufferpools storage qw0225bb */
           Ofs_d=Ofs_d+8
           QW0225AX_dbm1 = C2D(SUBSTR(InpRec,Ofs_d,8))
           Ofs_d=Ofs_d+8
           /* QW0225HVPagesInReal 64 bits private Real */
           QW0225HVPagesInReal =  C2D(SUBSTR(InpRec,Ofs_d,8))
           Ofs_d=Ofs_d+8
           /* QW0225HVAuxSlots    64 bits private Aux */
           QW0225HVAuxSlots =  C2D(SUBSTR(InpRec,Ofs_d,8))
           Ofs_d=Ofs_d+24
      /*   /* QW0225HWM           64 bits private Real*/
           QW0225HVGPagesInReal =  C2D(SUBSTR(InpRec,Ofs_d,8))
           Ofs_d=Ofs_d+8
           /* QW0225HWM           64 bits private Aux */
           QW0225HVGAuxSlots=  C2D(SUBSTR(InpRec,Ofs_d,8))
           Ofs_d=Ofs_d+8 */
           /* QW0225PagesInReal 64 bits private Real without BP */
           QW0225PriStg_Real=  C2D(SUBSTR(InpRec,Ofs_d,8))
           Ofs_d=Ofs_d+8
           /* QW0225PagesInAux  64 bits private Aux  without BP */
           QW0225PriStg_Aux=  C2D(SUBSTR(InpRec,Ofs_d,8))
           Ofs_d=Ofs_d+8
           TotalRealUsedBP = QW0225HVPagesInReal - QW0225PriStg_Real
           TotalAuxUsedBP = QW0225HVAuxSlots    - QW0225PriStg_Aux
       end  /* if  QW0225AN =  'DBM1' & vsm = 'Y' then */
 
       /* rep = 2 : there is 2 parts , DBM1 and DDF */
       if rep = 2 then
       do
          /* partie DIST */
          QW0225AN =(SUBSTR(InpRec,Ofs_d2,4))
          if  QW0225AN <> 'DIST'  then
          do
              say 'W0225 - Mapping error DIST not found'
              say 'InpRec' InpRec
              say 'Ofs'      Ofs_d2
              exit 8
          end
          if  QW0225AN =  'DIST' & vsm='Y' then
          do
              Ofs_d2=Ofs_d2+104
              QW0225RL_dist = C2D(SUBSTR(InpRec,Ofs_d2,8))
              Ofs_d2=Ofs_d2+8
              QW0225AX_dist = C2D(SUBSTR(InpRec,Ofs_d2,8))
          end  /* if  QW0225AN =  'DIST' & vsm = 'Y' then */
       end
       else /*if rep = 2 then*/
       do
              QW0225RL_dist = 0
              QW0225AX_dist = 0
       end
 
       /*pointer to data section 2*/
 
       Ofs_d= C2D(SUBSTR(InpRec,Ofs,4))
       Ofs_d=Ofs_d -3
 
 
       QW0225AT =C2D(SUBSTR(InpRec,Ofs_d,4))
       /* overflow protection 4294967295 = FFFFFFFFFFFF */
       if QW0225AT > 9999999 then QW0225AT = 0
       Ofs_d=Ofs_d+4 /*pointer on data section 2*/
       QW0225DB =C2D(SUBSTR(InpRec,Ofs_d,4))
 
       if (QW0225AT + qw0225DB) < MinThdSee then
          do
              MinThdSee = QW0225AT + qw0225DB
              MinThdSeeTime= run_fmt_time
              MinThdSeeDate= sm100dte
          end
       if (QW0225AT + qw0225DB) > MaxThdSee then
          do
              MaxThdSee = QW0225AT + qw0225DB
              MaxThdSeeTime= run_fmt_time
              MaxThdSeeDate= sm100dte
          end
       /* say 'threads allied=' QW0225AT
          say 'threads dbat=' QW0225DB      */
 
       /*pointer to data section 3 : Shared and Common Storage */
       Ofs=Ofs+8 /* go to next pointer*/
       if vsm = 'Y' then
       do
          /* load address of section 3*/
          Ofs_d= C2D(SUBSTR(InpRec,Ofs,4))
          Ofs_d=Ofs_d -3
 
          Ofs_d=Ofs_d +136
          QW0225SHRINREAL  =C2D(SUBSTR(InpRec,Ofs_d,8))
          Ofs_d=Ofs_d + 32
          QW0225ShrStg_Real=C2D(SUBSTR(InpRec,Ofs_d,8))
          Ofs_d=Ofs_d + 8
          QW0225ShrStg_Aux =C2D(SUBSTR(InpRec,Ofs_d,8))
          Ofs_d=Ofs_d + 8
          QW0225ShrStkStg_Real=C2D(SUBSTR(InpRec,Ofs_d,8))
          Ofs_d=Ofs_d + 8
          QW0225ShrStkStg_Aux =C2D(SUBSTR(InpRec,Ofs_d,8))
          Ofs_d=Ofs_d + 8
          QW0225ComStg_Real=C2D(SUBSTR(InpRec,Ofs_d,8))
          Ofs_d=Ofs_d + 8
          QW0225ComStg_Aux =C2D(SUBSTR(InpRec,Ofs_d,8))
 
      /*  TotalRealUsedByLPAR meaning not clear - value does not  */
      /*     corresponds with others z/OS monitoring tool         */
      /*  TotalRealUsedByLPAR= qw0225rl_dbm1+ qw0225rl_dist +,    */
      /*       QW0225ComStg_Real + -- in redbook but no where else*/
      /*                           QW0225SHRINREAL                */
          /* QW0225ComStg_Real Real in use 64 bit shared */
          /* QW0225SHRINREAL   Real in use 64 bit common */
 
      /*  if MaxRealLPAR  <  TotalRealUsedByLPAR then */
      /*       do                                     */
      /*           MaxRealLPAR = TotalRealUsedByLPAR  */
      /*           time_MaxRealLPAR = run_fmt_time    */
      /*       end                                    */
 
          Ofs_d=Ofs_d + 40
          QW0225_REALAVAIL =C2D(SUBSTR(InpRec,Ofs_d,4))
          if MinQW0225_REALAVAIL > QW0225_REALAVAIL then
               do
                   MinQW0225_REALAVAIL = QW0225_REALAVAIL
                   time_MinQW0225_REALAVAIL = run_fmt_time
                   date_MinQW0225_REALAVAIL = sm100dte
               end
 
          Ofs_d=Ofs_d + 40
          QW0225_LMWrite_Real=C2D(SUBSTR(InpRec,Ofs_d,4))
          Ofs_d=Ofs_d + 4
          QW0225_LMWrite_Aux =C2D(SUBSTR(InpRec,Ofs_d,4))
          Ofs_d=Ofs_d + 4
          QW0225_LMCtrl_Real =C2D(SUBSTR(InpRec,Ofs_d,4))
          Ofs_d=Ofs_d + 4
          QW0225_LMCtrl_Aux  =C2D(SUBSTR(InpRec,Ofs_d,4))
         /* formula from    Redbook V11 Monitoring */
         /* table 13-1 13-2                        */
         /* And Memu Excel */
          TotalRealUsedByDB2 = qw0225rl_dbm1+ qw0225rl_Dist +,
                 QW0225ShrStg_Real + QW0225ShrStkStg_Real +,
                 QW0225ComStg_Real + QW0225_LMWrite_Real +,
                 QW0225_LMCtrl_Real
         TotalAuxlUsedByDB2 = qw0225ax_dbm1+ qw0225ax_Dist +,
               QW0225ComStg_Aux  + QW0225ShrStg_Aux  +  ,
               QW0225ShrStkStg_Aux + QW0225_LMCtrl_Aux +,
               QW0225_LMWrite_Aux
         If MaxDB2AuxUse < TotalAuxlUsedByDB2 then
                          do
                             MaxDB2AuxUse=TotalAuxlUsedByDB2
                             timeMaxDB2AuxUse=run_fmt_time
                             DateMaxDB2AuxUse=sm100dte
                          end
       end
 
       /*-------------------------*/
       /*pointer to data section 4*/
       /*-------------------------*/
       Ofs=Ofs+8
 
       /*-------------------------------------------------*/
       /*pointer to data section 5 : Pool storage details */
       /*-------------------------------------------------*/
       Ofs=Ofs+8
       if  vsm = 'Y' then
       do
         Ofs_d= C2D(SUBSTR(InpRec,Ofs,4))
         Ofs_d= Ofs_d+4
       /* QW0225AS Total system agent storage 31 bits*/
         QW0225AS =C2D(SUBSTR(InpRec,Ofs_d,4))
       /* QW0225BB Total buffer manager storage blocks */
 
       /*-------------------------------*/
       /* Calculate Max threads allowed */
       /*-------------------------------*/
 
         /*Ici on a eu tous les infos on peut donc calculer le */
         /* nombre de threads Max theoriques*/
         /* Source : IBM formula  */
         /* (Redbook V11 subsystem monitoring Chap. Virtual Stor*/
 
         /*    Thread footprint calculation : */
 
         /* Basic Storage Cushion */
         BC = QW0225CR + QW0225MV + QW0225SO
         /* Non DB2 storage, retains Max value for final calculation*/
         ND = QW0225EH-QW0225GM-QW0225GS-QW0225FX-QW0225VR
         /* Max Allowable storage */
         AS= QW0225RG-BC-ND
         /* Max Allowable storage for thread use*/
         TS = AS-(QW0225AS + QW0225FX + QW0225GM+ QW0225EL)
         /* Average thread footprint */
         if (QW0225AT + qdstcnat) = 0 then
            /* if threads in system = 0 then 1 */
            TF =  QW0225VR- QW0225AS + QW0225GS
         else
            TF = (QW0225VR-QW0225AS+QW0225GS)/(QW0225AT+qdstcnat)
 
         /* Max threads supported    */
         ThdComp =TS /TF     /* Original IBM formula */
  /* Theoric number of threads supported */
 
    allthreads=QDSTHWAT- QDSTMIN2+QW0225AT
    if  allthreads   > ThdComp   then
    Do
     ReportFlag=1
     MsgType='STO'
     rec.1= 'DBAT + AlliedThreads > Theoric Max Thread Number',
        'Time/Threads/ThdComp'
     call LOGW
     ReportFlag=1
     MsgType='STO'
     rec.1= run_fmt_time allthreads format(ThdComp,5,0)
     call LOGW
    end
/* ------------------------------------------------------------*/
         StorBefContract=qw0225AV-(qw0225cr+qw0225SO+qw0225MV)
         /* Storage contraction ?*/
         if qw0225AV <  qw0225cr then
                do
                    say ' Storage critical condition',
                        '@ ' run_fmt_time
                end
         else do
              if qw0225AV <  (qw0225cr+ qw0225SO+qw0225MV) then
                do
                    say ' Full system contraction should happen',
                        '@ ' run_fmt_time
                end
         end /* else */
 
         if ThdComp < MinThdComp then do
                                     MinThdComp =ThdComp
                                     MinThdCompTime=run_fmt_time
                                     MinThdCompDate=sm100dte
                                   end
         if ThdComp > MaxThdComp then do
                                     MaxThdComp =ThdComp
                                     MaxThdCompTime =run_fmt_time
                                     MaxThdCompDate =sm100dte
                                   end
 
         Real4K_dbm1=(QW0225RL_dbm1 *4096)/ 1048576    /*1MB*/
         Real4K_dist=(QW0225RL_dist *4096)/ 1048576    /*1MB*/
 
         If MinReal4K_dbm1 > Real4K_dbm1 then
                          do
                             MinReal4K_dbm1=Real4K_dbm1
                             time_MinReal4K_dbm1=run_fmt_time
                             Date_MinReal4K_dbm1=sm100dte
                          end
         If MaxReal4K_dbm1 < Real4K_dbm1 then
                          do
                             MaxReal4K_dbm1=Real4K_dbm1
                             time_MaxReal4K_dbm1=run_fmt_time
                             Date_MaxReal4K_dbm1=sm100dte
                          end
         If MinReal4K_dist > Real4K_dist then
                          do
                             MinReal4K_dist=Real4K_dist
                             time_MinReal4K_dist=run_fmt_time
                             Date_MinReal4K_dist=sm100dte
                          end
         If MaxReal4K_dist < Real4K_dist then
                          do
                             MaxReal4K_dist=Real4K_dist
                             time_MaxReal4K_dist=run_fmt_time
                             Date_MaxReal4K_dist=sm100dte
                          end
       end /* if vsm ... */
return
 
/***************************************************/
/* MAP SELF-DEFINING SECT IFCID 002 LG = 12X8 = 96 */
/***************************************************/
DSNDQWS1:
  /*  OFFSET TO THE PRODUCT SECTION */
  QWS10PSO = C2D(SUBSTR(InpRec,Ofs,4))
  Ofs = Ofs + 8
  /*  OFFSET TO THE DATA SECTION MAPPED BY DSNDQXST */
  /*  RDS stats block  QWS10R1O  */
  QWS10R1O = C2D(SUBSTR(InpRec,Ofs,4))
  Ofs = Ofs + 8
  if  QWS10R1O > 0 then
  do
    save_Ofs = Ofs
    Ofs = QWS10R1O - 3
    call DSNDQXST
    Ofs = save_Ofs
  end
  /*  OFFSET TO THE DATA SECTION MAPPED BY DSNDQTST */
  /*  nbre de bind, nbre de plan allocated succ ... */
  QWS10R2O = C2D(SUBSTR(InpRec,Ofs,4))
  Ofs = Ofs + 8
  if  QWS10R2O > 0 then
  do
    save_Ofs = Ofs
    Ofs = QWS10R2O - 3
    call DSNDQTST
    Ofs = save_Ofs
  end
  /*  OFFSET TO THE DATA SECTION MAPPED BY DSNDQBST */
  /*  Buffer manager stats                          */
  QWS10R3O = C2D(SUBSTR(InpRec,Ofs,4))
  Ofs = Ofs + 6
  QWS10r3N = C2D(SUBSTR(InpRec,Ofs,2))
  Ofs = Ofs + 2
  /* decode dsndqbst to have  buffer stats */
  if  QWS10R3O > 0 then
  do
      /* Init sum = figures by category for ALL BP */
      Sum_QBSTGET = 0 /* All getpages for all BP in this interval*/
      Sum_QBSTRIO = 0
      Sum_QBSTIMW = 0
      Sum_QBSTDSO = 0
      Sum_QBSTWIO = 0
      Sum_QBSTRPI = 0
      Sum_QBSTWPI = 0
      Sum_QBSTPIO = 0
      Sum_QBSTCIO = 0
      Sum_QBSTDIO = 0
      Sum_QBSTLIO = 0
      Sum_QBSTSIO = 0
 
      save_Ofs= Ofs
      Ofs=QWS10R3O - 3
      /*figures by bufferpool ID */
      /*figures for all subsys ID */
      m=0
      do until m= QWS10r3N
         m = m+ 1
         call dsndqbst
         Sum_QBSTGET = Sum_QBSTGET + QBSTGET
         Sum_QBSTRIO = Sum_QBSTRIO + QBSTRIO
         Sum_QBSTIMW = Sum_QBSTIMW + QBSTIMW
         Sum_QBSTDSO = Sum_QBSTDSO + QBSTDSO
         Sum_QBSTWIO = Sum_QBSTWIO + QBSTWIO
         Sum_QBSTRPI = Sum_QBSTRPI + QBSTRPI
         Sum_QBSTWPI = Sum_QBSTWPI + QBSTWPI
         Sum_QBSTPIO = Sum_QBSTPIO + QBSTPIO
         Sum_QBSTCIO = Sum_QBSTCIO + QBSTCIO
         Sum_QBSTDIO = Sum_QBSTDIO + QBSTDIO
         Sum_QBSTLIO = Sum_QBSTLIO + QBSTLIO
         Sum_QBSTSIO = Sum_QBSTSIO + QBSTSIO
      end
      Ofs=save_Ofs
  end
 
  /*  OFFSET TO THE DATA SECTION MAPPED BY DSNDQIST */
  /*  Data   manager stats                          */
  QWS10R4O = C2D(SUBSTR(InpRec,Ofs,4))
  Ofs = Ofs + 8
  /* decode dsnDQIST to have to Data manager stats */
  if QWS10R4O > 0 then do
     save_Ofs= Ofs
     Ofs=QWS10R4O - 3
     call dsndqist
     Ofs=save_Ofs
  end
  /*  OFFSET TO THE DATA SECTION MAPPED BY DSNDQTXA */
  /*  Lock   manager stats                          */
  Ofs = Ofs + 8
  /*  OFFSET TO THE DATA SECTION MAPPED BY DSNDQISE */
  /*  EDM Pool stats                                */
  QWS10R6O = C2D(SUBSTR(InpRec,Ofs,4))
  Ofs = Ofs + 4
  QWS10R6L = C2D(SUBSTR(InpRec,Ofs,2))
  Ofs = Ofs + 2
  QWS10R6N = C2D(SUBSTR(InpRec,Ofs,2))
  Ofs = Ofs + 2
  if QWS10R6O > 0 then
    do
      save_Ofs= Ofs
      Ofs=QWS10R6O - 3
      CALL DSNDQISE
      Ofs = save_Ofs
    end
  /*  OFFSET TO THE DATA SECTION MAPPED BY DSNDQBGL */
  /*  Group BufferPool stats                        */
  QWS10R7O = C2D(SUBSTR(InpRec,Ofs,4))
  Ofs = Ofs + 6
  QWS10R7N = C2D(SUBSTR(InpRec,Ofs,2))
  Ofs = Ofs + 2
  if  QWS10R7O > 0 then
  do
       save_Ofs = Ofs
       Ofs = QWS10R7O - 3
       m=0
       do until m= QWS10r7N
           m = m+ 1
           call DSNDQBGL
       end /* do until */
       Ofs = save_Ofs
  end  /* QWS10R7O > 0  */
  /*  (...)                                         */
  /*  Others sections - Check Rex100                */
  return
 
dsndqist:
    numeric digits 15
    Ofs     =  Ofs +4
    /* Fields of these macro seems to be all cumulative */
    /* calculate difference between interval */
    /* check QIEYE */
      if  SUBSTR(InpRec,Ofs,4) <> 'QIST' then
        do
              say 'Mapping error QIST eye catcher not found'
              exit(8)
        end
 
    Ofs = Ofs + 4
    /* RID Term RDS Limit */
    /* RID Term DM  Limit */
    Ofs = Ofs + 24
    /* not optimal column proc Invalid Sproc */
    QISTCOLS = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 40
    /* 32KB Wrkfile used instead of 4KB */
    QISTWFP1 = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
    /* 4 KB Wrkfile used instead of 32 KB */
    QISTWFP2 = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 28
    /* hwm storage used by workfiles in KB */
    Ofs = Ofs + 8
    /* Current all workfile usage in KB : DGTT and Sort */
    Ofs = Ofs + 8
    /* Current 4K wrkfile storage usage in KB*/
    QISTW4K  = C2D(SUBSTR(InpRec,Ofs,8))
    if QISTW4K > Max_QISTW4K then
          Max_QISTW4K = QISTW4K
    Ofs = Ofs + 8
    /* Current 32K wrkfile storage usage in KB*/
    QISTW32K = C2D(SUBSTR(InpRec,Ofs,8))
    if QISTW32K > Max_QISTW32K then
          Max_QISTW32K = QISTW32K
    /* Nb DM in memory   wrkfiles active currently */
    /* Space DM in memory active currently in KB*/
    /* Nb SRT in memory   wrkfiles active currently */
    /* Space SRT in memory active currently in bytes */
    /* Current RID blocks overflowed (stored) in wrkfiles*/
    /* Current NON Sort related workfiles active */
    /* Physical  workfiles created */
    Ofs = Ofs + 128
    /* HWM wkfile storage used by an agent */
    QISTAMXU =  C2D(SUBSTR(InpRec,Ofs,8))
    /* Current storage configured for wkfiles*/
    /* Current DGTT  configured for wkfile KB*/
    /* Current DGTT  used  KB*/
    Ofs = Ofs + 32
    /* HWM     DGTT  used  KB*/
    QISTDGTTMXU = C2D(SUBSTR(InpRec,Ofs,8))
    /* Current others  configured for wkfile KB*/
    /* Current others used  KB*/
    Ofs = Ofs + 24
    /* HWM    others used KB*/
    QISTWFMXU = C2D(SUBSTR(InpRec,Ofs,8))
    return
/* MAP STANDARD HEADER PRODUCT SECTION */
DSNDQWHS:
  Ofs = Ofs + 4
  /* QWHSIID DS XL2 IFCID */
  IFCID = C2D(SUBSTR(InpRec,Ofs,2))
  Ofs = Ofs + 3
/* optimisation pour ne pas recalculer */
/*if  QWHSRN > ' ' then
      return */
  /* release number */
  QWHSRN = C2X(SUBSTR(InpRec,Ofs,1))
  /* TOTAL LENGTH = 76 */
  RETURN
 
/* STATISTICS CPU TIME MAPPING MACRO LG = 52*4*/
DSNDQWSA:
    numeric digits 15
    QWSAPROC =(SUBSTR(InpRec,Ofs,4))
    /* tempo erreur possible socle 48 */
    if wordpos(QWSAPROC,'MSTR DBM1 IRLM DIST')=0 then
    do
      Ofs = Ofs + 8
      signal DSNDQWSA
    end
    Ofs = Ofs + 4
    /*CONVERT INTO HEX VALUE*/
    QWSAEJST = C2X(SUBSTR(InpRec,Ofs,8))
    /*ELIMINATE 1.5 BYTES */
    QWSAEJST = X2D(SUBSTR(QWSAEJST,1,13))
    QWSAEJST = QWSAEJST/1000000
    Ofs = Ofs + 8
 
    QWSASRBT = C2X(SUBSTR(InpRec,Ofs,8))
    QWSASRBT = X2D(SUBSTR(QWSASRBT,1,13))
    QWSASRBT = QWSASRBT/1000000
    Ofs = Ofs + 16
 
    QWSAPSRB = C2X(SUBSTR(InpRec,Ofs,8))
    QWSAPSRB = X2D(SUBSTR(QWSAPSRB,1,13))
    QWSAPSRB = QWSAPSRB/1000000
    Ofs = Ofs + 8
 
    QWSAPSRB_Ziip = C2X(SUBSTR(InpRec,Ofs,8))
    QWSAPSRB_Ziip = X2D(SUBSTR(QWSAPSRB_Ziip,1,13))
    QWSAPSRB_Ziip = QWSAPSRB_Ziip/1000000
    Ofs = Ofs + 16
 
    Select
         When qwsaproc  = 'MSTR' Then do
                    MstrTcb      =QWSAEJST
                    MstrSrb      =QWSAsrbt
                    MstrpSRB     =QWSApsrb
                    MstrpSRB_Ziip=QWSApsrb_Ziip
                 end
         When qwsaproc  = 'DBM1' Then do
                    DBM1Tcb      =QWSAEJST
                    DBM1Srb      =QWSAsrbt
                    DBM1pSRB     =QWSApsrb
                    DBM1pSRB_Ziip=QWSApsrb_Ziip
                 end
         When qwsaproc  = 'DIST' Then do
                    DISTTcb      =QWSAEJST
                    DISTSrb      =QWSAsrbt
                    DISTpSRB     =QWSApsrb
                    DISTpSRB_Ziip=QWSApsrb_Ziip
                 end
         When qwsaproc  = 'IRLM' Then do
                    IRLMTcb      =QWSAEJST
                    IRLMSrb      =QWSAsrbt
                    IRLMpSRB     =QWSApsrb
                    IRLMpSRB_Ziip=QWSApsrb_Ziip
                 end
         Otherwise      do
                          say 'qwsaproc NOT correct' qwsaproc
                          exit 8
                        end
    end   /* select */
RETURN
 
DSNDQISE:
    /* EDMPOOL STATS */
    numeric digits 15
    /* Fields from IFCID002  : all cumulative */
    /* calculate difference between interval */
 
    /*# OF REQ FOR CT SECTIONS*/
    Ofs = Ofs + 8
    QISECTG = C2D(SUBSTR(InpRec,Ofs,4))
    /*# OF LOAD CT SECT FROM DASD*/
    Ofs = Ofs + 4
    QISECTL = C2D(SUBSTR(InpRec,Ofs,4))
    /*# OF REQUESTS FOR DBD*/
    Ofs = Ofs + 20
    QISEDBDG = C2D(SUBSTR(InpRec,Ofs,4))
    /*# OF LOAD DBD FROM DASD*/
    Ofs = Ofs + 4
    QISEDBDL = C2D(SUBSTR(InpRec,Ofs,4))
    /*# OF REQ FOR PT SECTIONS*/
    Ofs = Ofs + 4
    QISEKTG  = C2D(SUBSTR(InpRec,Ofs,4))
    /*# OF LOAD PT SECT FROM DASD*/
    Ofs = Ofs + 4
    QISEKTL = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 12
    /*# OF Inserts  FOR DYN CACHE*/
    QISEDSI  = C2D(SUBSTR(InpRec,Ofs,4))
    /*# OF REQUESTS FOR DYN CACHE*/
    Ofs = Ofs +        4
    QISEDSG  = C2D(SUBSTR(InpRec,Ofs,4))
    /*NUMBER OF PAGES IN DBD POOL*/
    Ofs = Ofs + 12
    QISEDPGE = C2D(SUBSTR(InpRec,Ofs,4))
    /*# OF FREE PG IN DBD FREE CHAIN*/
    Ofs = Ofs + 4
    QISEDFRE = C2D(SUBSTR(InpRec,Ofs,4))
    /*# OF FAIL DUE TO DBD POOL FULL*/
    Ofs = Ofs - 8
    QISEDFAL = C2D(SUBSTR(InpRec,Ofs,4))
    /*# OF PGS IN STMT POOL*/
    Ofs = Ofs + 20
    QISECPGE = C2D(SUBSTR(InpRec,Ofs,4))
    /*# OF FREE PG IN STMT FREE CHAIN*/
    Ofs = Ofs + 4
    QISECFRE = C2D(SUBSTR(InpRec,Ofs,4))
    /*# OF FAIL DUE TO STMT POOL FULL*/
    Ofs = Ofs - 8
    QISECFAL = C2D(SUBSTR(InpRec,Ofs,4))
    /*# OF PAGES IN SKEL EDM POOL*/
    Ofs = Ofs + 24
    QISEKPGE = C2D(SUBSTR(InpRec,Ofs,4))
    /*# OF FREE PG IN SKEL EDM POOL FREE CHAIN */
    Ofs = Ofs + 4
    QISEKFRE = C2D(SUBSTR(InpRec,Ofs,4))
    /*# OF FAIL DUE TO STMT SKEL POOL FULL*/
    Ofs = Ofs - 8
    QISEKFAL = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 52
    /* Total stealable SKEL pages*/
    QISEKLRU = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
    /* Total stealable DBD  pages*/
    QISEDLRU = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 8
    /* Storage allocated to Plan Below The Bar BTB - in bytes */
    QISESQCB = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
    /* Storage allocated to Pack Below The Bar BTB */
    QISESQKB = C2D(SUBSTR(InpRec,Ofs,4))
 
      /* --- DBD -- */
      Pct=  trunc((QISEDLRU + QISEDFRE)*100/QISEDPGE)
      if Pct < 15 & Already_dbd=0  then do
         MsgType='DBD'
         ReportFlag=1
         rec.1= 'Pct DBD Free% low ' Pct run_fmt_time
         call LOGW
         retcode=4
         Already_dbd =1
      end
      /* --- Skel-- (Static SQL) */
      Pct=  trunc((QISEKLRU + QISEKFRE)*100/QISEKPGE)
      if Pct < 15 & Already_skel= 0 then do
         MsgType='SKL'
         ReportFlag=1
         rec.1= 'Pct EDM Skel(Static SQL) Free% low ',
                              Pct run_fmt_time
         call LOGW
         retcode=4
         Already_skel=1
      end
      /* --- Stmt Pool (cached dynamic SQL statements) ---*/
      if  Old_Hour > '08' & Old_Hour < '19'  & QISECFRE < 600 ,
         then
      do
        Pct=  trunc( QISECFRE*100/QISECPGE)
        if QISECFRE < 5000 & Pct < 5 & Already_stmt = 0 ,
        & QISECPGE > 15000  then
        do
           MsgType='DYN'
           ReportFlag=1
           rec.1= 'Pct EDM Stmt(Dynamic SQL) Free low',
           pct'% #Free:'QISECFRE '#Total:'QISECPGE '@' !!,
                                    run_fmt_time
           call LOGW
           retcode=4
           Already_stmt=1
        end
      end
return
DSNDQSST:
    Ofs= Ofs+4
    /* eye catcher */
    eyec     = SUBSTR(InpRec,Ofs,4)
    if ( eyec     <> 'QSST' ) then
                  do
                      say 'DSNDQSST eye catcher not met, error'
                      exit(8)
                  end
    Ofs= Ofs+56
    /* full storage contraction*/
    QSSTCONT = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
    QSSTCRIT = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
    QSSTABND = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
 return
 
DSNDQTST:
    /* Service Controler Stats */
    Ofs= Ofs+4
    /* eye catcher */
    eyec     = SUBSTR(InpRec,Ofs,4)
    if ( eyec     <> 'QTST' ) then
                  do
                      say 'DSNDQTST eye catcher not met, error'
                      exit(8)
                  end
    Ofs= Ofs+12
    /* Autobind Plan Attempts*/
    QTABINDA =  C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
    /* Autobind Plan Success */
    QTABIND  =  C2D(SUBSTR(InpRec,Ofs,4))
    Ofs= Ofs+48
    /* Plan Auth attempts    */
    QTAUCHK  =  C2D(SUBSTR(InpRec,Ofs,4))
    Ofs= Ofs+4
    /* Plan Auth Succ        */
    QTAUSUC  =  C2D(SUBSTR(InpRec,Ofs,4))
    Ofs= Ofs+4
    /* Datasets opened (snapshot)*/
    QTDSOPN  =  C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 8
    /* Plans Auth Succ with Plan Auth Cache */
    QTAUCCH  =  C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 12
    /* Pack authh Succ with Pack Auth Cache */
    QTPACAUT =  C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 8
    /* Pack auth can't use  Pack Auth Cache */
    QTPACNOT =  C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 20
    /* DS closed by drain DSMAX reached */
    QTDSDRN  =  C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
    /* RWRO Convert */
    QTPCCT   =  C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 44
    /* Autobind Package Attemps */
    QTAUTOBA =  C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
    /* Autobind Package Succ    */
    QTPKABND =  C2D(SUBSTR(InpRec,Ofs,4))
 
 return
DSNDQ3ST:
    /* DB2 Subsystem services fields */
    Ofs= Ofs+4
    /* Signon, meaningful only with CICS or IMS */
    /* Nbr of signon for new user of an EXISTING thread*/
    /* If Signon > CrtThread then there is Thread reuse */
    Q3STSIGN = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
    /* Create thread (does not include DBAT) */
    Q3STCTHD = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
    /* Terminate     */
    Q3STTERM = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 8
    /* Commit1 */
    Q3STPREP = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
    /* Commit2 */
    Q3STCOMM = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
    /* Aborts */
    Q3STABRT = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 36
    /* HWM   IDBACK*/
    Q3STHWIB = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
    /* HWM   IDFORE*/
    Q3STHWIF = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
    /* HWM   CTHREAD*/
    Q3STHWCT = C2D(SUBSTR(InpRec,Ofs,4))
 return
 
DSNDQJST:
    Ofs=Ofs+4
    /* eye catcher */
    eyec     = SUBSTR(InpRec,Ofs,4)
    if ( eyec     <> 'QJST' ) then
                  do
                      say 'DSNDQJST eye catcher not met, error'
                      exit(8)
                  end
    Ofs=Ofs+16
    /* WAIT COUNT DUE TO UNAVAILABLE ACTIVE BUFFER*/
    QJSTWTB  = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs=Ofs+24
    /* active log output CI created */
    QJSTBFFL = C2D(SUBSTR(InpRec,Ofs,4))
    return
DSNDQDST:
/* part of IFCID 001 = Non cumulative */
    if QWS00RCO = 0 then
    /* No DDF information */
      do
       /* say 'There is no DDF information in this trace'
          say ' ' */
          QDSTQDBT =0
          QDSTQCRT =0
          QDSTNQR2 =0
          QDSTQCIT =0
          QDSTQMIT =0
          QDSTCNAT =0
          QDSTHWAT =0
          QDSTHWDT =0
          QDSTCIN2 =0
          QDSTMIN2 =0
          return
      end
    /* dbat queued */
    QDSTQDBT = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 20 /* 4x 5 */
    /* dbat rejected condbat reached */
    QDSTQCRT = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
    /* current inact 1 */
    QDSTQCIT = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
    /* Max     inact 1 */
    QDSTQMIT = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
    /* curr pooled dbat : active and disconnect */
    QDSTCNAT = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
    /* Max  pooled dbat : active and disconnect */
    QDSTHWAT = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
    /* Max  dbat        : Max active + inact    */
    QDSTHWDT = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 8
    /* cur inact 2        */
    QDSTCIN2 = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
    /* Max inact 2        */
    QDSTMIN2 = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 8
    /* Cur type 2 queued MAXDBAT reached */
    QDSTNQR2 = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
    /* HWM type 2 queued MAXDBAT reached */
    QDSTMQR2 = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 12
    /* Requests that required DBAT creation Type 2 */
    QDSTNDBA = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 4
    /* Requests that reuse a disconnected DBAT (Pooled DBAT)*/
    QDSTPOOL = C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 16
    /* Min time wait QDSTNQMN */
    QDSTNQMN = C2X(SUBSTR(InpRec,Ofs,8))
    /*ELIMINATE 1.5 BYTES */
    QDSTNQMN = X2D(SUBSTR(QDSTNQMN,1,13))
    QDSTNQMN = QDSTNQMN/1000000
    Ofs = Ofs + 8
    /* Max time wait QDSTNQMX */
    QDSTNQMX = C2X(SUBSTR(InpRec,Ofs,8))
    /*ELIMINATE 1.5 BYTES */
    QDSTNQMX = X2D(SUBSTR(QDSTNQMX,1,13))
    QDSTNQMX = QDSTNQMX/1000000
    Ofs = Ofs + 8
    /* Avg time wait QDSTNQAV */
    QDSTNQAV = C2X(SUBSTR(InpRec,Ofs,8))
    /*ELIMINATE 1.5 BYTES */
    QDSTNQAV = X2D(SUBSTR(QDSTNQAV,1,13))
    QDSTNQAV = QDSTNQAV/1000000
    Ofs = Ofs + 8
 
    Already_DSNDQDST=1
    return
 
 
GET_FMT_TIME:
  Old_Hour = RUN_HH
  RUN_HH = SM100TME % 360000
  RUN_HH = RIGHT(RUN_HH,2,'0')
  RUN_MIN = SM100TME % 6000 - RUN_HH*60
  RUN_MIN = RIGHT(RUN_MIN,2,'0')
  RUN_SEC = SM100TME % 100 - RUN_HH *3600 - RUN_MIN*60
  RUN_SEC = RIGHT(RUN_SEC,2,'0')
  RUN_FMT_TIME = RUN_HH!!':'!!RUN_MIN!!':'!!RUN_SEC
  If FirstTime then do
      FirstTime=0
      MinTime  =Run_Fmt_Time
  end
  /* Detect if we change hour */
  if Old_Hour <> RUN_HH & AlreadyGetTime then Change_Hour=1
                      else Change_Hour=0
  if   Change_Hour &  reco >= 1
  then do
      call CheckValues
      call write_summary
      call init_summary
  end
  /* if we change date the reformat the new date */
  if old_dte <> sm100dte0 ! recs = 1 then
  do
      /* Format Date */
       parse value sm100dte0 with 1 . 2 c 3 yy 5 ddd 8 .
       if (c = 0) then
         yyyy = '19'!!yy
       else
         yyyy = '20'!!yy
       sm100dte    = yyyy!!'.'!!ddd
       /* get day of week : easier to select days */
       test_date = yyyy ddd
       sm100dte=DAT_MVS2SD(test_date)
       dayoweek = DAT_S2DOW(sm100dte)
   end
   /* save date of smf records processed */
   if reco = 0 then save_date=sm100dte
   else do
     if save_date <> sm100dte & displ = 0 then do
        displ=1
        say 'There is 2 different dates in this SMF extract'
        say '             '  save_date sm100dte
        say ' '
     end
   end
  AlreadyGettime=1
  RETURN
 
 
write_header:
  say 'CSV file ' oufl     ' will be produced'
  queue "Lpar,ssid,date,dow,Hour,MstrTCB,MstrSRB,MstrPSRB,"!!,
         "MstrPSRB_Ziip,Dbm1TCB,DBm1SRB,DBm1PSRB,Dbm1PSRB_Ziip,"!!,
                       "IrlmTCB,IrlmSRB,IrlmPSRB,IrlmPSRB_Ziip,"!!,
                       "DistTCB,DistSRB,DistPSRB,DistPSRB_Ziip,"!!,
         "CrtThd,Sign,Term,Comm1,Comm2,Abort,MaxIDBACK,"!!,
         "MaxIDFOR,CThread,"!!,
         "Chkpt,"!!,
         "MaxDSCur,DSClose,DSOpen,"!!,
         "ROSwitch,"!!,
                       "Getpage,Syncio,SyncWr,AsyncWr,"!!,
                       "PageInR,PageInW,"!!,
                       "SPrefIO,CastIO,DynPrfIO,LstPrfIO,BpSio,"!!,
         "MaxInac1,MaxActDbat,MaxAllDbat,"!!,
         "MaxDbat,"!!,
         "MaxAldThds,ThdMaxComp,ThdMaxComp2,"!!,
         "MaxRealUsedDB2,MaxAuxUsedDB2,MinRealAvail,"!!,
         "MaxExtRegion,Min31Avail,"!!,
         "NotOptColProc,32KbUsed4Prf,4KbUsed32Prf,"!!,
    ,/* Logging */
         "ActLogCI," !!,
    ,/* Workfile usage  */
         "Max4KwfMB,Max32KWfMB,MaxWfUseThdMB," !!,
         "MaxDGTTMB,MaxOthMB"
     /*  Zones below correspond to the ibm provided excel columns */
     /*  "Z,BE,CV,CX,CZ,CU,CW,CY,CQ,Y,BD"  */
 
  "EXECIO" queued() "DISKW OUFL"
  return
 
 
write_report:
    /* summarize or Max min to report only by hour */
   /* pas de rupture pour le 1er record lu */
   if rupture = 0
   then do
       rupture=1
       call init_summary
   end
   /* We change hour, start write */
 
   /* sum until change_hour*/
       sum_MstrTcb      = sum_MstrTcb + dif_MstrTcb
       sum_MstrSrb      = sum_MstrSrb + dif_MstrSrb
       sum_MstrpSRB     = sum_MstrpSRB + dif_MstrpSRB
       sum_MstrpSRB_Ziip = sum_MstrpSRB_Ziip + dif_MstrpSRB_Ziip
       sum_dbm1Tcb      = sum_dbm1Tcb + dif_dbm1Tcb
       sum_dbm1Srb      = sum_dbm1Srb + dif_dbm1Srb
       sum_dbm1pSRB     = sum_dbm1pSRB + dif_dbm1pSRB
       sum_dbm1pSRB_Ziip = sum_dbm1pSRB_Ziip + dif_dbm1pSRB_Ziip
       sum_IrlmTcb      = sum_IrlmTcb + dif_IrlmTcb
       sum_IrlmSrb      = sum_IrlmSrb + dif_IrlmSrb
       sum_IrlmpSRB     = sum_IrlmpSRB + dif_IrlmpSRB
       sum_IrlmpSRB_Ziip = sum_IrlmpSRB_Ziip + dif_IrlmpSRB_Ziip
       sum_DistTcb   = sum_DistTcb + dif_DistTcb
       sum_DistSrb   = sum_DistSrb + dif_DistSrb
       sum_DistpSRB  = sum_DistpSRB+ dif_DistpSRB
       sum_DistpSRB_Ziip = sum_DistpSRB_Ziip+ dif_DistpSRB_Ziip
       sum_Q3STCTHD  = sum_Q3STCTHD + dif_Q3STCTHD /* cr threads*/
       sum_Q3STSIGN  = sum_Q3STSIGN + dif_Q3STSIGN /* Signon  */
       sum_Q3STTERM  = sum_Q3STTERM + dif_Q3STTERM /* Terminate*/
       sum_Q3STPREP  = sum_Q3STPREP + dif_Q3STPREP /* commit ph1*/
       sum_Q3STCOMM  = sum_Q3STCOMM + dif_Q3STCOMM /* Commit Ph 2*/
       sum_Q3STABRT  = sum_Q3STABRT + dif_Q3STABRT /* Aborts */
       if  Q3STHWIB > Max_Q3STHWIB  then     /* Max IDBACK */
           Max_Q3STHWIB = Q3STHWIB
       if  Q3STHWIF > Max_Q3STHWIF  then     /* Max IDFORE */
           Max_Q3STHWIF = Q3STHWIF
       if  Q3STHWCT > Max_Q3STHWCT  then     /* Max IDFORE */
           Max_Q3STHWCT = Q3STHWCT
       if  QTDSOPN  > Max_QTDSOPN   then     /* Max DS Opened*/
           Max_QTDSOPN  = QTDSOPN
       Sum_QXSTFND = Sum_QXSTFND + dif_QXSTFND   /* Full prepare*/
       Sum_QXSTNFND = Sum_QXSTNFND + Dif_QXSTNFND
       Sum_QXSTIPRP = Sum_QXSTIPRP + Dif_QXSTIPRP
       Sum_QXSTNPRP = Sum_QXSTNPRP + Dif_QXSTNPRP
       Sum_QXNSMIAP= Sum_QXNSMIAP+ dif_QXNSMIAP
       Sum_QXMRMIAP= Sum_QXMRMIAP+ dif_QXMRMIAP
       Sum_QXWFRIDS= Sum_QXWFRIDS+ dif_QXWFRIDS
       Sum_QXWFRIDT= Sum_QXWFRIDT+ dif_QXWFRIDT
       Sum_QXHJINCS= Sum_QXHJINCS+ dif_QXHJINCS
       Sum_QXHJINCT= Sum_QXHJINCT+ dif_QXHJINCT
       Sum_QXSISTOR= Sum_QXSISTOR+ dif_QXSISTOR
    if  QWHSRN > 'B1' then do     /* V12*/
       Sum_QXRWSINSRTDAlg1=Sum_QXRWSINSRTDAlg1+dif_QXRWSINSRTDAlg1
       Sum_QXRWSINSRTDAlg2=Sum_QXRWSINSRTDAlg2+dif_QXRWSINSRTDAlg2
       Sum_QXRFMIAP= Sum_QXRFMIAP+ dif_QXRFMIAP
    end
       Sum_QWSDCKPT= Sum_QWSDCKPT+ dif_QWSDCKPT  /* Checkpoints */
       Sum_QTDSDRN = Sum_QTDSDRN + dif_QTDSDRN   /* Drain Close */
       Sum_QTPCCT  = Sum_QTPCCT  + dif_QTPCCT    /* RWRO Switch */
       Sum_QTABINDA= Sum_QTABINDA+ dif_QTABINDA  /* Autobind plans*/
       Sum_QTABIND = Sum_QTABIND + dif_QTABIND
       Sum_QTAUCHK = Sum_QTAUCHK + dif_QTAUCHK   /* Plan auth*/
       Sum_QTAUSUC = Sum_QTAUSUC + dif_QTAUSUC
       Sum_QTAUCCH = Sum_QTAUCCH + dif_QTAUCCH
       Sum_QTPACAUT= Sum_QTPACAUT+ dif_QTPACAUT  /*Pack auth*/
       Sum_QTPACNOT= Sum_QTPACNOT+ dif_QTPACNOT
       Sum_QTAUTOBA= Sum_QTAUTOBA+ dif_QTAUTOBA  /* Autobind pack*/
       Sum_QTPKABND= Sum_QTPKABND+ dif_QTPKABND
       Sum2_QBSTDSO = Sum2_QBSTDSO + dif_QBSTDSO /* Open DS*/
       sum2_QBSTGET = sum2_QBSTGET + dif_QBSTGET /* gp */
       sum2_QBSTRIO = sum2_QBSTRIO + dif_QBSTRIO /* sync read */
       /* Stats   for individual BP */
       do i=1 to nbBP
          bpn=BPList.i
          sum_QBSTRIO.bpn = sum_QBSTRIO.bpn+ dif_QBSTRIO.bpn
          sum_QBSTRPI.bpn = sum_QBSTRPI.bpn+ dif_QBSTRPI.bpn
          sum_QBSTWPI.bpn = sum_QBSTWPI.bpn+ dif_QBSTWPI.bpn
       end
       sum2_QBSTIMW = sum2_QBSTIMW + dif_QBSTIMW /* Immed. write */
       sum2_QBSTWIO = sum2_QBSTWIO + dif_QBSTWIO /* Async Write */
       sum2_QBSTRPI = sum2_QBSTRPI + dif_QBSTRPI /* Page IN Read*/
       sum2_QBSTWPI = sum2_QBSTWPI + dif_QBSTWPI /* Page In Writ*/
       sum2_QBSTPIO = sum2_QBSTPIO + dif_QBSTPIO /* Seq Pref. IO */
       sum2_QBSTCIO = sum2_QBSTCIO + dif_QBSTCIO /* Castout IO */
       sum2_QBSTDIO = sum2_QBSTDIO + dif_QBSTDIO /* Dyn Pr IO */
       sum2_QBSTLIO = sum2_QBSTLIO + dif_QBSTLIO /* Lst Pr IO */
       sum2_QBSTSIO = sum2_QBSTSIO + dif_QBSTSIO /* SIO */
       if  QDSTQMIT > Max_QDSTQMIT  then     /* Max inact type1*/
           Max_QDSTQMIT = QDSTQMIT
       if  QDSTHWAT > Max_QDSTHWAT  then     /* Max act dbat */
           Max_QDSTHWAT = QDSTHWAT
       if  QDSTHWDT > Max_QDSTHWDT  then     /* Max act&inact dbat*/
           Max_QDSTHWDT = QDSTHWDT
       if  QDSTMIN2 > Max_QDSTMIN2  then     /* Max  dbat*/
           Max_QDSTMIN2 = QDSTMIN2
       if  QW0225AT > Max_QW0225AT  then     /* Max allied threads*/
           Max_QW0225AT = QW0225AT
       if  ThdComp  < MinThdComp   then     /* Max thread computed*/
           MinThdcomp  = Thdcomp
       if  TotalRealUsedByDB2 > Max_TotalRealUsedByDB2 then
           Max_TotalRealUsedByDB2 = TotalRealUsedByDB2
       if  TotalAuxlUsedByDB2 > Max_TotalAuxlUsedByDB2 then
           Max_TotalAuxlUsedByDB2 = TotalAuxlUsedByDB2
       if  QW0225_REALAVAIL   < min_QW0225_REALAVAIL then
           min_QW0225_REALAVAIL = QW0225_REALAVAIL
       if  QW0225RG    > Max_QW0225RG then
           Max_QW0225RG         = QW0225RG /* Region Size extended */
       if  QW0225AV    < Min_QW0225AV then /* 31 bits available */
          Min_QW0225AV         = QW0225AV
       sum_QISTCOLS= Sum_QISTCOLS+ dif_QISTCOLS /* Cols not optimized*/
       sum_QISTWFP1= Sum_QISTWFP1+ dif_QISTWFP1 /* 32KbUsed4Pref.*/
       sum_QISTWFP2= Sum_QISTWFP2+ dif_QISTWFP2 /* 4KbUsed32Prf*/
       sum_QJSTBFFL= Sum_QJSTBFFL+ dif_QJSTBFFL /* Log created*/
   return
write_summary:
    /* write only if some records have been read between writes*/
    if RFlush= 0 ! ( RFlush=1 & recw<reci)  then nop
                      else return
    /* output counter */
    reco= reco+ 1
    recw= reci  /* we save when we write */
    /* Display some warnings */
    Call Check_counters
    /*rows in excel format */
    queue sm100sid !! ',' !! ssid     !! ','  ,
    !! '"' !! sm100dte !! '"' !! ','   ,
    !! dayoweek     !! ','   ,
    !! Old_Hour     !! ','   ,
    !! sum_MstrTcb      !! ','   ,
    !! sum_MstrSrb      !! ','   ,
    !! sum_MstrpSRB     !! ','   ,
    !! sum_MstrpSRB_Ziip !! ','   ,
    !! sum_dbm1Tcb      !! ','   ,
    !! sum_dbm1Srb      !! ','   ,
    !! sum_dbm1pSRB     !! ','   ,
    !! sum_dbm1pSRB_Ziip !! ','   ,
    !! sum_IrlmTcb      !! ','   ,
    !! sum_IrlmSrb      !! ','   ,
    !! sum_IrlmpSRB     !! ','   ,
    !! sum_IrlmpSRB_Ziip !! ','  ,
    !! sum_DistTcb      !! ','   ,
    !! sum_DistSrb      !! ','   ,
    !! sum_DistpSRB     !! ','     ,
    !! sum_DistpSRB_Ziip !! ','    ,
    !! sum_Q3STCTHD  !! ','        ,     /* Create Thd */
    !! sum_Q3STSIGN  !! ','        ,     /* Signon  */
    !! sum_Q3STTERM  !! ','        ,     /* Terminate*/
    !! sum_Q3STPREP  !! ','        ,     /* Commit phase 1 */
    !! sum_Q3STCOMM  !! ','        ,     /* Commit Ph 2*/
    !! sum_Q3STABRT  !! ','        ,     /* Aborts */
    !! Max_Q3STHWIB  !! ','        ,     /* Max IDBACK */
    !! Max_Q3STHWIF  !! ','        ,     /* Max IDFORE */
    !! Max_Q3STHWCT  !! ','        ,     /* Max CTHREAD */
    !! sum_QWSDCKPT  !! ','        ,     /* Checkpoints */
    !! Max_QTDSOPN   !! ','        ,     /* DS Opened   */
    !! sum_QTDSDRN   !! ','        ,     /* Drain Close */
    !! sum2_QBSTDSO  !! ','        ,     /* OPEN DS     */
    !! sum_QTPCCT    !! ','        ,     /* RWRO switch */
    !! sum2_QBSTGET   !! ','        ,
    !! sum2_QBSTRIO   !! ','        ,
    !! sum2_QBSTIMW   !! ','        ,
    !! sum2_QBSTWIO   !! ','        ,
    !! sum2_QBSTRPI   !! ','        , /*page in read */
    !! sum2_QBSTWPI   !! ','        ,
    !! sum2_QBSTPIO   !! ','        ,
    !! sum2_QBSTCIO   !! ','        ,
    !! sum2_QBSTDIO   !! ','        ,
    !! sum2_QBSTLIO   !! ','        ,
    !! sum2_QBSTSIO   !! ','        ,
    !! Max_QDSTQMIT      !! ','        ,     /* Max . inact type 1*/
    !! Max_QDSTHWAT      !! ','        ,     /* Max active dbat*/
    !! Max_QDSTHWDT      !! ','        ,     /* Max act & inact dbat */
    !! Max_QDSTMIN2      !! ','        ,     /* act dbat */
    !! Max_QW0225AT      !! ','        ,     /*  allied threads*/
    !! format(MinThdComp ,8,0)   !! ',' ,
    !! format(MinThdComp ,8,0)   !! ',' ,
    !! f2mb(Max_TotalRealUsedByDB2)     !! ',' ,
    !! f2mb(Max_TotalAuxlUsedByDB2)     !! ',' ,
    !! f2mb(min_QW0225_REALAVAIL)       !! ',' ,
    !! b2mb(Max_QW0225RG)               !! ',' ,
    !! b2mb(min_QW0225AV)               !! ',' , /* 31 bits avail*/
    !!         sum_QISTCOLS         !! ',' ,
    !!         sum_QISTWFP1         !! ',' ,
    !!         sum_QISTWFP2         !! ',' ,
    !!     sum_QJSTBFFL             !! ',' ,  /*Log created*/
    !!  trunc(Max_QISTW4K/1024)  !! ',' , /* Max MB 4K */
    !!  trunc(Max_QISTW32K/1024) !! ',' ,
    !!  trunc(QISTAMXU/1024)     !! ',' , /*Max MB wk used thread*/
    !!  trunc(QISTDGTTMXU/1024)  !! ',' , /* Max MB DGTT */
    !!  trunc(QISTWFMXU/1024)    !! ','   /* Max MB Other*/
   "EXECIO" queued() "DISKW OUFL"
return
 
 
/* SMF HEADER */
DSNDQWST:
   /* SM100SID lpar  */
   if recs = 0  then do
      sm100sid = SUBSTR(InpRec,11,4)
      select
       when sm100sid = 'PROD' and LparId =  'LPAR353' then
                    sm100sid = 'ZPR1'
       when sm100sid = 'D14Q' then
                    sm100sid = 'DEV'
       otherwise
      end
   end
 
   Ofs = Ofs + 1
 
   /* SM100RTY DS XL1 RECORD TYPE X'64' OR 100 */
   SM100RTY = C2D(SUBSTR(InpRec,Ofs,1))
 
   /* stop processing if not 100 */
   if sm100rty <> 100 then return
 
   Ofs = Ofs + 13
   /* SM100SSI DS CL4 SUBSYSTEM ID */
   sm100ssi = SUBSTR(InpRec,Ofs,4)
 
              /* ssid > ' '  ssid has value  */
   if sm100ssi <> ssid & ssid > ' ' then return
   /* Load date and time only on selected records */
   /* otherwise error on comparison on date       */
   Ofs = Ofs - 12
   /* SM100TME DS XL4 TIME SMF MOVED RECORD */
   SM100TME = C2D(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* SM100DTE DATE  */
   old_dte =  sm100dte0 /* save old date to avoid format operation*/
   sm100dte0 = C2X(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 18
   /* TOTAL LENGTH = 28 */
RETURN
 
 
dsndqbst:
    numeric digits 15
    QBSTPID =  C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 8
    QBSTGET =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 8
    QBSTRIO =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 48
    QBSTWIO =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 16
    QBSTRPI =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 8
    QBSTWPI =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 8
    /* Open Dataset */
    QBSTDSO =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 8
    QBSTIMW =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 16
    /* Pages read seq Prefetch */
    QBSTSPP =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 56
    /* OF SEQ PREFETCH (ASYNCHRONOUS) READ*/
    QBSTPIO =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 8
    /* Reference on workfile : V11 Subsys and Transac Monitoring ... */
    /* Wrk prefetch aborted 0 prefetch quanity */
    QBSTWKPD=  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 8
    /* nb wkfile not created due to buffers resource */
    QBSTMAX =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 32
    /* nb of wrkfile requested for all merge pass operations*/
    QBSTWFR =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 8
    /* nb of merge pass requested               */
    QBSTWFT =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 8
    /* nb of workfiles denied during sort/merge */
    QBSTWFD =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 8
    /* nb of time sort not optimized due to BP shortage*/
    /* :the max nb workfiles allowed is less than the nb requested*/
    QBSTWFF =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 40
    /* nb of cast out IO */
    QBSTCIO =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 8
    /* vpsize */
    QBSTVPL =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 8
    /* Pages read by Dyn. Pref */
    QBSTDPP =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 8
    /* Pages read by Lst. Pref */
    QBSTLPP =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 8
    /* save BP0 size - after 17:00 because i had time to modify */
    /*
    if lpar = 'SUD2' & Old_Hour > '17' then
    do
         if bp0_vpsize  = 0 then
         do
             if QBSTPID = 0 then do
                                 bp0_vpsize = QBSTVPL
                                 say  ssid 'BP0VPSIZE=' bp0_vpsize
                            end
         end
    end
    */
    QBSTDIO =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 8
    QBSTLIO =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 16
    QBSTSIO =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 24
    /* £ OF concurrent PREFETCH I/O STREAMS  DENIED */
    QBSTJIS =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 88        /* 8*14*/
    /* Min SRLU */
    QBSTSMIN=  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 8
    /* Max SRLU */
    QBSTSMAX=  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 8
    /* Nb times SLRU = VPSEQT */
    QBSTHST =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 8
    /* Nb times Random getpage found in SRLU chain */
    QBSTRHS =  C2D(SUBSTR(InpRec,Ofs,8))
    if QWHSRN = 'B1' then /* V11*/
        Ofs = Ofs + 8
    else
        Ofs = Ofs + 40 /*V12*/
 
    /*****************************/
    /* Processing the data read  */
    /*****************************/
 
    /* Test if BufferID QBSTPIDis Already recorded */
    i=1
    do while i <= nbBP
       if QBSTPID = BPList.i then leave
       i=i+1
    end
    if i >  nbBP then /* this BP is not recorded yet */
    do
        nbBP=nbBP+1
 
        sum_QBSTRIO.QBSTPID=0
        sum_QBSTRPI.QBSTPID=0
        sum_QBSTWPI.QBSTPID=0
        BPList.nbBP=QBSTPID
        PrefQtyLow.QBSTPID = 0
        WfSyncHigh.QBSTPID  = 0
        WfPrfNotSch.QBSTPID=0
        MergePassDegr.QBSTPID =0
        WrkfileReqRej.QBSTPID =0
        ConPfRej.QBSTPID =0
 
        /* First entry is  created with read value because */
        /* records are cumulative */
        Old_QBSTVPL.QBSTPID=QBSTVPL
        Old_QBSTLPP.QBSTPID=QBSTLPP
        Old_QBSTDPP.QBSTPID=QBSTDPP
        Old_QBSTSPP.QBSTPID=QBSTSPP
        Old_QBSTGET.QBSTPID=QBSTGET
        Old_QBSTRIO.QBSTPID=QBSTRIO /* Sync IO */
        Old_QBSTRPI.QBSTPID=QBSTRPI /* Page in read */
        Old_QBSTWPI.QBSTPID=QBSTWPI
        Old_QBSTPIO.QBSTPID=QBSTPIO /* Seq Pref IO */
        Old_QBSTWKPD.QBSTPID=QBSTWKPD
        Old_QBSTMAX.QBSTPID=QBSTMAX
        Old_QBSTWFD.QBSTPID=QBSTWFD
        Old_QBSTWFF.QBSTPID=QBSTWFF
        Old_QBSTWFT.QBSTPID=QBSTWFT
        Old_QBSTWFR.QBSTPID=QBSTWFR
        Old_QBSTJIS.QBSTPID=QBSTJIS
    end
 
    /* Processing counters to report */
    Dif_QBSTVPL.QBSTPID = QBSTVPL  - Old_QBSTVPL.QBSTPID
          /***************************/
          /* detect change in vpsize */
          /***************************/
          if ç LparAutoSize then do
            j= abs(Dif_QBSTVPL.QBSTPID)
            if j > 0 & j > 5000 then /*avoid autosize case */
            do
               bpnm=TranslateBP(QBSTPID)
               rec.1= sm100sid'/'sm100ssi,
                    'Vpsize change for Buffer ' bpnm,
                    '@:' run_fmt_time 'Old:' Old_QBSTVPL.QBSTPID,
                    'New:' QBSTVPL
               ReportFlag=1
               MsgType='LOG'
               call LogAlert
               call LogW
            end
          end
    Dif_QBSTLPP.QBSTPID = QBSTLPP  - Old_QBSTLPP.QBSTPID
    Dif_QBSTDPP.QBSTPID = QBSTDPP  - Old_QBSTDPP.QBSTPID
    Dif_QBSTSPP.QBSTPID = QBSTSPP  - Old_QBSTSPP.QBSTPID
    Dif_QBSTPIO.QBSTPID = QBSTPIO  - Old_QBSTPIO.QBSTPID
    Dif_QBSTGET.QBSTPID = QBSTGET  - Old_QBSTGET.QBSTPID
    Dif_QBSTRIO.QBSTPID = QBSTRIO  - Old_QBSTRIO.QBSTPID
    Dif_QBSTRPI.QBSTPID = QBSTRPI  - Old_QBSTRPI.QBSTPID
    Dif_QBSTWPI.QBSTPID = QBSTWPI  - Old_QBSTWPI.QBSTPID
    Dif_QBSTWKPD.QBSTPID= QBSTWKPD - Old_QBSTWKPD.QBSTPID
    Dif_QBSTMAX.QBSTPID = QBSTMAX  - Old_QBSTMAX.QBSTPID
    Dif_QBSTWFD.QBSTPID = QBSTWFD  - Old_QBSTWFD.QBSTPID
    Dif_QBSTWFF.QBSTPID = QBSTWFF  - Old_QBSTWFF.QBSTPID
    Dif_QBSTWFT.QBSTPID = QBSTWFT  - Old_QBSTWFT.QBSTPID
    Dif_QBSTWFR.QBSTPID = QBSTWFR  - Old_QBSTWFR.QBSTPID
    Dif_QBSTJIS.QBSTPID = QBSTJIS  - Old_QBSTJIS.QBSTPID
 
    Old_QBSTSPP.QBSTPID=QBSTSPP
    Old_QBSTVPL.QBSTPID=QBSTVPL
    Old_QBSTLPP.QBSTPID=QBSTLPP
    Old_QBSTDPP.QBSTPID=QBSTDPP
    Old_QBSTPIO.QBSTPID=QBSTPIO
    Old_QBSTGET.QBSTPID=QBSTGET
    Old_QBSTRIO.QBSTPID=QBSTRIO
    Old_QBSTRPI.QBSTPID=QBSTRPI
    Old_QBSTWPI.QBSTPID=QBSTWPI
    Old_QBSTWKPD.QBSTPID=QBSTWKPD
    Old_QBSTMAX.QBSTPID=QBSTMAX
    Old_QBSTWFD.QBSTPID=QBSTWFD
    Old_QBSTWFF.QBSTPID=QBSTWFF
    Old_QBSTWFT.QBSTPID=QBSTWFT
    Old_QBSTWFR.QBSTPID=QBSTWFR
    Old_QBSTJIS.QBSTPID=QBSTJIS
 
    /* Note MaxReads rate */
    if MaxReads < Dif_QBSTRIO.QBSTPID then
    do
        MaxReadsBP = QBSTPID
        MaxReads   = Dif_QBSTRIO.QBSTPID
        MaxReadsGP = Dif_QBSTGET.QBSTPID
        MaxReadsHr = RUN_FMT_TIME
    end
    /****************************************************/
    /* Reevaluate max SRLU                              */
    /****************************************************/
    If QBSTSMAX.QBSTPID < QBSTSMAX then
                          QBSTSMAX.QBSTPID = QBSTSMAX
    /*************************************************/
    /* Calculate WF not created lack of resource     */
    /*************************************************/
    If QBSTMAX.QBSTPID < QBSTMAX then
                          QBSTMAX.QBSTPID = QBSTMAX
    /*************************************************/
    /* Calculate prefetch quantity each stat Interval*/
    /*************************************************/
    if Dif_QBSTRIO.QBSTPID > 60000 then  /* 1000 IO/s */
    do
      if  Dif_QBSTSPP.QBSTPID > 0 & Dif_QBSTPIO.QBSTPID > 0 then
      do
        PrefQty = trunc(Dif_QBSTSPP.QBSTPID/Dif_QBSTPIO.QBSTPID)
        if PrefQty <= 4 then
          do
            PrefQtyLow.QBSTPID = PrefQtyLow.QBSTPID+1
          end
      end
    end
 
    /***************************************************/
    /* Calculate Rand page vs. Pages read by Prefetch  */
    /***************************************************/
    if Dif_QBSTRIO.QBSTPID > 60000  then /* 1000 IO/s*/
    do
      PagesPrefetch = Dif_QBSTSPP.QBSTPID + Dif_QBSTLPP.QBSTPID,
                   + Dif_QBSTDPP.QBSTPID
      if   PagesPrefetch > 0 then
      do
        x = trunc(Dif_QBSTRIO.QBSTPID*100/PagesPrefetch)
        if x >= 1 then do
               WfSyncHigh.QBSTPID = WfSyncHigh.QBSTPID+1
          end
      end
    end
 
    /**************************/
    /* Prefetch not scheduled */
    /**************************/
    if  Dif_QBSTRIO.QBSTPID > 60000 &,
        Dif_QBSTWKPD.QBSTPID > 0  & Dif_QBSTPIO.QBSTPID > 0 then
    do
      /* QBSTWKPD must be less then 1-5% of QBSTPIO*/
      if Dif_QBSTWKPD.QBSTPID > Dif_QBSTPIO.QBSTPID*0.01 then
      do
          WfPrfNotSch.QBSTPID = WfPrfNotSch.QBSTPID+1
      end
    end
 
    /**************************/
    /* Merge Pass Degraded    */
    /**************************/
    if  Dif_QBSTWFF.QBSTPID > 0  & Dif_QBSTWFR.QBSTPID > 0 then
    do
      /* QBSTWKFF must be less then 1-5% of QBSTWFR*/
      if Dif_QBSTWFF.QBSTPID > Dif_QBSTWFR.QBSTPID*0.01 then
      do
          MergePassDegr.QBSTPID = MergePassDegr.QBSTPID+1
      end
    end
 
    /**************************/
    /* Workfile rejected      */
    /**************************/
    if  Dif_QBSTWFD.QBSTPID > 0  & Dif_QBSTWFT.QBSTPID > 0 then
    do
      /* QBSTWFD  must be less then 1-5% of QBSTWFT*/
      if Dif_QBSTWFD.QBSTPID > Dif_QBSTWFT.QBSTPID*0.01 then
      do
          WrkfileReqRej.QBSTPID = WrkfileReqRej.QBSTPID+1
      end
    end
 
    /*************************************/
    /* Concurrent Pref Rejected nobuffer */
    /*************************************/
    if  Dif_QBSTJIS.QBSTPID > 0  then
    do
      ConPfRej.QBSTPID=Dif_QBSTJIS.QBSTPID+ConPfRej.QBSTPID
    end
 
    return
dsndqbgl:
    numeric digits 15
    /* Group BPID */
    QBGLGN  =  C2D(SUBSTR(InpRec,Ofs,4))
    Ofs = Ofs + 8
    /* GBP Dependent Getpage */
    /* QBGLGG  =  C2D(SUBSTR(InpRec,Ofs,8)) */
    Ofs = Ofs + 8
    /* Syn.Read(XI)-Data returned (A in the formula ) */
    QBGLXD  =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 8
    /* Syn.Read(XI)-No Data Return (B in the formula) */
    QBGLXR  =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 24
    /* Sync Write  (from local BP to GBP) called User Write */
    /* QBGLSW  =  C2D(SUBSTR(InpRec,Ofs,8)) */
    Ofs = Ofs + 56
    /* ASync Write  (from local BP to GBP) called Syst Write */
    /* QBGLAW  =  C2D(SUBSTR(InpRec,Ofs,8)) */
    Ofs = Ofs + 8
    /* Pages castout (written from GBP to DASD) */
    /* QBGLRC  =  C2D(SUBSTR(InpRec,Ofs,8)) */
    Ofs = Ofs + 32
    /* Write requests failed no storage */
    QBGLWF  =  C2D(SUBSTR(InpRec,Ofs,8))
    Ofs = Ofs + 104
    /* Write requests failed no storage secondary GBP */
    /* QBGL2F  =  C2D(SUBSTR(InpRec,OFFSET,8)) */
    /* Write Around */
    Ofs = Ofs + 136
    /* Page in write around  */
    /* QBGLWA  =  C2D(SUBSTR(InpRec,Ofs,8)) */
    /* go to end of macro QBGL */
    Ofs = Ofs + 32
 
    /*****************************/
    /* Processing the data read  */
    /*****************************/
 
    /* test if BufferID QBGLGN is Already recorded */
    i=1
    do while i <= nbGBP
       if QBGLGN = GBPList.i then leave
       i=i+1
    end
    if i >  nbGBP then /* this GBP is not recorded yet */
    do
        nbGBP=nbGBP+1
        GBPList.nbGBP=QBGLGN
        /* First entry is  created with read value because */
        /* records are cumulative (from yesterday value for example*/
        Old_QBGLWF.QBGLGN =QBGLWF
        Old_QBGLXD.QBGLGN =QBGLXD
        Old_QBGLXR.QBGLGN =QBGLXR
        SumHr_QBGLWF.QBGLGN = 0
        SumHr_QBGLXD.QBGLGN = 0
        SumHr_QBGLXR.QBGLGN = 0
    end
 
    /* Processing counters to report */
    Dif_QBGLWF.QBGLGN = QBGLWF - Old_QBGLWF.QBGLGN
    Dif_QBGLXD.QBGLGN = QBGLXD - Old_QBGLXD.QBGLGN
    Dif_QBGLXR.QBGLGN = QBGLXR - Old_QBGLXR.QBGLGN
    Old_QBGLWF.QBGLGN = QBGLWF
    Old_QBGLXD.QBGLGN = QBGLXD
    Old_QBGLXR.QBGLGN = QBGLXR
    if Dif_QBGLWF.QBGLGN > 0  then
      SumHr_QBGLWF.QBGLGN=SumHr_QBGLWF.QBGLGN+Dif_QBGLWF.QBGLGN
    if Dif_QBGLXD.QBGLGN > 0  then
      SumHr_QBGLXD.QBGLGN=SumHr_QBGLXD.QBGLGN+Dif_QBGLXD.QBGLGN
    if Dif_QBGLXR.QBGLGN > 0  then
      SumHr_QBGLXR.QBGLGN=SumHr_QBGLXR.QBGLGN+Dif_QBGLXR.QBGLGN
 
    return
 
ifcid_diff:
       /* Cumulative values, report only the difference */
       /* When diff is negative, this means that the value have been*/
       /* reset (Seen at DB2 restart , but probably also if they    */
       /* reach their Max)                                          */
       Dif_MstrTcb =       MstrTcb       - Old_MstrTcb
       Dif_MstrSrb =       MstrSrb       - Old_MstrSrb
       Dif_MstrpSRB=       MstrpSRB      - Old_MstrpSRB
       Dif_MstrpSRB_Ziip = MstrpSRB_Ziip - Old_MstrpSRB_Ziip
       Dif_dbm1Tcb =       dbm1Tcb       - Old_dbm1Tcb
       Dif_dbm1srb =       dbm1srb       - Old_dbm1srb
       Dif_dbm1pSRB=       dbm1pSRB      - Old_dbm1pSRB
       Dif_dbm1pSRB_Ziip = dbm1pSRB_Ziip - Old_dbm1pSRB_Ziip
       Dif_irlmTcb =       irlmTcb       - Old_irlmTcb
       Dif_irlmsrb =       irlmsrb       - Old_irlmsrb
       Dif_irlmpSRB=       irlmpSRB      - Old_irlmpSRB
       Dif_irlmpSRB_Ziip = irlmpSRB_Ziip - Old_irlmpSRB_Ziip
       Dif_distTcb =       distTcb       - Old_distTcb
       Dif_distsrb =       distsrb       - Old_distsrb
       Dif_distpSRB=       distpSRB      - Old_distpSRB
       Dif_distpSRB_Ziip = distpSRB_Ziip - Old_distpSRB_Ziip
 
        if    Dif_MstrTcb < 0 then
        do
          say '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
          say 'Cumulative fields reset, possible DB2 RECYCLE'
          say '      at' sm100dte run_fmt_time
          say '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
          say ''
          Dif_MstrTcb =       MstrTcb
          Dif_MstrSrb =       MstrSrb
          Dif_MstrpSRB=       MstrpSRB
          Dif_MstrpSRB_Ziip = MstrpSRB_Ziip
          Dif_dbm1Tcb =       dbm1Tcb
          Dif_dbm1srb =       dbm1srb
          Dif_dbm1pSRB=       dbm1pSRB
          Dif_dbm1pSRB_Ziip = dbm1pSRB_Ziip
          Dif_irlmTcb =       irlmTcb
          Dif_irlmsrb =       irlmsrb
          Dif_irlmpSRB=       irlmpSRB
          Dif_irlmpSRB_Ziip = irlmpSRB_Ziip
          Dif_distTcb =       distTcb
          Dif_distsrb =       distsrb
          Dif_distpSRB=       distpSRB
          Dif_distpSRB_Ziip = distpSRB_Ziip
        end
          Old_MstrTcb =       MstrTcb
          Old_MstrSrb =       MstrSrb
          Old_MstrpSRB=       MstrpSRB
          Old_MstrpSRB_Ziip = MstrpSRB_Ziip
          Old_dbm1Tcb =       dbm1Tcb
          Old_dbm1srb =       dbm1srb
          Old_dbm1pSRB=       dbm1pSRB
          Old_dbm1pSRB_Ziip = dbm1pSRB_Ziip
          Old_irlmTcb =       irlmTcb
          Old_irlmsrb =       irlmsrb
          Old_irlmpSRB=       irlmpSRB
          Old_irlmpSRB_Ziip = irlmpSRB_Ziip
          Old_distTcb =       distTcb
          Old_distsrb =       distsrb
          Old_distpSRB=       distpSRB
          Old_distpSRB_Ziip = distpSRB_Ziip
 
          Dif_QDSTQDBT =     QDSTQDBT-Old_QDSTQDBT
          Dif_QDSTQCRT =     QDSTQCRT-Old_QDSTQCRT
 
       /*********************************/
       /* Subsystem services stats Q3ST */
       /*********************************/
 
          Dif_Q3STSIGN =     Q3STSIGN-Old_Q3STSIGN
          Dif_Q3STTERM =     Q3STTERM-Old_Q3STTERM
          Dif_Q3STCTHD =     Q3STCTHD-Old_Q3STCTHD
          Dif_Q3STPREP =     Q3STPREP-Old_Q3STPREP
          Dif_Q3STCOMM =     Q3STCOMM-Old_Q3STCOMM
          Dif_Q3STABRT =     Q3STABRT-Old_Q3STABRT
 
          if  Dif_Q3STSIGN < 0 then
          do
            Dif_QDSTQDBT = QDSTQDBT
            Dif_QDSTQCRT = QDSTQCRT
            Dif_Q3STSIGN = Q3STSIGN
            Dif_Q3STTERM = Q3STTERM
            Dif_Q3STCTHD = Q3STCTHD
            Dif_Q3STPREP = Q3STPREP
            Dif_Q3STCOMM = Q3STCOMM
            Dif_Q3STABRT = Q3STABRT
          end
 
          Old_QDSTQDBT = QDSTQDBT
          Old_QDSTQCRT = QDSTQCRT
          Old_Q3STSIGN = Q3STSIGN
          Old_Q3STTERM = Q3STTERM
          Old_Q3STCTHD = Q3STCTHD
          Old_Q3STPREP = Q3STPREP
          Old_Q3STCOMM = Q3STCOMM
          Old_Q3STABRT = Q3STABRT
 
       /***************************/
       /* buffer pool stats       */
       /***************************/
 
          Dif_QBSTGET = Sum_QBSTGET-Old_QBSTGET
          Dif_QBSTRIO = Sum_QBSTRIO-Old_QBSTRIO
          Dif_QBSTDSO = Sum_QBSTDSO-Old_QBSTDSO
          Dif_QBSTIMW = Sum_QBSTIMW-Old_QBSTIMW
          Dif_QBSTWIO = Sum_QBSTWIO-Old_QBSTWIO
          Dif_QBSTRPI = Sum_QBSTRPI-Old_QBSTRPI
          Dif_QBSTWPI = Sum_QBSTWPI-Old_QBSTWPI
          Dif_QBSTPIO = Sum_QBSTPIO-Old_QBSTPIO
          Dif_QBSTCIO = Sum_QBSTCIO-Old_QBSTCIO
          Dif_QBSTDIO = Sum_QBSTDIO-Old_QBSTDIO
          Dif_QBSTlIO = Sum_QBSTlIO-Old_QBSTlIO
          Dif_QBSTsIO = Sum_QBSTSIO-Old_QBSTSIO
 
          if  Dif_QBSTGET < 0 then
          do
            Dif_QBSTGET = Sum_QBSTGET
            Dif_QBSTRIO = Sum_QBSTRIO
            Dif_QBSTDSO = Sum_QBSTDSO
            Dif_QBSTIMW = Sum_QBSTIMW
            Dif_QBSTWIO = Sum_QBSTWIO
            Dif_QBSTRPI = Sum_QBSTRPI
            Dif_QBSTWPI = Sum_QBSTWPI
            Dif_QBSTPIO = Sum_QBSTPIO
            Dif_QBSTCIO = Sum_QBSTCIO
            Dif_QBSTDIO = Sum_QBSTDIO
            Dif_QBSTlIO = Sum_QBSTlIO
            Dif_QBSTSIO = Sum_QBSTSIO
          end
            Old_QBSTGET = Sum_QBSTGET
            Old_QBSTRIO = Sum_QBSTRIO
            Old_QBSTIMW = Sum_QBSTIMW
            Old_QBSTDSO = Sum_QBSTDSO
            Old_QBSTWIO = Sum_QBSTWIO
            Old_QBSTRPI = Sum_QBSTRPI
            Old_QBSTWPI = Sum_QBSTWPI
            Old_QBSTPIO = Sum_QBSTPIO
            Old_QBSTCIO = Sum_QBSTCIO
            Old_QBSTDIO = Sum_QBSTDIO
            Old_QBSTLIO = Sum_QBSTLIO
            Old_QBSTSIO = Sum_QBSTSIO
 
      /****************************************/
      /* dsndqjst Log  Manager stats IFCID 001*/
      /****************************************/
      Dif_QJSTBFFL = QJSTBFFL - Old_QJSTBFFL
      if  Dif_QJSTBFFL < 0 then
              Dif_QJSTBFFL = QJSTBFFL
      Old_QJSTBFFL = QJSTBFFL
 
      Dif_QJSTWTB  = QJSTWTB  - Old_QJSTWTB
      if  Dif_QJSTWTB  < 0 then
              Dif_QJSTWTB  = QJSTWTB
      if Dif_QJSTWTB > 9  & Old_QJSTWTB > 0
      then
      do
         rec.1= sm100sid'/'sm100ssi,
              'Log Wait Unav. Output Buffer @'run_fmt_time,
               '#Occur:' Dif_QJSTWTB
         If   (Old_Hour > '08' & Old_Hour < '19') ! DispAll then
         do
           ReportFlag=1
           MsgType='LOG'
           call LogAlert
           call LogW
         end
         else say rec.1
      end
      Old_QJSTWTB  = QJSTWTB
 
      /****************************************/
      /* dsndqist Data Manager stats IFCID 002 */
      /****************************************/
          Dif_QTDSDRN  = QTDSDRN  - Old_QTDSDRN
          Dif_QTPCCT   = QTPCCT   - Old_QTPCCT
          Dif_QTABINDA = QTABINDA - Old_QTABINDA
          Dif_QTABIND  = QTABIND  - Old_QTABIND
          Dif_QTAUCHK  = QTAUCHK  - Old_QTAUCHK
          Dif_QTAUSUC  = QTAUSUC  - Old_QTAUSUC
          Dif_QTAUCCH  = QTAUCCH  - Old_QTAUCCH
          Dif_QTPACAUT = QTPACAUT - Old_QTPACAUT
          Dif_QTPACNOT = QTPACNOT - Old_QTPACNOT
          Dif_QTAUTOBA = QTAUTOBA - Old_QTAUTOBA
          Dif_QTPKABND = QTPKABND - Old_QTPKABND
          Dif_QWSDCKPT = QWSDCKPT - Old_QWSDCKPT
          Dif_QXSTFND  = QXSTFND  - Old_QXSTFND
          Dif_QXSTNFND = QXSTNFND - Old_QXSTNFND
          Dif_QXSTIPRP = QXSTIPRP - Old_QXSTIPRP
          Dif_QXSTNPRP = QXSTNPRP - Old_QXSTNPRP
          Dif_QXNSMIAP= QXNSMIAP - Old_QXNSMIAP
          Dif_QXMRMIAP= QXMRMIAP - Old_QXMRMIAP
          Dif_QXWFRIDS= QXWFRIDS - Old_QXWFRIDS
          Dif_QXWFRIDT= QXWFRIDT - Old_QXWFRIDT
          Dif_QXHJINCS= QXHJINCS - Old_QXHJINCS
          Dif_QXHJINCT= QXHJINCT - Old_QXHJINCT
          Dif_QXSISTOR= QXSISTOR - Old_QXSISTOR
    if  QWHSRN > 'B1' then do     /* V12*/
          Dif_QXRWSINSRTDAlg1 = QXRWSINSRTDAlg1-Old_QXRWSINSRTDAlg1
          Dif_QXRWSINSRTDAlg2 = QXRWSINSRTDAlg2-Old_QXRWSINSRTDAlg2
              Dif_QXRFMIAP= QXRFMIAP - Old_QXRFMIAP
    end
 
          Dif_QISTCOLS = QISTCOLS - Old_QISTCOLS
          Dif_QISTWFP1 = QISTWFP1 - Old_QISTWFP1
          Dif_QISTWFP2 = QISTWFP2 - Old_QISTWFP2
 
      if  Dif_QWSDCKPT < 0 then
          Dif_QWSDCKPT = QWSDCKPT
 
      if  Dif_QISTCOLS < 0 then
      do
          Dif_QTDSDRN  = QTDSDRN
          Dif_QTPCCT   = QTPCCT
          Dif_QTABINDA = QTABINDA
          Dif_QTABIND  = QTABIND
          Dif_QTAUCHK  = QTAUCHK
          Dif_QTAUSUC  = QTAUSUC
          Dif_QTAUCCH  = QTAUCCH
          Dif_QTPACAUT = QTPACAUT
          Dif_QTPACNOT = QTPACNOT
          Dif_QTAUTOBA = QTAUTOBA
          Dif_QTPKABND = QTPKABND
          Dif_QXSTFND  = QXSTFND
          Dif_QXSTNFND = QXSTNFND
          Dif_QXSTIPRP = QXSTIPRP
          Dif_QXSTNPRP = QXSTNPRP
          Dif_QXNSMIAP = QXNSMIAP
          Dif_QXMRMIAP = QXMRMIAP
          Dif_QXWFRIDS = QXWFRIDS
          Dif_QXWFRIDT = QXWFRIDT
          Dif_QXHJINCS = QXHJINCS
          Dif_QXHJINCT = QXHJINCT
          Dif_QXSISTOR = QXSISTOR
          if  QWHSRN > 'B1' then do     /* V12*/
              Dif_QXRFMIAP = QXRFMIAP
              Dif_QXRWSINSRTDAlg1=QXRWSINSRTDAlg1
              Dif_QXRWSINSRTDAlg2=QXRWSINSRTDAlg2
          end
          Dif_QISTCOLS = QISTCOLS
          Dif_QISTWFP1 = QISTWFP1
          Dif_QISTWFP2 = QISTWFP2
      end
 
          Old_QWSDCKPT = QWSDCKPT
 
          Old_QTDSDRN  = QTDSDRN
          Old_QTPCCT   = QTPCCT
          Old_QTABINDA = QTABINDA
          Old_QTABIND  = QTABIND
          Old_QTAUCHK  = QTAUCHK
          Old_QTAUSUC  = QTAUSUC
          Old_QTAUCCH  = QTAUCCH
          Old_QTPACAUT = QTPACAUT
          Old_QTPACNOT = QTPACNOT
          Old_QTAUTOBA = QTAUTOBA
          Old_QTPKABND = QTPKABND
          Old_QXSTFND  = QXSTFND
          Old_QXSTNFND = QXSTNFND
          Old_QXSTIPRP = QXSTIPRP
          Old_QXSTNPRP = QXSTNPRP
          Old_QXNSMIAP = QXNSMIAP
          Old_QXMRMIAP = QXMRMIAP
          Old_QXWFRIDS = QXWFRIDS
          Old_QXWFRIDT = QXWFRIDT
          Old_QXHJINCS = QXHJINCS
          Old_QXHJINCT = QXHJINCT
          Old_QXSISTOR = QXSISTOR
          if  QWHSRN > 'B1' then do     /* V12*/
              Old_QXRFMIAP = QXRFMIAP
              Old_QXRWSINSRTDAlg1=QXRWSINSRTDAlg1
              Old_QXRWSINSRTDAlg2=QXRWSINSRTDAlg2
          end
          Old_QISTCOLS = QISTCOLS
          Old_QISTWFP1 = QISTWFP1
          Old_QISTWFP2 = QISTWFP2
 
      return
DisplayVStor:
  if vsm='Y' & reco > 0 & lpar <> 'SUD2' then
  do
    MsgType='STP'
    ReportFlag=2
    rec.1= ''; call LOGW ;ReportFlag=2; rec.1= '' ; call LOGW
    ReportFlag=2
    rec.1= 'Threads observed Max : ' MaxThdSee 'at' MaxThdSeeDate,
                                                 MaxThdSeeTime
    call LOGW
    ReportFlag=2
    rec.1= '                 Min : ' MinThdSee 'at' MinThdSeeDate,
                                                 MinThdSeeTime
    call LOGW
    ReportFlag=2
    rec.1= 'Therorical allowed number of threads is : '
    call LOGW
    ReportFlag=2
    rec.1= '    ' floor(MinThdComp) '@' MinThdCompTime,
        '=>' floor(MaxThdComp) '@' MaxThdCompTime
    call LOGW
    ReportFlag=2
    rec.1= 'DBM1 Max Real Storage is : ' format(MaxReal4K_dbm1,5,2),
        'MB @' time_MaxReal4K_dbm1
    call LOGW
    ReportFlag=2
    rec.1= '                  Min is : ' ,
                             format(MinReal4K_dbm1,5,2) 'MB @',
                               time_MinReal4K_dbm1
    call LOGW
    ReportFlag=2
    rec.1= 'DIST Max Real Storage is : ' format(MaxReal4K_dist,5,2),
        'MB @' time_MaxReal4K_dist
    call LOGW
    ReportFlag=2
    rec.1= '                  Min is : ' ,
                          format(MinReal4K_dist,5,2) 'MB @',
                             time_MinReal4K_dist
    call LOGW
    ReportFlag=2
    rec.1= 'Minimum Real Stor. available for LPAR : ' ,
      f2mb(MinQW0225_REALAVAIL) 'MB @' time_MinQW0225_REALAVAIL
    call LOGW
    ReportFlag=2
    rec.1= 'Max Aux Storage used by DB2  :' f2mb(MaxDB2AuxUse) 'MB',
           '@' timeMaxDB2AuxUse
    call LOGW
  end
return
init_var:
  FirstTime=1
  QWHSRN=' ' /* avoid to get the value all the time */
  Already_stmt=0
  Already_dbd=0
  Already_btb=0
  Already_skel=0
  MaxReads=0
  AlreadyGettime=0
  if vsm='Y' then
      do
           MaxND=0
           MinAS=999999999999999
           MinTS=999999999999999
           MaxTF=0
           MaxThdSee =0
           MaxThdComp=0
           MinThdSee =999999999999999
           MinThdComp=999999999999999
           MaxReal4K_dbm1=0
           MinReal4K_dbm1=999999999999999
           MaxReal4K_dist=0
           MinReal4K_dist=999999999999999
           MinQW0225_REALAVAIL=999999999999999
        /* MaxRealLPAR = 0 */
           MaxDB2AuxUse = -1
      end
/* Others ... */
nbmsg=0
ListMsgType=''
TotPrep=0
LocalDynCache=1
DDFUSage =0
HitMinGlobal=1
HitMaxGlobal=0
HitMinLocal=1
HitMaxLocal=0
nbGBP=0
nbBP=0
Hour='00'
Max_QISTW4K=0
Max_QISTW32K=0
bp0_vpsize=0
ifcid1_seen=0
Max_SUD2_gp=0
SumBP_SUD2=0
SumBP_SUD2_all=0
SUD2_BpInact=0
tsaylocal=0
ope =0
rupture=0
rec.0  =1
recw   =0
RFlush =0
Already_DSNDQDST=0
  /* init counters */
  Old_QBSTGET = 0
  Old_QBSTRIO = 0
  Old_QTDSDRN = 0
  Old_QTPCCT  = 0
  Old_QTABINDA= 0
  Old_QTABIND = 0
  Old_QTAUCHK = 0
  Old_QTAUSUC = 0
  Old_QTAUCCH = 0
  Old_QTPACAUT= 0
  Old_QTPACNOT= 0
  Old_QTAUTOBA= 0
  Old_QTPKABND= 0
  Old_QWSDCKPT= 0
  Old_QXSTFND = 0
  Old_QXSTNFND= 0
  Old_QXSTIPRP= 0
  Old_QXSTNPRP= 0
  Old_QXNSMIAP= 0
  Old_QXMRMIAP= 0
  Old_QXWFRIDS= 0
  Old_QXWFRIDT= 0
  Old_QXHJINCS= 0
  Old_QXHJINCT= 0
  Old_QXSISTOR= 0
  Old_QXRFMIAP= 0
  Old_QXRWSINSRTDAlg1=0
  Old_QXRWSINSRTDAlg2=0
  Dif_QXRFMIAP= 0
  Dif_QXRWSINSRTDAlg1=0
  Dif_QXRWSINSRTDAlg2=0
  Old_QBSTDSO = 0
  Old_QBSTIMW = 0
  Old_QBSTWIO = 0
  Old_QBSTRPI = 0
  Old_QBSTWPI = 0
  Old_QBSTPIO = 0
  Old_QBSTCIO = 0
  Old_QBSTDIO = 0
  Old_QBSTLIO = 0
  Old_QBSTSIO = 0
 
  Old_QJSTBFFL  = 0
  Old_QJSTWTB   = 0
 
  Old_QISTCOLS  = 0
  Old_QISTWFP1  = 0
  Old_QISTWFP2  = 0
 
  Old_QDSTQDBT = 0
  Old_QDSTQCRT = 0
  Old_Q3STSIGN = 0
  Old_Q3STTERM = 0
  Old_Q3STCTHD = 0
  Old_Q3STPREP = 0
  Old_Q3STCOMM = 0
  Old_Q3STABRT = 0
 
 
  Old_MstrTcb =       0
  Old_MstrSrb =       0
  Old_MstrpSRB=       0
  Old_MstrpSRB_Ziip = 0
  Old_dbm1Tcb =       0
  Old_dbm1srb =       0
  Old_dbm1pSRB=       0
  Old_dbm1pSRB_Ziip = 0
  Old_irlmTcb =       0
  Old_irlmsrb =       0
  Old_irlmpSRB=       0
  Old_irlmpSRB_Ziip = 0
  Old_distTcb =       0
  Old_distsrb =       0
  Old_distpSRB=       0
  Old_distpSRB_Ziip = 0
 
 
  /* compteurs input/output */
  reco= 0
  reci= 0
  recs= 0
 
  displ=0
 
  min_date ='20990101'
  Max_date ='19700101'
  call dsndqist0
  call dsndqXst0
  call dsndqtst0
return
 
FLOOR: procedure
parse arg F
return TRUNC(F) - (F < 0) * (F <> TRUNC(F))
 
CEIL: procedure
parse arg C
return TRUNC(C) + (C > 0) * (C <> TRUNC(C))
/* convert 4K frames to MB */
f2mb:
 arg num
 num = format(num*4/1024,,2)
 return num
/* convert bytes to MB */
b2mb:
 arg num
 num = format(num/1048576,,0)
 return num
/*========================================== */
/* Set SMF data set name , depending on lpar */
/*========================================== */
SetDb2ToStart:
  oufl = 'systmp.wsyngud.smfexta'
  Select
       When lpar  = 'SUD2' then
            do
                ssid='DBAP'
            end
       When lpar  = 'XX10' then
            do
                ssid='DB2B'
            end
       When lpar  = 'XK01' then
            do
                ssid='DB2K'
            end
       When lpar  = 'LIM'   then
            do
                ssid='DBP1'
            end
       When lpar  = 'CTR'   then
            do
                ssid='DB2I'
            end
       When lpar  = 'LIM2' then
            do
                ssid='DBP2'
            end /* end Lpar XX10 Sofinco */
       When lpar  = 'LIM3' then
            do
                ssid='DBP3'
            end /* end Lpar XX10 Sofinco */
       When lpar  = 'LIM4' then
            do
                ssid='DBP8'
            end
       When lpar  = 'LIM5' then
            do
                ssid='DBP9'
            end
       When lpar  = 'MVSA' then
            do
                ssid='DB2P'
            end /* end Lpar CRPP  */
       When lpar  = 'IPOA' then
            do
                ssid='DSN3'
            end /* end Lpar CRPP  */
       When lpar  = 'IPO4' then
            do
                ssid='DSN2'
            end /* end Lpar CRPP  */
       When lpar  = 'OSJB' then
            do
                ssid='D2GH'
            end /* end Lpar  Prod CACIB */
       When lpar  = 'OSET' then
            do
                ssid='DB2T'
            end /* end Lpar  Prod CACIB */
       When lpar  = 'OSFA' then
            do
                ssid='D2FP'
            end /* end Lpar  Prod CACIB */
       When lpar  = 'ZPR1' then
            do
                ssid='DB2E'
            end /* end Lpar  Prod CASA  */
       When lpar  = 'ZDV1' then
            do
                ssid='DB2J'
            end
       When lpar  = 'DD20' then
            do
                ssid='DB2C'
            end /* end Lpar  DD20       */
       When lpar  = 'DJ02' then
            do
                ssid='DB2J'
            end /* end Lpar  DJ02       */
       When lpar  = 'XK01' then
            do
                ssid='DB2K'
            end /* end Lpar  XK01       */
       When lpar  = 'IPO1' then
            do
                ssid='DSNA'
            end /* end Lpar  IPO1       */
       When lpar  = 'IPO3' then
            do
                ssid='DSN3'
            end /* end Lpar  IPO3       */
       When lpar  = 'DEV'  then
            do
                ssid='DBD1'
            end /* end Lpar  DEV LCL    */
       When lpar  = 'I083' then
            do
                ssid='DBST'
            end /* end Lpar  I083 CAPS  */
       When wordpos(lpar,'SUD2 SUDB SUDM',
       ' PROD SUDM SUDF SUD1 PACI SUD3') > 0 then  nop
       Otherwise
            do
               say 'Lpar' lpar 'not processed - End of program'
               exit(0)
            end
  end   /* End select */
  return
init_summary:
       sum_MstrTcb      = dif_MstrTcb
       sum_MstrSrb      = dif_MstrSrb
       sum_MstrpSRB     = dif_MstrpSRB
       sum_MstrpSRB_Ziip =  dif_MstrpSRB_Ziip
       sum_dbm1Tcb      = dif_dbm1Tcb
       sum_dbm1Srb      =  dif_dbm1Srb
       sum_dbm1pSRB     =  dif_dbm1pSRB
       sum_dbm1pSRB_Ziip = dif_dbm1pSRB_Ziip
       sum_IrlmTcb      =  dif_IrlmTcb
       sum_IrlmSrb      =  dif_IrlmSrb
       sum_IrlmpSRB     =  dif_IrlmpSRB
       sum_IrlmpSRB_Ziip =  dif_IrlmpSRB_Ziip
       sum_DistTcb   =  dif_DistTcb
       sum_DistSrb   =  dif_DistSrb
       sum_DistpSRB  =  dif_DistpSRB
       sum_DistpSRB_Ziip =  dif_DistpSRB_Ziip
       sum_Q3STCTHD  =  dif_Q3STCTHD /* cr threads*/
       sum_Q3STSIGN  =  dif_Q3STSIGN /* Signon  */
       sum_Q3STTERM  =  dif_Q3STTERM /* Terminate*/
       sum_Q3STPREP  =  dif_Q3STPREP /* commit ph1*/
       sum_Q3STCOMM  =  dif_Q3STCOMM /* Commit Ph 2*/
       sum_Q3STABRT  =  dif_Q3STABRT /* Aborts */
       Max_Q3STHWIB = Q3STHWIB
       Max_Q3STHWIF = Q3STHWIF
       Max_Q3STHWCT = Q3STHWCT
       Max_QTDSOPN  = QTDSOPN
       SUm_QWSDCKPT=  dif_QWSDCKPT  /* Checkpoints */
       SUm_QXSTFND =  dif_QXSTFND   /* Prepare     */
       SUm_QXSTNFND=  dif_QXSTNFND
       SUm_QXSTIPRP=  dif_QXSTIPRP
       SUm_QXSTNPRP=  dif_QXSTNPRP
       SUm_QXNSMIAP=  dif_QXNSMIAP
       SUm_QXMRMIAP=  dif_QXMRMIAP
       SUm_QXWFRIDS=  dif_QXWFRIDS
       SUm_QXWFRIDT=  dif_QXWFRIDT
       SUm_QXHJINCS=  dif_QXHJINCS
       SUm_QXHJINCT=  dif_QXHJINCT
       SUm_QXSISTOR=  dif_QXSISTOR
     if  QWHSRN > 'B1' then do     /* V12*/
       SUm_QXRFMIAP=  dif_QXRFMIAP
       SUm_QXRWSINSRTDAlg1=dif_QXRWSINSRTDAlg1
       SUm_QXRWSINSRTDAlg2=dif_QXRWSINSRTDAlg2
     end
       Sum_QTDSDRN =  dif_QTDSDRN   /* Drain Close */
       Sum_QTPCCT  =  dif_QTPCCT    /* RWRO switch */
       Sum_QTABINDA=  dif_QTABINDA
       Sum_QTABIND =  dif_QTABIND
       Sum_QTAUCHK =  dif_QTAUCHK
       Sum_QTAUSUC =  dif_QTAUSUC
       Sum_QTAUCCH =  dif_QTAUCCH
       Sum_QTPACAUT=  dif_QTPACAUT
       Sum_QTPACNOT=  dif_QTPACNOT
       Sum_QTAUTOBA=  dif_QTAUTOBA
       Sum_QTPKABND=  dif_QTPKABND
       SUm2_QBSTDSO =  dif_QBSTDSO   /* Open DS*/
       sum2_QBSTGET = dif_QBSTGET /* gp */
       sum2_QBSTRIO = dif_QBSTRIO /* sync read */
       sum2_QBSTIMW = dif_QBSTIMW /* Immed. write */
       sum2_QBSTWIO = dif_QBSTWIO /* Async Write */
       sum2_QBSTRPI = dif_QBSTRPI /* Async Write */
       sum2_QBSTWPI = dif_QBSTWPI /* Async Write */
       sum2_QBSTPIO = dif_QBSTPIO /* Seq Pref. IO */
       sum2_QBSTCIO = dif_QBSTCIO /* Castout IO */
       sum2_QBSTDIO = dif_QBSTDIO /* Dyn Pr IO */
       sum2_QBSTLIO = dif_QBSTLIO /* Lst Pr IO */
       sum2_QBSTSIO = dif_QBSTSIO /* SIO */
       Max_QDSTQMIT = QDSTQMIT
       Max_QDSTHWAT = QDSTHWAT
       Max_QDSTHWDT = QDSTHWDT
       Max_QDSTMIN2 = QDSTMIN2
       Max_QW0225AT = QW0225AT
       MinThdcomp  = Thdcomp
       Max_TotalRealUsedByDB2 = TotalRealUsedByDB2
       Max_TotalAuxlUsedByDB2 = TotalAuxlUsedByDB2
       min_QW0225_REALAVAIL = QW0225_REALAVAIL
       Max_QW0225RG         = QW0225RG /* Region Size extended */
       Min_QW0225AV         = QW0225AV
       sum_QISTCOLS=  dif_QISTCOLS /* Cols not optimized*/
       sum_QISTWFP1=  dif_QISTWFP1 /* 32KbUsed4Pref.*/
       sum_QISTWFP2=  dif_QISTWFP2 /* 4KbUsed32Prf*/
       sum_QJSTBFFL=  dif_QJSTBFFL /* Log created*/
       sum_QJSTWTB =  dif_QJSTWTB
       /* init read i/o for individual BP */
       do i=1 to nbBP
          bpn=BpList.i
          sum_QBSTRIO.bpn = dif_QBSTRIO.bpn
          sum_QBSTRPI.bpn = dif_QBSTRPI.bpn
          sum_QBSTWPI.bpn = dif_QBSTWPI.bpn
       end
  return
DSNDQWSD:
    /* Nbr of checkpoints cumulative value */
    QWSDCKPT = C2D(SUBSTR(InpRec,Ofs,4))
 return
 
Check_counters:
    sum_dbm1SrbX = sum_dbm1Srb  + sum_dbm1Psrb + sum_dbm1Psrb_ziip
    /*
    /* Only for SUD2 */
    if lpar = 'SUD2'   then
    do
        SumBP_SUD2_all = sum2_QBSTGET + SumBP_SUD2_all
        /* record Max getpage */
        if  sum2_QBSTGET > Max_SUD2_gp then do
                Max_SUD2_gp = sum2_QBSTGET
                Max_SUD2_gp_hour = Old_Hour
            end
        /* record activity between 9-18 */
        if (Old_Hour > '08' & Old_Hour < '19') then
             do
               SumBP_SUD2 = sum2_QBSTGET + SumBP_SUD2
               if sum2_QBSTGET < 1000000 then,
                      SUD2_BpInact = SUD2_BpInact + 1
             end
        return
    end
    */
    /* Global Dynamic Stmt cache hit ratio > 90% */
    /* prepare ...*/
    SumPrep = Sum_QXSTFND+Sum_QXSTNFND
    TotPrep = TotPrep+SumPrep
    if SumPrep > 899 then /* No calculation if not significant*/
    do
      DDFUSage=1
      Hit = Sum_QXSTFND / (SumPrep + 0.01)
      if Hit < 0.89  &    SumPrep >  9999 then
           do
             rec.1= 'Global Dyn. Cache Hit < 90%',
             format(Hit,3,2) '@' run_fmt_time '#Prepare:'SumPrep
             if  (Old_Hour > '07' & Old_Hour < '20') ! DispAll then
             do
                MsgType='GLO'
                ReportFlag=1
                call logw
                retcode=4
             end
             else say rec.1
           end
      /* Record Min Max */
      if Hit < HitMinGlobal then do
                               HitMinGlobal=Hit
                               TimeMinGlobal=run_fmt_time
                               PrepMinGlobal=SumPrep
                            end
      if Hit > HitMaxGlobal then do
                               HitMaxGlobal=Hit
                               TimeMaxGlobal=run_fmt_time
                               PrepMaxGlobal=SumPrep
                            end
    /* Local  Dynamic Stmt cache hit ratio > 70% */
    /* with KEEPDYNAMIC(YES) */
    /* Source Optimizing DB2 System Performance using DB2 statistics*/
    /* Avoided Prepared / (Avoided Prepare + Implicit Prepare ) */
    SumPrep= (Sum_QXSTNPRP + Sum_QXSTIPRP )
    Hit = Sum_QXSTNPRP/ (SumPrep + 0.01)
    if Hit = 0   then do
           if tsaylocal=0 then do
             MsgType='LOC'
             ReportFlag=9
             LocalDynCache=0
             rec.1= 'Local Dyn. Cache probably not used.',
                    'Zero Avoided Prepare in statistics'
             call LOgw
             tsayLocal = 1
           end
    end
    else if Hit < 0.69 then
         do
           MsgType='LOC'
           ReportFlag=1
           rec.1= 'Local Dyn. Cache Hit < 70%',
              format(Hit,3,2) '@' run_fmt_time '#Prepare:'SumPrep
           call logw
           retcode=4
         end
    /* Record Min Max */
    if Hit < HitMinLocal  then do
                             HitMinLocal=Hit
                             TimeMinLocal=run_fmt_time
                          end
    if Hit > HitMaxLocal  then do
                             HitMaxLocal =Hit
                             TimeMaxLocal=run_fmt_time
                          end
    end  /* End SumPage < 100 */
    /* DBM1 time */
    if (sum_dbm1Tcb*3) > sum_dbm1SrbX & sum_dbm1Tcb > 50  then do
        MsgType='DBM'
        ReportFlag=1
        rec.1= 'DBM1 TCB time too high vs DBM1 SRB ',
               'Hour/DBM1TCB/DBM1SRB ' Old_Hour sum_dbm1TCB,
                sum_dbm1SRBX
        if  (Old_Hour > '07' & Old_Hour < '20') ! DispAll then
           call LOGW
        else say rec.1
    end
    /* Wrk 32K used 4k preferred  */
    if sum_QISTWFP1 > 0   then do
        MsgType='WK4'
        ReportFlag=1
        rec.1= 'Workfile 32K used, 4K preferred but nor available.',
               'Hour' Old_Hour '#'sum_QISTWFP1
        call LOGW
    end
    /* Wrk 4k used 32k preferred  */
    if sum_QISTWFP2 > 0   then do
        MsgType='WK3'
        ReportFlag=1
        rec.1= 'Workfile 4K used, 32K preferred but not available.',
               'Hour' Old_Hour '#'sum_QISTWFP2
        call LOGW
    end
 
    /* Checkpoint frequency */
    if sum_QWSDCKPT > 39             then  do
       MsgType='CHK'
       rec.1= 'Checkpoint frequency > 1chkp/3-5mn',
              '@Hour:' Old_Hour,
              '#Checkpoint:' sum_QWSDCKPT,
              'MSTRTcb:' sum_MstrTcb
       ReportFlag=1
       call LOGW
    end
    /* Drain close DSMAX */
    if sum_QTDSDRN  > 1  &,
       (Old_Hour > '07' & Old_Hour < '20')  then
    do
       rec.1= 'DSMax reached during Online',
            '@Hour:' Old_Hour,
            'DrainClose:' sum_QTDSDRN,
            'DBM1Tcb:' sum_dbm1Tcb,
            'DBM1Srb:' sum_dbm1SrbX
       if   sum_dbm1Tcb > 50 ! DispAll then
       do
          MsgType='DSM'
          ReportFlag=1
          call LOGW
       end
       else say rec.1
    end
    /*Specific to v12 maintenance */
    if  QWHSRN > 'B1' then do     /* V12*/
      /* RID List not used */
      if Sum_QXRFMIAP > 1  then
      do
         rec.1= 'RIDList processing not used',
              '@Hour:' Old_Hour,
              '#:' QXRFMIAP
         MsgType='RID'
         ReportFlag=1
         call LOGW
      end
    end
    /* RW/RO switch */
    if sum_QTPCCT   > 3600  then do
       rec.1= 'RWRO switch > 60/mn',
              '@Hour:' Old_Hour,
              'ROSwitch/mn:' format(sum_QTPCCT/60,4,0)
       if  (Old_Hour > '07' & Old_Hour < '20') ! DispAll then
       do
         MsgType='RWRO'
         ReportFlag=1
         call LOGW
       end
       else say rec.1
    end
    /* Autobind plans */
    temp=sum_QTABINDA-sum_QTABIND
    if temp > 1 & LparProd & clnt <> 'LCL' then
    do
       rec.1= 'Autobind plans failed',
              '@Hour:' Old_Hour,
              '#:' temp
       MsgType='AUTB'
       ReportFlag=1
       call LOGW
    end
    /* Autobind packs */
    temp=sum_QTAUTOBA-sum_QTPKABND
    if temp > 1 & LparProd & clnt <> 'LCL' then
    do
       rec.1= 'Autobind packages failed',
              '@Hour:' Old_Hour,
              '#:' temp
       MsgType='AUTP'
       ReportFlag=1
       call LOGW
    end
    /* Pack auth      */
    If Sum_QTPACAUT > 1000 then
    do
       Hit =Hit= 1- sum_QTPACNOT/(sum_QTPACAUT+0.01)
       if Hit < 0.7 & LparProd & Hit > 0 then
       do
          rec.1= 'Pack cache hit too low',
                 '@Hour:' Old_Hour,
                 'Hit:'strip(format(Hit,4,2)),
                 '-OK W/o cache:'Sum_QTPACNOT,
                 '-Success:'Sum_QTPACAUT
          MsgType='AUTH'
          ReportFlag=1
          if LparProd then call LOGW
          else say rec.1
       end
    end
    /* Plan auth      */
    If Sum_QTAUCHK > 1000 then
    do
      Hit= Sum_QTAUCCH/(Sum_QTAUSUC+0.01)
      if Hit < 0.6 &   Hit > 0 then
      do
         rec.1= 'Plan cache hit too low',
                '@Hour:' Old_Hour,
                'Hit:'strip(format(Hit,4,2)),
                '-OK W/ cache:'Sum_QTAUCCH 'Success:'Sum_QTAUSUC,
                'Total checks:' Sum_QTAUCHK
         MsgType='AUTH'
         ReportFlag=9
         if LparProd then call LOGW
         else say rec.1
      end
    end
    /* Check Page In for each BP */
    do i=1 to nbBP
          bpn=BPList.i
          /* threshold id 1000 IO/s */
          if (sum_QBSTRPI.bpn + sum_QBSTWPI.bpn) >  100 &,
          LparProd &,
          sum_QBSTRIO.bpn > 3600000  then /* > 1000IO/s */
          do
            MsgType='PAG'
            bpnm=TranslateBP(bpn)
            rec.1=bpnm 'PageIn observed @hour:'Old_Hour,
            '#PageInR/PageInWr:'sum_QBSTRPI.bpn'/'sum_QBSTWPI.bpn,
            'SyncIO/s:'format(sum_QBSTRIO.bpn/3600,,0)
            ReportFlag=1
            call LOGW
          end
    end
 
    /* Bypassed columns - Invalid Select Procedure */
    if (sum_QISTCOLS )               >  500 then do
       MsgType='INV'
       ReportFlag=9 /* ne pas envoyer attente alerte attente rebind */
       rec.1= 'Not optimized SProc observed at hour:' !!,
            Old_Hour 'Total:'sum_QISTCOLS
       call LOGW
    end
 
  /* GBP counters */
      h=1
      do while h <= nbGBP
         i = GBPList.h
         h=h+1
         /* Calcul XI Read Ratio */
         Ratio = SumHr_QBGLXD.i / (SumHr_QBGLXR.i+SumHr_QBGLXD.i+1)
         ratio = format(ratio,,2) /* presentation 2 chiffres*/
         /* Exclude Batch period */
         if Ratio < 0.6  & Ratio > 0 & sum_QBSTRIO.i>3600000 &,
             Old_Hour > 8  & Old_Hour < 19 & ssid <> 'DBP9' then
             do
                MsgType='XI'
                ReportFlag=1
                bpnm=TranslateBP(i)
                rec.1= 'G'bpnm 'XI Read ratio < 50%',
                  sm100sid'/'sm100ssi '@'Old_Hour Ratio*100 !! '%',
                 'XI ReadNfd/s' format(SumHr_QBGLXR.i/3600,,0),
                 'SyncIO/s:' format(sum_QBSTRIO.i/3600,,0),
                call logW
             end
         if SumHr_QBGLWF.i > 0    then
             do
                MsgType='GBP'
                ReportFlag=1
                bpnm=TranslateBP(i)
                rec.1= 'G'bpnm 'Write GBP NoStorage',
                  sm100sid'/'sm100ssi '@'Old_Hour SumHr_QBGLWF.i
                call logW
             end
 
          SumHr_QBGLWF.i=0
          SumHr_QBGLXD.i=0
          SumHr_QBGLXR.i=0
      end  /* End do */
 
    return
LOGW:
     say rec.1
     if ReportFlag>1 then return /* No file report if not set */
     ReportFlag=9 /* No file report is the default */
     nbmsg = nbmsg+1
     logtxt.nbmsg= rec.1 ; logtype.nbmsg=MsgType
     /* record MsgType met */
     imax = words(ListMsgType)
     DO Il=1 TO imax
         if Msgtype = word(ListMsgType,il)
         then leave
     end
     if il > imax then ListMsgType = ListMsgType MsgType
     return
/* End of program report all messages by group */
FlushLog:
     imax = words(ListMsgType)
     Do I=1 TO imax
       Msgtype = word(ListMsgType,i)
       Do j=1 TO nbmsg
         if Msgtype = logtype.j then
         do
             rec.1=logtxt.j
             "EXECIO 1 DISKW OUFw  (STEM rec. "
         end
       end
     end
     return
/* for SUD2 */
LOGW2:
     say rec.1
     "EXECIO 1 DISKW OUFs2 (STEM rec. "
    return
LOGWS:
     say rec.1
     "EXECIO 1 DISKW OUFWS (STEM rec. "
    return
 
/* Report dataset on output */
CrOutput:
    ope = 1
    /* caagis ssid forced to some value */
    if clnt = 'CAAGIS' & Already_here=0 then
    do
          Already_here=1
          Select
            when sm100ssi = 'DBPR' ! sm100ssi = 'DBAP'  then
            do
                lpar='SUDM'
                ssid='DBPR'
            end
            when sm100ssi = 'DB2I' ! sm100ssi = 'DB2V'  then
            do
                lpar='SUDB'
                ssid='DB2I'
            end
            when sm100ssi = 'DB2Q' ! sm100ssi = 'DB2G' ,
               ! sm100ssi = 'DPE3' ! sm100ssi = 'DPD3' then
            do
                lpar='SUDF'
                ssid='DB2Q'
            end
            when sm100ssi = 'DB2C' ! sm100ssi = 'DB2A'  then
            do
                lpar='PROD'
                ssid='DB2A'
            end
            otherwise say 'sm100ssi not found' sm100ssi
          end
    end
    oufL = "'" !! hlq !! '.reportS.' !! lpar !! '.' !! ssid !! "'"
      X=outtrap(tmp.)
      "DELETE" oufL "PURGE"
      X=outtrap(off)
    say 'Allocate' oufL
    /* if with header */
    if OPT2 = 'H' then
      "ALLOC FI(OUFL) DA("oufL") NEW CATALOG REUSE" ,
      "LRECL(900) RECFM(V B) TRACKS SPACE(5,1) RELEASE"
    else
      "ALLOC FI(OUFL) DA("oufL") NEW CATALOG REUSE" ,
      "LRECL(500) RECFM(V B) TRACKS SPACE(5,1) RELEASE"
    rcalloc = rc
    if rcalloc <> 0 then Do
         say "**********************************************"
         say "   Error allocating report file" rcalloc
         say "   Abnormal end  "
         say "**********************************************"
         Exit 8
    end
    ADDRESS TSO "DELSTACK"
    /* WRITE report header */
       if OPT2 = 'H' then
        CALL write_header
    /* Report warning messages  */
    oufw = "'" !! hlq !! '.reportsw.' !! lpar !!'.' !! ssid !! "'"
    X=OUTTRAP(TMP.)
    "DELETE" oufw "PURGE"
    X=OUTTRAP(OFF)
    "ALLOC FI(OUFw) DA("oufw") NEW CATALOG" ,
    "LRECL(130) RECFM(F B) TRACKS SPACE(5,5) RELEASE"
    rcalloc = rc
    if rcalloc <> 0 then Do
         say "**********************************************"
         say "   Error allocating report warnings file" rcalloc
         say "   Abnormal end  "
         say "**********************************************"
         Exit 8
    end
    oufws= "'" !! hlq !! '.reportmi.' !! lpar !!'.' !! ssid !! "'"
    X=OUTTRAP(TMP.)
    "DELETE" oufws "PURGE"
    X=OUTTRAP(OFF)
    "ALLOC FI(OUFWS) DA("oufws") NEW CATALOG" ,
    "LRECL(130) RECFM(F B) TRACKS SPACE(5,5) RELEASE"
    rcalloc = rc
    if rcalloc <> 0 then Do
         say "**********************************************"
         say "   Error allocating report migration file" rcalloc
         say "   Abnormal end  "
         say "**********************************************"
         Exit 8
    end
    /* quelques mots de presentation */
    Msgtype = 'BEG'
    ReportFlag=1
    rec.1= '*********************'
    call logW
    ReportFlag=1
    rec.1= 'Lpar:' sm100sid  'SSID:' ssid
    call logW
    ReportFlag=1
    rec.1= '*********************'
    call logW
    ReportFlag=1
    rec.1= ''
    call logW
    /*
    /* Only SUD2 report BP usage Generate ALTER BP command */
    if lpar = 'SUD2' & temX=0 then
    do
      temX=1
      oufs2= "'" !! hlq !! '.reportsw.alrt2' !! "'"
      say 'Output to' oufs2
      X=OUTTRAP(TMP.)
      "DELETE" oufs2 "PURGE"
      x=OUTTRAP(OFF)
      "ALLOC FI(OUFs2) DA("oufs2") NEW CATALOG REUSE" ,
      "LRECL(80) RECFM(F B) TRACKS SPACE(2,2) RELEASE"
      rcalloc = rc
      if rcalloc <> 0 then Do
        say "**********************************************"
        say "   Error allocating report warnings bp file" rcalloc
        say "   Abnormal end  "
        say "**********************************************"
        Exit 8
      end
    end /* SUD2*/
    */
    rec.1= ''
    call logw
    rec.1= '*** Processing for Subsys ***' ssid lpar
    call logw
return
 
/*-----------------------------------------*/
/* Specific for lpar SUD2 : Check BP usage */
/*-----------------------------------------*/
SUD2_report_bp_usage:
  Msgtype = 'BP'
  /* report usage activity */
  rec.1= ''
  call LOGW
  rec.1 = 'BP Usage report :'
  call LOGW
  /* compute average usage */
  SUD2avg_bp_all  = SumBP_SUD2 % 24
  rec.1 = ,
         'SUD2: ' ssid 'has BP inact - avg gp/h :' SUD2avg_bp_all
  call LOGW
  rec.1 = ,
         '              Max gp/h observed :' Max_SUD2_gp ' at ',
                                             Max_SUD2_gp_hour
  call LOGW
  rec.1 = ,
         '              avg gp/h office hours:' SUD2avg_bp
  call LOGW
  rec.1='  SUD2 avg getpage for 00:00-2359   :' SUD2avg_bp_all
  call logW
  SUD2avg_bp = SumBP_SUD2 % 10
  rec.1='  SUD2_BpInact hours from 9:00-18:00:' SUD2_BpInact
  call logW
  rec.1='  SUD2avg getpage during 9:00-18:00 :' SUD2avg_bp
  call logW
  /********************/
  /*  SET VPSIZE PART */
  /********************/
 
  /* important activity observed all day */
  if SUD2avg_bp_all > 2000000 &  bp0_vpsize < 55000 then
  do
        rec.1 ='BP probably small vs. observed activity, recommend :'
        call LOGW2
        rec.1 ='DSN SYSTEM('ssid')'
        call LOGW2
        rec.1 ='-ALTER BPOOL(BP0) VPSIZE(300000)'
        call LOGW2
        rec.1 ='-ALTER BPOOL(BP1) VPSIZE(100000)'
        call LOGW2
        return
  end
 
  /* Max gp/hour high at somes time => higher a little */
  if Max_SUD2_gp > 5000000 & bp0_vpsize < 55000 then
     do
        rec.1 ='DSN SYSTEM('ssid')'
        call LOGW2
        rec.1 ='-ALTER BPOOL(BP0) VPSIZE(100000)'
        call LOGW2
        return
     end
  /* Not enough activity */
  if Max_SUD2_gp < 5000000 & bp0_vpsize > 55000 then
     do
          rec.1 ='DSN SYSTEM('ssid')'
          call LOGW2
          rec.1 ='-ALTER BPOOL(BP0) VPSIZE(50000)'
          call LOGW2
          return
     end
return
/*---------------------------------------*/
/* Date functions from Chuck Meyer paper */
/*---------------------------------------*/
/* yyyymmdd => weekday */
DAT_S2DOW: Procedure
Parse Arg 1 yyyy +4 mm +2 dd +2 .
f = yyyy + (mm-14)%12
w = ((13*(mm+10-(mm+10)%13*12)-1)%5+dd+77 ,
+ 5 * (f - f%100*100)%4 + f%400 - f%100*2) //7
Return WORD('Sun Mon Tue Wed Thur Fri Sat',w+1)
/*---------------------*/
/* Is this leap year ? */
/*---------------------*/
LY?: Procedure
Parse Arg 1 y +4
Return ((y//4)=0)
/*---------------------*/
/* yyyyddd => yyyymmdd */
/*---------------------*/
DAT_MVS2SD: Procedure
Parse Value REVERSE(arg(1)) With 1 j +3 y
Parse Value REVERSE(j y) With y j
If LENGTH(y) = 2 Then y = YY2YYYY(y)
months = '31' (28 + LY?(y)) ,
'31 30 31 30 31 31 30 31 30 31'
Do m = 1 To 12 While j > WORD(months,m)
j = j - WORD(months,m)
End
Return RIGHT(y,4,0) !! RIGHT(m,2,0) !! RIGHT(j,2,0)
 
DisplayHighRandWk:
    Call ListWBP
    /* Merge pass degraded */
    title=0
    i=1
    do while i <= nbBP
       j=BPList.i
       /* valeur seuil pour d' j ay 500 */
       If MergePassDegr.j > 20   & wordpos(j,ListWBP) > 0 then
       do
         /* Display title */
         if title=0 then
         do
            Msgtype = 'MERG'
            ReportFlag=1
            rec.1= 'Merge Pass degraded Low Buffers report:'
            call logW
            title=1
         end
         bpnm=TranslateBP(j)
         rec.1= bpnm MergePassDegr.j
         ReportFlag=1
         call logW
       end
       i=i+1
    end
    /* Workfile Req. rejected */
    title=0
    i=1
    do while i <= nbBP
       j=BPList.i
       /* valeur seuil 500 */
       If WrkfileReqRej.j > 20  & wordpos(j,ListWBP) > 0   then
       do
         /* Display title */
         if title=0 then
         do
            MsgType='REJ'
            ReportFlag=1
            rec.1= 'Workfile requests rejected report:'
            call logW
            title=1
         end
         ReportFlag=1
         bpnm=TranslateBP(j)
         rec.1= bpnm WrkfileReqRej.j
         call logW
       end
       i=i+1
    end
    /* Workfile Prefetch Not scheduled */
    title=0
    i=1
    do while i <= nbBP
       j=BPList.i
       /* valeur seuil 500 */
       If WfPrfNotSch.j > 20  & wordpos(j,ListWBP) > 0     then
       do
         /* Display title */
         if title=0 then
         do
            MsgType='PRF'
            ReportFlag=1
            rec.1= 'Workfile Prefetch Not scheduled report:'
            call logW
            title=1
         end
         ReportFlag=1
         bpnm=TranslateBP(j)
         rec.1= bpnm WfPrfNotSch.j
         call logW
       end
       i=i+1
    end
    /* Prefetch buffers not optimized for full conditions */
    /*
    title=0
    i=1
    do while i <= nbBP
       j=BPList.i
       /* 4K ?*/
       If  j < 80 then
       do
         /* vpseqt buffer > 320 MB (V11) or 450 MB (V12) */
         if  QBSTSMAX.j < 81920 & QBSTVPL.j > 81000 &,
                             LparProd =1 then
         do
             MsgType='SEQ'
             /* Display title */
             if title=0 then
             do
                ReportFlag=9 /* ne pas signaler pour l'instant */
                rec.1= 'Seq. buffers < 320MB(81920 pages)V11',
                       'should be > for best pref. operations'
                call logW
                title=1
             end
             ReportFlag=1
             bpnm=TranslateBP(j)
             rec.1= bpnm 'SEQ:'QBSTSMAX.j 'VPSIZE:'QBSTVPL.j
             call logW
         end
       end
       i=i+1
    end
                  */
    /* Workfile not created no buffer */
    title=0
    i=1
    do while i <= nbBP
       j=BPList.i
       if  QBSTMAX.j > 0      then
        do
             MsgType='WRK'
             /* Display title */
             if title=0 then
             do
                ReportFlag=1
                rec.1= 'Workfile not created no buffer'
                call logW
                title=1
             end
             ReportFlag=1
             bpnm=TranslateBP(j)
             rec.1= bpnm ':'QBSTMAX.j
             call logW
       end
       i=i+1
    end
    /* WF Bufferpols with a High Random reads vs Prefetch*/
    title=0
    i=1
    do while i <= nbBP
       j=BPList.i
       /* Sort BP= SRLU >= 85% vpsize */
       /* traduit par  QBSTSMAX.j > (0.9*QBSTVPL.j) */
       /* si c'est un BP Sort */
       If wordpos(j,ListWBP) > 0  then
       do
         /* seuil de display 1800*/
         if  WfSyncHigh.j > 1800 then /* 3600 = 1 hour */
         do
             MsgType='RAN'
             /* Display title */
             if title=0 then
             do
                ReportFlag=1
                rec.1= 'List of WF Bufferpols with a ',
                       'High Random reads vs Prefetch'
                call logW
                title=1
             end
             ReportFlag=1
             bpnm=TranslateBP(j)
             rec.1= bpnm WfSyncHigh.j 'times with SyncIO/s >1000'
             call logW
         end
       end
       i=i+1
    end
return
/********************************************/
/* Display Dynamic Cache statistics         */
/********************************************/
DisplayDynStats:
    MsgType='GLO'
    hit=TotPrep/24
    if TotPrep < 7200 then /* less than 300 / hour */
    do
         ReportFlag=1
         rec.1= 'Dynamic SQL usage (DDF) not significant.'
         call logW
         ReportFlag=1
         rec.1= 'Average Prepare Executed / hour :',
                       format(Hit,9,0)
         call logW
         return
    end
    If DDFUsage then
    do
      ReportFlag=2
      rec.1= 'Max Dynamic Stmt Global Cache Hit :',
        format(HitMaxGlobal,3,2) '@' TimeMaxGlobal,
        'for #Prepare:' PrepMaxGlobal
      call logW
      ReportFlag=2
      rec.1= 'Min Dynamic Stmt Global Cache Hit :',
        format(HitMinGlobal,3,2) '@' TimeMinGlobal,
        'for #Prepare:' PrepMinGlobal
      call logW
    end
    ReportFlag=2
    rec.1= 'Average Prepare Executed / hour :',
      format(Hit,9,0)
    call logW
    if LocalDynCache = 1  & DDFUsage then
    do
       ReportFlag=1
       rec.1= 'Max Dynamic Stmt Local Cache Hit :',
      format(HitMaxLocal,3,2) '@' TimeMaxLocal
       call logW
       ReportFlag=1
       rec.1= 'Min Dynamic Stmt Local Cache Hit :',
      format(HitMinLocal,3,2) '@' TimeMinLocal
       call logW
    end
    return
/********************************************/
/* Display list of BP with Pref problems    */
/********************************************/
DisplayPref:
    title=0
    MsgType='WPRF'
    i=1
    do while i <= nbBP
       j=BPList.i
       /* valeur minimal to display = 50  */
       if  PrefQtyLow.j > 1800  & wordpos(j,ListWBP) > 0 then
       do
              /* Display title */
              if title=0 then
              do
                 ReportFlag=1
                 rec.1= 'List of WK Buf. Pools with',
                        'a low Prefetch Quantity'
                 call logW
                 title=1
              end
              ReportFlag=1
              bpnm=TranslateBP(j)
              rec.1= bpnm PrefQtyLow.j 'times with SyncIO/s >1000'
              call logW
       end
       /* valeur minimal to display = 50   */
       if  ConPfRej.j > 50       > 0 then
       do
                  /* Display title */
                  if title=0 then
                  do
                     ReportFlag=1
                     rec.1= 'List of Bufferpols with concurrent',
                            'Prefetch denied due to lack of buffers'
                     call logW
                     title=1
                  end
                  ReportFlag=1
                  rec.1= bpnm ConPfRej.j
                  call logW
       end
       /* next BP*/
       i=i+1
    end
return
TranslateBP: procedure
arg j
     Select
             When j >='0'   & j <= '50'    Then bpnm = 'BP'j
             When j >='100' & j <= '109'   Then do
                                                  k    = j-100
                                                  bpnm = 'BP8K'k
                                                end
             When j >='120' & j <= '129'   Then do
                                                  k    = j-120
                                                  bpnm = 'BP16K'k
                                                end
             When j >='80'  & j <= '89'    Then do
                                                  k    = j-80
                                                  if k=0 then
                                                  bpnm = 'BP32K' else
                                                  bpnm = 'BP32K'k
                                                end
             Otherwise do
                         say 'Buffer pool ID ??? 'j
                         bpnm = '?'j
                       end
        end
 return(bpnm)
dsndqist0:
    QISTCOLS = Old_QISTCOLS
    QISTWFP1 = Old_QISTWFP1
    QISTWFP2 = Old_QISTWFP2
    QISTW4K  = 0
    QISTW32K = 0
    QISTAMXU =  0
    QISTDGTTMXU = 0
    QISTWFMXU = 0
return
dsndqXst0:
     QXSTFND  = Old_QXSTFND
     QXSTNFND = Old_QXSTNFND
     QXSTIPRP = Old_QXSTIPRP
     QXSTNPRP = Old_QXSTNPRP
     QXNSMIAP = Old_QXNSMIAP
     QXMRMIAP = Old_QXMRMIAP
     QXWFRIDS = Old_QXWFRIDS
     QXWFRIDT = Old_QXWFRIDT
     QXHJINCS = Old_QXHJINCS
     QXHJINCT = Old_QXHJINCT
     QXSISTOR = Old_QXSISTOR
   if  QWHSRN > 'B1' ! QWHSRN=' ' then do     /* V12*/
     QXRFMIAP = Old_QXRFMIAP
     QXRWSINSRTDAlg1=Old_QXRWSINSRTDAlg1
     QXRWSINSRTDAlg2=Old_QXRWSINSRTDAlg2
   end
return
dsndqtst0:
    QTDSOPN  =  Old_QTDSOPN
    QTDSDRN  =  Old_QTDSDRN
    QTPCCT   =  Old_QTPCCT
return
LogAlert:
/* Report warning messages , will be sent to Outlook Alert */
/* at 8:30 */
     oufwm= "'" !! hlq !! '.reportsw.' !! 'ALRT' !! "'"
     i =1
     /* Try to allocate 5 times */
     do until i > 5
       "ALLOC FI(OUFwm) DA("oufwm") MOD CATALOG " ,
       "LRECL(130) RECFM(F B) TRACKS SPACE(5,5) RELEASE"
       i=i+1
       if rc <> 0 then call MySleep 5
       else leave
     end
     if rc <> 0 then exit(8)
     rec.0=1
     "EXECIO 1 DISKW OUFwm (FINIS STEM rec. "
     "FREE DD(OUFWm)"
    return
/* reinit some data before processing another SSID */
raz_data:
    i=1
    do while i <= nbBP
       QBSTSMAX.i  = 0
       i=i+1
    end
return
Listwbp:
    ListWBP=''
    select
       when,
         wordpos(lpar,'SUD2 SUDB SUDM',
                 ' PROD SUDM SUDF SUD1 PACI SUD3') > 0 then
            do
                   ListWBP = '7 87'
                   return
            end
       when lpar=  'LIM'  then
            do
                   ListWBP = '48 88' /* BP48 et BP32K8*/
                   return
            end
       when lpar=  'OSJB'  then
            do
                   ListWBP = '1 81'
                   return
            end
       otherwise nop
      end
    /* DIS BPOOL command */
    say "-DIS BPOOL(active)"
    ADDRESS TSO "DELSTACK"
    QUEUE "-DIS BPOOL(active)"
    QUEUE "END"
    X=OUTTRAP(TP.)
    ADDRESS TSO "DSN SYSTEM("ssid")"
    ADSN_COD=RC
    X=OUTTRAP(OFF)
    if adsn_cod > 0 then
    do
        say 'Error submitting DB2 command'
        x=DispWBP(ListWBP)
        return
    end
    /* Process command output */
    k=1
    ErrorGBP=0
    DO while k <=  TP.0
       say tp.k
       select
            /*display une seule fois date statistics incremental*/
            when word(tp.k,1)='DSNB401I'          then
                    temp= word(tp.k,8)
            when word(tp.k,1)='VP' & word(tp.k,2)='SEQUENTIAL' &,
                    word(tp.k,4) > 80 then
                    do
                     temp=substr(temp,1,length(temp)-1)
                     ListWBP = ListWBP temp
                    end
            otherwise nop
       end  /* end select */
       k=k+1
    END
    say 'List WBP' ListWBP
    x=DispWBP(ListWBP)
return
DispWBP: procedure
arg ListWBP
   Lst=''
   DO I=1 TO words(ListWBP)
     bnm= TranslateBP(word(ListWBP,I))
     Lst  = Lst bnm
   end
   say 'Workfile Buffer Pools :' Lst
   return(0)
CheckValues:
    if Dif_QDSTQDBT    > 0 & Already_DSNDQDST then
    do
      ReportFlag=1
      rec.1= sm100sid'/'sm100ssi,
         'MAXDBAT reached, DBAT queued :',
         Dif_QDSTQDBT ' @' run_fmt_time
      call LogAlert
      call LogW
    end
    if Dif_QDSTQCRT    > 0 & Already_DSNDQDST then
    do
      ReportFlag=1
      rec.1= sm100sid'/'sm100ssi,
         'CONDBAT reached, Connections rejected :',
         Dif_QDSTQCRT ' @' run_fmt_time
      call LogAlert
      call LogW
    end
    if QDSTNQR2 > 0 & QDSTNQAV > 0.5  then
    do
      ReportFlag=1
      rec.1= sm100sid'/'sm100ssi,
         'Type2 Inactive threads queued too long:' ,
         QDSTNQR2 ' @' run_fmt_time 'Avg wait:'QDSTNQAV
      call logAlert
      call LogW
    end
return
MySleep: procedure
      arg sleeptime
      Say 'Sleep for' sleeptime 'seconds'
      call syscalls 'ON'
      address syscall 'sleep ' sleeptime
      call syscalls 'OFF'
return

/*REXX*/
numeric digits 15
Say '***************************************'
Say '   SMF DECODER FOR IIDR CDC Z 11.4     '
Say '***************************************'
/*-------------------------------------------------------------*/
/* Extract SMF records of IIDR CDC   by Nguyen Duc Tuan        */
/*                                      ndt.db2àgmail.com      */
/* Developed and tested on Db2 V12-CDC 11.4  z/OS              */
/*                                                             */
/*  26 May 2020     First release                              */
/*-------------------------------------------------------------*/
/*Comment : Change datasets high level identifier              */
/*-------------------------------------------------------------*/
Arg SmfType ssid Hlq
retcode=0
/* ssid is the STC name */
say time() 'Processing for Subsys' ssid
Hlq=strip(Hlq)
 
/* Report dataset on output (System  stats) */
ouflsy = "'" !! hlq !! '.CDCREPSY.' !! ssid !! '.CSV' !! "'"
x=OUTTRAP(dum.)
"DELETE" ouflsy "PURGE"
x=OUTTRAP(OFF)
/* Report dataset on output (Source Subscr) */
ouflss = "'" !! hlq !! '.CDCREPSS.' !! ssid !! '.CSV' !! "'"
x=OUTTRAP(dum.)
"DELETE" ouflss "PURGE"
x=OUTTRAP(OFF)
/* Report dataset on output (Log Cache ) */
oufllc = "'" !! hlq !! '.CDCREPLC.' !! ssid !! '.CSV' !! "'"
x=OUTTRAP(dum.)
"DELETE" oufllc "PURGE"
x=OUTTRAP(OFF)
 
 
"ALLOC FI(OUFLSY) DA("ouflsy") NEW CATALOG REUSE" ,
"LRECL(400) RECFM(V B) TRACKS SPACE(50,50)"
RcAlloc = rc
if RcAlloc <> 0 then Do
     say "**********************************************"
     say "   Error allocating report file" ouflsy RcAlloc
     say "   Abnormal end  "
     say "**********************************************"
     Exit 8
end
"ALLOC FI(OUFLSS) DA("ouflss") NEW CATALOG REUSE" ,
"LRECL(700) RECFM(V B) TRACKS SPACE(50,50)"
RcAlloc = rc
if RcAlloc <> 0 then Do
     say "**********************************************"
     say "   Error allocating report file" ouflss RcAlloc
     say "   Abnormal end  "
     say "**********************************************"
     Exit 8
end
"ALLOC FI(OUFLLC) DA("oufllc") NEW CATALOG REUSE" ,
"LRECL(300) RECFM(V B) TRACKS SPACE(50,50)"
RcAlloc = rc
if RcAlloc <> 0 then Do
     say "**********************************************"
     say "   Error allocating report file" oufllc RcAlloc
     say "   Abnormal end  "
     say "**********************************************"
     Exit 8
end
 
/* init counters */
call init_var
/* WRITE report header */
Call WriteHeader
 
/* START PROCESSING */
Do Forever
  /* read SMF record one by one   */
  "EXECIO 1 DISKR INP"
  IF RC > 0 THEN DO
            if rc =  2 then
             do
              SAY time() 'End of input SMF file rc=' RC
              RcAlloc = rc
             end
             else do
              SAY 'Error while reading SMF file rc=' RC
              RcAlloc = 8
             end
              leave
            END
  PARSE PULL InpRec
  reci=reci+1
  Ofs = 1
  /* Decode SMF header */
  Call GetSMFHeader
  if Result > 0 then iterate
  /* Record SMF records period   */
  if min_time > RunFmtTime then min_time=RunFmtTime
  if max_time < RunFmtTime then max_time=RunFmtTime
  if min_date > SmfDte       then min_date=SmfDte
  if max_date < SmfDte       then max_date=SmfDte
 
  /* Get CDC SMF Header */
  Call GetCDCSMFHeader
 
  Select
      When TsEntyp =0 then call SystemRec
      When TsEntyp =1 then call SourceSubsRec
      When TsEntyp =2 then call TargetSubsRec
      When TsEntyp =3 then call Db2LogCacheRec
      otherwise do
                    say 'Incorrect CDC record or unknown:' TsEntyp
                    exit 8
                end
  End
End /* Do Forever */
 
/* Close and Free files */
"EXECIO 0 DISKR INP (FINIS"
"FREE DD(INP)"
"EXECIO 0 DISKW OUFLLC (FINIS"
"FREE DD(OUFLLC)"
"EXECIO 0 DISKW OUFLSY (FINIS"
"FREE DD(OUFLSY)"
"EXECIO 0 DISKW OUFLSS (FINIS"
"FREE DD(OUFLSS)"
 
say "Input records =" reci
say "Output records=" reco
say 'SMF period : ' min_date "/" max_date min_time "/" max_time
 
/*-------------------------------------------------*/
/* F20 End of program display counters and figures */
/*-------------------------------------------------*/
 
EXIT 0
 
/*---------------------------------------*/
/*    Routines section                   */
/*---------------------------------------*/
WriteHeader:
  Say OUFLSY 'will be produced - General Stats'
  Say OUFLLC 'will be produced - Log Cache Stats'
  Say OUFLSS 'will be produced - Source Subscription Stats'
 
  /* System Header */
  outrec.0= 1
  outrec.1= ,
        "Lpar,JobN,Ssid,Date,DoW,Time,Hour,"!!,
        "OSCSts,OSCSbSts,OSCcpu,OSCStoBbytes,OSCMaxSto,OSCMiss,"!!,
        "CITSts,CITSbSts,CITcpu,"!!,
        "PALSts,PALSbSts,PALcpu,"!!,
        "MAASts,MAASbSts,MAAcpu,"!!,
        "CMOSts,CMOSbSts,CMOcpu,"!!,
        "CLSSts,CLSSbSts,CLScpu,"!!,
        "CVFSts,CVFSbSts,CVFcpu,"!!,
        "DSCSts,DSCSbSts,DSCcpu,"!!,
        "DLPSts,DLPSbSts,DLPcpu,"!!,
        "DALSts,DALSbSts,DALcpu,"!!,
        "PAASts,PAASbSts,PAAcpu,"!!,
        "CCISts,CCISbSts,CCIcpu,"!!,
        "CCOSts,CCOSbSts,CCOcpu,"
  "EXECIO 1 DISKW OUFLSY (STEM OUTREC. "
  reco=reco+1
 
  /* SourceSubsRec Header */
  outrec.0= 1
  outrec.1= ,
  "Lpar,StcN,Ssid,SubsN,Date,Dow,time,Hour,"!!,
  "SCTSts,SCTSbSts,SCTcpu,"!!,
  "SDTSts,SDTSbSts,SDTcpu,TcpSnd,TcpSndByt,InsSnd,"!!,
   "UpdSnd,DelSnd,CmitSnd,LogRRd,LogRIns2Stg,LogRDelFrStg,"!!,
   "LogRCurInStg,ByCurInStg,CmitCurStg,"!!,
   "CmitSzCurSnd,MaxCmitSz,"!!,
   "MinCmitSz,ByRdStg,SrcPrefiltIns,SrcPrfUpd,SrcPrfDel,"!!,
   "CpuDrvCol,ElpDrvCol,MaxByStg,NbFreeStg,CLRProcStg,"!!,
   "ByDOCommQ,LogPosRd,LogPosSnd,LogPosRdN,LogPosSndN,"!!,
  "DSLSts,DSLSbSts,DSLcpu,LogRFlt,LogByFlt,IfiCall,IfiCpu,"!!,
    "LogByProc,LogRProc,LogCachRdReq,LogCachRdOK,IfiElap,"!!,
    "LogWinSz,HeadLogPos,CurLogPos,HeadLogN,CurLogN,"!!,
  "CDISts,CDISbSts,CDIcpu,TcpSnd,TcpRcv,BySnt,ByRcv,CommSndWait,"!!,
    "CommRcvWait,"!!,
  "CDOSts,CDOSbSts,CDOcpu,TcpSnd,TcpRcv,BySnt,ByRcv,CommSndWait,"!!,
    "CommRcvWait,"
 
  "EXECIO 1 DISKW OUFLSS (STEM OUTREC. "
  reco=reco+1
 
  /* Log Cache */
  outrec.0= 1
  outrec.1= ,
     "Lpar,JobN,Ssid,Date,DoW,Time,Hour,"!!,
     "DLRSts,DLRSbSts,DLRCpu,WrCache,RdCache,RdOK,RdNOK,"!!,
       "BlkWrL1,BlkUpdL1,BlkRdL1Cach,BlkRdL2Cach,CpuIFIRd,ElpIFIRd,"!!,
       "HeadLogPos,LoLogPos,HiLogPos,"!!,
       "HeadLogN,LoLogN,HiLogN,"!!,
     "DCWSts,DCWSbSts,DCWCpu,BlkWrL2,"
  "EXECIO 1 DISKW OUFLLC (STEM OUTREC. "
  reco=reco+1
 
  return
 
WriteDb2LogCacheRep:
    outrec.0= 1
    outrec.1= smfsid!!','!!strip(TsJobNm)!!','!!TsSsid!!',',
    !! SmfDte           !! ','   ,
    !! DayOWeek         !! ','   ,
    !! RunFmtTime       !! ','   ,
    !! RunHH            !! ','   ,
    !! TssSts.1         !! ','   ,
    !! TssStsMd.1       !! ','   ,
    !! DLRCpu           !! ','   ,
    !! DLRWrt           !! ','   ,
    !! DLRRd            !! ','   ,
    !! DLRRdOK          !! ','   ,
    !! DLRRdNOK         !! ','   ,
    !! DLRBlWt1         !! ','   ,
    !! DLRBlUp1         !! ','   ,
    !! DLRBlRd1         !! ','   ,
    !! DLRBlRd2         !! ','   ,
    !! DLRIfCpu         !! ','   ,
    !! DLRIfElp         !! ','   ,
    !! DLRHoLX          !! ','   ,
    !! DLRLoCX          !! ','   ,
    !! DLRHiCX          !! ','   ,
    !! DLRHoLn          !! ','   ,
    !! DLRLoCn          !! ','   ,
    !! DLRHiCn          !! ','   ,
    !! TssSts.2         !! ','   ,
    !! TssStsMd.2       !! ','   ,
    !! DCWCpu           !! ','   ,
    !! DCWBlWt2         !! ','
  "EXECIO 1 DISKW OUFLLC (STEM OUTREC. "
  reco=reco+1
  return
 
WriteSourceSubsRep:
    outrec.0= 1
    outrec.1= smfsid!!','!!strip(TsJobNm)!!','!!TsSsid!!',',
    !! TsEntNm          !! ','   ,
    !! SmfDte           !! ','   ,
    !! DayOWeek         !! ','   ,
    !! RunFmtTime       !! ','   ,
    !! RunHH            !! ','   ,
    !! TssSts.1         !! ','   ,
    !! TssStsMd.1       !! ','   ,
    !! SCTCpu           !! ','   ,
    !! TssSts.2         !! ','   ,
    !! TssStsMd.2       !! ','   ,
    !! SDTCpu           !! ','   ,
    !! SDTSndS          !! ','   ,
    !! SDTSndBt         !! ','   ,
    !! SDTIns           !! ','   ,
    !! SDTUpd           !! ','   ,
    !! SDTDel           !! ','   ,
    !! SDTCmt           !! ','   ,
    !! SDTLRRLW         !! ','   ,
    !! SDTLRISS         !! ','   ,
    !! SDTLRRSS         !! ','   ,
    !! SDTLRSS          !! ','   ,
    !! SDTSzSS          !! ','   ,
    !! SDTCmtSS         !! ','   ,
    !! SDTCRCmt         !! ','   ,
    !! SDTMxCmt         !! ','   ,
    !! SDTMnCmt         !! ','   ,
    !! SDTEngBT         !! ','   ,
    !! SDTPrIns         !! ','   ,
    !! SDTPrUpd         !! ','   ,
    !! SDTPrDel         !! ','   ,
    !! SDTCpuDC         !! ','   ,
    !! SDTElDC          !! ','   ,
    !! SDTmaxSS         !! ','   ,
    !! SDTFreSS         !! ','   ,
    !! SDTCmpSS         !! ','   ,
    !! SDTCmQSz         !! ','   ,
    !! SDTLPLWX         !! ','   ,
    !! SDTLPSnX         !! ','   ,
    !! SDTLPLWn         !! ','   ,
    !! SDTLPSnn         !! ','   ,
    !! TssSts.3         !! ','   ,
    !! TssStsMd.3       !! ','   ,
    !! DSLCpu           !! ','   ,
    !! DSLNumFl         !! ','   ,
    !! DSLBytFl         !! ','   ,
    !! DSLNumIF         !! ','   ,
    !! DSLCpuIF         !! ','   ,
    !! DSLBytLg         !! ','   ,
    !! DSLNumLg         !! ','   ,
    !! DSLChReq         !! ','   ,
    !! DSLChHit         !! ','   ,
    !! DSLElpIf         !! ','   ,
    !! DSLLWSz          !! ','   ,
    !! DSLHoLX          !! ','   ,
    !! DSLScrpX         !! ','   ,
    !! DSLHoLn          !! ','   ,
    !! DSLScrpn         !! ','   ,
    !! TssSts.4         !! ','   ,
    !! TssStsMd.4       !! ','   ,
    !! CDICpu           !! ','   ,
    !! CDISnd           !! ','   ,
    !! CDIRcv           !! ','   ,
    !! CDISndBt         !! ','   ,
    !! CDIRcvBt         !! ','   ,
    !! CDISndWt         !! ','   ,
    !! CDIRcvWt         !! ','   ,
    !! TssSts.5         !! ','   ,
    !! TssStsMd.5       !! ','   ,
    !! CDOCpu           !! ','   ,
    !! CDOSnd           !! ','   ,
    !! CDORcv           !! ','   ,
    !! CDOSndBt         !! ','   ,
    !! CDORcvBt         !! ','   ,
    !! CDOSndWt         !! ','   ,
    !! CDORcvWt         !! ','
  "EXECIO 1 DISKW OUFLSS (STEM OUTREC. "
  reco=reco+1
  return
 
WriteSystemRep:
    outrec.0= 1
    outrec.1= smfsid!!','!!strip(TsJobNm)!!','!!TsSsid!!',',
    !! SmfDte           !! ','   ,
    !! DayOWeek         !! ','   ,
    !! RunFmtTime       !! ','   ,
    !! RunHH            !! ','   ,
    !! TssSts.1         !! ','   ,
    !! TssStsMd.1       !! ','   ,
    !! OSCCpu           !! ','   ,
    !! OSCSmCur         !! ','   ,
    !! OSCSmMax         !! ','   ,
    !! OSCMsInt         !! ','   ,
    !! TssSts.2         !! ','   ,
    !! TssStsMd.2       !! ','   ,
    !! CITCpu           !! ','   ,
    !! TssSts.3         !! ','   ,
    !! TssStsMd.3       !! ','   ,
    !! PALCpu           !! ','   ,
    !! TssSts.4         !! ','   ,
    !! TssStsMd.4       !! ','   ,
    !! MAACpu           !! ','   ,
    !! TssSts.5         !! ','   ,
    !! TssStsMd.5       !! ','   ,
    !! CMOCpu           !! ','   ,
    !! TssSts.6         !! ','   ,
    !! TssStsMd.6       !! ','   ,
    !! CLSCpu           !! ','   ,
    !! TssSts.7         !! ','   ,
    !! TssStsMd.7       !! ','   ,
    !! CVFCpu           !! ','   ,
    !! TssSts.8         !! ','   ,
    !! TssStsMd.8       !! ','   ,
    !! DSCCpu           !! ','   ,
    !! TssSts.9         !! ','   ,
    !! TssStsMd.9       !! ','   ,
    !! DLPCpu           !! ','   ,
    !! TssSts.10        !! ','   ,
    !! TssStsMd.10      !! ','   ,
    !! DALCpu           !! ','   ,
    !! TssSts.11        !! ','   ,
    !! TssStsMd.11      !! ','   ,
    !! PAACpu           !! ','   ,
    !! TssSts.12        !! ','   ,
    !! TssStsMd.12      !! ','   ,
    !! CCICpu           !! ','   ,
    !! TssSts.13        !! ','   ,
    !! TssStsMd.13      !! ','   ,
    !! CCOCpu           !! ','
  "EXECIO 1 DISKW OUFLSY (STEM OUTREC. "
  reco=reco+1
  return
 
/* SMF header */
GetSmfHeader:
   Ofs = Ofs + 1
   /* Smf record type  */
   smfrty   = C2D(SUBSTR(InpRec,Ofs,1))
   Ofs = Ofs + 1
   Tsssid  = SUBSTR(InpRec,Ofs+38,4)
   /* stop processing if not 100 */
   if smfrty   <> smftype ! ssid <> Tsssid  then return 4
   SMfTme = C2D(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   RunFmttime=GetFmtTime(SmfTme)
   if RunHH =  23 ! SmfDte='' then
   do
     smfdte = C2X(SUBSTR(InpRec,Ofs,4))
     parse value smfdte with 1 . 2 c 3 yy 5 ddd 8 .
     smfdte    = '20'yy!!'.'!!ddd
     /* get day of week : easier to select days */
     test_date = '20'yy ddd
     smfdte=DAT_MVS2SD(test_date)
     DayOWeek = DAT_S2DOW(smfdte)
   end
   Ofs = Ofs + 4
   /* System Id = SMF ID */
   smfsid = SUBSTR(InpRec,Ofs,4)
   Ofs = Ofs + 4
   return 0
 
/* CDC SMF Header */
GetCDCSMFHeader:
   /* Len of the SMF CDC record = record - Standard SMF Header */
   TsRecLen = C2D(SUBSTR(InpRec,Ofs,2))
   Ofs = Ofs + 2
   /* Len of the SMF CDC Header */
   TsHdrLen = C2D(SUBSTR(InpRec,Ofs,2))
   Ofs = Ofs + 2
   /* Eye Catcher */
   If SUBSTR(InpRec,Ofs,8) <> 'TSSMFREC' then
      do
           say 'Eye catcher not found SMF CDC Header'
           exit 8
      end
   Ofs = Ofs + 12
 
   /* CDC Address Space Name */
   TsJobNm  = SUBSTR(InpRec,Ofs,8)
   Ofs = Ofs + 10 +4
   /* Category of the CDC SMF record*/
   TsCatg   = c2d(SUBSTR(InpRec,Ofs,2))
   Ofs = Ofs + 2
   /* Type of Entity of this SMF record*/
   TsEnTyp  = c2d(SUBSTR(InpRec,Ofs,2))
   Ofs = Ofs + 2
   /* Entity Name (Subscription name ) */
   TsEnTNm  = strip(SUBSTR(InpRec,Ofs,12))
   Ofs = Ofs + 12
   /* TsIntvl - normally 60 seconds */
   TsIntvl  = c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Number of Segments following this header */
   TsSegs   = c2d(SUBSTR(InpRec,Ofs,2))
   Ofs = Ofs + 28
   if TsSegs <> 13 & TsSegs <> 5 & TsSegs <> 2 then do
          say 'TsSegs not valid' TsSegs
          exit(8)
      end
   return
 
GetPerfSegHead:
   /***************************/
   /* CDC Performance Segment */
   /***************************/
   /* Len of the entire segment */
   /* Ofs = Ofs + TssSegLn.EntId si on veut sauter le segment */
   TssSegLn.EntId = c2d(SUBSTR(InpRec,Ofs,2))
   Ofs = Ofs + 2
   TssHdrLn       = c2d(SUBSTR(InpRec,Ofs,2))
   Ofs = Ofs + 2 +4
   /* Type of Entity */
   TssEnTyp.EntId = c2d(SUBSTR(InpRec,Ofs,4))
   if TssEnTyp.EntId > 31 then do
                 Say 'TssEnTyp not correct' TssEnTyp.EntId
                 exit(8)
              end
   Ofs = Ofs + 4
   /* Entity Name*/
   TssEntNm.EntId=strip(SUBSTR(InpRec,Ofs,12))
   Ofs = Ofs + 12
   if wordpos(TssEntNm.EntId,TaskName) = 0 then
     do
        say 'TssEntNm not valid' TssEntNm.EntId
        exit 8
     end
   /* SCT record not described in the manual yet */
   if TssEntNm.EntId='SCT' & TssSegLn.EntId = 146 then
      do
           return(4)
      end
   /* Entity Status */
   TssSts.EntId   = c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   select
          when TssSts.EntId   = 3
            then  TssSts.EntId   = 'A'
          when TssSts.EntId   = 1
            then  TssSts.EntId   = 'I'
          when TssSts.EntId   = 2
            then  TssSts.EntId   = 'Starting'
          when TssSts.EntId   = 4
            then  TssSts.EntId   = 'Ending'
          when TssSts.EntId   = 0
            then  TssSts.EntId   = 'Unk'
          otherwise do
                       Say 'TssSts',
                           'Value not found' TssSts.EntId
                       exit 8
                    end
   end
   /* Entity Sub Status */
   TssStsMd.EntId  =     SUBSTR(InpRec,Ofs,4)
   select
          when TssStsMd.EntId = '00000020'x
               then TssStsMd.EntId='Mir'
          when TssStsMd.EntId = '00000001'x
               then TssStsMd.EntId='Norm'
          when TssStsMd.EntId = '00000000'x
               then TssStsMd.EntId='Unk'
          when TssStsMd.EntId = '00000002'x
               then TssStsMd.EntId='Err'
          when TssStsMd.EntId = '00000004'x
               then TssStsMd.EntId='Describe'
          when TssStsMd.EntId = '00000008'x
               then TssStsMd.EntId='Refrsh'
          when TssStsMd.EntId = '00000010'x
               then TssStsMd.EntId='RefBefMir'
          when TssStsMd.EntId = '00000040'x
               then TssStsMd.EntId='MirNxtChg'
          otherwise do
                       Say 'TssStsMd',
                           'Value not found' TssStsMd.EntId
                       exit 8
                    end
   end
   Ofs = Ofs + 4 +32
   return(0)
 
SourceSubsRec:
   /* Source Subscription mirror performance record */
   /*  - Standard SMF Header
       - CDC SMF Header
       - CDC Performance Header
      1- CDC Perf segment for task SCT
       - CDC Performance Header
      2- CDC Perf segment for task SDT
       - CDC Performance Header
      3- CDC Perf segment for task DSL
       - CDC Performance Header
      4  CDC Perf segment for task CDI
       - CDC Performance Header
      5- CDC Perf segment for task CDO
   */
   /*  SCT task */
   EntId=1
   Call GetPerfSegHead
   /* SCT record not described yet */
   if result > 0 then return
   Call GetSCT
   EntId=EntID+1
   /*  SDT task */
   Call GetPerfSegHead
   Call GetSDT
   EntId=EntID+1
   /*  DSL task */
   Call GetPerfSegHead
   Call GetDSL
   EntId=EntID+1
   /*  CDI task */
   Call GetPerfSegHead
   Call GetCDI
   EntId=EntID+1
   /*  CDO task */
   Call GetPerfSegHead
   Call GetCDO
 
   call WriteSourceSubsRep
   return
 
Db2LogCacheRec:
   /* System SMF Performance Record */
   /*  - Standard SMF Header
       - CDC SMF Header
       - CDC Performance Header
      1- CDC Perf segment for task DLR
       - CDC Performance Header
      2- CDC Perf segment for task DCW
   */
   /*  DLR task */
   EntId=1
   Call GetPerfSegHead
   Call GetDLR
   EntId=EntID+1
   /*  DCW task */
   Call GetPerfSegHead
   Call GetDCW
 
   call WriteDb2LogCacheRep
   return
 
SystemRec:
   /* System SMF Performance Record */
   /*  - Standard SMF Header
       - CDC SMF Header
       - CDC Performance Header
      1- CDC Perf segment for task OSC
      2- CDC Perf segment for task CIT
      3- CDC Perf segment for task PAL
      4- CDC Perf segment for task MAA
      5- CDC Perf segment for task CMO
      6- CDC Perf segment for task CLS
      7- CDC Perf segment for task CVF
      8- CDC Perf segment for task DSC
      9- CDC Perf segment for task DLP
     10- CDC Perf segment for task DAL
     11- CDC Perf segment for task PAA
     12- CDC Perf segment for task CCI
     13- CDC Perf segment for task CCO
   */
   /*  OSC task */
   EntId=1
   Call GetPerfSegHead
   Call GetOSC
   EntId=EntID+1
   /*  CIT task */
   Call GetPerfSegHead
   Call GetCIT
   EntId=EntID+1
   /*  PAL task */
   Call GetPerfSegHead
   Call GetPAL
   EntId=EntID+1
   /*  MAA task */
   Call GetPerfSegHead
   Call GetMAA
   EntId=EntID+1
   /*  CMO task */
   Call GetPerfSegHead
   Call GetCMO
   EntId=EntID+1
   /*  CLS task */
   Call GetPerfSegHead
   Call GetCLS
   EntId=EntID+1
   /*  CVF task */
   Call GetPerfSegHead
   Call GetCVF
   EntId=EntID+1
   /*  DSC task */
   Call GetPerfSegHead
   Call GetDSC
   EntId=EntID+1
   /*  DLP task */
   Call GetPerfSegHead
   Call GetDLP
   EntId=EntID+1
   /*  DAL task */
   Call GetPerfSegHead
   Call GetDAL
   EntId=EntID+1
   /*  PAA task */
   Call GetPerfSegHead
   Call GetPAA
   EntId=EntID+1
   /*  CCI task */
   Call GetPerfSegHead
   Call GetCCI
   EntId=EntID+1
   /*  CCO task */
   Call GetPerfSegHead
   Call GetCCO
 
   call WriteSystemRep
   return
/* COmmunication Data Out */
GetCDO:
   if TssEnTyp.EntId <> 23 then do
      say 'In GetCDO but not a valid TssEnTyp' TssEnTyp.EntId
      exit 8
   end
   /* CPU */
   CDOCpu = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Number of TCP Sends*/
   CDOSnd = c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Number of TCP Rcvd*/
   CDORcv = c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Amount of bytes sent */
   CDOSndBt = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Amount of bytes received */
   CDORcvBt = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Comms send wait time in micro seconds*/
   CDOSndWt = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Comms recv wait time in micro seconds*/
   CDORcvWt = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   return
/* Communication Data In */
GetCDI:
   if TssEnTyp.EntId <> 22 then do
      say 'In GetCDI but not a valid TssEnTyp' TssEnTyp.EntId
      exit 8
   end
   /* CPU */
   CDICpu = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Number of TCP Sends*/
   CDISnd = c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Number of TCP Rcvd*/
   CDIRcv = c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Amount of bytes sent */
   CDISndBt = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Amount of bytes received */
   CDIRcvBt = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Comms send wait time in micro seconds*/
   CDISndWt = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Comms recv wait time in micro seconds*/
   CDIRcvWt = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   return
 
/* The Data Synchronous Log get notification from DAL that there is */
/* new log to read, it issues IFI reads (IFCID 306)                 */
/* When the log cache is used, log is read from the cache, if not   */
/* found it will be read with IFI                                   */
/* There is one DSL per Subscription                                */
/* The DSL tasks continues to read log data from the cache or  via */
/* IFI reads until it hts the current end of the log, it suspends  */
/* until awaken by DAL                                             */
/* also called Log Scraper                                          */
GetDSL:
   if TssEnTyp.EntId <> 10 then do
      say 'In GetSDT but not a valid TssEnTyp' TssEnTyp.EntId
      exit 8
   end
   /* CPU */
   DSLCpu = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 24
   /*
   /* DSL Head of Log */
   DSLHoL = c2x(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Current Log Position being read */
   DSLScrp= c2x(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8 */
   /* CDC Log records filtered out*/
   DSLNumFl=c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* CDC Log bytes   filtered out*/
   DSLBytFl=c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Number of IFI306 calls */
   DSLNumIF=c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Cpu consumed by IFI306 calls */
   DSLCpuIF=c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Source Database log bytes processed */
   DSLBytLg=c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Source Database log rec   processed */
   DSLNumLg=c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Num of subscription log cache read requests */
   DSLChReq=c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Num of subscription log cache hits  */
   DSLChHit=c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Elap micro secs in IFI306 calls */
   DSLElpIf=c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Log window (data buffers) current size */
   DSLLWSz =c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* DSL Head of Log */
   DSLHoLX= c2x(SUBSTR(InpRec,Ofs,10))
   DSLHoLn= c2d(SUBSTR(InpRec,Ofs,10))
   Ofs = Ofs + 10
   /* Current Log Position being read Extended */
   DSLScrpX= c2x(SUBSTR(InpRec,Ofs,10))
   DSLScrpn= c2d(SUBSTR(InpRec,Ofs,10))
   Ofs = Ofs + 10
 
   return
 
/* Source Data : like SCT but deals with data in subscription. */
/* Data transformations at the source occur as part of the SDT task */
/* It receives data from the DSL (log scraper). Will group changes  */
/* by UOW and stage them in hiperspace waiting for a commit/rollback*/
GetSDT:
   if TssEnTyp.EntId <> 26 then do
      say 'In GetSDT but not a valid TssEnTyp' TssEnTyp.EntId
      exit 8
   end
   /* CPU */
   SDTCpu = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 24
   /*
   /* Last Db2 Log position read from the log window */
   SDTLPLW= c2x(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Last Db2 Log position sent to the target */
   SDTLPSnd= c2x(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8 */
   /* Numb of TCP sends to the target */
   SDTSndS = c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Numb of bytes sent to the target */
   SDTSndBt= c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Numb of Inserts sent to the target */
   SDTIns  = c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Numb of Updates sent to the target */
   SDTUpd  = c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Numb of Delete  sent to the target */
   SDTDel  = c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Numb of Commit  sent to the target */
   SDTCmt  = c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Numb of Log record read from the log window */
   SDTLRRLW= c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Numb of Log record Inserted into the Staging Space */
   SDTLRISS= c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Numb of Log record Removed  from the Staging Space */
   SDTLRRSS= c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Numb of Log record currently in the staging Space */
   SDTLRSS = c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Numb of bytes currently in the staging Space */
   SDTSzSS = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Numb of completed commits group in the staging Space */
   SDTCmtSS = c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Size of the Commit group currently being sent to the Target */
   SDTCRCmt = c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Size of the largest Commit Group sent */
   SDTMxCmt = c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Size of the smallest Commit Group sent */
   SDTMnCmt = c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Number of bytes read from the staging space */
   SDTEngBT = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Number of source prefilter insert operations */
   SDTPrIns = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Number of source prefilter upd  operations */
   SDTPrUpd = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Number of source prefilter Del  operations */
   SDTPrDel = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* The amount of CPU time in micro secs spent processing derived*/
   /* columns */
   SDTCpuDC = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* The amount of Elap  in micro secs spent processing derived*/
   /* columns */
   SDTElDC = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* MAx bytes used Stageing Space */
   SDTmaxSS= c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Number of elements in the Free List in the SS */
   SDTFreSS= c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Number of CLR processed in the SS */
   SDTCmpSS= c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Number of bytes in the DO comms Queue*/
   SDTCmQSz= c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Extended last Db2 log position read from the log window*/
   SDTLPLWX= c2x(SUBSTR(InpRec,Ofs,10))
   SDTLPLWn= c2d(SUBSTR(InpRec,Ofs,10))
   Ofs = Ofs + 10
   /* Extended last Db2 log position sent to the Target */
   SDTLPSnX= c2x(SUBSTR(InpRec,Ofs,10))
   SDTLPSnn= c2d(SUBSTR(InpRec,Ofs,10))
   Ofs = Ofs + 10
 
   return
 
/* Source Control : coordinates communication of the control   */
/* information for a single subscription                       */
GetSCT:
   if TssEnTyp.EntId <> 24 then do
      say 'In GetSCT but not a valid TssEnTyp' TssEnTyp.EntId
      exit 8
   end
   /* CPU */
   SCTCpu = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   return
 
/* DCW moves data between L1 and L2(VSAM) cache, when caching is  */
/* enable                                                         */
GetDCW:
   if TssEnTyp.EntId <> 29 then do
      say 'In GetDCW but not a valid TssEnTyp' TssEnTyp.EntId
      exit 8
   end
   /* CPU */
   DCWCpu = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Blocks written to L2 Db2 Log Cache */
   DCWBlWt2=c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   return
 
/* DBMS Log Data Cache Reader. DLR task reads data from Db2 log */
/* and populates the level 1 cache - DLR task is shared over    */
/* multiple subscription                                        */
GetDLR:
   if TssEnTyp.EntId <> 28 then do
      say 'In GetDLR but not a valid TssEnTyp' TssEnTyp.EntId
      exit 8
   end
   /* CPU */
   DLRCpu = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 32
   /*
   /* Head Of Log */
   DLRHoL = c2x(SUBSTR(InpRec,Ofs,8))
   Say 'DLRHol' DLRHoL
   Ofs = Ofs + 8
   /* Lowest Db2 Log Position in cache */
   DLRLiC = c2x(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Highst Db2 Log Position in cache */
   DLRHiC = c2x(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8 */
   /* Number of request to write to Db2 Log Cache */
   DLRWrt = c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Number of request to Read from Db2 Log Cache */
   DLRRd  = c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Number of request to Read OK (Successful) Db2 Log Cache*/
   DLRRdOK= c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Number of request to Read NOK(Not Found) Db2 Log Cache*/
   DLRRdNOK= c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Number of new blocks written to L1 Db2 Log cache */
   DLRBlWt1= c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Number of blocks Updated to L1 Db2 Log cache */
   DLRBlUp1= c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Number of blocks Read from L1 Db2 Log cache */
   DLRBlRd1= c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* Number of blocks Read from L2 Db2 Log cache */
   DLRBlRd2= c2d(SUBSTR(InpRec,Ofs,4))
   Ofs = Ofs + 4
   /* CPU used by DLR in DB2 IFI Calls to read log data */
   DLRIfCpu= c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Cumulative Elapsed time in DB2 IFI Calls to read log data */
   DLRIfElp= c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Head of Log Extended */
   DLRHoLX = c2x(SUBSTR(InpRec,Ofs,10))
   DLRHoLn = c2d(SUBSTR(InpRec,Ofs,10))
   Ofs = Ofs + 10
   /* Lowest Log  Extended */
   DLRLoCX = c2x(SUBSTR(InpRec,Ofs,10))
   DLRLoCn = c2d(SUBSTR(InpRec,Ofs,10))
   Ofs = Ofs + 10
   /* Highest Log Extended */
   DLRHiCX = c2x(SUBSTR(InpRec,Ofs,10))
   DLRHiCn = c2d(SUBSTR(InpRec,Ofs,10))
   Ofs = Ofs + 10
 
   return
 
GetCCO:
   if TssEnTyp.EntId <> 21 then do
      say 'In GetCCO but not a valid TssEnTyp' TssEnTyp.EntId
      exit 8
   end
   /* CPU */
   CCOCpu=c2d(SUBSTR(InpRec,ofs,8),8)
   Ofs = Ofs + 8
   return
 
 
GetCCI:
   if TssEnTyp.EntId <> 20 then do
      say 'In GetCCI but not a valid TssEnTyp' TssEnTyp.EntId
      exit 8
   end
   /* CPU */
   CCICpu = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   return
/* Product Admin Agent : support for Management Console */
GetPAA:
   if TssEnTyp.EntId <> 05 then do
      say 'In GetPAA but not a valid TssEnTyp' TssEnTyp.EntId
      exit 8
   end
   /* CPU */
   PAACpu = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   return
 
/* The DAL Task receives notification from the DBMS that new data */
/* has been written to the log and forwards notification to DSL   */
/* Async access to Log (vs. DSL Sync access to log)               */
GetDAL:
   if TssEnTyp.EntId <> 09 then do
      say 'In GetDAL but not a valid TssEnTyp' TssEnTyp.EntId
      exit 8
   end
   /* CPU */
   DALCpu = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   return
 
/* DBmS Log Profile. DLP reads the log to detect events such as Reorg*/
/* DDL Change on the source table                                    */
GetDLP:
   if TssEnTyp.EntId <> 16 then do
      say 'In GetDSC but not a valid TssEnTyp' TssEnTyp.EntId
      exit 8
   end
   /* CPU */
   DLPCpu = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   return
/* DBMS Supervision and Control. The DSC task is responsible for */
/* management of subscriptions (start/stop/state transitions)    */
GetDSC:
   if TssEnTyp.EntId <> 07 then do
      say 'In GetDSC but not a valid TssEnTyp' TssEnTyp.EntId
      exit 8
   end
   /* CPU */
   DSCCpu = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   return
 
GetCVF:
   if TssEnTyp.EntId <> 27 then do
      say 'In GetCVF but not a valid TssEnTyp' TssEnTyp.EntId
      exit 8
   end
   /* CPU */
   CVFCpu = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   return
 
GetCLS:
   if TssEnTyp.EntId <> 19 then do
      say 'In GetMMA but not a valid TssEnTyp' TssEnTyp.EntId
      exit 8
   end
   /* CPU */
   CLSCpu = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   return
/* COmmunication Monitoring task */
GetCMO:
   if TssEnTyp.EntId <> 18 then do
      say 'In GetCMO but not a valid TssEnTyp' TssEnTyp.EntId
      exit 8
   end
   /* CPU */
   CMOCpu = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   return
 
GetMAA:
   if TssEnTyp.EntId <> 30 then do
      say 'In GetMMA but not a valid TssEnTyp' TssEnTyp.EntId
      exit 8
   end
   /* CPU */
   MAACpu = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   return
 
GetPAL:
   if TssEnTyp.EntId <> 3 then do
      say 'In GetPAL but not a valid TssEnTyp' TssEnTyp.EntId
      exit 8
   end
   /* CPU */
   PALCpu = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   return
 
GetCIT:
   if TssEnTyp.EntId <> 4 then do
      say 'In GetCIT but not a valid TssEnTyp' TssEnTyp.EntId
      exit 8
   end
   /* CPU */
   CITCpu = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   return
/* Operrating System Command task , process commands  */
GetOSC:
   if TssEnTyp.EntId <> 2 then do
      say 'In GetOSC but not a valid TssEnTyp' TssEnTyp.EntId
      exit 8
   end
   /* CPU */
   OSCCpu = c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Storage in bytes*/
   OSCSmCur= c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Max Stor   bytes*/
   OSCSmMax= c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   /* Missed Count */
   OSCMsInt =c2d(SUBSTR(InpRec,Ofs,8))
   Ofs = Ofs + 8
   return
 
init_var:
  TaskName='CCI CCO CIT CDI CDO CLS CMO CVF DAL DCW DLP DSC DLR ',
           'DSL DTC OSC PAA PAL SCT SDT MAA TCT TDT'
 
  smfdte=''
 
  /* compteurs input/output */
  reco= 0
  reci= 0
  recs= 0
 
  min_time ='26:00:00'
  max_time ='ZZ:00:00'
  min_date ='2100.000'
  max_date ='1900.000'
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
/*---------------------*/
/* Is this leap year ? */
/*---------------------*/
LY?: Procedure
Parse Arg 1 y +4
Return ((y//4)=0)
/*---------------------------------------------*/
/* Convert timestamp internal format 8 to text */
/*---------------------------------------------*/
stck:
Arg TUNITS
  TIMESTAMP = Copies(0,26)  /* force result length=26 */
  Address linkpgm "BLSUXTOD TUNITS TIMESTAMP"
  /* variable Timestamp has the value of timestamp */
  return
GetFmtTime: procedure expose runHH
arg SmfTME
  RunHH = SMfTME % 360000
  RunHH = RIGHT(RunHH,2,'0')
  RunMN = SMfTME % 6000 - RunHH*60
  RunMN = RIGHT(RunMN,2,'0')
  RunSS = SMfTME % 100 - RunHH *3600 - RunMN*60
  RunSS = RIGHT(RunSS,2,'0')
  RunFmtTime = RunHH!!':'!!RunMN!!':'!!RunSS
  return(RunFmtTime)

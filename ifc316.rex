/*REXX ****************************************************************/
/* Read statement cache - Long SQL                                    */
/* ndt.db2@gmail.com  15/03/2019  ver 1.0                             */
/*                                                                    */
/* <ssid>       DB2 subsystem name                                    */
/* <numtimes>   Number of intervals (default 60)                      */
/* <sleeptime>  Time in seconds between two intervals (default 60)    */
/*                                                                    */
/**********************************************************************/
arg  ssid hlq numtimes sleeptime NoWait
numeric digits 25
err317= 0
first = 1
nbmax = 30
nblist = 0
reuse  = 0
 
RtrSz = 16000000
RtrArea = d2c(RtrSz+4,4)left(' ',RtrSz,' ')
 
if ssid = '' then do
 say 'YOU MUST ENTER THE NAME OF THE DB2 SUBSYSTEM'
 exit 20
end
if numtimes = '' then numtimes = 60
if datatype(numtimes) <> 'NUM' then do
 logds = numtimes
 numtimes = 60
end
 
say ' '
say 'Processing for Subsys' ssid
say '    Number of iteration : ' numtimes
say '    Sleep time (seconds): ' sleeptime
say ' '
 
/* init compteurs divers */
call init_var
/* Connect to DB2 */
CALL Init_DB2
/* Start Trace IFCID 318 (switch on) */
CMD = '-STA TRA(MON) C(30) IFCID(318)'
tno =StartTrace(CMD)
if tno  < 0 then exit(8)
/* Wait 5 minutes to collect stats */
if NoWait <> 'NOWAIT' then
     call Wait 300
/* Start 316 and 317 */
CMD = '-STA TRA(MON) C(30) IFCID(316,317) BUFSIZE(10240)'
tno2 =StartTrace(CMD)
if  tno2  < 0 then exit(8)
 
iterno = 0
 
call AllocFile
/* Loop of  READS command using IFI interface */
do numtimes
    a=date()
    b=time()
    iterno = iterno+1
    say b 'Iteration' iterno 'of' numtimes', Records written:' reco
    /* WRITE report header */
    if iterno =  1  then CALL Writeheader
    call IFIReads
    if  bytes_moved > 0 then
      do
          call ProcessIFIData316
      end
    if numtimes > 1 & iterno <numtimes then call Wait sleeptime
end /* end do numtimes */
/*  Close  file */
"EXECIO "QUEUED()" DISKW OUFS(FINIS"
   if rc > 0 then
   do
        say 'Error writing output file' rc
        exit(8)
   end
"FREE F(OUFS)"
 
/* End of program */
say ' '
say '*** END OF PROGRAM IFC316 ***'
say 'Stopping trace for IFCID 318 ...'
x=StopTrace(tno)
x=StopTrace(tno2)
 
/* Disconnect from DB2 */
ADDRESS DSNREXX "DISCONNECT"
 
say 'End of Program'
say '   Nbr records written : ' reco
say '   Nbr records read    : ' reci
say '   Nbr Reads 317 NOK   : ' err317
exit 0
 
StopTrace: procedure
 arg tno
 if tno = 99 then do
    say 'Trace not stopped as not started by this program'
    return(0)
 end
 if datatype(tno) = 'NUM' & tno > 0 then do
    say 'Try to stop trace ...' tno
    CMD = '-STO TRACE(MON) TNO('tno')'
    COMMAND = substr('COMMAND',1,10)
    IFCA = '00B40000'X!!'IFCA'!!copies('00'X,172)
    RtrSz = 512
    RtrArea = d2c(RtrSz+4,4)left(' ',RtrSz,' ')
    DumZon = d2c(length(CMD)+4,2)!!'0000'X!!CMD
    Buff = '00000000'X!!'WBUF'!!'0000000000000000'X
    ADDRESS LINKPGM "DSNWLI2 COMMAND IFCA RtrArea DumZon Buff"
    LEN = c2d(substr(RtrArea,5,2))
    MSG = substr(RtrArea,9,LEN-5)
    parse var MSG msgno . 'TRACE NUMBER(S)' tno
    RetC = c2d(substr(IFCA,13,4))
    Reas = d2x(c2d(substr(IFCA,17,4)))
    if RetC <> 0 & Reas <> 'E60820' then do
     say 'PROBLEM WITH STOP TRACE COMMAND'
     say 'COMMAND RETCODE = ' RetC
     say 'COMMAND REASON = ' Reas
    end
    if msgno =  'DSNW131I' then
         say 'Trace Stopped TNO' tno
 end    /* if datatype(tno */
 else say '** Warning - MONITOR trace was started but not stopped **'
 return(0)
/*--------------------------------------------------------------------*/
 
QW0316:
       arg offset_ifc
       /* save start of Ifcid Data */
       Offs=Offset_ifc
       /* QW0316ID    */
       QW0316ID =SUBSTR(rec,offs,20)
       offs = offs +16
       QW0316TK =c2d(SUBSTR(rec,offs,4))
       offs = offs +8
       /* nbr users QW0316US*/
       CurrUsers = C2D(SUBSTR(rec,offs,8))
       offs = offs +8
       /* copies  QW0316CP */
       Copies    = C2D(SUBSTR(rec,offs,4))
       offs = offs +4
       /* Status  QW0316FL */
       Status    = SUBSTR(rec,offs,1)
       offs = offs +1
       select
           When status = '80'x then status = 'Invalid DROP/ALTER'
           When status = '40'x then status = 'Invalid REVOKE'
           When status = '20'x then status = 'Removed LRU'
           When status = '10'x then status = 'Invalid RUNSTAT'
           Otherwise  status = 'OK'
       end
       if status <> 'OK' then return 8
       /* Cache literal replacement indicator*/
       QW0316LR =  SUBSTR(rec,offs,1)
       if QW0316LR =  ' ' then QW0316LR=''
       offs = offs +1
       /* Timestamp insert in cache */
       QW0316TM =c2x(substr(rec,offs,10))
       QW0316TM = substr(QW0316TM,1,4)'-'substr(QW0316TM,5,2),
            !! '-'substr(QW0316TM,7,2)'.'substr(QW0316TM,9,2),
            !! '.'substr(QW0316TM,11,2)'.'substr(QW0316TM,13,2)
       offs = offs +10
       /* nbr execs QW0316NE*/
       nbr_execs =c2d(SUBSTR(rec,offs,8))
       offs = offs +8
       /* nbr reads  QW0316NB */
       nbr_reads=c2d(SUBSTR(rec,offs,8))
       offs = offs +8
       /* nbr gp    QW0316NG */
       nbr_gp =c2d(SUBSTR(rec,offs,8))
       offs = offs +8
       /* nbr examined rows */
       nbr_ER =c2d(SUBSTR(rec,offs,8))
       offs = offs +8
       /* nbr rows Processed */
       nbr_pr =c2d(SUBSTR(rec,offs,8))
       offs = offs +8
       /* nbr sorts */
       nbr_sort =c2d(SUBSTR(rec,offs,8))
       offs = offs +8
       /* nbr ix scans */
       nbr_ixscan =c2d(SUBSTR(rec,offs,8))
       offs = offs +8
       /* nbr TS scans*/
       nbr_tsscan =c2d(SUBSTR(rec,offs,8))
       offs = offs +8
       /* nbr Parallel groups created*/
       nbr_PG =c2d(SUBSTR(rec,offs,8))
       offs = offs +8
       /* nbr buffer sync writes QW0316NW*/
       nbr_syncwr =c2d(SUBSTR(rec,offs,8))
       offs = offs +8
       /* db2 elapsed   QW0316AE */
       elapse = c2x(SUBSTR(rec,offs,8))
       elapse   = x2d(substr(elapse,1,13))
       elapse   = elapse  /1000000
       /* skip ... waits ...*/
       /* pgm name      */
       offs = offs +70
       len=c2d(SUBSTR(rec,offs,2))
       /*QW0316T1*/
       pgm_name = SUBSTR(rec,offs+2,len)
       if pgm_name <> 'DSNACCOX' then
             return 1
       offs = offs +46
       /* QW0316T2 */
       tran_name = strip(SUBSTR(rec,offs,10),'t')
       offs = offs +32
       /* QW0316XE*/
       end_user  = SUBSTR(rec,offs,8)
       offs = offs +16
       if end_user = '0000000000000000'x then
          end_user = ''
       else end_user=strip(end_user,'t')
       /* QW0316XF*/
       wrkstation= strip(SUBSTR(rec,offs,18),'t')
       offs = offs +60
       if substr(wrkstation,1) = '00'x then
          wrkstation = ''
       /* QW0316TS date statistic started gmt time */
       /* (stats begin when IFCID318 is started    */
       QW0316TS  = c2x(SUBSTR(rec,offs,8))
       QW0316TS = substr(QW0316TS,1,4)'-'substr(QW0316TS,5,2),
            !! '-'substr(QW0316TS,7,2)'.'substr(QW0316TS,9,2),
            !! '.'substr(QW0316TS,11,2)'.'substr(QW0316TS,13,2)
       offs = offs +40
       /* db2 cpu (including ziip) QW0316CT  */
       cputime  = c2x(SUBSTR(rec,offs,8))
       cputime  = x2d(substr(cputime,1,13))
       cputime  = cputime     /1000000
       offs = offs +56
       /* RID list failed Limit   QW0316RT */
       rid_limit= c2d(SUBSTR(rec,offs,8))
       offs = offs +8
       /* RID list failed Storage  QW0316RS */
       rid_stor = c2d(SUBSTR(rec,offs,8))
       return 0
 
QW0317: procedure
       arg offs,rec
       /* QW0317ST    */
       offs = offs + 20
       /*QW0317LN*/
       QW0317LN=c2d(SUBSTR(rec,Offs,4))
       offs=offs+4
       /*QW0317TX SQL Text Truncate at 10000 bytes*/
       if QW0317LN > 10000 then QW0317LN = 10000
       QW0317TX = SUBSTR(rec,offs,QW0317LN)
       QW0317TX = space(QW0317TX,1)
       return QW0317TX
 
AllocFile:
   /* Report dataset  */
   Datex=substr(date(j),3,3)
   Timex=time()
   Timex=substr(timex,1,2)!!substr(timex,4,2)
   Datex='D'Datex!!Timex
   oufs = "'" !! hlq !! '.IFC316.' !! ssid !!'.'!!Datex"'"
   if first=1  then
   do
       "DELETE" oufS "PURGE"
       first=0
   end
 
   "ALLOC FI(OUFs) DA("oufs") MOD CATALOG REUSE" ,
   "LRECL(10550) RECFM(V B) CYLINDERS SPACE(600,600)"
   rcalloc = rc
   if rcalloc <> 0 then Do
        say "**********************************************"
        say "   Error allocating repSQL file" rcalloc
        say "   Abnormal end  "
        say "**********************************************"
        Exit 8
   end
  RETURN
 
init_var:
  /* compteurs input/DumZon */
  reco= 0
  reci= 0
  return
 
Writeheader:
    say 'CSV file ' oufS     ' will be produced'
    queue "Date;Time;Ssid;StmId;TsInsCach;TsStaStats;",
    "Elap;Cpu;CurUsers;Copies;",
    "LitRep;Execs;Getp;Reads;SyncWr;ExamRows;ProcRows;",
    "Sort;IxScan;TsScan;ParalGrp;RIDFdLim;RIDFdStor;",
    "Pgm;Tran;EndUser;WrkStation;SqlText;"
 
    "EXECIO" queued() "DISKW OUFS"
    if rc > 0 then
    do
         say 'Error writing output file' rc
         exit(8)
    end
  return
 
WriteReport:
    reco= reco+ 1
    /*rows in excel format */
    queue a !! ';' !! b !! ';' !! ssid !! ';',
    !! QW0316TK    !! ';',
    !! QW0316TM    !! ';',
    !! QW0316TS    !! ';',
    !! elapse      !! ';',
    !! cputime     !! ';',
    !! CurrUsers   !! ';',
    !! Copies      !! ';',
    !! QW0316LR    !! ';',
    !! nbr_execs   !! ';',
    !! nbr_gp      !! ';',
    !! nbr_reads   !! ';',
    !! nbr_syncwr  !! ';',
    !! nbr_ER      !! ';',
    !! nbr_pr      !! ';',
    !! nbr_sort    !! ';',
    !! nbr_ixscan  !! ';',
    !! nbr_tsscan  !! ';',
    !! nbr_PG      !! ';',
    !! rid_limit   !! ';',
    !! rid_stor    !! ';',
    !! pgm_name    !! ';',
    !! tran_name   !! ';',
    !! end_user    !! ';',
    !! wrkstation  !! ';',
    !! '"' !! QW0316ST !! '"' !! ';'
 
   "EXECIO "QUEUED()" DISKW OUFS"
   if rc > 0 then
   do
        say 'Error writing output file' rc
        exit(8)
   end
return
 
IFIReads:
/* Prepare zones for READS */
   READS = substr('READS',1,8)
   IFCA = '00B40000'X!!'IFCA'!!copies('00'X,172) /* 180*/
   IFCIDAREA = '00060000013C'X  /*IFCID 316*/
   /* Qualify Area is described by DSNDWQAL */
   /* Length of Qual. Area must have some defined  */
   /* values. Cf. SDSNMACS*/
   /* Otherwise Error - LEN choosen 920 WQALLN9 */
   /* QUAL below no selection */
   /*QUAL     = '03980000'X !! 'WQAL' !! copies('00'x,912)*/
   QUAL     = '03980000'X !! 'WQAL'  ,
          !! copies('00'x,158)  ,
          !! '02'x         , /*QWALFLTR Activate filter */
          !! 'G'           , /*QWALFFLD  Qualify on Getpage */
          !! '00000001'x   , /*QWALFVAL At least xxxx GETPAGE */
          !! copies('00'x,744)
   ADDRESS LINKPGM "DSNWLI2 READS IFCA RtrArea IFCIDAREA QUAL"
   RetC = c2d(substr(IFCA,13,4))
   Reas = d2x(c2d(substr(IFCA,17,4)))
   if RetC > 4 then do
        say 'Error READS ...'
        say '  READS RETCODE = ' RetC
        say '  READS REASON = ' Reas
        x=StopTrace(tno2)
        exit 8
   end
   bytes_moved = c2d(substr(IFCA,21,4)) /*IFCABM*/
   bytes_left = c2d(substr(IFCA,25,4))   /*IFCABNM*/
/* say bytes_moved bytes_left time() */
/* if bytes_moved = 0 then
      do
        say '** Warning - Nothing to read  **'
        return
      end */
   RETURN
 
Reads317:
   RtrSz = 10240
   RtrArea317 = d2c(RtrSz+4,4)left(' ',RtrSz,' ')
   IFCIDAREA = '00060000013D'X  /*IFCID 317*/
   /* Qualify Area is described by DSNDWQAL */
   /* Length of Qual. Area must have some defined  */
   /* values. Cf. SDSNMACS*/
   /* Performance Guide  on READS */
   /* Otherwise Error - LEN choosen 192 WQALLN5 */
   QUAL     = '00C00000'X !! 'WQAL'  ,
       !! copies('00'x,158)  ,
       !! '03'x         , /*QWALFTR Activate filter */
       !! 'Z'           , /*QWALFFLD Not used */
       !! '00000000'x   , /*QWALFVAL Not used  4 bytes*/
       !! QW0316ID        /*QWALSTNM 16 bytes + qwalstid */
 
   ADDRESS LINKPGM "DSNWLI2 READS IFCA RtrArea317 IFCIDAREA QUAL"
   RetC = c2d(substr(IFCA,13,4))
   Reas = d2x(c2d(substr(IFCA,17,4)))
   bytes_moved317 = c2d(substr(IFCA,21,4)) /*IFCABM*/
   if RetC > 0 then
      err317 = err317 + 1
   return
 
 
Wait:
      arg sleeptime
      call syscalls 'ON'
      address syscall 'sleep ' sleeptime
      call syscalls 'OFF'
return
 
Init_DB2:
  /* Connect to DB2 subsystem */
  ADDRESS TSO "SUBCOM DSNREXX"
   if RC then
   S_RC = RXSUBCOM('ADD','DSNREXX','DSNREXX')
  ADDRESS DSNREXX "CONNECT "SSID
  if SQLCODE <> 0 then do
   say 'PROBLEM CONNECTING TO DB2'
   say 'SQLCODE = ' SQLCODE
   say 'SQLSTATE = ' SQLSTATE
   say 'SQLERRP = ' SQLERRP
   say 'SQLERRMC = ' SQLERRMC
   exit 12
  end
  return
 
StartTrace: Procedure
  arg CMD
  say CMD
  COMMAND = substr('COMMAND',1,10)
  /*init zones */
  IFCA = '00B40000'X!!'IFCA'!!copies('00'X,172) /*180*/
  RtrSz = 512
  RtrArea = d2c(RtrSz+4,4)left(' ',RtrSz,' ')
  DumZon = d2c(length(CMD)+4,2)!!'0000'X!!CMD
  Buff = '00000000'X!!'WBUF'!!'0000000000000000'X
  /* Submit START command using IFI interface */
  ADDRESS LINKPGM "DSNWLI2 COMMAND IFCA RtrArea DumZon Buff"
  RetC = c2d(substr(IFCA,13,4))
  Reas = d2x(c2d(substr(IFCA,17,4)))
  if RetC <> 0 & Reas <> 'E60820' then do
     say 'PROBLEM WITH START TRACE COMMAND'
     say 'COMMAND RETCODE = ' RetC
     say 'COMMAND REASON = ' Reas
     return(-1)
  end
  /*
    Check if message DSNW130I was issued indicating a
    new trace has been
    started, and if so remember the tno so trace can be stopped later.
  */
  LEN = c2d(substr(RtrArea,5,2))
  MSG = substr(RtrArea,9,LEN-5)
  parse var MSG msgno . 'TRACE NUMBER 'tno
  if pos('318',cmd) > 0 & msgno = 'DSNW135I' then
  do
      Say 'IFCID 318 already started TNO' tno
      return 99
  end
  if msgno <> 'DSNW130I' then do
                         say MSG
                         return(-1)
                      end
  if msgno <> 'DSNW135I' then
     say  'Trace started TNO' tno
  return(tno)
 
ProcessIfiData316:
    /* RTRAREA described by DSNDQWIW */
    if  c2d(substr(RtrArea,5,1)) = 128   /* first byte = x'80' */
      then    len  = c2d(substr(RtrArea,6,3)) /* Len QWIWLEN */
      else    len  = c2d(substr(RtrArea,5,2))
    Rec  = substr(RtrArea,5,LEN)     /* recup data */
    /* process each data section*/
    /* varying length repeating group */
    OffsData= c2d(substr(rec,13,4))+1
    LenData= c2d(substr(rec,17,2))
    /* len can be zero , read sdsnmacs DSNDQWT0 */
    /* (it is called "varying length repeating group")  */
    RepData= c2d(substr(rec,19,2))
    /* 316 = varying len repat. group  LenData=0    */
    i = 1
    /* 316 is a Var Len Repeating Group */
    do while i <= RepData
          reci=reci+1
          LenData= c2d(substr(rec,OffsData,2))
          i=i+1
       /* Subsequent members can be found by advancing the pointers*/
       /* (length of current member + 2 bytes) forward.            */
          Call QW0316 OffsData+2
          if result = 0 then
          do
              /* Get Long SQL Text if not done yet */
              Call Reads317
              if RetC = 0 then
              do
                Call ProcessIfiData317
                Call WriteReport
              end
          end
          OffsData= OffsData+LenData+2 /*cf doc sdsnmacs*/
    end
 
return
 
ProcessIfiData317:
   /* Look at IfiHeaderCheck for comments */
   if  c2d(substr(RtrArea317,5,1)) = 128   /* first byte = x'80' */
      then    len317  = c2d(substr(RtrArea317,6,3)) /* Len QWIWLEN */
      else    len317  = c2d(substr(RtrArea317,5,2))
   Rec317  = substr(RtrArea317,5,len317)     /* recup data */
   /* go to Product section - mapped by DSNDQWHS */
   /* process each data section*/
   /* 13=5+8*1  ptr to next self de. data section */
   OffsData317= c2d(substr(rec317,13,4))+1
   /* len can be zero , read sdsnmacs DSNDQWT0 */
   /* (it is called "varying length repeating group")  */
   /* Not the case of IFCID 317 */
   /* Decode IFCID 317 to get SQL Text Long  */
   QW0316ST=qw0317(OffsData317,rec317)
return

/* REXX ***************************************************************/
/* 15Apr2019 New improved release                                     */
/*                                                                    */
/* <ssid>       DB2 subsystem name                                    */
/* <numtimes>   Number of intervals (default 60)                      */
/* <sleeptime>  Time in seconds between two intervals (default 60)    */
/* <GPMin>      Filter only records with Getpage > GPMin              */
/*                                                                    */
/* For information on programming "Managing Performance V11"          */
/* chapter : "Programming for the Instrumentation Facility Interface" */
/*                                                                    */
/* REXX****************************************************************/
arg  ssid hlq numtimes sleeptime GPMin Nowait
numeric digits 25
 
if ssid = '' then do
 say 'YOU MUST ENTER THE NAME OF THE DB2 SUBSYSTEM'
 exit 20
end
if numtimes = '' then numtimes = 60
if datatype(numtimes) <> 'NUM' then do
 logds = numtimes
 numtimes = 60
end
 
if GPMin     = '' then GPMin     = 1
 
say ' '
say 'Processing for Subsys' ssid
say '    Number of iteration : ' numtimes
say '    Sleep time (seconds): ' sleeptime
say '    Getpage minimum     : ' GPMin
say ' '
 
/* init compteurs divers */
call init_var
/* Connect to DB2 */
CALL Init_DB2
/* Start Trace IFCID 400 (switch on) */
CMD = '-STA TRACE(MON) CLASS(30) IFCID(400)'
tno2=StartTrace(CMD)
if tno2 < 0 then exit(8)
/* wait 5 minutes to have enough stats */
if nowait <> 'NOWAIT' then
    call wait 300
/* Prepare START TRACE command */
CMD = '-STA TRACE(MON) CLASS(32) IFCID(401) BUFSIZE(10240)'
tno=StartTrace(CMD)
if tno < 0 then do
        x=Stoptrace(tno2)
        exit(8)
    end
 
iterno = 1
a=date()
call Alloc_File
/* WRITE report header */
CALL write_header
 
/* Loop of  READS command using IFI interface */
do numtimes
    say 'iteration :' iterno
    b=time()
    call IFIReads
    Say '**** READS ****' time() bytes_moved
    if  bytes_moved > 0 then
    do
        call ProcessData
    end
    if numtimes > 1 then call Wait sleeptime
    iterno = iterno+1
end /* end do numtimes */
/* Close & Deallocate files */
"EXECIO "QUEUED()" DISKW OUFS(FINIS"
"FREE F(OUFS)"
 
/* End of program */
x=StopTrace(tno2)
x=StopTrace(tno)
 
/* Disconnect from DB2 */
ADDRESS DSNREXX "DISCONNECT"
 
say 'End of Program'
say '   Nbr records skipped GP Minimum encountered :' NbrSkipGP
say '   Nbr records written : ' reco
say '   Nbr records read    : ' reci
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
ProcessVarLenRepGroup:
      k=i   /* number of data section to process */
  /*  Say 'ProcessVarLenRepGroup: number of data sect to process' i*/
      offset_data2= offset_data
      do while k <= rep_data
          len_data2= c2d(substr(rec,offset_data2,2))
          k=k+1
       /* Subsequent members can be found by advancing the pointers*/
       /* (length of current member + 2 bytes) forward.            */
          Call QW0401 offset_data2+2
          if write   > 0 then Call Write_RepSQL
          /* offset_data2 not updated by QW0401 */
          offset_data2=  offset_data2+len_data2+2 /*cf doc sdsnmacs*/
      end
   RETURN
 
QW0401:
       arg offset_ifc
    /* say 'QW0401 Process offset' offset_ifc */
     /*say 'Process data section QW0401'*/
       write = 1
       /* save start of Ifcid Data */
       Offs=Offset_ifc
       /* Getpage     */
       QW0401GP =c2d(SUBSTR(rec,offs+24,8))
    /* if QW0401GP < 1000  then
           do
               /* exclude Getpage < 1000  */
               write = 0
               NbrSkipGP = NbrSkipGP+1
               return
           end */
       /* db2 cpu (including ziip) */
       QW0401CP = c2x(SUBSTR(rec,offs+96,8))
       QW0401CP = x2d(substr(QW0401CP,1,13))
       QW0401CP = QW0401CP /1000000
    /* if QW0401CP < 1     then
           do
               /* exclude cpu < 1 sec     */
               write = 0
               return
           end */
       /* offset_QW0401 will be used later */
       /*offset_d points to the IFCID 401 data to process */
       QW0401ID =C2D(SUBSTR(rec,offs,8))
       offs = offs +8
       /* nbr execs */
       QW0401EX =c2d(SUBSTR(rec,offs,8))
       offs = offs +8
       /* nbr sync buffer reads */
       QW0401SR =c2d(SUBSTR(rec,offs,8))
       offs = offs +16
       /* nbr examined rows */
       QW0401ER =c2d(SUBSTR(rec,offs,8))
       offs = offs +8
       /* nbr rows processed */
       QW0401PR =c2d(SUBSTR(rec,offs,8))
       offs = offs +8
       /* nbr sorts */
       QW0401ST =c2d(SUBSTR(rec,offs,8))
       offs = offs +8
       /* nbr ix scans */
       QW0401IX =c2d(SUBSTR(rec,offs,8))
       offs = offs +8
       /* nbr TS scans*/
       QW0401TB =c2d(SUBSTR(rec,offs,8))
       offs = offs +8
       /* nbr Buff writes*/
       QW0401WT =c2d(SUBSTR(rec,offs,8))
       offs = offs +8
       /* nbr Parallel groups created*/
       QW0401PG =c2d(SUBSTR(rec,offs,8))
       offs = offs +8
       /* db2 elapse time */
       QW0401ET = c2x(SUBSTR(rec,offs,8))
       QW0401ET = x2d(substr(QW0401ET,1,13))
       QW0401ET = QW0401ET /1000000
       offs = offs +16
       /* wait time for sync IO    */
       QW0401SI = c2x(SUBSTR(rec,offs,8))
       QW0401SI = x2d(substr(QW0401SI,1,13))
       QW0401SI = QW0401SI/1000000
       offs = offs +32
       /* wait time for other Reads  */
       QW0401OR = c2x(SUBSTR(rec,offs,8))
       QW0401OR = x2d(substr(QW0401OR,1,13))
       QW0401OR = QW0401OR/1000000
       offs = offs +8
       /* wait time for other Write  */
       QW0401OW = c2x(SUBSTR(rec,offs,8))
       QW0401OW = x2d(substr(QW0401OW,1,13))
       QW0401OW = QW0401OW/1000000
       offs = offs +8
       /* RID list failed Limit    */
       QW0401RL= c2d(SUBSTR(rec,offs,8))
       offs = offs +8
       /* RID list failed Storage  */
       QW0401RS = c2d(SUBSTR(rec,offs,8))
       offs = offs +48
       /* Package token   */
       QW0401CT= c2x(SUBSTR(rec,offs,8))
       offs = offs +8
       /* Process Pkg Collection */
       Tmp_Off=C2D(SUBSTR(rec,offs,2))
       Tmp_Off=Tmp_Off + offset_ifc
       len=C2D(SUBSTR(rec,Tmp_Off,2))
       QW0401CL =SUBSTR(rec,Tmp_Off+2,len)
       /* Process Pkg Name */
       offs = offs +2
       Tmp_Off=C2D(SUBSTR(rec,offs,2))
       Tmp_Off=Tmp_Off + offset_ifc
       len=C2D(SUBSTR(rec,Tmp_Off,2))
       QW0401PK    =SUBSTR(rec,Tmp_Off+2,len)
       if QW0401PK <> 'DSNACCOX' then do
          write = 0
          return
       end
       offs = offs +2
       if  QW0401EX = QW0401TB  & QW0401CP >60 then
       do
         say 'TS    Scan detected, exec > 60s :',
         strip(QW0401CL)!!'.'strip(QW0401PK)'.'!!,
         right(QW0401ID,8,'0')
       end
       /* QW0401TM2 */
       clock =c2x(SUBSTR(rec,offs,8))
       Parse Value Stck2Local(clock) With datei timei
       offs = offs +18
       /* QW0401UT1 */
       clock =c2x(SUBSTR(rec,offs,8))
       Parse Value Stck2Local(clock) With dateS timeS
       return
 
Alloc_File:
   /* Report dataset  */
   oufs = "'" !! hlq !! '.IFC401.' !! ssid !! "'"
   /* "DELETE" oufS "PURGE" */
 
   "ALLOC FI(OUFs) DA("oufs") MOD CATALOG REUSE" ,
   "LRECL(350) RECFM(V B) TRACKS SPACE(300,200)"
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
   /* Init some zones of IFI calls */
   READS = 'READS   '
   RtrSz = 10000000 /* 16000000 partout sauf sofinco*/
   RtrArea = d2c(RtrSz+4,4)left(' ',RtrSz,' ')
   /* Convert gpmin to hexa to be qualified by READS statement */
   gpmin='00000000'd2x(gpmin)
   gpmin=right(gpmin,8)
   QUAL     = '03980000'X !! 'WQAL'  ,
        !! copies('00'x,158)  ,
        !! '02'x         , /*QWALFTR Activate filter */
        !! 'G'           , /*QWALFFLD  Qualify on Getpage */
        !! x2c(gpmin)    , /*QWALFVAL At least 0010 GETPAGE */
     !! copies('00'x,744)
 
  /* compteurs input/DumZon */
  numtimes=numtimes+1
  NbrSkipGP = 0
  nbr_ifcid = 0
  reco= 0
  reci= 0
  recs= 0
  min_time='23:59:59'
    QW0401ID =-1
    Use_Cnt=-1
    tran_name='NA'
    end_user='NA'
    wrkstation='NA'
    table_name='NA'
    sql_text='NA'
    QW0401CT='NA'
    QW0401CL='NA'
  return
 
write_header:
    say 'CSV file ' oufS     ' will be produced'
    queue "Date,Time,SSID,StmID,DatInEDM,TimeIn,DateStats,TimeS,",
       "Elap,Cpu,Execs,SyncRead,BufWr,GP,WtSyncIO,WOthRd,WOthWr,",
       "ExRows,ProcRows,",
       "Sort,IxScan,TsScan,ParaGrp,",
       "RIDLim,RIDStor,PgmN,ColId,PkgTok,"
 
    "EXECIO" queued() "DISKW OUFS"
  return
 
Write_RepSQL:
    reco= reco+ 1
    /*rows in excel format */
    queue a !! ',' !! b !! ',' !! ssid      !! ',' ,
    !! right(QW0401ID,8,'0')     !! ',' ,
    !! DateI        !! ','   ,
    !! substr(TimeI,1,13)        !! ','   ,
    !! DateS        !! ','   ,
    !! substr(TimeS,1,13)        !! ','   ,
    !! QW0401ET     !! ','   ,
    !! QW0401CP     !! ','   ,
    !! QW0401EX     !! ','   ,
    !! QW0401SR     !! ','   ,
    !! QW0401WT     !! ','   ,
    !! QW0401GP     !! ','   ,
    !! QW0401SI     !! ','   ,
    !! QW0401OR     !! ','   ,
    !! QW0401OW     !! ','   ,
    !! QW0401ER     !! ','   ,
    !! QW0401PR     !! ','   ,
    !! QW0401ST     !! ','   ,
    !! QW0401IX     !! ','   ,
    !! QW0401TB     !! ','   ,
    !! QW0401PG     !! ','   ,
    !! QW0401RL     !! ','   ,
    !! QW0401RS     !! ','   ,
    !! QW0401PK     !! ','   ,
    !! QW0401CL     !! ','   ,
    !! QW0401CT     !! ','
 
   "EXECIO "QUEUED()" DISKW OUFS"
   if rc > 0 then
      do
           say 'Error writing output file' rc
           exit(8)
      end
return
 
IFIReads:
   IFCA = '00B40000'X!!'IFCA'!!copies('00'X,172) /* 180*/
   IFCIDAREA = '000600000191'X  /*IFCID 401*/
   /* Qualify Area is described by DSNDWQAL */
   /* Length of Qual. Area must have some defined  */
   /* values. Cf. SDSNMACS*/
   /* Otherwise Error - LEN choosen 920 WQALLN9 */
   /*
   QUAL     = '03980000'X !! 'WQAL' !! copies('00'x,912) */
   ADDRESS LINKPGM "DSNWLI2 READS IFCA RtrArea IFCIDAREA QUAL"
   RetC = c2d(substr(IFCA,13,4))
   Reas = d2x(c2d(substr(IFCA,17,4)))
   if RetC > 4 then do
        say 'Error READS ...'
        say '  READS RETCODE = ' RetC
        say '  READS REASON = ' Reas
        x= StopTrace(tno)
        exit 8
   end
   bytes_moved = c2d(substr(IFCA,21,4)) /*IFCABM*/
   bytes_left = c2d(substr(IFCA,25,4))  /*IFCABNM*/
   if bytes_left > 0 then
      say bytes_left ' bytes not reported'
   return
 
IfiHeaderCheck:
 /* Processing RTRAREA */
 /* 4 bytes (RTRAREA Len.)  */
 /* 2 bytes (IFCID Data Len) + 2 reserved  */
 /* Self defining Section (Pointers to Prod section and data sect. */
 /*      4 bytes offset to Prod, 2 bytes Len of Prod Section,  */
 /*                              2 bytes Repeat Prod Section,  */
 /*      4 bytes offset to Data, 2 bytes Len of Data Section,  */
 /*                              2 bytes Repeat Data Section,  */
 /* Header described by DSNDQWIW */
 if  c2d(substr(RtrArea,5,1)) = 128   /* first byte = x'80' */
    then    len  = c2d(substr(RtrArea,6,3)) /* Len QWIWLEN */
    else    len  = c2d(substr(RtrArea,5,2))
 Rec  = substr(RtrArea,5,LEN)     /* recup data */
 /* go to Product section - mapped by DSNDQWHS */
 offset_prod = c2d(substr(rec,5,4))+1
 /* len_prod = c2d(substr(rec,9,2))
 rep_prod = c2d(substr(rec,11,2)) */
 Ifcid = c2d(substr(rec,offset_prod+4,2))
 DataN  = c2d(substr(rec,offset_prod+6,1))
 RETURN
 
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
    days    = clock %  (24*60*60)
    days    = days + 2415021
    Parse Value DATECONV(days) With y m d dow
    hours   = RIGHT( seconds %3600    ,2,'0')
    minutes = RIGHT((seconds//3600)%60,2,'0')
    seconds = seconds//60
    /* t1      = y'/'m'/'d hours':'minutes':'seconds   */
    /*TsTime  =  hours':'minutes':'seconds
    TsDate  =  y'/'m'/'d */
    return  y'/'m'/'d hours':'minutes':'seconds
 
DATECONV:
    Parse Upper Arg julday
    j =julday-1721119
    d =((4*j-1)//146097+146097)//146097
    d =d%4
    y =(4*j-1)%146097*100+(4*d+3)%1461
    d =(((4*d+3)//1461+1461)//1461+4)%4
    m =(5*d-3)%153
    d =(((5*d-3)//153+153)//153+5)%5
    If m<10 ,
      Then  Parse Value m+3     With m
      Else  Parse Value m-9 y+1 With m y
    dow = (julday+1)//7
    Return RIGHT(y,4,'0') RIGHT(m,2,'0') RIGHT(d,2,'0')   ,
       WORD('Sun Mon Tue Wed Thu Fri Sat',1+dow) !! 'day'
 
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
   say 'PROBLEM CONNECTING TO SUBSYSTEM' ssid
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
  if pos('400',cmd) > 0 & msgno = 'DSNW135I' then
  do
      Say 'IFCID 400 already started TNO' tno
      return 99
  end
  if msgno <> 'DSNW130I' then do
                         say MSG
                         return(-1)
                      end
  if msgno <> 'DSNW135I' then
     say  'Trace started TNO' tno
  return(tno)
 
ProcessData:
    call IfiHeaderCheck
    /* process each data section*/
    i = 1
    do while i <  datan
     /* say 'Processing Self Defined Data' i */
        j=5+8*i /* ptr to next self de. data section */
        offset_data= c2d(substr(rec,j,4))+1
        len_data= c2d(substr(rec,j+4,2))
        /* len can be zero , read sdsnmacs DSNDQWT0 */
        /* (it is called "varying length repeating group")  */
        rep_data= c2d(substr(rec,j+6,2))
    /*  say 'off data/len/rep' offset_data len_data rep_data */
        if len_data = 0 then
        do
            reci=reci+1
            call ProcessVarLenRepGroup
            leave
        end
     /* This can't happen to IFCID401 */
     /* call QW0401 offset_data
        if write   > 0    then
                      call Write_RepSQL */
    end
return

/* REXX ***************************************************************/
/* IFCID 376/366 reporting functions incompatibilities                */
/* => Get SQL Text  with IFCID 317                                    */
/*                                                                    */
/* <ssid>       DB2 subsystem name                                    */
/* <numtimes>   Number of intervals (default 60)                      */
/* <sleeptime>  Time in seconds between two intervals (default 60)    */
/* By default EXCLUDE records with Cputime=0  QW0401CP                */
/*                                                                    */
/* For information on programming "Managing Performance V11"          */
/* chapter : "Programming for the Instrumentation Facility Interface" */
/*                                                                    */
/* REXX****************************************************************/
arg suf ssid numtimes sleeptime ifcids
numeric digits 25
first=1
 
hlq='SYSTMP.WSYNGUD'
if suf = 'AUTO' then
do
   suf=ssid
end
if ssid = '' then do
 say 'YOU MUST ENTER THE NAME OF THE DB2 SUBSYSTEM'
 exit 20
end
if numtimes = '' then numtimes = 60
if datatype(numtimes) <> 'NUM' then do
 logds = numtimes
 numtimes = 60
end
/* With READA, the first read is the -STA TRACE command text  */
numtimes = numtimes + 1
 
say ' '
say 'Processing for Subsys' ssid
say '    Number of iteration : ' numtimes
say '    Sleep time (seconds): ' sleeptime
say ' '
 
/* init compteurs divers */
call init_var
/* Connect to DB2 */
CALL Init_DB2
/* Start Trace IFCID 376  */
CMD = '-STA TRA(MON) C(30) IFCID('ifcids') D(OPX) BUFSIZE(10240)'
tno=StartTrace(CMD)
IFCAOPN376 = IFCAOPN
if tno < 0 then do
        exit(8)
    end
/* Init zones for READA */
READA = substr('READA',1,8)
IFCA = SUBSTR('00'X,1,180,'00'X)
IFCA = OVERLAY(D2C(LENGTH(IFCA),2),IFCA,1+0)
IFCA = OVERLAY("IFCA",IFCA,4+1)
IFCA = OVERLAY(IFCAOPN376,IFCA,36+1)
IFCA = OVERLAY('0004'X,IFCA,40+1)
RtrSz = 10240000
RtrArea = d2c(RtrSz+4,4)left(' ',RtrSz,' ')
 
/* Start IFCID 318 (switch on) & 317 */
CMD = '-STA TRA(MON) C(30) IFCID(318,317) BUFSIZE(10240)'
tno2=StartTrace(CMD)
if tno2 < 0 then exit(8)
 
iterno = 1
call Alloc_File
 
/* Loop of  READA command using IFI interface */
do numtimes
    a=date()
    b=time()
    /* WRITE report header */
    if iterno =  1  then CALL WriteHeader
    READCount=0
    Do until READcount > 50
        READCount=READCount+1
        call IFIREADA
        if BytesMoved376 = 0 then leave
        /* Decode first time Ret Area */
        OfsRecREADA376=5
        /* Read  repeated data from IFI RetArea */
        Do while OfsRecREADA376 < BytesMoved376
            /* first byte = x'80' */
            if  c2d(substr(RtrArea,OfsRecREADA376,1)) = 128
               then  LenRec = c2d(substr(RtrArea,OfsRecREADA376+1,3))
               else  LenRec = c2d(substr(RtrArea,OfsRecREADA376,2))
            Rec  = substr(RtrArea,OfsRecREADA376,LenRec)
            /* Standard Header */
            OfsProd = c2d(substr(rec,5,4))+1
            LenStdHdr= c2d(substr(rec,OfsProd,2))
            Ifcid = c2d(substr(rec,OfsProd+4,2))
            DataN = c2d(substr(rec,OfsProd+6,1))
            /* Ifcid 376 then get all the data */
            if ifcid =  ifcids then
            do
               /* Corr Header DSNDQWHC */
               OfsCor=OfsProd+LenStdHdr
               call DSNDQWHC  OfsCor
               /* Distributed header */
               if conntype = 'DRDA' then
               do
                  OfsNext=OfsCor+QWHCLEN
                  call DSNDQWHD OfsNext
               end
               else
               do
                  QWHDRQNM=''
                  QWHDSVNM=''
                  QWHDPRID=''
               end
               /* Process QW0376*/
               call Process366
            end
            /* Next Record */
            OfsRecREADA376=OfsRecREADA376+LenRec
        end /* End loop processing RtrArea */
 
        /* there is still bytes to process .. READA again */
        if BytesLeft376 > 0   then
             iterate
    end
    /* Close & Deallocate files */
    if numtimes > 1 then call Wait
    iterno = iterno+1
end /* end do numtimes */
"EXECIO "QUEUED()" DISKW OUFS(FINIS"
if rc > 0 then
   do
        say 'Error writing output file' rc
        exit(8)
   end
"FREE F(OUFS)"
 
/* End of program */
call StopTrace tno2
call StopTrace tno
 
/* Disconnect from DB2 */
ADDRESS DSNREXX "DISCONNECT"
 
say 'End of Program'
say '   Nbr records written : ' reco
say '   Nbr records read    : ' reci
say '   Nbr IFCID 317 reads failed : ' recf
exit 0
 
StopTrace:
 arg tno
 if datatype(tno) = 'NUM' & tno > 0 then do
    say 'Try to stop trace ...'
    CMD = '-STO TRACE(MON) TNO('tno')'
    COMMAND = substr('COMMAND',1,10)
    IFCA = '00B40000'X!!'IFCA'!!copies('00'X,172)
    RtrSz = 512
    RtrArea = d2c(RtrSz+4,4)left(' ',RtrSz,' ')
    DumZon = d2c(length(CMD)+4,2)!!'0000'X!!CMD
    Buff = '00000000'X!!'WBUF'!!'0000000000000000'X
    ADDRESS LINKPGM "DSNWLI2 COMMAND IFCA RtrArea DumZon Buff"
    RetC = c2d(substr(IFCA,13,4))
    Reas = d2x(c2d(substr(IFCA,17,4)))
    if RetC <> 0 & Reas <> 'E60820' then do
     say 'PROBLEM WITH STOP TRACE COMMAND'
     say 'COMMAND RETCODE = ' RetC
     say 'COMMAND REASON = ' Reas
    end
    else say 'Trace Stopped'
 end    /* if datatype(tno */
 else say '** Warning - MONITOR trace was started but not stopped **'
 return
/*--------------------------------------------------------------------*/
 
QW0366:
       arg offset_d
       offset_ifc=offset_d
       /*offset_d points to the IFCID 0366 data to process */
       /* Function code */
       QW0366FN =c2d(SUBSTR(rec,OFFSET_d,4))
       select
           when QW0366FN=1 then
               FnTxt='V9 CHAR(decimal-expr)'
           when QW0366FN=2 then
               FnTxt='V9 VARCHAR(decimal-expr)-CAST decimal as CHAR',
                     '/VARCHAR'
           when QW0366FN=3 then
               FnTxt='Unsupported char. string representation ',
                     'of a timestamp'
           when QW0366FN=7 then
               FnTxt='Unsupported Cast because DDF_COMPARTIBILITY ',
                     'zparm value'
           when QW0366FN=8 then
               FnTxt='DDF_COMPARTIBILITY=SP_PARMS_xJV and match ',
                     'output data is returned'
           when QW0366FN=9 then
               FnTxt='TIMEZONE ignored because of',
                     ' DDF_COMPARTIBILITY zparm value'
           when QW0366FN=10 then
               FnTxt='Pre v10 version of  ',
                     'LTRIM, RTRIM or STRIP has been executed'
           when QW0366FN=11 then
               FnTxt='SELECT INTO with UNION UNION ALL EXCEPT ALL ',
                     'INTERSECT INTERSECT ALL OPERATOR'
           when QW0366FN=1103 then
               FnTxt='ASUTIME IMPACT'
           when QW0366FN=1104 then
               FnTxt='CLIENT_ACCTNG SPECIAL REGISTER TOO LONG'
           when QW0366FN=1105 then
               FnTxt='CLIENT_APPLNAME SPECIAL REGISTER TOO LONG'
           when QW0366FN=1106 then
               FnTxt='CLIENT_USERID SPECIAL REGISTER TOO LONG'
           when QW0366FN=1107 then
               FnTxt='CLIENT_WRKSTNNAME SPECIAL REG. TOO LONG'
           when QW0366FN=1108 then
               FnTxt='CLIENT_* SPECIAL REGISTER TOO LONG'
           when QW0366FN=1109 then
               FnTxt='CAST string as Timestamp'
           when QW0366FN=1110 then
               FnTxt='Integer Arg in SPACE function > 32K'
           when QW0366FN=1111 then
               FnTxt='Integer Arg in VARCHAR function > 32K'
           when QW0366FN=1112 then
               FnTxt='Empty XML element serialized to <X></X>'
           otherwise
           do
               FnTxt =QW0366FN
           end
       end
       /*bypass this record */
       if pos('SPECIAL',FnTxt) > 0 then return
 
       offset_d = offset_d +4
       /* Statement number in the query */
       QW0366SN =c2d(SUBSTR(rec,OFFSET_d,4))
       offset_d = offset_d +4
       /* Planname */
       QW0366PL =SUBSTR(rec,OFFSET_d,8)
       offset_d = offset_d +8
       /* ConToken - not relevant with DISTSERV */
       if QW0366PL = 'DISTSERV' then
            QW0366TS = ''
       else
            QW0366TS =c2x(SUBSTR(rec,OFFSET_d,8))
       offset_d = offset_d +8
       /* Statement Id */
       QW0366SI =SUBSTR(rec,OFFSET_d+4,4)
       QW0366SId =c2d(QW0366SI)
       offset_d = offset_d +8
         /* statement identifier QW0350SI
         stmtid   =  c2x(SUBSTR(rec,OFFSET_d,8))
         say '366/stmtid=' stmtid */
       /* Statement type */
       QW0366TY =SUBSTR(rec,OFFSET_d,2)
       offset_d = offset_d +2
       select
           when qw0366ty='8000'x then sqltype='D'
           when qw0366ty='4000'x then sqltype='S'
           otherwise
           do
                say 'qw0366ty contents error unexpected value',
                          qw0366ty
                exit(8)
           end
       end
       /* Section Number */
       QW0366SE =c2d(SUBSTR(rec,OFFSET_d,2))
       offset_d = offset_d +2
       /* Offset to Collid */
       QW0366PC_Off =c2d(SUBSTR(rec,OFFSET_d,2))
       QW0366PC_Off = QW0366PC_Off + offset_ifc
       offset_d = offset_d +2
       /* Offset to Package */
       QW0366PN_Off =c2d(SUBSTR(rec,OFFSET_d,2))
       QW0366PN_Off = QW0366PN_Off + offset_ifc
       offset_d = offset_d +2
       /*Version Len */
       QW0366VL = c2d(SUBSTR(rec,OFFSET_d,2))
       offset_d = offset_d +2
       /*Version  */
       QW0366VN = SUBSTR(rec,OFFSET_d,qw0366VL)
       offset_d = offset_d +68
       /*Offset to Incompatible parms */
       QW0366INC_Off=c2d(SUBSTR(rec,OFFSET_d,2))
       QW0366INC_Off=QW0366INC_Off + offset_ifc
       offset_d = offset_d +2
       /*Offset to sql text */
       QW0366SQL_Off=c2d(SUBSTR(rec,OFFSET_d,2))
       QW0366SQL_Off=QW0366SQL_Off + offset_ifc
 
       /* Extract Collid  */
       QW0366PC_Len= c2d(SUBSTR(rec,QW0366PC_Off,2))
       offset_d = QW0366PC_Off + 2
       QW0366PC = SUBSTR(rec,OFFSET_d,QW0366PC_Len)
       /* Extract Package name */
       QW0366PN_Len= c2d(SUBSTR(rec,QW0366PN_Off,2))
       offset_d = QW0366PN_Off + 2
       QW0366PN = SUBSTR(rec,OFFSET_d,QW0366PN_Len)
       /* Extract Incomp. parms */
       QW0366INC_Len=c2d(SUBSTR(rec,QW0366INC_Off,2))
       offset_d =QW0366INC_Off + 2
       QW0366INC = SUBSTR(rec,OFFSET_d,QW0366INC_Len)
       SqlTrunc='N'
       if QW0366SId >  0 & sqltype  = 'D'        then
       do
         QW0366SQL=GetSqlText(QW0366SI)
         if QW0366SQL='NFD' then
         do
           /* Extract SQLText      */
           QW0366SQL_Len=c2d(SUBSTR(rec,QW0366SQL_Off,2))
           offset_d =QW0366SQL_Off + 2
           QW0366SQL = SUBSTR(rec,OFFSET_d,QW0366SQL_Len)
         end
       end
       else do
         /* Extract SQLText      */
         QW0366SQL_Len=c2d(SUBSTR(rec,QW0366SQL_Off,2))
         offset_d =QW0366SQL_Off + 2
         QW0366SQL = SUBSTR(rec,OFFSET_d,QW0366SQL_Len)
       end
       /* Remove extra space */
       QW0366SQL=space(QW0366SQL,1)
  return
 
GetSqlText: procedure expose SqlTrunc recf
  arg QW0366SI
  /* Execute qualified READS to get the SQL statement */
  READS = 'READS    '
  RtrSz = 32768
  RtrArea317 = d2c(RtrSz+4,4)left(' ',RtrSz,' ')
  IFCA = '00B40000'X!!'IFCA'!!copies('00'X,172)
  IFCIDAREA = '00060000013D'X  /*IFCID 317*/
  /* Qualify Area is described by DSNDWQAL */
  /* Length of Qual. Area must have some defined  */
  /* values. Cf. SDSNMACS*/
  /* Performance Guide  on READS */
  /* Otherwise Error - LEN choosen 192 WQALLN5 */
  QUAL     = '00C00000'X !! 'WQAL'  ,
      !! copies('00'x,158)  ,
      !! '04'x         , /*QWALFTR Activate filter */
      !! 'Z'           , /*QWALFFLD Not used */
      !! '00000000'x   , /*QWALFVAL Not used  4 bytes*/
      !! 'ZZZZZZZZZZZZZZZZ',/* QWALSTNM 16 bytes not used*/
      !! QW0366SI        /* qwalstid 4 bytes */
 
  ADDRESS LINKPGM "DSNWLI2 READS IFCA RtrArea317 IFCIDAREA QUAL"
  RetC = c2d(substr(IFCA,13,4))
  Reas = d2x(c2d(substr(IFCA,17,4)))
  BytesMoved317 = c2d(substr(IFCA,21,4)) /*IFCABM*/
  if RetC > 0 then do
       recf=recf+1
       return 'NFD'
  end
 
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
 
  /* QW0317ST    */
  offsData317 = offsData317 + 20
  /*QW0317LN*/
  QW0317LN=c2d(SUBSTR(rec317,offsData317,4))
  offsData317=offsData317+4
  /*QW0317TX SQL Text Truncate at 10000 bytes*/
  if QW0317LN > 10000 then do
                          QW0317LN = 10000
                          SqlTrunc='Y'
                     end
  QW0317TX = SUBSTR(rec317,offsData317,QW0317LN)
  return QW0317TX
 
 
Alloc_File:
   /* Report dataset  */
   Datex=substr(date(j),3,3)
   Timex=time()
   Timex=substr(timex,1,2)!!substr(timex,4,2)
   Datex='D'Datex!!Timex
   oufs = "'" !! hlq !! '.IFC376.' !! suf !!'.'Datex"'"
   /* Report dataset  */
   if first=1  then
   do
       "DELETE" oufS "PURGE"
       first=0
   end
 
   "ALLOC FI(OUFs) DA("oufs") MOD CATALOG REUSE" ,
   "LRECL(10300) RECFM(V B) TRACKS SPACE(900,900)"
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
  nbr_ifcid = 0
  reco= 0
  reci= 0
  recf= 0
  return
 
WriteHeader:
    say 'CSV file ' oufS     ' will be produced'
    queue "date;time;ssid;",
           "Fntype;StmNo;Plan;StmType;SectNo;Collid;Pack;",
           "Version;ConToken;IncParms;",
           "Requester;SrvName;ProdId;Userid;CorrId;ConnID;",
           "Conntype;Plan;OrigUser;EndUser;WrkStName;",
           "SqlTrunc;SqlTxt;"
 
    "EXECIO" queued() "DISKW OUFS(FINIS"
   if rc > 0 then
   do
        say 'Error writing output file' rc
        exit(8)
   end
  return
 
WriteReport:
    /* don't report Special Register anomalies */
    reco= reco+ 1
    /*rows in excel format */
    queue a !! ';' !! b !! ';' !! ssid      !! ';' ,
    !! '"' !! FnTxt !! '"' !! ';'   ,
    !! QW0366SN     !! ';'   , /* stm no*/
    !! QW0366PL     !! ';'   , /* Plan */
    !! sqltype      !! ';'   , /* sql type */
    !! QW0366SE     !! ';'   , /* Section No*/
    !! QW0366PC     !! ';'   , /* Collid */
    !! QW0366PN     !! ';'   , /* Pack */
    !! QW0366VN     !! ';'   , /* Version*/
    !! QW0366TS     !! ';'   , /* Contoken*/
    !! QW0366INC    !! ';'   , /* Incompat. Parms */
    !! strip(QWHDRQNM)     !! ';'   , /* requester location*/
    !! strip(QWHDSVNM)     !! ';'   , /* Server name */
    !! strip(QWHDPRID)     !! ';'   , /* Product ID */
    !! strip(QWHCAID)      !! ';'   , /* Userid*/
    !! strip(QWHCCV)       !! ';'   , /* Correlation Id */
    !! strip(QWHCCN)       !! ';'   , /* Connection Id */
    !! Conntype     !! ';'   , /* Connection type */
    !! strip(QWHCPLAN)     !! ';'   , /* Plan    */
    !! strip(QWHCOPID)     !! ';'   , /* Initial User ID */
    !! strip(QWHCEUID)     !! ';'   , /* End User ID */
    !! strip(QWHCEUWN)     !! ';'   , /* Workstation Name */
    !! SqlTrunc     !! ';' ,  /* SQL text truncated ? */
    !! '"' !! QW0366SQL !! '"' !! ';'     /* SQL text */
 
   "EXECIO "QUEUED()" DISKW OUFS(FINIS"
   if rc > 0 then
   do
        say 'Error writing output file' rc
        exit(8)
   end
return
 
IFIREADA:
   ADDRESS LINKPGM "DSNWLI2 READA IFCA RtrArea "
   RetC = c2d(substr(IFCA,13,4))
   Reas = d2x(c2d(substr(IFCA,17,4)))
   if RetC > 4 then do
        say 'Error READA ...'
        say '  READA RETCODE = ' RetC
        say '  READA REASON = ' Reas
        call StopTrace tno
        exit 8
   end
   reci=reci+1
   BytesMoved376 = c2d(substr(IFCA,21,4)) /*IFCABM*/
   BytesLeft376 = c2d(substr(IFCA,25,4))   /*IFCABNM*/
   if  BytesMoved376 > 0 then
     Say '**** READA ****' time()  BytesMoved376
   return
 
/* MAP distributed header */
DSNDQWHD:
    arg ofs
    ofs= ofs+2                     /* skip len  */
    /* check if type 16 = Distributed header */
    if c2d(substr(Rec,ofs,1)) <> 16 then
         do
            say 'Not a distributed header as expected'
            return
         end
    ofs= ofs+2
    /* requester location */
    QWHDRQNM = SUBSTR(Rec,ofs,16)
    ofs= ofs + 24
    /* Server Name  */
    QWHDSVNM = SUBSTR(Rec,ofs,16)
    ofs= ofs + 16
    /* Product ID   */
    QWHDPRID = SUBSTR(Rec,ofs,8)
  return
 
/* correlation header */
DSNDQWHC:
  arg ofs
  QWHCLEN = C2D(SUBSTR(Rec,ofs,2))
  ofs = ofs + 2
  QWHCTYP = C2D(SUBSTR(Rec,ofs,1))
  ofs = ofs + 2
  /* authid */
  QWHCAID      = SUBSTR(Rec,ofs,8)
  ofs = ofs + 8
  QWHCCV  = SUBSTR(Rec,ofs,12)
  ofs = ofs + 12
  /* QWHCCN DS CL8 CONNECTION NAME */
  QWHCCN = SUBSTR(Rec,ofs,8)
  ofs = ofs + 8
  /* QWHCPLAN DS CL8 PLAN NAME */
  QWHCPLAN = SUBSTR(Rec,ofs,8)
  ofs = ofs + 8
  /* QWHCOPID  initial  authid */
  QWHCOPID  = SUBSTR(Rec,ofs,8)
  ofs = ofs + 8
  /* QWHCATYP  Type de connection*/
  QWHCATYP  = C2D(SUBSTR(Rec,ofs,4))
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
 
 
  ofs = ofs + 28
  if conntype =  'DRDA' then
  do
    /* QWHCEUID  end userid */
    QWHCEUID  = SUBSTR(Rec,ofs,16)
    ofs = ofs + 48
    /* QWHCEUWN  user workstation name */
    QWHCEUWN  = SUBSTR(Rec,ofs,18)
  end
  else do
    QWHCEUID  = ''
    QWHCEUWN  = ''
  end
  RETURN 0
 
Wait:
      call syscalls 'ON'
      address syscall 'sleep ' sleeptime
      call syscalls 'OFF'
      if iterno//15 == 0 then
      do
          say 'number of records written' reco
      end
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
 
StartTrace: Procedure expose IFCAOPN
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
  if pos('318',cmd) > 0 & msgno = 'DSNW135I' then return(99)
  if msgno <> 'DSNW130I' then
       do
           say MSG
           return(-1)
       end
  /* Get the OPn buffer for READA */
  IFCAOPN = substr(IFCA,37,4)    /*IFCAOPN*/
  say  'Trace started TNO' tno '>'IFCAOPN'<'
  return(tno)
 
Process366:
    /* process each data section*/
    i = 1
    do while i <  datan
        j=5+8*i /* ptr to next self def data section */
        offset_data= c2d(substr(rec,j,4))+1
        len_data= c2d(substr(rec,j+4,2))
        rep_data= c2d(substr(rec,j+6,2))
        i=i+1
        if len_data = 0  then iterate
        /* len can be zero , read sdsnmacs DSNDQWT0 */
        /* (it is called "varying length repeating group")  */
     /* if len_data = 0 & rep_data=0 then iterate
        IFCID 376/366 here - Not varying length*/
        call QW0366 offset_data
        if pos('SPECIAL',FnTxt) = 0 then
            call WriteReport
    end
return

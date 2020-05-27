/* REXX ***************************************************************/
/* IFCID 053 Report Error SQLCODE                                     */
/*                                                                    */
/*                                                                    */
/* <ssid>       DB2 subsystem name                                    */
/* <numtimes>   Number of iteration                                   */
/* <sleeptime>  Time in seconds between an iteration                  */
/*                                                                    */
/* IFCID 53 is like IFCID 58 except that it doesn't need a paired     */
/* 'Start SQL event' IFCID. It can be started alone                   */
/* IFCID 53 reports SQLCode even when the SQL could not be executed   */
/*  (-805, -501 ..)                                                   */
/* IFCID 53 reports SQLCode even when the SQL could not be executed   */
/* IFCID 58 is reported only if started with the corresponding pair   */
/*       IFCID 59-66 is started (Read DSNWMSGS for more information)  */
/**********************************************************************/
arg  ssid numtimes sleeptime  modex
numeric digits 25
first=1
 
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
/* Start Trace IFCID 058  (If not 59-66 then no 58 generated */
/* Start Trace IFCID 053  unpaired event check SDSNIVPD for comments */
CMD = '-STA TRA(P) c(30) IFCID(53) D(OPX) BUFSIZE(10240)'
/*
CMD = '-STA TRA(MON) C(1) D(OPX) BUFSIZE(10240)'
CMD = CMD 'IFCID(003,020,022,023,024,025,029,030,031,' !!,
          '044,045,051,052,053,055,058,059,060,'!!,
          '061,062,064,065,066,068,069,070,071,'!!,
          '072,073,074,084,085,088,089,095,096,'!!,
          '108,109,110,111,112,125,140,159,167,'!!,
          '168,169,170,171,172,173,177,190,196,'!!,
          '213,214,215,216,218,224,226,227,231,'!!,
          '237,239,247,269,270,272,273,305,311,'!!,
          '324,325,343,350,351,352,359,360,363,'!!,
          '378,379,380,381,497,498,499)' */
tno=StartTrace(CMD)
if tno < 0 then do
        exit(8)
    end
/* Init zones for READA */
READA = substr('READA',1,8)
IFCA = SUBSTR('00'X,1,180,'00'X)
IFCA = OVERLAY(D2C(LENGTH(IFCA),2),IFCA,1+0)
IFCA = OVERLAY("IFCA",IFCA,4+1)
IFCA = OVERLAY(IfcaOpn,IFCA,36+1)
IFCA = OVERLAY('0004'X,IFCA,40+1)
RtrSz = 10240000
RtrArea = d2c(RtrSz+4,4)left(' ',RtrSz,' ')
 
 
iterno = 1
a=date()
/* Loop of  READA command using IFI interface */
do numtimes
    b=time()
    /* WRITE report header */
    READCount=0
    Do until READcount > 50
        READCount=READCount+1
        call IFIREADA
        if BytesMoved    = 0 then leave
        /* Decode first time Ret Area */
        OfsRecREADA=5
        /* Read  repeated data from IFI RetArea */
        Do while OfsRecREADA < BytesMoved
            /* first byte = x'80' */
            if  c2d(substr(RtrArea,OfsRecREADA,1)) = 128
               then  LenRec = c2d(substr(RtrArea,OfsRecREADA+1,3))
               else  LenRec = c2d(substr(RtrArea,OfsRecREADA,2))
            Rec  = substr(RtrArea,OfsRecREADA,LenRec)
            /* Standard Header */
            OfsProd = c2d(substr(rec,5,4))+1
            LenStdHdr= c2d(substr(rec,OfsProd,2))
            Ifcid = c2d(substr(rec,OfsProd+4,2))
            DataN = c2d(substr(rec,OfsProd+6,1))
            /* Ifcid 053 same macro as IFCID 058*/
            if ifcid =  58 ! ifcid =  53 then
            do
               /* Corr Header DSNDQWHC */
               OfsCor=OfsProd+LenStdHdr
               call DSNDQWHC  OfsCor
               call ProcessIfcid
            end
            /* Next Record */
            OfsRecREADA=OfsRecREADA+LenRec
        end /* End loop processing RtrArea */
 
        /* there is still bytes to process .. READA again */
        if BytesLeft > 0      then
             iterate
    end
    /* Close & Deallocate files */
    if numtimes > 1 & sleeptime > 0 then call Wait
    iterno = iterno+1
end /* end do numtimes */
 
/* End of program */
call StopTrace tno
 
/* Disconnect from DB2 */
ADDRESS DSNREXX "DISCONNECT"
 
say 'End of Program'
say '   Nbr records written : ' reco
say '   Nbr records read    : ' reci
say '   Nbr IFCID 053 reads failed : ' recf
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
init_var:
  /* compteurs input/DumZon */
  nbr_ifcid = 0
  reco= 0
  reci= 0
  recf= 0
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
   BytesMoved    = c2d(substr(IFCA,21,4)) /*IFCABM*/
   BytesLeft = c2d(substr(IFCA,25,4))      /*IFCABNM*/
   /* No display because there can be a lot of line
   Say '**** READA ****' time()  'Bytes Read' BytesMoved    */
   return
 
/* MAP distributed header */
DSNDQWHD:
    /* Optimize no need to get these fields, yet */
    return
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
  ofs = ofs + 4
  /* authid */
  QWHCAID = strip(SUBSTR(Rec,ofs,8))
  ofs = ofs + 8
  /* Correlation Id */
  QWHCCV  = strip(SUBSTR(Rec,ofs,12))
  ofs = ofs + 12
  /* QWHCCN DS CL8 CONNECTION NAME */
  QWHCCN = strip(SUBSTR(Rec,ofs,8))
  ofs = ofs + 8
  /* QWHCPLAN DS CL8 PLAN NAME */
  QWHCPLAN = strip(SUBSTR(Rec,ofs,8))
  ofs = ofs + 16
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
  /* Optimize - no need for these fields */
  return 0
 
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
 
ProcessIfcid:
    /* process each data section*/
    /* for IFCID 053 only first data - check with new release */
    /* Optimize : all values already computed check others programs*/
    /* for the method used */
        offset_data= c2d(substr(rec,13,4))+1
    /*  len_data= c2d(substr(rec,17,2))
        rep_data= c2d(substr(rec,23,2))
        if len_data = 0  then iterate */
        /* len can be zero , read sdsnmacs DSNDQWT0 */
        /* (it is called "varying length repeating group")  */
     /* if len_data = 0 & rep_data=0 then iterate */
        call QW0053 offset_data
return
/*--------------------------------------------------------------------*/
 
QW0053:
       arg offsetd
       /* offset to sqlcode from qw0053 macro is 74 */
       /* Check with new release ... */
       sqlcode  =x2d(c2x(SUBSTR(Rec,offsetd+74,4)),8)
       /* ignore "normal" sqlcode */
       if modex = 'NEG' &,
          sqlcode >= 0 ! sqlcode = -811 ! sqlcode = -803
          then return
       reco=reco+1
       say ' '
       say '--------------------------------'
       Say 'Authid:'QWHCAID'/Plan:'QWHCPLAN'/Conntype:'!!,
            Conntype'/Corrid:'QWHCCV
       /* Collid   */
       offsetd = offsetd +16
       QW0053PC =strip(SUBSTR(Rec,offsetd,18))
       offsetd = offsetd +18
       /* Package name */
       QW0053PN =strip(SUBSTR(Rec,offsetd,18))
       say  'Collid:'QW0053PC'/Pack:'QW0053pn
 
       offsetd = offsetd +28
       /* Consitency token (Contoken in sysibm.syspackstmt) */
       /* PRECOMPILER TIME STAMP */
       /* SQLCA */
       QW0053SQ =    SUBSTR(Rec,offsetd,136)
       offsetd= offsetd +136
       say '053/SQLCA 1-50           >'!! substr(QW0053sq,1,50)!!'<'
       say '053/SQLCA 51-100         >'!! substr(QW0053sq,51,50)!!'<'
       say '053/SQLCA 101-136        >'!! substr(QW0053sq,101,36)!!'<'
       say '053/SQLCA 101-136        >'!! substr(QW0053sq,101,36)!!'<'
 
       /* jump to SQLCODE from sqlca */
       /************** BEGIN SQLCA PROCESSING ****************/
       offsetx = offsetd +12
       /* sqlcode is in sqlca -look dsntiac for sqlca description*/
       nsqlcode  =x2d(c2x(SUBSTR(Rec,offsetx,4)),3)
         /* interpreter sqlcode
            sqlcodehex=FFFFFCDB
            haha=x2d(sqlcodehex,3) */
         /* On sait que sqlcode sera au max sur 3 positions */
 
       offsetx= offsetx +84
       sqlerrd1  =c2x(SUBSTR(Rec,offsetx,4))
       offsetx= offsetx + 4
       sqlerrd2  =c2x(SUBSTR(Rec,offsetx,4))
       offsetx= offsetx + 4
       sqlerrd3  =c2x(SUBSTR(Rec,offsetx,4))
       offsetx= offsetx + 4
       sqlerrd4  =c2x(SUBSTR(Rec,offsetx,4))
       offsetx= offsetx + 4
       sqlerrd5  =c2x(SUBSTR(Rec,offsetx,4))
       offsetx= offsetx + 4
       sqlerrd6  =c2x(SUBSTR(Rec,offsetx,4))
       offsetx= offsetx + 4
       say 'nsqlcode' nsqlcode
       say sqlerrd1'/'sqlerrd2'/'sqlerrd3'/'sqlerrd4'/'sqlerrd5'/',
           sqlerrd6
       /**************** END SQLCA PROCESSING ****************/
       offsetd= offsetd + 2
       /* Statement number  */
       QW0053SN = c2d(SUBSTR(Rec,offsetd,4))
       say 'offsetd' offsetd
       say substr(rec,offsetd,50)
       offsetd= offsetd +26
       /* SQL Type */
       /* Not meaningful when Sql not executed (-805, -501) */
       QW0053TOS= c2x(SUBSTR(Rec,offsetd,1))
       select
           when QW0053TOS = '01'  then sqltype='FETCH'
           when QW0053TOS = '10'  then sqltype='INSERT'
           when QW0053TOS = '11'  then sqltype='SELECT INTO'
           when QW0053TOS = '20'  then sqltype='UPDATE NO CURSOR'
           when QW0053TOS = '21'  then sqltype='UPDATE CURSOR'
           when QW0053TOS = '30'  then sqltype='MERGE'
           when QW0053TOS = '40'  then sqltype='DELETE NO CURSOR'
           when QW0053TOS = '41'  then sqltype='DELETE CURSOR'
           when QW0053TOS = '50'  then sqltype='TRUNCATE'
           when QW0053TOS = '80'  then sqltype='PREPARE NO CURSOR'
           when QW0053TOS = '81'  then sqltype='PREPARE CURSOR'
           when QW0053TOS = '91'  then sqltype='OPEN'
           when QW0053TOS = 'A1'  then sqltype='CLOSE'
           otherwise do
               say ifcid!!'/SQL Type QW0053TOS not known>'QW0053TOS'<'
               sqltype='UNKNOWN'
             end
       end /* end select */
       offsetd= offsetd +1
       say  'Sqlcode:'sqlcode,
           'Statement number:'QW0053sn'/Type:'sqltype
    /* say  'Rec display below'
       say  SUBSTR(Rec,1,99 )
       say  SUBSTR(Rec,100,099)
       say  SUBSTR(Rec,200,099)
       say  SUBSTR(Rec,300,099)
       say  SUBSTR(Rec,400,099)
       say  SUBSTR(Rec,500,099)
       say  SUBSTR(Rec,600,099)
       say  SUBSTR(Rec,700,099) */
 
  return

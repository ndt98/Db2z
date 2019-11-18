/* REXX */
/* Scan les infos DB2 sur toutes les LPAR */
/* cinematique :       */
/*  etape 1 - d iplinfo */
/*  etape 2 - d opdata --> liste des DB2 défini  */
/*                          --> test si actif */
/*                               --> OPTDATA */
/*                                 --> DIS DDF */
/*                                 --> lecture MSTR,DBM1,IRLM */
/*                               --> lecture DSNJU004 */
/*                               --> DIS GROUP */
/*                               --> interro sql*/
/*                               --> info dasd */
ARG OPT
hlq= 'SYSTMP.DBDC.DB2'
/* Init zones */
oresx='' /* Old resource */
SendAlarm=0
DateMinArch='Unknow'
zAlertMsg = '' /*MSGID de l'alerte */
zAlertType = '' /* Type Alerte */
info_dasd=1    /* mettre a 1 ou 0 - 0 si probleme */
rxsms    =1    /* appel rxsms (plus rapide) ou ancienne mode */
HIGHQUAL="SYSPRM.DBDC.DB2.DB2INST"
PRINQUAL="SYSTMP.DBDC.DB2.DB2INST"
LPNUL="SYSA SYSB SYSK SYSQ SYSR PFH1 PPR3 PPR4 PPR2 HLI2 " !!,
      "CSYS IPO1 IPO2 IPOA ZSY2 GS90 SDEV REF1 HLI1 HSNE"
LPLCL="LIM LIM2 LIM3 LIM4 LIM5 RLN SNE TEC "!!,
      "CTR DEV SYSA SYSB SYSK SYSQ SYSR PFH1 "!!,
      "PPR3 PPR4 PPR2 HLI2 REF1 HLI1 HSNE"
LPCAP="CSYS CERT I083 IMIN INT2 AMC2 CAPB TIPS SDEV" /* LPAR CAPS */
LPCAS="ZPR1 ZDV1 ZSY1 ZSY2"       /* LPAR CASA       */
LPCAL="IPO1 IPO2 IPO3 IPO4 IPOA"      /* LPAR CACIB      */
LPCAR="OSET OSLA OSJB OSGA OSFA MVSA MVST"
LPSOF="DD20 DJ02 XK01 XX10 GS90"
LPCAG="SUD1 SUD2 SUD3 PROD PACI SUDB SUDM SUDF ZTEC"!!,
      "SYST"
DATEJ=DATE()     /* Date du jour format Europeen */
UPPER DATEJ      /* ex : 12 NOV 2017 1 DEC 2017 */
LPAR=MVSVAR(SYSNAME)
LPDEV="DEV SYSA SYSB SYSK SYSQ SYSR PFH1 "!!,
      "PPR3 PPR4 PPR2 "!!,
      "ZDV1 ZSY1 ZSY2 "!!,
      "IPO1 IPOA IPO2 "!!,
      "DJ02 "!!,
      "OSET MVST OSJB "!!,
      "DD20 GS90 "!!,
      "SYST ZTEC SUD2 SUD3"
/* LPAR = dev ou prod ? */
LPARprod=0
if wordpos(LPAR,lpnul) > 0 then LPARtest=1
       else  LPARtest=0
if LPAR='SYSB' & MVSVAR(SYMDEF,'LPARNAME')='LPAR41E' /* CAPS*/
then do
       LPAR='CAPB'
       LPARProd=1
     end
else if wordpos(LPAR,lpdev) = 0 & lpartest=0              then
       LPARProd=1
PDSOUT=PRINQUAL"."LPAR
EXTRACT=PDSOUT"(EXTRACT)"
LOGSCAN=PDSOUT"(LOGSCAN)"
VOLCATR=PDSOUT"(VLKT"
LOGACTR=PDSOUT"(LOGA"
LOGACTV=PDSOUT"(LOGV"
STGCATR=PDSOUT"(STKT"
ENVCATR=PDSOUT"(ENVE"
SQLCATR=PDSOUT"(SQLC"
RBA1   =PDSOUT"(RBA1"
RBA2   =PDSOUT"(RBA2"
CONSNAME="MONJOB"SUBSTR(MVSVAR('SYMDEF',CLIENT),2,1)!!,
         MVSVAR('SYMDEF',LSYST)
/* ZONE DES VARIABLES */
NUMERIC DIGITS 16
CPTEXT=0
CPTLOG=0
CPTENV=0
CPTSQL=0
DATIPL=""
LISTDB2=""
TAB.LST=""
CPTLOG=CPTLOG+1;LOG.CPTLOG="SCAN DE LA LPAR "LPAR
SAY TIME()" "LOG.CPTLOG
/* */
X=OUTTRAP(TMP.)
ADDRESS TSO "DELETE '"PDSOUT"'"
X=OUTTRAP(OFF)
ADDRESS TSO "ALLOC DD(SINN) DS('"PDSOUT"') NEW "!!,
  "DSORG(PO) RECFM(F B) LRECL(80) BLKSIZE(0) "!!,
  "SPACE(30 30) DIR(30) DSNTYPE(PDS)"
CPTLOG=CPTLOG+1
LOG.CPTLOG="CREATE DU PDS DE SORTIE : "PDSOUT
SAY TIME()" "LOG.CPTLOG
ADDRESS TSO "FREE DDNAME(SINN)"
/* Init membre EXTRACT pour marquer le traitement du SSID par DB2ETAT*/
/* Si DB2ETAT trouve un fichier EXTRACT pas bon il va le signaler */
SQLC.0=1
SQLC.1='DUMMY LINE'
ADDRESS TSO "ALLOC DD(FILE) DS('"EXTRACT"') SHR"
ADDRESS TSO "EXECIO * DISKW FILE (STEM SQLC. FINIS "
ADDRESS TSO "FREE DDNAME(FILE)"
DROP SQLC.
/***********************************************************/
/* Debut traitement de recuperation des infos pour DB2ETAT */
/***********************************************************/
/* Display iplinfo */
CALL DIFO
/* Get active DB2 subsys */
Call GetActDB2
DO I=1 TO WORDS(TAB.LST)
 SSID=WORD(TAB.LST,I)
 /* Je ne reporte que les DB2 ACTIF */
 /* pour que DB2ETAT scanne moins le membre EXTRACT*/
 IF (LPAR=TAB.SSID.4  & TAB.SSID.5 = "ON") THEN DO
  CPTEXT=CPTEXT+1;
  EXT.CPTEXT="***** DB2 "TAB.SSID.27" ***** "TAB.SSID.5
  CPTEXT=CPTEXT+1;EXT.CPTEXT="CLIENT            = "TAB.SSID.6
  CPTEXT=CPTEXT+1;EXT.CPTEXT="LPAR              = "TAB.SSID.4
  LP=TAB.SSID.4
  CPTEXT=CPTEXT+1;EXT.CPTEXT="SSID              = "TAB.SSID.1
  SSID=TAB.SSID.1
  CPTEXT=CPTEXT+1;EXT.CPTEXT="NOM               = "TAB.SSID.27
  NDB2=TAB.SSID.27
  CPTEXT=CPTEXT+1;EXT.CPTEXT="COMMAND PREFIX    = "TAB.SSID.3
  PF=TAB.SSID.3
  CPTEXT=CPTEXT+1;EXT.CPTEXT="ETAT              = "TAB.SSID.5
  ET=TAB.SSID.5
  CPTEXT=CPTEXT+1;EXT.CPTEXT="DATE START        = "TAB.SSID.25
  DATST=TAB.SSID.25
  CPTEXT=CPTEXT+1;EXT.CPTEXT="IPLED             = "DATIPL
  CPTEXT=CPTEXT+1;EXT.CPTEXT="DATE D'EXTRACTION = "TAB.SSID.2
  DT=TAB.SSID.2
  CPTEXT=CPTEXT+1;EXT.CPTEXT="TICTOC            = "TAB.SSID.16
  CPTEXT=CPTEXT+1;EXT.CPTEXT="BSDS01            = "TAB.SSID.17
  BSDS1=WORD(TAB.SSID.17,1)
  CPTEXT=CPTEXT+1;EXT.CPTEXT="BSDS02            = "TAB.SSID.18
  BSDS2=WORD(TAB.SSID.18,1)
  IF BSDS1<>"" THEN DO
   CALL JU004
   TAB.SSID.30=DataSharingMode
   TAB.SSID.33=CATNAME
   /* decode log active => info occupation du storage group */
   DsnActLog =WORD(LSTACTLG,1) /* on recupere un active log */
                           /* pour prendre juste le prefixe */
   call process_sms2
   IF DataSharingMode="ON" THEN DO
    SAY NDB2" EST UN MEMBRE D'UN DATASHARING. RECHERCHE DES INFOS."
    DTSHRPR=0
    CALL DISGROUP NDB2
    TAB.SSID.7=DTSHRGA
    TAB.SSID.31=DTSHRLT
    TAB.SSID.32=DTSHRGP
   END
   ELSE DO
    CALL DISGROUP NDB2
    DTSHRPR=1
   END
   LIBEXIT="EXPL.DB2."
   IF TAB.SSID.7="" THEN LIBEXIT=LIBEXIT!!NDB2!!".SDSNEXIT"
   ELSE LIBEXIT=LIBEXIT!!TAB.SSID.7!!".SDSNEXIT"
   RACF='N/A';CALL racfopt /* racf DB2 or not ? */
   /* pas data sharing member */
   IF DTSHRPR=1 & info_dasd=1 THEN DO
         CALL DOSQL
         say 'process_sms deb'
         call process_sms
         say 'process_sms fin'
   END
  END /* IF BSDS1<>"" THEN DO*/
  CPTEXT=CPTEXT+1;EXT.CPTEXT="UNIT              = "TAB.SSID.29
  CPTEXT=CPTEXT+1;EXT.CPTEXT="NBAR30J           = "TAB.SSID.35
  CPTEXT=CPTEXT+1;EXT.CPTEXT="CYMINAR           = "TAB.SSID.36
  CPTEXT=CPTEXT+1;EXT.CPTEXT="CYMAXAR           = "TAB.SSID.37
  CPTEXT=CPTEXT+1;EXT.CPTEXT="1EREARC           = "TAB.SSID.38
  CPTEXT=CPTEXT+1;EXT.CPTEXT="MAX ARC. DURATION = "TAB.SSID.26
  CPTEXT=CPTEXT+1;EXT.CPTEXT="HRBAWRIT          = "TAB.SSID.48
  CPTEXT=CPTEXT+1;EXT.CPTEXT="PERIOD ARCH MIN.  = "TAB.SSID.47
  IF NbActLog=WORDS(LSTACTLG) THEN DO
     /* LOGGING SYMPLEX */
     SIZLOG=TOZACTLG
  END
  ELSE DO
     /* DUAL */
     IF TOZACTLG="TOZACTLG" THEN TOZACTLG=0
     SIZLOG=TOZACTLG/2
  END
  CPTEXT=CPTEXT+1;EXT.CPTEXT="NBACTLG           = "NbActLog" "SIZLOG
  CPTEXT=CPTEXT+1;EXT.CPTEXT="RACF              = "RACF
  CPTEXT=CPTEXT+1;EXT.CPTEXT="SDSNEXIT          = "TAB.SSID.19
  DEXIT=TAB.SSID.19
  CPTEXT=CPTEXT+1;EXT.CPTEXT="DSNZPARM          = "TAB.SSID.21
  ZPARM=TAB.SSID.21
  CPTEXT=CPTEXT+1;EXT.CPTEXT="VCATNAME          = "TAB.SSID.33
  CATNAME=TAB.SSID.33
  CPTEXT=CPTEXT+1;EXT.CPTEXT="PROCLIB           = "TAB.SSID.20
  PROCL=TAB.SSID.20
  CPTEXT=CPTEXT+1;EXT.CPTEXT="USER STC DB2      = "TAB.SSID.22
  USDB2=TAB.SSID.22
  CPTEXT=CPTEXT+1;EXT.CPTEXT="GROUP STC DB2     = "TAB.SSID.23
  GPDB2=TAB.SSID.23
  CPTEXT=CPTEXT+1;EXT.CPTEXT="MODE DB2          = "TAB.SSID.24
  MODE8=TAB.SSID.24
  CPTEXT=CPTEXT+1;EXT.CPTEXT="GROUPE ATTACH     = "TAB.SSID.7
  GA=TAB.SSID.7
  CPTEXT=CPTEXT+1;EXT.CPTEXT="DATASHARING MODE  = "TAB.SSID.30
  DSHMD=TAB.SSID.30
  CPTEXT=CPTEXT+1;EXT.CPTEXT="DATASHARING LIST  = "TAB.SSID.31
  DSHLT=TAB.SSID.31
  CPTEXT=CPTEXT+1;EXT.CPTEXT="DATASHARING GROUP = "TAB.SSID.32
  DSHLT=TAB.SSID.32
  CPTEXT=CPTEXT+1;EXT.CPTEXT="LOCATION NAME     = "TAB.SSID.8
  DFLO=TAB.SSID.8
  CPTEXT=CPTEXT+1;EXT.CPTEXT="LUNAME            = "TAB.SSID.9
  CPTEXT=CPTEXT+1;EXT.CPTEXT="GENERIC LU        = "TAB.SSID.10
  CPTEXT=CPTEXT+1;EXT.CPTEXT="ADRESSE IP        = "TAB.SSID.11
  CPTEXT=CPTEXT+1;EXT.CPTEXT="TCPIP PORT        = "TAB.SSID.12
  CPTEXT=CPTEXT+1;EXT.CPTEXT="RESPONSE PORT     = "TAB.SSID.13
  CPTEXT=CPTEXT+1;EXT.CPTEXT="ETAT DU DDF       = "TAB.SSID.14
  CPTEXT=CPTEXT+1;EXT.CPTEXT="DOMAIN            = "TAB.SSID.15
  CPTEXT=CPTEXT+1;EXT.CPTEXT="DEADLOK           = "TAB.SSID.28
  if TAB.SSID.39<>" " then do  /*NOMBRE DE LOG MAXIMUM SUR 10M*/
    CPTEXT=CPTEXT+1;EXT.CPTEXT=TAB.SSID.39
    CPTEXT=CPTEXT+1;EXT.CPTEXT=TAB.SSID.40
    CPTEXT=CPTEXT+1;EXT.CPTEXT=TAB.SSID.41
    CPTEXT=CPTEXT+1;EXT.CPTEXT=TAB.SSID.42
    CPTEXT=CPTEXT+1;EXT.CPTEXT=TAB.SSID.43
    CPTEXT=CPTEXT+1;EXT.CPTEXT=TAB.SSID.44
    CPTEXT=CPTEXT+1;EXT.CPTEXT=TAB.SSID.45
    CPTEXT=CPTEXT+1;EXT.CPTEXT=TAB.SSID.46
  END
  CPTEXT=CPTEXT+1;EXT.CPTEXT="***** DB2 END ******"
 END
END
CPTLOG=CPTLOG+1
LOG.CPTLOG=""
ADDRESS TSO "ALLOC DD(FILE) DS('"LOGSCAN"') SHR"
ADDRESS TSO "EXECIO * DISKW FILE (STEM LOG. FINIS "
ADDRESS TSO "FREE DDNAME(FILE)"
DROP LOG.
CPTEXT=CPTEXT+1
IF CPTEXT=1 THEN DO
  EXT.CPTEXT="*"
  CPTEXT=CPTEXT+1
END
EXT.CPTEXT=""
ADDRESS TSO "ALLOC DD(FILE) DS('"EXTRACT"') SHR"
ADDRESS TSO "EXECIO * DISKW FILE (STEM EXT. FINIS "
ADDRESS TSO "FREE DDNAME(FILE)"
DROP EXT.
/***********************************/
/* fin de programme End of program */
/***********************************/
EXIT
/**************************************************************/
/* EXTRACTION DE LA COMMANDE "D IPLINFO" */
/*  SORTIE : DATIPL CONTIENT LA DATE D'IPL */
/**************************************************************/
DIFO:
 say 'Display IPLINFO'
 DIFO_CMD="D IPLINFO"
 X=OUTTRAP(TMP.)
 ADDRESS TSO "CONSPROF SOLDISPLAY(NO)"
 X=OUTTRAP(OFF)
 DIFO_CDE=RC
 IF DIFO_CDE=0 THEN DO
  ADDRESS TSO "CONSOLE  SYSCMD("DIFO_CMD") NAME("CONSNAME") CART('CLNK')"
  MSG = GETMSG('DIFO_CMSG.','SOL','CLNK',,5)
  ADDRESS TSO "CONSOLE DEACTIVATE"
  IF DIFO_CMSG.0>0 THEN DO
   DO I=1 TO DIFO_CMSG.0
    IF WORD(DIFO_CMSG.I,1)="SYSTEM" &,
       WORD(DIFO_CMSG.I,2)="IPLED" THEN DO
     DATIPL=WORD(DIFO_CMSG.I,6)" "WORD(DIFO_CMSG.I,4)
    END
   END
  END
 END
RETURN
/***************************************************************/
/* EXTRACTION DE LA COMMANDE "D OPDATA" */
/***************************************************************/
GetActDB2:
 LstDB2='' /* List active DB2 on the LPAR */
 call Erly /* Get active DB2 subsys */
 say LstDB2
 DO I=1 TO words(LstDB2)
      CurrDB2=word(LstDB2,i)
      /* traitement specifique - en mode test seulement
      if LPAR = 'SUD2' & CurrDB2 <> 'DB2G' then iterate */
      say '**** processing ' CurrDB2 i
      /* CAPS saut de SDEV/DB2R car plantage ??- tempo */
      EXCLUS = ''
      if wordpos(CurrDB2,EXCLUS) > 0 & ,
                       LPAR = 'SDEV' then
           do
               say '  ==> skip' CurrDB2
               iterate
           end
      call disgroup CurrDB2
      ActDb2Lp=CurrDB2!!LPAR
      IF POS(ActDb2Lp,TAB.LST)=0 THEN,
       TAB.LST=TAB.LST" "ActDb2Lp
      TAB.ActDb2Lp.1=ActDb2Lp
      TAB.ActDb2Lp.27=CurrDB2
      TAB.ActDb2Lp.2=DATE('E')"."TIME()
      TAB.ActDb2Lp.3=CmdPref
      TAB.ActDb2Lp.4=LPAR
      SELECT
         WHEN POS(LPAR,LPLCL)<>0 THEN TAB.ActDb2Lp.6="LCL"
         WHEN POS(LPAR,LPCAS)<>0 THEN TAB.ActDb2Lp.6="CASA"
         WHEN POS(LPAR,LPCAL)<>0 THEN TAB.ActDb2Lp.6="CACIB"
         WHEN POS(LPAR,LPFIN)<>0 THEN TAB.ActDb2Lp.6="FINAREF"
         WHEN POS(LPAR,LPCAR)<>0 THEN TAB.ActDb2Lp.6="CRP"
         WHEN POS(LPAR,LPSOF)<>0 THEN TAB.ActDb2Lp.6="SOFINCO"
         WHEN POS(LPAR,LPCAG)<>0 THEN TAB.ActDb2Lp.6="CAAGIS"
         WHEN POS(LPAR,LPCAP)<>0 THEN TAB.ActDb2Lp.6="CAPS"
         OTHERWISE TAB.ActDb2Lp.6="INCONNU"
      END
      client=TAB.ActDb2Lp.6
      TAB.ActDb2Lp.7=" "
      TAB.ActDb2Lp.8=" "
      TAB.ActDb2Lp.9=" "
      TAB.ActDb2Lp.10=" "
      TAB.ActDb2Lp.11=" "
      TAB.ActDb2Lp.12=" "
      TAB.ActDb2Lp.13=" "
      TAB.ActDb2Lp.14=" "
      TAB.ActDb2Lp.15=" "
      TAB.ActDb2Lp.16=" "
      TAB.ActDb2Lp.17=" "
      TAB.ActDb2Lp.18=" "
      TAB.ActDb2Lp.19=" "
      TAB.ActDb2Lp.20=" "
      TAB.ActDb2Lp.21=" "
      TAB.ActDb2Lp.22=" "
      TAB.ActDb2Lp.23=" "
      TAB.ActDb2Lp.24=" "
      TAB.ActDb2Lp.25=" "
      TAB.ActDb2Lp.26=" "
      TAB.ActDb2Lp.28=" "
      TAB.ActDb2Lp.29=" "
      TAB.ActDb2Lp.30=" "
      TAB.ActDb2Lp.31=" "
      TAB.ActDb2Lp.32=" "
      TAB.ActDb2Lp.33=" "
      TAB.ActDb2Lp.34=" "
      TAB.ActDb2Lp.35=" "
      TAB.ActDb2Lp.36=" "
      TAB.ActDb2Lp.37=" "
      TAB.ActDb2Lp.38=" "
      TAB.ActDb2Lp.39=" "
      TAB.ActDb2Lp.40=" "
      TAB.ActDb2Lp.41=" "
      TAB.ActDb2Lp.42=" "
      TAB.ActDb2Lp.43=" "
      TAB.ActDb2Lp.44=" "
      TAB.ActDb2Lp.45=" "
      TAB.ActDb2Lp.46=" "
      TAB.ActDb2Lp.48=" "
      /* get System info via D DDF & MSTR DBM1 IRLM*/
      CALL GDB2INFO CurrDB2 ActDb2Lp
     END
RETURN
/*****************************************/
/* APPEL DU DB2 : */
/*  - DIS DDF */
/*  - RECUPERE MSTR */
/*****************************************/
GDB2INFO:
/* LECTURE MSTR DBM1 ET IRLM */
 ARG NDB2 ADSN_SSID
 NDB2=WORD(NDB2,1)
 CPTLOG=CPTLOG+1
 LOG.CPTLOG="DIS DDF DU DB2 "NDB2"."
 SAY TIME()" "LOG.CPTLOG
 ADDRESS TSO "DELSTACK"
 QUEUE "-DIS DDF"
 QUEUE "END"
 X=OUTTRAP(TP.)
 ADDRESS TSO "DSN SYSTEM("NDB2")"
 ADSN_COD=RC
 X=OUTTRAP(OFF)
 
 IF ADSN_COD>0 THEN DO
      TAB.ADSN_SSID.14="NODDF"
      TAB.ADSN_SSID.5="ON"
      CPTLOG=CPTLOG+1
      LOG.CPTLOG=NDB2" DIS DDF       RC="ADSN_COD
      SAY TIME()" "LOG.CPTLOG
      DO K=1 TO TP.0
       CPTLOG=CPTLOG+1;LOG.CPTLOG="MSG : "TP.K
       SAY TIME()" "LOG.CPTLOG
       IF wordpos('UNAUTHORIZED',tp.k) >  0 then
       do
         SendAlarm=1
         ZalertMsg='Erreur DIS DDF'
         call Myalarmf
       end
      END
 END    /*IF ADSN_COD>0 THEN DO*/
 ELSE DO
  CPTLOG=CPTLOG+1;LOG.CPTLOG=NDB2" DIS DDF OK."
  SAY TIME()" "LOG.CPTLOG
  CPTLOG=CPTLOG+1
  /* Etat du DDF */
  TAB.ADSN_SSID.14=TRANSLATE(WORD(TP.2,2)," ","=")
  TAB.ADSN_SSID.14=WORD(TAB.ADSN_SSID.14,2)
  TAB.ADSN_SSID.8=WORD(TP.4,2)
  TAB.ADSN_SSID.9=TRANSLATE(WORD(TP.4,3)," ",".")
  TAB.ADSN_SSID.9=WORD(TAB.ADSN_SSID.9,2)
  TAB.ADSN_SSID.10=WORD(TP.4,4)
  IF TAB.ADSN_SSID.10="-NONE" THEN TAB.ADSN_SSID.10="(NULL)"
  TAB.ADSN_SSID.11=substr(WORD(TP.6,2),10,length(WORD(TP.6,2))-9)
  /* port */
  TAB.ADSN_SSID.12=TRANSLATE(WORD(TP.5,2)," ","=")
  TAB.ADSN_SSID.12=WORD(TAB.ADSN_SSID.12,2)
  /* resync port */
  TAB.ADSN_SSID.13=TRANSLATE(WORD(TP.5,4)," ","=")
  TAB.ADSN_SSID.13=WORD(TAB.ADSN_SSID.13,2)
  /* Domain  */
  TAB.ADSN_SSID.15=TRANSLATE(WORD(TP.7,3)," ","=")
  TAB.ADSN_SSID.15=WORD(TAB.ADSN_SSID.15,2)
  TAB.ADSN_SSID.5="ON"
 END     /* COMMANDE DDF OK                IF 01 : DB2    */
 
 /***************************************/
 /* Display GBP seulement pour GBP1 LCL */
 /***************************************/
 drop tp.
 if NDB2 = 'DBP1' & LPAR = 'LIM' then do
     CPTLOG=CPTLOG+1
     LOG.CPTLOG="DIS GBPOOL POUR "NDB2"."
     SAY TIME()" "LOG.CPTLOG
     ADDRESS TSO "DELSTACK"
     QUEUE "-DIS GBPOOL TYPE(GCONN) GDETAIL(INTERVAL)"
     QUEUE "END"
     X=OUTTRAP(TP.)
     ADDRESS TSO "DSN SYSTEM("NDB2")"
     ADSN_COD=RC
     X=OUTTRAP(OFF)
     call ProcessGBPCmd
 end
 /******************/
 /* Display Trace  */
 /*****************/
 drop tp.
     CPTLOG=CPTLOG+1
     LOG.CPTLOG="DIS TRACE POUR "NDB2"."
     SAY TIME()" "LOG.CPTLOG
     ADDRESS TSO "DELSTACK"
     QUEUE "-DIS TRACE"
     QUEUE "END"
     X=OUTTRAP(TP.)
     ADDRESS TSO "DSN SYSTEM("NDB2")"
     ADSN_COD=RC
     X=OUTTRAP(OFF)
     IFC376Seen = 0
     call ProcessDTrace
     say 'IFC376Seen=' IFC376Seen client lpartest
     if IFC376Seen = 0 & client <> 'CRP' & lpartest = 0 then
     do
       rec.1=LPAR'/'NDB2,
         'Absence de trace Fonctions Incompatibles (IFC376)'
       call LogW
     end
 Call ProcessSubsysLogs
 /* recopier les messages dans membre ENVEssid */
 ENVCATD=ENVCATR!!NDB2!!")"
 SAY "ECRITURE : "ENVCATD" "CPTENV" RECORDS"
 ENV.0=CPTENV
 ADDRESS TSO "ALLOC DD(FILE) DS('"ENVCATD"') SHR"
 ADDRESS TSO "EXECIO * DISKW FILE (STEM ENV. FINIS "
 ADDRESS TSO "FREE DDNAME(FILE)"
 /* il faut faire le drop - le env.0 n'a pas d'effet - voir doc REXX */
 drop ENV.
RETURN
/**********************************************************************/
DISGROUP:
 ARG NDB2
 NDB2=WORD(NDB2,1)
 ADDRESS TSO "DELSTACK"
 QUEUE "-DIS GROUP"
 QUEUE "END"
 X=OUTTRAP(TP.)
 ADDRESS TSO "DSN SYSTEM("NDB2")"
 X=OUTTRAP(OFF)
 CptMember = 0
 CptQuiesce = 0
 DO K=1 TO TP.0
  SELECT
   WHEN WORD(TP.K,2)="BEGIN" THEN DO
    DTSHRGP=WORD(SUBSTR(WORD(TP.K,5),7,8),1)
    NBW=WORDS(TP.K)
    MODEV8=SUBSTR(WORD(TP.K,NBW-2),7,3)!!SUBSTR(WORD(TP.K,NBW-1),6,1)
   END
   WHEN WORD(TP.K,4)="ATTACH" THEN DO
    DTSHRGA=WORD(SUBSTR(WORD(TP.K,5),6,4),1)
   END
   WHEN WORD(TP.K,1)="--------" THEN DO
    OUT="NO"
    DO WHILE OUT<>"YES"
     K=K+1
     IF SUBSTR(TP.K,1,3)="---" THEN OUT="YES"
     ELSE DO
      /* Normalement le traitement SMS se fait sur le membre 1*/
      /* mais dans le cas des faux DS, le membre 1 peut etre */
      /* Quiesced , dans ce cas il faut forcer les traitement SMS*/
      CptMember = CptMember + 1
      DTSHRLT=DTSHRLT" "WORD(TP.K,1)
      IF WORD(TP.K,2)="1" & NDB2=WORD(TP.K,1) THEN DTSHRPR=1
      IF WORD(TP.K,5)='QUIESCED' then CptQuiesce = CptQuiesce+1
      IF WORD(TP.K,3)=NDB2  then do
                                   IrlmName = WORD(TP.K,9)
                                   CmdPref  = WORD(TP.K,4)
                                 end
     END
    END
   END
   OTHERWISE
  END
 END
 DTSHRLT=strip(DTSHRLT)
 TAB.SSID.24=MODEV8
 if (CptMember - CptQuiesce) = 1 then DTSHRPR=1
RETURN
/**********************************************************************/
JU004:
 X=OUTTRAP(VAR.)
 ADDRESS TSO "FREE DDNAME(SYSIN)"
 ADDRESS TSO "FREE DDNAME(SYSPRINT)"
 BSDSOUT1="SYSTMP.DBDC."SSID".DB2INST.D"DATE('B')".T"TIME('S')
 ADDRESS TSO "ALLOC DD(SYSPRINT) DS('"BSDSOUT1"') NEW "!!,
             "DSORG(PS) RECFM(F B) LRECL(133) BLKSIZE(0) "!!,
             "SPACE(10000 10000)"
 IF RC<>0 THEN DO
  SAY "ERREUR D'ALLOCATION DU : "BSDSOUT1
  SAY "CODE : "RC
  call myexite
 END
 ADDRESS TSO "ALLOC DD(SYSUT1) DS('"BSDS1"') SHR"
 RC1=RC
 IF BSDS2<>"" THEN DO
  ADDRESS TSO "ALLOC DD(SYSUT2) DS('"BSDS2"') SHR"
  IF RC1=0 THEN RC1=RC
 END
 X=OUTTRAP(OFF)
 IF RC1=0 THEN DO
  CPTLOG=CPTLOG+1
  LOG.CPTLOG="LECTURE BSDS "BSDS1
  SAY LOG.CPTLOG
  X=OUTTRAP(VAR.)
  Say 'Appel DSNJU004' /* submit DSNJU004 */
  ADDRESS LINK "DSNJU004"
  ADDRESS TSO "FREE DDNAME(SYSUT1)"
  ADDRESS TSO "FREE DDNAME(SYSUT2)"
  X=OUTTRAP(OFF)
  ADDRESS TSO "EXECIO * DISKR SYSPRINT ( FINIS"
  NBR=QUEUED()
  /* si probleme sur dsnju004 */
  if nbr   < 20 then
  do
       say 'erreur execution DSNJU004, sysprint :'
       DO L=1 TO NBR
                PULL TAMP
                say  TAMP
       end
       ADDRESS TSO "DELETE '"BSDSOUT1"'"
       call myexite
  end
  ADDRESS TSO "FREE DDNAME(SYSPRINT)"
  X=OUTTRAP(VAR.)
  /* delete pour eviter pb d'espace dans systmp */
  ADDRESS TSO "DELETE '"BSDSOUT1"'"
  X=OUTTRAP(OFF)
  /* Init. variables */ 
  CATNAME=""
  DataSharingMode=""
  DTSHRGP=""
  DTSHRLT=""
  TypeActiveLog=0  /* active 1 ou 2 */
  TypeArchLog=0 /* archive 1 ou 2 */
  NbActLog=0
  MDT1=0
  MDT2=0
  MDT3=0
  MDT4=0
  MDT5=0
  MDT6=0
  MDT7=0
  MDT8=0
  MDT9=0
  MDT10=0
  MDT11=0
  MDT12=0
  DureeTotalLog=9999999
  DateAAJJJ=DATE('J')  /* Date en AAJJJ*/
  DateAA=SUBSTR(DateAAJJJ,1,2)  /* Année*/
  DateJJ=SUBSTR(DateAAJJJ,3,3)  /* Jour en format JJJ*/
  DateJJ=DateJJ-35  /* On remonte à 35 jours dans le passé*/
  IF DateJJ<1 THEN DO
   DateJJ=365+DateJJ
   DateAA=DateAA-1
  END
  /* On reconstruit la date AAJJJ mais 35 jour avant */
  DateAAJJJ=RIGHT(DateAA,2,"0")!!RIGHT(DateJJ,3,"0")
  LSTACTLG=""
  SIZACTLG=""
  TOZACTLG=0
  FlagLogActive=0
  FlagArchive=0
  /* boucle de lecture sysprint ds dsnju004 */
  DO L=1 TO NBR
       PULL TAMP
       L=L+1
       TAMP=SUBSTR(TAMP,2,132)
       /* traiter chaque ligne de JU004 (archives et active) */
       CALL PROCESS_JU004
       /* on arrete de lire quand on rencontre la ligne log active 2*/
       if TypeActiveLog=2 then leave
  END
  /* check unit archive */
  DsnArchive = "'" !! strip(DsnArchive) !! "'"
  x    = OUTTRAP('dsi.') /* trap LISTDSI message */
  rtn_code =  LISTDSI(DsnArchive)
  x    = OUTTRAP(OFF)
  say 'last_archive ' DsnArchive
  if rtn_code > 0 then
  do
    say sysmsglvl1
    say sysmsglvl2
  end
  if word(sysmsglvl2,5) = 'DOES' & word(sysmsglvl2,6) = 'NOT',
   & word(sysmsglvl2,7) = 'RESIDE' & word(sysmsglvl2,10)= 'DIRECT',
   & word(sysmsglvl2,11)= 'ACCESS'
  then
           TAB.SSID.29='T'      /* Unit Tape      */
  else  do
           if rtn_code = 0 then TAB.SSID.29='D'
           else
               do
                  if word(sysmsglvl2,2) = 'DATA' & ,
                     word(sysmsglvl2,4) = 'MIGRATED'
                  then TAB.SSID.29='D'
                  else TAB.SSID.29='V' /*probably VTS */
               end
         end
  TAB.SSID.35=NbArch-NBLG30J /* nbre archive sur 30 jours */
  /* max cycle log et min cycle log */
  VNBMIN=TRUNC(HMINBSEC/60)
  NBSEC=HMINBSEC-(VNBMIN*60)
  VNBHRS=TRUNC(VNBMIN/60)
  NBMIN=VNBMIN-(VNBHRS*60)
  NBJRS=TRUNC(VNBHRS/24)
  NBHRS=VNBHRS-(NBJRS*24)
  /* Cycle Minimum Archivage */
  TAB.SSID.36=NBJRS"J "RIGHT(NBHRS,2,"0")":"RIGHT(NBMIN,2,"0")":",
           !!RIGHT(NBSEC,2,"0")
  VNBMIN=TRUNC(HMANBSEC/60)
  NBSEC=HMANBSEC-(VNBMIN*60)
  VNBHRS=TRUNC(VNBMIN/60)
  NBMIN=VNBMIN-(VNBHRS*60)
  NBJRS=TRUNC(VNBHRS/24)
  NBHRS=VNBHRS-(NBJRS*24)
  /* Cycle Max Archivage */
  TAB.SSID.37=NBJRS"J "RIGHT(NBHRS,2,"0")":"RIGHT(NBMIN,2,"0")":",
        !!RIGHT(NBSEC,2,"0")
  TAB.SSID.38=DateFirstArch /* Premiere archive */
  NBGLA=WORDS(LSTDBAR) /* nbre de log archives de - de  30j */
  IF NBGLA>0 THEN DO
   FLAG=""
   NBLG10M=0
   NBLG20M=0
   NBLG30M=0
   NBLG01H=0
   NBLG03h=0
   NBLG06H=0
   NBLG12H=0
   NBLG24H=0
   NBLG30J=0
   DO N=1 TO NBGLA
    REF10M=400; NBLGREF10=0
    REF20M=800; NBLGREF20=0
    REF30M=1200; NBLGREF30=0
    REF01H=2400; NBLGREF01=0
    REF03H=7200; NBLGREF03=0
    REF06H=21600; NBLGREF06=0
    REF12H=43200; NBLGREF12=0
    REF24H=86400;
    DEBREF=WORD(LSTDBAR,N)
    /* calcul sur 30 jours, le nombre maxi de : */
    /* le nombre de log en moins de x temps  */
    DO M=1 TO NBGLA
       NB=M+N
       NBLGREF=M     /* nbre de log distant de debref */
       IF NB>NBGLA THEN FLAG="%%%%"
       ELSE DO
        FLAG=""
        FINREF=WORD(LSTDBAR,NB)
        DELTA=FINREF-DEBREF
        IF DELTA>REF10M & NBLGREF10=0 THEN NBLGREF10=NBLGREF
        IF DELTA>REF20M & NBLGREF20=0 THEN NBLGREF20=NBLGREF
        IF DELTA>REF30M & NBLGREF30=0 THEN NBLGREF30=NBLGREF
        IF DELTA>REF01H & NBLGREF01=0 THEN NBLGREF01=NBLGREF
        IF DELTA>REF03H & NBLGREF03=0 THEN NBLGREF03=NBLGREF
        IF DELTA>REF06H & NBLGREF06=0 THEN NBLGREF06=NBLGREF
        IF DELTA>REF12H & NBLGREF12=0 THEN NBLGREF12=NBLGREF
        /* si le delta est > 24 h on sort de la boucle */
        IF DELTA>REF24H THEN M=NBGLA
     END  /* else */
    END /* fin boucle interieure */
    /* on prend la nouvelle valeur si elle est plus grande */
    IF NBLG10M<NBLGREF10 & FLAG="" THEN NBLG10M=NBLGREF10
    IF NBLG20M<NBLGREF20 & FLAG="" THEN NBLG20M=NBLGREF20
    IF NBLG30M<NBLGREF30 & FLAG="" THEN NBLG30M=NBLGREF30
    IF NBLG01H<NBLGREF01 & FLAG="" THEN NBLG01H=NBLGREF01
    IF NBLG03H<NBLGREF03 & FLAG="" THEN NBLG03H=NBLGREF03
    IF NBLG06H<NBLGREF06 & FLAG="" THEN NBLG06H=NBLGREF06
    IF NBLG12H<NBLGREF12 & FLAG="" THEN NBLG12H=NBLGREF12
    IF NBLG24H<NBLGREF & FLAG="" THEN NBLG24H=NBLGREF
   END /* boucle exterieur */
   TAB.SSID.39="NOMBRE DE LOG MAXIMUM SUR 10M "NBLG10M
   TAB.SSID.40="NOMBRE DE LOG MAXIMUM SUR 20M "NBLG20M
   TAB.SSID.41="NOMBRE DE LOG MAXIMUM SUR 30M "NBLG30M
   TAB.SSID.42="NOMBRE DE LOG MAXIMUM SUR 01H "NBLG01H
   TAB.SSID.43="NOMBRE DE LOG MAXIMUM SUR 03H "NBLG03H
   TAB.SSID.44="NOMBRE DE LOG MAXIMUM SUR 06H "NBLG06H
   TAB.SSID.45="NOMBRE DE LOG MAXIMUM SUR 12H "NBLG12H
   TAB.SSID.46="NOMBRE DE LOG MAXIMUM SUR 24H "NBLG24H
  END
  ELSE DO
   TAB.SSID.39="NOMBRE DE LOG MAXIMUM SUR 10M NOP"
   TAB.SSID.40="NOMBRE DE LOG MAXIMUM SUR 20M NOP"
   TAB.SSID.41="NOMBRE DE LOG MAXIMUM SUR 30M NOP"
   TAB.SSID.42="NOMBRE DE LOG MAXIMUM SUR 01H NOP"
   TAB.SSID.43="NOMBRE DE LOG MAXIMUM SUR 03H NOP"
   TAB.SSID.44="NOMBRE DE LOG MAXIMUM SUR 06H NOP"
   TAB.SSID.45="NOMBRE DE LOG MAXIMUM SUR 12H NOP"
   TAB.SSID.46="NOMBRE DE LOG MAXIMUM SUR 24H NOP"
  END
  TAB.SSID.48=HRBAWRIT
  TAB.SSID.47=DateMinArch
 END
RETURN

ConvertDate2NbDays:
/* CONVERTIT UNE DATE FORMAT AAAA.QQQ EN NBR DE JOUR DEPUIS LE 01/01/2000*/
/* EXEMPLE  2010.291 DONNE 3944 */
 ARG VAL
 /* jusqu' a 2019 ...*/
 NJ2000="        366   731  1096  1461  1827  2192  2557  2922  3288 "!!,
        " 3653  4018  4383  4749  5114  5479  5844  6210  6575  6940 "!!,
        " 7305  7671  8036  8401  8766  9132  9497  9862 10227 10593 "
 VAL=TRANSLATE(VAL," ",".")
 ANN=WORD(VAL,1)
 ANN=ANN-2000
 JJJ=WORD(VAL,2)
 IF ANN>0 THEN NBJ=WORD(NJ2000,ANN)
 ELSE NBJ=0
 NBJ=NBJ+JJJ
RETURN NBJ
ConvertDate2DateB:
/* CONVERTIT UNE DATE FORMAT AAAA.QQQ EN JJ JJJ AAAA*/
/* EXEMPLE  2010.291 DONNE 18 Oct 2010 */
 ARG VAL
 VAL=ConvertDate2NbDays(VAL)
RETURN DATE('N',VAL,'C')
process_sms2:
     X=OUTTRAP(LSTCAT.)
     CPTLOG=CPTLOG+1
     LOG.CPTLOG="LECTURE ACTIVE LOG "  DsnActLog
     SAY TIME()" "LOG.CPTLOG
     l= lastpos('.',DsnActLog)
     DsnActLog=substr(DsnActLog,1,l-1)
     /* appel display info ds */
     ADDRESS TSO CMDLSTDS DsnActLog
     X=OUTTRAP(OFF)
       CPTLOG=CPTLOG+1
       LOG.CPTLOG="FIN LECTURE ACT LOG"
       SAY TIME()" "LOG.CPTLOG
     LSTVOL=""
     /* construction du membre LOGAssid */
     say 'construction du membre LOGAssid'
     DO L=1 TO LSTCAT.0
      /* on retient tous les volser pour traiter apres*/
      IF WORD(LSTCAT.L,1)="VOLSER" THEN DO
       IF POS(WORD(LSTCAT.L,3),LSTVOL)=0 THEN,
       LSTVOL=LSTVOL" "WORD(LSTCAT.L,3)
      END
     END
     VOLCATD=LOGACTR!!NDB2!!")"
     IF LSTCAT.0>0 THEN DO
      CPT=LSTCAT.0
      CPT=CPT+1
      LSTCAT.CPT="EXTRACTION LISTCAT DU "DATE()" A "TIME()
      CPT=CPT+1
      LSTCAT.CPT=""
      ADDRESS TSO "ALLOC DD(FILE) DS('"VOLCATD"') SHR"
      ADDRESS TSO "EXECIO * DISKW FILE (STEM LSTCAT. FINIS "
      ADDRESS TSO "FREE DDNAME(FILE)"
      DROP LSTCAT.
     END
     say 'Fin construction du membre LOGAssid'
     /* fin construction membre LOGAssid */
     LSTVLSC=""
     LSTSTOG=""
     CONSMSX.0=0
     DO L=1 TO WORDS(LSTVOL)
      IF POS(WORD(LSTVOL,L),LSTVLSC)=0 & WORD(LSTVOL,L)<>"*" THEN DO
       /* commande display sms pour recup. storage group */
       CMD="D SMS,VOL("WORD(LSTVOL,L)")"
       X=OUTTRAP(TMP.)
       ADDRESS TSO "CONSPROF SOLDISPLAY(NO)"
       if rc > 0 then do
              say 'erreur commande CONSPROF SOLDISPLAY' rc
              DO R=1 TO TMP.0
                    say tmp.r
              end
              call myexite
          end
       X=OUTTRAP(OFF)
       CDE=RC
       IF CDE=0 THEN DO
        ADDRESS TSO "CONSOLE  SYSCMD("CMD") NAME("CONSNAME") "!!,
                    "CART('CLNK')"
        if rc > 0 then do
                         say 'erreur commande CONSOLE SYSCMD'
                         call myexite
                      end
        MSG = GETMSG('CONSMSG.','SOL','CLNK',,5)
        ADDRESS TSO "CONSOLE DEACTIVATE"
        IF CONSMSG.0>0 THEN DO
         DO M=1 TO CONSMSG.0
          IF WORD(CONSMSG.M,1)=WORD(LSTVOL,L) THEN DO
           STGNAM=WORD(CONSMSG.M,WORDS(CONSMSG.M))
           IF POS(STGNAM,LSTSTOG)=0 THEN DO
            LSTSTOG=LSTSTOG" "STGNAM
            CMD="D SMS,SG("STGNAM"),LISTVOL"
            X=OUTTRAP(TMP.)
            ADDRESS TSO "CONSPROF SOLDISPLAY(NO)"
            X=OUTTRAP(OFF)
            CDE=RC
            IF CDE=0 THEN DO
               ADDRESS TSO "CONSOLE  SYSCMD("CMD") "!!,
                           "NAME("CONSNAME") CART('CLNK')"
               if rc > 0 then do
                         say 'erreur commande CONSOLE SYSCMD 2'
                         call myexite
                      end
               MSG = GETMSG('CONSMS2.','SOL','CLNK',,5)
               ADDRESS TSO "CONSOLE DEACTIVATE"
            END
           END
          END
         END
         IF CONSMS2.0>0 THEN DO
     /*   say consms2 = conSMS2.0
          do i=1 to CONSMS2.0
                  say CONSMS2.i
          end */
          MBX=0
          TOTVOL=0
          TOTUSE=0
          DO M=1 TO CONSMS2.0
           VOLUME=""
           IF CONSMS2.M <>"" THEN DO
            CPT=CONSMSX.0; CPT=CPT+1; CONSMSX.CPT=CONSMS2.M
            CONSMSX.0=CPT
            SELECT
             WHEN WORD(CONSMS2.M,1)="STORGRP" THEN DO
              CP=M+1;STOG=SUBSTR(CONSMS2.CP,1,9)
              STOG=TRANSLATE(STOG," ",'00'X)
              STOG=WORD(STOG,1)
             END
             WHEN WORD(CONSMS2.M,1)="VOLUME" &,
                  WORD(CONSMS2.M,WORDS(CONSMS2.M))="NAME" THEN DO
              MBX=WORDS(CONSMS2.M)
             END
             WHEN WORD(CONSMS2.M,WORDS(CONSMS2.M))=STOG &,
               WORDS(CONSMS2.M)=MBX-2 THEN DO
              VOLUME=WORD(CONSMS2.M,1)
              IF POS(VOLUME,LSTVLSC)=0 THEN DO
               IF TBHISTVL.VOLUME.0=17 THEN DO
                CPTLOG=CPTLOG+1;LOG.CPTLOG="RECUP. INFO VOLUME "VOLUME
                SAY TIME()" "LOG.CPTLOG
                LSTVLSC=LSTVLSC" "VOLUME
                DO R=1 TO TBHISTVL.VOLUME.0
                 CPT=CPT+1;CONSMSX.0=CPT;CONSMSX.CPT=TBHISTVL.VOLUME.R
                 VOLXX=TBHISTVL.VOLUME.99
                 TOTVOL=TOTVOL+VOLXX
                 USEXX=TBHISTVL.VOLUME.98
                 TOTUSE=TOTUSE+USEXX
                END
               END
               ELSE DO
                CPTLOG=CPTLOG+1;LOG.CPTLOG="SCAN DU VOLUME "VOLUME
                SAY TIME()" "LOG.CPTLOG
                LSTVLSC=LSTVLSC" "VOLUME
 
                call info_space
 
               END  /* fonction scan volume */
              END
             END
             OTHERWISE
            END
           END
          END
          IF TOTVOL<>0 THEN DO
       /*  Pas d'alerte sur log car stogroup taillé tres pres*/
       /*  IF TOTuse *100/TOTVOL>95 THEN DO
            CMD="ALARMDB2 "NDB2" STOGROUP LOGS PLEIN A PLUS"!!,
                " DE 95%" TOTuse "/" TOTVOL STOG
            rec.1=CMD
            call LogWm
           END */
          END
          STGCATD=LOGACTV!!NDB2!!")"
          CPT=CONSMSX.0
          CPT=CPT+1
          CONSMSX.CPT="EXTRACTION INFO SMS DU "DATE()" A "TIME()
          CONSMSX.0=CPT
          ADDRESS TSO "ALLOC DD(FILE) DS('"STGCATD"') SHR"
          ADDRESS TSO "EXECIO * DISKW FILE (STEM CONSMSX. FINIS "
          ADDRESS TSO "FREE DDNAME(FILE)"
         END
        END
       END
      END
     END
 return
process_sms:
    IF CATNAME<>"" THEN DO
     X=OUTTRAP(LSTCAT.)
     CPTLOG=CPTLOG+1
     LOG.CPTLOG="LECTURE "CATNAME".DSNDBC.DSNDB01"
     SAY TIME()" "LOG.CPTLOG
     /* appel display info ds */
     ADDRESS TSO CMDLSTDS CATNAME".DSNDBC.DSNDB01 LIST"
       CPTLOG=CPTLOG+1
       LOG.CPTLOG="LECTURE "CATNAME".DSNDBC.DSNDB06"
       SAY TIME()" "LOG.CPTLOG
     /* appel display info ds */
     ADDRESS TSO CMDLSTDS CATNAME".DSNDBC.DSNDB06 LIST"
     X=OUTTRAP(OFF)
       CPTLOG=CPTLOG+1
       LOG.CPTLOG="FIN LECTURE "CATNAME".DSNDBC.DSNDB06"
       SAY TIME()" "LOG.CPTLOG
     LSTVOL=""
     /* construction du membre VLKTssid */
     say 'construction du membre VLKTssid'
     DO L=1 TO LSTCAT.0
      /* on retient tous les volser pour traiter apres*/
      IF WORD(LSTCAT.L,1)="VOLSER" THEN DO
       IF POS(WORD(LSTCAT.L,3),LSTVOL)=0 THEN,
       LSTVOL=LSTVOL" "WORD(LSTCAT.L,3)
      END
     END
     VOLCATD=VOLCATR!!NDB2!!")"
     IF LSTCAT.0>0 THEN DO
      CPT=LSTCAT.0
      CPT=CPT+1
      LSTCAT.CPT="EXTRACTION DU "DATE()" A "TIME()
      CPT=CPT+1
      LSTCAT.CPT=""
      ADDRESS TSO "ALLOC DD(FILE) DS('"VOLCATD"') SHR"
      ADDRESS TSO "EXECIO * DISKW FILE (STEM LSTCAT. FINIS "
      ADDRESS TSO "FREE DDNAME(FILE)"
      DROP LSTCAT.
     END
     say 'Fin construction du membre VLKTssid'
     /* fin construction membre VLKTssid */
     LSTVLSC=""
     LSTSTOG=""
     CONSMSX.0=0
     DO L=1 TO WORDS(LSTVOL)
      IF POS(WORD(LSTVOL,L),LSTVLSC)=0 & WORD(LSTVOL,L)<>"*" THEN DO
       /* commande display sms */
       CMD="D SMS,VOL("WORD(LSTVOL,L)")"
       X=OUTTRAP(TMP.)
       ADDRESS TSO "CONSPROF SOLDISPLAY(NO)"
       if rc > 0 then do
                         say 'erreur commande CONSPROF SOLDISPLAY'
                         call myexite
                      end
       X=OUTTRAP(OFF)
       CDE=RC
       IF CDE=0 THEN DO
        ADDRESS TSO "CONSOLE  SYSCMD("CMD") NAME("CONSNAME") "!!,
                    "CART('CLNK')"
        if rc > 0 then do
                         say 'erreur commande CONSOLE SYSCMD'
                         call myexite
                      end
        MSG = GETMSG('CONSMSG.','SOL','CLNK',,5)
        ADDRESS TSO "CONSOLE DEACTIVATE"
        IF CONSMSG.0>0 THEN DO
         DO M=1 TO CONSMSG.0
          IF WORD(CONSMSG.M,1)=WORD(LSTVOL,L) THEN DO
           STGNAM=WORD(CONSMSG.M,WORDS(CONSMSG.M))
           IF POS(STGNAM,LSTSTOG)=0 THEN DO
            LSTSTOG=LSTSTOG" "STGNAM
            CMD="D SMS,SG("STGNAM"),LISTVOL"
            X=OUTTRAP(TMP.)
            ADDRESS TSO "CONSPROF SOLDISPLAY(NO)"
            X=OUTTRAP(OFF)
            CDE=RC
            IF CDE=0 THEN DO
             ADDRESS TSO "CONSOLE  SYSCMD("CMD") "!!,
                         "NAME("CONSNAME") CART('CLNK')"
             MSG = GETMSG('CONSMS2.','SOL','CLNK',,5)
             ADDRESS TSO "CONSOLE DEACTIVATE"
            END
           END
          END
         END
         IF CONSMS2.0>0 THEN DO
          MBX=0
          TOTVOL=0
          TOTUSE=0
          DO M=1 TO CONSMS2.0
           VOLUME=""
           IF CONSMS2.M<>"" THEN DO
            CPT=CONSMSX.0;
            CPT=CPT+1; CONSMSX.CPT=CONSMS2.M
            CONSMSX.0=CPT
            SELECT
             WHEN WORD(CONSMS2.M,1)="STORGRP" THEN DO
              CP=M+1;STOG=SUBSTR(CONSMS2.CP,1,9)
              STOG=TRANSLATE(STOG," ",'00'X)
              STOG=WORD(STOG,1)
             END
             WHEN WORD(CONSMS2.M,1)="VOLUME" &,
                  WORD(CONSMS2.M,WORDS(CONSMS2.M))="NAME" THEN DO
              MBX=WORDS(CONSMS2.M)
             END
             WHEN WORD(CONSMS2.M,WORDS(CONSMS2.M))=STOG &,
               WORDS(CONSMS2.M)=MBX-2 THEN DO
              VOLUME=WORD(CONSMS2.M,1)
              IF POS(VOLUME,LSTVLSC)=0 THEN DO
               IF TBHISTVL.VOLUME.0=17 THEN DO
                CPTLOG=CPTLOG+1;LOG.CPTLOG="RECUP. INFO VOLUME "VOLUME
                SAY TIME()" "LOG.CPTLOG
                LSTVLSC=LSTVLSC" "VOLUME
                DO R=1 TO TBHISTVL.VOLUME.0
                 CPT=CPT+1;CONSMSX.0=CPT;CONSMSX.CPT=TBHISTVL.VOLUME.R
                 VOLXX=TBHISTVL.VOLUME.99
                 TOTVOL=TOTVOL+VOLXX
                 USEXX=TBHISTVL.VOLUME.98
                 TOTUSE=TOTUSE+USEXX
                END
               END
               ELSE DO
                CPTLOG=CPTLOG+1;LOG.CPTLOG="SCAN DU VOLUME "VOLUME
                SAY TIME()" "LOG.CPTLOG
                LSTVLSC=LSTVLSC" "VOLUME
 
                call info_space
 
               END  /* fonction scan volume */
              END
             END
             OTHERWISE
            END
           END
          END
          IF TOTVOL<>0 THEN DO
           IF TOTuse *100/TOTVOL>95 THEN DO
            TOTFREE=TOTVOL-TOTUSE
            CMD="ALARMDB2 "LPAR NDB2" STOGROUP SYST. PLEIN A +"!!,
                  "95%" STOG TOTuse"/"TOTVOL "FREE="TOTFREE
            if LPARProd=1 &   TOTFREE < 2500 then do
              rec.1=CMD /* message warning to Team */
              call LogWm
            end
            /* Push Alerte DASD que si taille restant < 2Gb */
            If TotFree < 1500 then
                Do
                 zAlertType='DASD'
                 call MyAlarmf
                End
            X=OUTTRAP(TMP.)
            ADDRESS TSO "CONSPROF SOLDISPLAY(NO)"
            X=OUTTRAP(OFF)
            CDE=RC
            IF CDE=0 THEN DO
             ADDRESS TSO "CONSOLE  SYSCMD("CMD") NAME("CONSNAME") "!!,
                         "CART('CLNK')"
             MSG = GETMSG('CONSMSG.','SOL','CLNK',,5)
             ADDRESS TSO "CONSOLE DEACTIVATE"
            END
           END
          END
          STGCATD=STGCATR!!NDB2!!")"
          CPT=CONSMSX.0
          CPT=CPT+1
          CONSMSX.CPT="EXTRACTION DU "DATE()" A "TIME()
     /*   CPT=CPT+1
          CONSMSX.CPT="" */
          CONSMSX.0=CPT
          ADDRESS TSO "ALLOC DD(FILE) DS('"STGCATD"') SHR"
          ADDRESS TSO "EXECIO * DISKW FILE (STEM CONSMSX. FINIS "
          ADDRESS TSO "FREE DDNAME(FILE)"
         END
        END
       END
      END
     END
    END
    ELSE DO
     CPTLOG=CPTLOG+1
     LOG.CPTLOG="ERREUR LECTURE BSDS "BSDS1" : VCATNAME NON TROUVE."
     SAY TIME()" "LOG.CPTLOG
    END
 return
 
SDSF:
ARG JOBNAME PARM
 /* si dbm1 on ne prend que les 1000 premieres lignes */
 dbm1=0
 if right(JOBNAME,4)='DBM1'  THEN
 do
    dbm1=1
 end
 say 'SDSF searching output for job:' jobname
 
 RC=ISFCALLS('ON')
 ISFPREFIX=jobname
 ISFOWNER="*"
 if MVSVAR(SYSNAME) = 'SYST' then ISFINPUT="ON"
 ADDRESS SDSF "ISFEXEC DA OSTC"
  IF  RC  <> 0 then
  do
       Say 'Command ' CMD ' not issued: ' ISFMSG
       reasonstep = ISFMSG2.1
       DO I = 1 TO ISFMSG2.0
          SAY 'ISFMSG2.' I ISFMSG2.I
       end
  end
 LRC=RC
 JNAME.0=ISFROWS
 PT=0
 IF LRC<>0 THEN EXIT 20
 DO IX=1 TO JNAME.0
    IF JNAME.IX = JOBNAME THEN
    do
       ADDRESS SDSF "ISFACT DA OSTC TOKEN('"TOKEN.IX"') PARM(NP SA)"
       LRC=RC
       IF  RC >0 THEN
       do
      /************************************************/
      /* The isfmsg variable contains a short message */
      /************************************************/
          Say  isfmsg
 
           /****************************************************/
           /* The isfmsg2 stem contains additional descriptive */
           /* error messages                                   */
           /****************************************************/
          do ix=1 to isfmsg2.0
            Say isfmsg2.ix
          end
          exit 20
       end
       mstr_full=0
       DO JX=1 TO ISFDDNAME.0
          if mstr_full then leave
          RCIO=0
          /* on ne lit que le 2e output */
          if dbm1 & jx=1 then iterate
          if dbm1 & jx=3 then leave
          DO WHILE RCIO=0
               ADDRESS TSO "DELSTACK"
               /* boucle de lecture chaque 5000 records */
               Select
                 when parm <> 'SKIP' then
                    nop
                 when parm =  'SKIP' & rt=1 then
                 do
                  say 'Skip MSTR 1M lines'
                  "EXECIO 1000000 DISKR" ISFDDNAME.JX "(SKIP"
                  parm = 'SK'
                  pt=60
                 end
                 when parm =  'SKIP' & rt=2  then
                 do
                  say 'Skip MSTR 2M lines'
                  "EXECIO 2000000 DISKR" ISFDDNAME.JX "(SKIP"
                  parm = 'SK'
                  pt=60
                 end
                 when parm =  'SKIP' & rt=3 then
                 do
                  say 'Skip MSTR 3M lines'
                  "EXECIO 3000000 DISKR" ISFDDNAME.JX "(SKIP"
                  parm = 'SK'
                  pt=60
                 end
                 otherwise
               End
               "EXECIO 5000 DISKR" ISFDDNAME.JX "(STEM LINE."
               RCIO=RC
               if (pt > 1000000)          then
               /* prevent storage exhaust too much lines*/
               /* On envoie le message qu'une fois      */
               do
                  /* On envoie le message qu'une fois      */
                  if parm = 'PRINT' then
                  do
                     /* exclusion manuelle ...*/
                     if wordpos(lpar,'SUDB IPO4') < 0 then
                     do
                       CMD=LPAR NDB2 'MSTR trop gros, saut',
                           '1Millions lignes'
                       rec.1=CMD
                       call LogWm
                     end
                  end
                  mstr_full=1
                  leave
               end
               DO II=1 TO LINE.0
                   PT=PT+1
                   sdf.PT=LINE.II
               END
               if dbm1 then leave
          END /* do while rcio */
          "EXECIO 0 DISKR" ISFDDNAME.JX "(FINIS"
       END /* DO JX=1 TO ISFDDNAME.0 */
    END /* IF JNAME.IX */
 END
 sdf.0=PT
 RC=ISFCALLS('OFF')
return
info_space:
/* appel rxsms ou lstvtoc    */
if rxsms=1 then
do
      /* appel prog. assembleur RXSMS */
      RC=RXSMS('VOL','VOL.',VOLUME)
      if rc > 0  then
      do
          say 'erreur call RXSMS rc=' rc
          call myexite
      end
      TotVolx= word(VOL.1,8)
      TotFreex= word(VOL.1,9)
      TotUsedx= TotVolx - TotFreex
      PerUsedx= TotUsedx*100/TotVolx
      TotVol = TotVolx+Totvol
      TotUse  = TotUsedx + TotUse
      /* reconstruction du message % USED */
      CPT=CONSMSX.0
      CPT=CPT+1;CONSMSX.0=CPT
      CONSMSX.CPT='  '!! VOLUME !! ' %USED = ' format(PerUsedx,5,2)
 
end
else do
      X=OUTTRAP(TMP.)
      ADDRESS TSO CMDVTOC VOLUME
      X=OUTTRAP(OFF)
      CPT=CONSMSX.0
      CPTH=0
      DO R=1 TO TMP.0
       CPT=CPT+1;CONSMSX.0=CPT;CONSMSX.CPT=TMP.R
       CPTH=CPTH+1;
       IF WORD(TMP.R,2)="TVOL" & WORD(TMP.R,3)="=" THEN DO
        VOLXX=WORD(TMP.R,4)
        TOTVOL=TOTVOL+VOLXX
        TBHISTVL.VOLUME.99=VOLXX
       END
       IF WORD(TMP.R,2)="USED" & WORD(TMP.R,3)="=" THEN DO
        USEXX=WORD(TMP.R,4)
        TOTUSE=TOTUSE+USEXX
        TBHISTVL.VOLUME.98=USEXX
       END
       TBHISTVL.VOLUME.CPTH=TMP.R;TBHISTVL.VOLUME.0=CPTH
      END
end
return
/* Read ju004 sysout and process each line */
process_ju004:
   SELECT
    WHEN WORD(TAMP,1)="VSAM" & WORD(TAMP,2)="CATALOG" THEN DO
       CATNAME=WORD(SUBSTR(WORD(TAMP,3),6,8),1)
    END
    WHEN WORD(TAMP,1)="DATA" & WORD(TAMP,2)="SHARING" &,
         WORD(TAMP,3)="MODE" THEN DO
       DataSharingMode=WORD(TAMP,5)  /* Data Sharing mode is ON */
    END
    WHEN WORD(TAMP,1)="HIGHEST" & WORD(TAMP,3)="WRITTEN" THEN DO
       HRBAWRIT=WORD(TAMP,4)
    END
    /*----------------------------*/
    /*     Traitement Active Log  */
    /*----------------------------*/
    WHEN WORD(TAMP,1)="ACTIVE" &,
         WORD(TAMP,2)="LOG" &,
         WORD(TAMP,3)="COPY" THEN
    DO
       TypeActiveLog=WORD(TAMP,4) /* copy 1 ou 2 */
       /* on arrete la lecture si copy 2*/
       FlagLogActive=1
    END
    
    /* Format V11 */
    WHEN FlagLogActive & SUBSTR(WORD(TAMP,4),1,4)='DSN=' THEN
    DO
       /* Concatenation des dsn active logs V11 */
       LSTACTLG=LSTACTLG" "WORD(SUBSTR(WORD(TAMP,4),5,44),1)
       call DiffRBA  /* calcul de la taille active log */
    END
 
    /*------------------------------*/
    /*     Traitement Archive Logs  */
    /*------------------------------*/
 
    WHEN WORD(TAMP,1)='ARCHIVE' & WORD(TAMP,2)='LOG' &,
          WORD(TAMP,3)='COPY' then
    DO
       FlagLogActive=0
       TypeArchLog=WORD(TAMP,4) /* archive 1 ou 2 */
       If TypeArchLog = 2 then return /* Arret traitement si Archive 2 */ 
       IF TypeArchLog=1 then 
       DO
         NbArch=0
         LSTSCAR=''
         LSTDBAR=''
         HMINBSEC=2592000 /* Nb de secondes sur 30 jours  */
         HMANBSEC=0
         /* Date('C') = number of day from 2000 to current */
         /* Seconds of current - 30 days */
         DEBSCAN=(DATE('C')-30)*24*60*60
         NBLG30J=0
         DateFirstArch='' /* Premiere archive */
       END /* End TypeArchLog = 1 */
    END /* End ligne Demarrage section Archive 1 ou 2 */
 
    WHEN TypeArchLog=1 & TypeActiveLog=1 THEN
    DO
       /* On est dans la lecture Archive */
       SELECT
        /* on retient le nom de l'archive pour donner l'info UNIT */
        
 
        WHEN SUBSTR(WORD(TAMP,4),1,4)='DSN=' then 
        Do /* v11 - a optimiser car fait tout le temps */
             DsnArchive= SUBSTR(WORD(TAMP,4),5,44)
        End
 
        /*------------------------------*/
        /* cas des membres data sharing */
        /*----------------------------- */
        
 
        WHEN substr(WORD(TAMP,4),1,4)='VOL=' THEN    /*v11 nfm */
        DO
           L=L+1
           PULL TAMP
           TAMP=SUBSTR(TAMP,2,132)
	         Call ProcessArchLine
        END
 
 
        /*----------------- */
        /* Non Data Sharing */
        /*------------------*/
        /* La seule difference c'est que l'info date est sur la meme*/
        /* ligne que la ligne PASSWORD car on n'a pas le LSRN */
 
        
 
        WHEN substr(WORD(TAMP,6),1,4)='VOL=' THEN    /*     v11 nfm */
        DO
           Call ProcessArchLine
        END
 
        OTHERWISE
 
       END /* End Select */
 
    END /* End WHEN TypeArchLog=1 & TypeActiveLog=1 */
 
   
    WHEN DataSharingMode="OFF" &, /*  v11 NFM */
        TypeActiveLog=1 & TypeArchLog=0 &,
        SUBSTR(WORD(TAMP,6),1,7)="STATUS=" then
    DO
    * on compte le nombre d'active log */
       NbActLog=NbActLog+1
 		END
    END
 
   
    WHEN DataSharingMode="ON" &, /* V11 NFM Absence de PASSWORD=*/
        TypeActiveLog=1 & TypeArchLog=0 &,
        SUBSTR(WORD(TAMP,4),1,7)='STATUS=' then
    DO
       L=L+1
       PULL TAMP
       TAMP=SUBSTR(TAMP,2,132)
       NbActLog=NbActLog+1
    END
 
    OTHERWISE
 
   END    /* End Select */
return
init_MsgAlerte:
/* a reactualiser avec la table IMSG sur SYSA de temps en temps */
MsgAlerte =,
    ' *DSNJ004I',
    ' *DSNJ017E',
    ' *DSNJ032I',
    ' *DSNJ111E',
    ' *DSN7505A',
    ' *IEA480E',
    ' DSNB250E',
    ' *DSNB325A',
    ' DSNB303E',
    ' DSNB601I',
    ' DSNG014I', /* V12 Chgt de function level */
    ' DSNJ033E',
    ' DSNJ110E',
    ' DSNJ113E',
    ' DSNJ114I',
    ' DSNJ114I',
    ' DSNJ125I',
    ' DSNJ128I',
    ' DSNL047I',
    ' DSNL074I', /* Nb Connection 80% */
    ' DSNT816I',
    ' DSNT501I',
    ' DSNT772I',
    ' DSNV516I',
    ' DSNV517I',
    ' DSNI053I',
    ' DSNZ009I',
    ' IOS000I',
    ' IXL013I',
    ' IEA794I' ,
    ' IGD17287I' /* DATA SET COULD NOT BE ALLOCATED NORMALLY */
/* consigner dans warning mais pas alerte mail */
MsgWarn =,
    ' DSNI053I',
    ' DSNV517I',
    ' DSNB431I'
   return
process_mstr:
   cpt053i = 0
   dsnt500i_seen=0
   dsnj002i_seen=0
   MaxArcDur = 0  /* Max archive duration */
   DO J=1 TO SDF.0
    LIGNE=SUBSTR(SDF.J,2,132)
    IF STCID<>"" & STCID=WORD(LIGNE,2) THEN
    DO
        TIMEAL=WORD(LIGNE,1) /* Time at Alert */
        HOURAL=substr(timeal,1,2) /* Hour at alert */
        NOMMSG=WORD(LIGNE,3)
        /* message CTT avec des : qui sont colles a la fin*/
        if substr(nommsg,1,3) = 'CTT' then
        do
           nommsg=strip(nommsg,'T',':')
        end
        /* LSTMSG contient la liste des MSGID vus */
        IF POS(NOMMSG,LSTMSG)=0 &,
           NOMMSG<>"SE" &,
           NOMMSG<>"COUNT" &,
           NOMMSG<>"(TAPE" &,
           NOMMSG<>"DSNZPARM" &,
           NOMMSG<>"ADDR" &,
           NOMMSG<>"CURRENT" &,
           NOMMSG<>"NO" &,
           NOMMSG<>"END" &,
           NOMMSG<>"MODIFY" &,
           SUBSTR(NOMMSG,1,2)<>"*0" &,
           SUBSTR(NOMMSG,1,2)<>"*1" &,
           SUBSTR(NOMMSG,1,2)<>"*2" &,
           SUBSTR(NOMMSG,1,2)<>"*3" &,
           SUBSTR(NOMMSG,1,2)<>"*4" &,
           SUBSTR(NOMMSG,1,2)<>"*5" &,
           SUBSTR(NOMMSG,1,2)<>"*6" &,
           SUBSTR(NOMMSG,1,2)<>"*7" &,
           SUBSTR(NOMMSG,1,2)<>"*8" &,
           SUBSTR(NOMMSG,1,2)<>"*9" &,
           SUBSTR(NOMMSG,1,1)<>"=" &,
           SUBSTR(NOMMSG,1,1)<>"-" &,
           SUBSTR(NOMMSG,1,1)<>"+" &,
           SUBSTR(NOMMSG,1,1)<>"<" &,
           WORD(LIGNE,4)<>"CBR4196D" &,
           WORD(LIGNE,4)<>"IEF238D" &,
           WORD(LIGNE,4)<>"IEF433D" &,
           WORD(LIGNE,4)<>"SETPROG" &,
           SUBSTR(NOMMSG,1,LENGTH(NDB2))<>NDB2 THEN
                 DO
                  LSTMSG=LSTMSG" "NOMMSG
                  /* compteur du jour */
                  TABMSG.NOMMSG.0=0
                  /* compteur du historique */
                  TABMSG.NOMMSG.1=0
                 END
        IF SUBSTR(TABMSG.NOMMSG.0,1,7)<>"TABMSG." THEN
   /* ici il compare la valeur courante avec toute la table TABMSG */
        DO
           TABMSG.NOMMSG.0=TABMSG.NOMMSG.0 + 1
           if  nommsg='DSNI053I' then
                           cpt053i = cpt053i+1
            /* si la date du record est aussi la date du jour */
            /* Dans le Panel J = JOUR H=Historique  */
            /* DATES = Date de la ligne en cours */
            /* Test car  on ne met l'alerte qu'une fois*/
            /* Date du jour : On a tous les records de 00 à 06*/
            /* mais il faut inclure aussi ceux de la journée d'hier */
          IF DATES=DATEJ ! (dates = prevd & houral > '04') then
           do
            TABMSG.NOMMSG.1=TABMSG.NOMMSG.1 + 1
            if TABMSG.NOMMSG.1 = 1 & ,
            wordpos(nommsg,MsgAlerte) > 0 then
               do
                 /* quand on arrive ici il y a une alerte a lancer*/
                 zAlertType = 'MSG'
            /*   timealx=translate(timeal,':','.') */
                 WaitAlerte=0
                 select
                     when  nommsg='DSNT501I' then
                        do
                           WaitAlerte=1
                           if WORD(LIGNE,5) = 'DSNIWCUB' then
                           do
                             WaitAlerte=0
                             rec.1='Alerte:' LPAR,
                               NDB2 Dates timeal 'B37 SORTWRK'
                             zAlertMsg= nommsg !! '@' !! timeal,
                              !! '-' !! 'B37 SORTWRK'
                           end
                        end
                     when  nommsg='DSNB250E'  then
                        do
                           /* go to line 'LPL REASON TYPE=' */
                           j=j+11
                           ligne=Substr(SDF.J,2,132)
                           say ligne
                           if word(ligne,4) = 'TYPE=NOTLOGGD'
                           then nop
                           else
                           do
                             rec.1='Alerte:' lpar ndb2 nommsg,
                                 'Pages to LPL',
                                 word(ligne,4) !! '@' !! timeal
                             zAlertMsg= nommsg !! '@' !! timeal,
                                 ' ' 'Pages to LPL' word(ligne,4)
                           end
                        end
                     when  nommsg='*DSNB325A'  then
                        do
                           /* ligne suivante */
                           if lpar = 'LIM' then
                           do
                             j=j+1
                             LIGNE=SUBSTR(SDF.J,2,132)
                             rec.1='Alerte:' 'SNPP',
                                 'DBP0' Dates timeal nommsg ' ',
                                 word(ligne,8)
                             zAlertMsg= nommsg !! '@' !! timeal,
                                 ' ' word(ligne,8) 'All SNPP'
                           end
                           else WaitAlerte=1 /*no display for others*/
                        end
                     when  nommsg='DSNV516I' then
                        do
                           WaitAlerte=1
                           timeald= timeal
                        end
                     when  nommsg='DSNV517I' then
                        do
                         timeald=translate(timeald,':','.')
                         parse var timeald cac':'mna':'cac1
                         parse var timeal  cac'.'mnb'.'cac1
                         /* envoi alerte que si le SOS
                         dépasse 3 minutes */
                         if (mnb-mna) > 3 then
                         do
                          zAlertMsg= nommsg !! '@' !! timeald !!,
                            '-' !! timealx
                          rec.1='Alerte:' LPAR,
                           NDB2 nommsg !! '@' !! timeald !!,
                            '-' !! timeal
                         end
                         else  WaitAlerte=1
                        end /* when 517i */
                     when  nommsg='DSNI053I' then
                        do
                           cpt053i = cpt053i+1
                           WaitAlerte=1
                           if cpt053i > 2 ! LPARProd =1 then
                           do
                             WaitAlerte=0
                             zAlertMsg= nommsg !! '@' !! timeal ,
                              !! '-' !! 'occ'cpt053i
                             rec.1='Alerte:' LPAR,
                               NDB2 nommsg !! '@' !! timeal ,
                              !! '-' !! 'occ'cpt053i
                           end
                        end
                     otherwise
                        do
                           rec.1='Alerte:' LPAR,
                               NDB2 Dates timeal nommsg
                           zAlertMsg= nommsg !! '@' !! timeal
                        end
                 end /*select */
                 /* On envoie alerte que si le flag attente est a zero*/
                 if WaitAlerte=0 then
                 do
                   /* Dev ou Prod, tout est signale dans msg warning*/
                   /* Alarm que si Prod et message critique */
                   if wordpos(nommsg,MsgWarn)=0 & LPARProd=1 then
                           call MyAlarmf
                   else call LogWm
                 end
               end /* wordpos(nommsg,MsgAlerte) > 0 then */
               else if nommsg = 'DSNT500I' then
               do
                   DSNT500I_seen = 1
               end /* dsnt500i */
           end
        END
    END /* IF STCID<>"" ... */
    ELSE DO
     IF dsnt500I_seen = 1 & WORD(LIGNE,2)='TYPE' then
     do
        dsnt500I_seen = 0
        /* resource not available edm pool */
        if substr(word(ligne,3),1,6) = '000001' ! ,
           substr(word(ligne,3),1,6) = '000020' ! ,
           substr(word(ligne,3),1,6) = '000002' ! ,
           substr(word(ligne,3),1,6) = '000003' ! ,
           substr(word(ligne,3),1,6) = '000008' ! ,
           substr(word(ligne,3),1,8) = '00001202' , /* DSC */
        then nop
        else
        do
           resx=substr(word(ligne,3),4,5)
           if resx=oresx then iterate
           zAlertType = 'MSG'
           zAlertMsg= 'DSNT500I' !! '@' !! timeal      !! ,
                'RES' resx
           call MyAlarmf
           oresx=resx
           iterate
        end
     end
     else
     IF WORD(LIGNE,1)="%%%" & WORD(LIGNE,2)="%%%" THEN DO
          NOMMSG=WORD(LIGNE,3)
          LSTMSG=LSTMSG" "NOMMSG
          TABMSG.NOMMSG.0=0
          TABMSG.NOMMSG.1=WORD(LIGNE,4)
     END
    END
    /* Debut SELECT */
    SELECT
     WHEN WORD(LIGNE,3)="IEF695I" THEN DO
          DATSTA=DATES" "WORD(LIGNE,1)
          USERDB2=WORD(LIGNE,13)
          GRPDB2=WORD(LIGNE,16)
     END
     WHEN WORD(LIGNE,3)='DSNJ002I' & dsnj002i_seen = '0' then do
         dsnj002i_seen ='1'
         dsnj003i_seen ='0'
         j002_date = DateJul
         j002_time = WORD(LIGNE,1)
     END
     WHEN WORD(LIGNE,3)='DSNJ003I' & dsnj002i_seen = '1'then
     do
         dsnj002i_seen ='0'
         j003_time = WORD(LIGNE,1)
         /* DateJul = Date of the current line processed */
         ArcDur = diff_time(j002_date,j002_time,DateJul,j003_time)
         if MaxArcDur < ArcDur then
         do
            MaxArcDur = ArcDur
            MaxArcDate = Dates
            MaxArcTime = j003_time
         end
     END
     WHEN WORD(LIGNE,3)='DSNJ003I' & dsnj003i_seen = '1'then
     do
       dsnj003i_seen ='0'
     END
     WHEN WORD(LIGNE,3)="----" & substr(word(ligne,2),1,3) = 'STC',
     then do
          DATES=WORD(LIGNE,5)" "WORD(LIGNE,6)" "WORD(LIGNE,7)
          STCID=WORD(LIGNE,2)
          /* Date format Julian aaaa.ddd */
          DateJul=Date_Jul(ligne)
     END
     WHEN WORD(LIGNE,3)="DSNZ002I" THEN DO
      CMDPRF=WORD(LIGNE,4)
      ZPARM=WORD(LIGNE,14)
     END
     WHEN WORD(LIGNE,3)="DSNG007I" THEN DO
      CPW=WORDS(LIGNE)
      MODEV8=WORD(LIGNE,CPW-2)WORD(LIGNE,CPW)
      MODEV8=TRANSLATE(MODEV8," ","(")
      MODEV8=TRANSLATE(MODEV8," ",")")
      MODEV8=WORD(MODEV8,1)!!WORD(MODEV8,2)
     END
     WHEN  SDSNEXIT = '' & POS('SYSTEM PARM',LIGNE) > 0
     THEN DO
       CPT=POS('SYSTEM PARM',LIGNE)+13
       CPTX=POS('(',LIGNE)
       IF CPT>0 & CPTX>0 THEN
             SDSNEXIT=SUBSTR(LIGNE,CPT,CPTX-CPT)
     END
     WHEN WORD(LIGNE,2)="XXBSDS2" ! WORD(LIGNE,2)="//BSDS2" !,
          WORD(LIGNE,2)="++BSDS2" THEN DO
      DSBSDS2=WORD(LIGNE,4)
      DSBSDS2=SUBSTR(DSBSDS2,POS("DSN=",DSBSDS2)+4,LENGTH(DSBSDS2)-4)
     END
     WHEN WORD(LIGNE,2)="XXBSDS1" ! WORD(LIGNE,2)="//BSDS1" !,
          WORD(LIGNE,2)="++BSDS1" THEN DO
      DSBSDS1=WORD(LIGNE,4)
      DSBSDS1=SUBSTR(DSBSDS1,POS("DSN=",DSBSDS1)+4,LENGTH(DSBSDS1)-4)
     END
     WHEN WORD(LIGNE,2)="IEFC002I" & WORD(LIGNE,9)= 'SYSTEM',
          & WORD(LIGNE,10)= 'LIBRARY' then
                               PROCLIB=WORD(LIGNE,11)
     OTHERWISE
    END /* End Select */
   END  /* fin boucle lecture mstr */
return
process_dbm1:
   DO J=1 TO SDF.0
    LIGNE=SUBSTR(SDF.J,2,132)
    /* Debut SELECT */
    SELECT
      /*  WHEN WORD(LIGNE,2)='XXSTEPLIB' &, */
          WHEN POS('SDSNLOAD.TICTOC',LIGNE) > 0    then
                do
                     TICTOC='YES'
                     leave
                end
          WHEN WORD(LIGNE,1)='IGD104I'  then
                do
                     leave
                end
          OTHERWISE
    END /* End Select */
   END  /* fin boucle lecture dbm1 */
return
process_irlm:
   DO J=1 TO SDF.0
    LIGNE=SUBSTR(SDF.J,2,132)
    /* Debut SELECT */
    posX= POS('DEADLOK=',LIGNE)
    SELECT
      /*  WHEN WORD(LIGNE,2)='XXSTEPLIB' &, */
          WHEN posX > 0    then
                do
                     /* search for the second "'" */
                     posX=posX+9
                     subline=substr(ligne,posX,10)
                     posY = pos("'",subline)
                     DEADLOK=substr(ligne,posX,posY-1)
                     leave
                end
          OTHERWISE
    END /* End Select */
   END  /* fin boucle lecture irlm */
return
mstr_ok:
   /*--------------------------*/
   /* il y a qqchose dans MSTR */
   /*--------------------------*/
   CPTLOG=CPTLOG+1
   LOG.CPTLOG="LECTURE DE LA SYSOUT "NDB2"MSTR."
   SAY TIME()" "LOG.CPTLOG SDF.0 "LINES TO PROCESS"
   DATES=""
   STCID=""; LSTMSG=""
   bdate  = Date('B') /* today base format */
   PrevD  = Date('N', bdate-1, 'B')  /* previous day in Eur format */
   upper prevd
   /* Dates = Date extracted from MSTR , always with 0 , ex 04 DEC */
   /* Datej & Prevd = Do not have 0 , must add 0 for comparison */
   DateJ=AddZero(DateJ)     /* ex : 01 DEC 2017 */
   PrevD=AddZero(PrevD)
 
   /* chargement variable MsgAlerte */
   call init_MsgAlerte
   /* traitement ligne par ligne mstr */
   SDSNEXIT=''
 
   /********************/
   /* Scan sysout MSTR */
   /********************/
   call process_mstr
 
   /*****************************************/
   /* display valeur MaxArcDur for this DB2 */
   /*****************************************/
   say  LPAR NDB2 'Max Archive duration is : ' MaxArcDur 's',
         '@'  MaxArcDate MaxArcTime
   /* Send message if > 120 seconds & yesterday or today */
   if MaxArcDur > 360 &  LPARProd=1   &,
     (MaxArcDate = Datej ! ,
          (MaxArcDate = PrevD & substr(MaxArcTime,1,2) > 5) )
   then do
       rec.1=LPAR NDB2 'Max Arch. duration is : ' ,
          MaxArcDur 's @' MaxArcDate MaxArcTime
       call LogWm
   end
   /****************************/
   /* Test si relance hors IPL */
   /****************************/
   Testi=  TestRelanceHorsIPL(datipl,datsta,datej)
   if Testi > 0 then
   do
       rec.1=LPAR NDB2 'was recycled on :' datsta
       call LogW
   end
   if  LPARProd=1    &,
       Testi < 0 then
   do
       if         DAT_S2DOW(diplsav) <> 'Sun' then do
         SendAlarm=1
         ZalertMsg='Relance_Hors_IPL'
         call Myalarmf
       end
   end
   k=  WORDS(LSTMSG)
   /* si on en trouve pas assez ... erreur probable */
   if k < 5 then
   do
       say 'Erreur probable lecture sdsf'
       do  i=1 to sdf.0
            say sdf.i
       end
   end
   DO J=1 TO k
      NOMMSG=WORD(LSTMSG,J)
      CPTENV=CPTENV+1
      ENV.CPTENV=LEFT(NOMMSG,10)" "RIGHT(TABMSG.NOMMSG.1,8)" "!!,
                 RIGHT(TABMSG.NOMMSG.0,8)
   END
   drop MsgAlerte
return
dbm1_ok:
   /*--------------------------*/
   /* il y a qqchose dans DBM1 */
   /*--------------------------*/
   CPTLOG=CPTLOG+1
   LOG.CPTLOG="LECTURE DE LA SYSOUT "NDB2"DBM1."
   SAY TIME()" "LOG.CPTLOG SDF.0 "LINES TO PROCESS"
 
   /* traitement ligne  ligne */
   TICTOC=''
   call process_dbm1
   say 'TICTOC=' TICTOC
return
irlm_ok:
   /*--------------------------*/
   /* il y a qqchose dans IRLM */
   /*--------------------------*/
   CPTLOG=CPTLOG+1
   LOG.CPTLOG="LECTURE DE LA SYSOUT "NDB2"IRLM."
   SAY TIME()" "LOG.CPTLOG SDF.0 "LINES TO PROCESS"
 
   /* traitement ligne  ligne */
   DEADLOK=''
   call process_irlm
   say 'DEADLOK=' DEADLOK
return
racfopt:
  /* taille module racf DB2 */
  name='DSNXàXAC'
  say TAB.SSID.7
  if TAB.SSID.7 = '' then
      dsname = "EXPL.DB2."NDB2".SDSNEXIT"
  else
      dsname = "EXPL.DB2."TAB.SSID.7".SDSNEXIT"
  if client = 'CAAGIS' then
  do
      dsname = SDSNEXIT
  end
  say 'Checking racf DB2 module ' name ' in ' dsname
  Address ISPEXEC "LMINIT DATAID(FINDMOD1) DATASET('"dsname"')"
  If RC <> 0 then do
    Say   'Error processing' name ':'
    Say   Strip(ZERRLM)
    return
  End
  Address ISPEXEC "LMOPEN DATAID("FINDMOD1") RECFM(RFVAR)"
  If RC <> 0 then do
    Say   'Error processing' name ':'
    Say   Strip(ZERRLM)
    Address ISPEXEC "LMFREE DATAID("FINDMOD1")"
    return
  End /* if RC <> 0 */
  Address ISPEXEC "lmmfind DATAID("FINDMOD1")  ",
          "member("NAME") STATS(YES)"
  If RC = 0 then     /* match found */
    Do
      Say  name    'found in' dsname 'size'  ZLSIZE
      if ZLSIZE > '00000040' then RACF='Y'
                             else RACF='N'
    End
    Else do  /* no match found, or no more in list */
      say name 'not found'
      Address ISPEXEC "LMCLOSE DATAID("FINDMOD1")"
      Address ISPEXEC "LMFREE DATAID("FINDMOD1")"
    End /* else do */
  return
LogW:
     oufw = "'" !! hlq !! '.reportsw.' !! 'DIV' !! "'"
     Say 'Output to' oufw
     "ALLOC FI(OUFw) DA("oufw") MOD CATALOG REUSE" ,
     "LRECL(130) RECFM(F B) TRACKS SPACE(5,5) RELEASE"
     rec.0=1
     rec.1=Datej Rec.1
     say rec.1
     "EXECIO 1 DISKW OUFw (FINIS STEM rec. "
     "FREE DD(OUFW)"
    return
 
LogWm:
/* Report warning messages , will be sent to Outlook Me */
     oufw = "'" !! hlq !! '.reportsw.' !! 'ALRT' !! "'"
     Say 'Output to' oufw
     "ALLOC FI(OUFw) DA("oufw") MOD CATALOG REUSE" ,
     "LRECL(130) RECFM(F B) TRACKS SPACE(5,5) RELEASE"
     rec.0=1
     rec.1=Datej Rec.1
     say rec.1
     "EXECIO 1 DISKW OUFw (FINIS STEM rec. "
     "FREE DD(OUFW)"
    return
myexite:
     ZISPFRC = 8
     ADDRESS ISPEXEC "VPUT (ZISPFRC)"
     exit 8
DiffRBA:
       SIZ01=X2D(WORD(TAMP,1))     /* rba1 et rba2 */
       SIZ02=X2D(WORD(TAMP,2))
       /* Calcul taille a partir des RBA    */
       SIZACT=TRUNC((SIZ02-SIZ01)/1024/1024,2)
       SIZACTLG=SIZACTLG" "SIZACT
       TOZACTLG=TOZACTLG+SIZACT
   return
ProcessArchLine:
         /*-------------------------------------------------*/
         /* Exemple d'une ligne                             */
         /*   2015.352  12:28:10.7  2015.352  14:11:08.8    */
         /* On est sur la ligne Date                        */
         /*-------------------------------------------------*/
         DateDebutArch=WORD(TAMP,1) /* Date debut */
         DateFinArch=WORD(TAMP,3) /* Date fin */
         HeureDebutArch=WORD(TAMP,2) /* Heure debut */
         HeureFinArch=WORD(TAMP,4) /* Heure fin */ 
         NbArch=NbArch+1     /* compteur nbre archives */
         /* Calcul nbre de secondes Debut a partir de la date */
         NbSecDebut=(ConvertDate2NbDays(DateDebutArch)-1)*24*60*60
         NBSEC=TRANSLATE(HeureDebutArch," ",":")
         NBSEC=TRANSLATE(NBSEC," ",".")
         HENS=WORD(NBSEC,1)*60*60
         MENS=WORD(NBSEC,2)*60
         SENS=WORD(NBSEC,3)
         NBSEC=HENS+MENS+SENS
         NbSecDebut=NbSecDebut+NBSEC
         /* sauvegarde liste des secondes debut */
         LSTSCAR=LSTSCAR" "NbSecDebut
         /* Calcul nbre de secondes Fin   a partir de la date */
         NBSCFN=(ConvertDate2NbDays(DateFinArch)-1)*24*60*60
         NBSEC=TRANSLATE(HeureFinArch," ",":")
         NBSEC=TRANSLATE(NBSEC," ",".")
         HENS=WORD(NBSEC,1)*60*60
         MENS=WORD(NBSEC,2)*60
         SENS=WORD(NBSEC,3)
         NBSEC=HENS+MENS+SENS
         NBSCFN=NBSCFN+NBSEC
         /* on ne retient que les dernieres NbActLog archives */
         /* NbActLog = nbre de log active */
         IF WORDS(LSTSCAR)>NbActLog  THEN
         DO
            PT=WORDINDEX(LSTSCAR,2) /* position du 2ieme mot */
            /* on ne retient que les dernieres NbActLog archives */
            LSTSCAR=SUBSTR(LSTSCAR,PT,LENGTH(LSTSCAR)-PT+1)
         END
         /* Recalcul a partir du nouveau temps archive apres decalage */
         /* Calcul du cycle minimum pour faire le tour des actives */
         IF WORDS(LSTSCAR)=NbActLog THEN
         DO
            NbSecDebut=WORD(LSTSCAR,1)
            NBSEC=NBSCFN-NbSecDebut
            /* si l'archive date plus de  30j */
            IF DEBSCAN>NbSecDebut THEN
               NBLG30J=NbArch
            ELSE
             /* si l'archive date moins de  30j on l'enregistre*/
             /* pour calcul plus tard */
               LSTDBAR=LSTDBAR" "NbSecDebut
            /* calcul Min Max cycle archive */
            IF NBSEC<HMINBSEC & DEBSCAN<NbSecDebut THEN
                          do
                              HMINBSEC=NBSEC
                              DateMinArch=substr(tamp,4,20)
                              call convert_date
                              DateMinArch=DateMinArch 'GMT'
                          end
            IF NBSEC>HMANBSEC & DEBSCAN<NbSecDebut THEN HMANBSEC=NBSEC
         END /* IF WORDS(LSTSCA */
         /* Sauvegarde date premiere archive */
         IF WORDS(LSTSCAR)<NbActLog THEN DO
             IF DateFirstArch="" THEN DateFirstArch=WORD(TAMP,1)" "WORD(TAMP,2)
             NBSEC="WAIT"
         END
return
MyAlarmf:
   /* selection pour eviter trop alarme
   if NDB2= 'DSN6' & (nommsg = 'DSNJ032I' !,
                           nommsg = 'DSNJ033I')  then return
   */
   select
      when zAlertType = 'FIC' then
         do
           zAlertMsg = '-NoFICCatDir'
         end
      when zAlertType = 'DASD' then
         do
           zAlertMsg = '-Cat/DirStgFull'
         end
      otherwise nop
   end
   /* toujours envoyer en parallele sur LogWm*/
   rec.1=LPAR NDB2 zAlertMsg
   call LogWm
   Say 'Call MyAlarm: ' zAlertMsg
   /* Alerte seulement si pas LPAR dev */
   if LPARProd=1  & SendAlarm then
   do
        call MYALARM "CHECKDB2ETAT DB2JOB" LPAR NDB2 zAlertmsg
        SendAlarm=0
   end
   else say 'pas d appel MYALARM pour ' LPAR NDB2
 
return
/*-------------------------------------------------------------*/
/*  Mise en forme date avant appel foncition conversion reelle */
/*-------------------------------------------------------------*/
Convert_date:
   parse var DateMinArch datex DateMinArch
   parse var datex yyyy'.'ddd
   datex=yyyy !!ddd
   datex=DAT_MVS2SD(datex)
   DateMinArch=datex!!DateMinArch
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
If LENGTH(y) = 2 Then y = '20'y
months = '31' (28 + LY?(y)) ,
'31 30 31 30 31 31 30 31 30 31'
Do m = 1 To 12 While j > WORD(months,m)
j = j - WORD(months,m)
End
Return RIGHT(y,4,0) !! RIGHT(m,2,0) !! RIGHT(j,2,0)
/*-------------------------------*/
/* Date function  format attendu */
/*-------------------------------*/
/*   2015.352  12:28:10.7  2015.352  14:11:08.8    */
diff_time: procedure
arg DateDebutArch,HeureDebutArch,DateFinArch,HeureFinArch
         /* Calcul nbre de secondes Debut a partir de la date */
         NbSecDebut=(ConvertDate2NbDays(DateDebutArch)-1)*24*60*60
         NBSEC=TRANSLATE(HeureDebutArch," ",".")
         NBSEC=TRANSLATE(NBSEC," ",".")
         HENS=WORD(NBSEC,1)*60*60
         MENS=WORD(NBSEC,2)*60
         SENS=WORD(NBSEC,3)
         NBSEC=HENS+MENS+SENS
         NbSecDebut=NbSecDebut+NBSEC
         /* Calcul nbre de secondes Fin   a partir de la date */
         NBSCFN=(ConvertDate2NbDays(DateFinArch)-1)*24*60*60
         NBSEC=TRANSLATE(HeureFinArch," ",".")
         NBSEC=TRANSLATE(NBSEC," ",".")
         HENS=WORD(NBSEC,1)*60*60
         MENS=WORD(NBSEC,2)*60
         SENS=WORD(NBSEC,3)
         NBSEC=HENS+MENS+SENS
         NBSCFN=NBSCFN+NBSEC
         diffsec = nbscfn - NbSecDebut
    return  diffsec
Date_Jul: procedure
   arg line
   mymm = word(line,6)
   select
      when mymm = 'JAN' then mymm = '01'
      when mymm = 'FEB' then mymm = '02'
      when mymm = 'MAR' then mymm = '03'
      when mymm = 'APR' then mymm = '04'
      when mymm = 'MAY' then mymm = '05'
      when mymm = 'JUN' then mymm = '06'
      when mymm = 'JUL' then mymm = '07'
      when mymm = 'AUG' then mymm = '08'
      when mymm = 'SEP' then mymm = '09'
      when mymm = 'OCT' then mymm = '10'
      when mymm = 'NOV' then mymm = '11'
      when mymm = 'DEC' then mymm = '12'
      otherwise nop
   end
   DatGrg= word(line,7) !! mymm !! word(line,5)
   ddd = Date('D',DatGrg,'S')
   DatJul  = Substr(DatGrg,1,4)'.'ddd
   return DatJul
AddZero: procedure
   arg datexx /* date dd  sur 1 car => ajout 0 :  1 => 01 */
   ddx = word(datexx,1)
   if length(ddx) = 1 then ddx = '0'ddx
   datexx = ddx word(datexx,2) word(datexx,3)
   return(datexx)
 
/* Test relance Hors IPL */
TestRelanceHorsIPL: Procedure expose diplsav
    arg datipl,datsta,datej /* format datsta 19 DEC 2017 21.07.16*/
    /* datej 12 NOV 2017 */
    /* Test seulement si récent */
    /* format datej 22 DEC 2017 */
    ddx=word(datsta,1) /* date start dd */
    mmx=word(datsta,2) /* date start mm */
    hhx=SUBSTR(datsta,13,2)
    ddy=word(datej,1) /* date jour dd */
    mmy=word(datej,2) /* date jour  mm */
    /* si le db2 vient de restarter */
    if (ddx = ddy ! (ddy - ddx = 1 & hhx >= 6)) & mmx = mmy then nop
           else return(0)
 
    /* RECUPERE LA DATE D'IPL ET LA FORMAT EN NUM YYYYMMDD  */
    dipx=SUBSTR(WORD(datipl,1),7,4)!!SUBSTR(WORD(datipl,1),1,2)!!,
        SUBSTR(WORD(datipl,1),4,2)
    diplsav  = dipx       /* save de ce format yyyymmdd */
    dipx=DATE('B',dipx,'S');dipx=dipx*1000
    /* RECUPERE L'HEURE D'IPL ET LA FORMAT EN NUM SUR 000 */
    TIMXH=SUBSTR(WORD(datipl,2),1,2)                       /* HEURE   */
    TIMXM=SUBSTR(WORD(datipl,2),4,2)                       /* MINUTE  */
    TIMXS=SUBSTR(WORD(datipl,2),6,2)                       /* SECONDE */
    TIMX=((((TIMXH*60)+TIMXM)*60)+TIMXS)*999/86399         /* SUR 000 */
    dipx=TRUNC(dipx+TIMX) /* DATE D'IPL SUR XXXXXX000 + TIME SUR 000  */
    VARM="JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC" /* VAR MOIS*/
 
    /* RECUPERE LA DATE DE START AU FORMAT EN NUM XXXXXX000  */
    STJ=RIGHT(WORD(datsta,1),2,"0")                        /* JOUR    */
    STM=RIGHT(WORDPOS(WORD(datsta,2),VARM),2,"0")          /* MOIS    */
    STA=WORD(datsta,3)                                     /* ANNEE   */
    DSTX=DATE('B',STA!!STM!!STJ,'S');DSTX=DSTX*1000        /* AVEC 000*/
    /* RECUPERE L'HEURE DE START AU FORMAT EN NUM 000  */
    STTH=SUBSTR(WORD(datsta,4),1,2)                        /* HEURE   */
    STTM=SUBSTR(WORD(datsta,4),4,2)                        /* MINUTE  */
    STTS=SUBSTR(WORD(datsta,4),6,2)                        /* SECONDE */
    TSTX=((((STTH*60)+STTM)*60)+STTS)*999/86399            /* SUR 000 */
    DSTX=TRUNC(DSTX+TSTX)  /* DATE DE START SUR XXXXXX000+TIME SUR 000*/
 
    DNOW=DATE('B');DNOW=DNOW*1000      /* DATE ACTUELLE SUR XXXXXX000 */
    DateAAJJJ=TIME('S'); DateAAJJJ=DateAAJJJ*999/86399      /* TIME ACTUELLE SUR
000 */
    DNOW=TRUNC(DNOW+DateAAJJJ)    /* DATE ACTUELLE SUR XXXXXX000+TIME SUR00*/
    IF ((DSTX-DipX)>42 & (DNOW-DSTX)<2056) THEN return(-1)
    else return(1)
ProcessGBPCmd:
    k=1
    ErrorGBP=0
    /* Search for Cross Invalidation due to Directory reclaim */
    DO while k <=  TP.0
       select
            /*display une seule fois date statistics incremental*/
            when word(tp.k,1)='DSNB782I' & k < 52 then
                 do
                    say tp.k
                    k=k+1
                    say tp.k
                 end
            when word(tp.k,1)='DSNB750I' then
                             gbpname=word(tp.k,8)
            when word(tp.k,1)  = 'DSNB785I' then
                 do
                   k=k+2     /* saut de 2 lignes */
                   /* DIRECTORY ENTRY CREATED */
                   DirEntCre= word(tp.k,5)
                   k=k+1     /* ligne suivante */
                   /* DIRECTORY ENTRY NOT CREATED     = 1567482, 0 */
                   DirEntNotCre= word(tp.k,7)
                   if DirEntNotCre> 0 then do
                      say tp.k
                      rec.1='SNPP 'gbpname' Directory not ',
                         !! 'created:' DirEntNotCre
                      ErrorGBP=1
                      call LogWm
                   end
                 end
            When word(tp.k,1) = 'DSNB786I' then
                 do
                   k=k+3
                   /* FAILED DUE TO LACK OF STORAGE           = 0 */
                   FailNoStor = word(tp.k,8)
                   if FailNoStor >  0 then do
                      /* format datsta 19 DEC 2017 21.07.16*/
                      /* format datej 22 DEC 2017 */
                      dd1=substr(datsta,1,2)
                      dd2=substr(datej,1,2)
                      mm1=substr(datsta,4,3)
                      mm2=substr(datej,4,3)
                      /* fausse alerte si premiere commande apres*/
                      /* redemarrage */
                      if mm1=mm2 & dd2-dd1 > 1 then iterate
                      say tp.k
                      rec.1='SNPP 'gbpname' Write failed NoStor',
                         !! 'age:'  FailNoStor
                      ErrorGBP=1
                      call LogWm
                   end
                 end
            when word(tp.k,1)='DSNB788I' then
                do
                   l=k
                   k=k+1
                   NbXIDirReclaim = word(tp.k,6)
                   if NbXIDirReclaim >  0 then do
                      say tp.l
                      say tp.k
                      rec.1='SNPP 'gbpname' XI due to Directory',
                      ' reclaim :' NbXIDirReclaim
                      ErrorGBP=1
                      call LogWm
                   end
                end
            otherwise nop
       end  /* end select */
       k=k+1
    END
    if ErrorGBP = 1 then do
    /* report the GBP command output */
        k=1
        oufw = "'" !! hlq !! '.reportsw.' !! 'ALRT' !! "'"
        "ALLOC FI(OUFw) DA("oufw") MOD CATALOG REUSE" ,
        "LRECL(130) RECFM(F B) TRACKS SPACE(5,5) RELEASE"
        "EXECIO * DISKW OUFw (FINIS STEM tp. "
        "FREE DD(OUFW)"
        say ''
        say '-DISPLAY GBPOOL GDETAIL follows : '
        /* Search for Cross Invalidation due to Directory reclaim */
        DO while k <=  TP.0
             say tp.k
             k=k+1
        end
    end
return
ProcessDTrace:
    OldTNO = word(tp.1,1)
    nblines = 1
    k=2
    /* Search Long Trace  */
    DO while k <=  TP.0
       /* detect IFCID 376 trace */
       if word(tp.k,2) = 'PERFM' &,
          word(tp.k,6) = '376' &,
          word(tp.k,4) = 'SMF'
          then IFC376Seen=1
       /* detect MVW Detailed trace */
       if word(tp.k,1) = OldTNO then
       do
         nblines=nblines+1
         if nblines > 3 then
         do
             rec.1=LPAR'/'NDB2,
                  'Detailed trace pasts day - Performance impact !!!'
             call LogWm
             k=TP.0
         end
       end
       else
       do
         OldTNO = word(tp.k,1)
         nblines = 1
       end
       k=k+1
    end
return
DOSQL:
  DROP SQL. SQLC. J CPTSQL
  CPTSQL=1
  SQLC.CPTSQL="QUERY D'EXTRACTION DES OBJETS SANS IC POUR "NDB2
  CPTSQL=2
  SQLC.CPTSQL="DBNAME/SPNAME/PARTITION/QUERY#(VOIR CMDCATXX)"
  X=OUTTRAP(SQL.)
  CALL CMDCATXX NDB2
  X=OUTTRAP(OFF)
  DO J=1 TO SQL.0
   CPTSQL=CPTSQL+1
   say sql.j
   SQLC.CPTSQL=SQL.J
  END
  /* ecriture membre SQL */
  SQLCATD=SQLCATR!!NDB2!!")"
  SQLC.0=cptsql
  SAY "ECRITURE : "SQLCATD" "CPTSQL" RECORDS"
  /* positionner alerte pour absence image copy */
  say 'day=' substr(Date('W', Date('U'), 'U'),1,3)
  if cptsql  > 2 then
            do
          /*   if client = 'CAAGIS' &, */
               if lparprod=0 &,
                 substr(Date('W', Date('U'), 'U'),1,3) <> 'Fri' ,
                 then say 'NoFICCatDir detected but no alert'
               else do
                 zAlertType = 'FIC'
                 call MyAlarmf
               end
            end
  ADDRESS TSO "ALLOC DD(FILE) DS('"SQLCATD"') SHR"
  ADDRESS TSO "EXECIO * DISKW FILE (STEM SQLC. FINIS "
  ADDRESS TSO "FREE DDNAME(FILE)"
  DROP SQL. SQLC. J CPTSQL
  /*******************/
  /* Requete SQL RBA1*/
  /*******************/
  DROP SQL. SQLC. J CPTSQL
  CPTSQL=1
  SQLC.CPTSQL="QUERY RBA EXTENDED 1"NDB2
  CPTSQL=2
  SQLC.CPTSQL="COUNT NOT EXTENDED(VOIR CMDRBA1)"
  X=OUTTRAP(SQL.)
  CALL CMDRBA1  NDB2
  X=OUTTRAP(OFF)
  DO J=1 TO SQL.0
   CPTSQL=CPTSQL+1
   SQLC.CPTSQL=SQL.J
  END
  /* ecriture membre SQL */
  SQLCATD=RBA1!!NDB2!!")"
  SQLC.0=cptsql
  SAY "ECRITURE : "SQLCATD" "CPTSQL" RECORDS"
  /* positionner alerte pour Xtd RBA */
  parse var sql.1   cac cac1
  cac1 = substr(HRBAWRIT,9,2)
  /* Alerte extented  RBA tablespace */
  if cac > 0 & cac1 = 'FB' & LPAR <> 'XX10' then
      do
             WaitAlerte=0
             rec.1='Alerte:' LPAR,
                   NDB2 'TS not RBA Extended :' cac
             call LogWm
       end
  ADDRESS TSO "ALLOC DD(FILE) DS('"SQLCATD"') SHR"
  ADDRESS TSO "EXECIO * DISKW FILE (STEM SQLC. FINIS "
  ADDRESS TSO "FREE DDNAME(FILE)"
  DROP SQL. SQLC. J CPTSQL
  /********************/
  /* Requete SQL RBA2 */
  /********************/
  DROP SQL. SQLC. J CPTSQL
  CPTSQL=1
  SQLC.CPTSQL="QUERY RBA EXTENDED 2"NDB2
  CPTSQL=2
  SQLC.CPTSQL="COUNT NOT EXTENDED(VOIR CMDRBA2)"
  X=OUTTRAP(SQL.)
  CALL CMDRBA2  NDB2
  X=OUTTRAP(OFF)
  DO J=1 TO SQL.0
   CPTSQL=CPTSQL+1
   SQLC.CPTSQL=SQL.J
  END
  /* ecriture membre SQL */
  SQLCATD=RBA2!!NDB2!!")"
  SQLC.0=cptsql
  SAY "ECRITURE : "SQLCATD" "CPTSQL" RECORDS"
  /* Alerte Extended RBA index */
  parse var sql.1   cac cac1
  cac1 = substr(HRBAWRIT,9,2)
  if cac > 0 & cac1 = 'FB' & LPAR <> 'XX10' then
       do
             WaitAlerte=0
             rec.1='Alerte:' LPAR,
                   NDB2 'IX not RBA Extended :' cac
             call LogWm
       end
  ADDRESS TSO "ALLOC DD(FILE) DS('"SQLCATD"') SHR"
  ADDRESS TSO "EXECIO * DISKW FILE (STEM SQLC. FINIS "
  ADDRESS TSO "FREE DDNAME(FILE)"
  DROP SQL. SQLC. J CPTSQL
  /*************************/
  /* Fin de la requete RBA2*/
  /*************************/
  return
Erly: procedure expose LstDB2
/* Rexx -------------------------------------------------------------*/
/*                                                                   */
/* DB2SSIDS                                                          */
/* ========                                                          */
/* Return the status of all DB2 subsystems defined on this LPAR.     */
/*                                                                   */
/* Parms  : None                                                     */
/*                                                                   */
/* Output : A line for each subsystem that is defined on the LPAR of */
/*          the following form:                                      */
/*                                                                   */
/*               ssid { ACTIVE }                                     */
/*                                                                   */
/*          i.e. each subsystem is listed and is flagged as ACTIVE   */
/*          if running.                                              */
/*                                                                   */
/*-------------------------------------------------------------------*/
/*                                                                   */
/* James Gill - November 2014                                        */
/*                                                                   */
/*-------------------------------------------------------------------*/
   numeric digits 20
 
   psa         = 0     /* psa absolute address                       */
   psa_cvt     = 16    /* psa->cvt ptr offset                        */
   cvt_jesct   = 296   /* cvt->jesct ptr offset                      */
   jesct_sscvt = 24    /* jesct->sscvt ptr offset                    */
   sscvt_sscvt = 4     /* sscvt->next sscvt ptr offset               */
   sscvt_ssid  = 8     /* sscvt subsystem id offset                  */
   sscvt_ssvt  = 16    /* sscvt->ssvt                                */
   sscvt_suse  = 20    /* subsystem user field (->ERLY)              */
   sscvt_syn   = 24    /* has table synonym pointer                  */
   sscvt_sus2  = 28    /* subsystem user field                       */
   sscvt_eyec  = 0     /* sscvt eyecatcher offset                    */
   erly_id   = 0       /* ERLY block identifier ( = x'A5')           */
   erly_size = 2       /* ERLY block size (= x'A8')                  */
   erly_eyec = 4       /* ERLY block eyecatcher                      */
   erly_ssid = 8       /* DB2 subsystem id                           */
   erly_mstr = 12      /* MSTR STC name                              */
   erly_pclx = 20      /* PC LX value                                */
   erly_ssvt = 34      /* ptr back to SSVT                           */
   erly_ssgp = 38      /* ptr to DSN3SSGP (= 0 is subsystem is down) */
   erly_scom = 56      /* ptr to SCOM (subsys communication block)   */
   erly_modn = 84      /* DSN3EPX                                    */
 
   cvt   = c2d(storage(d2x(psa + psa_cvt),4))
   jesct = c2d(storage(d2x(cvt + cvt_jesct),4))
   sscvt = c2d(storage(d2x(jesct + jesct_sscvt),4))
   do while sscvt /= 0
      subsystem = storage(d2x(sscvt + sscvt_ssid),4)
      ssctssvt = c2d(storage(d2x(sscvt + sscvt_ssvt),4))
      ssctsuse = c2d(storage(d2x(sscvt + sscvt_suse),4))
      ssctsyn  = c2d(storage(d2x(sscvt + sscvt_syn),4))
      ssctsus2 = c2d(storage(d2x(sscvt + sscvt_sus2),4))
      if ssctsuse /= 0 then do   /* pointing to ERLY? */
         erly = ssctsuse
         erlyid = c2x(storage(d2x(erly + erly_id),2))
         if erlyid = "00A5" then do  /* id = ERLY */
            erlysize = c2d(storage(d2x(erly + erly_size),2))
            /* say  storage(d2x(erly),100) */
            erlyeyec = storage(d2x(erly + erly_eyec),4)
            if erlyeyec = "ERLY" then do  /* eyecatcher = ERLY */
               modn = strip(storage(d2x(erly + erly_modn),8))
               if modn = "DSN3EPX" then do
                  scom = c2d(storage(d2x(erly + erly_scom),4))
                  /* concatenate active subsystem */
                  if scom <> 0 then LstDB2=LstDB2 subsystem
               end
           end
         end
      end
      sscvt = c2d(storage(d2x(sscvt + sscvt_sscvt),4))
   end
return(0)
 
ProcessSubsysLogs:
  /********************/
  /* Read sysout MSTR */
  /********************/
  /* lecture sysout MSTR */
      /*  if LPAR = 'TEC' then call sdsfmanu
          else */
  call  sdsf NDB2"MSTR PRINT"
  /* Si Full on retente en sautant les 1M lignes */
  rt=0
  do 3
    if mstr_full then
        do
           rt=rt+1
           call  sdsf NDB2"MSTR SKIP"
        end
  end
 
  DATSTA=""; DSBSDS1="";
  DSBSDS2=""; SDSNEXIT=""; PROCLIB=""; ZPARM=""; CMDPRF=""; USERDB2="";
  GRPDB2=""; MODE  =""; CPTENV=0; DataSharingMode=""; DTSHRLT=""; DTSHRGP="";
  IF SDF.0 > 2 then
            call mstr_ok
  ELSE DO
       CPTLOG=CPTLOG+1;
       LOG.CPTLOG="LECTURE DE LA SYSOUT "NDB2"MSTR IMPOSSIBLE"
       SAY TIME()" "LOG.CPTLOG
       if sdf.0 > 200 then j=200
                      else j=sdf.0
       do i=1 to j
            say sdf.i
       end
  END
  drop sdf.
  TAB.ADSN_SSID.17=DSBSDS1
  TAB.ADSN_SSID.18=DSBSDS2
  TAB.ADSN_SSID.19=SDSNEXIT
  TAB.ADSN_SSID.20=PROCLIB
  TAB.ADSN_SSID.21=ZPARM
  TAB.ADSN_SSID.22=USERDB2
  TAB.ADSN_SSID.23=GRPDB2
  TAB.ADSN_SSID.24=MODEV8
  TAB.ADSN_SSID.25=DATSTA
  TAB.ADSN_SSID.26=MaxArcDur MaxArcDate MaxArcTime
  TAB.ADSN_SSID.30=DataSharingMode
  TAB.ADSN_SSID.31=DTSHRLT
  TAB.ADSN_SSID.32=DTSHRGP
  /* Traitement jcl de DBM1     */
  /* pour traquer usage de TICTOC */
  say 'APPEL  SDSFREXX POUR LECTURE SYSOUT DU DB2DBM1.'
  call sdsf NDB2"DBM1 PRINT"
  IF SDF.0>2 THEN DO
            call dbm1_ok
  END
  ELSE DO
       CPTLOG=CPTLOG+1;
       LOG.CPTLOG="LECTURE DE LA SYSOUT "NDB2"DBM1 IMPOSSIBLE"
       SAY TIME()" "LOG.CPTLOG
  END
  TAB.ADSN_SSID.16=TICTOC
  drop sdf.
  /* Traitement jcl de IRLM     */
  /* pour reporter paramètre IRLM */
  say 'APPEL  SDSFREXX POUR LECTURE SYSOUT DU DB2IRLM.'
  call sdsf IrlmName PRINT
  IF SDF.0>2 THEN DO
            call irlm_ok
  END
  ELSE DO
       CPTLOG=CPTLOG+1;
       LOG.CPTLOG="LECTURE DE LA SYSOUT "NDB2"IRLM IMPOSSIBLE"
       SAY TIME()" "LOG.CPTLOG
  END
  TAB.ADSN_SSID.28=DEADLOK
  drop sdf.
return

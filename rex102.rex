/*Rexx*/
numeric digits 15
/*-------------------------------------------------------------*/
/* Extract smf 102 records - written by Nguyen Duc Tuan        */
/*                                      ndt.db2@gmail.com      */
/* These IFCIDs are available only in Performance trace        */
/*   4 may 2016     Release 1.0                                */
/*  12 Aug 2016     Release 2.0 Process SQL Stmt               */
/*  29 Nov 2016     Release 2.1 Process IFCID 366              */
/*  13 Apr 2017     Release 2.2 Process IFCID 376 & update 366 */
/*                  IFCID376 is just an aggregated version of  */
/*                  IFCID366 , the mapping is identical        */
/*  19 Apr 2018     Release 2.5 Dataset Extend IFCID 258       */
/*  16 Oct 2018     Release 2.6 EDM request    IFCID 030       */
/*  27 Mar 2019     IFCID 361 Audit Admin activities           */
/*  01 Oct 2019     Remove IFCID366 and changes 376            */
/*  30 Dec 2019     Bind & Autobind with IFCID 108 109         */
/*-------------------------------------------------------------*/
/*-------------------------------------------------------------*/
/*Comment : Change datasets high level identifier              */
/*Notes : Ifcid 63 (sql text) is available only for dynamic sql*/
/*        (Spufi or Rexx for example)                          */
/*        For static SQL, there is no ifcid 350 or 63 produced */
/*        it seems that for static SQL, stmtno is provided and */
/*        we have to go to syspackstmt to get the SQL text     */
/*        Ifcid 53 is the ifcid to get sqlcode                 */
/*        Ifcid 58 is produced only for dynamic SQL (DESCRIBE) */
/*-------------------------------------------------------------*/
ARG  modex   /*PROCESS THIS DB2 SUBSYS ONLY */
 
db2_cmd='N'       /* process ifcid 090 DB2 cmd ? */
/* -STA TRACE(PERFM) DEST(SMF) CLASS(30) IFCID(90) */
Bind      ='N'    /* process ifcid 108/109 : Bind operations ? */
/* -STA TRACE(PERFM) DEST(SMF) CLASS(30) IFCID(108,109) */
/* */
/* MINIMUM FOR STATEMENT CACHE DYN IS : */
/* -STA TRA(P) DEST(SMF) C(30) IFCID(316,318) FOR DYN. SQL */
/* IFCID 317 : LONG SQL TEXT BUT READS ONLY */
/* IFCID 318 IS A SWITCH ON IFCID */
/* MINIMUM FOR STATEMENT CACHE STATIC : */
/* -STA TRA(P) DEST(SMF) C(30) IFCID(400,401) FOR STATIC SQL */
/* IFCID 400 IS A SWITCH ON IFCID */
Stmt_cache='N'  /* process stmt_cache ? IFCID 316,317,318,400,401 */
sql_text  ='N'    /* process Sql statement IFCID 63,64,247  */
/* Ifcid 53 and 58 is for sqlca (in particular sqlcode) */
/* -STA TRACE(PERFM) DEST(SMF) CLASS(30) IFCID(63,64,247,53,58)*/
IFC361='N'        /* process ifcid 361 Audit Administrators actions */
IFC376='N'        /* process ifcid 376 Unsupported fonctions    */
IFC224='N'        /* process ifcid 224 invalids Sproc */
IFC342='N'        /* process ifcid 342 workfile usage */
IFC063='N'        /* process ifcid 063 SQL Text       */
EDM   ='N'        /* process ifcid 030 EDM requests   */
DsExt ='N'        /* Data Set Extend IFCID 258        */
IFC021='N'        /* Locks IFCID 021       */
IFC029='N'        /* Snapshot PT CT DBD    */
IFC314='N'        /* Trace RACF Exit       */
select
    when modex = 'CMD'    then db2_cmd='Y'
    when modex = 'XTD'    then DSExt='Y'
    when modex = 'BIND'   then Bind='Y'
    when modex = 'STMTC'  then Stmt_cache='Y'
    when modex = 'SQLTXT' then sql_text='Y'
    when modex = 'IFC063' then IFC063='Y'
    when modex = 'IFC314' then IFC314='Y'
    when modex = 'IFC376' then IFC376='Y'
    when modex = 'IFC224' then IFC224='Y'
    when modex = 'IFC342' then IFC342='Y'
    when modex = 'IFC361' then IFC361='Y'
    when modex = 'EDM' then EDM='Y'
    when modex = 'IFC021' then IFC021='Y'
    when modex = 'IFC029' then IFC029='Y'
    otherwise  do
         say 'Missing or wrong argument :' modex
         exit 8
       end
end /* end select */
say ' '
say 'Processing for SMF102 - All subsystems'
 
repSQL = 'N'
if stmt_cache = 'Y' ! sql_text = 'Y' then repSQL = 'Y'
 
/* init compteurs divers */
call init_var
 
/* START PROCESSING */
DO FOREVER
  /* read SMF record one by one   */
  "EXECIO 1 DISKR INP"
  IF RC > 0 THEN DO
            if rc =  2 then
             do
              SAY ''
              SAY 'End of input SMF file rc=' RC
              rcalloc = rc
             end
             else do
              SAY ''
              SAY 'Error while reading SMF file rc=' RC
              rcalloc = 8
             end
              leave
            END
  PARSE PULL InpRec
  reci=reci+1
  OFFSET = 1
  /* Decode SMF header */
  CALL DSNDQWST
  /* record SMF records period   */
  if min_time > run_fmt_time then min_time=run_fmt_time
  if max_time < run_fmt_time then max_time=run_fmt_time
 
  /* process only smf102 */
  IF (sm102RTY = 102    ) THEN
  DO
    recs=recs+1
    /*sauvegarde offset_self car on le reutilise */
    offset_selfdef= offset
    /* Get   pointer to product section */
    offset = C2D(SUBSTR(InpRec,OFFSET,4))
      temp   = offset_selfdef+4
      prod_len = C2D(SUBSTR(InpRec,temp,2))
      temp=temp+2
      prod_rep = C2D(SUBSTR(InpRec,temp,2))
    offset = offset - 4 + 1
    /* Process product section*/
    Call DSNDQWHS
    offset=offset_selfdef
    /* record all ifcid in smf for analysis : unexploited data ? */
    call record_ifcid
 
    if temA =0 then do
       temA=1
       hlq= 'SYSTMP.WSYNGUD.'sm102sid
       call alloc_file
       CALL write_header
    end
    Select
         When ifcid     = 53 & sql_text = 'Y' then
                            Do
                                say 'process IFCID 53'
                                /* SQLCA most used */
                                CALL QW0058
                                OFFSET = offset_save
                            end
         When ifcid     = 58 & sql_text = 'Y' then
                            Do
                                say 'process IFCID 58'
                                /* SQLCA     */
                                CALL QW0058
                                OFFSET = offset_save
                            end
         When ifcid     = 63 & ,
              ( IFC063 = 'Y' ! sql_text = 'Y') then
                            Do
                                say 'process IFCID 63'
                                /* SQL stmt - dynamic SQL */
                                CALL QW0063
                                OFFSET = offset_save
                            end
         When ifcid     = 247 & sql_text = 'Y' then
                            Do
                                say 'process IFCID 247'
                                /* Host Var  */
                                CALL QW0247
                                OFFSET = offset_save
                            end
         When ifcid     = 350 & sql_text = 'Y' then
                            Do
                                /* Long sql text - dynamic */
                                CALL QW0350
                                OFFSET = offset_save
                            end
         When ifcid     = 361 & IFC361 = 'Y'   then
                            Do
                                /* get authid and the rest */
                                call DSNDQWHC offset_corr
                                offset_dist=offset_corr + QWHCLEN
                                call DSNDQWHD offset_dist
                                /* Audit trace class 11 Admin*/
                                CALL QW0361
                                call Write_IFC361
                                OFFSET = offset_save
                            end
         When ifcid     =  21 & IFC021   = 'Y' then
                            Do
                                /* Locks details */
                                CALL QW0021
                                call Write_IFC021
                                OFFSET = offset_save
                            end
         When ifcid     =  29 & IFC029   = 'Y' then
                            Do
                                /* EDMPool CT PT snapshot */
                                CALL QW0029
                            /*  call Write_IFC029 */
                                OFFSET = offset_save
                            end
         When ifcid     = 30  & EDM      = 'Y' then
                            Do
                                /* End of EDM request */
                                CALL QW0030
                                call Write_IFC030
                                OFFSET = offset_save
                            end
         When ifcid     = 31  & EDM      = 'Y' then
                            Do
                                /* End of EDM request */
                                CALL QW0031
                                call Write_IFC030
                                OFFSET = offset_save
                            end
         When ifcid     = 376 & IFC376   = 'Y' then
                            Do
                                /* Incompatible functions usage */
                                CALL QW0376
                                /* get authid and the rest */
                                call DSNDQWHC offset_corr
                                call Write_IFC376
                                OFFSET = offset_save
                            end
         When ifcid     = 224 & IFC224   = 'Y' then
                            Do
                                /* Invalid SProc  */
                                CALL QW0224
                                call Write_IFC224
                                OFFSET = offset_save
                            end
         When ifcid     = 90 & db2_cmd = 'Y' then
                            Do
                                /* get command text */
                                CALL QW0090
                                /* get authid and the rest */
                                call DSNDQWHC offset_corr
                                /*write report */
                                call Write_REPCMD
                                OFFSET = offset_save
                            end
         When ifcid     = 258 & DsExt    = 'Y' then
                            Do
                                /* Data Set Extend */
                                CALL QW0258
                                call Write_REPExt
                                OFFSET = offset_save
                            end
         When ifcid     = 108 & Bind = 'Y' then
                            Do
                                /* get Bind details */
                                CALL QW0108
                                /* get authid and the rest */
                                call DSNDQWHC  offset_corr
                                /*write report */
                                call Write_REPBnd
                                OFFSET = offset_save
                            end
         When ifcid     = 109 & Bind = 'Y' then
                            Do
                                /* get Bind Return code */
                                CALL QW0109
                                /* get authid and the rest */
                                call DSNDQWHC offset_corr
                                /*write report */
                                call Write_REPBNDRC
                                OFFSET = offset_save
                            end
         When ifcid     = 314 & IFC314 = 'Y' then
                            Do
                                /* RACF Exit */
                                CALL QW0314
                                /* get authid and the rest */
                                call DSNDQWHC  offset_corr
                                /*write report */
                                call Write_IFC314
                                OFFSET = offset_save
                            end
         When ifcid     = 316 & stmt_cache = 'Y' then
                            Do
                                /* get dynamic SQL stats*/
                                CALL init_sql
                                CALL QW0316
                                /*write report */
                                call WriRepSQL
                                OFFSET = offset_save
                            end
         When ifcid     = 317 & stmt_cache = 'Y' then
                            Do
                                /* get dynamic SQL text */
                                CALL QW0317
                                /*write report */
                                call WriRepSQLTxt
                                OFFSET = offset_save
                            end
         When ifcid     = 342 & IFC342   = 'Y' then
                            Do
                                /* get workfile usage  stats*/
                                CALL QW0342
                                /*write report */
                                call write_IFC342
                                OFFSET = offset_save
                            end
         When ifcid     = 401 & stmt_cache = 'Y' then
                            Do
                                /* get static SQL stats*/
                                CALL init_sql
                                CALL QW0401
                                /*write report */
                                call WriRepSQL
                                OFFSET = offset_save
                            end
         otherwise
                do
                     nop
                  /* say 'ifcid' ifcid 'not processed' */
                end
    end   /* select */
 
  END /*    IF SM102RTY = 102  */
END
call close_all
 
say "Input records =" reci
say "Output records=" reco
say 'SMF period : ' min_time "/" max_time
 
call report_ifcid
/*-------------------------------------------------*/
/* F20 End of program display counters and figures */
/*-------------------------------------------------*/
 
EXIT rcalloc
 
/*---------------------------------------*/
/* End of program body- Routines section */
/*---------------------------------------*/
 
 
QW0090:
numeric digits 15
       offset_save=offset
       /* offset= offset of self definition section*/
       /* offset= offset + 8 : bypass pointer to Product  Section*/
       /* Pointer 4 bytes + Len 2 bytes + Repeat factor 2 bytes  */
       offset=offset+4+2+2 /*pointer to data section 1*/
       /*take the contents pointed by the offset */
       offset_d= C2D(SUBSTR(InpRec,OFFSET,4))
       offset_d=offset_d -4+1
       /*offset_d points to the IFCID 090 data to process */
       offset = offset +4
       len     = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       repeat  = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       QW0090LN =c2d(SUBSTR(InpRec,OFFSET_d,2))
       offset_d = offset_d +2
       QW0090CT = SUBSTR(InpRec,OFFSET_d,qw0090ln-2)
  return
QW0021:
/* Locks details*/
       offset_save=offset
       /* offset= offset of self definition section*/
       /* offset= offset + 8 : bypass pointer to Product  Section*/
       /* Pointer 4 bytes + Len 2 bytes + Repeat factor 2 bytes  */
       offset=offset+4+2+2 /*pointer to data section 1*/
       /*take the contents pointed by the offset */
       offset_d= C2D(SUBSTR(InpRec,OFFSET,4))
       offset_d=offset_d -4+1
       /*offset_d points to the IFCID 021 data to process */
       offset = offset +4
       len     = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       repeat  = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       /* Beginning QW0021        */
       offset = offset +2
       QW0258DS =SUBSTR(InpRec,OFFSET_d,44)
       parse var QW0258DS dum1 "." dum2 "." dum3 "." ts ".",
               dum4 '.' part
       offset_d = offset_d +44+28
       QW0258PQ =c2d(SUBSTR(InpRec,OFFSET_d,4))
       offset_d = offset_d +4
       QW0258SQ =c2d(SUBSTR(InpRec,OFFSET_d,4))
       offset_d = offset_d +4
       QW0258MS =c2d(SUBSTR(InpRec,OFFSET_d,4))
       offset_d = offset_d +4
       QW0258HB =c2d(SUBSTR(InpRec,OFFSET_d,4))
       offset_d = offset_d +4
       QW0258HA =c2d(SUBSTR(InpRec,OFFSET_d,4))
       offset_d = offset_d +4
  return
QW0029:
/* DBD CT and PT externalisation */
       offset_save=offset
       /* offset= offset of self definition section*/
       /* offset= offset + 8 : bypass pointer to Product  Section*/
       /* Pointer 4 bytes + Len 2 bytes + Repeat factor 2 bytes  */
       offset=offset+4+2+2 /*pointer to data section 1*/
       /*take the contents pointed by the offset */
       offset_d= C2D(SUBSTR(InpRec,OFFSET,4))
       offset_d=offset_d -4+1
       /*offset_d points to the IFCID 021 data to process */
       offset = offset +4
       len     = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       repeat  = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       /* Beginning QW0029        */
       /* Type DB CT or PT */
       say'>>'SUBSTR(InpRec,Offset_d,80)'<<'
       QW0029ID =SUBSTR(InpRec,Offset_d,2 )
       offset_d = offset_d +2
       select
         when  QW0029ID = 'DB' then
           do
             /* DBID */
             QW0029DB =c2d(SUBSTR(InpRec,OFFSET_d,2))
             say 'DBID=' QW0029DB
           end
         when  QW0029ID = 'CT' then
           do
             /* Plan */
             QW0029PL =SUBSTR(InpRec,OFFSET_d,8)
             say 'Plan=' QW0029PL
           end
         when  QW0029ID = 'PT' then
           do
             /* Location name */
             QW0029LN =strip(SUBSTR(InpRec,OFFSET_d,16))
             offset_d = offset_d +18
             /* Collid        */
             QW0029CI =strip(SUBSTR(InpRec,OFFSET_d,18))
             offset_d = offset_d +18
             /* Package ID    */
             QW0029PI =strip(SUBSTR(InpRec,OFFSET_d,18))
             offset_d = offset_d +18
             /* Consistency Token */
             QW0029CT =SUBSTR(InpRec,OFFSET_d,8)
             say 'Pack='QW0029LN'.'QW0029CI'.'QW0029PI'.'QW0029CT
           end
           otherwise
       end
  return
QW0258:
/* Dataset extend */
       offset_save=offset
       /* offset= offset of self definition section*/
       /* offset= offset + 8 : bypass pointer to Product  Section*/
       /* Pointer 4 bytes + Len 2 bytes + Repeat factor 2 bytes  */
       offset=offset+4+2+2 /*pointer to data section 1*/
       /*take the contents pointed by the offset */
       offset_d= C2D(SUBSTR(InpRec,OFFSET,4))
       offset_d=offset_d -4+1
       /*offset_d points to the IFCID 258 data to process */
       offset = offset +4
       len     = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       repeat  = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       /* Dataset name            */
       QW0258DS =SUBSTR(InpRec,OFFSET_d,44)
       parse var QW0258DS dum1 "." dum2 "." dum3 "." ts ".",
               dum4 '.' part
       offset_d = offset_d +44+28
       QW0258PQ =c2d(SUBSTR(InpRec,OFFSET_d,4))
       offset_d = offset_d +4
       QW0258SQ =c2d(SUBSTR(InpRec,OFFSET_d,4))
       offset_d = offset_d +4
       QW0258MS =c2d(SUBSTR(InpRec,OFFSET_d,4))
       offset_d = offset_d +4
       QW0258HB =c2d(SUBSTR(InpRec,OFFSET_d,4))
       offset_d = offset_d +4
       QW0258HA =c2d(SUBSTR(InpRec,OFFSET_d,4))
       offset_d = offset_d +4
  return
QW0030:
       offset_save=offset
       /* offset= offset of self definition section*/
       /* offset= offset + 8 : bypass pointer to Product  Section*/
       /* Pointer 4 bytes + Len 2 bytes + Repeat factor 2 bytes  */
       offset=offset+8     /*pointer to data section 1*/
       /*take the contents pointed by the offset */
       offset_d= C2D(SUBSTR(InpRec,OFFSET,4))
       offset_d=offset_d -3
       /*offset_d points to the IFCID 030 data to process */
       offset = offset +4
       len     = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       repeat  = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       /* Init */
       QW0030DB=0
       QW0030DC=0
       QW0030PL=''
       QW0030CC=0
       QW0030LN=''
       QW0030CI=''
       QW0030PI=''
       QW0030CT=''
       QW0030GC=0
       /* Begin specific processing for IFCID */
       /* Type EDM :DB=DBDID, CT = Cursor table, PT=Pack table */
       QW0030ID =SUBSTR(InpRec,OFFSET_d,2)
       offset_d = offset_d +2
       Select
            when QW0030ID = 'DB' then
            do
              QW0030DB =c2d(SUBSTR(InpRec,OFFSET_d,2))
              /* because we process also 31 here */
              offset_d = offset_d +2
              QW0030DC =c2d(SUBSTR(InpRec,OFFSET_d,4))
            end
            when QW0030ID = 'CT' then
            do
              QW0030PL =SUBSTR(InpRec,OFFSET_d,8)
              offset_d = offset_d +8+4+2
              QW0030CC =c2d(SUBSTR(InpRec,OFFSET_d,4))
            end
            when  QW0030ID = 'PT' then
            do
              QW0030LN =SUBSTR(InpRec,OFFSET_d,16)
              offset_d = offset_d +18
              if substr(QW0030LN,1,1) = '00'x
                then QW0030LN=''
                else QW0030LN=strip(QW0030LN)
              QW0030CI =SUBSTR(InpRec,OFFSET_d,18)
              offset_d = offset_d +18
              QW0030CI =strip(QW0030CI)
              QW0030PI =SUBSTR(InpRec,OFFSET_d,18)
              offset_d = offset_d +18
              QW0030PI =strip(QW0030PI)
              QW0030CT =c2x(SUBSTR(InpRec,OFFSET_d,8))
              offset_d = offset_d +8+2+8+2
              QW0030GC =c2d(SUBSTR(InpRec,OFFSET_d,4))
              offset_d = offset_d +4
            end
            otherwise say QW0030ID 'not processed'
       End /* End select */
  return
QW0031:
       offset_save=offset
       /* offset= offset of self definition section*/
       /* offset= offset + 8 : bypass pointer to Product  Section*/
       /* Pointer 4 bytes + Len 2 bytes + Repeat factor 2 bytes  */
       offset=offset+8     /*pointer to data section 1*/
       /*take the contents pointed by the offset */
       offset_d= C2D(SUBSTR(InpRec,OFFSET,4))
       offset_d=offset_d -3
       /*offset_d points to the IFCID 030 data to process */
       offset = offset +4
       len     = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       repeat  = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       /* Init */
       QW0030DB=0
       QW0030DC=0
       QW0030PL=''
       QW0030CC=0
       QW0030LN=''
       QW0030CI=''
       QW0030PI=''
       QW0030CT=''
       QW0030GC=0
       /* Begin specific processing for IFCID */
       /* Type EDM :DB=DBDID, CT = Cursor table, PT=Pack table */
       QW0030ID =SUBSTR(InpRec,OFFSET_d,2)
       offset_d = offset_d +2
       Select
            when QW0030ID = 'DB' then
            do
              QW0030DB =c2d(SUBSTR(InpRec,OFFSET_d,2))
            end
            when QW0030ID = 'CT' then
            do
              QW0030PL =SUBSTR(InpRec,OFFSET_d,8)
            end
            when  QW0030ID = 'PT' then
            do
              QW0030LN =SUBSTR(InpRec,OFFSET_d,16)
              offset_d = offset_d +18
              if substr(QW0030LN,1,1) = '00'x
                then QW0030LN=''
                else QW0030LN=strip(QW0030LN)
              QW0030CI =SUBSTR(InpRec,OFFSET_d,18)
              offset_d = offset_d +18
              QW0030CI =strip(QW0030CI)
              QW0030PI =SUBSTR(InpRec,OFFSET_d,18)
              offset_d = offset_d +18
              QW0030PI =strip(QW0030PI)
              QW0030CT =c2x(SUBSTR(InpRec,OFFSET_d,8))
            end
            otherwise say QW0030ID 'not processed'
       End /* End select */
  return
QW0314:
       QW0314PL=''
       QW0314UN=''
       QW0314BN=''
       QW0314ON=''
       QW03141N=''
       QW03142N=''
       QW0314NN=''
       QW0314LN=''
       QW0314DN=''
       QW0314DA=''
       QW0314IM=''
       offset_save=offset
       /* offset= offset of self definition section*/
       /* offset= offset + 8 : bypass pointer to Product  Section*/
       /* Pointer 4 bytes + Len 2 bytes + Repeat factor 2 bytes  */
       offset=offset+4+2+2 /*pointer to data section 1*/
       /*take the contents pointed by the offset */
       offset_d= C2D(SUBSTR(InpRec,OFFSET,4))
       offset_d=offset_d -4+1
       offset_ifc=offset_d
       /*offset_d points to the IFCID 314 data to process */
       offset = offset +4
       len     = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       repeat  = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       /* Jump to RC */
       offset_d = offset_d + 12
       QW0314RC =C2D(substr(InpRec,OFFSET_d,2))
       offset_d = offset_d + 4
       /* Reason code     */
       QW0314RS =C2D(substr(InpRec,OFFSET_d,4))
       offset_d = offset_d + 20
       /* Reason code     */
  /*   QW0314PL =substr(InpRec,OFFSET_d,256)
       QW0314PL =strip(QW0314PL) */
       offset_d = offset_d + 256
 
       /* Database (QW0314D) */
       QW0314DO=C2D(substr(InpRec,OFFSET_d,2))
       offset_d = offset_d + 2
 
       /* Get User (QW0314U) */
       QW0314UO=C2D(substr(InpRec,OFFSET_d,2))
       offset_d = offset_d + 2
                      /*offset */
       QW0314UO=QW0314UO+ offset_ifc
                      /*len */
       QW0314UL= c2d(SUBSTR(InpRec,QW0314UO,2))
       QW0314UO = QW0314UO + 2
       QW0314UN = SUBSTR(InpRec,QW0314UO,QW0314UL)
 
       /* QW0314BO Unqualifies object*/
       QW0314BO=C2D(substr(InpRec,offset_d,2))
       offset_d = offset_d + 2
                      /*offset */
       QW0314BO=QW0314BO+ offset_ifc
                      /*len */
       QW0314BL= c2d(SUBSTR(InpRec,QW0314BO,2))
       QW0314BO = QW0314BO + 2
       QW0314BN = SUBSTR(InpRec,QW0314BO,QW0314BL)
 
       /* QW0314OO Object owner*/
       QW0314OO=C2D(substr(InpRec,offset_d,2))
       offset_d = offset_d + 2
                      /*offset */
       QW0314OO=QW0314OO+ offset_ifc
                      /*len */
       QW0314OL= c2d(SUBSTR(InpRec,QW0314OO,2))
       QW0314OO = QW0314OO + 2
       QW0314ON = SUBSTR(InpRec,QW0314OO,QW0314OL)
 
 
       /* QW03141O Info1       */
       QW03141O=C2D(substr(InpRec,offset_d,2))
       offset_d = offset_d + 2
                      /*offset */
       QW03141O=QW03141O+ offset_ifc
                      /*len */
       QW03141L= c2d(SUBSTR(InpRec,QW03141O,2))
       QW03141O = QW03141O + 2
       QW03141N = SUBSTR(InpRec,QW03141O,QW03141L)
 
       /* QW03142O Info2       */
       QW03142O=C2D(substr(InpRec,offset_d,2))
       offset_d = offset_d + 2
                      /*offset */
       QW03142O=QW03142O+ offset_ifc
                      /*len */
       QW03142L= c2d(SUBSTR(InpRec,QW03142O,2))
       QW03142O = QW03142O + 2
       QW03142N = SUBSTR(InpRec,QW03142O,QW03142L)
 
       /* QW0314NO Owner       */
       QW0314NO=C2D(substr(InpRec,offset_d,2))
       offset_d = offset_d + 2
                      /*offset */
       QW0314NO=QW0314NO+ offset_ifc
                      /*len */
       QW0314NL= c2d(SUBSTR(InpRec,QW0314NO,2))
       QW0314NO = QW0314NO + 2
       QW0314NN = SUBSTR(InpRec,QW0314NO,QW0314NL)
 
       /* QW0314LO Role        */
       QW0314LO=C2D(substr(InpRec,offset_d,2))
       offset_d = offset_d + 2
                      /*offset */
       QW0314LO=QW0314LO+ offset_ifc
                      /*len */
       QW0314LL= c2d(SUBSTR(InpRec,QW0314LO,2))
       QW0314LO = QW0314LO + 2
       QW0314LN = SUBSTR(InpRec,QW0314LO,QW0314LL)
 
       offset_d = offset_d + 10+6+80
 
       /* Nb of Database entries */
       QW0314DS=c2d(SUBSTR(InpRec,offset_d,4))
       if  QW0314DS > 0
         say 'code to complete to display DB Info '
         QW0314DX=QW0314DO+ offset_ifc
                        /*len */
         QW0314DP= c2d(SUBSTR(InpRec,QW0314DX,4))
         QW0314DX = QW0314DX + 2
         QW0314DN = SUBSTR(InpRec,QW0314DX,8)
         QW0314DX = QW0314DX + 8
         QW0314DA = SUBSTR(InpRec,QW0314DX,1)
         QW0314DX = QW0314DX + 1
         QW0314IM = SUBSTR(InpRec,QW0314DX,1)
       end
 
 
  return
QW0108:
       offset_save=offset
       /* offset= offset of self definition section*/
       /* offset= offset + 8 : bypass pointer to Product  Section*/
       /* Pointer 4 bytes + Len 2 bytes + Repeat factor 2 bytes  */
       offset=offset+4+2+2 /*pointer to data section 1*/
       /*take the contents pointed by the offset */
       offset_d= C2D(SUBSTR(InpRec,OFFSET,4))
       offset_d=offset_d -4+1
       /*offset_d points to the IFCID 108 data to process */
       offset = offset +4
       len     = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       repeat  = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       /* plan name if applicable */
       QW0108PN =SUBSTR(InpRec,OFFSET_d,8)
       offset_d = offset_d + 10
       /* Bind type A B R */
       QW0108T  = SUBSTR(InpRec,OFFSET_d,1)
       offset_d = offset_d +8
       /* Explain         */
       QW0108X  = SUBSTR(InpRec,OFFSET_d,1)
       if QW0108X  = '80'x then QW0108X ='Y'
                           else QW0108X ='N'
       offset_d = offset_d +2
       /* Owner */
       QW0108OW = SUBSTR(InpRec,OFFSET_d,8)
       offset_d = offset_d +8
       /* Type  PLAN ou PACKAGE */
       QW0108TY = SUBSTR(InpRec,OFFSET_d,8)
       offset_d = offset_d +34
       QW0108TY = Strip(QW0108TY)
       if QW0108TY = 'PACKAGE'  then
       do
            QW0108PN = ''
            /* Pack. name */
            QW0108PK = SUBSTR(InpRec,OFFSET_d,36)
            parse var  QW0108PK var1 var2
            QW0108PK=strip(var1)'.'strip(var2)
       end
       else QW0108PK = ''
       offset_d = offset_d + 126 /* real len of pack name*/
  return
QW0109:
numeric digits 15
       offset_save=offset
       /* offset= offset of self definition section*/
       /* offset= offset + 8 : bypass pointer to Product  Section*/
       /* Pointer 4 bytes + Len 2 bytes + Repeat factor 2 bytes  */
       offset=offset+4+2+2 /*pointer to data section 1*/
       /*take the contents pointed by the offset */
       offset_d= C2D(SUBSTR(InpRec,OFFSET,4))
       offset_d=offset_d -4+1
       /*offset_d points to the IFCID 108 data to process */
       offset = offset +4
       len     = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       repeat  = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       /* Return code  */
       QW0109RC =c2d(SUBSTR(InpRec,OFFSET_d,4))
  return
 
QW0350:
       offset_save=offset
       /* offset= offset of self definition section*/
       /* offset= offset + 8 : bypass pointer to Product  Section*/
       /* Pointer 4 bytes + Len 2 bytes + Repeat factor 2 bytes  */
       offset=offset+4+2+2 /*pointer to data section 1*/
       /*take the contents pointed by the offset */
       offset_d= C2D(SUBSTR(InpRec,OFFSET,4))
       offset_d=offset_d -4+1
       /*offset_d points to the IFCID 0350 data to process */
       offset = offset +4
       len     = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       repeat  = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       offset_d=offset_d+4 /* skip data */
       say ' '
       say '---- Begin Long SQL Text ----'
       /* Total len */
       QW0350TL =c2d(SUBSTR(InpRec,OFFSET_d,4))
       say '350/Total Len             :' QW0350TL
       offset_d = offset_d +4
       QW0350TY = SUBSTR(InpRec,OFFSET_d,2)
       select
           when qw0350ty='8000'x then sqltype='D'
           when qw0350ty='4000'x then sqltype='S'
           otherwise
           do
                say 'qw0350ty contents error unexpected value',
                          qw0350ty
                exit(8)
           end
       end
       say '350/Sql type              :' sqltype
       offset_d = offset_d +2
       /* statement identifier QW0350SI
       stmtid   =  c2x(SUBSTR(InpRec,OFFSET_d,8))
       say '350/stmtid=' stmtid */
       offset_d = offset_d +8
       /*Source CCSID */
       ccsid    = c2d(SUBSTR(InpRec,OFFSET_d,2))
       say '350/Original parser CCSID :' ccsid
       offset_d = offset_d +2
       /* len of the following */
       QW0350SPL=  c2d(SUBSTR(InpRec,OFFSET_d,2))
       len = QW0350SPL -2
       offset_d = offset_d +2
       QW0350SP =      SUBSTR(InpRec,OFFSET_d,len)
       xx= '350/Sql len/Text          :' len '/' !! ,
                        space(QW0350SP) !!'/'
       say xx
  /*   say 'offset_d 350 after stmtid =' offset_d
       say  'Display InpRec below'
       say  SUBSTR(InpRec,1,100)
       say  SUBSTR(InpRec,101,100)
       say  SUBSTR(InpRec,201,100)
       say  SUBSTR(InpRec,301,100)
       say  SUBSTR(InpRec,401,100)
       say  SUBSTR(InpRec,501,100)
       say  SUBSTR(InpRec,601,100)
       say  SUBSTR(InpRec,701,100) */
  return
QW0361:
       offset_save=offset
       /* offset= offset of self definition section*/
       /* offset= offset + 8 : bypass pointer to Product  Section*/
       /* Pointer 4 bytes + Len 2 bytes + Repeat factor 2 bytes  */
       offset=offset+4+2+2 /*pointer to data section 1*/
       /*take the contents pointed by the offset */
       offset_d= C2D(SUBSTR(InpRec,OFFSET,4))
       offset_d=offset_d -4+1
       /* offset_d of the ifcid data for use later*/
       offset_ifc = offset_d
       /*offset_d points to the IFCID 0376 data to process */
       offset = offset +4
       len     = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       repeat  = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       /* Authority type*/
       QW0361AT =    SUBSTR(InpRec,OFFSET_d,1)
       select
           when QW0361AT= 'I' then QW0361AT= 'InstSYSADM'
           when QW0361AT= 'D' then QW0361AT= 'DBADM'
           when QW0361AT= 'B' then QW0361AT= 'SystDBADM'
           when QW0361AT= 'C' then QW0361AT= 'DBCTRL'
           when QW0361AT= 'E' then QW0361AT= 'SECADM'
           when QW0361AT= 'G' then QW0361AT= 'ACCESSCTRL'
           when QW0361AT= 'K' then QW0361AT= 'SQLADM'
           when QW0361AT= 'L' then QW0361AT= 'SYSCTRL'
           when QW0361AT= 'M' then QW0361AT= 'DBMAINT'
           when QW0361AT= 'O' then QW0361AT= 'SYSOPR'
           when QW0361AT= 'P' then QW0361AT= 'PACKADM'
           when QW0361AT= 'R' then QW0361AT= 'InstSYSOPR'
           when QW0361AT= 'S' then QW0361AT= 'SYSADM'
           when QW0361AT= 'T' then QW0361AT= 'DATAACCESS'
           when QW0361AT= 'U' then QW0361AT= 'USER'
           otherwise QW0361AT = '?'
       end
       offset_d = offset_d +1
       /* Authid type*/
       QW0361IT =    SUBSTR(InpRec,OFFSET_d,1)
       offset_d = offset_d +1
       select
           when QW0361IT=' ' then QW0361IT = 'Auth'
           when QW0361IT='L' then QW0361IT = 'Role'
           otherwise QW0361IT = '?'
       end
       QW0361ID_Off=c2d(SUBSTR(InpRec,OFFSET_d,2))
       offset_d = offset_d +2
       /* Privilege checked */
       QW0361PR    =c2d(SUBSTR(InpRec,OFFSET_d,2))
       offset_d = offset_d +2
       select
           when QW0361PR=64  then QW0361PR = 'EXEC'
           when QW0361PR=50  then QW0361PR = 'SELECT'
           when QW0361PR=51  then QW0361PR = 'INSERT'
           when QW0361PR=52  then QW0361PR = 'DELETE'
           when QW0361PR=53  then QW0361PR = 'UPDATE'
           when QW0361PR=61  then QW0361PR = 'ALTER'
           when QW0361PR=98  then QW0361PR = 'LOCK TABLE'
           when QW0361PR=239 then QW0361PR = 'QUIESCE UTILITY'
           when QW0361PR=09  then QW0361PR = 'DIS PROFILE'
           when QW0361PR=10  then QW0361PR = 'STA PROFILE'
           when QW0361PR=11  then QW0361PR = 'STO PROFILE'
           when QW0361PR=12  then QW0361PR = 'STA RLIMIT'
           when QW0361PR=13  then QW0361PR = 'STO RLIMIT'
           when QW0361PR=14  then QW0361PR = 'DIS RLIMIT'
           when QW0361PR=15  then QW0361PR = 'CREATE ALIAS'
           when QW0361PR=16  then QW0361PR = 'MONITOR1'
           when QW0361PR=17  then QW0361PR = 'MONITOR2'
           when QW0361PR=19  then QW0361PR = 'CHECK UTILITY'
           when QW0361PR=20  then QW0361PR = 'DROP ALIAS'
           when QW0361PR=21  then QW0361PR = 'DDF CMD STA STO CAN'
           when QW0361PR=51  then QW0361PR = 'INSERT'
           when QW0361PR=52  then QW0361PR = 'DELETE'
           when QW0361PR=53  then QW0361PR = 'UPDATE'
           when QW0361PR=54  then QW0361PR = 'REFERENCES'
           when QW0361PR=55  then QW0361PR = 'TRIGGER'
           when QW0361PR=56  then QW0361PR = 'CREATE INDEX'
           when QW0361PR=58  then QW0361PR = 'TERMINATE UTILITY ON DB'
           when QW0361PR=62  then QW0361PR = 'D THREAD OR D DB'
           when QW0361PR=65  then QW0361PR = 'BIND, REBIND OR FREE'
           when QW0361PR=66  then QW0361PR = 'CREATEDBA'
           when QW0361PR=67  then QW0361PR = 'CREATE STOGROUP'
           when QW0361PR=68  then QW0361PR = 'DBCTRL'
           when QW0361PR=69  then QW0361PR = 'DBMAINT'
           when QW0361PR=72  then QW0361PR = 'RECOVER INDOUBT'
           when QW0361PR=73  then QW0361PR = 'DROP'
           when QW0361PR=74  then QW0361PR = 'COPY'
           when QW0361PR=75  then QW0361PR = 'LOAD'
           when QW0361PR=76  then QW0361PR = 'EXPLICIT QUALIFIER USE'
           when QW0361PR=77  then QW0361PR = 'REORG'
           when QW0361PR=78  then QW0361PR = 'REPAIR'
           when QW0361PR=79  then QW0361PR = 'START DATABASE'
           when QW0361PR=80  then QW0361PR = 'STA/STO DB2 OR DB(*)'
           when QW0361PR=82  then QW0361PR = 'RUNSTATS UTILITY'
           when QW0361PR=83  then QW0361PR = 'STOP DATABASE'
           when QW0361PR=84  then QW0361PR = 'STOP OR START TRACE'
           when QW0361PR=85  then QW0361PR = 'SYSADM'
           when QW0361PR=86  then QW0361PR = 'SYSOPR'
           when QW0361PR=87  then QW0361PR = 'USE'
           when QW0361PR=88  then QW0361PR = 'BIND ADD'
           when QW0361PR=89  then QW0361PR = 'RECOVER'
           when QW0361PR=92  then QW0361PR = 'CREATEDBC'
           when QW0361PR=93  then QW0361PR = 'RECOVER BSDS'
           when QW0361PR=94  then QW0361PR = 'CREATE TABLE'
           when QW0361PR=95  then QW0361PR = 'CREATE TABLESPACE'
           when QW0361PR=96  then QW0361PR = 'DISPLAY UTILITY'
           when QW0361PR=97  then QW0361PR = 'COMMENT ON'
           when QW0361PR=99  then QW0361PR = 'DISPLAY DATABASE'
           when QW0361PR=102 then QW0361PR = 'CREATE SYNONYM'
           when QW0361PR=103 then QW0361PR = 'ALTER INDEX'
           when QW0361PR=104 then QW0361PR = 'DROP SYNONYM'
           when QW0361PR=105 then QW0361PR = 'DROP INDEX'
           when QW0361PR=107 then QW0361PR = 'STOSPACE UTILITY'
           when QW0361PR=108 then QW0361PR = 'CREATE VIEW'
           when QW0361PR=109 then QW0361PR = 'TERM UTILITY'
           when QW0361PR=112 then QW0361PR = 'DISPLAY BUFFERPOOL'
           when QW0361PR=113 then QW0361PR = 'ALTER BUFFERPOOL'
           when QW0361PR=224 then QW0361PR = 'SYSCTRL'
           when QW0361PR=225 then QW0361PR = 'COPY PACKAGE'
           when QW0361PR=226 then QW0361PR = 'CREATE IN'
           when QW0361PR=227 then QW0361PR = 'BINDAGENT'
           when QW0361PR=60  then QW0361PR = 'ALL ON PACKAGES'
           when QW0361PR=231 then QW0361PR = 'ARCHIVE'
           when QW0361PR=228 then QW0361PR = 'ALLPKAUT'
           when QW0361PR=229 then QW0361PR = 'SUBPKAUT'
           when QW0361PR=233 then QW0361PR = 'DESCRIBE TABLE'
           when QW0361PR=236 then QW0361PR = 'DIAGNOSE UTILITY'
           when QW0361PR=237 then QW0361PR = 'MERGECOPY UTILITY'
           when QW0361PR=238 then QW0361PR = 'MODIFY UTILITY'
           when QW0361PR=240 then QW0361PR = 'REPORT UTILITY'
           when QW0361PR=241 then QW0361PR = 'REPAIR DBD UTILITY'
           when QW0361PR=242 then QW0361PR = 'PACKADM'
           when QW0361PR=243 then QW0361PR = 'SET ARCHIVE'
           when QW0361PR=244 then QW0361PR = 'DISPLAY ARCHIVE'
           when QW0361PR=248 then QW0361PR = 'CREATE GTT'
           when QW0361PR=251 then QW0361PR = 'RENAME TABLE'
           when QW0361PR=252 then QW0361PR = 'ALTERIN'
           when QW0361PR=261 then QW0361PR = 'CREATEIN'
           when QW0361PR=262 then QW0361PR = 'DROPIN'
           when QW0361PR=263 then QW0361PR = 'USAGE'
           when QW0361PR=265 then QW0361PR = 'START'
           when QW0361PR=266 then QW0361PR = 'STOP'
           when QW0361PR=267 then QW0361PR = 'DISPLAY'
           when QW0361PR=274 then QW0361PR = 'COMMENT ON INDEX'
           when QW0361PR=280 then QW0361PR = 'VALIDATE SECLABEL'
           when QW0361PR=281 then QW0361PR = 'MLS READWRITE'
           when QW0361PR=282 then QW0361PR = 'DEBUG SESSION'
           when QW0361PR=283 then QW0361PR = 'RENAME INDEX'
           when QW0361PR=284 then QW0361PR = 'SECADM'
           when QW0361PR=285 then QW0361PR = 'CREATE SECURE OBJ'
           when QW0361PR=286 then QW0361PR = 'EXPLAIN'
           when QW0361PR=287 then QW0361PR = 'SYSTEM DBADM'
           when QW0361PR=289 then QW0361PR = 'ACCESSCTRL'
           when QW0361PR=290 then QW0361PR = 'SQLADM'
           when QW0361PR=293 then QW0361PR = 'EXPLAIN MONITOR'
           when QW0361PR=294 then QW0361PR = 'QUERY TUNING'
           when QW0361PR=295 then QW0361PR = 'CHECK DATA'
           when QW0361PR=296 then
                       QW0361PR = 'SYSOPR SYSCTRL SYSADM SECAADM'
           otherwise QW0361PR = '?'
       end
       /* For excel ... */
       QW0361PR='"'QW0361PR'"'
       QW0361SQ='"'QW0361SQ'"'
       /* Source Object */
       QW0361SC_Off=c2d(SUBSTR(InpRec,OFFSET_d,2))
       offset_d=offset_d+2
       QW0361SN_Off=c2d(SUBSTR(InpRec,OFFSET_d,2))
       offset_d=offset_d+6
       /* Obj type */
       QW0361OT    =    SUBSTR(InpRec,OFFSET_d,1)
       offset_d=offset_d+1
       select
           when QW0361OT='K' then QW0361OT = 'PACK'
           when QW0361OT='T' then QW0361OT = 'TABLE/VIEW'
           when QW0361OT='R' then QW0361OT = 'TABLESPACE'
           when QW0361OT='D' then QW0361OT = 'DATABASE'
           when QW0361OT='P' then QW0361OT = 'APPLICATION PLAN'
           when QW0361OT='B' then QW0361OT = 'BUFFERPOOL'
           when QW0361OT='C' then QW0361OT = 'COLLECTION'
           when QW0361OT='E' then QW0361OT = 'DISTINCT TYPE'
           when QW0361OT='F' then QW0361OT = 'FUNCTION'
           when QW0361OT='H' then QW0361OT = 'GLOBAL VARIABLE'
           when QW0361OT='J' then QW0361OT = 'JAR'
           when QW0361OT='L' then QW0361OT = 'ROLE'
           when QW0361OT='M' then QW0361OT = 'SCHEMA'
           when QW0361OT='N' then QW0361OT = 'TRUSTED CONTEXT'
           when QW0361OT='O' then QW0361OT = 'PROCEDURE'
           when QW0361OT='Q' then QW0361OT = 'SEQUENCE'
           when QW0361OT='S' then QW0361OT = 'STORAGE GROUP'
           when QW0361OT='U' then QW0361OT = 'USER AUTH'
           when QW0361OT='A' then QW0361OT = 'ACEE'
           when QW0361OT='W' then QW0361OT = 'ROW'
           when QW0361OT='Z' then QW0361OT = 'ZPARM'
           otherwise QW0361OT = '?'
       end
       offset_d=offset_d+5
       /* SQL Len  ..*/
       QW0361LL    = c2d(SUBSTR(InpRec,offset_d,4))
       offset_d=offset_d+4
       /* Len if truncated */
       QW0361LE    = c2d(SUBSTR(InpRec,offset_d,2))
       offset_d=offset_d+2
       /* SQL TXT  ..*/
       if QW0361LL > 0  then
       QW0361SQ    = '"'SUBSTR(InpRec,offset_d,QW0361LE)'"'
       else
       QW0361SQ    = ''
 
       /* Extract Authid or Role */
       QW0361ID_Off = QW0361ID_Off + offset_ifc
       QW0361ID_Len= c2d(SUBSTR(InpRec,QW0361ID_Off,2))
       offset_d = QW0361ID_Off + 2
       QW0361ID = SUBSTR(InpRec,OFFSET_d,QW0361ID_Len)
       /* Extract Source Qual    */
       if QW0361SC_Off > 0 then
       do
         QW0361SC_Off = QW0361SC_Off + offset_ifc
         QW0361SC_Len= c2d(SUBSTR(InpRec,QW0361SC_Off,2))
         offset_d = QW0361SC_Off + 2
         QW0361SC = SUBSTR(InpRec,OFFSET_d,QW0361SC_Len)
         /* Extract Source Name    */
         QW0361SN_Off = QW0361SN_Off + offset_ifc
         QW0361SN_Len= c2d(SUBSTR(InpRec,QW0361SN_Off,2))
         offset_d = QW0361SN_Off + 2
         QW0361SN = SUBSTR(InpRec,OFFSET_d,QW0361SN_Len)
         Obj= QW0361SC'.'QW0361SN
       end
       else
         Obj = ''
       return
QW0376:
       offset_save=offset
       /* offset= offset of self definition section*/
       /* offset= offset + 8 : bypass pointer to Product  Section*/
       /* Pointer 4 bytes + Len 2 bytes + Repeat factor 2 bytes  */
       offset=offset+4+2+2 /*pointer to data section 1*/
       /*take the contents pointed by the offset */
       offset_d= C2D(SUBSTR(InpRec,OFFSET,4))
       offset_d=offset_d -4+1
       /* offset_d of the ifcid data for use later*/
       offset_ifc = offset_d
       /*offset_d points to the IFCID 0376 data to process */
       offset = offset +4
       len     = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       repeat  = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       /* Function code */
       QW0376FN =c2d(SUBSTR(InpRec,OFFSET_d,4))
       select
           when QW0376FN=1 then
               FnTxt='V9 CHAR(decimal-expr)'
           when QW0376FN=2 then
               FnTxt='V9 VARCHAR(decimal-expr)-CAST decimal as CHAR',
                     '/VARCHAR'
           when QW0376FN=3 then
               FnTxt='Unsupported char. string representation ',
                     'of a timestamp'
           when QW0376FN=7 then
               FnTxt='Unsupported Cast because DDF_COMPARTIBILITY ',
                     'zparm value'
           when QW0376FN=8 then
               FnTxt='DDF_COMPARTIBILITY=SP_PARMS_xJV and match ',
                     'output data is returned'
           when QW0376FN=9 then
               FnTxt='TIMEZONE ignored because of',
                     ' DDF_COMPARTIBILITY zparm value'
           when QW0376FN=10 then
               FnTxt='Pre v10 version of  ',
                     'LTRIM, RTRIM or STRIP has been executed'
           when QW0376FN=11 then
               FnTxt='SELECT INTO with UNION UNION ALL EXCEPT ALL ',
                     'INTERSECT INTERSECT ALL OPERATOR'
           when QW0376FN=1104 then
               FnTxt='CLIENT_ACCTNG SPECIAL REGISTER WAS SET FOR ',
                     'A VALUE NOT SUPPORTED IN V11'
           when QW0376FN=1105 then
               FnTxt='CLIENT_APPLNAME SPECIAL REGISTER WAS SET FOR ',
                     'A VALUE NOT SUPPORTED IN V11'
           when QW0376FN=1106 then
               FnTxt='CLIENT_USERID SPECIAL REGISTER WAS SET FOR ',
                     'A VALUE NOT SUPPORTED IN V11'
           when QW0376FN=1107 then
               FnTxt='CLIENT_WRKSTNNAME SPECIAL REGISTER WAS SET FOR ',
                     'A VALUE NOT SUPPORTED IN V11'
           when QW0376FN=1108 then
               FnTxt='CLIENT_* SPECIAL REGISTER WAS SET FOR ',
                     'A VALUE TOO LONG IN V11'
           when QW0376FN=1109 then
               FnTxt='CAST string as Timestamp'
           otherwise
           do
               FnTxt =QW0376FN
           end
       end
       offset_d = offset_d +4
       /* Statement number in the query */
       QW0376SN =c2d(SUBSTR(InpRec,OFFSET_d,4))
       offset_d = offset_d +4
       /* Planname */
       QW0376PL =SUBSTR(InpRec,OFFSET_d,8)
       offset_d = offset_d +8
       /* ConToken */
       QW0376TS =c2x(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* Statement Id */
       QW0376SI =c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
         /* statement identifier QW0350SI
         stmtid   =  c2x(SUBSTR(InpRec,OFFSET_d,8))
         say '376/stmtid=' stmtid */
       /* Statement type */
       QW0376TY =SUBSTR(InpRec,OFFSET_d,2)
       offset_d = offset_d +2
       select
           when qw0376ty='8000'x then sqltype='D'
           when qw0376ty='4000'x then sqltype='S'
           otherwise
           do
                say 'qw0376ty contents error unexpected value',
                          qw0376ty
                exit(8)
           end
       end
       /* Section Number */
       QW0376SE =c2d(SUBSTR(InpRec,OFFSET_d,2))
       offset_d = offset_d +2
       /* Offset to Collid */
       QW0376PC_Off =c2d(SUBSTR(InpRec,OFFSET_d,2))
       QW0376PC_Off = QW0376PC_Off + offset_ifc
       offset_d = offset_d +2
       /* Offset to Package */
       QW0376PN_Off =c2d(SUBSTR(InpRec,OFFSET_d,2))
       QW0376PN_Off = QW0376PN_Off + offset_ifc
       offset_d = offset_d +2
       /*Version Len */
       QW0376VL = c2d(SUBSTR(InpRec,OFFSET_d,2))
       offset_d = offset_d +2
       /*Version  */
       QW0376VN = SUBSTR(InpRec,OFFSET_d,qw0376VL)
       offset_d = offset_d +68
       /*Offset to Incompatible parms */
       QW0376INC_Off=c2d(SUBSTR(InpRec,OFFSET_d,2))
       QW0376INC_Off=QW0376INC_Off + offset_ifc
       offset_d = offset_d +2
       /*Offset to sql text */
       QW0376SQL_Off=c2d(SUBSTR(InpRec,OFFSET_d,2))
       QW0376SQL_Off=QW0376SQL_Off + offset_ifc
 
 
       /* Extract Collid  */
       QW0376PC_Len= c2d(SUBSTR(InpRec,QW0376PC_Off,2))
       if QW0376PC_Len > 10 then QW0376PC_Len = 10
       offset_d = QW0376PC_Off + 2
       QW0376PC = SUBSTR(InpRec,OFFSET_d,QW0376PC_Len)
       /* Extract Package name */
       QW0376PN_Len= c2d(SUBSTR(InpRec,QW0376PN_Off,2))
       if QW0376PN_Len > 10 then QW0376PN_Len = 10
       offset_d = QW0376PN_Off + 2
       QW0376PN = SUBSTR(InpRec,OFFSET_d,QW0376PN_Len)
       /* Extract Incomp. parms */
       QW0376INC_Len=c2d(SUBSTR(InpRec,QW0376INC_Off,2))
       offset_d =QW0376INC_Off + 2
       QW0376INC = SUBSTR(InpRec,OFFSET_d,QW0376INC_Len)
       /* Extract SQLText      */
       QW0376SQL_Len=c2d(SUBSTR(InpRec,QW0376SQL_Off,2))
       offset_d =QW0376SQL_Off + 2
       QW0376SQL = SUBSTR(InpRec,OFFSET_d,QW0376SQL_Len)
    /* Say 'SQL Off' QW0376SQL_Off QW0376SQL_Len InpRec*/
 
  return
QW0342:
       offset_save=offset
       /* offset= offset of self definition section*/
       /* offset= offset + 8 : bypass pointer to Product  Section*/
       /* Pointer 4 bytes + Len 2 bytes + Repeat factor 2 bytes  */
       offset=offset+4+2+2 /*pointer to data section 1*/
       /*take the contents pointed by the offset */
       offset_d= C2D(SUBSTR(InpRec,OFFSET,4))
       offset_d=offset_d -4+1
       /* offset_d of the ifcid data for use later*/
       offset_ifc = offset_d
       /*offset_d points to the IFCID 0342 data to process */
       offset = offset +4
       len     = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       repeat  = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       /* WF type  */
       QW0342TY = SUBSTR(InpRec,OFFSET_d,4)
       offset_d = offset_d +4
       /* DBID */
       QW0342DB = c2d(SUBSTR(InpRec,OFFSET_d,2))
       offset_d = offset_d +2
       /* PSID */
       QW0342PS = c2d(subSTR(InpRec,OFFSET_d,2))
       offset_d = offset_d +2
       /* Current space usage in KB */
       QW0342CT =c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* Max     space usage in KB */
       QW0342MT =c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8+16
       /* Agent token */
       QW0342AT = c2x(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
  return
QW0224:
       offset_save=offset
       /* offset= offset of self definition section*/
       /* offset= offset + 8 : bypass pointer to Product  Section*/
       /* Pointer 4 bytes + Len 2 bytes + Repeat factor 2 bytes  */
       offset=offset+8     /*pointer to data section 1*/
       /*take the contents pointed by the offset */
       offset_d= C2D(SUBSTR(InpRec,OFFSET,4))
       offset_d=offset_d -3
       /*offset_d points to the IFCID 0224 data to process */
       offset = offset +4
       len     = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       repeat  = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       /* Nb cols       */
       QW0224CL =c2d(SUBSTR(InpRec,OFFSET_d,4))
       offset_d = offset_d +4
       /* Pgm  */
       QW0224PN =SUBSTR(InpRec,OFFSET_d,8)
       offset_d = offset_d +8
       /* Collid   */
       QW0224CI =SUBSTR(InpRec,OFFSET_d,18)
  return
QW0063:
       offset_save=offset
       /* offset= offset of self definition section*/
       /* offset= offset + 8 : bypass pointer to Product  Section*/
       /* Pointer 4 bytes + Len 2 bytes + Repeat factor 2 bytes  */
       offset=offset+4+2+2 /*pointer to data section 1*/
       /*take the contents pointed by the offset */
       offset_d= C2D(SUBSTR(InpRec,OFFSET,4))
       offset_d=offset_d -4+1
       /*offset_d points to the IFCID 0063 data to process */
       offset = offset +4
       len     = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       repeat  = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       offset_d=offset_d+2 /* skip data */
       QW0063LL =c2d(SUBSTR(InpRec,OFFSET_d,2))
       offset_d = offset_d +2
       QW0063ST = SUBSTR(InpRec,OFFSET_d,QW0063LL-2)
   /*  say ' '
       say '---- Begin Dynamic SQL ----' */
       xx= '63/SQL Text             >' !!  space(QW0063ST) !! '<'
       say xx
       offset_d = offset_d + QW0063LL /* skip statement type*/
       /* statement identifier QW0063SI
       stmtid   =  c2x(SUBSTR(InpRec,OFFSET_d,8))
       say '63/stmtid=' stmtid */
       offset_d = offset_d +8
       /*Source CCSID */
       ccsid    = c2d(SUBSTR(InpRec,OFFSET_d,2))
 /*    say '63/Original parser CCSID :' ccsid
       say 'offset_d 063 after stmtid =' offset_d
       say  'Display InpRec below'
       say  SUBSTR(InpRec,1,100)
       say  SUBSTR(InpRec,101,100)
       say  SUBSTR(InpRec,201,100)
       say  SUBSTR(InpRec,301,100)
       say  SUBSTR(InpRec,401,100)
       say  SUBSTR(InpRec,501,100)
       say  SUBSTR(InpRec,601,100)
       say  SUBSTR(InpRec,701,100) */
  return
QW0317:
       offset_save=offset
       /* offset= offset of self definition section*/
       /* offset= offset + 8 : bypass pointer to Product  Section*/
       /* Pointer 4 bytes + Len 2 bytes + Repeat factor 2 bytes  */
       offset=offset+4+2+2 /*pointer to data section 1*/
       /*take the contents pointed by the offset */
       offset_d= C2D(SUBSTR(InpRec,OFFSET,4))
       offset_d=offset_d -4+1
       /*offset_d points to the IFCID 0317 data to process */
       offset = offset +4
       len     = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       repeat  = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       offset_d=offset_d+36/* skip data */
       QW0317ID =SUBSTR(InpRec,OFFSET_d,4)
       offset_d = offset_d +4
       QW0317LN =c2d(SUBSTR(InpRec,OFFSET_d,2))
       offset_d = offset_d +2
       /* To go fast, take only the first 4000 bytes of SQL*/
       if QW0317LN < 4003 then
          QW0317TX = SUBSTR(InpRec,OFFSET_d,QW0317LL-2)
       else
          QW0317TX = SUBSTR(InpRec,OFFSET_d,4000)
  return
QW0247:
       offset_save=offset
       /* offset= offset of self definition section*/
       /* offset= offset + 8 : bypass pointer to Product  Section*/
       /* Pointer 4 bytes + Len 2 bytes + Repeat factor 2 bytes  */
       offset=offset+4+2+2 /*pointer to data section 1*/
       /*take the contents pointed by the offset */
       offset_d= C2D(SUBSTR(InpRec,OFFSET,4))
       offset_d=offset_d -4+1
       /*offset_d points to the IFCID 0247 data to process */
       offset = offset +4
       len     = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       repeat  = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       /* location */
       QW0247LN =SUBSTR(InpRec,OFFSET_d,16)
       offset_d = offset_d +16
       /* Collid   */
       QW0247PC =SUBSTR(InpRec,OFFSET_d,18)
       say ' '
       say '---- begin host variable ----'
       offset_d = offset_d +18
       /* Package name */
       QW0247PN =SUBSTR(InpRec,OFFSET_d,18)
       xx= '247/Collid/Program       :' ,
                  strip(QW0247PC)!! '/' !! strip(qw0247pn)
       say xx
       /* Consitency token (Contoken in sysibm.syspackstmt) */
       offset_d = offset_d +18
       /* Divers */
       offset_d = offset_d +8+2
       /* Number of entries in SQLDA */
       QW0247NE =c2d(SUBSTR(InpRec,OFFSET_D,2))
       offset_d = offset_d +2
       /* Len of each SQLDA entry */
       QW0247LE =c2d(SUBSTR(InpRec,OFFSET_d,2))
       offset_d = offset_d +2+1+1
       /* Statement number = STMNO in SYSPACKSTMT */
       QW0247SN = c2d(SUBSTR(InpRec,OFFSET_d,4))
       say '247/STMTNO               :'  qw0247sn
       offset_d = offset_d + 4
       offset_d = offset_d + 8 /* H + H + H then 0000x ?? */
       /* jump Qw0247LN_D Dsect */
       /* Begin SQLDA entry */
       /* Data type (defined in SQLTYPE Manual SQL Reference */
       QW0247TY = c2d(SUBSTR(InpRec,OFFSET_d,2))
       select
           when QW0247TY = 388 then VTYPE='TIME'
           when QW0247TY = 389 then VTYPE='TIME'
           when QW0247TY = 392 then VTYPE='TS'
           when QW0247TY = 393 then VTYPE='TS'
           when QW0247TY > 403 & QW0247TY < 414 then VTYPE='xLOB'
           when QW0247TY =448 then VTYPE='VARCHAR'
           when QW0247TY =449 then VTYPE='VARCHAR'
           when QW0247TY =452 then VTYPE='CHAR'
           when QW0247TY =453 then VTYPE='CHAR'
           when QW0247TY =484 then VTYPE='DEC'
           when QW0247TY =485 then VTYPE='DEC'
           when QW0247TY =492 then VTYPE='BINT'
           when QW0247TY =493 then VTYPE='BINT'
           when QW0247TY =496 then VTYPE='INT'
           when QW0247TY =497 then VTYPE='INT'
           otherwise do
               say '247/Data type QW0247 not Processed yet' QW0247TY
               VTYPE='UNKNOWN'
             end
       end /* end select */
       offset_d = offset_d + 2
       say '247/Datatype/vtype       :',
                                 qw0247TY '/' vtype
       if VTYPE = 'DEC' then
       do
          /* Precision if Decimal */
          QW0247LP = c2d(SUBSTR(InpRec,OFFSET_d,1))
          say '    247/Decimal Precision    :'  qw0247LP
          offset_d = offset_d + 1
          /* Scale     if Decimal */
          QW0247LS = c2d(SUBSTR(InpRec,OFFSET_d,1))
          say '    247/DEC Scale            :'   qw0247LS
          offset_d = offset_d + 1
       end
       else
       do
          offset_d = offset_d + 2
       end
       /* skip */
       offset_d = offset_d + 20
       /* SQLDA Entry No */
       QW0247NO = c2d(SUBSTR(InpRec,OFFSET_d,4))
       xx= '247/Entry No/Total       :' qw0247no !!  '/' !! qw0247NE
       say xx
       offset_d = offset_d + 40
 
       /* QW0247B DSECT */
       QW0247LL = c2d(SUBSTR(InpRec,OFFSET_d,2))
       offset_d = offset_d + 2
       xx= '247/Host Var below Text is in Unicode !!'
       say xx
       select
          when  VTYPE = 'VARCHAR' then
             do
               len      = c2d(SUBSTR(InpRec,OFFSET_d,2))
               offset_d = offset_d + 2
               hv       = SUBSTR(InpRec,OFFSET_d,len)
               xx= '247/Host Var. value/len  >' ,
                             !!  hv !! '<' !! len !! '/'
             end
          when  VTYPE = 'CHAR' then
            do
              Null_ind = SUBSTR(InpRec,OFFSET_d,1)
              if Null_ind = '00'x then  Null_ind = 'N'
                                  else  Null_ind = 'Y'
              len   = qw0247ll-2
              hv    = SUBSTR(InpRec,OFFSET_d+1,len)
              xx= '247/Null/Host Var. value/Len   :',
                          !!  null_ind !! '>' !! hv !!'<'!! len!! '/'
            end
          when  VTYPE = 'DEC' then
            do
              len   = qw0247ll-2
              hv       = c2x(SUBSTR(InpRec,OFFSET_d,len))
              xx= '     247/Host Var. value Hexa/len   >',
                        !!             hv !!'<'!! len!! '/'
            end
          otherwise
            do
              len   = qw0247ll-2
              hv       = SUBSTR(InpRec,OFFSET_d,len)
              xx= '247/Host Var. value/len        >',
                        !!             hv !!'<'!! len!! '/'
            end
       end /* end select */
       say  xx
   /*  say  'InpRec display below'
       say  SUBSTR(InpRec,1,99 )
       say  SUBSTR(InpRec,100,099)
       say  SUBSTR(InpRec,200,099)
       say  SUBSTR(InpRec,300,099)
       say  SUBSTR(InpRec,400,099)
       say  SUBSTR(InpRec,500,099)
       say  SUBSTR(InpRec,600,099)
       say  SUBSTR(InpRec,700,099) */
 
  return
 
QW0058:
       /* lot of things in common with IFCID 0247 */
       offset_save=offset
       /* offset= offset of self definition section*/
       /* offset= offset + 8 : bypass pointer to Product  Section*/
       /* Pointer 4 bytes + Len 2 bytes + Repeat factor 2 bytes  */
       offset=offset+4+2+2 /*pointer to data section 1*/
       /*take the contents pointed by the offset */
       offset_d= C2D(SUBSTR(InpRec,OFFSET,4))
       offset_d=offset_d -4+1
       /*offset_d points to the IFCID 0058 data to process */
       offset = offset +4
       len     = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       repeat  = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       /* location */
       QW0058LN =SUBSTR(InpRec,OFFSET_d,16)
       offset_d = offset_d +16
       /* Collid   */
       QW0058PC =SUBSTR(InpRec,OFFSET_d,18)
       say ' '
       say '---- End SQL ---- ifcid :' ifcid
       offset_d = offset_d +18
       /* Package name */
       QW0058PN =SUBSTR(InpRec,OFFSET_d,18)
       xx= ifcid !! '/Collid/Program       :',
               strip(QW0058PC) !! '/' !! strip(qw0058pn)
       say xx
       /* Consitency token (Contoken in sysibm.syspackstmt) */
       offset_d = offset_d +18
       /* Divers */
       offset_d = offset_d +10
       /* SQLCA */
       QW0058SQ =    SUBSTR(InpRec,OFFSET_D,136)
       say '058/SQLCA 1-50           >'!! substr(qw0058sq,1,50)!!'<'
       say '058/SQLCA 51-100         >'!! substr(qw0058sq,51,50)!!'<'
       say '058/SQLCA 101-136        >'!! substr(qw0058sq,101,36)!!'<'
       say '058/SQLCA 101-136        >'!! substr(qw0058sq,101,36)!!'<'
       offset_d = offset_d +136+2
       /* jump to SQLCODE from sqlca */
       offset_d = offset_d +8+4
       /* sqlcode is in sqlca -look dsntiac for sqlca description*/
       sqlcode  =x2d(c2x(SUBSTR(InpRec,OFFSET_d,4)),8)
       xx= ifcid !!'/Sqlcode              :' sqlcode
       say xx
       offset_d = offset_d +4+120
       /* Statement number  */
       QW0058SN = c2d(SUBSTR(InpRec,OFFSET_d,4))
       offset_d = offset_d + 4
       offset_d = offset_d + 22 + 2
       /* SQL Type */
       QW0058TOS= SUBSTR(InpRec,OFFSET_d,1)
       select
           when QW0058TOS = '01'x then sqltype='FETCH'
           when QW0058TOS = '10'x then sqltype='Insert'
           when QW0058TOS = '11'x then sqltype='SELECT INTO'
           when QW0058TOS = '20'x then sqltype='UPDATE NONCURSOR'
           when QW0058TOS = '21'x then sqltype='UPDATE CURSOR'
           when QW0058TOS = '30'x then sqltype='MERGE'
           when QW0058TOS = '40'x then sqltype='DELETE NONCURSOR'
           when QW0058TOS = '41'x then sqltype='DELETE CURSOR'
           when QW0058TOS = '50'x then sqltype='TRUNCATE'
           when QW0058TOS = '80'x then sqltype='PREPARE NONCURSOR'
           when QW0058TOS = '81'x then sqltype='PREPARE CURSOR'
           when QW0058TOS = '91'x then sqltype='OPEN'
           when QW0058TOS = 'A1'x then sqltype='CLOSE'
           otherwise do
               xx= ifcid!!'/SQL type QW0058 not Processed yet',
                                QW0058TOS
               sqltype='UNKNOWN'
             end
       end /* end select */
       xx= ifcid!!'/Statement number/type:'  qw0058sn !! '/' sqltype
       say xx
       offset_d = offset_d + 1
    /* say  'InpRec display below'
       say  SUBSTR(InpRec,1,99 )
       say  SUBSTR(InpRec,100,099)
       say  SUBSTR(InpRec,200,099)
       say  SUBSTR(InpRec,300,099)
       say  SUBSTR(InpRec,400,099)
       say  SUBSTR(InpRec,500,099)
       say  SUBSTR(InpRec,600,099)
       say  SUBSTR(InpRec,700,099) */
 
  return
 
QW0316:
       SQLType='DY'
       offset_save=offset
       /* offset= offset of self definition section*/
       /* offset= offset + 8 : bypass pointer to Product  Section*/
       /* Pointer 4 bytes + Len 2 bytes + Repeat factor 2 bytes  */
       offset=offset+4+2+2 /*pointer to data section 1*/
       /*take the contents pointed by the offset */
       offset_d= C2D(SUBSTR(InpRec,OFFSET,4))
       offset_d=offset_d -4+1
       /* offset_d of the ifcid data for use later*/
       offset_ifc=offset_d
       /*offset_d points to the IFCID 316 data to process */
       offset = offset +4
       /* length of data section*/
       len     = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       /* How many  data section ?*/
       repeat  = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
 
       offset_d = offset_d +16
       /* QW0316TK*/
       Stmtid = C2D(SUBSTR(InpRec,OFFSET_d,4))
       /* skip the first 24 bytes*/
       offset_d = offset_d +8
       /* nbr users QW0316US*/
       CurrUsers = C2D(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* copies    */
       Copies    = C2D(SUBSTR(InpRec,OFFSET_d,4))
       offset_d = offset_d +4
       /* Status  QW0316FL */
       Status    = SUBSTR(InpRec,OFFSET_d,1)
       offset_d = offset_d +1
       select
           When status = '80'x then status = 'Inv by DROP ALTER'
           When status = '40'x then status = 'Inv by REVOK'
           When status = '20'x then status = 'Removed LRU'
           When status = '10'x then status = 'Inv by RUNSTATS'
           Otherwise  status = 'OK'
       end
       offset_d = offset_d +1+10
       /* nbr execs QW0316NE*/
       nbr_execs =c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* nbr reads */
       nbr_reads=c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* nbr gp    */
       nbr_gp =c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* nbr examined rows */
       nbr_ER =c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* nbr rows Processed */
       nbr_pr =c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* nbr sorts */
       nbr_sort =c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* nbr ix scans */
       nbr_ixscan =c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* nbr TS scans*/
       nbr_tsscan =c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* nbr Parallel groups created*/
       nbr_PG =c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* nbr buffer sync writes QW0316NW*/
       nbr_syncwr =c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* db2 elapsed   QW0316AE */
       elapse = c2x(SUBSTR(InpRec,OFFSET_d,8))
       elapse   = x2d(substr(elapse,1,13))
       elapse   = elapse  /1000000
       /* skip ... waits ...*/
       /* pgm name      */
       offset_d = offset_d +70
       len=c2d(SUBSTR(InpRec,OFFSET_d,2))
       /*QW0316T1*/
       pgm_name = SUBSTR(InpRec,OFFSET_d+2,len)
       offset_d = offset_d +46
       /* QW0316T2 */
       tran_name = SUBSTR(InpRec,OFFSET_d,8)
       offset_d = offset_d +32
       /* QW0316XE*/
       end_user  = SUBSTR(InpRec,OFFSET_d,8)
       offset_d = offset_d +16
       /* QW0316XF*/
       wrkstation= SUBSTR(InpRec,OFFSET_d,8)
       offset_d = offset_d +68
       /* QW0316TD */
       table_name= strip(SUBSTR(InpRec,OFFSET_d,8)) !! '.' !!,
                   strip(SUBSTR(InpRec,OFFSET_d+10,8))
       offset_d = offset_d +32
       /* db2 cpu (including ziip) QW0316CT  */
       cputime  = c2x(SUBSTR(InpRec,OFFSET_d,8))
       cputime  = x2d(substr(cputime,1,13))
       cputime  = cputime     /1000000
       offset_d = offset_d +8*7
       /* RID list failed Limit   QW0316RT */
       rid_limit= c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* RID list failed Storage  QW0316RS */
       rid_stor = c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       ssid_sql = SUBSTR(InpRec,OFFSET_d,8)
       offset_d = offset_d +80+4+8
       /* QW0316ST*/
       sql_stmt = '"' !! SUBSTR(InpRec,OFFSET_d,64) !! '"'
       /* remplace low value par blanc */
       x = 1
       tcar=' 0123456789+-ABCDEFGHIJKLMNOPQRSTUVXWYZ',
         'abcdefghijklmnopqrstuvwxyz.,_'
       do until x > 64
          car = substr(sql_stmt,x,1)
          zz=pos(car,tcar)
          /* replace bad characters by space */
          if zz = 0 then sql_stmt= overlay(' ',sql_stmt,x)
          x=x+1
       end
       sql_stmt = space(sql_stmt,1)
       return
QW0401:
       SQLType='ST'
       offset_save=offset
       /* offset= offset of self definition section*/
       /* offset= offset + 8 : bypass pointer to Product  Section*/
       /* Pointer 4 bytes + Len 2 bytes + Repeat factor 2 bytes  */
       offset=offset+4+2+2 /*pointer to data section 1*/
       /*take the contents pointed by the offset */
       offset_d= C2D(SUBSTR(InpRec,OFFSET,4))
       offset_d=offset_d -4+1
       /* offset_QW0401 will be used later */
       /* offset_d of the ifcid data for use later*/
       offset_ifc=offset_d
       /*offset_d points to the IFCID 401 data to process */
       offset = offset +4
       /* length of data section*/
       len     = C2D(SUBSTR(InpRec,OFFSET,2))
       offset = offset +2
       /* How many  data section ?*/
       repeat  = C2D(SUBSTR(InpRec,OFFSET,2))
       say 'repeat data section401=' repeat
       offset = offset +2
    /*   say 'offset 401/len/rep' offset_d len repeat
         say 'ifc401='
         say SUBSTR(InpRec,OFFSET_d,100)
         say SUBSTR(InpRec,OFFSET_d+101,100)
         say SUBSTR(InpRec,OFFSET_d+201,100)
         say SUBSTR(InpRec,OFFSET_d+301,100) */
       StmtId =C2D(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* nbr execs */
       nbr_execs =c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* nbr reads */
       nbr_reads =c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* nbr gp    */
       nbr_gp =c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* nbr examined rows */
       nbr_ER =c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* nbr rows Processed */
       nbr_pr =c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* nbr sorts */
       nbr_sort =c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* nbr ix scans */
       nbr_ixscan =c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* nbr TS scans*/
       nbr_tsscan =c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* nbr buffer writes*/
       nbr_syncwr =c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* nbr Parallel groups created*/
       nbr_PG =c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* db2 elapsed   */
       elapse   = c2x(SUBSTR(InpRec,OFFSET_d,8))
       elapse   = x2d(substr(elapse,1,13))
       elapse   = elapse  /1000000
       offset_d = offset_d +8
       /* db2 cpu (including ziip) */
       cputime  = c2x(SUBSTR(InpRec,OFFSET_d,8))
       cputime  = x2d(substr(cputime,1,13))
       cputime  = cputime /1000000
       offset_d = offset_d +8
       /* wait time for sync IO    */
       wait_sio = c2x(SUBSTR(InpRec,OFFSET_d,8))
       wait_sio = x2d(substr(wait_sio,1,13))
       wait_sio = wait_sio/1000000
       offset_d = offset_d +8 * 6
       /* RID list failed Limit    */
       rid_limit= c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       /* RID list failed Storage  */
       rid_stor = c2d(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8*6
       pkg_token= c2x(SUBSTR(InpRec,OFFSET_d,8))
       offset_d = offset_d +8
       QW0401CL_Off=C2D(SUBSTR(InpRec,offset_d,2))
       QW0401CL_Off=QW0401CL_Off + offset_ifc
       len=C2D(SUBSTR(InpRec,QW0401CL_Off,2))
       Collid      =SUBSTR(InpRec,QW0401CL_Off+2,len)
       offset_d = offset_d +2
       QW0401PK_Off=C2D(SUBSTR(InpRec,offset_d,2))
       QW0401PK_Off=QW0401PK_Off + offset_ifc
       len=C2D(SUBSTR(InpRec,QW0401PK_Off,2))
       /* package name */
       Pgm_name    =SUBSTR(InpRec,QW0401PK_Off+2,len)
       offset_d = offset_d +2
       tunits=SUBSTR(InpRec,offset_d,8)
       /* QW0401TM2 timestamp */
       call stck tunits
       say timestamp  Tsdate tstime
       offset_d = offset_d +8
       offset_d = offset_d +10
       tunits=SUBSTR(InpRec,offset_d,8)
       call stck tunits
       say timestamp  Tsdate tstime
       offset_d = offset_d +8
return
 
/* MAP  PRODUCT SECTION */
DSNDQWHS:
  QWHSLEN = C2D(SUBSTR(InpRec,OFFSET,2))
  /* go to the next prod section header  */
  if qwhslen < prod_len  then
              offset_corr = offset + qwhslen
        else
              offset_corr = 0
 
  OFFSET = OFFSET + 2
  QWHSTYP = C2D(SUBSTR(InpRec,OFFSET,1))
   /* say 'header len' QWHSLEN, */
   /*     'header type' QWHSTYP */
  OFFSET = OFFSET + 2
  /* QWHSIID DS XL2 IFCID */
  QWHSIID = C2D(SUBSTR(InpRec,OFFSET,2))
  IFCID=QWHSIID
  OFFSET = OFFSET + 2
  QWHSNSDA =C2D(SUBSTR(InpRec,OFFSET,1))
  OFFSET = OFFSET + 6
  /* QWHSSSID DS CL4 SUBSYSTEM NAME */
  QWHSSSID = SUBSTR(InpRec,OFFSET,4)
  OFFSET = OFFSET + 47
  /* QWHSSID MVS NAME */
  QWHSSID = SUBSTR(InpRec,OFFSET,4)
  /* TOTAL LENGTH = 86 */
 
  RETURN
 
DSNDQWHD: /* MAP distributed header */
    arg ofs_header
    ofs= ofs_header            + 4 /* skip len + type */
    /* requester location */
    QWHDRQNM = SUBSTR(InpRec,ofs,16)
    QWHDRQNM = strip(QWHDRQNM)
    ofs= ofs + 24
    QWHDSVNM = SUBSTR(InpRec,ofs,16)
    ofs= ofs + 16
    QWHDPRID = SUBSTR(InpRec,ofs,8)
  return
/* correlation header QWHCTYP = 2 */
DSNDQWHC:
  arg offs
  QWHCLEN = C2D(SUBSTR(InpRec,offs,2))
  offs = offs + 2
  QWHCTYP = C2D(SUBSTR(InpRec,offs,1))
  /* process type 2 only */
  if QWHCTYP >< 2 then return
  /* process type 2 product header */
  offs = offs + 2
  /* authid */
  QWHCAID      = SUBSTR(InpRec,offs,8)
  QWHCAID      = strip(QWHCAID)
  offs = offs + 8
  /* corrid */
  QWHCCV  = SUBSTR(InpRec,offs,12)
  QWHCCV  = strip(QWHCCV)
  offs = offs + 12
  /* Connid */
  QWHCCN = SUBSTR(InpRec,offs,8)
  QWHCCN = strip(QWHCCN)
  offs = offs + 8
  /* QWHCPLAN DS CL8 PLAN NAME */
  QWHCPLAN = SUBSTR(InpRec,offs,8)
  QWHCPLAN = strip(QWHCPLAN)
  offs = offs + 8
  /* QWHCOPID  initial  authid */
  QWHCOPID  = SUBSTR(InpRec,offs,8)
  QWHCOPID = strip(QWHCOPID)
  offs = offs + 8
  /* QWHCATYP  Type de connection*/
  QWHCATYP  = C2D(SUBSTR(InpRec,offs,4))
      Select
           When QWHCATYP  = 4  Then do
                                        conntype='CICS'
                                    end
           When QWHCATYP  = 2  Then do
                                        conntype='DB2CALL'
                /* direct call inside program (used by software ..      )*/
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
 
 
  offs = offs + 28
  if conntype =  'DRDA' then
  do
    /* QWHCEUID  end userid */
    QWHCEUID  = SUBSTR(InpRec,offs,16)
    QWHCEUID  = strip(QWHCEUID)
    offs = offs + 48
    /* QWHCEUWN  user workstation name */
    QWHCEUWN  = SUBSTR(InpRec,offs,18)
    QWHCEUWN  = strip(QWHCEUWN)
  end
  else do
    QWHCEUID  = ''
    QWHCEUWN  = ''
  end
  return
 
GET_FMT_TIME:
  RUN_HH = sm102TME % 360000
  RUN_HH = RIGHT(RUN_HH,2,'0')
  RUN_MIN = sm102TME % 6000 - RUN_HH*60
  RUN_MIN = RIGHT(RUN_MIN,2,'0')
  RUN_SEC = sm102TME % 100 - RUN_HH *3600 - RUN_MIN*60
  RUN_SEC = RIGHT(RUN_SEC,2,'0')
  RUN_FMT_TIME = RUN_HH!!':'!!RUN_MIN!!':'!!RUN_SEC
  RETURN
 
write_header:
  if EDM           = 'Y' then
  do
    say 'CSV file ' oufC     ' will be produced'
    queue "Lpar,ssid,date,time,Hour,",
           "Ifcid,Rqtype,DBID,DBCalls,PLan,CTCalls,Loc,Collid,Pack,",
           "ConToken,PTCalls"
 
    "EXECIO" queued() "DISKW OUFC"
  end
  if IFC376='Y'          then
  do
    say 'CSV file ' oufC     ' will be produced'
    queue "Lpar;ssid;date;time;",
           "Fntype;StmNo;Plan;StmId;StmType;SectNo;Collid;Pack;",
           "Version;ConToken;IncParms;SqlTxt;Authid;Corrid;",
           "Connid;Conntype;"
 
    "EXECIO" queued() "DISKW OUFC"
  end
  if IFC361  = 'Y' then
  do
    say 'CSV file ' oufC     ' will be produced'
    queue "Lpar;ssid;date;time;Hour;",
           "Authid;Corrid;Connid;Plan;Conntype;InitialUser;",
           "WrkStation;ReqLoc;",
           "AuthorityType;AuthidType;AuthUse;PrivChked;ObjType;",
           "Obj;More;"
 
    "EXECIO" queued() "DISKW OUFC"
  end
  if IFC224  = 'Y' then
  do
    say 'CSV file ' oufC     ' will be produced'
    queue "Lpar,ssid,date,time,Hour,",
           "NbCols,Pgm"
 
    "EXECIO" queued() "DISKW OUFC"
  end
  if IFC342  = 'Y' then
  do
    say 'CSV file ' oufC     ' will be produced'
    queue "Lpar,ssid,date,time,Hour,",
           "Type,DBID,PSID,CurKB,MaxKB,AgentTok"
 
    "EXECIO" queued() "DISKW OUFC"
  end
  if db2_cmd = 'Y' then
  do
    say 'CSV file ' oufC     ' will be produced'
    queue "Lpar,ssid,date,time,Hour,",
           "CmdTxt,Authid,Corrid,Connid,"
 
    "EXECIO" queued() "DISKW OUFC"
  end
  if Bind    = 'Y' then
  do
    say 'CSV file ' oufC     ' will be produced'
    queue "Lpar,ssid,date,time,Hour,",
       "PLan,BindType,Exp,Owner,Type,Pack,rc,Authid,Corrid,Connid,"
 
    "EXECIO" queued() "DISKW OUFC"
  end
  if IFC314  = 'Y' then
  do
    say 'CSV file ' oufC     ' will be produced'
    queue "Lpar,ssid,date,time,Hour,",
       "Param,",
       "RC,Reas,User,UnqObj,ObjQual,Other1,Other2,ObjOwn,Role,",
       "NbDb,Dbname,DBADM,DBimp"
 
    "EXECIO" queued() "DISKW OUFC"
  end
  if DsExt   = 'Y' then
  do
    say 'CSV file ' oufC     ' will be produced'
    queue "Lpar,ssid,date,time,Hour,",
           "DSN,ts,part,PQTY,SQTY,MaxSz,HiAllocB,HiAllocA"
 
    "EXECIO" queued() "DISKW OUFC"
  end
  if stmt_cache = 'Y' ! sql_text = 'Y' then
  do
    say 'CSV file ' oufS     ' will be produced'
    queue "Lpar;ssid;date;time;Hour;",
       "Type;AccuElT;Cpu;Execs;SyncRead;SyncWwr;GP;ExRows;ProcRows;",
       "Sort;IxScan;TsScan;ParaGrp;",
    "RIDLim;RIDStor;PgmName;Collid;PkgToken;StmtID;",
    "Copies;Status;CurrUsrs;TranName;EndUser;WkStation;TbName;SQLTxt;"
 
    "EXECIO" queued() "DISKW OUFS"
 
    /* For  IFCID 317 */
    say 'CSV file ' oufST    ' will be produced (SQL Text Long)'
    say '  SQL Text long limited to 4000 car. Dyn SQL Only (IFID317)'
    queue "Lpar,ssid,date,time,Hour,",
       "StmID,Text,"
 
    "EXECIO" queued() "DISKW OUFSt"
  end
  return
 
 
Write_REPEXT:
 if DSExt= 'Y' then do
    reco= reco+ 1
    /*rows in excel format */
    queue sm102sid  !! ',' !! sm102ssi !! ','  ,
    !! sm102dte     !! ','   ,
    !! run_fmt_time !! ','   ,
    !! run_hh       !! ','   ,
    !! strip(QW0258DS)     !! ',' ,
    !! ts                  !! ',' ,
    !! part                !! ',' ,
    !! QW0258PQ*4          !! ',' ,
    !! QW0258SQ*4          !! ',' ,
    !! QW0258MS*4          !! ',' ,
    !! QW0258HB*4          !! ',' ,
    !! QW0258HA*4          !! ','
 
   "EXECIO" queued() "DISKW OUFC"
 end
return
Write_REPBND:
 if Bind = 'Y' then do
    reco= reco+ 1
    /*rows in excel format */
    queue sm102sid  !! ',' !! sm102ssi !! ','  ,
    !! sm102dte     !! ','   ,
    !! run_fmt_time !! ','   ,
    !! run_hh       !! ','   ,
    !! '"' !! strip(QW0108PN) !! '"'     !! ','   ,
    !! QW0108T      !! ','   ,  /*bind type */
    !! QW0108X      !! ','   ,  /*Explain   */
    !! strip(QW0108OW)     !! ','   ,  /*Owner     */
    !!       QW0108TY      !! ','   ,  /*Type      */
    !! '"' !! strip(QW0108PK) !! '"'     !! ','   ,
    !! ''          !! ','   , /* return code vide */
    !! QWHCAID      !! ','   ,
    !! QWHCCV       !! ','   ,
    !! QWHCCN       !! ','
 
   "EXECIO" queued() "DISKW OUFC"
 end
return
Write_IFC314:
 if IFC314 = 'Y' then do
    reco= reco+ 1
    /*rows in excel format */
    queue sm102sid  !! ',' !! sm102ssi !! ','  ,
    !! sm102dte     !! ','   ,
    !! run_fmt_time !! ','   ,
    !! run_hh       !! ','   ,
    !! QW0314PL     !! ','   ,
    !! QW0314RC     !! ','   ,
    !! QW0314RS     !! ','   ,
    !! QW0314UN     !! ','   ,
    !! QW0314BN     !! ','   ,
    !! QW0314ON     !! ','   ,
    !! QW03141N     !! ','   ,
    !! QW03142N     !! ','   ,
    !! QW0314NN     !! ','   ,
    !! QW0314LN     !! ','   ,
    !! QW0314DS     !! ','   ,
    !! QW0314DN     !! ','   ,
    !! QW0314DA     !! ','   ,
    !! QW0314IM     !! ','
   "EXECIO" queued() "DISKW OUFC"
 end
return
Write_REPBNDRC:
 if Bind = 'Y' then do
    reco= reco+ 1
    /*rows in excel format */
    queue sm102sid  !! ',' !! sm102ssi !! ','  ,
    !! sm102dte     !! ','   ,
    !! run_fmt_time !! ','   ,
    !! run_hh       !! ','   ,
    !! ' '          !! ','   ,
    !! ' '          !! ','   ,
    !! ' '          !! ','   ,
    !! ' '          !! ','   ,
    !! ' '          !! ','   ,
    !! ' '          !! ','   ,
    !! QW0109RC    !! ','   , /* return code */
    !! QWHCAID      !! ','   ,
    !! QWHCCV       !! ','   ,
    !! QWHCCN       !! ','
 
   "EXECIO" queued() "DISKW OUFC"
 end
return
Write_IFC376:
 if IFC376       = 'Y' then do
    reco= reco+ 1
    /*rows in excel format */
    queue sm102sid  !! ';' !! sm102ssi !! ';'  ,
    !! sm102dte     !! ';'   ,
    !! run_fmt_time !! ';'   ,
    !! '"' !! FnTxt !! '"' !! ';'   ,
    !! QW0376SN     !! ';'   ,
    !! QW0376PL     !! ';'   ,
    !! QW0376SI     !! ';'   ,
    !! sqltype      !! ';'   ,
    !! QW0376SE     !! ';'   ,
    !! QW0376PC     !! ';'   ,
    !! QW0376PN     !! ';'   ,
    !! QW0376VN     !! ';'   ,
    !! QW0376TS     !! ';'   ,
    !! QW0376INC    !! ';'   ,
    !! QW0376SQL    !! ';'   ,
    !! QWHCAID      !! ';'   ,
    !! QWHCCV       !! ';'   ,
    !! QWHCCN       !! ';'   ,
    !! Conntype     !! ';'
 
   "EXECIO" queued() "DISKW OUFC"
 end
return
Write_IFC224:
 if IFC224  = 'Y' then do
    reco= reco+ 1
    /*rows in excel format */
    queue sm102sid  !! ',' !! sm102ssi !! ','  ,
    !! sm102dte     !! ','   ,
    !! run_fmt_time !! ','   ,
    !! run_hh       !! ','   ,
    !! QW0224CL     !! ','   ,
    !! strip(QW0224CI)!!'.'!! strip(QW0224PN) !! ','
 
   "EXECIO" queued() "DISKW OUFC"
 end
return
Write_IFC342:
 if IFC342  = 'Y' then do
    reco= reco+ 1
    /*rows in excel format */
    queue sm102sid  !! ',' !! sm102ssi !! ','  ,
    !! sm102dte     !! ','   ,
    !! run_fmt_time !! ','   ,
    !! run_hh       !! ','   ,
    !! QW0342TY     !! ','   ,
    !! QW0342DB     !! ','   ,
    !! QW0342PS     !! ','   ,
    !! QW0342CT     !! ','   ,
    !! QW0342MT     !! ','   ,
    !! QW0342AT
 
   "EXECIO" queued() "DISKW OUFC"
 end
return
Write_IFC030:
 if EDM     = 'Y' then do
    reco= reco+ 1
    /*rows in excel format */
    queue sm102sid  !! ',' !! sm102ssi !! ','  ,
    !! sm102dte     !! ','   ,
    !! run_fmt_time !! ','   ,
    !! run_hh       !! ','   ,
    !! ifcid        !! ','   ,
    !! QW0030ID     !! ','   ,
    !! QW0030DB     !! ','   ,
    !! QW0030DC     !! ','   ,
    !! QW0030PL     !! ','   ,
    !! QW0030CC     !! ','   ,
    !! QW0030LN     !! ','   ,
    !! QW0030CI     !! ','   ,
    !! QW0030PI     !! ','   ,
    !! QW0030CT     !! ','   ,
    !! QW0030GC
 
   "EXECIO" queued() "DISKW OUFC"
 end
return
Write_REPCMD:
 if db2_cmd = 'Y' then do
    reco= reco+ 1
    /*rows in excel format */
    queue sm102sid  !! ',' !! sm102ssi !! ','  ,
    !! sm102dte     !! ','   ,
    !! run_fmt_time !! ','   ,
    !! run_hh       !! ','   ,
    !! '"' !! strip(QW0090CT) !! '"'     !! ','   ,
    !! QWHCAID      !! ','   ,
    !! QWHCCV       !! ','   ,
    !! QWHCCN       !! ','
 
   "EXECIO" queued() "DISKW OUFC"
 end
return
Write_IFC361:
    reco= reco+ 1
    /*rows in excel format */
    queue sm102sid  !! ';' !! sm102ssi !! ';'  ,
    !! sm102dte     !! ';'   ,
    !! run_fmt_time !! ';'   ,
    !! run_hh       !! ';'   ,
    !! QWHCAID      !! ';'   ,
    !! QWHCCV       !! ';'   ,
    !! QWHCCN       !! ';'   ,
    !! QWHCPLAN     !! ';'   ,
    !! conntype     !! ';'   ,
    !! QWHCEUID     !! ';'   ,
    !! QWHCEUWN     !! ';'   ,
    !! QWHDRQNM     !! ';'   ,
    !! QW0361AT     !! ';'   ,
    !! QW0361IT     !! ';'   ,
    !! QW0361ID     !! ';'   ,
    !! QW0361PR     !! ';'   ,
    !! QW0361OT     !! ';'   ,
    !! Obj          !! ';'   ,
    !! QW0361SQ     !! ';'
 
   "EXECIO" queued() "DISKW OUFC"
return
WriRepSQL:
 if repSQL =    'Y'  then do
    reco= reco+ 1
    /*rows in excel format */
    queue sm102sid  !! ';' !! sm102ssi !! ';'  ,
    !! sm102dte     !! ';'   ,
    !! run_fmt_time !! ';'   ,
    !! run_hh       !! ';'   ,
    !! SQLType      !! ';'   ,
    !! Elapse       !! ';'   ,
    !! Cputime      !! ';'   ,
    !! nbr_execs    !! ';'   ,
    !! nbr_reads    !! ';'   ,
    !! nbr_syncwr   !! ';'   ,
    !! nbr_gp       !! ';'   ,
    !! nbr_er       !! ';'   ,
    !! nbr_pr       !! ';'   ,
    !! nbr_sort     !! ';'   ,
    !! nbr_ixscan   !! ';'   ,
    !! nbr_tsscan   !! ';'   ,
    !! nbr_pg       !! ';'   ,
    !! rid_limit    !! ';'   ,
    !! rid_stor     !! ';'   ,
    !! pgm_name     !! ';'   ,
    !! Collid       !! ';'   ,
    !! pkg_token    !! ';'   ,
    !! stmtid       !! ';'   ,
    !! Copies       !! ';'   ,
    !! Status       !! ';'   ,
    !! CurrUsers    !! ';'   ,
    !! tran_name    !! ';'   ,
    !! end_user     !! ';'   ,
    !! wrkstation   !! ';'   ,
    !! table_name   !! ';'   ,
    !! sql_stmt     !! ';'
 
   "EXECIO" queued() "DISKW OUFS"
 end
return
 
WriRepSQLTxt:
 if repSQL =    'Y'  then do
    reco= reco+ 1
    /*rows in excel format */
    queue sm102sid  !! ',' !! sm102ssi !! ','  ,
    !! sm102dte     !! ','   ,
    !! run_fmt_time !! ','   ,
    !! run_hh       !! ','   ,
    !! QW0317ID     !! ','   ,
    !! QW0317TX     !! ','
 
   "EXECIO" queued() "DISKW OUFST"
 end
return
 
 
/* SMF HEADER */
DSNDQWST:
   OFFSET = OFFSET + 1
   /* sm102RTY DS XL1 RECORD TYPE X'66' OR 102 */
   sm102RTY = C2D(SUBSTR(InpRec,OFFSET,1))
   OFFSET = OFFSET + 1
   /* sm102TME DS XL4 TIME SMF MOVED RECORD */
   sm102TME = C2D(SUBSTR(InpRec,OFFSET,4))
   CALL GET_FMT_TIME
   OFFSET = OFFSET + 4
   field    = C2X(SUBSTR(InpRec,OFFSET,4))
     parse value field with 1 . 2 c 3 yy 5 ddd 8 .
     if (c = 0) then
       yyyy = '19'!!yy
     else
       yyyy = '20'!!yy
   sm102dte    = yyyy!!'.'!!ddd
   /* sauvegarde de la date traitee */
   OFFSET = OFFSET + 4
   sm102sid = SUBSTR(InpRec,OFFSET,4)
   OFFSET = OFFSET + 4
   /* sm102SSI DS CL4 SUBSYSTEM ID */
   sm102ssi = SUBSTR(InpRec,OFFSET,4)
   OFFSET = OFFSET + 10
   /* TOTAL LENGTH = 28 */
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
  say ' '
  say 'List of ifcids read in this SMF file :' nbr_ifcid
  say '   Ifcid/Description/Count'
  do i=1 to nbr_ifcid
      Select
           When ifcid_st.i = 04 then
                      ifcid_desc='Trace stop'
           When ifcid_st.i = 05 then
                      ifcid_desc='Trace stop'
           When ifcid_st.i = 22 then
                      ifcid_desc='Mini Bind'
           When ifcid_st.i = 30 then
                      ifcid_desc='EDM Request'
           When ifcid_st.i = 31 then
                      ifcid_desc='EDM Full'
           When ifcid_st.i = 53 then
                      ifcid_desc='End SQL-SQLCA - Processed'
           When ifcid_st.i = 58 then
                      ifcid_desc='End SQL-SQLCA - Processed'
           When ifcid_st.i = 59 then
                      ifcid_desc='Start Fetch'
           When ifcid_st.i = 63 then
                      ifcid_desc='SQL text - Processed'
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
           When ifcid_st.i = 108 then
                      ifcid_desc='Start Bind - Processed'
           When ifcid_st.i = 109 then
                      ifcid_desc='End Bind - Processed '
           When ifcid_st.i = 112 then
                      ifcid_desc='Thread alloc'
           When ifcid_st.i = 143 then
                      ifcid_desc='Audit first Write'
           When ifcid_st.i = 172 then
                      ifcid_desc='DeadLock, timeout'
           When ifcid_st.i = 173 then
                      ifcid_desc='CL2 time'
           When ifcid_st.i = 177 then
                      ifcid_desc='Pkg alloc'
           When ifcid_st.i = 196 then
                      ifcid_desc='Timeout data'
           When ifcid_st.i = 224 then
                      ifcid_desc='Invalid SPROC - Processed'
           When ifcid_st.i = 247 then
                      ifcid_desc='Host variables - Processed'
           When ifcid_st.i = 250 then
                      ifcid_desc='Conn/Rbd/Disc GBP'
           When ifcid_st.i = 254 then
                      ifcid_desc='CF structure cache stats'
           When ifcid_st.i = 258 then
                      ifcid_desc='Dataset extend activity'
           When ifcid_st.i = 261 then
                      ifcid_desc='GBP checkpoint'
           When ifcid_st.i = 262 then
                      ifcid_desc='GBPOOLT Castout'
           When ifcid_st.i = 313 then
                      ifcid_desc='Uncomm. UR'
           When ifcid_st.i = 316 then
                      ifcid_desc='DSC stats -Processed'
           When ifcid_st.i = 317 then
                      ifcid_desc='DSC stats -SQL Text'
           When ifcid_st.i = 337 then
                      ifcid_desc='Lock Escalation'
           When ifcid_st.i = 342 then
                      ifcid_desc='Workfile Usage'
           When ifcid_st.i = 350 then
                      ifcid_desc='SQL text (log) - Processed'
           When ifcid_st.i = 361 then
                      ifcid_desc='Audit Admin authorities'
           When ifcid_st.i = 362 then
                      ifcid_desc='Start/Stop trace with Audit Policies'
           When ifcid_st.i = 366 then
                      ifcid_desc='Incompat.funct.exec. - Processed'
           When ifcid_st.i = 376 then
                      ifcid_desc='Incompat.funct.exec. - Processed'
           When ifcid_st.i = 401 then
                      ifcid_desc='Static SQL stats - Processed'
           When ifcid_st.i = 402 then
                      ifcid_desc='System Profile Stats'
           otherwise
                      ifcid_desc='Unknow'
 
      end   /* select */
     xx= '   ' !! ifcid_st.i !!'/'!!ifcid_desc!!'/' !!ifcid_count.i
     say xx
   end /* end do */
   return
init_var:
  /* compteurs input/output */
  temA=0
  nbr_ifcid = 0
  reco= 0
  reci= 0
  recs= 0
  min_time='23:59:59'
  if repSQL =    'Y'  then call init_sql
  return
init_sql:
    StmtId =-1
    Copies   ='NA'
    Status   ='NA'
    CurrUsers=-1
    tran_name='NA'
    end_user='NA'
    wrkstation='NA'
    table_name='NA'
    sql_stmt='NA'
    pkg_token='NA'
    collid='NA'
  return
 
alloc_file:
  if IFC021  = 'Y' then
  do
       oufl = "'" !! hlq !! '.IFC021' !! "'"
       "DELETE" oufl "PURGE"
 
       "ALLOC DD(OUFC) DS("OUFl") NEW CATALOG REUSE" ,
       "LRECL(500) RECFM(V B) TRACKS SPACE(300,300)"
       rcalloc = rc
       if rcalloc <> 0 then Do
            say "**********************************************"
            say "   Error allocating IFC021 file" rcalloc
            say "   Abnormal end  "
            say "**********************************************"
            Exit 8
       end
  end
  if IFC361  = 'Y' then
  do
       oufl = "'" !! hlq !! '.IFC361' !! "'"
       "DELETE" oufl "PURGE"
 
       "ALLOC DD(OUFC) DS("OUFl") NEW CATALOG REUSE" ,
       "LRECL(500) RECFM(V B) TRACKS SPACE(300,300)"
       rcalloc = rc
       if rcalloc <> 0 then Do
            say "**********************************************"
            say "   Error allocating IFC361 file" rcalloc
            say "   Abnormal end  "
            say "**********************************************"
            Exit 8
       end
  end /* db2_cmd = 'Y' */
  if db2_cmd = 'Y' then
  do
       oufl = "'" !! hlq !! '.REPORT' !! "'"
       "DELETE" oufl "PURGE"
 
       "ALLOC DD(OUFC) DS("OUFl") NEW CATALOG REUSE" ,
       "LRECL(300) RECFM(V B) TRACKS SPACE(50,50)"
       rcalloc = rc
       if rcalloc <> 0 then Do
            say "**********************************************"
            say "   Error allocating REPCMD file" rcalloc
            say "   Abnormal end  "
            say "**********************************************"
            Exit 8
       end
  end /* db2_cmd = 'Y' */
  if IFC224  = 'Y' then
  do
       oufl = "'" !! hlq !! '.IFC224' !! "'"
       "DELETE" oufl "PURGE"
 
       "ALLOC DD(OUFC) DS("OUFl") NEW CATALOG REUSE" ,
       "LRECL(300) RECFM(V B) TRACKS SPACE(50,50)"
       rcalloc = rc
       if rcalloc <> 0 then Do
            say "**********************************************"
            say "   Error allocating IFC224 file" rcalloc
            say "   Abnormal end  "
            say "**********************************************"
            Exit 8
       end
  end /* IFC224  = 'Y' */
  if EDM     = 'Y' then
  do
       oufl = "'" !! hlq !! '.IFC030' !! "'"
       "DELETE" oufl "PURGE"
 
       "ALLOC DD(OUFC) DS("OUFl") NEW CATALOG REUSE" ,
       "LRECL(300) RECFM(V B) TRACKS SPACE(50,50)"
       rcalloc = rc
       if rcalloc <> 0 then Do
            say "**********************************************"
            say "   Error allocating IFC030 file" rcalloc
            say "   Abnormal end  "
            say "**********************************************"
            Exit 8
       end
  end /* EDM     = 'Y' */
  if IFC342  = 'Y' then
  do
       oufl = "'" !! hlq !! '.IFC342' !! "'"
       "DELETE" oufl "PURGE"
 
       "ALLOC DD(OUFC) DS("OUFl") NEW CATALOG REUSE" ,
       "LRECL(200) RECFM(V B) TRACKS SPACE(50,50)"
       rcalloc = rc
       if rcalloc <> 0 then Do
            say "**********************************************"
            say "   Error allocating IFC342 file" rcalloc
            say "   Abnormal end  "
            say "**********************************************"
            Exit 8
       end
  end /* IFC342  = 'Y' */
  if IFC376=        'Y' then
  do
       oufl = "'" !! hlq !! '.IFC376'  !! "'"
       "DELETE" oufl "PURGE"
 
       "ALLOC DD(OUFC) DS("OUFl") NEW CATALOG REUSE" ,
       "LRECL(300) RECFM(V B) TRACKS SPACE(50,50)"
       rcalloc = rc
       if rcalloc <> 0 then Do
            say "**********************************************"
            say "   Error allocating IFC3X6 file" rcalloc
            say "   Abnormal end  "
            say "**********************************************"
            Exit 8
       end
  end /* IFC3X6  = 'Y' */
  if IFC314  = 'Y' then
  do
       oufl = "'" !! hlq !! '.REPORT.IFC314' !! "'"
       "DELETE" oufl "PURGE"
 
       "ALLOC DD(OUFC) DS("OUFl") NEW CATALOG REUSE" ,
       "LRECL(500) RECFM(V B) TRACKS SPACE(50,50)"
       rcalloc = rc
       if rcalloc <> 0 then Do
            say "**********************************************"
            say "   Error allocating IFC314 file" rcalloc
            say "   Abnormal end  "
            say "**********************************************"
            Exit 8
       end
  end
  if Bind    = 'Y' then
  do
       oufl = "'" !! hlq !! '.REPORT.BND' !! "'"
       "DELETE" oufl "PURGE"
 
       "ALLOC DD(OUFC) DS("OUFl") NEW CATALOG REUSE" ,
       "LRECL(300) RECFM(V B) TRACKS SPACE(50,50)"
       rcalloc = rc
       if rcalloc <> 0 then Do
            say "**********************************************"
            say "   Error allocating REPCMD file" rcalloc
            say "   Abnormal end  "
            say "**********************************************"
            Exit 8
       end
  end /* Bind    = 'Y' */
  if DsExt   = 'Y' then
  do
       oufl = "'" !! hlq !! '.REPORT.XTD' !! "'"
       "DELETE" oufl "PURGE"
 
       "ALLOC DD(OUFC) DS("OUFl") NEW CATALOG REUSE" ,
       "LRECL(300) RECFM(V B) TRACKS SPACE(50,50)"
       rcalloc = rc
       if rcalloc <> 0 then Do
            say "**********************************************"
            say "   Error allocating REPCMD file" rcalloc
            say "   Abnormal end  "
            say "**********************************************"
            Exit 8
       end
  end /* DsEXT   = 'Y' */
 
  if repSQL =    'Y'  then
  do
       /* Report dataset on output */
       oufs = "'" !! hlq !! '.REPORT.SQL' !! "'"
       "DELETE" oufS "PURGE"
 
       "ALLOC FI(OUFs) DA("oufs") NEW CATALOG REUSE" ,
       "LRECL(300) RECFM(V B) TRACKS SPACE(50,50)"
       rcalloc = rc
       if rcalloc <> 0 then Do
            say "**********************************************"
            say "   Error allocating repSQL file" rcalloc
            say "   Abnormal end  "
            say "**********************************************"
            Exit 8
       End
       /* Report sqltext (longer text ) IFCID317 */
       oufst= "'" !! hlq !! '.REPORT.SQLL' !! "'"
       "DELETE" oufSt "PURGE"
 
       "ALLOC FI(OUFst) DA("oufst") NEW CATALOG REUSE" ,
       "LRECL(4010) RECFM(V B) TRACKS SPACE(50,50)"
       rcalloc = rc
       if rcalloc <> 0 then Do
            say "**********************************************"
            say "   Error allocating repSQLL file" rcalloc
            say "   Abnormal end  "
            say "**********************************************"
            Exit 8
       end
  end /* stmt_cache    */
 
  RETURN
close_all:
  if repSQL =    'Y'  then
  do
    "EXECIO" queued() "DISKW OUFs ( FINIS"
    "FREE DD(OUFs)"
    "EXECIO" queued() "DISKW OUFst ( FINIS"
    "FREE DD(OUFst)"
  end
  if db2_cmd='Y' then
  do
    "EXECIO" queued() "DISKW OUFC ( FINIS"
    "FREE DD(OUFC)"
  end
  "EXECIO 0 DISKR oufi (STEM INL. FINIS"
  "FREE DD(oufi)"
  return
/* correlation header */
DSNDQWHC:
  arg ofs
  QWHCLEN = C2D(SUBSTR(InpRec,ofs,2))
  ofs = ofs + 2
  QWHCTYP = C2D(SUBSTR(InpRec,ofs,1))
  ofs = ofs + 2
  /* authid */
  QWHCAID      = SUBSTR(InpRec,ofs,8)
  ofs = ofs + 8
  QWHCCV  = SUBSTR(InpRec,ofs,12)
  ofs = ofs + 12
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
                /* direct call inside program (used by software ..      )*/
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
stck:
Arg TUNITS
  TIMESTAMP = Copies(0,26)  /* force result length=26 */
  Address linkpgm "BLSUXTOD TUNITS TIMESTAMP"
  /* variable Timestamp has the value of timestamp */
  TSDate=substr(timestamp,1,10)
  TSTime=substr(timestamp,12,08)
  return

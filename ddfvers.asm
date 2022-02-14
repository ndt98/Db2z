BAL      OPSYN     BAS
BALR     OPSYN     BASR
DDFVERS START      0
*----------------------------------------------------------*
* 20 Oct 2021                                              *
*----------------------------------------------------------*
* Program     : DDFVERS                                   -*
* Written on  : 20.10.2021                                -*
* Author      : Nguyen Duc Tuan                           -*
* DESCRIPTION : Select 101 DDF DB2 Connect version        -*
* R1   System can't used                                  -*
* R4   Smf record read                                    -*
* R5   Self Def                                           -*
* R6   Branch return register                             -*
* R7   Active macro                                       -*
* R8/9 Read/write counters                                -*
* R10  TOT CPU                                            -*
* R12-15 Reserved                                         -*
*----------------------------------------------------------*
BEGIN    SAVE  (14,12)
         BALR  3,0
         USING *,3
         ST    13,SAVE+4
         LA    13,SAVE
*
         OPEN      (SMFIN,INPUT)   OPEN INPUT OUTPUT
         OPEN      (OUTDD,OUTPUT)
         SR        8,8               0=>R8 READ COUNT
         SR        9,9               0=>R9 WR COUNT
         MVC       OCOM1,=C','       For output
         MVC       OCOM2,=C','
         MVC       OCOM3,=C','
         MVC       OCOM4,=C','
         MVC       OCOM5,=C','
*----------------------------------------------------------*
*- MAIN PROGRAM                                           -*
*----------------------------------------------------------*
READON   DS        0H
         BAL       6,READREC          READ RECORD
         BAL       6,SELREC           SELECT RECORD
         B         READON             GET NEXT RECORD
*
*                                                END OF FILE
ENDFILE  DS        0H
*
*  formatage Total records read
         CVD   8,DBLWORD
         MVC   TOTRD,MASK10DG
* D = 8 caracteres , mais la zone edition est sur 10 chiffres
* 8 caracteres  = 16 chiffres, il faut donc avancer de 3 pour
* editer que sur 10 chiffres
         ED    TOTRD,DBLWORD+3
         MVC   PRTTXT,=CL18'SMF RECORDS READ :'
         MVC   PRTVAL,TOTRD
         MVC   PRTVAL+10,=CL7'       '
         WTO   MF=(E,WTOBLOC2),ROUTCDE=11 DISPLAY WTOBLOC2
*  formattage & Display Total records selected
         CVD   9,DBLWORD
         MVC   TOTWR,MASK10DG
         ED    TOTWR,DBLWORD+3
         MVC   PRTTXT,=CL18'RECORDS SELECTED :'
         MVC   PRTVAL,TOTWR
         MVC   PRTVAL+10,=CL7'       '
         WTO   MF=(E,WTOBLOC2),ROUTCDE=11 DISPLAY WTOBLOC2
*
         CLOSE     (SMFIN)   CLOSE FILES
         CLOSE     (OUTDD)
         L     13,SAVE+4
         LM    14,12,12(13)
         SR    15,15
         BR    14            R14 = RETURNED ADDRESS
*----------------------------------------------------------*
*- READREC ROUTINE                                        -*
*----------------------------------------------------------*
READREC  DS        0H
         USING     SM101,4     SET UP ADDR.ABILITY
         GET       SMFIN       GET RECORD LOCATE MODE (READ)
         LR        4,1         LOAD R4 WITH RECORD
         A         8,=F'1'     Increment R8 by 1 (Read count)
         BR        6           retour
*----------------------------------------------------------*
*- SELECT SMF RECORD                                      -*
*----------------------------------------------------------*
SELREC   CLI       SM101RTY,X'65'       IS THIS SMF101 ?
         BNE       FNSELREC             NO
* smf 101 here
         CLC       SM101STF,=X'0000'    subtype 0 ? (no pack records)
         BNE       FNSELREC             Not a right SMF101
* Select SSID
*        CLC       SM101SSI,=CL4'DBP9'   Db2 Name
*        BNE       FNSELREC
* Begin processing
* Here is the map (from DSNDQWAS)
*   QWHS    DSNDQWHS   *  STANDARD HEADER ALWAYS PRESENT
*    QWHC    DSNDQWHC  *  CORRELATION HEADER PRESENT ON ACCOUNTING
*    QWHT    DSNDQWHT  *  TRACE HEADER MAY APPEAR
*    QWHU    DSNDQWHU  *  CPU HEADER MAY APPEAR
*    QWHD    DSNDQWHD  *  DISTRIBUTED HEADER PRESENT ON ACCOUNTING
*    QWHA    DSNDQWHA  *  DATA SHARING HEADER
         LA        5,SM101END      Adresse de debut self-def
         USING     QWA0,5           --> Self def-Section
         L         7,QWA01PSO      QWA01PSO est un Offset par rapport
         AR        7,4             au debut du record, pour avoir
*                                  adresse absolue ajouter R4
* ------- QWHS
         USING     QWHS,7           --> Std header  puis Corr header
* Select Plan ? CorrelId ? Conntype
*        LA        7,QWHSEND       Adresse Correlation header
         AH        7,QWHSLEN
*                                  juste apres standard header
* ------- QWHC
         USING     QWHC,7           --> adressabilite
         CLC       QWHCATYP,=F'8'   CONNTYPE DDF ONLY
         BNE       FNSELREC
         MVC       OWHCAID,QWHCAID User Id
         AH        7,QWHCLEN
* ------- QWHC
         USING     QWHS,7           --> After standated Corr header
*                                   looking for DDF header
FCORR    DS  0H
* -- Debut display
*        MVC   PRTTXT,=CL18'TYPE             >'
*        MVC   PRTVAL,QWHSTYP
*        WTO   MF=(E,WTOBLOC2),ROUTCDE=11 DISPLAY WTOBLOC2
* -- fin display
         CLC       QWHSTYP,=X'10'    Is this distributed header ?
         BE        FCONT
         AH        7,QWHSLEN
         USING     QWHS,7
         B         FCORR
FCONT    DS 0H
         USING     QWHD,7    Distributed header
         MVC       OWHDRQNM,QWHDRQNM
         MVC       OWHDPRID,QWHDPRID
         DROP      7             Plus besoin
         ICM       1,15,SM101TME        Use R1 for time conversion
         BAS       14,CNVTIME           Branch to convert time
         MVC       OTIME,WORKTIME+2
         MVC       OSSID,SM101SSI
         PUT       OUTDD,OUTREC
         A         9,=F'1'        Increment R9 by 1
         B         FNSELREC
FNSELREC BR        6
*******************************
*                             *
*Convert time to HH:MM:SS     *
*                             *
*******************************
CNVTIME  BAKR      14,0            Save Contents of R14
         SLR       0,0             Subtract Register
*                                  R1-> time in 100th of sec
         D         0,=F'360000'    Get hours
         CVD       1,DBLWORD       Convert to decimal
         SRP       DBLWORD,4,0     000000000HH0000C
         ZAP       WTIME,DBLWORD   Save it for later
         LR        1,0            Get reminder
         SLR       0,0
         D         0,=F'6000'    Get minutes
         CVD       1,DBLWORD     Convert to decimal
         SRP       DBLWORD,2,0    00000000000MM00C
         AP        WTIME,DBLWORD  Add to saved time
         LR        1,0          Get reminder
         SLR       0,0
         D         0,=F'100'     Get seconds
         CVD       1,DBLWORD     Convert to decimal
         AP        WTIME,DBLWORD  Add to saved time
         MVC       WORKTIME,EDMASKT   Move edit mask for time
         ED        WORKTIME,WTIME+4   edit time
CNVT£999 PR                      goback
*----------------------------------------------------------*
*       ZONES POUR EDITION                                 *
*----------------------------------------------------------*
MASK10DG DC        X'40202020202020202020' MASK 10 DIGITS
TOTRD    DS        CL10             NBR RECORDS READ
TOTWR    DS        CL10             NBR RECORDS WRITTEN
         DS        0H               HALF WORD ALIGNMENT
WTOBLOC2 DC        H'39'      18+17+4
         DC        H'0'
PRTTXT   DS        CL18
PRTVAL   DS        CL17
*----------------------------------------------------------*
*- FILE SECTION                                           -*
*----------------------------------------------------------*
*----------------------------------------------------------*
SMFIN    DCB   DDNAME=SMFIN,                                           X
               DSORG=PS,                                               X
               MACRF=GL,                                               X
               EODAD=ENDFILE,                                          X
               BFTEK=A,                                                X
               RECFM=VBS,BUFNO=20
OUTDD    DCB   DDNAME=OUTDD,                                           X
               DSORG=PS,                                               X
               MACRF=PM,                                               X
               LRECL=49,                                               X
               RECFM=FB,                                               X
               BLKSIZE=0
*----------------------------------------------------------*
*- WORKING STORAGE SECTION                                -*
*----------------------------------------------------------*
SAVE     DS        18F
EDMASKT  DC        X'402120207A20207A2020' Edit mask for time
         DS        D
DBLWORD  DS        D   work
WTIME    DS        D   work time
WORKTIME DS        CL(L'EDMASKT) work area
BEGINW   DS    0H
         DC        CL8'>>>>>>>>'
OUTREC   DS  0CL49
OSSID    DS  CL4
OCOM1    DS  CL1
OTIME    DS  CL8
OCOM2    DS  CL1
OWHCAID  DS  CL8
OCOM3    DS  CL1
OWHDRQNM DS  CL16
OCOM4    DS  CL1
OWHDPRID DS  CL8
OCOM5    DS  CL1
         DC        CL8'<<<<<<<<'
*----------------------------------------------------------*
*- DSECT/MACRO     SECTION                                -*
*----------------------------------------------------------*
SMFTYPDA DS        0H
         DSNDQWAS  DSECT=YES,SUBTYPE=
DDFVERS CSECT
SELFDEFS DS        0H
         DSNDQWA0  DSECT=YES Self defined
DDFVERS CSECT
SMFTYPDB DS        0H
         DSNDQWST  DSECT=YES,SUBTYPE=
DDFVERS CSECT
PRODSECT DS        0H  Production Standard header
         DSNDQWHS  DSECT=YES
DDFVERS CSECT
         DS        0H Production Header type 2 for correlation Id
         DSNDQWHC  DSECT=YES
DDFVERS CSECT
         DS        0H Distributed header
         DSNDQWHD  DSECT=YES
DDFVERS CSECT
         DS        0H Accounting ifcid3
         DSNDQWAC  DSECT=YES
DDFVERS CSECT
LAST     DS    CL1
         END       BEGIN

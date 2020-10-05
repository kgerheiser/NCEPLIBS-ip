!> @file
!! INTERPOLATE VECTOR FIELDS (BILINEAR)
!! @author IREDELL @date 96-04-10
!
!> THIS SUBPROGRAM PERFORMS BILINEAR INTERPOLATION
!!           FROM ANY GRID TO ANY GRID FOR VECTOR FIELDS.
!!           OPTIONS ALLOW VARYING THE MINIMUM PERCENTAGE FOR MASK,
!!           I.E. PERCENT VALID INPUT DATA REQUIRED TO MAKE OUTPUT DATA,
!!           (IPOPT(1)) WHICH DEFAULTS TO 50 (IF IPOPT(1)=-1).
!!           ONLY HORIZONTAL INTERPOLATION IS PERFORMED.
!!           THE GRIDS ARE DEFINED BY THEIR GRID DESCRIPTION SECTIONS
!!           (PASSED IN INTEGER FORM AS DECODED BY SUBPROGRAM W3FI63).
!!           THE CURRENT CODE RECOGNIZES THE FOLLOWING PROJECTIONS:
!!             (KGDS(1)=000) EQUIDISTANT CYLINDRICAL
!!             (KGDS(1)=001) MERCATOR CYLINDRICAL
!!             (KGDS(1)=003) LAMBERT CONFORMAL CONICAL
!!             (KGDS(1)=004) GAUSSIAN CYLINDRICAL (SPECTRAL NATIVE)
!!             (KGDS(1)=005) POLAR STEREOGRAPHIC AZIMUTHAL
!!             (KGDS(1)=203) ROTATED EQUIDISTANT CYLINDRICAL (E-STAGGER)
!!             (KGDS(1)=205) ROTATED EQUIDISTANT CYLINDRICAL (B-STAGGER)
!!           WHERE KGDS COULD BE EITHER INPUT KGDSI OR OUTPUT KGDSO.
!!           THE INPUT AND OUTPUT VECTORS ARE ROTATED SO THAT THEY ARE
!!           EITHER RESOLVED RELATIVE TO THE DEFINED GRID
!!           IN THE DIRECTION OF INCREASING X AND Y COORDINATES
!!           OR RESOLVED RELATIVE TO EASTERLY AND NORTHERLY DIRECTIONS,
!!           AS DESIGNATED BY THEIR RESPECTIVE GRID DESCRIPTION SECTIONS.
!!           AS AN ADDED BONUS THE NUMBER OF OUTPUT GRID POINTS
!!           AND THEIR LATITUDES AND LONGITUDES ARE ALSO RETURNED
!!           ALONG WITH THEIR VECTOR ROTATION PARAMETERS.
!!           ON THE OTHER HAND, THE OUTPUT CAN BE A SET OF STATION POINTS
!!           IF KGDSO(1)<0, IN WHICH CASE THE NUMBER OF POINTS
!!           AND THEIR LATITUDES AND LONGITUDES MUST BE INPUT 
!!           ALONG WITH THEIR VECTOR ROTATION PARAMETERS.
!!           INPUT BITMAPS WILL BE INTERPOLATED TO OUTPUT BITMAPS.
!!           OUTPUT BITMAPS WILL ALSO BE CREATED WHEN THE OUTPUT GRID
!!           EXTENDS OUTSIDE OF THE DOMAIN OF THE INPUT GRID.
!!           THE OUTPUT FIELD IS SET TO 0 WHERE THE OUTPUT BITMAP IS OFF.
!!        
!! PROGRAM HISTORY LOG:
!! -  96-04-10  IREDELL
!! - 1999-04-08  IREDELL  SPLIT IJKGDS INTO TWO PIECES
!! - 2001-06-18  IREDELL  INCLUDE MINIMUM MASK PERCENTAGE OPTION
!! - 2002-01-17  IREDELL  SAVE DATA FROM LAST CALL FOR OPTIMIZATION
!! - 2007-05-22  IREDELL  EXTRAPOLATE UP TO HALF A GRID CELL
!! - 2007-10-30  IREDELL  SAVE WEIGHTS AND THREAD FOR PERFORMANCE
!! - 2012-06-26  GAYNO    FIX OUT-OF-BOUNDS ERROR.  SEE NCEPLIBS
!!                      TICKET #9.
!! - 2015-01-27  GAYNO    REPLACE CALLS TO GDSWIZ WITH MERGED VERSION
!!                      OF GDSWZD.
!!
!! @param IPOPT    - INTEGER (20) INTERPOLATION OPTIONS
!!                IPOPT(1) IS MINIMUM PERCENTAGE FOR MASK
!!                (DEFAULTS TO 50 IF IPOPT(1)=-1)
!! @param KGDSI    - INTEGER (200) INPUT GDS PARAMETERS AS DECODED BY W3FI63
!! @param KGDSO    - INTEGER (200) OUTPUT GDS PARAMETERS
!!                (KGDSO(1)<0 IMPLIES RANDOM STATION POINTS)
!! @param MI       - INTEGER SKIP NUMBER BETWEEN INPUT GRID FIELDS IF KM>1
!!                OR DIMENSION OF INPUT GRID FIELDS IF KM=1
!! @param MO       - INTEGER SKIP NUMBER BETWEEN OUTPUT GRID FIELDS IF KM>1
!!                OR DIMENSION OF OUTPUT GRID FIELDS IF KM=1
!! @param KM       - INTEGER NUMBER OF FIELDS TO INTERPOLATE
!! @param IBI      - INTEGER (KM) INPUT BITMAP FLAGS
!! @param LI       - LOGICAL*1 (MI,KM) INPUT BITMAPS (IF SOME IBI(K)=1)
!! @param UI       - REAL (MI,KM) INPUT U-COMPONENT FIELDS TO INTERPOLATE
!! @param VI       - REAL (MI,KM) INPUT V-COMPONENT FIELDS TO INTERPOLATE
!! @param[out] NO       - INTEGER NUMBER OF OUTPUT POINTS (ONLY IF KGDSO(1)<0)
!! @param[out] RLAT     - REAL (NO) OUTPUT LATITUDES IN DEGREES (IF KGDSO(1)<0)
!! @param[out] RLON     - REAL (NO) OUTPUT LONGITUDES IN DEGREES (IF KGDSO(1)<0)
!! @param[out] CROT     - REAL (NO) VECTOR ROTATION COSINES (IF KGDSO(1)<0)
!! @param[out] SROT     - REAL (NO) VECTOR ROTATION SINES (IF KGDSO(1)<0)
!!                (UGRID=CROT*UEARTH-SROT*VEARTH;
!!                 VGRID=SROT*UEARTH+CROT*VEARTH)
!! @param[out] IBO      - INTEGER (KM) OUTPUT BITMAP FLAGS
!! @param[out] LO       - LOGICAL*1 (MO,KM) OUTPUT BITMAPS (ALWAYS OUTPUT)
!! @param[out] UO       - REAL (MO,KM) OUTPUT U-COMPONENT FIELDS INTERPOLATED
!! @param[out] VO       - REAL (MO,KM) OUTPUT V-COMPONENT FIELDS INTERPOLATED
!! @param[out] IRET     - INTEGER RETURN CODE
!!                0    SUCCESSFUL INTERPOLATION
!!                2    UNRECOGNIZED INPUT GRID OR NO GRID OVERLAP
!!                3    UNRECOGNIZED OUTPUT GRID
!!
!! SUBPROGRAMS CALLED:
!! -  GDSWZD       GRID DESCRIPTION SECTION WIZARD
!! -  IJKGDS0      SET UP PARAMETERS FOR IJKGDS1
!! -  (IJKGDS1)    RETURN FIELD POSITION FOR A GIVEN GRID POINT
!! -  (MOVECT)     MOVE A VECTOR ALONG A GREAT CIRCLE
!! -  POLFIXV      MAKE MULTIPLE POLE VECTOR VALUES CONSISTENT
!!
SUBROUTINE POLATEV0(IPOPT,KGDSI,KGDSO,MI,MO,KM,IBI,LI,UI,VI, &
     NO,RLAT,RLON,CROT,SROT,IBO,LO,UO,VO,IRET)
  USE GDSWZD_MOD
!
 IMPLICIT NONE
!
 INTEGER,            INTENT(IN   ):: IPOPT(20),IBI(KM),MI,MO,KM
 INTEGER,            INTENT(IN   ):: KGDSI(200),KGDSO(200)
 INTEGER,            INTENT(INOUT):: NO
 INTEGER,            INTENT(  OUT):: IRET, IBO(KM)
!
 LOGICAL*1,          INTENT(IN   ):: LI(MI,KM)
 LOGICAL*1,          INTENT(  OUT):: LO(MO,KM)
!
 REAL,               INTENT(IN   ):: UI(MI,KM),VI(MI,KM)
 REAL,               INTENT(INOUT):: RLAT(MO),RLON(MO),CROT(MO),SROT(MO)
 REAL,               INTENT(  OUT):: UO(MO,KM),VO(MO,KM)
!
 REAL,               PARAMETER    :: FILL=-9999.
!
 INTEGER                          :: IJX(2),IJY(2),IJKGDSA(20)
 INTEGER                          :: MP,N,I,J,K,NK,NV,IJKGDS1
 INTEGER,                    SAVE :: KGDSIX(200)=-1,KGDSOX(200)=-1
 INTEGER,                    SAVE :: NOX=-1,IRETX=-1
 INTEGER,        ALLOCATABLE,SAVE :: NXY(:,:,:)
!
 REAL                             :: CM,SM,UROT,VROT
 REAL,           ALLOCATABLE      :: DUM1(:),DUM2(:)
 REAL                             :: PMP,XIJ,YIJ,XF,YF,U,V,W
 REAL                             :: XPTS(MO),YPTS(MO)
 REAL                             :: WX(2),WY(2)
 REAL                             :: XPTI(MI),YPTI(MI)
 REAL                             :: RLOI(MI),RLAI(MI)
 REAL                             :: CROI(MI),SROI(MI)
 REAL,           ALLOCATABLE,SAVE :: RLATX(:),RLONX(:)
 REAL,           ALLOCATABLE,SAVE :: CROTX(:),SROTX(:)
 REAL,           ALLOCATABLE,SAVE :: WXY(:,:,:),CXY(:,:,:),SXY(:,:,:)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  SET PARAMETERS
 IRET=0
 MP=IPOPT(1)
 IF(MP.EQ.-1.OR.MP.EQ.0) MP=50
 IF(MP.LT.0.OR.MP.GT.100) IRET=32
 PMP=MP*0.01
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  SAVE OR SKIP WEIGHT COMPUTATION
 IF(IRET.EQ.0.AND.(KGDSO(1).LT.0.OR.ANY(KGDSI.NE.KGDSIX).OR.ANY(KGDSO.NE.KGDSOX))) THEN
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  COMPUTE NUMBER OF OUTPUT POINTS AND THEIR LATITUDES AND LONGITUDES.
   IF(KGDSO(1).GE.0) THEN
     CALL GDSWZD(KGDSO, 0,MO,FILL,XPTS,YPTS,RLON,RLAT,NO,CROT,SROT)
     IF(NO.EQ.0) IRET=3
   ENDIF
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  LOCATE INPUT POINTS
   ALLOCATE(DUM1(NO))
   ALLOCATE(DUM2(NO))
   CALL GDSWZD(KGDSI,-1,NO,FILL,XPTS,YPTS,RLON,RLAT,NV)
   DEALLOCATE(DUM1,DUM2)
   IF(IRET.EQ.0.AND.NV.EQ.0) IRET=2
   CALL GDSWZD(KGDSI, 0,MI,FILL,XPTI,YPTI,RLOI,RLAI,NV,CROI,SROI)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  ALLOCATE AND SAVE GRID DATA
   KGDSIX=KGDSI
   KGDSOX=KGDSO
   IF(NOX.NE.NO) THEN
     IF(NOX.GE.0) DEALLOCATE(RLATX,RLONX,CROTX,SROTX,NXY,WXY,CXY,SXY)
     ALLOCATE(RLATX(NO),RLONX(NO),CROTX(NO),SROTX(NO), &
              NXY(2,2,NO),WXY(2,2,NO),CXY(2,2,NO),SXY(2,2,NO))
     NOX=NO
   ENDIF
   IRETX=IRET
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  COMPUTE WEIGHTS
   IF(IRET.EQ.0) THEN
     CALL IJKGDS0(KGDSI,IJKGDSA)
!$OMP PARALLEL DO PRIVATE(N,XIJ,YIJ,IJX,IJY,XF,YF,J,I,WX,WY,CM,SM)
     DO N=1,NO
       RLONX(N)=RLON(N)
       RLATX(N)=RLAT(N)
       CROTX(N)=CROT(N)
       SROTX(N)=SROT(N)
       XIJ=XPTS(N)
       YIJ=YPTS(N)
       IF(XIJ.NE.FILL.AND.YIJ.NE.FILL) THEN
         IJX(1:2)=FLOOR(XIJ)+(/0,1/)
         IJY(1:2)=FLOOR(YIJ)+(/0,1/)
         XF=XIJ-IJX(1)
         YF=YIJ-IJY(1)
         WX(1)=(1-XF)
         WX(2)=XF
         WY(1)=(1-YF)
         WY(2)=YF
         DO J=1,2
           DO I=1,2
             NXY(I,J,N)=IJKGDS1(IJX(I),IJY(J),IJKGDSA)
             WXY(I,J,N)=WX(I)*WY(J)
             IF(NXY(I,J,N).GT.0) THEN
               CALL MOVECT(RLAI(NXY(I,J,N)),RLOI(NXY(I,J,N)), &
                           RLAT(N),RLON(N),CM,SM)
               CXY(I,J,N)=CM*CROI(NXY(I,J,N))+SM*SROI(NXY(I,J,N))
               SXY(I,J,N)=SM*CROI(NXY(I,J,N))-CM*SROI(NXY(I,J,N))
             ENDIF
           ENDDO
         ENDDO
       ELSE
         NXY(:,:,N)=0
       ENDIF
     ENDDO
   ENDIF  ! IS IRET 0?
 ENDIF
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  INTERPOLATE OVER ALL FIELDS
 IF(IRET.EQ.0.AND.IRETX.EQ.0) THEN
   IF(KGDSO(1).GE.0) THEN
     NO=NOX
     DO N=1,NO
       RLON(N)=RLONX(N)
       RLAT(N)=RLATX(N)
       CROT(N)=CROTX(N)
       SROT(N)=SROTX(N)
     ENDDO
   ENDIF
!$OMP PARALLEL DO PRIVATE(NK,K,N,U,V,W,UROT,VROT,J,I)
   DO NK=1,NO*KM
     K=(NK-1)/NO+1
     N=NK-NO*(K-1)
     U=0
     V=0
     W=0
     DO J=1,2
       DO I=1,2
         IF(NXY(I,J,N).GT.0) THEN
           IF(IBI(K).EQ.0.OR.LI(NXY(I,J,N),K)) THEN
             UROT=CXY(I,J,N)*UI(NXY(I,J,N),K)-SXY(I,J,N)*VI(NXY(I,J,N),K)
             VROT=SXY(I,J,N)*UI(NXY(I,J,N),K)+CXY(I,J,N)*VI(NXY(I,J,N),K)
             U=U+WXY(I,J,N)*UROT
             V=V+WXY(I,J,N)*VROT
             W=W+WXY(I,J,N)
           ENDIF
         ENDIF
       ENDDO
     ENDDO
     LO(N,K)=W.GE.PMP
     IF(LO(N,K)) THEN
       UROT=CROT(N)*U-SROT(N)*V
       VROT=SROT(N)*U+CROT(N)*V
       UO(N,K)=UROT/W
       VO(N,K)=VROT/W
     ELSE
       UO(N,K)=0.
       VO(N,K)=0.
     ENDIF
   ENDDO  ! NK LOOP
   DO K=1,KM
     IBO(K)=IBI(K)
     IF(.NOT.ALL(LO(1:NO,K))) IBO(K)=1
   ENDDO
   IF(KGDSO(1).EQ.0) CALL POLFIXV(NO,MO,KM,RLAT,RLON,IBO,LO,UO,VO)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 ELSE
   IF(IRET.EQ.0) IRET=IRETX
   IF(KGDSO(1).GE.0) NO=0
 ENDIF
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 END SUBROUTINE POLATEV0

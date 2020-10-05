!> @file
!!
!! GDS WIZARD MODULE FOR GAUSSIAN CYLINDRICAL
!! @author GAYNO @date 2015-01-21
!!
!! - CONVERT FROM EARTH TO GRID COORDINATES OR VICE VERSA.
!! - COMPUTE VECTOR ROTATION SINES AND COSINES.
!! - COMPUTE MAP JACOBIANS.
!! - COMPUTE GRID BOX AREA.
!!
!! PROGRAM HISTORY LOG:
!!  - 2015-01-21  GAYNO   INITIAL VERSION FROM A MERGER OF
!!                       ROUTINES GDSWIZ04 AND GDSWZD04.
!!
!! USAGE:  "USE GDSWZD04_MOD"  THEN CALL THE PUBLIC DRIVER
!!         ROUTINE "GDSWZD04".
!!
!!
 MODULE GDSWZD04_MOD
 IMPLICIT NONE

 PRIVATE

 PUBLIC                         :: GDSWZD04

 REAL,            PARAMETER     :: RERTH=6.3712E6
 REAL,            PARAMETER     :: PI=3.14159265358979
 REAL,            PARAMETER     :: DPR=180./PI

 INTEGER                        :: J1, JH

 REAL,            ALLOCATABLE   :: BLAT(:)
 REAL                           :: DLON
 REAL,            ALLOCATABLE   :: YLAT_ROW(:)

 CONTAINS

!$$$  SUBPROGRAM DOCUMENTATION BLOCK
!
! SUBPROGRAM:  GDSWZD04   GDS WIZARD FOR GAUSSIAN CYLINDRICAL
!   PRGMMR: IREDELL       ORG: W/NMC23       DATE: 96-04-10
!
! ABSTRACT: THIS SUBPROGRAM DECODES THE GRIB GRID DESCRIPTION SECTION
!           (PASSED IN INTEGER FORM AS DECODED BY SUBPROGRAM W3FI63)
!           AND RETURNS ONE OF THE FOLLOWING:
!             (IOPT=+1) EARTH COORDINATES OF SELECTED GRID COORDINATES
!             (IOPT=-1) GRID COORDINATES OF SELECTED EARTH COORDINATES
!           FOR GAUSSIAN CYLINDRICAL PROJECTIONS.
!           IF THE SELECTED COORDINATES ARE MORE THAN ONE GRIDPOINT
!           BEYOND THE THE EDGES OF THE GRID DOMAIN, THEN THE RELEVANT
!           OUTPUT ELEMENTS ARE SET TO FILL VALUES.
!           THE ACTUAL NUMBER OF VALID POINTS COMPUTED IS RETURNED TOO.
!           OPTIONALLY, THE VECTOR ROTATIONS, THE MAP JACOBIANS AND
!           THE GRID BOX AREAS MAY BE RETURNED AS WELL.  TO COMPUTE
!           THE VECTOR ROTATIONS, THE OPTIONAL ARGUMENTS 'SROT' AND 'CROT'
!           MUST BE PRESENT.  TO COMPUTE THE MAP JACOBIANS, THE
!           OPTIONAL ARGUMENTS 'XLON', 'XLAT', 'YLON', 'YLAT' MUST BE PRESENT.
!           TO COMPUTE THE GRID BOX AREAS, THE OPTIONAL ARGUMENT
!           'AREA' MUST BE PRESENT.
!
! PROGRAM HISTORY LOG:
!   96-04-10  IREDELL
!   97-10-20  IREDELL  INCLUDE MAP OPTIONS
! 1999-04-08  IREDELL  USE SUBROUTINE SPLAT
! 2001-06-18  IREDELL  CORRECT AREA COMPUTATION
! 2012-08-01  GAYNO    CORRECT AREA COMPUTATION AT POLE.
!                      CORRECT YLAT COMPUTATION.
! 2015-01-21  GAYNO    MERGER OF GDSWIZ04 AND GDSWZD04.  MAKE
!                      CROT,SORT,XLON,XLAT,YLON,YLAT AND AREA
!                      OPTIONAL ARGUMENTS.  MAKE PART OF A MODULE.
!                      MOVE VECTOR ROTATION, MAP JACOBIAN AND GRID
!                      BOX AREA COMPUTATIONS TO SEPARATE SUBROUTINES.
!
! USAGE:    CALL GDSWZD04(KGDS,IOPT,NPTS,FILL,XPTS,YPTS,RLON,RLAT,NRET,
!    &                    CROT,SROT,XLON,XLAT,YLON,YLAT,AREA)
!
!   INPUT ARGUMENT LIST:
!     KGDS     - INTEGER (200) GDS PARAMETERS AS DECODED BY W3FI63
!     IOPT     - INTEGER OPTION FLAG
!                (+1 TO COMPUTE EARTH COORDS OF SELECTED GRID COORDS)
!                (-1 TO COMPUTE GRID COORDS OF SELECTED EARTH COORDS)
!     NPTS     - INTEGER MAXIMUM NUMBER OF COORDINATES
!     FILL     - REAL FILL VALUE TO SET INVALID OUTPUT DATA
!                (MUST BE IMPOSSIBLE VALUE; SUGGESTED VALUE: -9999.)
!     XPTS     - REAL (NPTS) GRID X POINT COORDINATES IF IOPT>0
!     YPTS     - REAL (NPTS) GRID Y POINT COORDINATES IF IOPT>0
!     RLON     - REAL (NPTS) EARTH LONGITUDES IN DEGREES E IF IOPT<0
!                (ACCEPTABLE RANGE: -360. TO 360.)
!     RLAT     - REAL (NPTS) EARTH LATITUDES IN DEGREES N IF IOPT<0
!                (ACCEPTABLE RANGE: -90. TO 90.)
!
!   OUTPUT ARGUMENT LIST:
!     XPTS     - REAL (NPTS) GRID X POINT COORDINATES IF IOPT<0
!     YPTS     - REAL (NPTS) GRID Y POINT COORDINATES IF IOPT<0
!     RLON     - REAL (NPTS) EARTH LONGITUDES IN DEGREES E IF IOPT>0
!     RLAT     - REAL (NPTS) EARTH LATITUDES IN DEGREES N IF IOPT>0
!     NRET     - INTEGER NUMBER OF VALID POINTS COMPUTED
!     CROT     - REAL, OPTIONAL (NPTS) CLOCKWISE VECTOR ROTATION COSINES
!     SROT     - REAL, OPTIONAL (NPTS) CLOCKWISE VECTOR ROTATION SINES
!                (UGRID=CROT*UEARTH-SROT*VEARTH;
!                 VGRID=SROT*UEARTH+CROT*VEARTH)
!     XLON     - REAL, OPTIONAL (NPTS) DX/DLON IN 1/DEGREES
!     XLAT     - REAL, OPTIONAL (NPTS) DX/DLAT IN 1/DEGREES
!     YLON     - REAL, OPTIONAL (NPTS) DY/DLON IN 1/DEGREES
!     YLAT     - REAL, OPTIONAL (NPTS) DY/DLAT IN 1/DEGREES
!     AREA     - REAL, OPTIONAL (NPTS) AREA WEIGHTS IN M**2
!
! EXTERNAL SUBPROGRAMS CALLED:
!   SPLAT      COMPUTE LATITUDE FUNCTIONS
!
! ATTRIBUTES:
!   LANGUAGE: FORTRAN 90
!
!$$$
 SUBROUTINE GDSWZD04(KGDS,IOPT,NPTS,FILL,XPTS,YPTS,RLON,RLAT,NRET, &
                     CROT,SROT,XLON,XLAT,YLON,YLAT,AREA)
 IMPLICIT NONE
!
 INTEGER,         INTENT(IN   ) :: IOPT, KGDS(200), NPTS
 INTEGER,         INTENT(  OUT) :: NRET
!
 REAL,            INTENT(IN   ) :: FILL
 REAL,            INTENT(INOUT) :: RLON(NPTS),RLAT(NPTS)
 REAL,            INTENT(INOUT) :: XPTS(NPTS),YPTS(NPTS)
 REAL, OPTIONAL,  INTENT(  OUT) :: CROT(NPTS),SROT(NPTS)
 REAL, OPTIONAL,  INTENT(  OUT) :: XLON(NPTS),XLAT(NPTS)
 REAL, OPTIONAL,  INTENT(  OUT) :: YLON(NPTS),YLAT(NPTS),AREA(NPTS)
!
 INTEGER                        :: ISCAN, JSCAN, IM, JM
 INTEGER                        :: J, JA, JG
 INTEGER                        :: N
!
 LOGICAL                        :: LROT, LMAP, LAREA
!
 REAL,            ALLOCATABLE   :: ALAT(:), ALAT_JSCAN(:)
 REAL,            ALLOCATABLE   :: ALAT_TEMP(:),BLAT_TEMP(:)
 REAL                           :: HI, RLATA, RLATB, RLAT1, RLON1, RLON2, WB
 REAL                           :: XMAX, XMIN, YMAX, YMIN, YPTSA, YPTSB
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 IF(PRESENT(CROT)) CROT=FILL
 IF(PRESENT(SROT)) SROT=FILL
 IF(PRESENT(XLON)) XLON=FILL
 IF(PRESENT(XLAT)) XLAT=FILL
 IF(PRESENT(YLON)) YLON=FILL
 IF(PRESENT(YLAT)) YLAT=FILL
 IF(PRESENT(AREA)) AREA=FILL
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 IF(KGDS(1).EQ.004) THEN
   IF(PRESENT(CROT).AND.PRESENT(SROT))THEN
     LROT=.TRUE.
   ELSE
     LROT=.FALSE.
   ENDIF
   IF(PRESENT(XLON).AND.PRESENT(XLAT).AND.PRESENT(YLON).AND.PRESENT(YLAT))THEN
     LMAP=.TRUE.
   ELSE
     LMAP=.FALSE.
   ENDIF
   IF(PRESENT(AREA))THEN
     LAREA=.TRUE.
   ELSE
     LAREA=.FALSE.
   ENDIF
   IM=KGDS(2)
   JM=KGDS(3)
   RLAT1=KGDS(4)*1.E-3
   RLON1=KGDS(5)*1.E-3
   RLON2=KGDS(8)*1.E-3
   JG=KGDS(10)*2
   ISCAN=MOD(KGDS(11)/128,2)
   JSCAN=MOD(KGDS(11)/64,2)
   HI=(-1.)**ISCAN
   JH=(-1)**JSCAN
   DLON=HI*(MOD(HI*(RLON2-RLON1)-1+3600,360.)+1)/(IM-1)
   ALLOCATE(ALAT_TEMP(JG))
   ALLOCATE(BLAT_TEMP(JG))
   CALL SPLAT(4,JG,ALAT_TEMP,BLAT_TEMP)
   ALLOCATE(ALAT(0:JG+1))
   ALLOCATE(BLAT(0:JG+1))
   DO JA=1,JG
     ALAT(JA)=DPR*ASIN(ALAT_TEMP(JA))
     BLAT(JA)=BLAT_TEMP(JA)
   ENDDO
   DEALLOCATE(ALAT_TEMP,BLAT_TEMP)
   ALAT(0)=180.-ALAT(1)
   ALAT(JG+1)=-ALAT(0)
   BLAT(0)=-BLAT(1)
   BLAT(JG+1)=BLAT(0)
   J1=1
   DO WHILE(J1.LT.JG.AND.RLAT1.LT.(ALAT(J1)+ALAT(J1+1))/2)
     J1=J1+1
   ENDDO
   IF(LMAP)THEN
     ALLOCATE(ALAT_JSCAN(JG))
     DO JA=1,JG
       ALAT_JSCAN(J1+JH*(JA-1))=ALAT(JA)
     ENDDO
     ALLOCATE(YLAT_ROW(0:JG+1))
     DO JA=2,(JG-1)
       YLAT_ROW(JA)=2.0/(ALAT_JSCAN(JA+1)-ALAT_JSCAN(JA-1))
     ENDDO
     YLAT_ROW(1)=1.0/(ALAT_JSCAN(2)-ALAT_JSCAN(1))
     YLAT_ROW(0)=YLAT_ROW(1)
     YLAT_ROW(JG)=1.0/(ALAT_JSCAN(JG)-ALAT_JSCAN(JG-1))
     YLAT_ROW(JG+1)=YLAT_ROW(JG)
     DEALLOCATE(ALAT_JSCAN)
   ENDIF
   XMIN=0
   XMAX=IM+1
   IF(IM.EQ.NINT(360/ABS(DLON))) XMAX=IM+2
   YMIN=0.5
   YMAX=JM+0.5
   NRET=0
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  TRANSLATE GRID COORDINATES TO EARTH COORDINATES
   IF(IOPT.EQ.0.OR.IOPT.EQ.1) THEN
     DO N=1,NPTS
       IF(XPTS(N).GE.XMIN.AND.XPTS(N).LE.XMAX.AND. &
          YPTS(N).GE.YMIN.AND.YPTS(N).LE.YMAX) THEN
         RLON(N)=MOD(RLON1+DLON*(XPTS(N)-1)+3600,360.)
         J=YPTS(N)
         WB=YPTS(N)-J
         RLATA=ALAT(J1+JH*(J-1))
         RLATB=ALAT(J1+JH*J)
         RLAT(N)=RLATA+WB*(RLATB-RLATA)
         NRET=NRET+1
         IF(LROT) CALL GDSWZD04_VECT_ROT(CROT(N),SROT(N))
         IF(LMAP) CALL GDSWZD04_MAP_JACOB(YPTS(N),&
                                          XLON(N),XLAT(N),YLON(N),YLAT(N))
         IF(LAREA) CALL GDSWZD04_GRID_AREA(YPTS(N),AREA(N))
       ELSE
         RLON(N)=FILL
         RLAT(N)=FILL
       ENDIF
     ENDDO
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  TRANSLATE EARTH COORDINATES TO GRID COORDINATES
   ELSEIF(IOPT.EQ.-1) THEN
     DO N=1,NPTS
       XPTS(N)=FILL
       YPTS(N)=FILL
       IF(ABS(RLON(N)).LE.360.AND.ABS(RLAT(N)).LE.90) THEN
         XPTS(N)=1+HI*MOD(HI*(RLON(N)-RLON1)+3600,360.)/DLON
         JA=MIN(INT((JG+1)/180.*(90-RLAT(N))),JG)
         IF(RLAT(N).GT.ALAT(JA)) JA=MAX(JA-2,0)
         IF(RLAT(N).LT.ALAT(JA+1)) JA=MIN(JA+2,JG)
         IF(RLAT(N).GT.ALAT(JA)) JA=JA-1
         IF(RLAT(N).LT.ALAT(JA+1)) JA=JA+1
         YPTSA=1+JH*(JA-J1)
         YPTSB=1+JH*(JA+1-J1)
         WB=(ALAT(JA)-RLAT(N))/(ALAT(JA)-ALAT(JA+1))
         YPTS(N)=YPTSA+WB*(YPTSB-YPTSA)
         IF(XPTS(N).GE.XMIN.AND.XPTS(N).LE.XMAX.AND. &
            YPTS(N).GE.YMIN.AND.YPTS(N).LE.YMAX) THEN
           NRET=NRET+1
           IF(LROT) CALL GDSWZD04_VECT_ROT(CROT(N),SROT(N))
           IF(LMAP) CALL GDSWZD04_MAP_JACOB(YPTS(N), &
                                            XLON(N),XLAT(N),YLON(N),YLAT(N))
           IF(LAREA) CALL GDSWZD04_GRID_AREA(YPTS(N),AREA(N))
         ELSE
           XPTS(N)=FILL
           YPTS(N)=FILL
         ENDIF
       ENDIF
     ENDDO
   ENDIF
   DEALLOCATE(ALAT, BLAT)
   IF (ALLOCATED(YLAT_ROW)) DEALLOCATE(YLAT_ROW)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  PROJECTION UNRECOGNIZED
 ELSE
   IF(IOPT.GE.0) THEN
     DO N=1,NPTS
       RLON(N)=FILL
       RLAT(N)=FILL
     ENDDO
   ENDIF
   IF(IOPT.LE.0) THEN
     DO N=1,NPTS
       XPTS(N)=FILL
       YPTS(N)=FILL
     ENDDO
   ENDIF
 ENDIF
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 END SUBROUTINE GDSWZD04
!
!
! SUBPROGRAM:  GDSWZD04_VECT_ROT   VECTOR ROTATION FIELDS FOR
!                                  GAUSSIAN CYLINDRICAL GRIDS
!
!   PRGMMR: GAYNO     ORG: W/NMC23       DATE: 2015-01-21
!
! ABSTRACT: THIS SUBPROGRAM COMPUTES THE VECTOR ROTATION SINES AND
!           COSINES FOR A GAUSSIAN CYLINDRICAL GRID.
!
! PROGRAM HISTORY LOG:
! 2015-01-21  GAYNO    INITIAL VERSION
!
! USAGE:    CALL GDSWZD04_VECT_ROT(CROT,SROT)
!
!   INPUT ARGUMENT LIST:
!     NONE
!
!   OUTPUT ARGUMENT LIST:
!     CROT     - CLOCKWISE VECTOR ROTATION COSINES (REAL)
!     SROT     - CLOCKWISE VECTOR ROTATION SINES (REAL)
!                (UGRID=CROT*UEARTH-SROT*VEARTH;
!                 VGRID=SROT*UEARTH+CROT*VEARTH)
!
! ATTRIBUTES:
!   LANGUAGE: FORTRAN 90
!
!$$$
!
 SUBROUTINE GDSWZD04_VECT_ROT(CROT,SROT)
 IMPLICIT NONE

 REAL,                INTENT(  OUT) :: CROT, SROT

 CROT=1.0
 SROT=0.0

 END SUBROUTINE GDSWZD04_VECT_ROT
!
!$$$  SUBPROGRAM DOCUMENTATION BLOCK
!
! SUBPROGRAM:  GDSWZD04_MAP_JACOB  MAP JACOBIANS FOR
!                                  GAUSSIAN CYLINDRICAL GRIDS
!
!   PRGMMR: GAYNO     ORG: W/NMC23       DATE: 2015-01-21
!
! ABSTRACT: THIS SUBPROGRAM COMPUTES THE MAP JACOBIANS FOR
!           A GAUSSIAN CYLINDRICAL GRID.
!
! PROGRAM HISTORY LOG:
! 2015-01-21  GAYNO    INITIAL VERSION
!
! USAGE:  CALL GDSWZD04_MAP_JACOB(YPTS,XLON,XLAT,YLON,YLAT)
!
!   INPUT ARGUMENT LIST:
!     YPTS     - Y-INDEX OF GRID POINT (REAL)
!
!   OUTPUT ARGUMENT LIST:
!     XLON     - DX/DLON IN 1/DEGREES (REAL)
!     XLAT     - DX/DLAT IN 1/DEGREES (REAL)
!     YLON     - DY/DLON IN 1/DEGREES (REAL)
!     YLAT     - DY/DLAT IN 1/DEGREES (REAL)
!
! ATTRIBUTES:
!   LANGUAGE: FORTRAN 90
!
!$$$
 SUBROUTINE GDSWZD04_MAP_JACOB(YPTS, XLON, XLAT, YLON, YLAT)

 IMPLICIT NONE

 REAL,                INTENT(IN   ) :: YPTS
 REAL,                INTENT(  OUT) :: XLON, XLAT, YLON, YLAT

 XLON=1/DLON
 XLAT=0.
 YLON=0.
 YLAT=YLAT_ROW(NINT(YPTS))

 END SUBROUTINE GDSWZD04_MAP_JACOB
!
!$$$  SUBPROGRAM DOCUMENTATION BLOCK
!
! SUBPROGRAM:  GDSWZD04_GRID_AREA  GRID BOX AREA FOR
!                                  GAUSSIAN CYLINDRICAL GRIDS
!
!   PRGMMR: GAYNO     ORG: W/NMC23       DATE: 2015-01-21
!
! ABSTRACT: THIS SUBPROGRAM COMPUTES THE GRID BOX AREA FOR
!           A GAUSSIAN CYLINDRICAL GRID.
!
! PROGRAM HISTORY LOG:
! 2015-01-21  GAYNO    INITIAL VERSION
!
! USAGE:  CALL GDSWZD04_GRID_AREA(YPTS,AREA)
!
!   INPUT ARGUMENT LIST:
!     YPTS     - Y-INDEX OF GRID POINT (REAL)
!
!   OUTPUT ARGUMENT LIST:
!     AREA     - AREA WEIGHTS IN M**2 (REAL)
!
! ATTRIBUTES:
!   LANGUAGE: FORTRAN 90
!
!$$$
 SUBROUTINE GDSWZD04_GRID_AREA(YPTS,AREA)
 IMPLICIT NONE

 REAL,            INTENT(IN   ) :: YPTS
 REAL,            INTENT(  OUT) :: AREA

 INTEGER                        :: J

 REAL                           :: WB, WLAT, WLATA, WLATB

 J = YPTS
 WB=YPTS-J
 WLATA=BLAT(J1+JH*(J-1))
 WLATB=BLAT(J1+JH*J)
 WLAT=WLATA+WB*(WLATB-WLATA)
 AREA=RERTH**2*WLAT*DLON/DPR

 END SUBROUTINE GDSWZD04_GRID_AREA
 
 END MODULE GDSWZD04_MOD

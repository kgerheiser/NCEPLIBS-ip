 FUNCTION IJKGDS1(I,J,IJKGDSA)
!$$$  SUBPROGRAM DOCUMENTATION BLOCK
!
! SUBPROGRAM:  IJKGDS1    RETURN FIELD POSITION FOR A GIVEN GRID POINT
!   PRGMMR: IREDELL       ORG: W/NMC23       DATE: 96-04-10
!
! ABSTRACT: THIS SUBPROGRAM DECODES THE GRIB GRID DESCRIPTION SECTION
!           AND RETURNS THE FIELD POSITION FOR A GIVEN GRID POINT.
!           CALL IJKGDS0 TO SET UP THE NAVIGATION PARAMETER ARRAY.
!
! PROGRAM HISTORY LOG:
!   96-04-10  IREDELL
!   97-03-11  IREDELL  ALLOWED HEMISPHERIC GRIDS TO WRAP OVER ONE POLE
!   98-07-13  BALDWIN  ADD 2D STAGGERED ETA GRID INDEXING (203)
! 1999-04-08  IREDELL  SPLIT IJKGDS INTO TWO
!
! USAGE:    ...IJKGDS1(I,J,IJKGDSA)
!
!   INPUT ARGUMENT LIST:
!     I        - INTEGER X GRID POINT
!     J        - INTEGER Y GRID POINT
!     IJKGDSA  - INTEGER (20) NAVIGATION PARAMETER ARRAY
!                IJKGDSA(1) IS NUMBER OF X POINTS
!                IJKGDSA(2) IS NUMBER OF Y POINTS
!                IJKGDSA(3) IS X WRAPAROUND INCREMENT
!                           (0 IF NO WRAPAROUND)
!                IJKGDSA(4) IS Y WRAPAROUND LOWER PIVOT POINT
!                           (0 IF NO WRAPAROUND)
!                IJKGDSA(5) IS Y WRAPAROUND UPPER PIVOT POINT
!                           (0 IF NO WRAPAROUND)
!                IJKGDSA(6) IS SCANNING MODE
!                           (0 IF X FIRST THEN Y; 1 IF Y FIRST THEN X;
!                            3 IF STAGGERED DIAGONAL LIKE PROJECTION 203)
!                IJKGDSA(7) IS MASS/WIND FLAG FOR STAGGERED DIAGONAL
!                           (0 IF MASS; 1 IF WIND)
!                IJKGDSA(8:20) ARE UNUSED AT THE MOMENT
!
!   OUTPUT ARGUMENT LIST:
!     IJKGDS1  - INTEGER POSITION IN GRIB FIELD TO LOCATE GRID POINT
!                (0 IF OUT OF BOUNDS)
!
! ATTRIBUTES:
!   LANGUAGE: FORTRAN 90
!
!$$$
 IMPLICIT NONE
!
 INTEGER,         INTENT(IN   ):: I, J, IJKGDSA(20)
!
 INTEGER                       :: IJKGDS1
 INTEGER                       :: II, JJ, IM, JM
 INTEGER                       :: IIF, JJF, IS1, IWRAP
 INTEGER                       :: JWRAP1, JWRAP2, KSCAN, NSCAN
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  EXTRACT FROM NAVIGATION PARAMETER ARRAY
 IM=IJKGDSA(1)
 JM=IJKGDSA(2)
 IWRAP=IJKGDSA(3)
 JWRAP1=IJKGDSA(4)
 JWRAP2=IJKGDSA(5)
 NSCAN=IJKGDSA(6)
 KSCAN=IJKGDSA(7)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  COMPUTE WRAPAROUNDS IN X AND Y IF NECESSARY AND POSSIBLE
 II=I
 JJ=J
 IF(IWRAP.GT.0) THEN
   II=MOD(I-1+IWRAP,IWRAP)+1
   IF(J.LT.1.AND.JWRAP1.GT.0) THEN
     JJ=JWRAP1-J
     II=MOD(II-1+IWRAP/2,IWRAP)+1
   ELSEIF(J.GT.JM.AND.JWRAP2.GT.0) THEN
     JJ=JWRAP2-J
     II=MOD(II-1+IWRAP/2,IWRAP)+1
   ENDIF
 ENDIF
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  COMPUTE POSITION FOR THE APPROPRIATE SCANNING MODE
 IJKGDS1=0
 IF(NSCAN.EQ.0) THEN
   IF(II.GE.1.AND.II.LE.IM.AND.JJ.GE.1.AND.JJ.LE.JM) IJKGDS1=II+(JJ-1)*IM
 ELSEIF(NSCAN.EQ.1) THEN
   IF(II.GE.1.AND.II.LE.IM.AND.JJ.GE.1.AND.JJ.LE.JM) IJKGDS1=JJ+(II-1)*JM
 ELSEIF(NSCAN.EQ.2) THEN
   IS1=(JM+1-KSCAN)/2
   IIF=JJ+(II-IS1)
   JJF=JJ-(II-IS1)+KSCAN
   IF(IIF.GE.1.AND.IIF.LE.2*IM-1.AND.JJF.GE.1.AND.JJF.LE.JM) &
     IJKGDS1=(IIF+(JJF-1)*(2*IM-1)+1-KSCAN)/2
 ELSEIF(NSCAN.EQ.3) THEN
   IS1=(JM+1-KSCAN)/2
   IIF=JJ+(II-IS1)
   JJF=JJ-(II-IS1)+KSCAN
   IF(IIF.GE.1.AND.IIF.LE.2*IM-1.AND.JJF.GE.1.AND.JJF.LE.JM) IJKGDS1=(IIF+1)/2+(JJF-1)*IM
 ENDIF
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 END FUNCTION IJKGDS1

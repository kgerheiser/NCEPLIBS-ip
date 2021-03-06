!> @file
!! MAKE MULTIPLE POLE SCALAR VALUES CONSISTENT
!! @author IREDELL @date 96-04-10
!
!> THIS SUBPROGRAM AVERAGES MULTIPLE POLE SCALAR VALUES
! ON A LATITUDE/LONGITUDE GRID.  BITMAPS MAY BE AVERAGED TOO.
!!        
!! @param NO       - INTEGER NUMBER OF GRID POINTS
!! @param NX       - INTEGER LEADING DIMENSION OF FIELDS
!! @param KM       - INTEGER NUMBER OF FIELDS
!! @param RLAT     - REAL (NO) LATITUDES IN DEGREES
!! @param RLON     - REAL (NO) LONGITUDES IN DEGREES
!! @param IB       - INTEGER (KM) BITMAP FLAGS
!! @param[out] LO       - LOGICAL*1 (NX,KM) BITMAPS (IF SOME IB(K)=1)
!! @param[out] GO       - REAL (NX,KM) FIELDS
!!
SUBROUTINE POLFIXS(NM,NX,KM,RLAT,RLON,IB,LO,GO)
 IMPLICIT NONE
!
 INTEGER,    INTENT(IN   ) :: NM, NX, KM
 INTEGER,    INTENT(IN   ) :: IB(KM)
!
 LOGICAL*1,  INTENT(INOUT) :: LO(NX,KM)
!
 REAL,       INTENT(IN   ) :: RLAT(NM), RLON(NM)
 REAL,       INTENT(INOUT) :: GO(NX,KM)
!
 REAL,       PARAMETER     :: RLATNP=89.9995
 REAL,       PARAMETER     :: RLATSP=-RLATNP
!
 INTEGER                   :: K, N
!
 REAL                      :: WNP, GNP, TNP, WSP, GSP, TSP
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 DO K=1,KM
   WNP=0.
   GNP=0.
   TNP=0.
   WSP=0.
   GSP=0.
   TSP=0.
!  AVERAGE MULTIPLE POLE VALUES
   DO N=1,NM
     IF(RLAT(N).GE.RLATNP) THEN
       WNP=WNP+1
       IF(IB(K).EQ.0.OR.LO(N,K)) THEN
         GNP=GNP+GO(N,K)
         TNP=TNP+1
       ENDIF
     ELSEIF(RLAT(N).LE.RLATSP) THEN
       WSP=WSP+1
       IF(IB(K).EQ.0.OR.LO(N,K)) THEN
         GSP=GSP+GO(N,K)
         TSP=TSP+1
       ENDIF
     ENDIF
   ENDDO
!  DISTRIBUTE AVERAGE VALUES BACK TO MULTIPLE POLES
   IF(WNP.GT.1) THEN
     IF(TNP.GE.WNP/2) THEN
       GNP=GNP/TNP
     ELSE
       GNP=0.
     ENDIF
     DO N=1,NM
       IF(RLAT(N).GE.RLATNP) THEN
         IF(IB(K).NE.0) LO(N,K)=TNP.GE.WNP/2
         GO(N,K)=GNP
       ENDIF
     ENDDO
   ENDIF
   IF(WSP.GT.1) THEN
     IF(TSP.GE.WSP/2) THEN
       GSP=GSP/TSP
     ELSE
       GSP=0.
     ENDIF
     DO N=1,NM
       IF(RLAT(N).LE.RLATSP) THEN
         IF(IB(K).NE.0) LO(N,K)=TSP.GE.WSP/2
         GO(N,K)=GSP
       ENDIF
     ENDDO
   ENDIF
 ENDDO
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 END SUBROUTINE POLFIXS

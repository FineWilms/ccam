! cable_carbon.f90
!
! Carbon store routines source file for CABLE, CSIRO land surface model
!
! The flow of carbon between the vegetation compartments and soil is described
! by a simple carbon pool model of Dickinson et al 1998, J. Climate, 11, 2823-2836.
! Model implementation by Eva Kowalczyk, CSIRO Marine and Atmospheric Research.
! 
! Fortran-95 coding by Harvey Davies, Gab Abramowitz and Martin Dix
! bugs to gabsun@gmail.com.

MODULE carbon_module
  USE define_types
  IMPLICIT NONE
  PRIVATE
  PUBLIC carbon_pl, soilcarb
CONTAINS

  SUBROUTINE carbon_pl(dels)
!  SUBROUTINE carbon_pl(dels, soil, ssoil, veg, canopy, bgc)
!    TYPE (soil_parameter_type), INTENT(IN)		:: soil  ! soil parameters
!    TYPE (soil_snow_type), INTENT(IN)	                :: ssoil   ! soil/snow variables
!    TYPE (veg_parameter_type), INTENT(IN)		:: veg     ! vegetation parameters
!    TYPE (canopy_type), INTENT(INOUT)	         	:: canopy ! canopy/veg variables
!    TYPE (bgc_pool_type), INTENT(INOUT)	                :: bgc     ! biogeochemistry variables
    REAL(r_1), INTENT(IN)			        :: dels    ! integration time step (s)
    REAL(r_1), PARAMETER        :: beta = 0.9
    REAL(r_1), DIMENSION(mp)	:: cfsf     ! fast soil carbon turnover
    REAL(r_1), DIMENSION(mp)	:: cfrts    ! roots turnover
    REAL(r_1), DIMENSION(mp)	:: cfwd     ! wood turnover 
    REAL(r_1), DIMENSION(mp)	:: fcl ! fraction of assimilated carbon that goes to the
    !					construction of leaves  (eq. 5)
    REAL(r_1), DIMENSION(mp)	:: fr
    REAL(r_1), DIMENSION(mp)    :: clitt
    REAL(r_1), DIMENSION(mp)    :: coef_cd ! total stress coeff. for vegetation (eq. 6)
    REAL(r_1), DIMENSION(mp)    :: coef_cold  ! coeff. for the cold stress (eq. 7)
    REAL(r_1), DIMENSION(mp)    :: coef_drght ! coeff. for the drought stress (eq. 8)
    REAL(r_1), PARAMETER, DIMENSION(13) :: rw = (/16., 8.7, 12.5, 16., 18., 7.5, 6.1, .84, &
                 10.4, 15.1, 9., 5.8, 0.001 /) ! approximate ratio of wood to nonwood carbon
    !	         				 inferred from observations 
    REAL(r_1), PARAMETER, DIMENSION(13) :: tfcl = (/0.248, 0.345, 0.31, 0.42, 0.38, 0.35, &
         0.997,	0.95, 2.4, 0.73, 2.4, 0.55, 0.9500/)         ! leaf allocation factor
    REAL(r_1), PARAMETER, DIMENSION(13) :: trnl = 3.17e-8    ! leaf turnover rate 1 year
    REAL(r_1), PARAMETER, DIMENSION(13) :: trnr = 4.53e-9    ! root turnover rate 7 years
    REAL(r_1), PARAMETER, DIMENSION(13) :: trnsf = 1.057e-10 ! soil transfer rate coef. 30 years
    REAL(r_1), PARAMETER, DIMENSION(13) :: trnw = 6.342e-10  ! wood turnover 50  years
    REAL(r_1), PARAMETER, DIMENSION(13) :: tvclst = (/ 283., 278., 278., 235., 268., &
                                           278.0, 278.0, 278.0, 278.0, 235., 278., &
                                           278., 268. /) ! cold stress temp. below which 
!                                                         leaf loss is rapid
    REAL(r_1), DIMENSION(mp)	:: wbav ! water stress index

    !
    ! coef_cold = EXP(-(canopy%tv - tvclst(veg%iveg)))   ! cold stress
    ! Limit size of exponent to avoif overflow when tv is very cold
!    coef_cold = EXP(MIN(50., -(canopy%tv - tvclst(veg%iveg))))   ! cold stress
    coef_cold = EXP(MIN(1., -(canopy%tv - tvclst(veg%iveg))))   ! cold stress
!les
    wbav = REAL(SUM(veg%froot * ssoil%wb, 2),r_1)
!    wbav = SUM(veg%froot * ssoil%wb, 2)
!    coef_drght = EXP(10.*( MIN(1., MAX(1.,wbav**(2-soil%ibp2)-1.) / & ! drought stress
    coef_drght = EXP(5.*( MIN(1., MAX(1.,wbav**(2-soil%ibp2)-1.) / & ! drought stress
         (soil%swilt**(2-soil%ibp2) - 1.)) - 1.))
    coef_cd = ( coef_cold + coef_drght ) * 2.0e-7
    !
    ! CARBON POOLS
    !
    fcl = EXP(-tfcl(veg%iveg) * veg%vlai)  ! fraction of assimilated carbon that goes
    !                                         to the construction of leaves  (eq. 5)

    !							 LEAF
    ! resp_lfrate is omitted below as fpn represents photosythesis - leaf transpiration
    ! calculated by the CBM 
    !
    clitt = (coef_cd + trnl(veg%iveg)) * bgc%cplant(:,1)
    bgc%cplant(:,1) = bgc%cplant(:,1) - dels * (canopy%fpn * fcl + clitt)
    !
    !							 WOOD
    !	                           fraction of photosynthate going to roots, (1-fr) to wood, eq. 9
    fr = MIN(1., EXP(- rw(veg%iveg) * beta * bgc%cplant(:,3) / MAX(bgc%cplant(:,2), 0.01)) / beta)
    !
    !                                            
    cfwd = trnw(veg%iveg) * bgc%cplant(:,2)
    bgc%cplant(:,2) = bgc%cplant(:,2) - dels * (canopy%fpn * (1.-fcl) * (1.-fr) + canopy%frpw + cfwd )

    !							 ROOTS
    !				
    cfrts = trnr(veg%iveg) * bgc%cplant(:,3)
    bgc%cplant(:,3) = bgc%cplant(:,3) - dels * (canopy%fpn * (1. - fcl) * fr + cfrts + canopy%frpr )
    !
    !							 SOIL
    !			                                	fast carbon 
    cfsf = trnsf(veg%iveg) * bgc%csoil(:,1)
    bgc%csoil(:,1) = bgc%csoil(:,1) + dels * (0.98 * clitt + 0.9 * cfrts + cfwd  - cfsf &
         - 0.98 * canopy%frs)
    !			                                	slow carbon 
    bgc%csoil(:,2) = bgc%csoil(:,2) + dels * (0.02 * clitt  + 0.1 * cfrts + cfsf &
         - 0.02 * canopy%frs)

    bgc%cplant(:,1)  = MAX(0.001, bgc%cplant(:,1))
    bgc%cplant(:,2)  = MAX(0.001, bgc%cplant(:,2))
    bgc%cplant(:,3) = MAX(0.001, bgc%cplant(:,3))
    bgc%csoil(:,1) = MAX(0.001, bgc%csoil(:,1))
    bgc%csoil(:,2) = MAX(0.001, bgc%csoil(:,2))
  END SUBROUTINE carbon_pl

  SUBROUTINE soilcarb
!  SUBROUTINE soilcarb(soil, ssoil, veg, bgc, met, canopy)
!    TYPE (soil_parameter_type), INTENT(IN) :: soil
!    TYPE (soil_snow_type), INTENT(IN)	:: ssoil
!    TYPE (veg_parameter_type), INTENT(IN)  :: veg
!    TYPE (bgc_pool_type), INTENT(IN)	:: bgc
!    TYPE (met_type), INTENT(IN)		:: met	
!    TYPE (canopy_type), INTENT(INOUT)	:: canopy
    REAL(r_1), DIMENSION(mp)		:: den ! sib3
    INTEGER(i_d)			:: k
    REAL(r_1), DIMENSION(mp)		:: rswc
    REAL(r_1), DIMENSION(mp)		:: sss
    REAL(r_1), DIMENSION(mp)		:: e0rswc
    REAL(r_1), DIMENSION(mp)		:: ftsoil
    REAL(r_1), DIMENSION(mp)		:: ftsrs
    REAL(r_1), PARAMETER, DIMENSION(13)	:: rswch = 0.16
    REAL(r_1), PARAMETER, DIMENSION(13)	:: soilcf = 1.0
    REAL(r_1), PARAMETER		:: t0 = -46.0
    REAL(r_1), DIMENSION(mp)		:: tref
    REAL(r_1), DIMENSION(mp)		:: tsoil
!    REAL(r_1), PARAMETER, DIMENSION(13)	:: vegcf = &
!         (/ 1.95, 1.5, 1.55, 0.91, 0.73, 2.8, 2.75, 0.0, 2.05, 0.6, 0.4, 2.8, 0.0 /)

!      print *,'soilcarb1'
    den = max(0.07,soil%sfc - soil%swilt)
    rswc =  MAX(0.0001_r_2, veg%froot(:,1)*(ssoil%wb(:,2) - soil%swilt)) / den
!    rswc = veg%froot(:, 1) * max(0.0001, ssoil%wb(:,2) - soil%swilt) / den
    tsoil = veg%froot(:,1) * ssoil%tgg(:,2) - 273.15
!    tref = MAX(t0 + 1.,ssoil%tgg(:,ms) - 273.1)
    tref = MAX(0.,ssoil%tgg(:,ms) - 273.1)


!      print *,'soilcarb2'
    DO k = 2,ms  ! start from 2nd index for less dependency on the surface condition
       rswc = rswc +  &
            MAX(0.0001_r_2, veg%froot(:,k) * (ssoil%wb(:,k) - soil%swilt)) / den
       tsoil = tsoil + veg%froot(:,k) * ssoil%tgg(:,k)
    ENDDO
!      print *,'soilcarb3'
    rswc = MIN(1.,rswc)
    tsoil = MAX(t0 + 2., tsoil)
    e0rswc = 52.4 + 285. * rswc
    ftsoil=min(0.0015,1./(tref - t0) - 1./(tsoil - t0))
    sss = MAX(-15.,MIN(1.,e0rswc * ftsoil))
    ftsrs=EXP(sss)
    !    ftsrs=exp(e0rswc * ftsoil)
    !        soilref=soilcf(soil%isoilm)*min(1.,1.4*max(.3,.0278*tsoil+.5))
    !        rpsoil=vegcf(veg%iveg)*soilref* ftsrs * frswc
    !     &              * 12./44.*12./1.e6 * 

!      print *,'soilcarb4'
!      print *,'soilcarb41',veg%iveg,vegcf(veg%iveg),soil%isoilm, &
!               soilcf(soil%isoilm),ftsrs,rswc,rswch(soil%isoilm)

! rml vegcf(veg%iveg) replaced with veg%vegcf
!    canopy%frs = vegcf(veg%iveg) * (144.0 / 44.0e6)  &
     canopy%frs = veg%vegcf * (144.0 / 44.0e6)  &
         * soilcf(soil%isoilm) * MIN(1.,1.4 * MAX(.3,.0278 * tsoil + .5)) &
         * ftsrs &
         * rswc / (rswch(soil%isoilm) + rswc)

!      print *,'soilcarb5'
  END SUBROUTINE soilcarb

END MODULE carbon_module
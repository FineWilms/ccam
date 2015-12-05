! Conformal Cubic Atmospheric Model
    
! Copyright 2015 Commonwealth Scientific Industrial Research Organisation (CSIRO)
    
! This file is part of the Conformal Cubic Atmospheric Model (CCAM)
!
! CCAM is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! CCAM is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with CCAM.  If not, see <http://www.gnu.org/licenses/>.

!------------------------------------------------------------------------------

! Reads AMIP-style, monthly Sea Surface Temperatures, sea-ice and (optionally)
! near surface salinity.  Use onthefly for sub-monthly input data.
!
! namip=0  No input data
! namip=-1 Persisted SST anomalies
! namip=1  Use PWCB intepolation for SSTs, diagnose sea-ice
! namip=2  Use linear interpolation for SSTs and sea-ice (assumes pre-processing of monthly SSTs)
! namip=3  Use PWCB interpolation for SSTs and no intepolation for sea-ice
! namip=4  Use PWCB interpolation for SSTs and sea-ice
! namip=5  Use PWCB interpolation for SSTs, sea-ice and salinity
    
!     iday is a variable which is equal to the number of
!     day of the month.(Thus iday = 1 at the
!     start of a month, is updated to 2 at end of first day etc.)
!     imo is the number of the month we are in (1<=imo<=12)

subroutine amipsst

use arrays_m                                      ! Atmosphere dyamics prognostic arrays
use cc_mpi                                        ! CC MPI routines
use latlong_m                                     ! Lat/lon coordinates
use mlo, only : mloexport,mloexpmelt,wlev,wrtemp  ! Ocean physics and prognostic arrays
use nesting                                       ! Nesting and assimilation
use pbl_m                                         ! Boundary layer arrays
use permsurf_m                                    ! Fixed surface arrays
use soil_m                                        ! Soil and surface data
use soilsnow_m                                    ! Soil, snow and surface data

implicit none

include 'newmpar.h'                               ! Grid parameters
include 'dates.h'                                 ! Date data
include 'parm.h'                                  ! Model configuration

integer leap
common/leap_yr/leap                               ! Leap year (1 to allow leap years)

real, allocatable, save, dimension(:) :: ssta, sstb, sstc
real, allocatable, save, dimension(:) :: aice, bice, cice
real, allocatable, save, dimension(:) :: asal, bsal, csal
real, allocatable, save, dimension(:) :: res
real, dimension(ifull) :: sssb,timelt,fraciceb
real, dimension(ifull,wlev) :: dumb,dumd
real, dimension(ifull,wlev,2) :: dumc
real x, c2, c3, c4, rat1, rat2
integer, dimension(0:13) :: mdays
integer idjd_g, iq, k
integer, save :: iyr, imo, iday
integer, parameter :: mlomode = 1 ! (0=relax, 1=scale-select)
integer, parameter :: mlotime = 6 ! scale-select period in hours

if ( .not.allocated(ssta) ) then
  allocate( ssta(ifull), sstb(ifull), sstc(ifull) )
  allocate( aice(ifull), bice(ifull), cice(ifull) )
  allocate( asal(ifull), bsal(ifull), csal(ifull) )
end if

idjd_g = id + (jd-1)*il_g
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

iyr = kdate/10000
imo = (kdate-10000*iyr)/100
iday = kdate - 10000*iyr - 100*imo + mtimer/(60*24)
mdays = (/ 31, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, 31 /)
if ( leap>=1 ) then
  if ( mod(iyr,4)==0 ) mdays(2) = 29
  if ( mod(iyr,100)==0 ) mdays(2) = 28
  if ( mod(iyr,400)==0 ) mdays(2) = 29
end if
do while ( iday>mdays(imo) )
  iday = iday - mdays(imo)
  imo = imo + 1
  if ( imo>12 ) then
    imo = 1
    iyr = iyr + 1
  end if
end do
if ( namip==-1 ) then
  iyr = 0
end if
x = (iday-1)/mdays(imo)  ! simplest at end of day

fraciceb = 0.  
if ( ktau==0 ) then
  if ( myid==0 ) then 
    call amiprd(ssta,sstb,sstc,aice,bice,cice,asal,bsal,csal,namip,iyr,imo,idjd_g,leap)
  else
    call ccmpi_distribute(ssta)
    call ccmpi_distribute(sstb)
    call ccmpi_distribute(sstc)
    if ( namip>=2 ) then
      call ccmpi_distribute(aice)
      call ccmpi_distribute(bice)
      call ccmpi_distribute(cice)
    end if
    if ( namip>=5 ) then
      call ccmpi_distribute(asal)
      call ccmpi_distribute(bsal)
      call ccmpi_distribute(csal)
    end if
  end if ! myid==0
end if

if ( ktau==0 ) then
  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!      
  ! Each day interpolate-in-time non-land sst's
  if ( namip==-1 ) then
    allocate(res(ifull))
    do iq = 1,ifull  
      if ( .not.land(iq) ) then
        c2 = ssta(iq)
        c3 = ssta(iq) + sstb(iq)
        c4 = c3 + sstc(iq)     
        res(iq) = tgg(iq,1) - ( .5*c3+(4.*c3-5.*c2-c4)*x+1.5*(c4+3.*c2-3.*c3)*x*x )
      end if      ! (.not.land(iq))
    end do
    if ( myid==0 ) then
      write(6,*)'some res values',(res(iq),iq=1,ifull,100)
    end if
  end if  ! (namip==-1)
end if    ! (ktau==0)


if ( namip==-1 ) then
  write(6,*) 'later_a ktau,res,tss ',ktau,res(idjd),tss(idjd)
  ! c1=0.
  do iq = 1,ifull  
    if ( .not.land(iq) ) then
      c2 = ssta(iq)
      c3 = ssta(iq)+sstb(iq)
      c4 = c3 + sstc(iq)     
      tgg(iq,1) = res(iq) + ( .5*c3+(4.*c3-5.*c2-c4)*x+1.5*(c4+3.*c2-3.*c3)*x*x )
      tss(iq) = tgg(iq,1)
    end if      ! (.not.land(iq))
  end do
  write(6,*) 'later ktau,res,tss ',ktau,res(idjd),tss(iq)
  return
end if  ! (namip==-1)

if ( namip==1 ) then
  ! c1=0.
  fraciceb = 0.
  do iq = 1,ifull  
    if ( .not.land(iq) ) then
      c2 = ssta(iq)
      c3 = ssta(iq)+sstb(iq)
      c4 = c3 + sstc(iq)          
      tgg(iq,1) = .5*c3+(4.*c3-5.*c2-c4)*x+1.5*(c4+3.*c2-3.*c3)*x*x
      if ( tgg(iq,1)<272. ) fraciceb(iq) = 1.
    end if      ! (.not.land(iq))
  end do
end if  ! (namip==1)

if ( namip==2 ) then
  if ( iday<mdays(imo)/2 ) then  ! 1st half of month
    rat1 = (mdays(imo)-2.*iday)/(mdays(imo)+mdays(imo-1))
    rat2 = (2.*iday+mdays(imo-1))/(mdays(imo)+mdays(imo-1))
    if ( mydiag ) write(6,*)'rat1,rat2,land: ',rat1,rat2,land(idjd)
    do iq = 1,ifull  
      if ( .not.land(iq) ) then
        tgg(iq,1) = rat1*ssta(iq) + rat2*sstb(iq)  ! sea water temperature
      end if      ! (.not.land(iq))
    end do
    fraciceb(:) = min( .01*(rat1*aice(:)+rat2*bice(:)), 1. ) ! convert from %
  else                             ! 2nd half of month
    rat1 = (mdays(imo+1)+2.*mdays(imo)-2.*iday)/(mdays(imo+1)+mdays(imo))
    rat2 = (2.*iday-mdays(imo))/(mdays(imo+1)+mdays(imo))
    do iq = 1,ifull  
      if ( .not.land(iq) ) then
        tgg(iq,1) = rat1*sstb(iq) + rat2*sstc(iq)  ! sea water temperature
      end if      ! (.not.land(iq))
    end do
    fraciceb(:) = min( .01*(rat1*bice(:)+rat2*cice(:)), 1. ) ! convert from %
  end if
end if  ! (namip==2)

if ( namip>2 ) then
  do iq=1,ifull  
    if(.not.land(iq))then
      c2=ssta(iq)
      c3=ssta(iq)+sstb(iq)
      c4=c3+sstc(iq)          
      tgg(iq,1)=.5*c3+(4.*c3-5.*c2-c4)*x+1.5*(c4+3.*c2-3.*c3)*x*x
    endif      ! (.not.land(iq))
  enddo
endif  ! (namip>2)

if ( namip==3 ) then
  do iq=1,ifull  
    fraciceb(iq)=min(.01*bice(iq),1.)
  enddo
endif  ! (namip==3)

if ( namip>=4 ) then
  do iq=1,ifull  
    c2=aice(iq)
    c3=aice(iq)+bice(iq)
    c4=c3+cice(iq)          
    fraciceb(iq)=min(.01*(.5*c3+(4.*c3-5.*c2-c4)*x+1.5*(c4+3.*c2-3.*c3)*x*x),1.)
  end do
endif  ! (namip==4)

if ( namip==5 ) then
  do iq=1,ifull  
    c2=asal(iq)
    c3=c2+bsal(iq)
    c4=c3+csal(iq)          
    sssb(iq)=.5*c3+(4.*c3-5.*c2-c4)*x+1.5*(c4+3.*c2-3.*c3)*x*x
  end do
  sssb=max(sssb,0.)
end if

where ( fraciceb(1:ifull)<=0.02 )
  fraciceb(1:ifull) = 0.
end where

! Sea-ice and Sea-Surface-Temperature
if ( nmlo==0 ) then
  sicedep(:)=0. 
  if ( ktau==0 ) then  ! will set sicedep in indata
    fracice(:)=fraciceb(:)
    do iq=1,ifull
      if(.not.land(iq))then
        tss(iq)=tgg(iq,1)
      endif    ! (.not.land(iq))
    enddo
    return
  endif       ! (ktau==0)
  do iq=1,ifull
    if(.not.land(iq))then
      if(fraciceb(iq)>0.)then
        if(fracice(iq)==0.)then
          ! create values for tice, and set averaged tss
          ! N.B. if already a sice point, keep present tice
          tggsn(iq,1)=min(271.2,tss(iq),t(iq,1)+.04*6.5) ! for 40 m lev1
        endif  ! (fracice(iq)==0.)
        if(rlatt(iq)>0.)then
          sicedep(iq)=2.
        else
          sicedep(iq)=1.
        endif ! (rlatt(iq)>0.)
      endif    ! (fraciceb(iq)>0.)
      fracice(iq)=fraciceb(iq)
      tss(iq)=tggsn(iq,1)*fracice(iq)+tgg(iq,1)*(1.-fracice(iq))
    endif      ! (.not.land(iq))
  enddo

elseif (ktau>0) then
  dumb=0.
  dumc=0.
  dumd=34.72
  if (nud_ouv/=0) then
    write(6,*) "ERROR: nud_ouv.ne.0 is not supported for"
    write(6,*) "       namip.ne.0"
    call ccmpi_abort(-1)
  end if
  if (nud_sfh/=0) then
    write(6,*) "ERROR: nud_sfh.ne.0 is not supported for"
    write(6,*) "       namip.ne.0"
    call ccmpi_abort(-1)
  end if
  timelt=273.16
  call mloexport(0,timelt,1,0)
  timelt=min(timelt,271.3)
  dumb(:,1)=tgg(:,1)
  where(fraciceb>0.)
    dumb(:,1)=timelt
  end where
  dumb(:,1)=dumb(:,1)-wrtemp
  dumd(:,1)=sssb
  select case(mlomode)
    case(0) ! relax
      call mlonudge(dumb,dumd,dumc,dumc(:,1,1),1)
    case(1)
      if (mod(mtimer,mlotime*60)==0) then
        call mlofilterhub(dumb,dumd,dumc,dumc(:,1,1),1)
      end if
    case DEFAULT
      write(6,*) "ERROR: Unknown mlomode ",mlomode
      call ccmpi_abort(-1)
  end select
  do k=1,ms
    call mloexport(0,tgg(:,k),k,0)
    where ( tgg(:,k)<100. )
      tgg(:,k)=tgg(:,k)+wrtemp
    end where    
  end do
end if ! if (nmlo==0) ..else..

return
end subroutine amipsst
      
subroutine amiprd(ssta,sstb,sstc,aice,bice,cice,asal,bsal,csal,namip,iyr,imo,idjd_g,leap)
      
use cc_mpi            ! CC MPI routines
use infile            ! Input file routines
      
implicit none
    
include 'newmpar.h'   ! Grid parameters
include 'filnames.h'  ! Filenames
include 'parmgeom.h'  ! Coordinate data
      
integer, parameter :: nihead = 54
integer, parameter :: nrhead = 14
      
integer, intent(in) :: namip, iyr, imo, idjd_g, leap
integer imonth, iyear, il_in, jl_in, iyr_m, imo_m, ierr, leap_in
integer varid, ncidx, iarchx, maxarchi, iernc
integer varid_date, varid_time, varid_timer
integer mtimer_r, kdate_r, ktime_r
integer, dimension(3) :: spos, npos
#ifdef i8r8
integer, dimension(nihead) :: nahead
#else
integer(kind=4), dimension(nihead) :: nahead
#endif
real, dimension(ifull), intent(out) :: ssta, sstb, sstc
real, dimension(ifull), intent(out) :: aice, bice, cice
real, dimension(ifull), intent(out) :: asal, bsal, csal
real, dimension(ifull_g) :: ssta_g
real, dimension(nrhead) :: ahead
real rlon_in, rlat_in, schmidt_in
real of, sc
logical ltest, tst
character(len=22) header
character(len=10) unitstr

iyr_m = iyr
imo_m = imo

! check for netcdf file format
call ccnf_open(sstfile,ncidx,iernc)
if ( iernc==0 ) then
    
  ! NETCDF
  write(6,*) "Reading AMIP file in netcdf format"
  ! check grid definition
  call ccnf_get_attg(ncidx,'int_header',nahead)
  call ccnf_get_attg(ncidx,'real_header',ahead)
  il_in      = nahead(1)
  jl_in      = nahead(2)
  rlon_in    = ahead(5)
  rlat_in    = ahead(6)
  schmidt_in = ahead(7)
  if(schmidt_in<=0..or.schmidt_in>1.)then
    rlon_in    = ahead(6)
    rlat_in    = ahead(7)
    schmidt_in = ahead(8)
  endif  ! (schmidtx<=0..or.schmidtx>1.)  
  if(il_g/=il_in.or.jl_g/=jl_in.or.rlong0/=rlon_in.or.rlat0/=rlat_in.or.schmidt/=schmidt_in)then
    write(6,*) 'il_g,il_in,jl_g,jl_in,rlong0,rlon_in',il_g,il_in,jl_g,jl_in,rlong0,rlon_in
    write(6,*) 'rlat0,rlat_in,schmidt,schmidt_in',rlat0,rlat_in,schmidt,schmidt_in
    write(6,*) 'wrong amipsst file'
    call ccmpi_abort(-1)
  endif
  call ccnf_get_attg(ncidx,'leap',leap_in,tst)
  if ( tst ) then
    leap_in = 0
  end if
  if ( leap/=leap_in ) then
    write(6,*) "ERROR: Input sstfile requires leap ",leap_in
    call ccmpi_abort(-1)
  end if
  call ccnf_inq_dimlen(ncidx,'time',maxarchi)
  ! search for required month
  iarchx = 0
  iyear  = -999
  imonth = -999
  ltest  = .true.
  call ccnf_inq_varid(ncidx,'kdate',varid_date,tst)
  if (tst) then
    write(6,*) "ERROR: Cannot locate kdate in ",trim(sstfile)
    call ccmpi_abort(-1)
  end if
  call ccnf_inq_varid(ncidx,'ktime',varid_time,tst)
  if (tst) then
    write(6,*) "ERROR: Cannot locate ktime in ",trim(sstfile)
    call ccmpi_abort(-1)
  end if
  call ccnf_inq_varid(ncidx,'mtimer',varid_timer,tst)
  if (tst) then
    write(6,*) "ERROR: Cannot locate mtimer in ",trim(sstfile)
    call ccmpi_abort(-1)
  end if
  do while ( ltest .and. iarchx<maxarchi )
    iarchx = iarchx + 1
    call ccnf_get_vara(ncidx,varid_date,iarchx,kdate_r)
    call ccnf_get_vara(ncidx,varid_time,iarchx,ktime_r)
    call ccnf_get_vara(ncidx,varid_timer,iarchx,mtimer_r)
    call datefix(kdate_r,ktime_r,mtimer_r)
    iyear  = kdate_r/10000
    imonth = (kdate_r-iyear*10000)/100
    ltest  = iyr_m/=iyear .or. imo_m/=imonth
  end do
  if ( ltest ) then
    write(6,*) "ERROR: Cannot locate year ",iyr_m
    write(6,*) "       and month ",imo_m
    write(6,*) "       in file ",trim(sstfile)
    call ccmpi_abort(-1)
  end if
  spos(1:2)=1
  spos(3)=iarchx
  npos(1)=il_g
  npos(2)=6*il_g
  npos(3)=1
  call ccnf_inq_varid(ncidx,'tos',varid,tst)
  if ( tst ) then
    write(6,*) "ERROR: Cannot locate tos"
    call ccmpi_abort(-1)
  end if
  unitstr=''
  call ccnf_get_att(ncidx,varid,'units',unitstr)
  write(6,*) "Reading SST data from amipsst file"        
  spos(3) = max( iarchx - 1, 1 )
  if ( spos(3)==iarchx .and. myid==0 ) then
    write(6,*) "Warning: Using current SSTs for previous month"
  end if
  call ccnf_get_vara(ncidx,varid,spos,npos,ssta_g)
  call ccnf_get_att(ncidx,varid,'add_offset',of,ierr=ierr)
  if ( ierr /= 0 ) of=0.
  if ( trim(unitstr) == 'C' ) of=of+273.16
  call ccnf_get_att(ncidx,varid,'scale_factor',sc,ierr=ierr)
  if ( ierr /= 0 ) sc=1.
  ssta_g=sc*ssta_g+of        
  call ccmpi_distribute(ssta, ssta_g)
  spos(3)=iarchx
  call ccnf_get_vara(ncidx,varid,spos,npos,ssta_g)
  ssta_g=sc*ssta_g+of  
  call ccmpi_distribute(sstb, ssta_g)
  spos(3) = min( iarchx+1, maxarchi )
  if ( spos(3)==iarchx .and. myid==0 ) then
    write(6,*) "Warning: Using current SSTs for next month"
  end if
  call ccnf_get_vara(ncidx,varid,spos,npos,ssta_g)
  ssta_g=sc*ssta_g+of  
  call ccmpi_distribute(sstc, ssta_g)
          
else
    
  ! ASCII
  open(unit=75,file=sstfile,status='old',form='formatted',iostat=ierr)
  if (ierr/=0) then
    write(6,*) "ERROR: Cannot read AMIP sstfile ",trim(sstfile)
    call ccmpi_abort(-1)
  end if
  write(6,*) "Reading AMIP file in ASCII format"
  iyear=-999
  imonth=-999
  do while(iyr_m/=iyear.or.imo_m/=imonth)
    write(6,*) 'about to read amipsst file'
    read(75,*) imonth,iyear,il_in,jl_in,rlon_in,rlat_in,schmidt_in,header
    write(6,'("reading sst ",i2,i5,2i4,2f6.1,f7.4,1x,a22)') imonth,iyear,il_in,jl_in,rlon_in,rlat_in,schmidt_in,header
    if(il_g/=il_in.or.jl_g/=jl_in.or.rlong0/=rlon_in.or.rlat0/=rlat_in.or.schmidt/=schmidt_in)then
      write(6,*) 'il_g,il_in,jl_g,jl_in,rlong0,rlon_in',il_g,il_in,jl_g,jl_in,rlong0,rlon_in
      write(6,*) 'rlat0,rlat_in,schmidt,schmidt_in',rlat0,rlat_in,schmidt,schmidt_in
      write(6,*) 'wrong amipsst file'
      call ccmpi_abort(-1)
    endif
    read(75,*) ssta_g
    ssta_g(:)=ssta_g(:)*.01 -50. +273.16
    write(6,*) 'want imo_m,iyr_m; ssta ',imo_m,iyr_m,ssta_g(idjd_g)
  end do
  call ccmpi_distribute(ssta, ssta_g)
  read(75,'(i2,i5,a22)') imonth,iyear,header
  write(6,*) 'reading sstb data:',imonth,iyear,header
  write(6,*) 'should agree with imo,iyr ',imo,iyr
  if(iyr/=iyear.or.imo/=imonth)then
    call ccmpi_abort(-1)
  end if
  read(75,*) ssta_g
  ssta_g(:)=ssta_g(:)*.01 -50. +273.16
  write(6,*) 'sstb(idjd) ',ssta_g(idjd_g)
  call ccmpi_distribute(sstb, ssta_g)
  ! extra read from Oct 08        
  read(75,'(i2,i5,a22)') imonth,iyear,header
  write(6,*) 'reading sstc data:',imonth,iyear,header
  read(75,*) ssta_g
  ssta_g(:)=ssta_g(:)*.01 -50. +273.16
  write(6,*) 'sstc(idjd) ',ssta_g(idjd_g)
  call ccmpi_distribute(sstc, ssta_g)
  close(75)
  
end if ! (iernc==0) .. else ..
  
if ( namip >= 2 ) then   ! sice also read at middle of month
  if ( iernc == 0 ) then
      
    ! NETCDF
    spos(3)=max( iarchx-1, 1 )
    if ( spos(3)==iarchx .and. myid==0 ) then
      write(6,*) "Warning: Using current sea-ice for previous month" 
    end if
    call ccnf_inq_varid(ncidx,'sic',varid,tst)
    if (tst) then
      write(6,*) "ERROR: Cannot locate sic"
      call ccmpi_abort(-1)
    end if
    write(6,*) "Reading Sea Ice data from amipsst file"
    call ccnf_get_vara(ncidx,varid,spos,npos,ssta_g)
    call ccnf_get_att(ncidx,varid,'add_offset',of,ierr=ierr)
    if (ierr/=0) of=0.
    call ccnf_get_att(ncidx,varid,'scale_factor',sc,ierr=ierr)
    if (ierr/=0) sc=1.
    ssta_g=sc*ssta_g+of
    ssta_g=100.*ssta_g  
    call ccmpi_distribute(aice, ssta_g)
    spos(3)=iarchx
    call ccnf_get_vara(ncidx,varid,spos,npos,ssta_g)
    ssta_g=sc*ssta_g+of
    ssta_g=100.*ssta_g       
    call ccmpi_distribute(bice, ssta_g)
    spos(3)=min( iarchx+1, maxarchi )
    if ( spos(3)==iarchx .and. myid==0 ) then
      write(6,*) "Warning: Using current sea-ice for next month"
    end if
    call ccnf_get_vara(ncidx,varid,spos,npos,ssta_g)
    ssta_g=sc*ssta_g+of
    ssta_g=100.*ssta_g  
    call ccmpi_distribute(cice, ssta_g)
          
  else
      
    ! ASCII
    open(unit=76,file=icefile,status='old',form='formatted',iostat=ierr)
    if (ierr/=0) then
      write(6,*) "ERROR: Cannot read AMIP icefile ",trim(icefile)
      call ccmpi_abort(-1)
    end if
    iyear=-999
    imonth=-999
    do while(iyr_m/=iyear.or.imo_m/=imonth)
      read(76,*) imonth,iyear,il_in,jl_in,rlon_in,rlat_in,schmidt_in,header
      write(6,'("reading ice ",i2,i5,2i4,2f6.1,f6.3,a22)') imonth,iyear,il_in,jl_in,rlon_in,rlat_in,schmidt_in,header
      if(il_g/=il_in.or.jl_g/=jl_in.or.rlong0/=rlon_in.or.rlat0/=rlat_in.or.schmidt/=schmidt_in)then
        write(6,*) 'il_g,il_in,jl_g,jl_in,rlong0,rlon_in',il_g,il_in,jl_g,jl_in,rlong0,rlon_in
        write(6,*) 'rlat0,rlat_in,schmidt,schmidt_in',rlat0,rlat_in,schmidt,schmidt_in
        write(6,*) 'wrong amipice file'
        call ccmpi_abort(-1)
      endif
      read(76,*) ssta_g
      write(6,*) 'want imo_m,iyr_m; aice ',imo_m,iyr_m,ssta_g(idjd_g)
    enddo
    call ccmpi_distribute(aice, ssta_g)
    read(76,'(i2,i5,a22)') imonth,iyear,header
    write(6,*) 'reading b_sice data:',imonth,iyear,header
    write(6,*) 'should agree with imo,iyr ',imo,iyr
    if(iyr/=iyear.or.imo/=imonth) then
      call ccmpi_abort(-1)
    end if
    read(76,*) ssta_g
    write(6,*) 'bice(idjd) ',ssta_g(idjd_g)
    call ccmpi_distribute(bice, ssta_g)
    ! extra cice read from Oct 08        
    read(76,'(i2,i5,a22)') imonth,iyear,header
    write(6,*) 'reading c_sice data:',imonth,iyear,header
    read(76,*) ssta_g
    write(6,*) 'cice(idjd) ',ssta_g(idjd_g)
    call ccmpi_distribute(cice, ssta_g)
    close(76)
  end if ! (iernc==0) ..else..    	    
  
endif   ! (namip>=2) 
      
if (namip>=5) then
  if (iernc==0) then
      
    ! NETCDF
    spos(3)=max( iarchx-1, 1 )
    if ( spos(3)==iarchx .and. myid==0 ) then
      write(6,*) "Warning: Using current salinity for previous month"
    end if
    call ccnf_inq_varid(ncidx,'sss',varid,tst)
    if (tst) then
      write(6,*) "ERROR: Cannot locate sss"
      call ccmpi_abort(-1)
    end if
    write(6,*) "Reading Salinity data from amipsst file"
    call ccnf_get_vara(ncidx,varid,spos,npos,ssta_g)
    call ccnf_get_att(ncidx,varid,'add_offset',of,ierr=ierr)
    if (ierr/=0) of=0.
    call ccnf_get_att(ncidx,varid,'scale_factor',sc,ierr=ierr)
    if (ierr/=0) sc=1.  
    ssta_g=sc*ssta_g+of
    call ccmpi_distribute(asal, ssta_g)
    spos(3)=iarchx
    call ccnf_get_vara(ncidx,varid,spos,npos,ssta_g)
    ssta_g=sc*ssta_g+of
    call ccmpi_distribute(bsal, ssta_g)
    spos(3)=min( iarchx+1, maxarchi )
    if ( spos(3)==iarchx .and. myid==0 ) then
      write(6,*) "Warning: Using current salinity for next month"
    end if
    call ccnf_get_vara(ncidx,varid,spos,npos,ssta_g)
    ssta_g=sc*ssta_g+of        
    call ccmpi_distribute(csal, ssta_g)

  else
      
    ! ASCII
    open(unit=77,file=salfile,status='old',form='formatted',iostat=ierr)
    if (ierr/=0) then
      write(6,*) "ERROR: Cannot read AMIP salfile ",trim(salfile)
      call ccmpi_abort(-1)
    end if
    iyear=-999
    imonth=-999
    do while (iyr_m/=iyear.or.imo_m/=imonth)
      read(77,*) imonth,iyear,il_in,jl_in,rlon_in,rlat_in,schmidt_in,header
      write(6,'("reading sal ",i2,i5,2i4,2f6.1,f6.3,a22)') imonth,iyear,il_in,jl_in,rlon_in,rlat_in,schmidt_in,header
      if(il_g/=il_in.or.jl_g/=jl_in.or.rlong0/=rlon_in.or.rlat0/=rlat_in.or.schmidt/=schmidt_in)then
        write(6,*) 'il_g,il_in,jl_g,jl_in,rlong0,rlon_in',il_g,il_in,jl_g,jl_in,rlong0,rlon_in
        write(6,*) 'rlat0,rlat_in,schmidt,schmidt_in',rlat0,rlat_in,schmidt,schmidt_in
        write(6,*) 'wrong sal file'
        call ccmpi_abort(-1)
      endif
      read(77,*) ssta_g
      write(6,*) 'want imo_m,iyr_m; asal ',imo_m,iyr_m,ssta_g(idjd_g)
    end do
    call ccmpi_distribute(asal, ssta_g)
    read(77,'(i2,i5,a22)') imonth,iyear,header
    write(6,*) 'reading b_sal data:',imonth,iyear,header
    write(6,*) 'should agree with imo,iyr ',imo,iyr
    if(iyr/=iyear.or.imo/=imonth) then
      call ccmpi_abort(-1)
    end if
    read(77,*) ssta_g
    write(6,*) 'bsal(idjd) ',ssta_g(idjd_g)
    call ccmpi_distribute(bsal, ssta_g)
    read(77,'(i2,i5,a22)') imonth,iyear,header
    write(6,*) 'reading c_sal data:',imonth,iyear,header
    read(77,*) ssta_g
    write(6,*) 'cice(idjd) ',ssta_g(idjd_g)
    call ccmpi_distribute(csal, ssta_g)
    close(77)

  end if ! (iernc==0) ..else..
endif

if ( iernc==0 ) then
  call ccnf_close(ncidx)
end if

return
end subroutine amiprd

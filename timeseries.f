      module timeseries

c     rml 25/08/03 declarations from sflux
      implicit none
      integer, save :: indextime,ntsfreq,ngrdpts,ngrdpts1,n3d,n2d
      double precision, save :: tstime
      integer, pointer, dimension(:,:), save :: listijk
      logical, pointer, dimension(:), save :: writesurf
      integer, pointer, dimension(:), save :: tsid
      character*10, pointer, dimension(:), save :: varname3,varname2
c     rml 25/11/03 declarations from sflux
      integer, save :: indship,nshippts,inshipid(4),outshipid(3)
      integer, save :: nshipout
      integer, pointer, dimension(:), save :: shipdate,shiptime


      contains
c *********************************************************************

      subroutine init_ts(ngas,dt)
      use tracermodule, only : sitefile,shipfile
      implicit none
      integer ngas
      real dt

      if (sitefile.ne.'') call readsitelist(ngas)
      if (shipfile.ne.'') call readshiplist(ngas,dt)

      return
      end subroutine

c ********************************************************************
      subroutine write_ts(ktau,ntau,dt)
      use tracermodule, only : sitefile,shipfile
      implicit none
      include 'dates.h'
      integer jyear,jmonth,jday,jhour,jmin
      integer ktau,ntau,mstart,mins
      real dt
      integer ndoy(12)   ! days from beginning of year (1st Jan is 0)
      data ndoy/ 0,31,59,90,120,151,181,212,243,273,304,334/

      jyear=kdate/10000
      jmonth=(kdate-jyear*10000)/100
      jday=kdate-jyear*10000-jmonth*100
      jhour=ktime/100
      jmin=ktime-jhour*100
      mstart=24*60*(ndoy(jmonth)+jday-1) + 60*jhour + jmin ! mins from start of year
!     mtimer contains number of minutes since the start of the run.
      mins = mtimer + mstart

c   rml 25/08/03 write tracer data to timeseries file
      if (sitefile.ne.'') call writetimeseries(ktau,ntau,jyear,mins)
c     rml 26/11/03 write mobile tracer data to file
      if (shipfile.ne.'') call writeshipts(ktau,ntau,dt)

      return

      end subroutine
c *********************************************************************
      subroutine readsitelist(ntrac)
c
c     rml 25/08/03 subroutine to read file containing list of sites for 
c     timeseries output and to open netcdf file for output and 
c     write dimensions etc.
c
      use tracermodule, only : sitefile
      implicit none
      integer kount,kountprof,n,kount500
      integer ierr,ntrac
      integer griddim,ijkdim,timedim,tracdim,gridid,dims(3)
      integer surfdim,gridsurfid
      integer, allocatable, dimension(:,:) :: templist
      integer i,i1,nn,k,ntop
      character*13 outfile
      character*8 chtemp
      character*80 head
      include 'netcdf.inc'
      include 'dates.h'
      include 'newmpar.h'  ! kl

c     read file of site locations for timeseries output
      open(88,file=sitefile,form='formatted', status='unknown')
      read(88,*) head
c     number of gridpoints and output frequency (number of timesteps)
      read(88,*) ngrdpts1,ntsfreq
      allocate(templist(ngrdpts1,3))
      kountprof=0
      kount500=0
      do k=1,ngrdpts1
        read(88,*) i,i1,(templist(k,nn),nn=1,3)
c       check if any profiles requested
        if (templist(k,3).eq.99) kountprof=kountprof+1
        if (templist(k,3).eq.98) kount500=kount500+1
      enddo
c     read in additional variables to output besides tracer
      n2d=0
      n3d=0
      read(88,*,end=880) head
      read(88,*) n3d
      allocate(varname3(n3d))
      do n=1,n3d
        read(88,*) varname3(n)
      enddo
      read(88,*) head
      read(88,*) n2d
      allocate(varname2(n2d))
      do n=1,n2d
        read(88,*) varname2(n)
      enddo
 880  continue
      close(88)

      ngrdpts = ngrdpts1 + kountprof*(kl-1) + kount500*8
      allocate(listijk(ngrdpts,3))
      allocate(writesurf(ngrdpts))
      kount = 0
      do k=1,ngrdpts1
c     rml 11/11/05 add '98' option for all levels to ~500 hPa
        if (templist(k,3).ge.98) then
          if (templist(k,3).eq.98) then
            ntop = 9
          else
            ntop = kl
          endif
          do n=1,ntop
            kount = kount + 1
            listijk(kount,1:2) = templist(k,1:2)
            listijk(kount,3) = n
            if (n.eq.1) then
              writesurf(kount) = .true.
            else
              writesurf(kount) = .false.
            endif
          enddo
        else
          kount = kount + 1
          listijk(kount,:) = templist(k,:)
          writesurf(kount) = .true.
        endif
      enddo
      if (kount.ne.ngrdpts) stop 'location file: kount.ne.ngrdpts'
c     deallocate(templist)
      allocate(tsid(3+n3d+n2d))
c
c     open netcdf file for writing output
      write(chtemp,'(i8)') kdate
      outfile = 'ts.'//chtemp(1:4)//'.'//chtemp(5:6)//'.nc'
      ierr = nf_create(outfile,0,tsid(1))
      if (ierr.ne.nf_noerr) stop 'create ts file failed'
c     define dimensions
      ierr=nf_def_dim(tsid(1),'gridpts',ngrdpts,griddim)
      if (ierr.ne.nf_noerr) stop 'timeseries: grid dimension error'
      ierr=nf_def_dim(tsid(1),'surfpts',ngrdpts1,surfdim)
      if (ierr.ne.nf_noerr) stop 'timeseries: grid dimension error'
      ierr=nf_def_dim(tsid(1),'ijk',3,ijkdim)
      ierr=nf_def_dim(tsid(1),'tracers',ntrac,tracdim)
      if (ierr.ne.nf_noerr) stop 'timeseries: tracer dimension error'
      ierr=nf_def_dim(tsid(1),'time',nf_unlimited,timedim)
      if (ierr.ne.nf_noerr) stop 'timeseries: time dimension error'
c     define variables
      dims(1)=griddim; dims(2)=ijkdim
      ierr = nf_def_var(tsid(1),'grid',nf_int,2,dims,gridid)
      if (ierr.ne.nf_noerr) stop 'timeseries: grid var error'
      dims(1)=surfdim; dims(2)=ijkdim
      ierr = nf_def_var(tsid(1),'gridsurf',nf_int,2,dims,gridsurfid)
      if (ierr.ne.nf_noerr) stop 'timeseries: grid var error'
      ierr = nf_def_var(tsid(1),'time',nf_double,1,timedim,tsid(2))
      if (ierr.ne.nf_noerr) stop 'timeseries: tstime var error'
      dims(1)=griddim; dims(2)=tracdim; dims(3)=timedim
      ierr = nf_def_var(tsid(1),'concts',nf_float,3,dims,tsid(3))
      if (ierr.ne.nf_noerr) stop 'timeseries: concts var error'
      do n=1,n3d
        dims(1)=griddim; dims(2)=timedim
        ierr = nf_def_var(tsid(1),varname3(n),nf_float,2,dims(1:2),
     & tsid(3+n))
        if (ierr.ne.nf_noerr) stop 'timeseries: 3d var error'
      enddo
      do n=1,n2d
        if (trim(varname2(n)).eq.'flux') then
          dims(1)=surfdim; dims(2)=tracdim; dims(3)=timedim
          ierr = nf_def_var(tsid(1),varname2(n),nf_float,3,dims,
     & tsid(3+n3d+n))
          if (ierr.ne.nf_noerr) stop 'timeseries: 2d var error'
        else
          dims(1)=surfdim; dims(2)=timedim
          ierr = nf_def_var(tsid(1),varname2(n),nf_float,2,dims(1:2),
     & tsid(3+n3d+n))
          if (ierr.ne.nf_noerr) stop 'timeseries: 2d var error'
        endif
      enddo
c
c     leave define mode
      ierr = nf_enddef(tsid(1))
      if (ierr.ne.nf_noerr) stop 'timeseries: end define error'
c
c     write grid point arrays
      ierr = nf_put_var_int(tsid(1),gridid,listijk)
      if (ierr.ne.nf_noerr) stop 'error writing grid'
      ierr = nf_put_var_int(tsid(1),gridsurfid,templist)
      if (ierr.ne.nf_noerr) stop 'error writing gridsurf'
      ierr = nf_sync(tsid(1))
      deallocate(templist)
c
      indextime=1
      return
      end subroutine
c
c **********************************************************************
   
      subroutine writetimeseries(ktau,ntau,jyear,mins)

c
c     rml: subroutine to write timeseries data to netcdf file
c  rml 10/11/05: added pressure, surface flux and pblh for TC
c
      use tracermodule, only : co2em,unit_trout
      implicit none
      real, dimension(:,:), allocatable :: cts
      real, dimension(:), allocatable :: vts
      integer ierr,start(3),count(3),n,iq,kount,m,jyear,mins
      integer ktau,ntau,k
      logical surfflux
      include 'netcdf.inc'
!!!      include 'cbmdim.h'
      include 'newmpar.h'    ! dimensions for tr array
      include 'tracers.h'    ! ntrac and tr array
      include 'extraout.h'   ! cloud arrays
      include 'arrays.h'     ! temp, q, ps
      include 'soil.h'       ! albedo
      include 'prec.h'       ! precip
      include 'vvel.h'       ! vertical velocity
      include 'pbl.h'        ! tss
      include 'morepbl.h'    ! rnet,eg,fg
      include 'soilsnow.h'   ! soil temp (tgg)
!!!      include 'nsibd.h'      ! rlai
      include 'sigs.h'       ! sigma levels for pressure
!!!      common/permsurf/ipsice,ipsea,ipland,iperm(ifull)
!!!      common/co2fluxes/pfnee(mp),pfpn(mp),pfrp(mp),pfrpw(mp),pfrpr(mp)
!!!     .       ,pfrs(mp) 



      real temparr2(il*jl,kl),temparr(il*jl)

      if (mod(ktau,ntsfreq).eq.0) then
        tstime = float(jyear) + mins/(365.*24.*60.)
        ierr = nf_put_var1_double(tsid(1),tsid(2),indextime,tstime)
        if (ierr.ne.nf_noerr) stop ': error writing tstime'
        allocate(cts(ngrdpts,ntrac))
        do n=1,ngrdpts
          iq = listijk(n,1) + (listijk(n,2)-1)*il
          cts(n,:)=tr(iq,listijk(n,3),:)
        enddo
        start(1)=1; start(2)=1; start(3)=indextime
        count(1)=ngrdpts; count(2)=ntrac; count(3)=1
        ierr=nf_put_vara_real(tsid(1),tsid(3),start,count,cts)
        if (ierr.ne.nf_noerr) stop 'error writing cts'
        deallocate(cts)
c
        do m=1,n3d
          select case(trim(varname3(m)))
          case ('t') ; temparr2=t(1:ifull,:)
          case ('u') ; temparr2=u(1:ifull,:)
          case ('v') ; temparr2=v(1:ifull,:)
          case ('qg') ; temparr2=qg(1:ifull,:)
          case ('sdotm') ; temparr2=sdot(:,1:kl)
          case ('sdotp') ; temparr2=sdot(:,2:kl+1)
          case ('pressure')
            do k=1,kl
              temparr2(:,k)=ps(1:ifull)*sig(k)
            enddo
          case default 
            write(unit_trout,*) varname3(m),' not found'
            stop
          end select
          allocate(vts(ngrdpts))
          do n=1,ngrdpts
            iq = listijk(n,1) + (listijk(n,2)-1)*il
            vts(n)=temparr2(iq,listijk(n,3))
          enddo
          start(1)=1; start(2)=indextime
          count(1)=ngrdpts; count(2)=1
          ierr=nf_put_vara_real(tsid(1),tsid(3+m),start(1:2),count(1:2),
     &                          vts)
          if (ierr.ne.nf_noerr) stop 'error writing vts'
          deallocate(vts)
        enddo
c
        do m=1,n2d
          temparr=0.
          surfflux=.false.
          select case(trim(varname2(m)))
          case ('cloudlo') ; temparr=cloudlo
          case ('cloudmi') ; temparr=cloudmi
          case ('cloudhi') ; temparr=cloudhi
          case ('ps')      ; temparr=ps(1:ifull)
          case ('tss')     ; temparr=tss
          case ('rnet')    ; temparr=rnet
          case ('eg')      ; temparr=eg
          case ('fg')      ; temparr=fg
          case ('alb')     ; temparr=alb
          case ('sgsave')  ; temparr=sgsave
          case ('rgsave')  ; temparr=rgsave
          case ('precip')  ; temparr=precip
          case ('tgg4')    ; temparr=tgg(:,4)
          case ('tgg5')    ; temparr=tgg(:,5)
          case ('tgg6')    ; temparr=tgg(:,6)
!!!          case ('rlai')    ; temparr=rlai
!!!          case ('pfnee') 
!!!            do ip=1,ipland
!!!              temparr(iperm(ip))=pfnee(ip)
!!!            enddo
!!!          case ('pfpn')
!!!            do ip=1,ipland
!!!              temparr(iperm(ip))=pfpn(ip)
!!!            enddo
!!!          case ('pfrp')
!!!            do ip=1,ipland
!!!              temparr(iperm(ip))=pfrp(ip)
!!!            enddo
!!!          case ('pfrs')
!!!            do ip=1,ipland
!!!              temparr(iperm(ip))=pfrs(ip)
!!!            enddo
          case ('pblh') ; temparr=pblh
          case ('flux')  
            allocate(cts(ngrdpts1,ntrac))
            kount=0
            do n=1,ngrdpts
              if (writesurf(n)) then
                 kount=kount+1
                 iq = listijk(n,1) + (listijk(n,2)-1)*il
                 cts(kount,:)=co2em(iq,:)
              endif
            enddo 
            start(1)=1; start(2)=1; start(3)=indextime
            count(1)=ngrdpts1; count(2)=ntrac; count(3)=1
            ierr=nf_put_vara_real(tsid(1),tsid(3+n3d+m),start,count,cts)
            if (ierr.ne.nf_noerr) stop 'error writing cts'
            deallocate(cts)
            surfflux=.true.
          case default
            write(unit_trout,*) trim(varname2(m)),' not found'
            stop
          end select
          
          if (.not.surfflux) then
            allocate(vts(ngrdpts1))
            kount = 0
            do n=1,ngrdpts
              if (writesurf(n)) then
                kount = kount+1
                iq = listijk(n,1) + (listijk(n,2)-1)*il
                vts(kount)=temparr(iq)
              endif
            enddo
            start(1)=1; start(2)=indextime
            count(1)=ngrdpts1; count(2)=1
            ierr=nf_put_vara_real(tsid(1),tsid(3+n3d+m),start(1:2),
     &                            count(1:2),vts)
            if (ierr.ne.nf_noerr) stop 'error writing vts'
            deallocate(vts)
          endif
        enddo

c
        ierr=nf_sync(tsid(1))
        indextime=indextime+1
      endif
      if (ktau.eq.ntau) ierr=nf_close(tsid(1))
c

      return
      end subroutine
c *********************************************************************
      subroutine readshiplist(ntrac,dt)
c
c     rml 25/11/03 subroutine to read file containing times and locations
c     of ship (or other mobile obs).  Also opens netcdf file for output.
c
      use tracermodule, only : shipfile
      implicit none
      integer ok,nptsdim,dateid,timeid,ntrac,i,i2
      integer dtlsdim,nvaldim,outshipid(3),dims(2),tracdim
      real dt
      character*15 outfile2
      character*8 chtemp
      include 'netcdf.inc'
      include 'dates.h'
c
c     open file with ship locations
      ok = nf_open(shipfile,0,inshipid(1))
      if (ok.ne.nf_noerr) stop 'readshiplist: open file failure'
      ok = nf_inq_dimid(inshipid(1),'npts',nptsdim)
      if (ok.ne.nf_noerr) stop 'readshiplist: read nptsdim failure'
      ok = nf_inq_dimlen(inshipid(1),nptsdim,nshippts)
      if (ok.ne.nf_noerr) stop 'readshiplist: read dimlen failure'
c     read times for ship samples
      allocate(shipdate(nshippts),shiptime(nshippts))
      ok = nf_inq_varid(inshipid(1),'date',dateid)
      if (ok.ne.nf_noerr) stop 'readshiplist: read dateid failure'
      ok = nf_get_var_int(inshipid(1),dateid,shipdate)
      if (ok.ne.nf_noerr) stop 'readshiplist: read shipdate failure'
      ok = nf_inq_varid(inshipid(1),'time',timeid)
      if (ok.ne.nf_noerr) stop 'readshiplist: read timeid failure'
      ok = nf_get_var_int(inshipid(1),timeid,shiptime)
      if (ok.ne.nf_noerr) stop 'readshiplist: read shiptime failure'
      ok = nf_inq_varid(inshipid(1),'loc',inshipid(2))
      if (ok.ne.nf_noerr) stop 'readshiplist: read locid failure'
      ok = nf_inq_varid(inshipid(1),'lev',inshipid(4))
      if (ok.ne.nf_noerr) stop 'readshiplist: read locid failure'
      ok = nf_inq_varid(inshipid(1),'ship',inshipid(3))
      if (ok.ne.nf_noerr) stop 'readshiplist: read shipid failure'
c
c     locate sample time just smaller than current time
      do i=1,nshippts
        if (shipdate(i).lt.kdate) then
          indship=i
        endif
      enddo
      i2=indship
      do i=i2+1,nshippts
        if (shipdate(i).eq.kdate.and.
     &    shiptime(i).lt.ktime+nint(dt)/120) then !half interval to next ktime
          indship=i
        endif
      enddo
c
c     open netcdf file for output  
      write(chtemp,'(i8)') kdate
      outfile2 = 'ship.'//chtemp(1:4)//'.'//chtemp(5:6)//'.nc'
      ok = nf_create(outfile2,0,outshipid(1))
      if (ok.ne.nf_noerr) stop 'readshiplist: create error'
      ok=nf_def_dim(outshipid(1),'nshiptrac',ntrac,tracdim)
      if (ok.ne.nf_noerr) stop 'readshiplist: tracer dimension error'
c    rml 18/12/03 increased dimension to include level for aircraft output
      ok = nf_def_dim(outshipid(1),'date_time_loc_ship',5,dtlsdim)
      if (ok.ne.nf_noerr) stop 'readshiplist: dtls dimension error'
      ok = nf_def_dim(outshipid(1),'nval',nf_unlimited,nvaldim)
      if (ok.ne.nf_noerr) stop 'readshiplist: npt dimension error'
      dims(1)=dtlsdim; dims(2)=nvaldim
      ok = nf_def_var(outshipid(1),'shipinfo',nf_int,2,dims,
     &                outshipid(2))
      if (ok.ne.nf_noerr) stop 'readshiplist: shipinfo variable error'
      dims(1)=tracdim; dims(2)=nvaldim
      ok = nf_def_var(outshipid(1),'tsship',nf_float,2,dims,
     &                outshipid(3))
      if (ok.ne.nf_noerr) stop 'readshiplist: shiptracer variable error'
      ok = nf_enddef(outshipid(1))
      if (ok.ne.nf_noerr) stop 'readshiplist: end define error'

      nshipout=0
      return
      end subroutine
c ********************************************************************
      subroutine writeshipts(ktau,ntau,dt)
c
c     rml 25/11/03 subroutine to write mobile timeseries e.g. ship
c
      implicit none
      integer ktau,ntau,ok,iloc,ilev,iship,ierr
      integer jdate1,jdate2,jtime1,jtime2,mon
      real dt
      integer start(2),kount(2),info(5)
      logical moredat,found
      integer monlen(12)
      data monlen/31,28,31,30,31,30,31,31,30,31,30,31/
      
      include 'newmpar.h'    ! dimensions for tr array
      include 'netcdf.inc'
      include 'tracers.h'
      include 'dates.h'
c
c     if reached end of data leave subroutine
      if (indship+1.gt.nshippts) return

c     assume always running in one month blocks so don't worry about
c     having to increment across months

      mon=(kdate-10000*(kdate/10000))/100
      if (mtimer.eq.monlen(mon)*60*24) then
c       end of month case
        jdate2 = kdate + 100
        jdate1 = kdate + monlen(mon)-1
      else
        jdate2 = kdate + mtimer/1440
        jdate1 = jdate2-1
      endif
      jtime1 = mod(mtimer-nint(dt)/120,1440)
      jtime1 = 100*(jtime1/60) + mod(jtime1,60)
      jtime2 = mod(mtimer+nint(dt)/120,1440)
      jtime2 = 100*(jtime2/60) + mod(jtime2,60)
c     check if sample time in current timestep (from jtime to jtime+dt)
c     assume ktime+dt will never force increment to kdate
      moredat=.true.
      do while (moredat)
        found=.false.
        if (jtime1.lt.jtime2) then
          if (shipdate(indship+1).eq.jdate2.and.
     &      shiptime(indship+1).ge.jtime1.and.
     &      shiptime(indship+1).lt.jtime2) found=.true.
        else
c         end of day case
          if ((shipdate(indship+1).eq.jdate1.and.
     &      shiptime(indship+1).ge.jtime1).or.
     &      (shipdate(indship+1).eq.jdate2.and.
     &      shiptime(indship+1).lt.jtime2)) found=.true.
        endif
        if (found) then
          nshipout = nshipout+1
c         keep real sample time rather than model time for easier
c         match to data
          info(1) = shipdate(indship+1)
          info(2) = shiptime(indship+1)
          ok = nf_get_var1_int(inshipid(1),inshipid(2),indship+1,iloc)
          if (ok.ne.nf_noerr) stop 'writeshipts: read loc error'
          info(3) = iloc
c    rml 18/12/03 addition of level info to do aircraft output
          ok = nf_get_var1_int(inshipid(1),inshipid(4),indship+1,ilev)
          if (ok.ne.nf_noerr) stop 'writeshipts: read lev error'
          info(4) = ilev
          ok = nf_get_var1_int(inshipid(1),inshipid(3),indship+1,iship)
          if (ok.ne.nf_noerr) stop 'writeshipts: read ship error'
          info(5) = iship
          start(1)=1; start(2)=nshipout
          kount(1)=5; kount(2)=1
          ok = nf_put_vara_int(outshipid(1),outshipid(2),start,kount,
     &                         info)
          if (ok.ne.nf_noerr) stop 'writeshipts: write info error'
          start(1)=1; start(2)=nshipout
          kount(1)=ntrac; kount(2)=1
          ok = nf_put_vara_real(outshipid(1),outshipid(3),start,kount,
     &                         tr(iloc,ilev,:))
          if (ok.ne.nf_noerr) stop 'writeshipts: write shipts error'

          indship=indship+1
        else
          moredat=.false.
        endif
      enddo
      ierr=nf_sync(outshipid(1))
      if (ktau.eq.ntau) then
        ok=nf_close(inshipid(1))
        ierr=nf_close(outshipid(1))
      endif
 
      return
      end subroutine

      end module
c     include 'latltoij.f'  ! watch out for ncray=1
!     has sigmf (& alb) fix-ups for adelaide, perth, darwin, sydney, brisbane

      subroutine indata(hourst,newsnow,jalbfix)! nb  newmask not yet passed thru
c     indata.f bundles together indata, insoil, rdnsib, tracini, co2
      use cc_mpi
      use diag_m
      implicit none
c     parameter (gwdfac=.02)  ! now .02 for lgwd=2  see below
      integer, parameter :: jlmsigmf=1  ! 1 for jlm fixes to dean's data
c     parameter (jalbfix=1)   ! 1 for jlm fixes to albedo
      integer, parameter :: nfixwb=2      ! 0, 1 or 2; wb fixes with nrungcm=1
c     indataj can read land-sea mask from topofile
c             alat, along calc now done here; defaults in blockdtb
c             sets hourst (gmt) from ktime
c             precc, precip setup moved to bottom
c     note: unformatted qg in g/kg
      include 'newmpar.h'
      include 'aalat.h'
      include 'arrays.h'
      include 'const_phys.h'
      include 'dates.h'     ! mtimer
      include 'dava.h'      ! davt
      include 'filnames.h'  ! list of files, read in once only
      include 'gdrag.h'
      include 'indices.h'
      include 'latlong.h'   ! rlatt, rlongg
      include 'map.h'
      include 'morepbl.h'
      include 'nsibd.h'     ! rsmin,ivegt,sigmf,tgf,ssdn,res,rmc,tsigmf
      include 'parm.h'
      include 'parmdyn.h'   ! epsp
      include 'parm_nqg.h'  ! nqg_r,nqg_set
      include 'pbl.h'
      include 'permsurf.h'
      include 'prec.h'
!     include 'scamdim.h'
      include 'sigs.h'
      include 'soil.h'      ! sice,sicedep,fracice
      include 'soilsnow.h'  ! tgg,wb
      include 'soilv.h'
      include 'stime.h'
      include 'tracers.h'
      include 'trcom2.h'    ! trcfil,nstn,slat,slon,istn,jstn
      include 'vecs.h'
      include 'xyzinfo.h'   ! x,y,z,wts
      include 'vecsuv.h'    ! vecsuv info
      include 'mpif.h'
      real, intent(out) :: hourst
      integer, intent(in) :: newsnow, jalbfix
      real epst
      common/epst/epst(ifull)
      integer neigh
      common/neigh/neigh(ifull)
      real rlong0x,rlat0x,schmidtx
      common/schmidtx/rlong0x,rlat0x,schmidtx ! infile, newin, nestin, indata
      real sigin
      integer kk
      common/sigin/sigin(kl),kk  ! for vertint, infile
!     common/work3/p(ifull,kl),dum3(ifull,kl,4)
c     watch out in retopo for work/zss
      real zss, psav, tsss, dum0, dumzs, aa, bb, dum2
      common/work2/zss(ifull),psav(ifull),tsss(ifull),dum0(ifull),
     &  dumzs(ifull,3),aa(ifull),bb(ifull),dum2(ifull,9)
      real tbarr(kl),qgin(kl)
      character co2in*80,radonin*80,surfin*80,header*80,qgfile*20

!     for the held-suarez test
      real, parameter :: delty = 60. ! pole to equator variation in equal temperature
      real, parameter :: deltheta = 10. ! vertical variation
      real, parameter :: rkappa = 2./7.

      integer :: lapsbot=0
      real :: pmsl=1.010e5, thlapse=3.e-3, tsea=290., gauss=2.,
     &        heightin=2000., hfact=0.1, uin=0., vin=0.
      namelist/tin/gauss,heightin,hfact,pmsl,qgin,tbarr,tsea,uin,vin
     &             ,thlapse,kdate,ktime

      integer i1, ii, imo, indexi, indexl, indexs, ip, iq, isoil, isoth,
     &     iveg, iyr, j1, jj, k, kdate_sav, kmax, ktime_sav, l,
     &     meso2, nem2, nface, nn, nsig, i, j, n,
     &     ix, jx, ixjx, ierr
      real aamax, aamax_g, c, cent, 
     &     coslat, coslong, costh, den, diffb, diffg, dist,
     &     epsmax, fracs, fracwet, ftsoil, gwdfac, hefact,
     &     helim, hemax, hemax_g, polenx, poleny,
     &     polenz, rad, radu, radv, ri, rj, rlai, rlat_d, rlon_d,
     &     rmax, rmin, sinlat, sinlong, sinth, snalb, sumdsig,
     &     timegb, tsoil, uzon, vmer, w,
     &     wet3, zonx, zony, zonz, zsdiff, zsmin, tstom, distnew

      real, dimension(44), parameter :: vegpmin = (/
     &              .98,.85,.85,.5,.2,.1 ,.85,.5,.2,.5,                ! 1-10
     &              .2,.1 ,.5,.2,.1 ,.1,.1 ,.85,.5,.2,                 ! 11-20
     &              .1 ,.85,.60,.50,.5 ,.2,.1 ,.5, .0, .0, .4,         ! 21-31
     &              .98,.75,.75,.75,.5,.86,.65,.79,.3, .42,.02,.54,0./)! 32-44
      real, dimension(44), parameter :: vegpmax = (/
     &              .98,.85,.85,.5,.7,.60,.85,.5,.5,.5,                ! 1-10
     &              .5,.50,.5,.6,.60,.4,.40,.85,.5,.8,                 ! 11-20
     &              .20,.85,.85,.50,.80,.7,.40,.5, .0, .0, .6,         ! 21-31
     &              .98,.75,.75,.75,.5,.86,.65,.79,.3, .42,.02,.54,0./)! 32-44

      real, dimension(12), parameter :: fracsum =
     &       (/-.5,-.5,-.3,-.1,.1, .3, .5, .5, .3, .1,-.1,-.3/)
      real, dimension(44), parameter :: fracwets = (/
     &              .5, .5, .5, .5, .5, .5, .5, .5, .5, .5,     !  1-10 summer
     &              .5, .5, .5, .5, .5, .5, .5, .5, .5, .5,     ! 11-20 summer
     &              .5, .5, .5, .5, .5, .5, .5, .5, .5, .5, .5, ! 21-31 summer
     & .5,.5, .3, .3, .3, .15, .15, .15, .1, .15, .02, .35, .5/)! 32-44 summer
      real, dimension(44), parameter :: fracwetw = (/
     &              .5, .5, .5, .5, .5, .5, .5, .5, .5, .5,     !  1-10 winter
     &              .5, .5, .5, .5, .5, .5, .5, .5, .5, .5,     ! 11-20 winter
     &              .5, .5, .5, .5, .5, .5, .5, .5, .5, .5, .5, ! 21-31 winter
     & .5,.5, .6, .6, .6, .25, .3 , .25, .2, .25, .05, .6, .5 /)! 32-44 winter
      real, dimension(ifull_g) :: glob2d

      bam(1)=114413.
c     now always read eig file fri  12-18-1992
!     All processes read this
      read(28,*)kmax,lapsbot,isoth,nsig
      if (myid==0) print*,'kl,lapsbot,isoth,nsig: ',
     &             kl,lapsbot,isoth,nsig
      if(kmax.ne.kl)then
        print *,'file 28 wrongly has kmax = ',kmax
        stop
      endif
      read(28,*)(sig(k),k=1,kl),(tbar(k),k=1,kl),(bam(k),k=1,kl)
     & ,((emat(k,l),k=1,kl),l=1,kl),((einv(k,l),k=1,kl),l=1,kl),
     & (qvec(k),k=1,kl),((tmat(k,l),k=1,kl),l=1,kl)
      if (myid==0) print*,'kmax,lapsbot,sig from eigenv file: ',
     &                     kmax,lapsbot,sig
      ! File has an sigmh(kl+1) which isn't required. Causes bounds violation
      ! to read this.
      ! read(28,*)(sigmh(k),k=1,kl+1) !runs into dsig, but ok
      read(28,*)(sigmh(k),k=1,kl) 
!     if(epsp.ne.0.)then              ! done in adjust5 from 16/5/00
!       print *,'bam altered because epsp =',epsp
!       do k=1,kl
!        bam(k)=(1.+epsp)*bam(k)
!       enddo
!     endif
      if (myid==0) then
         print *,'tbar: ',tbar
         print *,'bam: ',bam
      end if

c     read in namelist for uin,vin,tbarr etc. for special runs
c     note that kdate, ktime will be overridden by infile values for io_in<4
      if (myid==0) print *,'now read namelist tinit'
      read (99, tin)
      if (myid==0) write(6, tin)

      do iq=1,ifull
       snowd(iq)=0.
      enddo   ! iq loop

      if (myid==0) then
         print *,'iradon,ico2,iso2,iso4,ich4,io2 ',
     &            iradon,ico2,iso2,iso4,ich4,io2
         print *,'nllp,ngas,ntrac,ilt,jlt,klt ',
     &            nllp,ngas,ntrac,ilt,jlt,klt
      end if
      if(ngas.gt.0)call tracini  ! set up trace gases

!     read in fresh zs, land-sea mask (land where +ve), variances
!     Need to share iostat around here to do it properly?
      if(io_in.le.4)then
         if (myid==0) then
            print *,'before read zs from topofile'
            ! read(66,*,end=58)(zs(iq),iq=1,ifull) ! formatted zs
            read(66,*,end=58) glob2d
            call ccmpi_distribute(zs,glob2d)
         else
            call ccmpi_distribute(zs)
         end if
         if (myid==0) then
            print *,'before read land-sea array'
            ! read(66,*,end=58)(dumzs(iq,2),iq=1,ifull) ! formatted mask
            read(66,*,end=58) glob2d
            print *,'after read land-sea array'
            call ccmpi_distribute(dumzs(:,2),glob2d)
         else
            call ccmpi_distribute(dumzs(:,2))
         end if
         do iq=1,ifull
            if(dumzs(iq,2).ge.0.5)then
               land(iq)=.true. 
            else
               land(iq)=.false.
            endif  
         enddo                  ! iq loop
!        following is land fix for cape grim radon runs    **************
         if(rlat0.gt.-26.9.and.rlat0.lt.-26.7)stop
!	  had  land(37,47)=.false.
         if (myid==0) then
            ! read(66,*,end=58)(he(iq),iq=1,ifull) ! formatted in meters
            read(66,*,end=58) glob2d
            call ccmpi_distribute(he,glob2d)
         else
            call ccmpi_distribute(he)
         end if
         if ( mydiag ) print *,'he read in from topofile',he(idjd)
         go to 59
 58      print *,'end-of-file reached on topofile'
 59      close(66)
      endif   ! (io_in.le.4)

      if ( mydiag ) then
         write(6,"('zs#_topof ',9f7.1)") diagvals(zs)
!     &            ((zs(ii+(jj-1)*il),ii=id-1,id+1),jj=jd-1,jd+1)
         write(6,"('he#_topof ',9f7.1)") diagvals(he)
!     &            ((he(ii+(jj-1)*il),ii=id-1,id+1),jj=jd-1,jd+1)
      end if

      if(nhstest.lt.0)then  ! aquaplanet test -22   from June 2003
        do iq=1,ifull
         zs(iq)=0.
        enddo   ! iq loop
      endif  !  (nhstest.lt.0)

      hourst = 0. ! Some io_in options don't set it.
      if(io_in.lt.4)then
         kdate_sav=kdate_s
         ktime_sav=ktime_s
	 if(io_in.eq.1.or.io_in.eq.3)then
            call infile(meso2,kdate,ktime,nem2,
     &                  timegb,ds,psl,ps,zss,aa,bb,
     &                  tss,precip,wb,wbice,alb,snowd,sicedep,
     &                  t(1:ifull,:),u(1:ifull,:),v(1:ifull,:),
     &                  qg(1:ifull,:),tgg,
     &                  tggsn,smass,ssdn, ssdnn,osnowd,snage,isflag,0)
            if ( mydiag ) then
               print *,'meso2,timegb,ds,zss',meso2,timegb,ds,zss(idjd)
               print *,'kdate_sav,ktime_sav ',kdate_sav,ktime_sav
               print *,'kdate_s,ktime_s >= ',kdate_s,ktime_s
               print *,'kdate,ktime ',kdate,ktime
            end if
            if(kdate.ne.kdate_sav.or.ktime.ne.ktime_sav)stop
     &       'stopping in indata, not finding correct kdate/ktime'
            if(abs(rlong0  -rlong0x).gt..01.or.
     &         abs(rlat0    -rlat0x).gt..01.or.
     &       abs(schmidt-schmidtx).gt..01)stop "grid mismatch in indata"
         endif                  ! (io_in.eq.1.or.io_in.eq.3)

	 if(io_in.eq.-1.or.io_in.eq.-3)then
            call onthefly(kdate,ktime,psl,zss,tss,wb,wbice,snowd,
     &                    sicedep,
     &                    t,u,v,qg,tgg,
     &                    tggsn,smass,ssdn, ssdnn,osnowd,snage,isflag,0)
	 endif   ! (io_in.eq.-1.or.io_in.eq.-3)
	 	 
         if(newtop.eq.2)then
!           reduce sea tss to mslp      e.g. for qcca in ncep gcm
            do iq=1,ifull
               if(tss(iq).lt.0.)then
                  if(abs(zss(iq)).gt.1000.)print*,'zss,tss_sea in, out',
     &                 iq,zss(iq),tss(iq),tss(iq)-zss(iq)*stdlapse/grav
                  tss(iq)=tss(iq)-zss(iq)*stdlapse/grav ! n.b. -
               endif
            enddo
         endif                  ! (newtop.eq.2)

         if ( myid == 0 ) then
            print *,'rlatt(1),rlatt(ifull) ',rlatt(1),rlatt(ifull)
            print *,'rlongg(1),rlongg(ifull) ',rlongg(1),rlongg(ifull)
            print *,'using em: ',(em(ii),ii=1,10)
            print *,'using  f: ',(f(ii),ii=1,10)
         end if
         hourst=.01*ktime
         if ( myid == 0 ) then
            print *,'in indata hourst = ',hourst
            print *,'sigmas: ',sig
            print *,'sigmh: ',sigmh
         end if

         if (mydiag) print *,'t into indata ',t(idjd,:)
         if(kk.lt.kl)then
            if (mydiag) print *,
     &            '** interpolating multilevel data vertically to new'//
     &            ' sigma levels'
            call vertint(t, 1)
            if ( mydiag ) print *,'t after vertint ',t(idjd,:)
            call vertint(qg,2)
            call vertint(u, 3)
            call vertint(v, 4)
         endif

         if ( mydiag ) then
            print *,'newtop, zsold, zs,tss_in,land '
     &              ,newtop,zss(idjd),zs(idjd),tss(idjd),land(idjd)
         end if
         if(newtop.ge.1)then    ! don't need to do retopo during restart
            do iq=1,ifull
               if(land(iq))then
                  tss(iq)=tss(iq)+(zss(iq)-zs(iq))*stdlapse/grav
                  do k=1,ms
                     tgg(iq,k)=tgg(iq,k)+(zss(iq)-zs(iq))*stdlapse/grav
                  enddo
               endif
            enddo               ! iq loop
            if ( mydiag ) then
               print *,'newtop>=1 new_land_tss,zsold,zs: ',
     &                    tss(idjd),zss(idjd),zs(idjd)
!         compensate psl, t(,,1), qg as read in from infile
               write(6,"('zs#  in     ',9f7.1)") diagvals(zs)
!     &              ((zs(ii+(jj-1)*il),ii=id-1,id+1),jj=jd-1,jd+1)
               write(6,"('zss# in     ',9f7.1)") diagvals(zss)
!     &              ((zss(ii+(jj-1)*il),ii=id-1,id+1),jj=jd-1,jd+1)
               write(6,"('100*psl#  in',9f7.2)") 100.*diagvals(psl)
!     &            ((100.*psl(ii+(jj-1)*il),ii=id-1,id+1),jj=jd-1,jd+1)
               print *,'now call retopo from indata'
            end if
            call retopo(psl,zss,zs,t(1:ifull,:),qg(1:ifull,:))
            if(nmaxpr.eq.1.and.mydiag)then
               write(6,"('100*psl# out',9f7.2)") 100.*diagvals(psl)
!     &              ((100.*psl(ii+(jj-1)*il),ii=id-1,id+1),jj=jd-1,jd+1)
          endif
        endif   ! (newtop.ge.1)

      endif   ! (io_in.lt.4)

      do k=1,kl-1
       dsig(k)=sigmh(k+1)-sigmh(k)
      enddo
      dsig(kl)=-sigmh(kl)
      sumdsig=0.
      do k=1,kl
       sumdsig=sumdsig-dsig(k)
       tbardsig(k)=0.
      enddo
      if ( myid == 0 ) print *,'dsig,sumdsig ',dsig,sumdsig
      if(isoth.ge.0)then
        dtmax=1./(sig(1)*log(sig(1)/sig(2)))
        tbardsig(1)=dtmax*(tbar(1)-tbar(2))
        do k=2,kl-1
         tbardsig(k)=(tbar(k+1)-tbar(k-1))/(2.*dsig(k))
        enddo
      endif
c     rata and ratb are used to interpolate half level values to full levels
c     ratha and rathb are used to interpolate full level values to half levels
      rata(kl)=(sigmh(kl)-sig(kl))/sigmh(kl)
      ratb(kl)=sig(kl)/sigmh(kl)
      do k=1,kl-1
       bet(k+1)=rdry*log(sig(k)/sig(k+1))*.5
       rata(k)=(sigmh(k)-sig(k))/(sigmh(k)-sigmh(k+1))
       ratb(k)=(sig(k)-sigmh(k+1))/(sigmh(k)-sigmh(k+1))
       ratha(k)=(sigmh(k+1)-sig(k))/(sig(k+1)-sig(k))
       rathb(k)=(sig(k+1)-sigmh(k+1))/(sig(k+1)-sig(k))
      enddo

      if ( myid == 0 ) then
         print *,'rata ',rata
         print *,'ratb ',ratb
         print *,'ratha ',ratha
         print *,'rathb ',rathb
      end if
      c=grav/stdlapse
      bet(1)=c *(sig(1)**(-rdry/c)-1)
      if(lapsbot.eq.1)bet(1)=-rdry*log(sig(1))
      do k=1,kl
       betm(k)=bet(k)
      enddo
      if(lapsbot.eq.2)then   ! may need refinement for non-equal spacing
        do k=2,kl
         bet(k)=.5*rdry*(sig(k-1)-sig(k))/sig(k)
         betm(k)=.5*rdry*(sig(k-1)-sig(k))/sig(k-1)
        enddo
        bet(1)=rdry*(1.-sig(1))/sig(1)
      endif

      do iq=1,ifull
       ps(iq)=1.e5*exp(psl(iq))
      enddo  !  iq loop

      if(io_in.ge.5)then
         nsib=0
c        for rotated coordinate version, see jmcg's notes
         coslong=cos(rlong0*pi/180.)
         sinlong=sin(rlong0*pi/180.)
         coslat=cos(rlat0*pi/180.)
         sinlat=sin(rlat0*pi/180.)
         polenx=-coslat
         poleny=0.
         polenz=sinlat
         print *,'polenx,poleny,polenz ',polenx,poleny,polenz
         cent=.5*(il_g+1)  ! True center of face
         do k=1,kl
            do iq=1,ifull
               t(iq,k)=tbarr(k)
               qg(iq,k)=qgin(k)
               psl(iq)=.01
            enddo               ! iq loop
            do j=1,jpan
               do i=1,ipan
                  ! Need to add offsets to get proper face indices
                  rad=sqrt((i+ioff-cent)**2+(j+joff-cent)**2)
                  radu=sqrt((i+ioff+.5-cent)**2+(j+joff-cent)**2)
                  radv=sqrt((i+ioff-cent)**2+(j+joff+.5-cent)**2)
                  do n=1,npan
                     iq=indp(i,j,n)
                     u(iq,k)=uin*max(1.-radu/(.5*il_g),0.)
                     v(iq,k)=vin*max(1.-radv/(.5*il_g),0.)
c           if((n.eq.0.or.n.eq.2).and.io_in.ge.6.and.k.eq.kl)
c    &        zs(iq)=grav*heightin*max(1.-rad/(.5*il),0.)
                     if(io_in.ge.7.and.k.eq.kl)then
                        ps(iq)=1.e5*(1.-log(1. + thlapse*zs(iq)
     &                    /(grav*tsea))  *grav/(cp*thlapse)) **(cp/rdry)
                        psl(iq)= log(1.e-5*ps(iq))
                     endif
                  enddo         ! n loop
               enddo            ! i loop
            enddo               ! j loop
         enddo                  ! k loop
      endif                     ! io_in.ge.5

      if(io_in.eq.8)then
c        assign u and v from zonal and meridional uin and vin (no schmidt here)
c        with zero at poles
         do iq=1,ifull
            psl(iq)=.01
            uzon=uin * abs(cos(rlatt(iq)))
            vmer=vin * abs(cos(rlatt(iq)))
c           den=sqrt( max(x(iq)**2 + y(iq)**2,1.e-7) )  ! allow for poles
c           costh=(-y(iq)*ax(iq) + x(iq)*ay(iq))/den
c           sinth=az(iq)/den
c           set up unit zonal vector components
            zonx=            -polenz*y(iq)
            zony=polenz*x(iq)-polenx*z(iq)
            zonz=polenx*y(iq)
            den=sqrt( max(zonx**2 + zony**2 + zonz**2,1.e-7) ) ! allow for poles
            costh= (zonx*ax(iq)+zony*ay(iq)+zonz*az(iq))/den
            sinth=-(zonx*bx(iq)+zony*by(iq)+zonz*bz(iq))/den
            do k=1,kl
c             calculate u and v relative to the cc grid,
               u(iq,k)= costh*uzon+sinth*vmer
               v(iq,k)=-sinth*uzon+costh*vmer
            enddo  ! k loop
         enddo      ! iq loop
c       special option to display panels
         if(uin.lt.0.)then
            do n=1,npan
               do j=1,jpan
                  do i=1,ipan
                     iq=indp(i,j,n)
                     u(iq,:) = n - noff
                     t(iq,:) = 0.0001 + n - noff
                  enddo
               enddo
            enddo
         endif
      endif

!     for the held-suarez test
      if ( io_in .eq. 10 ) then
         vin=0.
         do k=1,kl
            do iq=1,ifull
c          den=sqrt( max(x(iq)**2 + y(iq)**2,1.e-7) ) ! allow for poles
c          costh=(-y(iq)*ax(iq) + x(iq)*ay(iq))/den
c          sinth=az(iq)/den
c          set up unit zonal vector components
               zonx=            -polenz*y(iq)
               zony=polenz*x(iq)-polenx*z(iq)
               zonz=polenx*y(iq)
               den=sqrt( max(zonx**2 + zony**2 + zonz**2,1.e-7) ) ! allow for poles
               costh= (zonx*ax(iq)+zony*ay(iq)+zonz*az(iq))/den
               sinth=-(zonx*bx(iq)+zony*by(iq)+zonz*bz(iq))/den
!              set the temperature to the equilibrium zonal mean
               t(iq,k) = max ( 200.,
     &               (315. - delty*sin(rlatt(iq))**2 -
     &                deltheta*log(sig(k))*cos(rlatt(iq))**2)
     &                *sig(k)**rkappa )
!          set zonal wind to an approximate equilibrium
c          uin = 3.5 * 125. * sin(rlatt(iq))**2 *
c    &          sig(k)*(1.-sig(k))/(1. + 10.*(sig(k)-0.25)**2 )
c          u(iq,k)=( costh*uin+sinth*vin)*abs(cos(rlatt(iq)))
c          v(iq,k)=(-sinth*uin+costh*vin)*abs(cos(rlatt(iq)))
               uin = 125. * sin(2.*rlatt(iq))**2 *
     &            sig(k)*(1.-sig(k))/(1. + 10.*(sig(k)-0.25)**2 )
               u(iq,k)= costh*uin+sinth*vin
               v(iq,k)=-sinth*uin+costh*vin
               if(iq.eq.idjd.and.k.eq.nlv.and.mydiag)then
                  print *,'indata setting u,v for h-s'
                  print *,'iq,k,ax,ay,az',iq,k,ax(iq),ay(iq),az(iq)
                  print *,'costh,sinth,x,y,z',
     &                     costh,sinth,x(iq),y(iq),z(iq)
                  print *,'uin,vin,u,v',uin,vin,u(iq,k),v(iq,k)
               endif
               qg(iq,k) = 0.
               ps(iq) = 1.e5
               psl(iq) = .01
               zs(iq) = 0.
            enddo               ! iq loop
!!       just to get something started set the meridional wind to a small
!!       value on the first face
!        do j=1,il
!           do i=1,il
!              iq=ind(i,j,0)
!              v(iq,k) = 0.1
!           end do
!        end do
         enddo
      endif  ! held-suarez test case

      if(io_in.eq.11)then
c       advection test, once around globe per 10 days
c       only non-rotated set up so far
         vmer=0.
c       assign u and v from zonal and meridional winds
         do iq=1,ifull
            den=sqrt( max(x(iq)**2 + y(iq)**2,1.e-7) ) ! allow for poles
            costh=(-y(iq)*ax(iq) + x(iq)*ay(iq))/den
            sinth=az(iq)/den
            uzon=2.*pi*rearth/(10.*86400) * abs(cos(rlatt(iq)))
            psl(iq)=.01
            ps(iq)=1.e5*exp(psl(iq))
            f(iq)=0.
            fu(iq)=0.
            fv(iq)=0.
            do k=1,kl
c             calculate u and v relative to the cc grid,
c             using components of gaussian grid u and v with theta
               u(iq,k)= costh*uzon+sinth*vmer
               v(iq,k)=-sinth*uzon+costh*vmer
               t(iq,k)=tbarr(k)
               qg(iq,k)=1.e-6
               if(rlongg(iq).gt.0.and.rlongg(iq).lt.10.*pi/180.)
     &               qg(iq,k)=10.e-3
            enddo  ! k loop
         enddo      ! iq loop
      endif  ! io_in.eq.11

      if ( myid == 0 ) print *,'ps test ',(ps(ii),ii=1,il)

c     section for setting up davies, defining ps from psl
      if(nbd.ne.0.and.nud_hrs.ne.0)then
         call davset   ! as entry in subr. davies, sets psls,qgg,tt,uu,vv
!        Not implemented properly yet.
!!!        do iq=1,ifull
!!!         davt(iq)=0.
!!!        enddo  ! iq loop
!!!        if(nbd.gt.0)then
!!!          do iq=1,ifull
!!!           davt(iq)=1./abs(nud_hrs)  !  e.g. 1/48
!!!          enddo  ! iq loop
!!!        endif  !  (nbd.gt.0)
!!!        if(nbd.eq.-1)then   ! linearly increasing nudging, just on panel 4
!!!	   centi=.5*(il+1)
!!!          do j=1,il  
!!!           do i=1,il
!!!	     dist=max(abs(i-centi),abs(j-centi)) ! dist from centre of panel
!!!	     distx=dist/(.5*il)  ! between 0. and 1.
!!!            davt(ind(j,i,4))=(1.-distx)/abs(nud_hrs)  !  e.g. 1/24
!!!           enddo  ! i loop
!!!          enddo   ! j loop
!!!        endif  !  (nbd.eq.-1) 
!!!        if(nbd.eq.-2)then   ! quadr. increasing nudging, just on panel 4
!!!	   centi=.5*(il+1)
!!!          do j=1,il  
!!!           do i=1,il
!!!	     dist=max(abs(i-centi),abs(j-centi)) ! dist from centre of panel
!!!	     distx=dist/(.5*il)  ! between 0. and 1.
!!!            davt(ind(j,i,4))=(1.-distx**2)/abs(nud_hrs)  !  e.g. 1/24
!!!           enddo  ! i loop
!!!          enddo   ! j loop
!!!        endif  !  (nbd.eq.-2) 
!!!        if(nbd.eq.-3)then   ! special form with no nudging on panel 1
!!!          do npan=0,5
!!!           do j=il/2+1,il
!!!!           linearly between 0 (at il/2) and 1/48 (at il+1)
!!!            rhs=(j-il/2)/((il/2+1.)*abs(nud_hrs))
!!!            do i=1,il
!!!             if(npan.eq.0)davt(ind(i,il+1-j,npan))=rhs
!!!             if(npan.eq.2)davt(ind(j,i,npan))=rhs
!!!             if(npan.eq.3)davt(ind(j,i,npan))=rhs
!!!             if(npan.eq.5)davt(ind(i,il+1-j,npan))=rhs
!!!            enddo  ! i loop
!!!           enddo   ! j loop
!!!          enddo    ! npan loop
!!!          do j=1,il  ! full nudging on furthest panel
!!!           do i=1,il
!!!            davt(ind(j,i,4))=1./abs(nud_hrs)  !  e.g. 1/48
!!!           enddo  ! i loop
!!!          enddo   ! j loop
!!!        endif  !  (nbd.eq.-3) 
c        do jj=1,jl,il/4
c	  j=jj
c         print 97,j,davt(1,j),davt(2,j),davt(3,j),davt(il/2,j),
c     &              davt(il-2,j),davt(il-1,j),davt(il,j)
c	  j=jj+1
c         print 97,j,davt(1,j),davt(2,j),davt(3,j),davt(il/2,j),
c     &              davt(il-2,j),davt(il-1,j),davt(il,j)
c	  j=jj+2
c         print 97,j,davt(1,j),davt(2,j),davt(3,j),davt(il/2,j),
c     &              davt(il-2,j),davt(il-1,j),davt(il,j)
c97       format('j,davt',i3,7f9.5)
c        enddo
      endif  ! (nbd.ne.0.and.nud_hrs.ne.0)

      if(io_in.ge.4)then   ! i.e. for special test runs without infile
c       set default tgg etc to level 2 temperatures, if not read in above
        do iq=1,ifull
         tgg(iq,ms) =t(iq,2)   ! just for io_in.ge.4
         tgg(iq,2) =t(iq,2)    ! just for io_in.ge.4
c        land(iq) =.true.
         tss(iq)=t(iq,2)
         if(zs(iq).eq. 0.)then
           land(iq) =.false.
           tss(iq)=tsea
         endif
        enddo   ! iq loop
      endif

c     for the moment assume precip read in at end of 24 h period
      do iq=1,ifull
       tss(iq)=abs(tss(iq))
       zolnd(iq)=zoland       ! just a default - uaully read in
!      initialize following to allow for leads with sice
       eg(iq)=0.
       fg(iq)=0.
       cduv(iq)=0.
      enddo   ! iq loop
      if ( myid == 0 ) print *,'zoland: ',zoland

      if(nqg_set.lt.7)then  ! initialize sicedep from tss (i.e. not read in)
!       n.b. this stuff & other nqg_set to be removed when always netcdf input
         if (myid==0) print *,
     &        'preset sice to .5 via tss, because nqg_set: ',nqg_set
        do iq=1,ifull
         if(tss(iq).le.271.2)then
           sicedep(iq)=2.  ! changed from .5 on 26/3/03
         else
           sicedep(iq)=0.     
         endif
        enddo   ! iq loop
      endif ! (nqg_set.lt.7)

      do iq=1,ifull
       sice(iq)=.false.
       if(land(iq))then   
         sicedep(iq)=0. 
	  fracice(iq)=0.          
       elseif(sicedep(iq).gt.0.)then             
         sice(iq)=.true.
	  fracice(iq)=1.  ! present default without leads
         snowd(iq)=0.    ! no snow presently allowed on sea-ice
       endif
      enddo   ! iq loop

c     read data for biospheric scheme if required
      if(nsib.ge.1)then
        call insoil   !  bundled in with sscam2
        call rdnsib   !  for usual defn of isoil, iveg etc
      else
        do iq=1,ifull
	  ivegt(iq)=1   ! default for h_s etc
	  isoilm(iq)=1  ! default for h_s etc
	 enddo
      endif      ! (nsib.ge.1)

!     nrungcm<0 controls presets for snowd, wb, tgg and other soil variables
!     they can be: preset/read_in_from_previous_run
!                  written_out/not_written_out    after 24 h    as follows:
!          nrungcm = -1     preset        | not written to separate file
!                    -2     preset        |     written  & qg
!                    -3     read_in       |     written  (usually preferred)
!                    -4     read_in       | not written
!                    -5     read_in & qg  |     written  & qg
      if(nrungcm.eq.-1.or.nrungcm.eq.-2)then
!       when no soil moisture available initially
!       new code follows; july 2001 jlm
        iyr=kdate/10000
        imo=(kdate-10000*iyr)/100
        do iq=1,ifull
         if(land(iq))then
           iveg=ivegt(iq)
           isoil=isoilm(iq)
!          fracsum(imo) is .5 for nh summer value, -.5 for nh winter value
	    fracs=sign(1.,rlatt(iq))*fracsum(imo)  ! +ve for local summer
	    fracwet=(.5+fracs)*fracwets(iveg)+(.5-fracs)*fracwetw(iveg)
           wb(iq,ms)= (1.-fracwet)*swilt(isoilm(iq))+ 
     &                  fracwet*sfc(isoilm(iq)) 
c          wb(iq,ms)= .5*swilt(isoilm(iq))+ .5*sfc(isoilm(iq)) ! till july 01
           if(abs(rlatt(iq)*180./pi).lt.18.)wb(iq,ms)=sfc(isoilm(iq)) ! tropics
           if(rlatt(iq)*180./pi.gt.-32..and.
     &        rlatt(iq)*180./pi.lt.-22..and.
     &        rlongg(iq)*180./pi.gt.117..and.rlongg(iq)*180./pi.lt.146.)
     &        wb(iq,ms)=swilt(isoilm(iq)) ! dry interior of australia
         endif    !  (land(iq))
         do k=1,ms-1
          wb(iq,k)=wb(iq,ms)
         enddo    !  k loop
        enddo     ! iq loop
        if ( mydiag ) then
           iveg=ivegt(idjd)
           isoil=isoilm(idjd)
           print *,'isoil,iveg,month,fracsum,rlatt: ',
     &           isoil,iveg,imo,fracsum(imo),rlatt(idjd)
           fracs=sign(1.,rlatt(idjd))*fracsum(imo) ! +ve for local summer
           fracwet=(.5+fracs)*fracwets(iveg)+(.5-fracs)*fracwetw(iveg)
           print *,'fracs,fracwet,initial_wb: ',
     &              fracs,fracwet,wb(idjd,ms)
        end if
      endif       !  ((nrungcm.eq.-1.or.nrungcm.eq.-2)

      if(nrungcm.le.-3)then
         print*, "NRUNGCM <= -3 not implemented in MPI version yet"
         stop
!       for sequence of runs starting with values saved from last run
        if(ktime.eq.1200)then
          co2in=co2_12      ! 'co2.12'
          radonin=radon_12  ! 'radon.12'
          surfin=surf_12    ! 'surf.12'
          qgfile='qg_12'
        else
          co2in=co2_00      !  'co2.00'
          radonin=radon_00  ! 'radon.00'
          surfin=surf_00    ! 'surf.00'
          qgfile='qg_00'
        endif
        print *,
     &    'reading previously saved wb,tgg,tss (land),snowd,sice from ',
     &         surfin
        open(unit=77,file=surfin,form='formatted',status='old')
        read(77,'(a80)') header
        print *,'header: ',header
        read(77,*) wb
        read(77,*) tgg
        read(77,*) aa           ! only use land values of tss
        read(77,*) snowd
        read(77,*) sicedep
        close(77)
        if(ico2.ne.0)then
          print *,'reading previously saved co2 from ',co2in
          open(unit=77,file=co2in,form='formatted',status='old')
          read(77,'(a80)') header
          print *,'header: ',header
          read(77,'(12f7.2)') ((tr(iq,k,ico2),iq=1,ilt*jlt),k=1,klt)
          rmin=0.
          rmax=0.
	   do k=1,klt
	    do iq=1,ilt*jlt
            rmin=min(rmin,tr(iq,k,ico2))
            rmax=max(rmax,tr(iq,k,ico2))
           enddo
          enddo
          print *,'min,max for co2 ',rmin,rmax
          close(77)
        endif
        if(iradon.ne.0)then
          print *,'reading previously saved radon from ',radonin
          open(unit=77,file=radonin,form='formatted',status='old')
          read(77,'(a80)') header
          print *,'header: ',header
          read(77,*) ((tr(iq,k,iradon),iq=1,ilt*jlt),k=1,klt)
          rmin=0.
          rmax=0.
	   do k=1,klt
	    do iq=1,ilt*jlt
            rmin=min(rmin,tr(iq,k,iradon))
            rmax=max(rmax,tr(iq,k,iradon))
           enddo
          enddo
          print *,'min,max for radon ',rmin,rmax
          close(77)
        endif
        do iq=1,ifull
         sice(iq)=.false.
         if(sicedep(iq).gt.0.)sice(iq)=.true.
         if(land(iq))tss(iq)=aa(iq)
        enddo   ! iq loop
	 if(nrungcm.eq.-5)then
	   print *,'reading special qgfile file: ',qgfile
          open(unit=77,file=qgfile,form='unformatted',status='old')
          read(77) qg
          close(77)
	 endif   ! (nrungcm.eq.-5)
      endif    !  (nrungcm.le.-3)

      if(nrungcm.ne.0)then  ! not for restart 
        do iq=1,ifull   ! often do this:
         tgg(iq,1) = tss(iq)
        enddo
        do k=1,3
         do iq=1,ifull
          tggsn(iq,k)=280.   ! just a default
         enddo   ! iq loop
        enddo    ! k loop
      endif   !  (nrungcm.ne.0)

      if(nrungcm.eq.4)then !  wb fix for ncep input 
!       this is related to eak's temporary fix for soil moisture
!       - to compensate for ncep drying out, increase minimum value
        do k=1,ms
         do iq=1,ifull     
           isoil=isoilm(iq)
           wb(iq,k)=min( sfc(isoil) ,
     &              max(.75*swilt(isoil)+.25*sfc(isoil),wb(iq,k)) )  
         enddo   ! iq loop
        enddo    !  k loop
      endif      !  (nrungcm.eq.4)

      if(nrungcm.eq.5)then !  tgg, wb fix for mark 3 input
!       unfortunately mk 3 only writes out 2 levels
!       wb just saved as excess above wilting; top level & integrated values
!       tgg saved for levels 2 and ms 
        do iq=1,ifull     
         isoil=isoilm(iq)
          do k=2,3
           wb(iq,k)=wb(iq,ms)
          enddo    !  k loop
          do k=1,ms
!          wb(iq,k)=min( sfc(isoil) ,wb(iq,k)+swilt(isoil) ) ! till 22/8/02
           wb(iq,k)=wb(iq,k)+swilt(isoil) 
          enddo    !  k loop
          tgg(iq,3)=.75*tgg(iq,2)+.25*tgg(iq,6)
          tgg(iq,4)= .5*tgg(iq,2)+ .5*tgg(iq,6)
          tgg(iq,5)=.25*tgg(iq,2)+.75*tgg(iq,6)
         enddo   ! iq loop
         if (mydiag) then
            print *,'after nrungcm=5 fixup of mk3 soil variables:'
            print *,'tgg ',(tgg(idjd,k),k=1,ms)
            print *,'wb ',(wb(idjd,k),k=1,ms)
         end if
      endif      !  (nrungcm.eq.5)

      if(nrungcm.eq.11)then   ! this is old nrungcm=-1 option
        do iq=1,ifull
         if(land(iq))then
           wb(iq,ms)=.5*(swilt(isoilm(iq))+sfc(isoilm(iq)))  
           if(abs(rlatt(iq)*180./pi).lt.18.)wb(iq,ms)=sfc(isoilm(iq)) ! tropics
           if(rlatt(iq)*180./pi.gt.-32..and.
     &        rlatt(iq)*180./pi.lt.-22..and.
     &        rlongg(iq)*180./pi.gt.117..and.rlongg(iq)*180./pi.lt.146.)
     &        wb(iq,ms)=swilt(isoilm(iq)) ! dry interior of australia
         endif    !  (land(iq))
         do k=1,ms-1
          wb(iq,k)=wb(iq,ms)
         enddo    !  k loop
        enddo     ! iq loop
      endif       !  ((nrungcm.eq.11)

      do iq=1,ifull
       if(.not.land(iq))then
         do k=1,ms
          wb(iq,k)=0.   ! default over ocean (for plotting)
         enddo    !  k loop
       endif    !  (.not.land(iq))
      enddo     ! iq loop

      if(newsnow.eq.1)then  ! don't do this for restarts
!       snowd is read & used in cm (i.e. as mm of water)
        call readreal(snowfile,snowd,ifull)
        if (mydiag) write(6,"('snowd# in',9f7.2)") diagvals(snowd)
!     &       ((snowd(ii+(jj-1)*il),ii=id-1,id+1),jj=jd-1,jd+1)
      elseif(nrungcm.ne.0)then     ! 21/12/01
        do iq=1,ifull
c        fix for antarctic snow
         if(land(iq).and.rlatt(iq)*180./pi.lt.-60.)snowd(iq)=
     &          max(snowd(iq),400.)
        enddo   ! iq loop
      endif    !  (newsnow.eq.1) .. else ..
!     check that snowd, as read in, is only over land or sice
      do iq=1,ifull
       if(.not.land(iq).and..not.sice(iq))snowd(iq)=0.
      enddo   ! iq loop

      if(newsoilm.gt.0)then
        print *,'newsoilm = ',newsoilm
        stop 'code not ready for read of w & w2'
        ! Note that this double read can't work with the MPI version.
        call readreal('smoist.dat',w,2*ifull) ! special read of w & w2
      endif

      if(nhstest.lt.0)then  ! aquaplanet test
        kdate=19790321
        do iq=1,ifull
         zs(iq)=0.
         land(iq)=.false.
         sice(iq)=.false.
         sicedep(iq)=0.
         snowd(iq)=0.
         if(abs(rlatt(iq)).lt.pi/3.)then
           tss(iq)=273.16 +27.*(1.-sin(rlatt(iq)*90./60.)**2)
         else
           tss(iq)=273.16
         endif
        enddo   ! iq loop
	 do k=1,ms
	  tgg(:,k)=tss(:)
	  wb(:,k)=0.
	 enddo
        if(nhstest.gt.-22)then  ! pgb test, e.g. nhtest=-1 or -2
	   ix=il/2
	   jx=1.19*il
           ix=id
	   jx=jd
	   do j=jx+nhstest,jx-nhstest
           do i=ix+nhstest,ix-nhstest
            iq=i+(j-1)*il
            zs(iq)=.1	   
            land(iq)=.true.
            isoilm(iq)=4   ! sandy-loam/loam
            ivegt(iq)=14
            sigmf(iq)=0.   ! bare soil
	     print *,'i,j,land,zs ',i,j,land(iq),zs(iq)
     	    enddo
	   enddo
	   ixjx=ix+(jx-1)*il
	   print *,'ix,jx,long,lat ',
     &             ix,jx,rlongg(ixjx)*180./pi,rlatt(ixjx)*180./pi
        endif  ! (nhstest.gt.-22)
      endif    ! (nhstest.lt.0)

c     zmin here is approx height of the lowest level in the model
      zmin=-rdry*280.*log(sig(1))/grav
      if (myid==0) print *,'zmin = ',zmin
      gwdfac=.01*lgwd   ! most runs used .02 up to fri  10-10-1997
      helim=800.       ! hal used 800.
      hefact=.1*abs(ngwd)   ! hal used hefact=1. (equiv to ngwd=10)
      if (myid==0) print *,'hefact,helim,gwdfac: ',hefact,helim,gwdfac
      if(lgwd.gt.0)then
        aamax=0.
        do iq=1,ifull
         aa(iq)=0.  ! for sea
         if(land(iq))then
           if(he(iq).eq.0.)print *,'zero he over land for iq = ',iq
           aa(iq)=min(gwdfac*max(he(iq),.01),.8*zmin)   ! already in meters
           aamax=max(aamax,aa(iq))
!          replace he by square of corresponding af value
           helo(iq)=( .4/log(zmin/aa(iq)) )**2
         endif
        enddo   ! iq loop
        if (mydiag) print *,'for lgwd>0, typical zo#: ', diagvals(aa)
!     & 	 ((aa(ii+(jj-1)*il),ii=id-1,id+1),jj=jd-1,jd+1)
        call mpi_reduce(aamax, aamax_g, 1, MPI_REAL, MPI_MAX, 0,
     &                  MPI_COMM_WORLD, ierr )
        if (myid==0) print *,'for lgwd>0, aamax: ',aamax_g
      endif

      if(ngwd.ne.0)then
        hemax=0.
        do iq=1,ifull
         hemax=max(he(iq),hemax)
c****    limit launching height : Palmer et al use limit on variance of
c****    (400 m)**2. we use launching height = std dev. we limit
c****    launching height to  2*400=800 m. this may be a bit severe.
c****    according to Palmer this prevents 2-grid noise at steep edge of
c****    himalayas etc.
         he(iq)=min(hefact*he(iq),helim)
        enddo
        if (myid==0) print *,'hemax = ',hemax
        call mpi_allreduce(hemax, hemax_g, 1, MPI_REAL, MPI_MAX, 
     &                  MPI_COMM_WORLD, ierr )
        hemax = hemax_g
        if(hemax.eq.0.)then
c         use he of 30% of orography, i.e. zs*.3/grav
          do iq=1,ifull
           he(iq)=min(hefact*zs(iq)*.3/grav , helim)
           hemax=max(he(iq),hemax)
          enddo ! iq loop
        endif   ! (hemax.eq.0.)
        call mpi_reduce(hemax, hemax_g, 1, MPI_REAL, MPI_MAX, 0,
     &                  MPI_COMM_WORLD, ierr )
        if (myid==0) print *,'final hemax = ',hemax_g
      endif     ! (ngwd.ne.0)

      if(namip.gt.0)then
        if(myid==0)print *,'calling amipsst at beginning of run'
        call amipsst
      endif   ! namip.gt.0

      snalb=.8
      do iq=1,ifull
       zolog(iq)=log(zmin/zolnd(iq))   ! for land use in sflux
       if(.not.land(iq))then
!        from June '03 tgg1	holds actual sea temp, tss holds net temp 
         tgg(iq,1)=max(271.3,tss(iq)) 
         tgg(iq,3)=tss(iq)         ! a default 
       endif   ! (.not.land(iq))
       if(sice(iq))then
!        at beginning of month set sice temperatures
         tgg(iq,3)=min(271.2,tss(iq),t(iq,1)+.04*6.5) ! for 40 m level 1
         tss(iq)=tgg(iq,3)*fracice(iq)+tgg(iq,1)*(1.-fracice(iq))
         alb(iq)=.65*fracice(iq)+.1*(1.-fracice(iq))
       endif   ! (sice(iq)) 
       if(isoilm(iq).eq.9)then
!        also at beginning of month ensure cold deep temps over permanent ice
         do k=2,ms
          tgg(iq,k)=min(tgg(iq,k),260.)
         enddo
       endif   ! (isoilm(iq).eq.9)
      enddo    ! iq loop

!     tgg(:,:)=max(190.,tgg(:,:))  ! temporary post-glacier-error fix
      if ( mydiag ) then
         print *,'near end of indata id+-1, jd+-1'
         write(6,"('tss#    ',3f7.2,1x,3f7.2,1x,3f7.2)") 
     &       diagvals(tss)
!     &       ((tss(ii+(jj-1)*il),ii=id-1,id+1),jj=jd-1,jd+1)
         write(6,"('tgg(1)# ',3f7.2,1x,3f7.2,1x,3f7.2)") 
     &       diagvals(tgg(:,1))
!     &       ((tgg(ii+(jj-1)*il,1),ii=id-1,id+1),jj=jd-1,jd+1)
         write(6,"('tgg(2)# ',3f7.2,1x,3f7.2,1x,3f7.2)") 
     &       diagvals(tgg(:,2))
!     &       ((tgg(ii+(jj-1)*il,2),ii=id-1,id+1),jj=jd-1,jd+1)
         write(6,"('tgg(3)# ',3f7.2,1x,3f7.2,1x,3f7.2)") 
     &       diagvals(tgg(:,3))
!     &       ((tgg(ii+(jj-1)*il,3),ii=id-1,id+1),jj=jd-1,jd+1)
         write(6,"('tgg(ms)#',3f7.2,1x,3f7.2,1x,3f7.2)") 
     &       diagvals(tgg(:,ms))
!     &       ((tgg(ii+(jj-1)*il,ms),ii=id-1,id+1),jj=jd-1,jd+1)
         write(6,"('land#   ',3l7,1x,3l7,1x,3l7)") 
     &       diagvals(land)
!     &       ((land(ii+(jj-1)*il),ii=id-1,id+1),jj=jd-1,jd+1)
         write(6,"('sice#   ',3l7,1x,3l7,1x,3l7)") 
     &       diagvals(sice)
!     &       ((sice(ii+(jj-1)*il),ii=id-1,id+1),jj=jd-1,jd+1)
         write(6,"('zo#     ',3f7.2,1x,3f7.2,1x,3f7.2)") 
     &       diagvals(zolnd)
!     &       ((zolnd(ii+(jj-1)*il),ii=id-1,id+1),jj=jd-1,jd+1)
         write(6,"('wb(1)#  ',3f7.3,1x,3f7.3,1x,3f7.3)") 
     &       diagvals(wb(:,1))
!     &       ((wb(ii+(jj-1)*il,1),ii=id-1,id+1),jj=jd-1,jd+1)
         write(6,"('wb(ms)# ',3f7.3,1x,3f7.3,1x,3f7.3)") 
     &       diagvals(wb(:,ms))
!     &       ((wb(ii+(jj-1)*il,ms),ii=id-1,id+1),jj=jd-1,jd+1)
         write(6,"('swilt#  ',3f7.3,1x,3f7.3,1x,3f7.3)")
     &       swilt(diagvals(isoilm))
!     &    ((swilt(isoilm(ii+(jj-1)*il)),ii=id-1,id+1),jj=jd-1,jd+1)
         write(6,"('wb3frac#',3f7.3,1x,3f7.3,1x,3f7.3)")
     &       (diagvals(wb(:,3)) - swilt(diagvals(isoilm))) /
     &       (sfc(diagvals(isoilm)) - swilt(diagvals(isoilm)))
!     &    (( (wb(ii+(jj-1)*il,3)-swilt(isoilm(ii+(jj-1)*il)))/
!     &    (sfc(isoilm(ii+(jj-1)*il))-swilt(isoilm(ii+(jj-1)*il))),
!     &            ii=id-1,id+1),jj=jd-1,jd+1)
         write(6,"('snowd#  ',3f7.2,1x,3f7.2,1x,3f7.2)") 
     &       diagvals(snowd)
!     &       ((snowd(ii+(jj-1)*il),ii=id-1,id+1),jj=jd-1,jd+1)
         write(6,"('fracice#',3f7.3,1x,3f7.3,1x,3f7.3)") 
     &       diagvals(fracice)
!     &       ((fracice(ii+(jj-1)*il),ii=id-1,id+1),jj=jd-1,jd+1)
      end if

      i1=1
      j1=1
      if(npanels.eq.0)i1=2    ! for darlam
      if(npanels.eq.0)j1=2    ! for darlam
      indexl=0
      if ( mydiag ) then
         print *,'idjd = ',idjd
         print *,'before land loop; land,sice,sicedep,isoil,ivegt,tss ',
     &           land(idjd),sice(idjd),sicedep(idjd),
     &           isoilm(idjd),ivegt(idjd),tss(idjd)
      end if
      do j=j1,jl
       do i=i1,il
        iq=i+(j-1)*il
        if(land(iq))then                                                ! land
          indexl=indexl+1
          iperm(indexl)=iq
        endif ! (land(iq))
       enddo  ! i loop
      enddo   ! j loop
      ipland=indexl
      indexi=ipland
      ipsea=(il+1-i1)*(jl+1-j1)
      indexs=ipsea+1
      if (mydiag) print *,'before sice loop; land,sice,sicedep,tss ',
     &           land(idjd),sice(idjd),sicedep(idjd),tss(idjd)
      do iq=1,ifull
        if(sice(iq))then
          indexi=indexi+1     ! sice point
          iperm(indexi)=iq    ! sice point
        elseif(.not.land(iq))then
          indexs=indexs-1     ! sea point
          iperm(indexs)=iq    ! sea point
        endif  ! (sice(iq))
      enddo   ! iq loop
      ipsice=indexi
      if (mydiag) print *,'ipland,ipsice,ipsea: ',ipland,ipsice,ipsea
      if(ipsea.ne.ifull.and.npanels.gt.0)
     &                                  stop 'whats going on in indata?'

      if(nrungcm.eq.1)then  ! jlm alternative wb fix for nsib runs off early mark 2 gcm
         if (mydiag ) then
            isoil = isoilm(idjd)
            write(6,"('before nrungcm=1 fix-up wb(1-ms)',9f7.3)") 
     &                   (wb(idjd,k),k=1,ms)
            print *,'nfixwb,isoil,swilt,sfc,ssat,alb ',
     &        nfixwb,isoil,swilt(isoil),sfc(isoil),ssat(isoil),alb(idjd)
         end if
        do ip=1,ipland  ! all land points in this nsib=1+ loop
         iq=iperm(ip)
         isoil = isoilm(iq)

         if(nfixwb.eq.0)then
!          very dry jlm suggestion. assume vegfrac ~.5, so try to satisfy
!          wb0/.36=.5*(wb/sfc + (wb-swilt)/(sfc-swilt) )
           wb(iq,1)=                                                     
     &        ( sfc(isoil)*(sfc(isoil)-swilt(isoil))*wb(iq,1)/.36  
     &      +.5*sfc(isoil)*swilt(isoil) )/(sfc(isoil)-.5*swilt(isoil)) 
           do k=2,ms                                                       
            wb(iq,k)=                                                      
     &        ( sfc(isoil)*(sfc(isoil)-swilt(isoil))*wb(iq,ms)/.36  
     &      +.5*sfc(isoil)*swilt(isoil) )/(sfc(isoil)-.5*swilt(isoil)) 
           enddo   !  k=2,ms
	  endif   ! (nfixwb.eq.0)
         if(nfixwb.eq.1.or.nfixwb.eq.2)then
!          alternative simpler jlm fix-up	
!          wb0/.36=(wb-swilt)/(sfc-swilt)
           wb(iq,1)=swilt(isoil)+
     &             (sfc(isoil)-swilt(isoil))*wb(iq,1)/.36
           do k=2,ms                                                       
            wb(iq,k)=swilt(isoil)+
     &              (sfc(isoil)-swilt(isoil))*wb(iq,ms)/.36
           enddo   !  k=2,ms
	  endif   ! (nfixwb.eq.1.or.nfixwb.eq.2)
         if(ip.eq.1)print *,'kdate ',kdate
         if(nfixwb.eq.2.and.kdate.gt.3210100.and.kdate.lt.3210200)then
	    rlon_d=rlongg(iq)*180./pi
	    rlat_d=rlatt(iq)*180./pi
           if(ip.eq.1)then
	      print *,'kdate in nfixwb=2 ',kdate
	      print *,'iq,rlon_d,rlat_d ',rlon_d,rlat_d
            endif
!          jlm fix-up for tropical oz in january 321
           if(rlon_d.gt.130..and.rlon_d.lt.150..and.
     &        rlat_d.gt.-20..and.rlat_d.lt.0.)then
             do k=1,ms                                                       
              wb(iq,k)=max(wb(iq,k),.5*(swilt(isoil)+sfc(isoil))) ! tropics
             enddo   !  k=1,ms
	    endif
!          jlm fix-up for dry interior in january 321
           if(rlon_d.gt.117..and.rlon_d.lt.142..and.
     &        rlat_d.gt.-32..and.rlat_d.lt.-22.)then
             do k=1,ms                                                       
              wb(iq,k)=swilt(isoil)  ! dry interior
             enddo   !  k=1,ms
	    endif
	  endif   ! (nfixwb.eq.2)
         if(nfixwb.eq.10)then    ! was default for nrungcm=1 till oct 2001
!          jlm suggestion, assume vegfrac ~.5, so try to satisfy
!          wb0/.36=.5*(wb/ssat + (wb-swilt)/(ssat-swilt) )
           wb(iq,1)=                                                     
     &        ( ssat(isoil)*(ssat(isoil)-swilt(isoil))*wb(iq,1)/.36  
     &      +.5*ssat(isoil)*swilt(isoil) )/(ssat(isoil)-.5*swilt(isoil)) 
           do k=2,ms                                                       
            wb(iq,k)=                                                      
     &        ( ssat(isoil)*(ssat(isoil)-swilt(isoil))*wb(iq,ms)/.36  
     &      +.5*ssat(isoil)*swilt(isoil) )/(ssat(isoil)-.5*swilt(isoil)) 
           enddo   !  k=2,ms
	  endif   ! (nfixwb.ne.10)

         do k=1,ms
          wb(iq,k)=max( swilt(isoil) , min(wb(iq,k),sfc(isoil)) )
!         safest to redefine wbice preset here
!         following linearly from 0 to .99 for tgg=tfrz down to tfrz-5
          wbice(iq,k)=
     &            min(.99,max(0.,.99*(273.1-tgg(iq,k))/5.))*wb(iq,k) ! jlm
         enddo     !  k=1,ms
        enddo        !  ip=1,ipland
        if (mydiag) then
           write(6,"('after nrungcm=1 fix-up wb(1-ms)',9f7.3)") 
     &                   (wb(idjd,k),k=1,ms)
           write(6,"('wbice(1-ms)',9f7.3)")(wbice(idjd,k),k=1,ms)
           write(6,"('wb3frac#',9f7.2)")
     &       (diagvals(wb(:,3)) - swilt(diagvals(isoilm))) /
     &       (sfc(diagvals(isoilm)) - swilt(diagvals(isoilm)))
!     &    (( (wb(ii+(jj-1)*il,3)-swilt(isoilm(ii+(jj-1)*il)))/
!     &   (sfc(isoilm(ii+(jj-1)*il))-swilt(isoilm(ii+(jj-1)*il))),
!     &            ii=id-1,id+1),jj=jd-1,jd+1)
        end if
      endif          !  (nrungcm.eq.1)

      if(nrungcm.eq.2)then  ! for nsib runs off early mark 2 gcm
         if (mydiag) then
            isoil = isoilm(idjd)
            print *,'before nrungcm=2 fix-up wb(1-ms): ',wb(idjd,:)
            print *,'isoil,swilt,ssat,alb ',
     &           isoil,swilt(isoil),ssat(isoil),alb(idjd)
         end if
        do ip=1,ipland  ! all land points in this nsib=1+ loop
         iq=iperm(ip)
         isoil = isoilm(iq)
         if( alb(iq) .ge. 0.25 ) then
           diffg=max(0. , wb(iq,1)-0.068)*ssat(isoil)/0.395   ! for sib3
           diffb=max(0. , wb(iq,ms)-0.068)*ssat(isoil)/0.395   ! for sib3
         else
           diffg=max(0. , wb(iq,1)-0.175)*ssat(isoil)/0.42    ! for sib3
           diffb=max(0. , wb(iq,ms)-0.175)*ssat(isoil)/0.42    ! for sib3
         endif
         wb(iq,1)=swilt(isoil)+diffg          ! for sib3
         do k=2,ms                            ! for sib3
          wb(iq,k)=swilt(isoil)+diffb         ! for sib3
         enddo     !  k=2,ms
        enddo        !  ip=1,ipland
        if(mydiag) print*,'after nrungcm=2 fix-up wb(1-ms): ',wb(idjd,:)
      endif          !  (nrungcm.eq.2)

c     initialize snow variables for sib3 and sib4
      if(mydiag) print *,'in indata nqg_set = ',nqg_set 
      if(nqg_set.le.11) then
	do iq=1,ifull
	 smass(iq,1)=0.
	 smass(iq,2)=0.
	 smass(iq,3)=0.
	 if(snowd(iq).gt.100.)then
	   ssdn(iq,1)=240.
	 else
	   ssdn(iq,1) = 140.
	 endif		! (snowd(iq).gt.100.)
	 do k=2,3
	  ssdn(iq,k)=ssdn(iq,1)
        enddo
	 ssdnn(iq)  = ssdn(iq,1)
	 isflag(iq) = 0
	 snage(iq)  = 0.
	 if(snowd(iq).gt.0.)tgg(iq,1)=min(tgg(iq,1),270.1)
        enddo   ! iq loop
        if (mydiag) print *,'in indata set snowd,ssdn: ',
     &       snowd(idjd),ssdn(idjd,1)
        if(nqg_set.lt.11)then
          do iq=1,ifull
	   do k=1,ms
!           following linearly from 0 to .99 for tgg=tfrz down to tfrz-5
            wbice(iq,k)=
     &            min(.99,max(0.,.99*(tfrz-tgg(iq,k))/5.))*wb(iq,k) ! jlm
	   enddo ! ms
          enddo  ! iq loop
        endif    ! (nqg_set.lt.11)
      endif      ! (nqg_set.le.11)
      
      osnowd = snowd  ! 2d
!     general initial checks for wb and wbice
      do k=1,ms
       do iq=1,ifull
        isoil=isoilm(iq)
        wb(iq,k)=min(ssat(isoil),wb(iq,k))
        wbice(iq,k)=min(.99*wb(iq,k),wbice(iq,k)) 
       enddo  ! iq loop
      enddo   ! ms

!!     can try fix up of oz albedo   27/4/01
!      do iq=1,ifull
!           if(alb(iq).ge..25.and.rlatt(iq)*180./pi.gt.-35..and.
!     &        rlatt(iq)*180./pi.lt.-15..and.
!     &        rlongg(iq)*180./pi.gt.110..and.rlongg(iq)*180./pi.lt.146.)
!     &      alb(iq)=alb(iq)-.04  ! fix over central oz
!      enddo

      if ( mydiag ) then
         print *,'nearer end of indata id+-1, jd+-1'
         write(6,"('tgg(2)# ',9f7.2)")  diagvals(tgg(:,2))
!     &       ((tgg(ii+(jj-1)*il,2),ii=id-1,id+1),jj=jd-1,jd+1)
         write(6,"('tgg(ms)#',9f7.2)")  diagvals(tgg(:,ms))
!     &        ((tgg(ii+(jj-1)*il,ms),ii=id-1,id+1),jj=jd-1,jd+1)
      end if

      do ip=1,ipland  ! all land points in this nsib=1+ loop
       iq=iperm(ip)
       isoil = isoilm(iq)
       iveg  = ivegt(iq)
       if(jlmsigmf.eq.1)then  ! fix-up for dean's veg-fraction
         sigmf(iq)=((sfc(isoil)-wb(iq,3))*vegpmin(iveg)
     &               +(wb(iq,3)-swilt(isoil))*vegpmax(iveg))/
     &                      (sfc(isoil)-swilt(isoil)) 
         sigmf(iq)=max(vegpmin(iveg),min(sigmf(iq),.8)) ! in case wb odd
c        sigmf(iq)=max(.01,min(sigmf(iq),.8))           ! in case wb odd
       endif   ! (jlmsigmf.eq.1)
!      following done here just for rsmin diags for nstn and outcdf	
       tstom=298.
       if(iveg.eq.6+31)tstom=302.
       if(iveg.ge.10.and.iveg.le.21.and.
     &    abs(rlatt(iq)*180./pi).lt.25.)tstom=302.
       tsoil=min(tstom, .5*(.3333*tgg(iq,2)+.6667*tgg(iq,3)
     &            +.95*tgg(iq,4) + .05*tgg(iq,5)))
       ftsoil=max(0.,1.-.0016*(tstom-tsoil)**2)
c      which is same as:  ftsoil=max(0.,1.-.0016*(tstom-tsoil)**2)
c                         if( tsoil .ge. tstom ) ftsoil=1.
       rlai=  max(.1,rlaim44(iveg)-slveg44(iveg)*(1.-ftsoil))
       rsmin(iq) = rsunc44(iveg)/rlai   
      enddo    !  ip=1,ipland
      
      if(jalbfix.eq.1)then  ! jlm fix-up for albedos, esp. over sandy bare soil
         if ( mydiag ) then
            isoil=isoilm(idjd)
            print *,'before jalbfix isoil,sand,alb,rsmin ',
     &                          isoil,sand(isoil),alb(idjd),rsmin(idjd)
         end if
         do ip=1,ipland  
            iq=iperm(ip)
            isoil = isoilm(iq)
            alb(iq)=max(alb(iq),sigmf(iq)*alb(iq)
     &        +(1.-sigmf(iq))*(sand(isoil)*.35+(1.-sand(isoil))*.06))
         enddo                  !  ip=1,ipland
         if ( mydiag ) then
            print *,'after jalbfix sigmf,alb ',sigmf(idjd),alb(idjd)
         end if
      endif  ! (jalbfix..eq.1)
      
!***  no fiddling with initial tss, snow, sice, w, w2, gases beyond this point
      call bounds(zs)
      do iq=1,ifull
	neigh(iq)=iq  ! default value
	zsmin=zs(iq)
	if(zs(ie(iq)).lt.zsmin)then
	  zsmin=zs(ie(iq))
	  neigh(iq)=ie(iq)
	endif
	if(zs(iw(iq)).lt.zsmin)then
	  zsmin=zs(iw(iq))
	  neigh(iq)=iw(iq)
	endif
	if(zs(in(iq)).lt.zsmin)then
	  zsmin=zs(in(iq))
	  neigh(iq)=in(iq)
	endif
	if(zs(is(iq)).lt.zsmin)then
	  neigh(iq)=is(iq)
	endif
      enddo
      if ( mydiag ) then
         print *,'for idjd get neigh = ',neigh(idjd),
     &                 idjd,ie(idjd),iw(idjd),in(idjd),is(idjd)
         print *,'with zs: ',zs(idjd),
     &       zs(ie(idjd)),zs(iw(idjd)),zs(in(idjd)),zs(is(idjd))
      end if

      if(epsp.ge.0.)then
        do iq=1,ifull
         epst(iq)=epsp
        enddo
      else
        do iq=1,ifull
         zsdiff=max(abs(zs(ie(iq))-zs(iq)),
     &              abs(zs(iw(iq))-zs(iq)),
     &              abs(zs(in(iq))-zs(iq)),
     &              abs(zs(is(iq))-zs(iq)) )
         if(zsdiff.gt.100.*grav)then           ! 100 m diff version
           epst(iq)=abs(epsp)
         else
           epst(iq)=0.
         endif
        enddo
      endif
      if(epsp.gt.1.)then  ! e.g. 20. to give epsmax=.2 for orog=600 m
        epsmax=epsp/100.
        do iq=1,ifull
         zsdiff=max(abs(zs(ie(iq))-zs(iq)),
     &              abs(zs(iw(iq))-zs(iq)),
     &              abs(zs(in(iq))-zs(iq)),
     &              abs(zs(is(iq))-zs(iq)) )
         epst(iq)=min(epsmax*zsdiff/(600.*grav),epsmax) ! sliding 0. to epsmax
        enddo
      endif
      if(epsp.gt.99.)then  ! e.g. 200. to give epsmax=.2 for orog=600 m
        epsmax=epsp/1000.
        do iq=1,ifull
         zsdiff=max(zs(iq)-zs(ie(iq)),
     &              zs(iq)-zs(iw(iq)),
     &              zs(iq)-zs(in(iq)),
     &              zs(iq)-zs(is(iq)),0. )
         epst(iq)=min(epsmax*zsdiff/(600.*grav),epsmax) ! sliding 0. to epsmax
        enddo
      endif

      print *,'at centre of the panels:'
      do n=1,npan
         iq = indp((ipan+1)/2,(jpan+1)/2,n)
         print '(" n,em,emu,emv,f,fu,fv "i3,3f6.3,3f10.6)',
     &        n-noff,em(iq),emu(iq),emv(iq),f(iq),fu(iq),fv(iq)
      enddo

!     What to do about this????

!!!      write(22,920)
!!! 920  format('                             land            isoilm')
!!!      write(22,921)
!!! 921  format('  iq     i   j rlong   rlat     sice  zs(m) alb  ivegt tss
!!!     &    t1    tgg2   tgg6     wb1  wb6    ico2  radon')
!!!      do j=1,jl
!!!       do i=1,il
!!!        iq=i+(j-1)*il
!!!        along(iq)=rlongg(iq)*180./pi    ! wed  10-28-1998
!!!        alat(iq)=rlatt(iq)*180./pi
!!!        write(22,922) iq,i,j,rlongg(iq)*180./pi,rlatt(iq)*180./pi,
!!!     &               land(iq),sice(iq),zs(iq)/grav,alb(iq),
!!!     &               isoilm(iq),ivegt(iq),
!!!     &               tss(iq),t(iq,1),tgg(iq,2),tgg(iq,ms),
!!!     &               wb(iq,1),wb(iq,ms),ico2em(iq),radonem(iq)
!!! 922    format(i6,2i4,2f8.3 ,2l2,f7.1,f5.2 ,2i3 ,4f7.1 ,2f6.2, i6,f5.2)
!!!       enddo
!!!      enddo

      if(nsib.ge.1)then   !  check here for soil & veg mismatches
         if (mydiag) print *,'idjd,land,isoil,ivegt ',
     &                   idjd,land(idjd),isoilm(idjd),ivegt(idjd)
        do iq=1,ifull
          if(land(iq))then
            if(ivegt(iq).eq.0)then
c	       if(rlatt(iq)*180./pi.gt.-50.)then
                print *,'stopping because nsib = 1 or 3 ',
     &          'and veg type not defined for iq = ',iq
                print *,'lat,long ',
     .		           rlatt(iq)*180./pi,rlongg(iq)*180./pi
                stop
            endif  ! (ivegt(iq).eq.0)
            if(isoilm(iq).eq.0)then
              print *,'stopping because nsib = 1',
     &        ' and soil type not defined for iq = ',iq
              stop
            endif  ! (isoilm(iq).eq.0)
          endif    ! (land(iq))
        enddo    !  iq loop
      endif      ! (nsib.ge.1)

      if(nstn.gt.0)then
         print*, "Stations not implemented in MPI version yet"
         stop
        print *,'land stations'
        print *,'lu istn jstn  iq   slon   slat land rlong  rlat',
     &   ' isoil iveg zs(m) alb  wb3  wet3 sigmf zo   rsm   he'
        do nn=1,nstn
         call latltoij(slon(nn),slat(nn),ri,rj,nface)
         istn(nn)=nint(ri)
         jstn(nn)=nint(rj) +nface*il
         iq=istn(nn)+(jstn(nn)-1)*il
	  if(.not.land(iq))then
!          simple search for neighbouring land point (not over panel bndries)
	    ii=nint(ri)
	    jj=nint(rj)
	    dist=100.
	    distnew=(nint(ri)+1-ri)**2 +(nint(rj)-rj)**2 
	    if(land(iq+1).and.distnew.lt.dist)then
	      ii=nint(ri)+1
	      dist=distnew
	    endif
	    distnew=(nint(ri)-1-ri)**2 +(nint(rj)-rj)**2 
	    if(land(iq-1).and.distnew.lt.dist)then
	      ii=nint(ri)-1
	      dist=distnew
	    endif
	    distnew=(nint(ri)-ri)**2 +(nint(rj)+1-rj)**2 
	    if(land(iq+il).and.distnew.lt.dist)then
	      jj=nint(rj)+1
	      dist=distnew
	    endif
	    distnew=(nint(ri)-ri)**2 +(nint(rj)-1-rj)**2 
	    if(land(iq-il).and.distnew.lt.dist)then
	      jj=nint(rj)-1
	      dist=distnew
	    endif
           istn(nn)=ii
           jstn(nn)=jj+nface*il
           iq=istn(nn)+(jstn(nn)-1)*il
	  endif  ! (.not.land(iq))
!        following removed on 30/1/02	  
c         if(schmidt.gt. .29.and.schmidt.lt. .31)then
c!          n.b. following should only be for stretched grid
c           if(nn.eq.2)alb(iq)=.16   ! fix-up for sydney     was   .13
c           if(nn.eq.3)alb(iq)=.24   ! fix-up for adelaide   was   .18
c           if(nn.eq.6)alb(iq)=.18   ! fix-up for brisbane   was   .12
c           if(nn.eq.7)alb(iq)=.18   ! fix-up for perth      was   .13
c           if(nn.eq.8)alb(iq)=.12   ! fix-up for darwin     was   .19
c           if(nn.eq.10)alb(iq)=.16  ! fix-up for albury     was   .13
c           if(nn.eq.2)sigmf(iq)=.5    ! fix-up for sydney
c           if(nn.eq.3)sigmf(iq)=.5    ! fix-up for adelaide
c           if(nn.eq.6)sigmf(iq)=.5    ! fix-up for brisbane
c!***  n.b. nec sx4 vopt/hopt f90 compiler does not cope with next line!
c           if(nn.eq.7)sigmf(iq)=.195  ! fix-up for perth
c           if(nn.eq.8)sigmf(iq)=.5    ! fix-up for darwin
c           if(nn.eq.8)zolnd(iq)=.3   ! fix-up for darwin     was   .79
c         endif  ! (schmidt.gt. .29.and.schmidt.lt. .31)
         iveg=ivegt(iq)
         isoil = isoilm(iq)
         wet3=(wb(iq,3)-swilt(isoil))/(sfc(isoil)-swilt(isoil)) 
         print 98,iunp(nn),istn(nn),jstn(nn),iq,slon(nn),slat(nn),
     &          land(iq),rlongg(iq)*180/pi,rlatt(iq)*180/pi,
     &    isoilm(iq),ivegt(iq),zs(iq)/grav,alb(iq),
     &    wb(iq,3),wet3,sigmf(iq),zolnd(iq),rsmin(iq),he(iq)
98        format(i3,i4,i5,i6,2f7.2 ,l3,2f7.2, i3,i6,f7.1,f5.2,
     &           4f5.2,f5.1,f7.1)
        enddo  ! nn=1,nstn
        if(mstn.eq.2)then   ! then eva's stn2 values too
          do nn=1,nstn2
           call latltoij(slon2(nn),slat2(nn),ri,rj,nface)
           istn2(nn)=nint(ri)
           jstn2(nn)=nint(rj) +nface*il
          enddo  ! nn
          print *,'sea station lu numbers: ',(iunp2(nn),nn=1,nstn)
          print *,'istn2, slon2: ',(istn2(nn),slon2(nn),nn=1,nstn2)
          print *,'jstn2, slat2: ',(jstn2(nn),slat2(nn),nn=1,nstn2)
        endif   !  (mstn.eq.2)
      endif     !  (nstn.gt.0)

      do iq=1,ifull
       albsav(iq)=alb(iq)
      enddo   ! iq loop
      return
      end

      subroutine rdnsib
c     subroutine to read in  data sets required for biospheric scheme.
      use cc_mpi
      include 'newmpar.h'
      include 'arrays.h'
      include 'const_phys.h'
      include 'filnames.h'  ! list of files, read in once only in darlam
      include 'map.h'
      include 'nsibd.h'    ! rsmin,ivegt,sigmf,tgf,ssdn,res,rmc,tsigmf
      include 'parm.h'
      include 'pbl.h'
!     include 'scamdim.h'
      include 'soil.h'
      include 'soilsnow.h' ! new soil arrays for scam - tgg too
      include 'soilv.h'
      include 'tracers.h'
      include 'mpif.h'
      parameter( ivegdflt=1, isoildflt=7, ico2dflt = 999 )
      parameter( falbdflt=15., fsoildflt=0.15, frsdflt=990.)
      parameter( fzodflt=1.)
      data idatafix/0/
      logical rdatacheck,idatacheck,mismatch
c     real vegpsig(13)
c     data vegpsig/ .98, .75, .75, .75, .5, .86, .65, .79, .3, .42, .0,
c    &              .54, .0/
      real vegpsig(44)
      integer ivegmin, ivegmax, ivegmin_g, ivegmax_g
      data vegpsig/ .98,.85,.85,.5,.2,.05,.85,.5,.2,.5,                ! 1-10
     &              .2,.05,.5,.2,.05,.2,.05,.85,.5,.2,                 ! 11-20
     &              .05,.85,.85,.55,.65,.2,.05,.5, .0, .0, .5,         ! 21-31
     &              .98,.75,.75,.75,.5,.86,.65,.79,.3, .42,.02,.54,0./ ! 32-44
c    &              .05,.85,.85,.55,.65,.2,.05,.5, .0, .0, 0.,         ! 21-31

       call readreal(albfile,alb,ifull)
       call readreal(rsmfile,rsmin,ifull)  ! not used these days
       call readreal(zofile,zolnd,ifull)
       if(iradon.ne.0)call readreal(radonemfile,radonem,ifull)
       call readint(vegfile,ivegt,ifull)
       call readint(soilfile,isoilm,ifull)

       mismatch = .false.
       if( rdatacheck(land,alb,'alb',idatafix,falbdflt))
     &      mismatch = .true.
       if( rdatacheck(land,rsmin,'rsmin',idatafix,frsdflt))
     &      mismatch = .true.
       if( rdatacheck(land,zolnd,'zolnd',idatafix,fzodflt))
     &      mismatch = .true.
       if( idatacheck(land,ivegt,'ivegt',idatafix,ivegdflt))
     &      mismatch = .true.
       if( idatacheck(land,isoilm,'isoilm',idatafix,isoildflt))
     &      mismatch = .true.
       if(newsoilm.gt.0)then
         print *,'newsoilm = ',newsoilm
         if(rdatacheck(land,wb(1,1),'w',idatafix,fsoildflt))
     &            mismatch  =.true.
         if(rdatacheck(land,wb(1,ms),'w2',idatafix,fsoildflt))
     &            mismatch  =.true.
       endif
       if(ico2.gt.0) then
         print *,'about to read co2 industrial emission file'
         call readint(co2emfile,ico2em,ifull)
!        if( jdatacheck(land,ico2em,'ico2em',idatafix,ico2dflt))
!    &     mismatch = .true.
       end if

c      if(mismatch.and.idatafix.eq.0)      ! stop in indata for veg
c    &                      stop ' rdnsib: landmask/field mismatch'

c --- rescale and patch up vegie data if necessary
      ivegmin=44
      ivegmax=0
      do iq=1,ifull
       ivegmin=min(ivegmin,ivegt(iq))
       ivegmax=max(ivegmax,ivegt(iq))
      enddo
      print*, "IVEG", myid, ivegmin, ivegmax
      call mpi_allreduce(ivegmin, ivegmin_g, 1, MPI_INTEGER, MPI_MIN, 
     &                  MPI_COMM_WORLD, ierr )
      call mpi_allreduce(ivegmax, ivegmax_g, 1, MPI_INTEGER, MPI_MAX, 
     &                  MPI_COMM_WORLD, ierr )
      if ( mydiag ) print *,'ivegmin,ivegmax ',ivegmin_g,ivegmax_g
      if(ivegmax_g.lt.14)then
       if ( mydiag ) print *,
     &      '**** in this run veg types increased from 1-13 to 32-44'
       do iq=1,ifull            ! add offset to sib values so 1-13 becomes 32-44
        if(ivegt(iq).gt.0)ivegt(iq)=ivegt(iq)+31
       enddo
      endif
 
      do iq=1,ifull
        alb(iq)=alb(iq)/100.
      enddo

      zobg = .05
      do iq=1,ifull
        zolnd(iq)=zolnd(iq)/100.
        zolnd(iq)=min(zolnd(iq) , 1.5)
        zolnd(iq)=max(zolnd(iq) , zobg)
      enddo

      do iq=1,ifull
        if(land(iq))then
          sigmf(iq)=min(.8,.95*vegpsig(ivegt(iq)))
          tsigmf(iq)=sigmf(iq)
        endif
      enddo

c     set sensible default for nso2lev for vertmix, in case so2 not done
      nso2lev=1
      if( iso2.gt.0) then
        print *,'iii3'
        call rdso2em( so2emfile, iso2em, jso2em, so2em, iso2emindex,
     &      iso2lev, nso2lev, so2background, nso2slev, nso2sour )
      end if

      return
      end

      subroutine rdso2em( file, iso2em, jso2em, so2em, iso2emindex,
     &       iso2lev, nso2lev, so2background, nsulfl, ns )
      include 'newmpar.h'
      include 'const_phys.h'
      include 'dates.h'     ! constants such as ds and dt
      include 'filnames.h'  ! list of files, read in once only in darlam
      include 'map.h'       ! array em(iq)
      include 'parm.h'
      integer iso2em(2,ns), jso2em(ns)
      integer iso2emindex(ns), iso2lev(0:nsulfl)
      real    so2em(ns)
      character sname*34, title*100, file*(*)
      data ludat/77/

       print*, "Error no MPI version of rdso2em yet"
       stop
       nso2src = 0
       open (unit=ludat,file=so2emfile,status='old',form='formatted')
       print *,'rdso2em: reading in so2'
       print *,'!!!!!!!!!!!!!! rdnsib: ds =',ds
* ds      - the standard latitude grid box length
* 365.24*24.*60.*60. - number of seconds in a year
* 1.e6    - kiloton to kg conversion
* em(iq) - fine grid scaling coeffincient
       factor = ds*ds*365.24*24.*60.*60./1.0e+06
* 64.065 molecular weight of so2
* 28.965 molecular weight of standard dry air
* 1.0e+09 - conversion to parts per billion
       factor = factor * 64.065 / 28.965 / 1.0e+09
       read( ludat,* )
       read( ludat,'(a)' ) title
       write( *,'(a)' ) title
       read( ludat,'(50x,f9.2)',end=30 ) so2background
       write( *,* ) ' rdso2em: so2 backgroud source value is',
     &               so2background
       so2background = so2background/factor

10     read( ludat,15,end=20 ) sname, rlat, rlon, eso2, height, rmult
       write(*,15)' '//sname, rlat, rlon, eso2, height, rmult
15     format(a,f6.2,f9.2,f9.1,9x,f12.0,f14.2)
       nso2src = nso2src+1

c ri - the index along the parallels axis
c rj - index along the latitudes axis
c iso2em - first index along the parallels
c        - second index along the latitudes
c        - third index for model sigma levels
c so2em  - emission values at iso2em grid point

       stop 'call lconij(rlon,rlat,ri,rj,theta)'  ! **** not ready for globpe
c      write(*,*)' rdso2em: rlat,rlon,ri,rj',rlat,rlon,ri,rj
c      iso2em(1,nso2src) = ri+.5
c      iso2em(2,nso2src) = rj+.5

c this is a rough treatment: 500m 3rd level
c                            250m 2nd level
c                              0m 1st level
       if( height.gt.400.) then
         jso2em(nso2src) = 3
       else if( height.gt.200.) then
         jso2em(nso2src) = 2
       else
         jso2em(nso2src) = 1
       end if

       ix = iso2em(1,nso2src)
       jx = iso2em(2,nso2src)
!      so2em(nso2src) = rmult*eso2/factor/em(ix,jx)**2
!        write(*,*) rmult,ix,jx,so2em(nso2src),factor,em(ix,jx)
       go to 10

20     close(unit=ludat)
       write(*,*) '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
       write(*,*) 'rdso2em: read',nso2src,' sources from file ',file
       write(*,*)
       write(*,*) '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'

       write(*,*) 'rdso2em: nsulfl =', nsulfl
       do i=1,nso2src
         write(*,'(3i4,1pe12.4)') (iso2em(jj,i),jj=1,2),
     &                            jso2em(i), so2em(i)
       end do

c sort the data by levels
       call iindexx(nso2src,jso2em,iso2emindex )
       write(*,*) 'rdso2em: after iindexx'

c if the highest level is above nsulfl, then i'm overwriting something --- quit
      ix0 = jso2em( iso2emindex(nso2src) )
      if( ix0.gt.nsulfl ) then
        write(*,*) ' rdso2em: level value out of range: jso2em(iso2emind
     .ex(nso2src)), iso2emindex(nso2src), nso2src =',
     &    jso2em( iso2emindex(nso2src) ),iso2emindex(nso2src),nso2src
          stop 'rdso2em: execution terminated due to error(s) (1)'
      end if

c index the level range in array iso2em
      iso2lev(   0 ) = 0
      iso2lev( ix0 ) = nso2src
      nso2lev = ix0
      write(*,*) 'ix0, iso2lev(ix0)',ix0, iso2lev(ix0)
      do i=nso2src-1, 1, -1
         ix = jso2em( iso2emindex(i) )
         if( ix.gt.nsulfl ) then
           write(*,*) ' rdso2em: level value out of range: jso2em(iso2em
     .index(i)), iso2emindex(i), i =',
     &     jso2em( iso2emindex(i) ),iso2emindex(i),i
           stop 'rdso2em: execution terminated due to error(s) (2)'
         else if( ix.ne.ix0 ) then
           iso2lev( ix ) = i
           ix0 = ix
           write(*,*) 'ix , iso2lev(ix )',
     &                 ix, iso2lev(ix)
         end if
      end do

       write(*,*) '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
       write(*,*) 'rdso2em: sources after sorting'
       write(*,*)
       write(*,*) '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'

       do i=1,nso2src
         ix = iso2emindex(i)
         write(*,'(4i4,1pe12.4)') i,(iso2em(jj,ix),jj=1,2),
     &                            jso2em(ix), so2em(ix)
       end do

c      stop 'rdso2em: about to exit routine'
       return

30     stop 'rdso2em: error in so2 emissions file (background)'
       end

      function rdatacheck( mask,fld,lbl,idfix,val )
      use cc_mpi, only : myid
      include 'const_phys.h'
      include 'newmpar.h'
      real fld(ifull)
      integer ifld(ifull)
      logical mask(ifull)
      logical rdatacheck, sdatacheck, idatacheck, jdatacheck
      logical toval, err
      character*(*) lbl
      from = 0.
      to   = val
      toval =.true.
      go to 10

      entry sdatacheck( mask,fld,lbl,idfix,val )
      from = val
      to   = 0.
      toval =.false.

 10   continue
      if (myid==0) write(*,*)' datacheck: verifying field ',lbl

      err =.false.
      do iq=1,ifull
          if( mask(iq) ) then
c            if( fld(iq).lt.from ) then
            if( fld(iq).eq.from ) then
              err = .true.
              if( idfix.eq.1 ) then
                fld(iq) = to
                write(*,'(a,2i4,2(a,1pe12.4))')
     &                  '  changing iq=',iq,' from',from,' to',to
              else
                write(*,*) '  mismatch at iq=',iq,', value',from
              end if
            end if
          end if
      end do

      if( toval ) then
        rdatacheck = err
      else
        sdatacheck = err
      end if
      return

      entry idatacheck( mask,ifld,lbl,idfix,ival )
      ifrom = 0
      ito   = ival
      toval =.true.
      go to 20

      entry jdatacheck( mask,ifld,lbl,idfix,ival )
      ifrom = ival
      ito   = 0
      toval =.false.

20    continue
      if(myid==0) write(*,*)' datacheck: verifying field ',lbl
      err =.false.
      do iq=1,ifull
          if( mask(iq) ) then
            if( ifld(iq).eq.ifrom ) then
              err = .true.
              if( idfix.eq.1 ) then
                ifld(iq) = ito
                write(*,'(a,2i4,2(a,i4))')
     &                '  changing iq=',iq,' from',ifrom,' to',ito
              else
                write(*,*) '  mismatch at iq=',iq,', value',ifrom
              end if
            end if
          end if
      end do

      if( toval ) then
        idatacheck = err
      else
        jdatacheck = err
      end if
      return
      end

      subroutine tracini
c --- provide initial tracer values (may be overwritten by infile)
      include 'const_phys.h'
      include 'newmpar.h'
      include 'parm.h'   ! rlat0, rlong0
      include 'tracers.h'
      data fco2/357.0/, fradon/0.0/, fso2/0.0/, fo2/2.1e5/
      print *,'initialize tracer gases'
      if( ico2.ne.0.) then
        if(rlat0.ge.38.5 .and. rlat0.le.39.5
     &      .and.rlong0.ge.137.5 .and. rlong0.le.138.5)fco2=0.
        tr(:,:,max(1,ico2))=fco2
      end if

      if( iradon.ne.0.) then
        tr(:,:,max(1,iradon))=fradon
      end if

      if( iso2.ne.0. ) then
        tr(:,:,max(1,iso2))=fso2
      end if

      if( io2.ne.0. ) then
        tr(:,:,max(1,io2))=fo2
      end if
      return
      end

      subroutine iindexx(n,arrin,indx)
      integer arrin(n),indx(n)
      integer q
      do 11 j=1,n
        indx(j)=j
11    continue
      l=n/2+1
      ir=n
10    continue
        if(l.gt.1)then
          l=l-1
          indxt=indx(l)
          q=arrin(indxt)
        else
          indxt=indx(ir)
          q=arrin(indxt)
          indx(ir)=indx(1)
          ir=ir-1
          if(ir.eq.1)then
            indx(1)=indxt
            return
          endif
        endif
        i=l
        j=l+l
20      if(j.le.ir)then
          if(j.lt.ir)then
            if(arrin(indx(j)).lt.arrin(indx(j+1)))j=j+1
          endif
          if(q.lt.arrin(indx(j)))then
            indx(i)=indx(j)
            i=j
            j=j+j
          else
            j=ir+1
          endif
        go to 20
        endif
        indx(i)=indxt
      go to 10
      end

      subroutine insoil
      use cc_mpi, only : myid
      include 'newmpar.h'
!     include 'scamdim.h'
      include 'soilv.h'
!     n.b. presets for soilv.h moved to blockdata
      common/soilzs/zshh(ms+1),ww(ms)

        do isoil=1,mxst
         cnsd(isoil)  = sand(isoil)*0.3+clay(isoil)*0.25+
     &                  silt(isoil)*0.265
         hsbh(isoil)  = hyds(isoil)*abs(sucs(isoil))*bch(isoil) !difsat*etasat
         ibp2(isoil)  = nint(bch(isoil))+2
         i2bp3(isoil) = 2*nint(bch(isoil))+3
         if ( myid == 0 ) then
            write(6,"('isoil,ssat,sfc,swilt,hsbh ',i2,3f7.3,e11.4)") 
     &            isoil,ssat(isoil),sfc(isoil),swilt(isoil),hsbh(isoil)
         end if
        enddo
        cnsd(9)=2.51

!      zse(1)=0.05
!      zse(2)=0.15
!      zse(3)=0.30
!      zse(4)=0.50
!      zse(5)=1.0
!      zse(6)=1.5                    ! was over-riding data statement (jlm)
       zshh(1) = .5*zse(1)           ! not used (jlm)
       zshh(ms+1) = .5*zse(ms)       !  ???  ! not used (jlm)
       ww(1) = 1.
       do k=2,ms
          zshh(k)= .5*(zse(k-1)+zse(k))  ! z(k)-z(k-1) (jlm)
          ww(k)   = zse(k)/(zse(k)+zse(k-1))
       enddo

      return
      end

!=======================================================================
      subroutine calzo(zobgin)     ! presently no option to call
      include 'newmpar.h'
      include 'arrays.h'
      include 'map.h'   
      include 'nsibd.h' ! ivegt
!     include 'scamdim.h'
      include 'soil.h'      ! zolnd
      include 'soilsnow.h'  ! tgg,wb

      xx=-1.e29
      xn= 1.e29
      do iq=1,ifull
        if(land(iq))then
          iveg=ivegt(iq)
          tsoil  = 0.5*(tgg(iq,ms)+tgg(iq,2))
          sdep=0.
          call cruf1 (iveg,tsoil,sdep,zolnd(iq),zobgin)
          xx=max(xx,zolnd(iq))
          xn=min(xn,zolnd(iq))
        endif ! (land(iq))then
      enddo   ! iq loop

      write(6,*)"zolnd x,n=",xx,xn

      return ! calzo
      end ! calzo
!=======================================================================
      subroutine cruf1 (iv,tsoil,sdep,z0m,zobgin)
c kf, 1997
c for each vegetation type (= iv), assign veg height, total lai, albedo,
c and computed aerodynamic, radiative and interception properties.
c jmax0 assigned due to table by ray leuning and estimates  21-08-97 
c apply seasonal variations in lai and height. return via /canopy/
c nb: total lai = xrlai, veglai = xvlai, veg cover fraction = xpfc,
c     with xrlai = xvlai*xpfc
c type  0 to 31: 2d version with graetz veg types
c type 32 to 43: 2d version with gcm veg types
c type 44:       stand-alone version
c-----------------------------------------------------------------------
c   name                             symbol  code hc:cm pfc:%  veglai
c   ocean                                oc     0     0     0  0.0
c   tall dense forest                    t4     1  4200   100  4.8
c   tall mid-dense forest                t3     2  3650    85  6.3
c   dense forest                         m4     3  2500    85  5.0  (?)
c   mid-dense forest                     m3     4  1700    50  3.75
c   sparse forest (woodland)             m2     5  1200    20  2.78
c   very sparse forest (woodland)        m1     6  1000     5  2.5
c   low dense forest                     l4     7   900    85  3.9
c   low mid-dense forest                 l3     8   700    50  2.77
c   low sparse forest (woodland)         l2     9   550    20  2.04
c   tall mid-dense shrubland (scrub)     s3    10   300    50  2.6
c   tall sparse shrubland                s2    11   250    20  1.69
c   tall very sparse shrubland           s1    12   200     5  1.9
c   low mid-dense shrubland              z3    13   100    50  1.37
c   low sparse shrubland                 z2    14    60    20  1.5
c   low very sparse shrubland            z1    15    50     5  1.21
c   sparse hummock grassland             h2    16    50    20  1.58
c   very sparse hummock grassland        h1    17    45     5  1.41
c   dense tussock grassland              g4    18    75    85  2.3
c   mid-dense tussock grassland          g3    19    60    50  1.2
c   sparse tussock grassland             g2    20    45    20  1.71
c   very sparse tussock grassland        g1    21    40     5  1.21
c   dense pasture/herbfield (perennial)  f4    22    60    85  2.3
c   dense pasture/herbfield (seasonal)  f4s    23    60    85  2.3
c   mid-dense pasture/herb (perennial)   f3    24    45    50  1.2
c   mid-dense pasture/herb  (seasonal)  f3s    25    45    50  1.2
c   sparse herbfield*                    f2    26    35    20  1.87
c   very sparse herbfield                f1    27    30     5  1.0
c   littoral                             ll    28   250    50  3.0
c   permanent lake                       pl    29     0     0  0
c   ephemeral lake (salt)                sl    30     0     0  0
c   urban                                 u    31     0     0  0
c   stand alone: hc,rlai from param1      -    44     -   100  -

c   above are dean's. below are sib (add 31 to get model iveg)
c  1 - broadleaf evergreen trees (tropical forest)
c  2 - broadleaf deciduous trees
c  3 - broadleaf and needleaf trees
c  4 - needleaf evergreen trees
c  5 - needleaf deciduous trees 
c  6 - broadleaf trees with ground cover (savannah)
c  7 - groundcover only (perennial)
c  8 - broadleaf shrubs with groundcover
c  9 - broadleaf shrubs with bare soil
c 10 - dwarf trees and shrubs with groundcover
c 11 - bare soil
c 12 - winter wheat and broadleaf deciduous trees 
 
c                             soil type
c       texture               
c  0   water/ocean
c  1   coarse               sand/loamy_sand
c  2   medium               clay-loam/silty-clay-loam/silt-loam
c  3   fine                 clay
c  4   coarse-medium        sandy-loam/loam
c  5   coarse-fine          sandy-clay
c  6   medium-fine          silty-clay 
c  7   coarse-medium-fine   sandy-clay-loam
c  8   organic              peat
c  9   land ice
c-----------------------------------------------------------------------
!     include 'newmpar.h'   ! parameter statement darlam npatch
!     include 'scamdim.h' 
!     include 'scampar.h'
      real xhc(0:44),xpfc(0:44),xvlai(0:44),xslveg(0:44)
!     common /canopy/
!    &    rlai,hc,disp,usuh,coexp,zruffs,trans,rt0us,rt1usa,rt1usb,
!    &    xgsmax(0:44),xjmax0(0:44)
c aerodynamic parameters, diffusivities, water density:
      parameter(vonk   = 0.40,     ! von karman constant
     &          a33    = 1.25,     ! inertial sublayer sw/us
     &          csw    = 0.50,     ! canopy sw decay (weil theory)
     &          ctl    = 0.40)     ! wagga wheat (rdd 1992, challenges)
c vegetation height
      data xhc    / 0.0,                                               ! 0
     &             30.0,28.0,25.0,17.0,12.0,10.0, 9.0, 7.0, 5.5, 3.0,  ! 1-10
     &              2.5, 2.0, 1.0, 0.6, 0.5, 0.5,0.45,0.75, 0.6,0.45,
     &              0.4, 0.6, 0.6,0.24,0.25,0.35, 0.3, 2.5, 0.0, 0.0,
     &              0.0,                                               ! 31
     & 32.,20.,20.,17.,17., 1., 1., 1., 0.5, 0.6, 0., 1.,0./ !sellers 1996 j.climate

c vegetation fractional cover
      data xpfc   /0.00,
     &             1.00,0.85,0.85,0.50,0.20,0.05,0.85,0.50,0.20,0.50,
     &             0.20,0.05,0.50,0.20,0.05,0.20,0.05,0.85,0.50,0.20,
     &             0.05,0.85,0.85,0.50,0.50,0.20,0.05,0.50,0.00,0.00,
     &             0.00,
     &   .98,.75,.75,.75,.50,.86,.65,.79,.30,.42,.02,.54,  1.0/

c veg lai from graetz table of 283 veg types (iv=0 to 31), and maximum 
c veg lai for gcm veg types (iv=32 to 43)  stand-alone: 44
      data xvlai  / 0.0,
     &              4.80,6.30,5.00,3.75,2.78,2.50,3.90,2.77,2.04,2.60,
     &              1.69,1.90,1.37,1.50,1.21,1.58,1.41,2.30,1.20,1.71,
     &              1.21,2.30,2.30,1.20,1.20,1.87,1.00,3.00,0.00,0.00,
     &              0.00,
     &   6.0,5.0,4.0,4.0,4.0,3.0,3.0,3.0,1.0,4.0,0.5,3.0,  0.0/     ! 32-44

c for seasonally varying lai, amplitude of veg lai seasonal change
      data xslveg  /0.00,
     &              0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,
     &              0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,
     &              0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,
     &              0.00,
     &   2.0,2.0,2.0,2.0,2.0,1.5,1.5,1.5,1.0,0.5,0.5,0.5,  0.0/
c leaf gsmax for forest (0.006), grass (0.008) and crop (0.012)
c littoral is regarded as forest, dense pasture between grass and crop
!     data xgsmax  / 0.0,
!    &     0.006,0.006,0.006,0.006,0.006,0.006,0.006,0.006,0.006,0.006,
!    &     0.006,0.006,0.006,0.006,0.006,0.008,0.008,0.008,0.008,0.008,
!    &     0.008,0.010,0.010,0.012,0.012,0.008,0.008,0.006,0.000,0.000,
!    &     0.000,
!    &  .006,.006,.006,.006,.006,.006,.008,.008,.006,.006,.0,0.010,  0./
! littoral is regarded as forest, dense pasture between grass and crop
!     data xjmax0 / 0.0,
!    &     5e-5,5e-5,5e-5,5e-5,5e-5,5e-5,5e-5,5e-5,5e-5,5e-5,
!    &     5e-5,5e-5,5e-5,5e-5,5e-5,10e-5,10e-5,10e-5,10e-5,10e-5,
!    &     10e-5,15e-5,15e-5,15e-5,15e-5,10e-5,10e-5,5e-5,1e-5,1e-5,
!    &     1e-5,
!    &     5e-5,5e-5,5e-5,5e-5,5e-5,10e-5,10e-5,10e-5,5e-5,10e-5,
!    &     1e-5,15e-5,  1e-5/
c-----------------------------------------------------------------------
c assign aerodynamic, radiative, stomatal, interception properties
c assign total lai (xrlai) from veg lai and pfc, and assign seasonal 
c   variation in lai and veg height where necessary. this is controlled
c   by the factor season (0 =< season =< 1).
      ftsoil=max(0.,1.-.0016*(298.-tsoil)**2)
      if( tsoil .ge. 298. ) ftsoil=1.
      vrlai = max(0.0,(xvlai(iv)-xslveg(iv)*(1.-ftsoil))*xpfc(iv))
      hc    = max(0.0,xhc(iv) - sdep)
      rlai  = vrlai*hc/max(0.01,xhc(iv))
c   find roughness length z0m from hc and rlai:
      call cruf2(hc,rlai,usuh,z0m,disp,coexp)
c   set aerodynamic variables for bare soil and vegetated cases:
      z0m=max(min(z0m, 1.5), zobgin)
      if (rlai.lt.0.001 .or. hc.lt..05) then
        z0m    = zobgin      ! bare soil surface
        hc     = 0.0  
        rlai   = 0.0
      endif
      return
      end
!=======================================================================
      subroutine cruf2(h,rlai,usuh,z0,d,coexp)
c-----------------------------------------------------------------------
c m.r. raupach, 24-oct-92
c see: raupach, 1992, blm 60 375-395
c      mrr notes "simplified wind model for canopy", 23-oct-92
c      mrr draft paper "simplified expressions...", dec-92
c-----------------------------------------------------------------------
c inputs:
c   h     = roughness height
c   rlai  = leaf area index (assume rl = frontal area index = rlai/2)
c output:
c   usuh  = us/uh (us=friction velocity, uh = mean velocity at z=h)
c   z0    = roughness length
c   d     = zero-plane displacement
c   coexp = coefficient in exponential in-canopy wind profile
c           u(z) = u(h)*exp(coexp*(z/h-1)), found by gradient-matching
c           canopy and roughness-sublayer u(z) at z=h
c-----------------------------------------------------------------------
c preset parameters:
      parameter (cr    = 0.3,          ! element drag coefficient
     &           cs    = 0.003,        ! substrate drag coefficient
     &           beta  = cr/cs,        ! ratio cr/cs
     &           ccd   = 15.0,         ! constant in d/h equation
     &           ccw   = 2.0,          ! ccw=(zw-d)/(h-d)
     &           usuhm = 0.3,          ! (max of us/uh)
     &           vonk  = 0.4)          ! von karman constant
      psih=alog(ccw)-1.0+1.0/ccw
      rl = rlai*0.5
c find uh/us
      usuhl  = sqrt(cs+cr*rl)
      usuh   = min(usuhl,usuhm)
c find d/h and d 
      xx     = sqrt(ccd*max(rl,0.0005))
      dh     = 1.0 - (1.0 - exp(-xx))/xx
      d      = dh*h
c find z0h and z0:
      z0h    = (1.0 - dh) * exp(psih - vonk/usuh)
      z0     = z0h*h
c find coexp: see notes "simplified wind model ..." eq 34a
      coexp  = usuh / (vonk*ccw*(1.0 - dh))
      return ! ruff
      end
!=======================================================================


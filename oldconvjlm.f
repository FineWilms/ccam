      subroutine oldconvjlm(iaero)      ! jlm convective scheme - Version v3
!     the shallow convection options here just for iterconv=1
!     has +ve fldownn depending on delta sigma; -ve uses older abs(fldown)   
!     N.B. nevapcc option has been removed
      use aerosolldr
      use arrays_m   
      use cc_mpi, only : mydiag, myid, bounds
      use cfrac_m
      use diag_m
      use indices_m
      use kuocomb_m
      use latlong_m
      use liqwpar_m  ! ifullw
      use map_m
      use morepbl_m
      use nharrs_m, only : phi_nh
      use prec_m
      use sigs_m
      use soil_m
      use tkeeps, only : tke,eps ! MJT
      use tracers_m  ! ngas, nllp, ntrac
      use vvel_m
      implicit none
      integer itn,iq,k,k13,k23
     .       ,khalf,khalfd,khalfp,kt
     .       ,ncubase,nfluxq,nfluxdsk,nlayers,nlayersd,nlayersp
     .       ,ntest,ntr,nums,nuv
     .       ,ka,kb,kc
      real convmax,delqq,delss,deltaq,delq_av,delt_av
     .    ,den1,den2,den3,detr,dprec,dqrx,entrainp,entrr,entrradd
     .    ,facuv,fldownn,fluxa,fluxb,fluxd,fluxup
     .    ,frac,fraca,fracb,gam,hbas,hbase,heatlev
     .    ,pwater,pwater0,qavg,qavgb,qentrr,qprec,qsk,rkmid
     .    ,savg,savgb,sentrr,sum,totprec,veldt
     .    ,rKa,Dva,cfls,cflscon,rhodz,qpf,pk,Apr,Bpr,Fr,rhoa,dz,Vr
     .    ,dtev,qr,qgdiff,Cev2,qr2,Cevx,alphal,blx,evapls,revq
     .    ,deluu,delvv,pb

      include 'newmpar.h'
      parameter (ntest=0)      ! 1 or 2 to turn on; -1 for ldr writes
!                               -2,-3 for other detrain test      
!     parameter (iterconv=1)   ! to kuocom.h
!     parameter (fldown=.6)    ! to kuocom.h
!     parameter (detrain=.05)  ! to kuocom.h
!     parameter (alflnd=1.15)  ! e.g. 1.15  
!     parameter (alfsea=1.05)  ! e.g. 1.05  
!                                3:for RH-enhanced base
c     parameter (ncubase=2)    ! 2 from 4/06, more like 0 before  - usual
      parameter (ncubase=3)    ! 3 ensure takes local maxima
!                ncubase=0       ktmax limited in later itns
!                        1       cloud base not below that of itn 1     
      parameter (nfluxq=2)     ! 1 from 8/02, 0 from 10/03, 2 from 3/06
      parameter (nfluxdsk=-2)  ! 1 till 6/8/02  then -2
                               ! nbase<-4 bypasses it
!     parameter (mbase=0)      ! .ne.0 cfrac test as %
!     parameter (methdetr=2)   ! original code removed March 2010
!     parameter (methprec=8)   ! 1 (top only); 2 (top half); 4 top quarter (= kbconv)
!     parameter (nuvconv=0)    ! usually 0, >0 or <0 to turn on momentum mixing
!     parameter (nuv=0)        ! usually 0, >0 to turn on new momentum mixing (base layers too)
      integer kcl_top          ! max level for cloud top (convjlm,radrive,vertmix)
!     nevapls:  turn off/on ls evap - through parm.h; 0 off, 5 newer UK
!     could reinstate nbase=0 & kbsav_b from .f0406
      include 'const_phys.h'
      include 'kuocom.h'   ! kbsav,ktsav,convfact,convpsav,ndavconv
      include 'parm.h'
      include 'parmdyn.h'
      integer ktmax(ifull),kbsav_ls(ifull),kb_sav(ifull),kt_sav(ifull)
      integer kmin(ifull),iaero
      real, dimension(:), allocatable, save :: alfqarr
      real, dimension(ifull) :: conrev,rho,xtgsto,ttsto,qqsto,qqrain
      real, dimension(ifull,naero) :: fscav
      logical, dimension(ifull) :: bliqu
      real delq(ifull,kl),dels(ifull,kl),delu(ifull,kl)
      real delv(ifull,kl),dqsdt(ifull,kl),es(ifull,kl) 
      real fldow(ifull),fluxq(ifull),fluxbb(ifull)
      real fluxr(ifull),flux_dsk(ifull),fluxt(ifull,kl),hs(ifull,kl)  
      real phi(ifull,kl),qbase(ifull),qdown(ifull),qliqw(ifull,kl)
      real qq(ifull,kl),qs(ifull,kl),qxcess(ifull)
      real qbass(ifull,kl-1)
      real rnrt(ifull),rnrtc(ifull),rnrtcn(ifull)
      real s(ifull,kl),sbase(ifull),tdown(ifull),tt(ifull,kl)
      real dsk(kl),h0(kl),q0(kl),t0(kl)  
      real qplume(ifull,kl),splume(ifull,kl)
      integer kdown(ifull)
      real entr(ifull),qentr(ifull),sentr(ifull),factr(ifull)
      real fluxqs,fluxt_k(kl)
      real cfraclim(ifull),convtim(ifull),ff(ifull,kl)
      real rlnd(ifull+iextra)    
      real, save:: detrainin
      real, dimension(:), allocatable, save :: timeconv
      real, dimension(:), allocatable, save :: factnb
      integer, save:: klon2,klon3
      data nuv/0/
      include 'establ.h'

      kcl_top=kl-2
      if (.not.allocated(alfqarr)) then
        allocate(alfqarr(ifull))
        allocate(timeconv(ifull))
        allocate(factnb(kl))
      end if

      do k=1,kl
       dsk(k)=-dsig(k)    !   dsk = delta sigma (positive)
      enddo     ! k loop
      
      if(ktau==1)then
        detrainin=detrain
        timeconv(:)=0.
        do k=1,kl
         if(sig(k)>.75)klon3=k
         if(sig(k)> .5)klon2=k
        enddo
        if (myid == 0) then
          write(6,*)'in convjlm klon3,klon2 = ',klon3,klon2
        end if
        do iq=1,ifull
          if(land(iq))then
            alfqarr(iq)=abs(alflnd)
          else
            alfqarr(iq)=abs(alfsea)
          endif
        enddo
        if(alfsea<0.)then
	  rlnd=0.
	  where (land)
	    rlnd=1.
	  end where
	  call bounds(rlnd)
          do iq=1,ifull
           if(rlnd(in(iq))>0.5.or.rlnd(ie(iq))>0.5.or.
     &        rlnd(iw(iq))>0.5.or.rlnd(is(iq))>0.5)
     &          alfqarr(iq)=abs(alflnd)
          enddo
        endif
        if(alflnd<0.)then
!         use full value for dx>60km, else linearly vary upwards from 1
          alfqarr(:)=1.+min(1.,ds/(60.e3*em(1:ifull)))*(alfqarr(:)-1.)
        endif  ! (alflnd<0)
        factnb(:)=0.
        do kb=1,kl
         do k=1,kb
          factnb(kb)=factnb(kb)+dsk(k)*(1.-sig(k))
c         factnb(kb)=factnb(kb)+(1.-sig(k))
         enddo
         factnb(kb)=1./factnb(kb)
        enddo
      endif    ! (ktau==1)

      if(mbase.ne.0)cfraclim(:)=.0001*abs(mbase) ! mbase=1000 for 10%, 100 for 1%

c     convective first, then L/S rainfall
      qliqw(:,:)=0.  
      kmin(:)=0
      conrev(1:ifull)=1000.*ps(1:ifull)/(grav*dt) ! factor to convert precip to g/m2/s
      rnrt(:)=0.       ! initialize large-scale rainfall array
      rnrtc(:)=0.      ! initialize convective  rainfall array
      ktmax(:)=kl      ! preset 1 level above current topmost-permitted ktsav
      kbsav_ls(:)=0    ! for L/S
      ktsav(:)=kl-1    ! preset value to show no deep or shallow convection
      kbsav(:)=kl-1    ! preset value to show no deep or shallow convection

      tt(1:ifull,:)=t(1:ifull,:)       
      qq(1:ifull,:)=qg(1:ifull,:)      
      if(convtime>10.)then       
!       following increases convtime_eff for small grid lengths
!       e.g. for convtime=15, gives 3600. for 15km,  900. for 60km
!                         30, gives 7200. for 15km, 1800. for 60km
        convtim(:)=convtime*3.6e6*em(1:ifull)/ds
      elseif(convtime<0.)then         
!       convtim decreases during convection, after it starts    
        do iq=1,ifull 
         convtim(:)=3600.*
     &              max(abs(convtime)-(timeconv(iq)-mdelay/3600.),0.)
        enddo
      else                                          ! original option
        convtim(:)=3600.*convtime
      endif  ! (convtime>10.) .. else ..
      factr(:)=dt/max(dt,convtim(:))          ! to re-scale convpsav
c     following modification was found to be not much use
c     do iq=1,ifull
c       k=kb_sav(iq)
c       if(qq(iq,k)+qlg(iq,k)+qfg(iq,k)>qs(iq,k))factr(iq)=1.
c     enddo

!_____________________beginning of convective calculations________________
      do itn=1,iterconv
!     calculate geopotential height 
      kb_sav(:)=kl-1   ! preset value for no convection
      kt_sav(:)=kl-1   ! preset value for no convection
      rnrtcn(:)=0.     ! initialize convective rainfall array (pre convpsav)
      convpsav(:)=0.
      dels(:,:)=1.e-20
      delq(:,:)=0.
      if(nuvconv.ne.0)then 
        if(nuvconv<0)nuv=abs(nuvconv)  ! Oct 08
        delu(:,:)=0.
        delv(:,:)=0.
        facuv=.1*abs(nuvconv) ! full effect for nuvconv=10
      endif

      phi(:,1)=bet(1)*tt(:,1)
      do k=2,kl
        phi(:,k)=phi(:,k-1)+bet(k)*tt(:,k)
     &                      +betm(k)*tt(:,k-1)
      enddo      ! k  loop
      phi=phi+phi_nh  ! add non-hydrostatic component - MJT

      do k=1,kl   
       do iq=1,ifull
        es(iq,k)=establ(tt(iq,k))
       enddo  ! iq loop
      enddo   ! k loop
      do k=1,kl   
       do iq=1,ifull
        pk=ps(iq)*sig(k)
c       qs(iq,k)=max(.622*es(iq,k)/(pk-es(iq,k)),1.5e-6)  
        qs(iq,k)=.622*es(iq,k)/max(pk-es(iq,k),1.)
        dqsdt(iq,k)=qs(iq,k)*pk*hlars/(tt(iq,k)**2*max(pk-es(iq,k),1.))
        s(iq,k)=cp*tt(iq,k)+phi(iq,k)  ! dry static energy
c       calculate hs
        hs(iq,k)=s(iq,k)+hl*qs(iq,k)   ! saturated moist static energy
       enddo  ! iq loop
      enddo   ! k loop
      hs(:,:)=max(hs(:,:),s(:,:)+hl*qq(:,:))   ! added 21/7/04
      if(itn==1)then
        do k=1,kl-1  ! N.B. qbass only defined for itn=1, here:
         qbass(:,k)=min(alfqarr(:)*qq(:,k),max(qs(:,k),qq(:,k))) 
        enddo
c***    by defining qbass just for itn=1, convpsav does not converge as quickly as may be expected,
c***    as qbass may not be reduced by convpsav if already qs-limited    
c***    Also entrain may slow convergence  
      endif
      do k=1,kl-1
c      qplume(:,k)=alfqarr(:)*qq(:,k)
c      qplume(:,k)=min(qplume(:,k),max(qs(:,k),qq(:,k)))    
       qplume(:,k)=min(alfqarr(:)*qq(:,k),qbass(:,k),   ! from Jan 08
     &         max(qs(:,k),qq(:,k)))   ! to avoid qb increasing with itn
       splume(:,k)=s(:,k)  
      enddo

      if(ktau==1.and.mydiag)then
        print *,'itn,iterconv,nuv,nuvconv ',itn,iterconv,nuv,nuvconv
        print *,'ntest,methdetr,methprec,detrain,detrainx ',
     .           ntest,methdetr,methprec,detrain,detrainx
        print *,'fldown,ncubase ',fldown,ncubase
        print *,'nfluxq,nfluxdsk ',nfluxq,nfluxdsk
        print *,'alflnd,alfsea ',alflnd,alfsea
        print *,'cfraclim,convtim,factr ',
     &           cfraclim(idjd),convtim(idjd),factr(idjd)
      endif
      if((ntest>0.or.diag.or.nmaxpr==1).and.mydiag) then
        iq=idjd
        write (6,"('near beginning of convjlm; ktau',i5,' itn',i1)") 
     &                                         ktau,itn 
        write (6,"('rh   ',12f7.2/(5x,12f7.2))") 
     .             (100.*qq(iq,k)/qs(iq,k),k=1,kl)
        write (6,"('qs   ',12f7.3/(5x,12f7.3))") 
     .             (1000.*qs(iq,k),k=1,kl)
        write (6,"('qq   ',12f7.3/(5x,12f7.3))") 
     .             (1000.*qq(iq,k),k=1,kl)
        pwater0=0.   ! in mm     
        do k=1,kl
         iq=idjd
         h0(k)=s(iq,k)/cp+hlcp*qq(iq,k)
         q0(k)=qq(iq,k)
         t0(k)=tt(iq,k)
         pwater0=pwater0-dsig(k)*qg(iq,k)*ps(iq)/grav
        enddo
        write (6,"('qbas  ',12f7.3/(5x,12f7.3))") 1000.*qplume(iq,:)
        write (6,"('tt    ',12f7.2/(5x,12f7.2))") tt(iq,:)
        write (6,"('s/cp  ',12f7.2/(5x,12f7.2))") s(iq,:)/cp
        write (6,"('s/cp  ',12f7.2/(5x,12f7.2))") s(iq,:)/cp
        write (6,"('h/cp  ',12f7.2/(5x,12f7.2))") 
     .             s(iq,:)/cp+hlcp*qq(iq,:)
        write (6,"('hb/cp',12f7.2/(5x,12f7.2))") 
     .             s(iq,:)/cp+hlcp*qplume(iq,:)
        write (6,"('hs/cp ',12f7.2/(5x,12f7.2))") hs(iq,:)/cp
        write (6,"('cfracc',12f7.3/6x,12f7.3)") cfrac(iq,:)
        write (6,"('k   ',12i7/(4x,12i7))") (k,k=1,kl)
        write (6,"('es     ',9f7.1/(7x,9f7.1))") es(iq,:)
        write (6,"('dqsdt6p',6p9f7.1/(7x,9f7.1))") dqsdt(iq,:)
        sum=0.
        do k=1,kl
         sum=sum-dsig(k)*(s(iq,k)/cp+hlcp*qq(iq,k))
        enddo
        print *,'h_sum   ',sum
      endif

      sbase(:)=0.  ! just for tracking running max, working downwards
      qbase(:)=0.  ! just for tracking running max, working downwards
!     Following procedure chooses lowest valid cloud bottom (and base)
      
      ka=klon2
      kb=kuocb+1
      kc=-1
      if(nbase<=-7)then
        ka=kuocb+1
        kb=klon2
        kc=1
      endif

      do k=ka,kb,kc   ! downwards (usually) to find cloud base **k loop**
       kdown(:)=1     ! set tentatively as valid cloud bottom
!      k here is nominally level about kbase      
       if(mbase>0)then  ! reduced timeconv let-out (when convtime set <0) 
!        mdelay <0 avoids timeconv let-out, keeping timeconv=0.
!        but note that leoncld sets a convective cloud fraction
         do iq=1,ifull
          if(cfrac(iq,k)<.01.or.
     &     (cfrac(iq,k)<cfraclim(iq).and.timeconv(iq)==0.))
     &                 kdown(iq)=-abs(kdown(iq)) ! suppressing this cloud base
         enddo      
c       elseif(mbase<0)then
c!        like mbase >0 but requires either level k or k-1
c         do iq=1,ifull
c          if((cfrac(iq,k)<.01.and.cfrac(iq,k-1)<.01).or.
c     &     (cfrac(iq,k)<cfraclim(iq).and.cfrac(iq,k-1)<cfraclim(iq).and.
c     &      timeconv(iq)==0.))kdown(iq)=-abs(kdown(iq))
c         enddo      
       endif  ! (mbase>0) .. elseif ..
       if(itn>1.and.ncubase==1)then  ! included on 27/3/06 - not usual
         do iq=1,ifull
          if(k-1>kbsav(iq))kdown(iq)=-abs(kdown(iq))
         enddo
       endif    ! (itn>1.and.ncubase==1)
c      print *,'kdown,k before test ',kdown(iq),k
           
       if(nbase==-6)then      !
        do iq=1,ifull
!        find tentative cloud base (bottom of k-1 level, lowest below pblh)
c        pb=pblh(iq)*grav
         if(k>2.and.kdown(iq)>0)then  ! kdown here for mbase cld option
          if(.5*(phi(iq,k-2)+phi(iq,k-1))<pblh(iq)*grav)then
           if(splume(iq,k-1)+hl*qplume(iq,k-1)>
     &           max(hs(iq,k),sbase(iq)+hl*qbase(iq))
     &       .and.qplume(iq,k-1)>max(qs(iq,k),qq(iq,k)))then      ! newer qbas test 
             kb_sav(iq)=k-1
             qbase(iq)=qplume(iq,k-1)
             sbase(iq)=splume(iq,k-1)
             kt_sav(iq)=k
           endif  
          endif  
         endif  
        enddo    ! iq loop
c       kdown(:)=abs(kdown(:))
       elseif(nbase==-7)then  
        do iq=1,ifull
!        find tentative cloud base 
!        - bottom of k-1 level below pblh; uppermost moist-unstable level
c        pb=pblh(iq)*grav
         if(k>2.and.kdown(iq)>0)then  
          if(.5*(phi(iq,k-2)+phi(iq,k-1))<pblh(iq)*grav)then
           if(splume(iq,k-1)+hl*qplume(iq,k-1)>hs(iq,k)
     &       .and.qplume(iq,k-1)>max(qs(iq,k),qq(iq,k)))then      ! newer qbas test 
             kb_sav(iq)=k-1
             kt_sav(iq)=k
           endif  
          endif  
         endif  
        enddo    ! iq loop
c       kdown(:)=abs(kdown(:))
       elseif(nbase==-8)then      !
        do iq=1,ifull
!        find uppermost tentative cloud base (k-1 level closest to pblh)
         pb=pblh(iq)*grav
         if(k>2.and.kdown(iq)>0)then  
          if(phi(iq,k-1)<pb.or.
     &       (phi(iq,k-1)>pb.and.phi(iq,k-1)-pb<pb-phi(iq,k-2)))then
           if(splume(iq,k-1)+hl*qplume(iq,k-1)>hs(iq,k)
     &       .and.qplume(iq,k-1)>max(qs(iq,k),qq(iq,k)))then      ! newer qbas test 
             kb_sav(iq)=k-1
c            qbase(iq)=qplume(iq,k-1)
c            sbase(iq)=splume(iq,k-1)
             kt_sav(iq)=k
           endif  
          endif  
         endif  
        enddo    ! iq loop
c       kdown(:)=abs(kdown(:))
       elseif(nbase==-9.or.nbase==-11)then      
        do iq=1,ifull
!        find tentative cloud base ! (middle of k-1 level, uppermost below pblh)
         if(k>2.and.kdown(iq)>0)then  
          if(phi(iq,k-1)<pblh(iq)*grav)then
           if(splume(iq,k-1)+hl*qplume(iq,k-1)>hs(iq,k)
     &       .and.qplume(iq,k-1)>max(qs(iq,k),qq(iq,k)))then      ! newer qbas test 
             kb_sav(iq)=k-1
             kt_sav(iq)=k
           endif  
          endif  
         endif  
        enddo    ! iq loop
c       kdown(:)=abs(kdown(:))
       elseif(nbase==-10)then     
        do iq=1,ifull
!        find tentative cloud base ! (bottom of k-1 level, uppermost below pblh)
         if(k>2.and.kdown(iq)>0)then  
          if(.5*(phi(iq,k-2)+phi(iq,k-1))<pblh(iq)*grav)then
           if(splume(iq,k-1)+hl*qplume(iq,k-1)>hs(iq,k)
     &       .and.qplume(iq,k-1)>max(qs(iq,k),qq(iq,k)))then      ! newer qbas test 
             kb_sav(iq)=k-1
             kt_sav(iq)=k
           endif  
          endif  
         endif  
        enddo    ! iq loop
c       kdown(:)=abs(kdown(:))
       else   !  previous default (up till 24/4/07) includes nbase=-4
        do iq=1,ifull
!        find tentative cloud base, and bottom of below-cloud layer
         if(kdown(iq)>0)then   
!         now choose base layer to also have local max of qplume      
          if(splume(iq,k-1)+hl*qplume(iq,k-1)>
     &           max(hs(iq,k),sbase(iq)+hl*qbase(iq))
     &       .and.qplume(iq,k-1)>max(qs(iq,k),qq(iq,k)))then      ! newer qbas test 
             kb_sav(iq)=k-1
             qbase(iq)=qplume(iq,k-1)
             sbase(iq)=splume(iq,k-1)
             kt_sav(iq)=k
             if(ncubase==3)kdown(iq)=2
          else
            if(kdown(iq)==2)kdown(iq)=0  ! switches off remaining levels 
          endif  ! (qbas>max(qs(iq,k),qq(iq,k)).and.sbas+hl*qbas>hs(iq,k))
         endif   ! (kdown(iq)>0)
        enddo    ! iq loop
c       kdown(:)=abs(kdown(:))
       endif     !  if(nbase==-6)then  ..else ..
              
       if(ntest>0.and.mydiag)then
c      if((ntest>0.or.diag).and.mydiag)then
         iq=idjd
         kb=kb_sav(iq)
         print *,'k,kdown,kb_sav,kt_sav ',
     &            k,kdown(iq),kb_sav(iq),kt_sav(iq)
         print *,'phi(,k-1)/g,pblh ',phi(iq,k-1)/9.806,pblh(iq)
         print *,'qbas,qs(.,k),qq(.,k) ',qplume(iq,kb),qs(iq,k),qq(iq,k)
         print *,'splume,qplume,(splume+hl*qplume)/cp,hs(iq,k)/cp ',
     &            splume(iq,kb),qplume(iq,kb),
     &           (splume(iq,kb)+hl*qplume(iq,kb))/cp,hs(iq,k)/cp
       endif    ! (ntest>0.and.mydiag) 
      enddo     ! ******************** k loop ****************************

      entrainp=1.+abs(entrain)
      entr(:)=0.
      qentr(:)=0.
      sentr(:)=0.
      if(entrain>=0.)then
        do k=kuocb+1,kl   ! upwards to find cloud top
         do iq=1,ifull
          if((kt_sav(iq)==k-1.or.kt_sav(iq)==k).and.k<ktmax(iq))then ! ktmax allows for itn
            hbase=splume(iq,k-1)+hl*qplume(iq,k-1)
            entrr=-entrain*dsig(k)
            qplume(iq,k)=qplume(iq,k-1)*(1.+entr(iq))+entrr*qq(iq,k)
            splume(iq,k)=splume(iq,k-1)*(1.+entr(iq))+entrr*s(iq,k)
            entr(iq)=entr(iq)+entrr
            qplume(iq,k)=qplume(iq,k)/(1.+entr(iq))
            splume(iq,k)=splume(iq,k)/(1.+entr(iq))
            if(ntest>0.and.iq==idjd.and.mydiag)
     &         print *,'k,hbase/cp,hs/cp ',k,hbase/cp,hs(iq,k)/cp
            if(hbase>hs(iq,k))then
              kt_sav(iq)=k
            endif
          endif   ! (kt_sav(iq)==k-1.and.k<ktmax(iq))
         enddo    ! iq loop
        enddo     ! k loop
        entr(:)=entrain
      endif  ! (entrain>=0.)
      if(nkuo==25.and.itn>1)then
        do iq=1,ifull
          if(kmin(iq)<0)then
            kt_sav(iq)=-kmin(iq)
            kmin(iq)=0
          endif          
        enddo
      endif
      if(entrain<0.)then  ! not fixed up yet!!!
        fluxr(:)=1.  ! just for qplume & splume denom (allows for 2-layer clouds)
        do k=kuocb+2,kl   ! upwards to find cloud top
         do iq=1,ifull
          if(kt_sav(iq)==k-1.and.k<ktmax(iq))then ! ktmax allows for itn
            kb=kb_sav(iq)
            hbas=splume(iq,kb)+hl*qplume(iq,kb)
            entrr=abs(entrain)/(sigmh(kb_sav(iq)+1)-sigmh(k))
            qentrr=qentr(iq)-dsig(k-1)*qq(iq,k-1)
            sentrr=sentr(iq)-dsig(k-1)*s(iq,k-1)
            hbase=(hbas+entrr*(sentrr+hl*qentrr))/entrainp
            if(hbase>hs(iq,k))then
              kt_sav(iq)=k
              entr(iq)=entrr
              qentr(iq)=qentrr
              sentr(iq)=sentrr
              fluxr(iq)=entrainp
            endif
          endif   ! (kt_sav(iq)==k-1.and.k<ktmax(iq))
         enddo    ! iq loop
        enddo     ! k loop
!       update top-emerging qplume & splume to include entrainment
        do iq=1,ifull
         kc=kt_sav(iq)-1
         qplume(iq,kc)=(qplume(iq,kc)+qentr(iq))/(1.+entr(iq))
         splume(iq,kc)=(splume(iq,kc)+sentr(iq))/(1.+entr(iq))
        enddo
        entr(:)=entrain
      endif  ! (entrain<0.)
      
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

!     calculate dels and delq for all layers for unit base mass flux
!     designed to be OK if q(k)>qs(k)
      do iq=1,ifull
!      dels and delq for top layer
!      following line allows for qq>qs, to avoid drying layer
       qsk=max(qs(iq,kt_sav(iq)),qq(iq,kt_sav(iq)))  
       entrradd=1.+entr(iq)*(sigmh(kb_sav(iq)+1)-sigmh(kt_sav(iq)))
       qprec=entrradd*max(0.,qplume(iq,kt_sav(iq)-1)-qsk)             
       dels(iq,kt_sav(iq))=entrradd*splume(iq,kt_sav(iq)-1) ! s flux
       if(nuv>0)then
         delu(iq,kt_sav(iq))=u(iq,kb_sav(iq))
         delv(iq,kt_sav(iq))=v(iq,kb_sav(iq))
       endif  ! (nuv>0)
       delq(iq,kt_sav(iq))=entrradd*qsk
       dels(iq,kt_sav(iq))=dels(iq,kt_sav(iq))+hl*qprec    ! precip. heating
       kdown(iq)=min(kl,kb_sav(iq)+nint(.6+.75*(kt_sav(iq)-kb_sav(iq))))
       if(nkuo>23)then 
!       following refines calc of kdown to be more accurately .75 of cloud depth       
        if(ntest>0.and.iq==idjd.and.mydiag)then
          pb=(.75*sig(kt_sav(iq))+.25*sig(kb_sav(iq))
     &            -sig(kdown(iq)))/dsig(kdown(iq))
          print *,'kdown1,kb_sav,kt_sav,dsig,pb,nint ',
     &      kdown(iq),kb_sav(iq),kt_sav(iq),dsig(kdown(iq)),pb,nint(pb)
        endif
        kdown(iq)=kdown(iq)+nint( (.75*sig(kt_sav(iq))
     &            +.25*sig(kb_sav(iq))-sig(kdown(iq)))/dsig(kdown(iq)) )
        if(ntest>0.and.iq==idjd.and.mydiag)print *,'kdown1b,sig ',
     &           kdown(iq),.75*sig(kt_sav(iq))+.25*sig(kb_sav(iq))
       endif  ! (nkuo>23)
c      qsk is value entering downdraft, qdown is value leaving downdraft
c      tdown is temperature emerging from downdraft (at cloud base)       
       qsk=min(qs(iq,kdown(iq)),qq(iq,kdown(iq))) ! N.B. min for downdraft subs
       tdown(iq)=t(iq,kb_sav(iq))+(s(iq,kdown(iq))-s(iq,kb_sav(iq))
     .      +hl*(qsk-qs(iq,kb_sav(iq))))/(cp+hl*dqsdt(iq,kb_sav(iq)))
!      don't want moistening of cloud base layer (can lead to -ve fluxes) 
c      qdown(iq)=min( qq(iq,kb_sav(iq)) , qs(iq,kb_sav(iq))+
c    .           (tdown(iq)-t(iq,kb_sav(iq)))*dqsdt(iq,kb_sav(iq)) )
       qdown(iq)= qs(iq,kb_sav(iq))+
     .           (tdown(iq)-t(iq,kb_sav(iq)))*dqsdt(iq,kb_sav(iq)) 
       dprec=qdown(iq)-qsk                      ! to be mult by fldownn
!      typically fldown=.6 or -.2        
       fldownn=max(-fldown,fldown*(sig(kb_sav(iq))-sig(kt_sav(iq))))
       totprec=qprec-fldownn*dprec 
       if(tdown(iq)>t(iq,kb_sav(iq)).or.totprec<0.)then
         fldow(iq)=0.
       else
         fldow(iq)=fldownn
       endif
c      fldow(iq)=(.5+sign(.5,totprec))*fldownn ! suppr. downdraft for totprec<0
       rnrtcn(iq)=qprec-fldow(iq)*dprec        ! already has dsk factor
       if(ntest==1.and.iq==idjd.and.mydiag)then
         print *,'qsk,qprec,totprec,dels0 ',qsk,qprec,totprec,hl*qprec 
         print *,'fldow,dprec,rnrtcn ',fldow(iq),dprec,rnrtcn(iq)
       endif
!      add in downdraft contributions
       dels(iq,kdown(iq))=dels(iq,kdown(iq))-fldow(iq)*s(iq,kdown(iq))
       delq(iq,kdown(iq))=delq(iq,kdown(iq))-fldow(iq)*qsk
!      calculate emergent downdraft properties
       delq(iq,kb_sav(iq))=fldow(iq)*qdown(iq)
       dels(iq,kb_sav(iq))=fldow(iq)*
     .        (s(iq,kb_sav(iq))+cp*(tdown(iq)-t(iq,kb_sav(iq))))  ! correct
c    .        (s(iq,kdown(iq)) +cp*(tdown(iq)-t(iq,kb_sav(iq))))  ! not this
       if(nuv>0)then
         delu(iq,kdown(iq))=delu(iq,kdown(iq))-fldow(iq)*u(iq,kdown(iq))
         delv(iq,kdown(iq))=delv(iq,kdown(iq))-fldow(iq)*v(iq,kdown(iq))
         delu(iq,kb_sav(iq))=fldow(iq)*u(iq,kdown(iq))
         delv(iq,kb_sav(iq))=fldow(iq)*v(iq,kdown(iq))
       endif  ! (nuv>0)
      enddo  ! iq loop
      if((ntest>0.or.diag).and.mydiag)then
        iq=idjd
        kb=kb_sav(iq)
        entrradd=1.+entr(iq)*(sigmh(kb_sav(iq)+1)-sigmh(kt_sav(iq)))
        print *,'ktmax,ktsav,entr,entrradd ',
     .           ktmax(iq),ktsav(iq),entr(iq),entrradd
        print *,'ktau,itn,kb_sav,kt_sav,kdown ',
     .           ktau,itn,kb_sav(iq),kt_sav(iq),kdown(iq)
        print *,'tdown,qdown,fldow ,alfqar',
     &           tdown(iq),qdown(iq),fldow(iq),alfqarr(iq)
        print *,'splume',splume(iq,1:kt_sav(iq))
        print *,'qplume',qplume(iq,1:kt_sav(iq))
C       following just shows flux into kt layer, and fldown at base and top     
        write (6,"('delsa',9f8.0/(5x,9f8.0))")
     &              dels(iq,1:kt_sav(iq))
        write (6,"('delqa',3p9f8.3/(5x,9f8.3))")
     &              delq(iq,1:kt_sav(iq))
      endif
      
      if(nbase==2)then
!       use full sub-cloud layer with linearly decreasing fluxes
!       N.B. this one has downdraft fully into kbsav layer
        do k=1,klon3-1
         do iq=1,ifull
          if(kb_sav(iq)<=klon3.and.k<kb_sav(iq))then
            fluxa=(1.-sigmh(k+1))/(1.-sigmh(kb_sav(iq)+1))
            delss=fluxa*(s(iq,k+1)-s(iq,k))
            delqq=fluxa*(qq(iq,k+1)-qq(iq,k))
            dels(iq,k)=dels(iq,k)+delss
            delq(iq,k)=delq(iq,k)+delqq
            dels(iq,k+1)=dels(iq,k+1)-delss
            delq(iq,k+1)=delq(iq,k+1)-delqq
          endif
         enddo
        enddo
      endif   ! (nbase==2)
      
      if(nbase==3)then
!       use full sub-cloud layer with quadratically decreasing fluxes
!       N.B. this one has downdraft fully into kbsav layer
        do k=1,klon3-1
         do iq=1,ifull
          if(kb_sav(iq)<=klon3.and.k<kb_sav(iq))then
            fluxa=((1.-sigmh(k+1))/(1.-sigmh(kb_sav(iq)+1)))**2
            delss=fluxa*(s(iq,k+1)-s(iq,k))
            delqq=fluxa*(qq(iq,k+1)-qq(iq,k))
            dels(iq,k)=dels(iq,k)+delss
            delq(iq,k)=delq(iq,k)+delqq
            dels(iq,k+1)=dels(iq,k+1)-delss
            delq(iq,k+1)=delq(iq,k+1)-delqq
          endif
         enddo
        enddo
      endif   ! (nbase==3)
      
      if(nbase<=-2.and.nbase>-11)then   ! usual in 2006-7 (includes nbase=-4, -6)
!       use full sub-cloud layer with linearly decreasing fluxes
!       N.B. this one does likewise with downdrafts
        do k=klon2,1,-1
         do iq=1,ifull
          if(kb_sav(iq)<=klon2)then
           if(k==kb_sav(iq))then
!           first reduce effect of downdraft on kb_sav layer 
!           using net downdraft flux into the whole sub-cloud layer
            fluxd=1.-(1.-sigmh(k))/(1.-sigmh(kb_sav(iq)+1))     
            dels(iq,k)=fluxd*dels(iq,k)
            delq(iq,k)=fluxd*delq(iq,k)
            if(nuv>0)then
              delu(iq,k)=fluxd*delu(iq,k)
              delv(iq,k)=fluxd*delv(iq,k)
            endif  ! (nuv>0)
           endif  ! (k==kb_sav(iq))
           if(k<kb_sav(iq))then
            fluxa=(1.-sigmh(k+1))/(1.-sigmh(kb_sav(iq)+1))
            fluxb=(1.-sigmh(k  ))/(1.-sigmh(kb_sav(iq)+1))
            fluxd=fldow(iq)*(fluxa-fluxb)          
            delss=fluxa*((1.-fldow(iq))*s(iq,k+1)-s(iq,k))
            delqq=fluxa*((1.-fldow(iq))*qq(iq,k+1)-qq(iq,k))
            dels(iq,k)=dels(iq,k)+delss
     &       +fluxd*(s(iq,k)+cp*(tdown(iq)-t(iq,k)))            
            delq(iq,k)=delq(iq,k)+delqq   +fluxd*qdown(iq)
            dels(iq,k+1)=dels(iq,k+1)-delss
            delq(iq,k+1)=delq(iq,k+1)-delqq
            if(nuv>0)then
              deluu=fluxa*((1.-fldow(iq))*u(iq,k+1)-u(iq,k))
              delvv=fluxa*((1.-fldow(iq))*v(iq,k+1)-v(iq,k))
              delu(iq,k)=delu(iq,k)+deluu   +fluxd*u(iq,kdown(iq))
              delv(iq,k)=delv(iq,k)+delvv   +fluxd*v(iq,kdown(iq))
              delu(iq,k+1)=delu(iq,k+1)-deluu
              delv(iq,k+1)=delv(iq,k+1)-delvv
           endif  ! (nuv>0)
          endif   ! (k<kb_sav(iq))
          endif   ! (kb_sav(iq)<=klon2)
         enddo
        enddo
      endif   ! (nbase<=-2.and.nbase>-11)

!     subtract contrib to cloud base layer (unit flux this one)
      do iq=1,ifull
       delq(iq,kb_sav(iq))=delq(iq,kb_sav(iq))-qplume(iq,kb_sav(iq))
       dels(iq,kb_sav(iq))=dels(iq,kb_sav(iq))-splume(iq,kb_sav(iq))
      enddo
      if(nuv>0)then
        do iq=1,ifull
         delu(iq,kb_sav(iq))=delu(iq,kb_sav(iq))-u(iq,kb_sav(iq))
         delv(iq,kb_sav(iq))=delv(iq,kb_sav(iq))-v(iq,kb_sav(iq))
        enddo
      endif  ! (nuv>0)
      if((ntest>0.or.diag).and.mydiag)then
        iq=idjd
        kb=kb_sav(iq)
        write (6,"('delsaa',9f8.0/(5x,9f8.0))")
     &              dels(iq,1:kt_sav(iq))
        write (6,"('delqaa',3p9f8.3/(5x,9f8.3))")
     &              delq(iq,1:kt_sav(iq))
      endif
 
      if(alfsea>0)then 
        fraca=1.    ! effectively used from 23/5/03
        fracb=0.    ! to avoid giving -ve qg for the layer
      else
        fraca=.5
        fracb=.5
      endif  ! (alfsea>0)

!     subsidence and (possible) entrainment
      do k=kuocb+1,kl-1
       do iq=1,ifull
        if(k>kb_sav(iq).and.k<=kt_sav(iq))then
          savg=(fraca*s(iq,k)+fracb*s(iq,k-1))         ! fraca=1. usually
     .         *(1.+(sigmh(kb_sav(iq)+1)-sigmh(k))*entr(iq))
          qavg=(fraca*qq(iq,k)+fracb*qq(iq,k-1))
     .         *(1.+(sigmh(kb_sav(iq)+1)-sigmh(k))*entr(iq))
!         savg=s(iq,k)   ! 23/5/03
!         qavg=qq(iq,k)  ! 23/5/03 to avoid giving -ve qg for the layer
          dels(iq,k)=dels(iq,k)-savg             ! subsidence 
          dels(iq,k-1)=dels(iq,k-1)+savg         ! subsidence into lower layer
          delq(iq,k)=delq(iq,k)-qavg             ! subsidence 
          delq(iq,k-1)=delq(iq,k-1)+qavg         ! subsidence into lower layer
          if(nuv>0)then
            delu(iq,k)=delu(iq,k)-u(iq,k)        ! subsidence 
            delu(iq,k-1)=delu(iq,k-1)+u(iq,k)    ! subsidence into lower layer
            delv(iq,k)=delv(iq,k)-v(iq,k)        ! subsidence 
            delv(iq,k-1)=delv(iq,k-1)+v(iq,k)    ! subsidence into lower layer
          endif  ! (nuv>0)
          if(k<kt_sav(iq))then
            dels(iq,k)=dels(iq,k)+dsig(k)*entr(iq)*s(iq,k)  ! entr into updraft
            delq(iq,k)=delq(iq,k)+dsig(k)*entr(iq)*qq(iq,k) ! entr into updraft
          endif
        endif  ! (k>kb_sav(iq).and.k<=kt_sav(iq))
       enddo   ! iq loop
      enddo    ! k loop
      if((ntest>0.or.diag).and.mydiag)then
        iq=idjd
        write (6,"('delsb',9f8.0/(5x,9f8.0))")
     &              dels(iq,1:kt_sav(iq))
        write (6,"('delqb',3p9f8.3/(5x,9f8.3))")
     &              delq(iq,1:kt_sav(iq))
      endif

!     modify calculated subsidence for downdraft effects
      do k=kuocb+1,kl-1
       do iq=1,ifull
        if(k<=kdown(iq).and.k>kb_sav(iq))then
         savgb=fraca*s(iq,k)+fracb*s(iq,k-1)
         qavgb=fraca*qq(iq,k)+fracb*qq(iq,k-1)
!        savgb=s(iq,k)   ! 23/5/03
!        qavgb=qq(iq,k)  ! 23/5/03
         dels(iq,k)=dels(iq,k)+fldow(iq)*savgb     ! anti-subsidence 
         dels(iq,k-1)=dels(iq,k-1)-fldow(iq)*savgb ! anti-subsidence into l-l
         delq(iq,k)=delq(iq,k)+fldow(iq)*qavgb     ! anti-subsidence 
         delq(iq,k-1)=delq(iq,k-1)-fldow(iq)*qavgb ! anti-subsidence into l-l
         if(nuv>0)then
           delu(iq,k)=delu(iq,k)+fldow(iq)*u(iq,k)     ! anti-subsidence 
           delu(iq,k-1)=delu(iq,k-1)-fldow(iq)*u(iq,k) ! anti-subsidence into l-l
         endif  ! (nuv>0)
        endif
       enddo   ! iq loop
      enddo    ! k loop
      if((ntest>0.or.diag).and.mydiag)then
        iq=idjd
        write (6,"('delsc',9f8.0/(5x,9f8.0))")
     &              dels(iq,1:kt_sav(iq))
        write (6,"('delqc',3p9f8.3/(5x,9f8.3))")
     &              delq(iq,1:kt_sav(iq))
      endif   
      
      if(nbase==-11)then  
!       use full sub-cloud layer with linearly decreasing fluxes
!       N.B. this one does likewise with downdrafts
        do k=1,klon2
         do iq=1,ifull
          if(kb_sav(iq)<=klon2.and.k<=kb_sav(iq))then
c           frac=(1.-sig(k))*factnb(kb_sav(iq))
            frac=(1.-sig(k))*dsk(k)*factnb(kb_sav(iq))
            dels(iq,k)=frac*dels(iq,kb_sav(iq))
            delq(iq,k)=frac*delq(iq,kb_sav(iq))
            if(nuv>0)then
              delu(iq,k)=frac*delu(iq,kb_sav(iq))
              delv(iq,k)=frac*delv(iq,kb_sav(iq))
            endif  ! (nuv>0)
          endif  ! (k==kb_sav(iq))
         enddo
        enddo
      endif   ! (nbase==-11)

      if((ntest>0.or.diag).and.mydiag)then
        print *,"before diag print of dels,delh "
        iq=idjd
        khalfd=kt_sav(iq)+1-nlayersd
        nlayersp=max(1,nint((kt_sav(iq)-kb_sav(iq)-.1)/methprec)) ! round down
        khalfp=kt_sav(iq)+1-nlayersp
        print *,'kb_sav,kt_sav,khalfd ',
     .           kb_sav(iq),kt_sav(iq),khalfd 
        print *,'khalfp,nlayersp ',khalfp,nlayersp 
        write (6,"('delsd',9f8.0/(5x,9f8.0))")
     &              dels(iq,1:kt_sav(iq))
        write (6,"('delq*hl',9f8.0/(5x,9f8.0))")
     &              delq(iq,1:kt_sav(iq))*2.5e6
        write (6,"('delh ',9f8.0/(5x,9f8.0))")
     &             (dels(iq,k)+hl*delq(iq,k),k=1,kl)
        write (6,"('delhb',9f8.0/(5x,9f8.0))")
     &             (dels(iq,k)+alfqarr(iq)*hl*delq(iq,k),k=1,kl)
        sum=0.
        do k=kb_sav(iq),kt_sav(iq)
         sum=sum+dels(iq,k)+hl*delq(iq,k)
        enddo
        print *,'qplume,sum_delh ',qplume(iq,kb_sav(iq)),sum
      endif

!     calculate actual delq and dels
      do k=1,kl-1    
       do iq=1,ifull
          delq(iq,k)=delq(iq,k)/dsk(k)
          dels(iq,k)=dels(iq,k)/dsk(k)
       enddo     ! iq loop
      enddo      ! k loop

      if((ntest>0.or.diag).and.mydiag)then
        iq=idjd
        print *,"before convpsav calc, after division by dsk"
        write (6,"('dels',9f8.0/(5x,9f8.0))")
     &              dels(iq,1:kt_sav(iq))
        write (6,"('delq3p',3p9f8.3/(7x,9f8.3))")
     &              delq(iq,1:kt_sav(iq))
      endif

!----------------------------------------------------------------------------
!     calculate base mass flux 
      do iq=1,ifull
       if(kb_sav(iq)<kl-1)then   
!        prevents withdrawal of unrealistically large moisture, which
!        may occur from using sequence of thin layers	
         if(nfluxdsk==1)flux_dsk(iq)=dsk(kb_sav(iq))
         if(nfluxdsk==2)flux_dsk(iq)=.5*dsk(kb_sav(iq))
         if(nfluxdsk==-1)flux_dsk(iq)=dsk(kb_sav(iq))/iterconv
         if(nfluxdsk==-2)flux_dsk(iq)=dsk(kb_sav(iq))/(2*iterconv) !usual
         if(nfluxdsk==-3)flux_dsk(iq)=dsk(kb_sav(iq))/(3*iterconv)
         if(nfluxdsk==-5)flux_dsk(iq)=dsk(kb_sav(iq))/(5*iterconv)
         if(nfluxdsk==0.or.nbase<=-4)flux_dsk(:)=9. 
         convpsav(iq)=flux_dsk(iq)
         if(nfluxq==1)then  ! does little cf flux_dsk - will be removed
!          fluxq limiter: new_qq(kb)=new_qq(kt)
!          i.e. [qq+M*delq]_kb=[qq+M*delq]_kt
           fluxq(iq)=max(0.,(qq(iq,kb_sav(iq))-qq(iq,kt_sav(iq)))/ 
     .                      (delq(iq,kt_sav(iq)) - delq(iq,kb_sav(iq))))
           convpsav(iq)=min(convpsav(iq),fluxq(iq))
         endif  ! (nfluxq==1)
         if(nfluxq==2)then  ! fluxqs option from 27/2/06
!          fluxq limiter: new_qq(kb)=new_qs(kb+1)
!          i.e. alfqarr*[qq+M*delq]_kb=[qs+M*dqsdt*dels/cp]_kb+1
           k=kb_sav(iq)
c          if(ktau==5)print *,'tst',iq,kb_sav(iq),kt_sav(iq),
c    &     dqsdt(iq,k+1),dels(iq,k+1),alfqarr(iq),delq(iq,k),
c    &     alfqarr(iq)*qq(iq,k)-qs(iq,k+1),
c    &     dqsdt(iq,k+1)*dels(iq,k+1)/cp -alfqarr(iq)*delq(iq,k)
c          if(dqsdt(iq,k+1)*dels(iq,k+1)/cp 
c    &        +alfqarr(iq)*abs(delq(iq,k))<0.)print *,'$$$$ iq,k ',iq,k
           fluxq(iq)=max(0.,(alfqarr(iq)*qq(iq,k)-qs(iq,k+1))/ 
     .     (dqsdt(iq,k+1)*dels(iq,k+1)/cp +alfqarr(iq)*abs(delq(iq,k))))
           if(delq(iq,k)>0.)fluxq(iq)=0.    ! delq should be -ve 15/5/08
           convpsav(iq)=min(convpsav(iq),fluxq(iq))
         endif  ! (nfluxq==2)
       endif    ! (kb_sav(iq)<kl-1)
      enddo     ! iq loop
      
      do k=kl-1,kuocb+1,-1
       do iq=1,ifull
!       want: new_hbas>=new_hs(k), i.e. in limiting case:
!       [h+alfsarr*M*dels+alfqarr*M*hl*delq]_base 
!                                          = [hs+M*dels+M*hlcp*dels*dqsdt]_k
!       pre 21/7/04 occasionally got -ve fluxt, for supersaturated layers
        if(k>kb_sav(iq).and.k<=kt_sav(iq))then
c         if(dels(iq,k)*(1.+hlcp*dqsdt(iq,k))-dels(iq,kb_sav(iq))           
c    .       -alfqarr(iq)*hl*delq(iq,kb_sav(iq))<0.)
c    .       print *,'-ve denom for iq,k = ',iq,k
          fluxt(iq,k)=(splume(iq,k-1)+hl*qplume(iq,k-1)-hs(iq,k))/
     .       max(1.e-9,dels(iq,k)*(1.+hlcp*dqsdt(iq,k))       ! 0804 for max
     .                -dels(iq,kb_sav(iq))                    ! to avoid zero
     .                -alfqarr(iq)*hl*delq(iq,kb_sav(iq)) )   ! with real*4
          if(fluxt(iq,k)<convpsav(iq))then
            convpsav(iq)=fluxt(iq,k)
            kmin(iq)=k
            if(nkuo==25.and.kmin(iq)<kt_sav(iq)
     &          .and.sig(k)>.8)then
              convpsav(iq)=0.
              kmin(iq)=-k
            endif
          endif
c         if(iq==idjd)print *,'diag k,convpsav,fluxt,kmin',
c    &                              k,convpsav(iq),fluxt(iq,k),kmin(iq)
          if(dels(iq,kb_sav(iq))+alfqarr(iq)*hl*delq(iq,kb_sav(iq))>0.)
     &             convpsav(iq)=0.  ! added 27/7/07       
        endif   ! (k>kb_sav(iq).and.k<kt_sav(iq))
       enddo    ! iq loop
       if((ntest>0.or.diag).and.mydiag)then
        iq=idjd
        if(k>kb_sav(iq).and.k<=kt_sav(iq))then
          den1=dels(iq,k)*(1.+hlcp*dqsdt(iq,k))
          den2=dels(iq,kb_sav(iq))
          den3=alfqarr(iq)*hl*delq(iq,kb_sav(iq))
          fluxt_k(k)=(splume(iq,k-1)+hl*qplume(iq,k-1)-hs(iq,k))/
     .                max(1.e-9,den1-den2-den3) 
          print *,'k,den1,den2,den3,fluxt ',k,den1,den2,den3,fluxt_k(k)
        endif   ! (k>kb_sav(iq).and.k<kt_sav(iq))
       endif    ! ((ntest>0.or.diag).and.mydiag)
      enddo     ! k loop      

      if(mbase<0)then
        do iq=1,ifull
          if(cfrac(iq,kb_sav(iq)+1)<cfraclim(iq).and.
     &       sig(kb_sav(iq))-sig(kt_sav(iq))>.11)convpsav(iq)=0.
        enddo
      endif

      if(ntest==2.and.mydiag)then
        convmax=0.
        do iq=1,ifull
         if(convpsav(iq)>convmax.and.kb_sav(iq)==2)then
           print *,'ktau,iq,convpsav,fluxt3,kb_sav2,kt_sav ',
     .            ktau,iq,convpsav(iq),fluxt(iq,3),kb_sav(iq),kt_sav(iq)
           idjd=iq
           convmax=convpsav(iq)
         endif
        enddo	
      endif   !  (ntest==2)
      
      if((ntest>0.or.diag).and.mydiag)then
        iq=idjd
        k=kb_sav(iq)
        if(k<kl)then
          fluxqs=(alfqarr(iq)*qq(iq,k)-qs(iq,k+1))/
     &           (dqsdt(iq,k+1)*dels(iq,k+1)/cp -alfqarr(iq)*delq(iq,k))
          print *,'alfqarr(iq)*qq(iq,k) ',alfqarr(iq)*qq(iq,k)
          print *,'alfqarr(iq)*delq(iq,k) ',alfqarr(iq)*delq(iq,k)
          print *,'qs(iq,k+1) ',qs(iq,k+1)
          print *,'dqsdt(iq,k+1)*dels(iq,k+1)/cp ',
     &             dqsdt(iq,k+1)*dels(iq,k+1)/cp
c         print *,'dqsdt(iq,k+1) ',dqsdt(iq,k+1)
c         print *,'dels(iq,k+1) ',dels(iq,k+1)
c         print *,'delq(iq,k) ',delq(iq,k)
          print *,'fluxqs ',fluxqs
        endif
        write(6,"('flux_dsk,fluxq,fluxbb,convpsav',5f9.5)")
     .             flux_dsk(iq),fluxq(iq),fluxbb(iq),convpsav(iq)
        write(6,"('delQ*dsk6p',6p9f8.3/(10x,9f8.3))")
     .    (convpsav(iq)*delq(iq,k)*dsk(k),k=1,kl)
        write(6,"('delt*dsk3p',3p9f8.3/(10x,9f8.3))")
     .   (convpsav(iq)*dels(iq,k)*dsk(k)/cp,k=1,kl)
        convmax=0.
        nums=0
        print *,'      iq nums kb  kt    dsk   flb     flt   flux',
     &         '  rhb  rht  rnrt    rnd'
        do iq=1,ifull     
         if(kt_sav(iq)-kb_sav(iq)==1)then
           nums=nums+1
           if(convpsav(iq)>convmax)then
c          if(nums<20)then
             convmax=convpsav(iq)
             write(6,"('bc  ',2i5,2i3,2x,3f7.3,f6.3,2f5.2,2f7.4)") 
     .       iq,nums,kb_sav(iq),kt_sav(iq),
     .       dsk(kb_sav(iq)),fluxbb(iq),
     .       fluxt(iq,kt_sav(iq)),convpsav(iq),
     .       qq(iq,kb_sav(iq))/qs(iq,kb_sav(iq)),
     .       qq(iq,kt_sav(iq))/qs(iq,kt_sav(iq)),
     &       rnrtcn(iq),rnrtcn(iq)*convpsav(iq)*ps(iq)/grav
           endif
         endif
        enddo  ! iq loop
        convmax=0.
        nums=0
        do iq=1,ifull     
         if(kt_sav(iq)-kb_sav(iq)==2)then
           nums=nums+1
           if(convpsav(iq)>convmax)then
c          if(nums<20)then
             convmax=convpsav(iq)
             write(6,"('bcd ',2i5,2i3,2x,3f7.3,f6.3,2f5.2,2f7.4)") 
     .       iq,nums,kb_sav(iq),kt_sav(iq),
     .       dsk(kb_sav(iq)),fluxbb(iq),
     .       fluxt(iq,kt_sav(iq)),convpsav(iq),
     .       qq(iq,kb_sav(iq))/qs(iq,kb_sav(iq)),
     .       qq(iq,kt_sav(iq))/qs(iq,kt_sav(iq)),
     &       rnrtcn(iq),rnrtcn(iq)*convpsav(iq)*ps(iq)/grav
           endif
         endif
        enddo  ! iq loop
        convmax=0.
        nums=0
        do iq=1,ifull     
         if(kt_sav(iq)-kb_sav(iq)==3)then
           nums=nums+1
           if(convpsav(iq)>convmax)then
c          if(nums<20)then
             convmax=convpsav(iq)
             write(6,"('bcde',2i5,2i3,2x,3f7.3,f6.3,2f5.2,2f7.4)") 
     .       iq,nums,kb_sav(iq),kt_sav(iq),
     .       dsk(kb_sav(iq)),fluxbb(iq),
     .       fluxt(iq,kt_sav(iq)),convpsav(iq),
     .       qq(iq,kb_sav(iq))/qs(iq,kb_sav(iq)),
     .       qq(iq,kt_sav(iq))/qs(iq,kt_sav(iq)),
     &       rnrtcn(iq),rnrtcn(iq)*convpsav(iq)*ps(iq)/grav
           endif
         endif
        enddo  ! iq loop
      endif    ! (ntest>0.or.diag)
      
      if(nmaxpr==1.and.mydiag)then
        iq=idjd
        print *,'Total_a delq (g/kg) & delt for this itn:'
        write(6,"('delQ',3p12f7.3/(4x,12f7.3))")
     &            convpsav(iq)*delq(iq,:)
        write(6,"('delT',12f7.3/(4x,12f7.3))")
     &            convpsav(iq)*dels(iq,:)/cp
        write (6,"('hb/cpo',12f7.2/(9x,12f7.2))") 
     .            (splume(iq,:)+hl*qplume(iq,:))/cp
        write (6,"('qq_n  ',12f7.3/(9x,12f7.3))") 
     &             (qq(iq,:)+convpsav(iq)*delq(iq,:))*1000.
        write (6,"('new_qbas ',12f7.3/(9x,12f7.3))") 
     &     alfqarr(iq)*(qq(iq,:)+convpsav(iq)*delq(iq,:))*1000.
c       this s and h does not yet include updated phi (or does it?)     
        write (6,"('s/cp_n',12f7.2/(9x,12f7.2))") 
     &             (s(iq,:)+convpsav(iq)*dels(iq,:))/cp 
        write (6,"('h/cp_n',12f7.2/(9x,12f7.2))") 
     &            (s(iq,:)+hl*qq(iq,:)+convpsav(iq)*
     &             (dels(iq,:)+hl*delq(iq,:)))/cp       
        write (6,"('hb/cpn',12f7.2/(9x,12f7.2))") 
     &            (splume(iq,:)+hl*qplume(iq,:)+convpsav(iq)
     &            *(dels(iq,:)+alfqarr(iq)*hl*delq(iq,:)))/cp 
        write (6,"('hs/cpn',12f7.2/(9x,12f7.2))") 
     &             (hs(iq,:)+convpsav(iq)*dels(iq,:)+
     &              (1.+hlcp*dqsdt(iq,:)))/cp  
      endif

      if(ntest==-2)then
        do iq=1,ifull     
          detrain=min(1.,max(0.,1.5*sig(kt_sav(iq))-.2))
          qxcess(iq)=detrain*rnrtcn(iq) 
        enddo
       elseif(ntest==-3)then
        do iq=1,ifull     
          detrain=min(1.,1.5*sig(kt_sav(iq))**2)
          qxcess(iq)=detrain*rnrtcn(iq) 
        enddo
      else  ! following is usual (beyond ntest test)
!       following line moved up further (for -ve sig_ct) on 27/6/08
        qxcess(:)=detrain*rnrtcn(:)             ! e.g. .2* gives 20% detrainment
      endif

      if(sig_ct<0.)then  ! detrain for shallow clouds
        do iq=1,ifull
         if(sig(kt_sav(iq))>-sig_ct)then  ! typically here sig_ct ~ -.8
           qxcess(iq)=rnrtcn(iq)     ! full detrainment
         endif
        enddo  ! iq loop
      else
        do iq=1,ifull
         if(sig(kt_sav(iq))>sig_ct)then  ! typically sig_ct ~ .8
           convpsav(iq)=0.       ! N.B. will get same result on later itns
           if(ktsav(iq)==kl-1)then
             kbsav(iq)=kb_sav(iq) 
             ktsav(iq)=kt_sav(iq)  ! for possible use in vertmix
           endif  ! (ktsav(iq)==kl-1)
         endif
        enddo  ! iq loop
      endif    !  (sig_ct<0.).. else ..

!     new detrain calc to try coping with shallow conv too 
!     - usually with methprec=8 too
      if(methdetr==1)then  
        do iq=1,ifull     
         detrain=min(1.,max(.15,               ! thicknesses .1 (full) and .6 (.15)
     &           1.17-1.7*(sig(kb_sav(iq))-sig(kt_sav(iq)))))
         qxcess(iq)=detrain*rnrtcn(iq) 
        enddo
      endif   ! (methdetr==1)     
      if(methdetr==2)then  
        do iq=1,ifull     
         detrain=min(1.,max(.16,               ! thicknesses .2 (full) and .6 (.15)
     &           1.42-2.1*(sig(kb_sav(iq))-sig(kt_sav(iq)))))
         qxcess(iq)=detrain*rnrtcn(iq) 
        enddo
      endif   ! (methdetr==2)     
      if(methdetr>4)then  
        do iq=1,ifull   
         if(sig(kb_sav(iq))-sig(kt_sav(iq))<.01*methdetr)then
           detrain=1.
         else
           detrain=detrainin
         endif
         qxcess(iq)=detrain*rnrtcn(iq) 
        enddo
      endif   ! (methdetr>4)     

      if(itn==1)then
        cape(:)=0.
        do k=2,kl-1
         do iq=1,ifull
          if(k>kb_sav(iq).and.k<=kt_sav(iq))then
            kb=kb_sav(iq)
            cape(iq)=cape(iq)-(splume(iq,kb)+hl*qplume(iq,kb)-hs(iq,k))*
     &              rdry*dsig(k)/(cp*sig(k))            
          endif
         enddo
        enddo
        do iq=1,ifull
         if(mdelay>=0.and.convpsav(iq)>0.)then ! mdelay option 3/3/07
           timeconv(iq)=timeconv(iq)+dt/3600.
         else
           timeconv(iq)=0.
         endif
        enddo
      endif  ! (itn==1)
      if(mdelay>0)then  ! suppresses conv. unless occurred for >= mdelay secs
        do iq=1,ifull
         if(timeconv(iq)<mdelay/3600.)then
           convpsav(iq)=0.
         endif
        enddo
      endif  ! (mdelay>0)
      
      do iq=1,ifull
       if(ktsav(iq)==kl-1.and.convpsav(iq)>0.)then
         kbsav(iq)=kb_sav(iq) 
         ktsav(iq)=kt_sav(iq)  
       endif  ! (ktsav(iq)==kl-1.and.convpsav(iq)>0.)
      enddo   ! iq loop

      if(itn<iterconv)then 
        convpsav(:)=convfact*convpsav(:) ! typically convfact=1.02  
        if(ncubase==0)ktmax(:)=kt_sav(:) ! ktmax added July 04  
      endif                              ! (itn<iterconv)
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!      
      rnrtcn(:)=rnrtcn(:)-qxcess(:)

!     update qq, tt and precip
      rnrtc(:)=rnrtc(:)+convpsav(:)*rnrtcn(:)*conrev(:) ! g/m**2/s
      if(ncvcloud==0)then  ! usual
        do k=1,kl   
         do iq=1,ifull
          qq(iq,k)=qq(iq,k)+convpsav(iq)*delq(iq,k)
          tt(iq,k)=tt(iq,k)+convpsav(iq)*dels(iq,k)/cp
         enddo    ! iq loop
        enddo     ! k loop
      else
        do k=1,kl   
         do iq=1,ifull
          qq(iq,k)=qq(iq,k)+convpsav(iq)*delq(iq,k)
         enddo    ! iq loop
c        fluxt here denotes delt, phi denotes del_phi
         if(k==1)then
           do iq=1,ifull
            fluxt(iq,1)=convpsav(iq)*dels(iq,1)/(cp+bet(1))
            phi(iq,1)=bet(1)*fluxt(iq,1)
            tt(iq,k)=tt(iq,k)+fluxt(iq,k)
           enddo    ! iq loop
         else
           do iq=1,ifull
            fluxt(iq,k)=(convpsav(iq)*dels(iq,k)-phi(iq,k-1)
     &                  -betm(k)*fluxt(iq,k-1))/(cp+bet(k))
            phi(iq,k)=phi(iq,k-1)+betm(k)*fluxt(iq,k-1)
     &                +bet(k)*fluxt(iq,k)
            tt(iq,k)=tt(iq,k)+fluxt(iq,k)
           enddo    ! iq loop
         endif
        enddo     ! k loop
      endif
      
!!!!!!!!!!!!!!!!!!!!! "deep" detrainment using detrain !!!!!v3!!!!!!    
!     N.B. convpsav has been updated here with convfact, but without factr term  
      if(methprec==1)then               ! moisten top layer only 
       do iq=1,ifull  
        deltaq=convpsav(iq)*qxcess(iq)/dsk(kt_sav(iq))             
        qliqw(iq,kt_sav(iq))=qliqw(iq,kt_sav(iq))+deltaq
       enddo  ! iq loop
      elseif(methprec==8)then           ! moisten all cloud layers, top most
       do k=kuocb+1,kl-1 
        do iq=1,ifull  
         nlayers=kt_sav(iq)-kb_sav(iq)
         sum=.5*nlayers*(nlayers+1)
         if(k>kb_sav(iq).and.k<=kt_sav(iq))then
           deltaq=convpsav(iq)*qxcess(iq)*(k-kb_sav(iq))/(sum*dsk(k))    
           qliqw(iq,k)=qliqw(iq,k)+deltaq
         endif
        enddo  ! iq loop
       enddo   ! k loop
      elseif(methprec==-1)then   
       do k=kuocb+1,kl-1 
        do iq=1,ifull  
         deltaq=0.
         nlayers=kt_sav(iq)-kb_sav(iq)
         sum=.5*nlayers*(nlayers+1)
         if(k>kb_sav(iq).and.k<=kt_sav(iq))then
           deltaq=convpsav(iq)*qxcess(iq)*(k-kb_sav(iq))/(sum*dsk(k))    
         endif
         if(sig(kb_sav(iq))-sig(kt_sav(iq))<.01*methdetr.and.  ! shallow clouds
     &     k>kb_sav(iq).and.k<=kt_sav(iq))then
           deltaq=convpsav(iq)*qxcess(iq)*(kt_sav(iq)+1-k)/(sum*dsk(k))    
         endif
         qliqw(iq,k)=qliqw(iq,k)+deltaq
        enddo  ! iq loop
       enddo   ! k loop
      elseif(methprec==9)then           ! moisten all cloud layers
!      N.B. equal "flux" of moisture into each layer, despite thickness      
       do iq=1,ifull  
        nlayers=kt_sav(iq)-kb_sav(iq)
        do k=kb_sav(iq)+1,kt_sav(iq)
         deltaq=convpsav(iq)*qxcess(iq)/(nlayers*dsk(k))       
         qliqw(iq,k)=qliqw(iq,k)+deltaq
        enddo  
       enddo   ! iq loop
      elseif(methprec==-2)then           ! moisten middle third
       do k=kuocb+1,kl-1 
        do iq=1,ifull  
         k13=nint(kb_sav(iq)+.6 +(kt_sav(iq)-kb_sav(iq))/3.)  ! up by .1
         k23=nint(kb_sav(iq)+.4 +(kt_sav(iq)-kb_sav(iq))/1.5) ! down by .1
         nlayers=k23+1-k13
         if(k>=k13.and.k<=k23)then
           deltaq=convpsav(iq)*qxcess(iq)/(nlayers*dsk(k))         
           qliqw(iq,k)=qliqw(iq,k)+deltaq
         endif
        enddo  ! iq loop
       enddo   ! k loop
      elseif(methprec==-3)then          ! moisten mostly middle third
       do k=kuocb+1,kl-1 
        do iq=1,ifull  
         sum=.25*(kt_sav(iq)-kb_sav(iq))**2
         rkmid=.5*(kt_sav(iq)+kb_sav(iq)+1)
         if(k>kb_sav(iq).and.k<=kt_sav(iq))then
           frac=kt_sav(iq)-rkmid+.5-abs(rkmid-k)
           if(abs(rkmid-k)<.1)frac=frac-.25    ! for central rkmid value
c          if(iq==idjd)print *,'k,frac ',k,frac
           deltaq=convpsav(iq)*qxcess(iq)*frac/(sum*dsk(k))         
           qliqw(iq,k)=qliqw(iq,k)+deltaq
         endif
        enddo  ! iq loop
       enddo   ! k loop
      else                    ! moisten upper layers, e.g. for 2,3,4,5
       do k=kuocb+1,kl-1 
        do iq=1,ifull  
         nlayers=max(1,nint((kt_sav(iq)-kb_sav(iq)-.1)/methprec))   ! round down
         khalf=kt_sav(iq)+1-nlayers
         if(detrainx<0..and.sig(kt_sav(iq))>.4)khalf=99 !suppr. cirr for low top
         if(k>=khalf.and.k<=kt_sav(iq))then
           deltaq=convpsav(iq)*qxcess(iq)/(nlayers*dsk(k))         
           qliqw(iq,k)=qliqw(iq,k)+deltaq
         endif
        enddo  ! iq loop
       enddo   ! k loop
      endif    ! (methprec==1)  .. else ..

      if((ntest>0.or.diag).and.mydiag)then
        iq=idjd
!       N.B. convpsav(iq) is already mult by dt jlm: mass flux is convpsav/dt
        print *,"after convection: ktau,itn,kbsav,ktsav ",
     .                 ktau,itn,kb_sav(iq),kt_sav(iq)
        write (6,"('qgc ',12f7.3/(8x,12f7.3))") 
     .             (1000.*qq(iq,k),k=1,kl)
        write (6,"('ttc ',12f7.2/(8x,12f7.2))") 
     .             (tt(iq,k),k=1,kl)
        print *,'rnrtc,fldow,qxcess ',rnrtc(iq),fldow(iq),qxcess(iq)
        print *,'rnrtcn,convpsav ',rnrtcn(iq),convpsav(iq)
        print *,'ktsav,qplume,qs_ktsav,qq_ktsav ',kt_sav(iq),
     .         qplume(iq,kb_sav(iq)),qs(iq,kt_sav(iq)),qq(iq,kt_sav(iq)) 
        iq=idjd
        delq_av=0.
        delt_av=0.
        heatlev=0.
        do k=1,kl
         delq_av=delq_av+dsk(k)*convpsav(iq)*delq(iq,k)
         delt_av=delt_av+dsk(k)*convpsav(iq)*dels(iq,k)/cp
         heatlev=heatlev+sig(k)*dsk(k)*convpsav(iq)*dels(iq,k)/cp
        enddo
        print *,'delq_av,delt_exp,rnd_exp ',
     .         delq_av,-delq_av*hl/cp,-delq_av*conrev(iq)
        if(delt_av.ne.0.)print *,'ktau,itn,kbsav,ktsav,delt_av,heatlev',
     .        ktau,itn,kb_sav(iq),kt_sav(iq),delt_av,heatlev/delt_av
      endif   ! (ntest>0.or.diag)
      
      if(nuv>0.or.nuvconv==0)go to 7
      if(nuvconv>0.and.nuvconv<100)then !  momentum calculations, original style
        do k=kl-2,1,-1
         do iq=1,ifull
          if(k==kt_sav(iq))then                 ! delu and delv for top layer
            delu(iq,k)=u(iq,kb_sav(iq))-u(iq,k)
            delv(iq,k)=v(iq,kb_sav(iq))-v(iq,k)
          elseif(k>=kb_sav(iq).and.k<kt_sav(iq))then
            delu(iq,k)=u(iq,k+1)-u(iq,k)       ! subs.
            delv(iq,k)=v(iq,k+1)-v(iq,k)       ! subs.
          endif  ! (k==kb_sav(iq))  .. else ..      
         enddo   ! iq loop
        enddo    ! k loop
      endif      ! (nuvconv>0.and.nuvconv<100)

      if(nuvconv>100.and.nuvconv<200)then   !  momentum, with downdrafts
        facuv=.1*(nuvconv-100) ! full effect for nuvconv=110
        do k=kl,1,-2
         do iq=1,ifull
          if(k==kt_sav(iq))then                 ! delu and delv for top layer
            delu(iq,k)=u(iq,kb_sav(iq))-u(iq,k)
            delv(iq,k)=v(iq,kb_sav(iq))-v(iq,k)
          elseif(k>=kdown(iq).and.k<kt_sav(iq))then
            delu(iq,k)=u(iq,k+1)-u(iq,k)       ! subs.
            delv(iq,k)=v(iq,k+1)-v(iq,k)       ! subs.
          elseif(k>kb_sav(iq).and.k<kdown(iq))then
            delu(iq,k)=(1.-fldow(iq))*(u(iq,k+1)-u(iq,k))   ! subs.
            delv(iq,k)=(1.-fldow(iq))*(v(iq,k+1)-v(iq,k))   ! subs.
          elseif(k==kb_sav(iq))then
            delu(iq,k)=(1.-fldow(iq))*u(iq,k+1)+
     .                  fldow(iq)*u(iq,kdown(iq))-u(iq,k)   ! subs.
            delv(iq,k)=(1.-fldow(iq))*v(iq,k+1)+
     .                  fldow(iq)*v(iq,kdown(iq))-v(iq,k)   ! subs.
          endif  ! (k==kb_sav(iq))  .. else ..    
         enddo   ! iq loop
        enddo    ! k loop
      endif      ! (nuvconv>100.and.nuvconv<200)

      if(nuvconv>200.and.nuvconv<300)then !  momentum, general mixing
!       this one assumes horiz. pressure gradients will be generated on parcel      
        facuv=.1*(nuvconv-200) ! full effect for nuvconv=210
        do k=1,kl-2
         do iq=1,ifull
          if(k==kt_sav(iq))then                 ! delu and delv for top layer
            delu(iq,k)=u(iq,k-1)-u(iq,k)
            delv(iq,k)=v(iq,k-1)-v(iq,k)
          elseif(k>kb_sav(iq).and.k<kt_sav(iq))then
            delu(iq,k)=u(iq,k+1)+u(iq,k-1)-2.*u(iq,k)       
            delv(iq,k)=v(iq,k+1)+v(iq,k-1)-2.*v(iq,k)      
          elseif(k==kb_sav(iq))then
            delu(iq,k)=u(iq,k+1)-u(iq,k)       
            delv(iq,k)=v(iq,k+1)-v(iq,k)      
          endif  ! (k==kb_sav(iq))  .. else ..      
         enddo   ! iq loop
        enddo    ! k loop
      endif      ! (nuvconv>200.and.nuvconv<300)

      if(nuvconv>300.and.nuvconv<400)then !  mixture of 10 & 210
!       this one assumes horiz. pressure gradients will be generated on parcel      
        facuv=.1*(nuvconv-300) ! full effect for nuvconv=310
        do k=kl,1,-2
         do iq=1,ifull
          if(k==kt_sav(iq))then                 ! delu and delv for top layer
            delu(iq,k)=.5*(u(iq,kb_sav(iq))+u(iq,k-1))-u(iq,k)
            delv(iq,k)=.5*(v(iq,kb_sav(iq))+v(iq,k-1))-v(iq,k)
          elseif(k>kb_sav(iq).and.k<kt_sav(iq))then
            delu(iq,k)=.5*(u(iq,k+1)-u(iq,k)       ! subs.
     .                    +u(iq,k+1)+u(iq,k-1)-2.*u(iq,k) )      
            delv(iq,k)=.5*(v(iq,k+1)-v(iq,k)       ! subs.
     .                    +v(iq,k+1)+v(iq,k-1)-2.*v(iq,k) )      
          elseif(k==kb_sav(iq))then
            delu(iq,k)=u(iq,k+1)-u(iq,k)       
            delv(iq,k)=v(iq,k+1)-v(iq,k)      
          endif  ! (k==kb_sav(iq))  .. else ..      
         enddo   ! iq loop
        enddo    ! k loop
      endif      ! (nuvconv>200.and.nuvconv<300)

      if(nuvconv>500.and.nuvconv<600)then   !  with extended downdrafts
        facuv=.1*(nuvconv-500) ! full effect for nuvconv=510
        do k=1,kl-2
         do iq=1,ifull
         if(kt_sav(iq)<kl-1)then
          if(k==kt_sav(iq))then                 ! delu and delv for top layer
            delu(iq,k)=u(iq,kb_sav(iq))-u(iq,k)
            delv(iq,k)=v(iq,kb_sav(iq))-v(iq,k)
          elseif(k>=kdown(iq).and.k<kt_sav(iq))then
            delu(iq,k)=u(iq,k+1)-u(iq,k)       ! subs.
            delv(iq,k)=v(iq,k+1)-v(iq,k)       ! subs.
          elseif(k>kb_sav(iq).and.k<kdown(iq))then
            delu(iq,k)=(1.-fldow(iq))*(u(iq,k+1)-u(iq,k))   ! subs.
            delv(iq,k)=(1.-fldow(iq))*(v(iq,k+1)-v(iq,k))   ! subs.
          elseif(k==kb_sav(iq))then
            delu(iq,k)=(1.-fldow(iq))*u(iq,k+1)+            ! subs.
     .                      fldow(iq)*u(iq,k-1) -u(iq,k)    ! ups.
            delv(iq,k)=(1.-fldow(iq))*v(iq,k+1)+            ! subs.
     .                      fldow(iq)*v(iq,k-1) -v(iq,k)    ! ups.
          elseif(k>1.and.k<kb_sav(iq))then
            delu(iq,k)=fldow(iq)*(u(iq,k-1)-u(iq,k))        ! ups.
            delv(iq,k)=fldow(iq)*(v(iq,k-1)-v(iq,k))        ! ups.
          elseif(k==1)then
            delu(iq,k)=fldow(iq)*(u(iq,kdown(iq))-u(iq,k))   
            delv(iq,k)=fldow(iq)*(v(iq,kdown(iq))-v(iq,k))
          endif  ! (k==kb_sav(iq))  .. else ..    
          endif   ! (kt_sav(iq)<kl-1)
         enddo   ! iq loop
        enddo    ! k loop
      endif      ! (nuvconv>500.and.nuvconv<600)

!     update u & v using actual delu and delv (i.e. divided by dsk)
7     if(nuvconv.ne.0.or.nuv>0)then
        if(ntest>0.and.mydiag)then
          print *,'u,v before convection'
          write (6,"('u  ',12f7.2/(3x,12f7.2))") u(idjd,:)
          write (6,"('v  ',12f7.2/(3x,12f7.2))") v(idjd,:)
        endif
        do k=1,kl-2   
         do iq=1,ifull
          u(iq,k)=u(iq,k)+facuv*factr(iq)*convpsav(iq)*delu(iq,k)/dsk(k)
          v(iq,k)=v(iq,k)+facuv*factr(iq)*convpsav(iq)*delv(iq,k)/dsk(k)
         enddo  ! iq loop
        enddo   ! k loop
        if(ntest>0.and.mydiag)then
          print *,'u,v after convection'
          write (6,"('u  ',12f7.2/(3x,12f7.2))") u(idjd,:)
          write (6,"('v  ',12f7.2/(3x,12f7.2))") v(idjd,:)
        endif
      endif     ! (nuvconv.ne.0)

!     section for convective transport of trace gases (jlm 22/2/01)
      if(ngas>0)then
        do ntr=1,ngas
         do k=1,kl-2
          do iq=1,ifull
           s(iq,k)=tr(iq,k,ntr)
          enddo    ! iq loop
         enddo     ! k loop
         do iq=1,ifull
          if(kt_sav(iq)<kl-1)then
            kb=kb_sav(iq)
            kt=kt_sav(iq)
            veldt=factr(iq)*convpsav(iq)*(1.-fldow(iq)) ! simple treatment
            fluxup=veldt*s(iq,kb)
!           remove gas from cloud base layer
            tr(iq,kb,ntr)=tr(iq,kb,ntr)-fluxup/dsk(kb)
!           put flux of gas into top convective layer
            tr(iq,kt,ntr)=tr(iq,kt,ntr)+fluxup/dsk(kt)
            do k=kb+1,kt
             tr(iq,k,ntr)=tr(iq,k,ntr)-s(iq,k)*veldt/dsk(k)
             tr(iq,k-1,ntr)=tr(iq,k-1,ntr)+s(iq,k)*veldt/dsk(k-1)
            enddo
          endif
         enddo   ! iq loop
        enddo    ! ntr loop    
      endif      ! (ngas>0)

      ! Convective transport of non-hydrostatic temperature correction - MJT
      if (nh.ne.0) then
        ff(:,1)=phi_nh(:,1)/bet(1)
        do k=2,kl-2
          ! representing non-hydrostatic term as a correction to air temperature
          ff(:,k)=(phi_nh(:,k)-phi_nh(:,k-1)
     &           -betm(k)*ff(1:ifull,k-1))/bet(k)
        end do
        s(:,1:kl-2)=ff(:,1:kl-2)
        do iq=1,ifull
         if(kt_sav(iq)<kl-1)then
           kb=kb_sav(iq)
           kt=kt_sav(iq)
           veldt=factr(iq)*convpsav(iq)*(1.-fldow(iq)) ! simple treatment
           fluxup=veldt*s(iq,kb)
!          remove ff from cloud base layer
           ff(iq,kb)=ff(iq,kb)-fluxup/dsk(kb)
!          put flux of ff into top convective layer
           ff(iq,kt)=ff(iq,kt)+fluxup/dsk(kt)
           do k=kb+1,kt
            ff(iq,k)=ff(iq,k)-s(iq,k)*veldt/dsk(k)
            ff(iq,k-1)=ff(iq,k-1)+s(iq,k)*veldt/dsk(k-1)
           enddo
         endif
        enddo   ! iq loop
        phi_nh(:,1)=bet(1)*ff(:,1)
        do k=2,kl-2
          phi_nh(:,k)=phi_nh(:,k-1)+bet(k)*ff(:,k)
     &                          +betm(k)*ff(:,k-1)
        end do
      end if

      ! Convective transport of TKE and eps
      if (nvmix.eq.6) then
        s(:,1:kl-2)=tke(1:ifull,1:kl-2)
        do iq=1,ifull
         if(kt_sav(iq)<kl-1)then
           kb=kb_sav(iq)
           kt=kt_sav(iq)
           veldt=factr(iq)*convpsav(iq)*(1.-fldow(iq)) ! simple treatment
           fluxup=veldt*s(iq,kb)
!          remove tke from cloud base layer
           tke(iq,kb)=tke(iq,kb)-fluxup/dsk(kb)
!          put flux of tke into top convective layer
           tke(iq,kt)=tke(iq,kt)+fluxup/dsk(kt)
           do k=kb+1,kt
            tke(iq,k)=tke(iq,k)-s(iq,k)*veldt/dsk(k)
            tke(iq,k-1)=tke(iq,k-1)+s(iq,k)*veldt/dsk(k-1)
           enddo
         endif
        enddo   ! iq loop
        s(:,1:kl-2)=eps(1:ifull,1:kl-2)
        do iq=1,ifull
         if(kt_sav(iq)<kl-1)then
           kb=kb_sav(iq)
           kt=kt_sav(iq)
           veldt=factr(iq)*convpsav(iq)*(1.-fldow(iq)) ! simple treatment
           fluxup=veldt*s(iq,kb)
!          remove eps from cloud base layer
           eps(iq,kb)=eps(iq,kb)-fluxup/dsk(kb)
!          put flux of eps into top convective layer
           eps(iq,kt)=eps(iq,kt)+fluxup/dsk(kt)
           do k=kb+1,kt
            eps(iq,k)=eps(iq,k)-s(iq,k)*veldt/dsk(k)
            eps(iq,k-1)=eps(iq,k-1)+s(iq,k)*veldt/dsk(k-1)
           enddo
         endif
        enddo   ! iq loop        
      end if

      ! Convective transport of aerosols
      if (abs(iaero)==2) then
        ! This is a simple approximation where all rain is attributed to
        ! kt_save.  However, rain is actually attributed to kt_save (qprec)
        ! kdown (fldow(iq)*qsk) and kb_sav (-fldow(iq)*qdown(iq)).
        do iq=1,ifull
          kt=min(kt_sav(iq),kl-1)
          ttsto(iq)=tt(iq,kt)
          qqsto(iq)=qq(iq,kt)
          rho(iq)=ps(iq)*sig(kt)/(rdry*ttsto(iq))
          bliqu(iq)=ttsto(iq).ge.253.16
          qqrain(iq)=qqsto(iq)+convpsav(iq)*rnrtcn(iq)
          xtgsto(iq)=xtg(iq,kt,3)
        end do
        call convscav(fscav,qqsto,qqrain,bliqu,ttsto,xtgsto,rho)
        xtusav=xtg(1:ifull,:,:) ! Outside convective cloud - fixed in aerointerface.f90
        do ntr=1,naero
          s(:,1:kl-2)=xtg(1:ifull,1:kl-2,ntr)
          do iq=1,ifull
           if(kt_sav(iq)<kl-1)then
             kb=kb_sav(iq)
             kt=kt_sav(iq)
             veldt=factr(iq)*convpsav(iq)*(1.-fldow(iq)) ! simple treatment
             fluxup=veldt*s(iq,kb)
!            remove aerosol from lower layer
             xtg(iq,kb,ntr)=xtg(iq,kb,ntr)-fluxup/dsk(kb)
!            put flux of aerosol into upper layer
             xtg(iq,kt,ntr)=xtg(iq,kt,ntr)+fluxup* 
     &                       (1.-fscav(iq,ntr))/dsk(kt)
             do k=kb+1,kt
              xtg(iq,k,ntr)=xtg(iq,k,ntr)-s(iq,k)*veldt/dsk(k)
              xtg(iq,k-1,ntr)=xtg(iq,k-1,ntr)+s(iq,k)*veldt/dsk(k-1)
             enddo
           endif
          enddo   ! iq loop
        end do
      end if
      
      if((ntest>0.or.diag).and.mydiag)then
        iq=idjd
        write (6,"('uuc ',12f6.1/(4x,12f6.1))") (u(iq,k),k=1,kl)
        write (6,"('vvc ',12f6.1/(4x,12f6.1))") (v(iq,k),k=1,kl)
      endif

      if(nmaxpr==1.and.mydiag)then
       iq=idjd
       write (6,"('ktau,itn,kb_sav,kmin,kdown,kt_sav,cfrac+,timeconv,'
     &  'rnrtcn,convpsav,cape ',i5,i3,' ]',4i3,f5.2,f6.2,2f8.5,f8.1)")
     &   ktau,itn,kb_sav(iq),kmin(iq),kdown(iq),kt_sav(iq),
     &   cfrac(iq,kb_sav(iq)+1),timeconv(iq),rnrtcn(iq),
     &   convpsav(iq),cape(iq)
       write (6,"('pblh,fldow,tdown,qdown,flux_dsk',
     &             f8.2,f5.2,f7.2,3pf7.3)")
     &             pblh(iq),fldow(iq),tdown(iq),qdown(iq),flux_dsk(iq)
       write(6,"('fluxt3p',3p14f8.3)") fluxt(iq,kb_sav(iq)+1:kt_sav(iq))
      endif
c     if(ktau<=3.and.nmaxpr==1.and.mydiag)then
      if(nmaxpr==1.and.mydiag)then
        print *,'at end of loop'
        iq=idjd
        phi(iq,1)=bet(1)*tt(iq,1)
        do k=2,kl
         phi(iq,k)=phi(iq,k-1)+bet(k)*tt(iq,k)+betm(k)*tt(iq,k-1)
        enddo      ! k  loop
        do k=1,kl   
         s(iq,k)=cp*tt(iq,k)+phi(iq,k)  ! dry static energy
        enddo   ! k loop
        write (6,"('s/cp_y',12f7.2/(5x,12f7.2))") (s(iq,k)/cp,k=1,kl)
        write (6,"('h/cp_y',12f7.2/(5x,12f7.2))") 
     .             (s(iq,k)/cp+hlcp*qq(iq,k),k=1,kl)
        sum=0.
        do k=1,kl
         sum=sum-dsig(k)*(s(iq,k)/cp+hlcp*qq(iq,k))
        enddo
        print *,'h_sumnew',sum
        sum=0.
        do k=1,kl
         sum=sum-dsig(k)*(dels(iq,k)/cp+hlcp*delq(iq,k))
        enddo
        print *,'non-scaled delh_sum   ',sum
      endif

      enddo     ! itn=1,iterconv
!-------------------------------------------------------------------      

      rnrtc(:)=factr(:)*rnrtc(:)
      do k=1,kl
      qq(1:ifull,k)=qg(1:ifull,k)+factr(:)*(qq(1:ifull,k)-qg(1:ifull,k))
      qliqw(1:ifull,k)=factr(:)*qliqw(1:ifull,k)      
      tt(1:ifull,k)= t(1:ifull,k)+factr(:)*(tt(1:ifull,k)- t(1:ifull,k))
      enddo

!     update qq, tt for evap of qliqw (qliqw arose from moistening)
      if(ldr.ne.0)then
!       Leon's stuff here, e.g.
        do k=1,kl
          do iq=1,ifullw
!          qlg(iq,k)=qlg(iq,k)+qliqw(iq,k)
           if(tt(iq,k)<253.16)then   ! i.e. -20C
             qfg(iq,k)=qfg(iq,k)+qliqw(iq,k)
             tt(iq,k)=tt(iq,k)+3.35e5*qliqw(iq,k)/cp   ! fusion heating
           else
             qlg(iq,k)=qlg(iq,k)+qliqw(iq,k)
           endif
          enddo
         enddo
      else      ! for ldr=0
        qq(1:ifull,:)=qq(1:ifull,:)+qliqw(1:ifull,:)         
        tt(1:ifull,:)=tt(1:ifull,:)-hl*qliqw(1:ifull,:)/cp   ! evaporate it
        qliqw(1:ifull,:)=0.   ! just for final diags
      endif  ! (ldr.ne.0)
!______________________end of convective calculations_____________________
     
      if((ntest>0.or.diag).and.mydiag)then
        iq=idjd
        print *,"after convection"
        write (6,"('qge ',12f7.3/(8x,12f7.3))")(1000.*qq(iq,k),k=1,kl)
        write (6,"('tte ',12f6.1/(8x,12f6.1))")(tt(iq,k),k=1,kl)
        print *,'rnrtc ',rnrtc(iq)
        delt_av=0.
        heatlev=0.
!       following calc of integ. column heatlev really needs iterconv=1  
         do k=kl-2,1,-1
          delt_av=delt_av-dsk(k)*delq(iq,k)*hlcp
          heatlev=heatlev-sig(k)*dsk(k)*delq(iq,k)*hlcp
          write (6,"('k, rh, delt_av, heatlev',i5,f7.2,2f10.2)")
     .                k,100.*qq(iq,k)/qs(iq,k),delt_av,heatlev
         enddo
         if(delt_av.ne.0.)print *,'ktau,delt_av-net,heatlev_net ',
     .                             ktau,delt_av,heatlev/delt_av
      endif
      if(ldr.ne.0)go to 8

!_______________beginning of large-scale calculations (for ldr=0)____________
!     check for grid-scale rainfall 
5     do k=1,kl   
       do iq=1,ifull
        es(iq,k)=establ(tt(iq,k))
       enddo  ! iq loop
      enddo   ! k loop
      do k=kl,1,-1    ! top down to end up with proper kbsav_ls
       do iq=1,ifull
        pk=ps(iq)*sig(k)
        qs(iq,k)=.622*es(iq,k)/max(pk-es(iq,k),1.)  
        if(qq(iq,k)>rhsat*qs(iq,k))then
          kbsav_ls(iq)=k
          gam=hlcp*qs(iq,k)*pk*hlars/(tt(iq,k)**2*max(pk-es(iq,k),1.)) 
          dqrx=(qq(iq,k)-rhsat*qs(iq,k))/(1.+rhsat*gam)
          tt(iq,k)=tt(iq,k)+hlcp*dqrx
          qq(iq,k)=qq(iq,k)-dqrx
          rnrt(iq)=rnrt(iq)+dqrx*dsk(k)
        endif   ! (qq(iq,k)>rhsat*qs(iq,k))
       enddo    ! iq loop
      enddo     ! k loop

!!!!!!!!!!!!!!!!  now do evaporation of L/S precip !!!!!!!!!!!!!!!!!!
!     conrev(iq)=1000.*ps(iq)/(grav*dt)     
      rnrt(:)=rnrt(:)*conrev(:)                 
!     here the rainfall rate rnrt has been converted to g/m**2/sec
      fluxr(:)=rnrt(:)*1.e-3*dt ! kg/m2      

      if((ntest>0.or.diag).and.mydiag)then
        iq=idjd
        print *,'after large scale rain: kbsav_ls,rnrt ',
     .                                   kbsav_ls(iq),rnrt(iq)
        write (6,"('qg ',12f7.3/(8x,12f7.3))") 
     .             (1000.*qq(iq,k),k=1,kl)
        write (6,"('tt ',12f7.2/(8x,12f7.2))") 
     .             (tt(iq,k),k=1,kl)
      endif

      if(nevapls.ne.0)then ! even newer UKMO Thu  03-05-1998
        rKa=2.4e-2
        Dva=2.21
        cfls=1. ! cld frac7 large scale
        cflscon=4560.*cfls**.3125
        do k=2*klon3,1,-1
         do iq=1,ifull
          if(k<kbsav_ls(iq))then
            rhodz=ps(iq)*dsk(k)/grav
            qpf=fluxr(iq)/rhodz     ! Mix ratio of rain which falls into layer
            pk=ps(iq)*sig(k)
c           es(iq,k)=qs(iq,k)*pk/.622
            Apr=hl*hl/(rKa*tt(iq,k)*(rvap*tt(iq,k))-1.)
            Bpr=rvap*tt(iq,k)*pk/(Dva*es(iq,k))
            Fr=fluxr(iq)/(cfls*dt)
            rhoa=pk/(rdry*tt(iq,k))
            dz=pk/(rhoa*grav)
            Vr=max(.01 , 11.3*Fr**(1./9.)/sqrt(rhoa)) ! Actual fall speed
            dtev=dz/Vr
            qr=fluxr(iq)/(dt*rhoa*Vr)
            qgdiff=qs(iq,k)-qq(iq,k)
            Cev2=cflscon*qgdiff/(qs(iq,k)*(Apr+Bpr))  ! Ignore rhoa**0.12
            qr2=max(0. , qr**.3125 - .3125*Cev2*dtev)**3.2
!           Cev=(qr-qr2)/(dtev*qgdiff)
            Cevx=(qr-qr2)/dtev  ! i.e. Cev*qgdiff
            alphal=hl*qs(iq,k)/(ars*tt(iq,k)**2)
!           bl=1.+Cev*dt*(1.+hlcp*alphal)
            blx=qgdiff+Cevx*dt*(1.+hlcp*alphal)  ! i.e. bl*qgdiff
!           evapls= cfls*dt*qgdiff*Cev/bl        ! UKMO
            evapls= cfls*dt*Cevx*qgdiff/blx      ! UKMO
            evapls=max(0. , min(evapls,qpf))
            qpf=qpf-evapls
c           if(evapls>0.)print *,'iq,k,evapls ',iq,k,evapls
            fluxr(iq)=fluxr(iq)+rhodz*qpf
            revq=evapls
            revq=min(revq , rnrt(iq)/(conrev(iq)*dsk(k)))
!           max needed for roundoff
            rnrt(iq)=max(1.e-10 , rnrt(iq)-revq*dsk(k)*conrev(iq))
            tt(iq,k)=tt(iq,k)-revq*hlcp
            qq(iq,k)=qq(iq,k)+revq
          endif   ! (k<kbsav_ls(iq))
         enddo    ! iq loop
        enddo     ! k loop
      endif       ! (nevapls==5)
!__________________end of large-scale calculations (for ldr=0)____________________


8     if(nmaxpr==1.and.mydiag)then
        iq=idjd
        print *,'Total delq (g/kg) & delt after all itns:'
        write(6,"('delQ_t',3p12f7.3/(6x,12f7.3))")
     .   (qq(iq,k)+qliqw(iq,k)-qg(iq,k),k=1,kl)
        write(6,"('delT_t',12f7.3/(6x,12f7.3))")
     .   (tt(iq,k)-t(iq,k),k=1,kl)
      endif
      qg(1:ifull,:)=qq(1:ifull,:)                   
      condc(:)=.001*dt*rnrtc(:)      ! convective precip for this timestep
      precc(:)=precc(:)+condc(:)        
      condx(:)=condc(:)+.001*dt*rnrt(:) ! total precip for this timestep
      conds(:)=0.
      precip(:)=precip(:)+condx(:)      
      t(1:ifull,:)=tt(1:ifull,:)             

      if(ntest>0.or.diag.or.(ktau<=2.and.nmaxpr==1))then
       if(mydiag)then
        print *,'at end of convjlm: rnrt,rnrtc ',rnrt(iq),rnrtc(iq)
        iq=idjd
        print *,'kdown,tdown,qdown ',kdown(iq),tdown(iq),qdown(iq)
        phi(iq,1)=bet(1)*tt(iq,1)
        do k=2,kl
         phi(iq,k)=phi(iq,k-1)+bet(k)*tt(iq,k)+betm(k)*tt(iq,k-1)
        enddo      ! k  loop
        do k=1,kl   
         es(iq,k)=establ(tt(iq,k))
         pk=ps(iq)*sig(k)
         qs(iq,k)=.622*es(iq,k)/max(pk-es(iq,k),1.)  
         s(iq,k)=cp*tt(iq,k)+phi(iq,k)  ! dry static energy
         hs(iq,k)=s(iq,k)+hl*qs(iq,k)   ! saturated moist static energy
        enddo   ! k loop
        write (6,"('rhx   ',12f7.2/(5x,12f7.2))") 
     .             (100.*qq(iq,k)/qs(iq,k),k=1,kl)
        write (6,"('qsx   ',12f7.3/(5x,12f7.3))") 
     .             (1000.*qs(iq,k),k=1,kl)
        write (6,"('qqx   ',12f7.3/(5x,12f7.3))") 
     .             (1000.*qq(iq,k),k=1,kl)
        write (6,"('ttx   ',12f7.2/(5x,12f7.2))") 
     .             (tt(iq,k),k=1,kl)
        write (6,"('s/cpx ',12f7.2/(5x,12f7.2))") (s(iq,k)/cp,k=1,kl)
        write (6,"('h/cpx ',12f7.2/(5x,12f7.2))") 
     .             (s(iq,k)/cp+hlcp*qq(iq,k),k=1,kl)
        write (6,"('hb/cpx',12f7.2/(5x,12f7.2))") 
     .             (s(iq,k)/cp+hlcp*qplume(iq,k),k=1,kl)
        write (6,"('hs/cpx',12f7.2/(5x,12f7.2))") 
     .             (hs(iq,k)/cp,k=1,kl)
        write (6,"('k  ',12i7/(3x,12i7))") (k,k=1,kl)
        print *,'following are h,q,t changes during timestep'
        write (6,"('delh ',12f7.3/(5x,12f7.3))") 
     .             (s(iq,k)/cp+hlcp*qq(iq,k)-h0(k),k=1,kl)
        write (6,"('delq ',3p12f7.3/(5x,12f7.3))") 
     .             (qq(iq,k)-q0(k),k=1,kl)
        write (6,"('delt ',12f7.3/(5x,12f7.3))") 
     .             (tt(iq,k)-t0(k),k=1,kl)
        flux_dsk=.5*dsk(kb_sav(iq))  ! may depend on nfluxdsk
        write(6,"('flux_dsk,fluxq,fluxbb,convpsav',5f8.5)")
     .           flux_dsk(iq),fluxq(iq),fluxbb(iq),convpsav(iq)
        write(6,"('fluxt',9f8.5/(5x,9f8.5))")
     .            (fluxt(iq,k),k=1,kt_sav(iq))
        pwater=0.   ! in mm     
        do k=1,kl
         pwater=pwater-dsig(k)*qg(iq,k)*ps(iq)/grav
        enddo
        print *,'pwater0,pwater+condx,pwater ',
     .           pwater0,pwater+condx(iq),pwater
        print *,'D rnrt,rnrtc,condx ',
     .             rnrt(iq),rnrtc(iq),condx(iq)
        print *,'precc,precip ',
     .           precc(iq),precip(iq)
       endif   ! (mydiag) needed here for maxmin
       call maxmin(rnrtc,'rc',ktau,1.,1)
      endif
      
      if(ntest==-1.and.nproc==1.and.ktau==10)then
        do k=1,kl
         do iq=il*il+1,2*il*il
          den1=qfg(iq,k)+qlg(iq,k)
          if(land(iq).and.den1>0.)then
            write(26,'(4f9.4,2i6)')
     &       t(iq,k),qfg(iq,k)/den1,1000.*qfg(iq,k),1000.*qlg(iq,k),iq,k
          endif
         enddo
        enddo     
      endif  ! (ntest==-1.and.nproc==1)    
      return
      end
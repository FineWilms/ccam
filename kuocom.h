      integer kbsav,ktsav,iterconv,ksc,kscmom,kscsea,kuocb,ldr,
     .        methdetr,methprec,nclddia,ncvcloud,ncvmix,ndavconv,
     .        nevapcc,nevapls,nkuo,nrhcrit,nstab_cld,nuvconv 
      real convpsav,alflnd,alfsea ,cldh_lnd,cldm_lnd,cldl_lnd,
     .     cldh_sea,cldm_sea,cldl_sea,convfact,convshr,convtime,
     .     detrain,detrainx,dsig2,dsig4,
     .     epsconv,fldown,rcrit_l,rcrit_s,rhcv,rhmois,rhsat,
     .     sigcb,sigcll,sigkscb,sig_ct,sigksct,
     .     tied_con,tied_over,tied_rh
      
      common/kuocom/
     .   kbsav(ifull),ktsav(ifull),convpsav(ifull) ! used by conjob

     .  ,alflnd       ! land-weighting ratio for cloud bases         [1.15]
     .  ,alfsea       ! sea-weighting ratio for cloud bases          [1.05]
     .  ,cldh_lnd,cldm_lnd,cldl_lnd !      for old nrhcrit=5     [95.,85.,75.]
     .  ,cldh_sea,cldm_sea,cldl_sea !      for old nrhcrit=5     [95.,90.,80.]
     .  ,convfact     ! overshooting factor for mass flux            [1.]
     .  ,convshr      ! convective shear inhibitor                   [99.]
     .  ,convtime     ! adjustment time (hrs) of cu scheme (.3?)     [0.]
     .  ,detrain      ! fraction of precip into detrainment          [.1]
     .  ,detrainx     ! fraction into detrainment for shallow clouds [1.]
     .  ,dsig2        ! delta-sigma2 for end of shallow clouds       [.1]
     .  ,dsig4        ! delta-sigma4 for start of deep clouds        [.7]
     .  ,epsconv      ! value of epsp which may be used in conjob    [0. off]
     .  ,fldown       ! fraction of convective flux into downdraft   [.6]
     .  ,iterconv     ! number of iterations in convjlm              [1]
     .  ,ksc          ! shallow convection switch (99 for Tiedtke on)[0]
     .  ,kscmom       ! shallow convection momentum switch (1 for on)[0]     
     .  ,kscsea       ! 1 for doing Tiedtke only over sea            [0]
     .  ,kuocb        ! level of min. cloud base, calc. from sigcb   [1]
     .  ,ldr          ! ldr scheme options; 0 for off                [?]
     .  ,methdetr     ! meth_shallow_detrainment for convjlm, 2 off  [2]
     .  ,methprec     ! meth_precip (deep_detrainment) for convjlm   [8]
     .  ,nclddia      ! conversion of RH to cloudiness, 0, 3, or     [5]
     .  ,ncvcloud     ! convective cloud enhancement in radrive      [0]
     .  ,ncvmix       ! cumulus mixing in vertmix                    [0]
     .  ,ndavconv     ! used by conjob & convjlm only for DARLAM     [0]
     .  ,nevapcc      ! evap scheme of convective rain               [0]
     .  ,nevapls      ! evap scheme of large-scale rain              [5]
     .  ,nkuo         ! convective scheme                            [23]
     .  ,nrhcrit      ! Hal's original 0; for jlm 7, 8               [8 ] 
     .  ,nstab_cld    ! 0 off, 3 for stability-enhanced cll          [0]
     .  ,nuvconv      ! 0 off, 1 to turn on momentum mixing          [0]
     .  ,rcrit_l      ! rcrit_land for ldr newcloud                  [.75]
     .  ,rcrit_s      ! rcrit_sea  for ldr newcloud                  [.85]
     .  ,rhcv         ! RH trigger for convective scheme             [.75]
     .  ,rhmois       ! used by conjob, convjlm for nevapcc=5        [.1]
     .  ,rhsat        ! saturation trigger for large-scale rain      [1.]
     .  ,sigcb        ! sig value for base of convection scheme      [1.]
     .  ,sigcll       ! sig value of low cloud base (for cll)        [.95]
     .  ,sig_ct       ! min sig value of cloud tops (for convjlm)    [.8]
     .  ,sigkscb      ! for tiedtke shallow convection               [.98]
     .  ,sigksct      ! for tiedtke shallow convection               [.75]
     .  ,tied_con     ! tiedtke diffsn const. e.g. 25., 20. or       [6.]
     .  ,tied_over    ! tiedtke overshooting constant                [2.]
     .  ,tied_rh      ! tiedtke RH trigger:                          [.75]

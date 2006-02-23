      integer meso,nem,ngwd,nrungcm,newtop,nhor,nhorps,                  &
     &        khor,khdif,kountr,ndiur,nrad,nvmix,nlocal,nhorjlm,         &
     &        nhstest,namip,nspecial,newrough,newsoilm,nsib,nsoil,       &
     &        ntaft,ntsea,ntsur,ntsur2,lgwd,newztsea,nglacier,           &
     &        nbd,kbotdav,kbotu,nbox,nud_p,nud_q,nud_t,nud_uv,nud_hrs,   &
     &        nudu_hrs,ktau,ndi,ndi2,ntau,nperavg,nperday,nmaxpr,nlv,    &
     &        ia,ib,ja,jb,id,jd,idjd,                                    &
     &        io_clim,io_in,io_out,io_rest,io_spec,                      &
     &        nwt,nqg,nrun,nrunx,nextout,nclim,nfly                  
      real qgmin,hdiff,hdifmax,rlong0,rlat0,schmidt,schm13,              &
     &     aleadfr,av_vmod,vmodmin,snmin,tss_sh,charnock,chn10,zobgin,   &
     &     ds,dt,dtin,timea,panfg,panzo
      logical diag, localhist,amipo3
      common/parm1/meso,nem,ngwd,nrungcm,newtop                          &
     &  ,qgmin        ! min value, esp. for stratosphere           [1.e-6]
 
      common/parmhdff/nhor,nhorps,hdiff(kl),khor,khdif,hdifmax,nhorjlm

      common/parmradn/kountr,ndiur,nrad,amipo3   

      common/parmvmix/nvmix,nlocal

      common/parmtest/nhstest,namip,nspecial

      common/parmgeom/rlong0,rlat0,schmidt,schm13

      common/parmsfce/newrough,newsoilm,nsib,nsoil,ntsea,ntsur,ntsur2,   &
     &                lgwd,newztsea,aleadfr,av_vmod,vmodmin,snmin,       &
     &                tss_sh,nglacier,charnock,chn10,zobgin,ntaft,       &
     &                panfg,panzo     

      common/parmnudg/nbd,kbotdav,kbotu,nbox,nud_p,nud_q,nud_t,nud_uv,   &
     &                nud_hrs,nudu_hrs   

      common/parmtime/ktau,ntau,nperavg,nperday,ds,dt,dtin,timea,nmaxpr, &
     &                diag,nlv,ia,ib,ja,jb,id,jd,idjd,ndi,ndi2

      common/parmio/io_clim,io_in,io_out,io_rest,io_spec,                &  ! type of I/O
     &              nwt,nqg,nrun,nrunx,nextout,nclim,nfly,localhist  


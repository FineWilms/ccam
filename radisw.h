c     common block radisw contains input quantities generated by the
c     external module and used in the longwave and/or shortwave 
c     radiation program:  
      integer ktop(imax,lp1)   ! Index of (data level) pressure of cloud top,
                               ! used in the longwave program
      integer kbtm(imax,lp1)   ! Index of (data level) pressure of cloud bottom, 
                               ! used in the longwave program 
      integer nclds(imax)      !  No. clouds at each grid pt. 
      integer ktopsw(imax,lp1) ! Index of (flux level) pressure of cloud top,
                               ! used in the shortwave program 
      integer kbtmsw(imax,lp1) ! Index of (flux level) pressure of cloud bottom,
                               ! used in the shortwave program
      real    emcld(imax,lp1)  ! Cloud emissivity. Set to one by default, but
                               ! may be modified for use in longwave program. 
      real    temp(imax,lp1)   ! Temperature (K) at data levels of model 
      real    temp2(imax,lp1)  ! Temperature (K) interpolated to half levels
      real    press(imax,lp1)  ! Pressure (CGS units) at data levels of model
      real    press2(imax,lp1) ! Pressure (CGS units) at half levels of model
      real    rh2o(imax,l)     ! Mass mixing ratio (g/g) of H2O at model 
                               ! data levels.
      real    qo3(imax,l)      ! Mass mixing ratio (g/g) of O3 at model 
                               ! data levels. 
      real    camt(imax,lp1)   ! Cloud amounts (their locations are specified 
                               ! in the ktop/kbtm indices)
      real    cuvrf(imax,lp1)  ! Reflectivity of clouds in the visible freq. 
                               ! band used in shortwave calcs. only
      real    cirrf(imax,lp1)  ! Reflectivity of clouds in the infrared freq.
                               ! band used in shortwave calcs. only
      real    cirab(imax,lp1)  ! Absorptivity of clouds in the infrared freq.
                               ! band used in shortwave calcs. only
      real    rrco2            ! Mass mixing ratio (g/g) of CO2, used in 
                               ! shortwave  calcs. only
      real    coszro(imax)     ! Zenith angle at grid pt. used in SW
      real    taudar(imax)     ! Fraction of day (or of timestep) that sun is
                               ! above  horizon. Used in shortwave calcs.
      real    ssolar           ! Solar constant (at present,in ly/min). 
                               ! May vary over one year
      real    rrvco2           ! CO2 volume mixing ratio used in SW calcs.
                               ! (This value must be the same as that used for
                               ! longwave tables). 
      common /radisw/ ktop, kbtm, nclds, ktopsw, kbtmsw, emcld, 
     &                temp, temp2, press, press2, rh2o, qo3,
     &                camt, cuvrf, cirrf, cirab, coszro, taudar
      common /radisw2/ rrco2, ssolar, rrvco2
FC = sxmpif90

# -ew is 64 bit precision (-dw for 32 bit)
# nodiv: division may not be changed to mult.
# noassume: array decl. not used to give assumed length of do loop
# loopcnt=  specifies max value of iteration count for a do loop (default 5000)
#     applies just to sflux   Needs 70000 for C200
#     applies just to sflux   Needs 180000 for C200 1 proc
#     applies just to sflux,soilsnow   40000 now OK for C200 3 proc

FFLAGS = -I /SX/local/include -Cvopt -ew -Ep -Wf"-O nodiv -pvctl noassume  -pvctl loopcnt=70000" -P stack
#use following line for 4, 16 processors
FFLAGS = -I /SX/local/include -Cvopt -ew -Ep -Wf"-O nodiv -pvctl noassume  -pvctl loopcnt=40000" -P stack -Duniform_decomp
#next one to ensure identical results for any number of processors
#            affecting tracermodule.o  cc_mpi.o    helmsol.o    sumdd_m.o  
FFLAGS = -I /SX/local/include -Cvopt -ew -Ep -Wf"-O nodiv -pvctl noassume  -pvctl loopcnt=40000" -P stack -Dsumdd
#following line is usual choice for SX6, SX8
FFLAGS = -I /SX/local/include -Cvopt -ew -Ep -Wf"-O nodiv -pvctl noassume  -pvctl loopcnt=40000" -P stack

#LIBS = -lnetcdf 
LIBS = /park/tools/SX/local/lib/libnetcdf.a  

LDFLAGS = 

OBJS = adjust5.o amipsst.o conjob.o betts.o bett_cuc.o bettinit.o \
bettrain.o bettspli.o convjlm.o depts.o esbda.o gettin.o globpe.o gwdrag.o \
hordifg.o hs_phys.o iabsdate.o indata.o infile.o ints.o helmsol.o jimcc.o\
helmsor.o optmx.o\
mslp.o nestin.o nonlin.o outcdf.o outfile.o pbldif.o radriv90.o retopo.o \
scrnout.o setxyz.o sflux.o soilsnow.o staguv.o trim.o upglobal.o eig.o \
updps.o vadv30.o vadvtvd.o vertmix.o esibda.o icefall.o leoncld.o newcloud.o \
newrain.o latltoij.o cldblk.o clddia.o cldset.o clo89.o cloud.o \
cloud2.o co2_read.o e1e288.o e3v88.o extras.o fst88.o hconst.o lwr88.o \
o3_read.o o3set.o resetd.o spa88.o swr99.o table.o zenith.o cc_mpi.o \
diag_m.o sumdd_m.o ilu_m.o davies.o utilities.o onthefly.o o3read_amip.o \
o3set_amip.o tracermodule.o timeseries.o trvmix.o ateb.o \
cable_ccam2.o cable_cbm.o cable_carbon.o cable_checks.o cable_soilsnow.o \
cable_variables.o

globpea: $(OBJS)
	$(FC) -o globpea $(FFLAGS) $(LDFLAGS) $(OBJS) $(LIBS)

clean:
	rm *.o *.mod globpea

.SUFFIXES:.f90

.f90.o:
	$(FC) -c $(FFLAGS) $<
.f.o:
	$(FC) -c $(FFLAGS) $<
infile.o:infile.f
	$(FC) -c -Cvopt  $(FFLAGS) $<

# Remove mod rule from Modula 2 so GNU make doesn't get confused
%.o : %.mod

# Dependencies
adjust5.o : adjust5.f xyzinfo.h xarrs.h vvel.h vecsuv.h vecs.h tracers.h sigs.h pbl.h parmvert.h parmdyn.h parm.h nlin.h morepbl.h map.h liqwpar.h kuocom.h indices.h const_phys.h arrays.h newmpar.h diag_m.o cc_mpi.o 
amipsst.o : amipsst.f soilsnow.h soil.h pbl.h parm.h nsibd.h map.h filnames.h dates.h arrays.h newmpar.h cc_mpi.o 
ateb.o : ateb.f90
bett_cuc.o : bett_cuc.f betts1.h newmpar.h 
bettinit.o : bettinit.f betts1.h newmpar.h 
bettrain.o : bettrain.f betts1.h newmpar.h 
betts.o : betts.f sigs.h prec.h parm.h morepbl.h betts1.h newmpar.h 
bettspli.o : bettspli.f 
cable_ccam2.o : cable_cbm.o zenith.o
cable_carbon.o : cable_variables.o
cable_cbm.o : cable_soilsnow.o cable_carbon.o
cable_checks.o : cable_cbm.o
cable_soilsnow.o : cable_variables.o
cldblk.o : cldblk.f 
cldcom.o : cldcom.f 
clddia.o : clddia.f vvel.h soil.h sigs.h pbl.h parm.h morepbl.h map.h kuocom.h davb.h const_phys.h arrays.h newmpar.h cc_mpi.o 
cldset.o : cldset.f const_phys.h 
clo89.o : clo89.f cldcom.h radisw.h rdparm.h newmpar.h 
cloud2.o : cloud2.f radisw.h hcon.h rdparm.h params.h kuocom.h cparams.h const_phys.h newmpar.h 
cloud.o : cloud.f radisw.h rdparm.h parm.h extraout.h newmpar.h 
Co2blk.o : co2blk.f 
co2dta.o : co2dta.f 
co2_read.o : co2_read.f radisw.h co2dta.h rdparm.h newmpar.h cc_mpi.o 
co2trn.o : co2trn.f 
conjob.o : conjob.f establ.h tracers.h soil.h sigs.h prec.h parm.h nlin.h morepbl.h kuocom.h dava.h const_phys.h arrays.h newmpar.h 
convjlm.o : convjlm.f establ.h vvel.h tracers.h soil.h sigs.h prec.h parm.h nlin.h morepbl.h map.h liqwpar.h latlong.h kuocom.h dava.h const_phys.h arrays.h newmpar.h diag_m.o cc_mpi.o 
davies.o : davies.f dates.h sigs.h parm.h davb.h dava.h arrays.h newmpar.h cc_mpi.o 
depts.o : depts.f bigxy4.h xyzinfo.h vecsuv.h parm.h map.h indices.h const_phys.h newmpar.h cc_mpi.o 
drive.o : drive.f 
e1e288.o : e1e288.f tfcom.h kdacom.h tabcom.h radisw.h rdparm.h hcon.h newmpar.h 
e3v88.o : e3v88.f tabcom.h rdparm.h hcon.h newmpar.h 
esbda.o : esbda.f 
esibda.o : esibda.f 
establ.o : establ.f 
extras.o : extras.f 
findij.o : findij.f newmpar.h 
findll.o : findll.f newmpar.h 
findnear.o : findnear.f 
fst88.o : fst88.f cldcom.h tfcom.h srccom.h kdacom.h lwout.h rdflux.h tabcom.h rnddta.h radisw.h rdparm.h hcon.h newmpar.h 
gettin.o : gettin.f savuvt.h arrays.h newmpar.h 
globpe.o : globpe.f mapproj.h establ.h xyzinfo.h xarrs.h vvel.h vecsuv.h trcom2.h tracers.h stime.h soilv.h soilsnow.h soil.h sigs.h screen.h scamdim.h savuvt.h raddiag.h prec.h pbl.h parmvert.h parm_nqg.h parmhor.h parmdyn.h parm.h nsibd.h nlin.h morepbl.h map.h liqwpar.h latlong.h kuocom.h indices.h histave.h filnames.h extraout.h dates.h darcdf.h const_phys.h arrays.h aalat.h newmpar.h diag_m.o cc_mpi.o tracermodule.o timeseries.o
gwdrag.o : gwdrag.f soil.h sigs.h pbl.h parm.h morepbl.h nlin.h gdrag.h const_phys.h arrays.h newmpar.h 
hconst.o : hconst.f hcon.h 
hordifg.o : hordifg.f vecsuv.h sigs.h parm.h nlin.h map.h indices.h const_phys.h arrays.h newmpar.h cc_mpi.o 
hs_phys.o : hs_phys.f sigs.h parm.h nlin.h latlong.h arrays.h newmpar.h 
iabsdate.o : iabsdate.f 
icefall.o : icefall.f params.h parm.h morepbl.h kuocom.h cparams.h const_phys.h newmpar.h cc_mpi.o
indata.o : indata.f vecsuv.h xyzinfo.h vecs.h trcom2.h tracers.h stime.h soilv.h soilsnow.h soil.h sigs.h prec.h permsurf.h pbl.h parm_nqg.h parmdyn.h parm.h nsibd.h morepbl.h map.h liqwpar.h latlong.h indices.h gdrag.h filnames.h dava.h dates.h const_phys.h arrays.h aalat.h newmpar.h diag_m.o cc_mpi.o tracermodule.o timeseries.o ateb.o cable_ccam2.o
infile.o : infile.f sigs.h tracers.h stime.h parm_nqg.h parm.h liqwpar.h kuocom.h darcdf.h newmpar.h diag_m.o cc_mpi.o 
int2.o : int2.f newmpar.h 
ints.o : ints.f indices.h parmhor.h parm.h newmpar.h cc_mpi.o 
jimcc.o : jimcc.f bigxy4.h parm.h newmpar_gx.h 
latltoij.o : latltoij.f parmdyn.h parm.h const_phys.h bigxy4.h newmpar.h utilities.o 
leoncld.o : leoncld.f establ.h vvel.h tracers.h soil.h sigs.h prec.h parm.h nlin.h morepbl.h map.h latlong.h kuocom.h dava.h arrays.h cparams.h const_phys.h liqwpar.h newmpar.h cc_mpi.o diag_m.o 
lwr88.o : lwr88.f tfcom.h rnddta.h kdacom.h co2dta.h radisw.h rdparm.h parm.h hcon.h newmpar.h 
mslp.o : mslp.f sigs.h parm.h const_phys.h newmpar.h cc_mpi.o 
mtimerget.o : mtimerget.f 
nestin.o : nestin.f stime.h soilsnow.h soil.h sigs.h pbl.h parm.h map.h davb.h dava.h dates.h const_phys.h arrays.h aalat.h newmpar.h diag_m.o cc_mpi.o 
newcloud.o : newcloud.f sigs.h parm.h params.h kuocom.h cparams.h const_phys.h newmpar.h 
newrain.o : newrain.f params.h morepbl.h kuocom.h cparams.h const_phys.h newmpar.h 
nonlin.o : nonlin.f xyzinfo.h xarrs.h vvel.h vecsuv.h tracers.h sigs.h savuvt.h parmvert.h parmdyn.h parm.h nlin.h morepbl.h map.h latlong.h liqwpar.h kuocom.h indices.h const_phys.h arrays.h newmpar.h diag_m.o cc_mpi.o 
o3_read.o : o3_read.f newmpar.h 
o3set.o : o3set.f const_phys.h newmpar.h 
onthefly.o : onthefly.f indices.h indices_g.h xyzinfo_g.h vvel.h vecsuv_g.h tracers.h stime.h sigs.h parm_nqg.h parm.h map.h latlong.h const_phys.h bigxy4.h newmpar.h utilities.o cc_mpi.o 
outcdf.o : outcdf.f vvel.h version.h trcom2.h soilv.h soilsnow.h soil.h sigs.h screen.h scamdim.h raddiag.h prec.h pbl.h nsibd.h morepbl.h mapproj.h map.h histave.h extraout.h arrays.h aalat.h tracers.h parmvert.h parmhor.h parmdyn.h parm.h liqwpar.h kuocom.h filnames.h dates.h darcdf.h newmpar.h cc_mpi.o ateb.o
outfile.o : outfile.f vvel.h tracers.h soilsnow.h soilv.h soil.h sigs.h screen.h scamdim.h prec.h pbl.h parmvert.h parmdyn.h parm.h nsibd.h nlin.h morepbl.h map.h kuocom.h histave.h filnames.h extraout.h dava.h dates.h darcdf.h arrays.h aalat.h newmpar.h cc_mpi.o 
pbldif.o : pbldif.f map.h sigs.h parm.h morepbl.h kuocom.h extraout.h const_phys.h arrays.h newmpar.h 
radriv90.o : radriv90.f establ.h tfcom.h swocom.h srccom.h rdflux.h raddiag.h radisw.h lwout.h hcon.h cldcom.h rdparm.h soilv.h soilsnow.h soil.h sigs.h scamdim.h pbl.h parm.h nsibd.h map.h liqwpar.h latlong.h kuocom.h extraout.h dates.h cparams.h const_phys.h arrays.h aalat.h newmpar.h zenith.o swr99.o ateb.o
rdparm.o : rdparm.f 
read_ht.o : read_ht.f 
resetd.o : resetd.f 
retopo.o : retopo.f sigs.h parm.h const_phys.h newmpar.h cc_mpi.o 
rnddta.o : rnddta.f 
scamrdn.o : scamrdn.f soilv.h soilsnow.h soil.h sigs.h scamdim.h pbl.h parm.h nsibd.h filnames.h const_phys.h arrays.h newmpar.h 
scrnout.o : scrnout.f establ.h soilsnow.h soil.h sigs.h scamdim.h prec.h pbl.h parm.h nsibd.h map.h liqwpar.h const_phys.h arrays.h newmpar.h diag_m.o cc_mpi.o morepbl.h
setxyz.o : setxyz.f bigxy4.h indices_gx.h vecsuv_gx.h xyzinfo_gx.h parm.h map_gx.h latlong_gx.h const_phys.h newmpar_gx.h utilities.o 
sflux.o : sflux.f latlong.h dates.h establ.h vvel.h trcom2.h tracers.h soilsnow.h soilv.h soil.h sigs.h screen.h scamdim.h savuvt.h prec.h permsurf.h pbl.h parm.h nsibd.h morepbl.h map.h liqwpar.h gdrag.h extraout.h const_phys.h arrays.h newmpar.h cc_mpi.o diag_m.o ateb.o cable_ccam2.o
soilsnow.o : soilsnow.f nlin.h soil.h sigs.h arrays.h morepbl.h nsibd.h soilv.h soilsnow.h permsurf.h parm.h const_phys.h newmpar.h diag_m.o cc_mpi.o 
solargh.o : solargh.f 
spa88.o : spa88.f lwout.h cldcom.h tfcom.h kdacom.h srccom.h rdflux.h rnddta.h radisw.h rdparm.h hcon.h newmpar.h 
srccom.o : srccom.f 
sscam2.o : sscam2.f soilv.h soilsnow.h scamdim.h parm.h newmpar.h 
staguv.o : staguv.f vecsuv.h parmdyn.h parm.h map.h indices.h newmpar.h cc_mpi.o 
swr99.o : swr99.f rdparm.h hcon.h newmpar.h 
table.o : table.f tabcom.h radisw.h hcon.h rnddta.h rdparm.h newmpar.h 
trim.o : trim.f newmpar.h 
updps.o : updps.f xarrs.h vvel.h sigs.h parmdyn.h parm.h parmhor.h savuvt.h nlin.h map.h indices.h const_phys.h arrays.h newmpar.h cc_mpi.o 
upglobal.o : upglobal.f xyzinfo.h xarrs.h vvel.h vecsuv.h tracers.h sigs.h parmvert.h parmhor.h parmdyn.h parm.h nlin.h map.h liqwpar.h kuocom.h indices.h const_phys.h arrays.h newmpar.h diag_m.o cc_mpi.o 
vadv30.o : vadv30.f xarrs.h vvel.h tracers.h sigs.h parmvert.h parmdyn.h parm.h map.h liqwpar.h kuocom.h indices.h arrays.h newmpar.h cc_mpi.o 
vadvtvd.o : vadvtvd.f xarrs.h vvel.h tracers.h sigs.h parmvert.h parmdyn.h parm.h map.h liqwpar.h kuocom.h arrays.h newmpar.h cc_mpi.o 
vertmix.o : vertmix.f nsibd.h establ.h tracers.h soil.h sigs.h savuvt.h permsurf.h screen.h pbl.h parm.h morepbl.h nlin.h map.h liqwpar.h kuocom.h indices.h dates.h const_phys.h arrays.h newmpar.h diag_m.o cc_mpi.o trvmix.o
cc_mpi.o : cc_mpi.f90 sigs.h newmpar_gx.h parm.h indices_g.h indices.h latlong_g.h latlong.h vecsuv_g.h vecsuv.h map_g.h map.h xyzinfo_g.h xyzinfo.h newmpar.h sumdd_m.o 
diag_m.o : diag_m.f90 parm.h xyzinfo.h sigs.h newmpar.h cc_mpi.o 
helmsol.o : helmsol.f90 parmdyn.h parm.h indices.h newmpar.h sumdd_m.o ilu_m.o cc_mpi.o 
helmsor.o : helmsor.f parmdyn.h parm.h indices.h newmpar.h cc_mpi.o 
ilu_m.o : ilu_m.f90 indices.h newmpar.h cc_mpi.o 
mpidummy.o : mpidummy.f90 
sumdd_m.o : sumdd_m.f90 
utilities.o : utilities.f90 const_phys.h 
zenith.o : zenith.f90 
tracermodule.o: tracermodule.f newmpar.h tracers.h parm.h const_phys.h arrays.h sigs.h xyzinfo.h
timeseries.o: timeseries.f dates.h newmpar.h tracers.h extraout.h arrays.h soil.h prec.h vvel.h pbl.h morepbl.h soilsnow.h nsibd.h sigs.h tracermodule.o
trvmix.o: trvmix.f newmpar.h const_phys.h parm.h sigs.h tracers.h arrays.h tracermodule.o
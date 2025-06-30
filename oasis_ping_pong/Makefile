#
include $(OASIS_COUPLE)/util/make_dir/make.inc
LIBPSMILE = $(ARCHDIR)/lib/libpsmile.${CHAN}.a $(ARCHDIR)/lib/libmct.a $(ARCHDIR)/lib/libmpeu.a $(ARCHDIR)/lib/libscrip.a $(ARCHDIR)/lib/libyac_core.a $(ARCHDIR)/lib/libyac_utils.a $(ARCHDIR)/lib/libyaxt_c.a $(ARCHDIR)/lib/libyaxt.a 
#
##### User configurable options #####
#
# CPP keys for type of decomposition for ocean (_M1) and for atmos (_M2)
# DECOMP_APPLE for 1D decomposition, DECOMP_BOX for 2D decomposition
CPPKEYDECOMP_M1=DECOMP_APPLE
CPPKEYDECOMP_M2=DECOMP_APPLE
CPPKEYDECOMP_M3=DECOMP_APPLE
#
### End User configurable options ###
#
CPPLOCAL_M1 =  -D${CPPKEYDECOMP_M1}
CPPLOCAL_M2 = -D${CPPKEYDECOMP_M2}
CPPLOCAL_M3 = -D${CPPKEYDECOMP_M3}
#
OBJ_M1 =  read_grid.o def_parallel_decomposition.o
OBJ_M2 =  read_grid.o def_parallel_decomposition_m2.o
OBJ_M3 =  read_grid.o def_parallel_decomposition_m2.o
#-------------------------------------------------------------------------------
# General rules
#-------------------------------------------------------------------------------
#
default: all
#
all: oasis3_psmile ocean atmos 
#
# Compile and link libaries
oasis3_psmile:
	(cd $(OASIS_COUPLE)/util/make_dir ; $(MAKE) oasis3_psmile -f TopMakefileOasis3)
#
#
#-------------------------------------------------------------------------------
# Rules for executables
#-------------------------------------------------------------------------------
#
ocean: $(OBJ_M1) ocean.o $(LIBPSMILE) Makefile
	$(LD) $(LDFLAGS) -o $@ $(OBJ_M1) ocean.o $(LIBPSMILE) $(FLIBS) $(NETCDF_LIBRARY) -g
atmos: $(OBJ_M2) atmos.o $(LIBPSMILE) Makefile
	$(LD) $(LDFLAGS) -o $@ $(OBJ_M2) atmos.o $(LIBPSMILE) $(FLIBS) $(NETCDF_LIBRARY)
oasis_ping_pong: $(OBJ_M3) oasis_ping_pong.o $(LIBPSMILE) Makefile
	$(LD) $(LDFLAGS) -o $@ $(OBJ_M3) oasis_ping_pong.o $(LIBPSMILE) $(FLIBS) $(NETCDF_LIBRARY)
#
#-------------------------------------------------------------------------------
# Rules for compilation
#-------------------------------------------------------------------------------
#
read_grid.o :		read_grid.F90
				$(F90) $(F90FLAGS) -c read_grid.F90
def_parallel_decomposition.o : 		def_parallel_decomposition.F90
				$(F90) $(F90FLAGS) $(CPPLOCAL_M1) -c def_parallel_decomposition.F90
def_parallel_decomposition_m2.o : 	def_parallel_decomposition.F90
				$(F90) $(F90FLAGS) $(CPPLOCAL_M2) -o def_parallel_decomposition_m2.o -c def_parallel_decomposition.F90
ocean.o :	ocean.F90 Makefile
		$(F90) $(F90FLAGS) $(CPPLOCAL_M1) -c ocean.F90 -g
atmos.o :	atmos.F90 Makefile
		$(F90) $(F90FLAGS) $(CPPLOCAL_M2) -c atmos.F90

oasis_ping_pong.o :	oasis_ping_pong.F90 Makefile
		$(F90) $(F90FLAGS) $(CPPLOCAL_M3) -c oasis_ping_pong.F90
#
#-------------------------------------------------------------------------------
# Utilities
#-------------------------------------------------------------------------------
#
help:
	more Make.help
#
# Clean directory
#
clean:
	-rm -f *.o *.mod *.MOD ocean atmos oasis_ping_pong
	-rm -f i.*.F90 *.L
	-rm -f core core.* 
#
# Make sure to recompile everything
#
realclean: clean remove
remove:
	(cd $(OASIS_COUPLE)/util/make_dir ; $(MAKE) realclean -f TopMakefileOasis3)

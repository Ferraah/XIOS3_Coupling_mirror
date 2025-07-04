include $(OASIS_COUPLE)/util/make_dir/make.inc

LIBPSMILE = $(ARCHDIR)/lib/libpsmile.${CHAN}.a $(ARCHDIR)/lib/libmct.a $(ARCHDIR)/lib/libmpeu.a $(ARCHDIR)/lib/libscrip.a $(ARCHDIR)/lib/libyac_core.a $(ARCHDIR)/lib/libyac_utils.a $(ARCHDIR)/lib/libyaxt_c.a $(ARCHDIR)/lib/libyaxt.a
OBJ = read_grid.o def_parallel_decomposition.o

default: all

all: oasis_ping_pong.exe 

oasis_ping_pong.exe: $(OBJ) oasis_ping_pong.o $(LIBPSMILE) Makefile
	$(LD) $(LDFLAGS) -o $@ $(OBJ) oasis_ping_pong.o $(LIBPSMILE) $(FLIBS) $(NETCDF_LIBRARY)

read_grid.o: read_grid.F90
	$(F90) $(F90FLAGS) -c read_grid.F90

def_parallel_decomposition.o: def_parallel_decomposition.F90
	$(F90) $(F90FLAGS) $(CPPLOCAL_M1) -c def_parallel_decomposition.F90

def_parallel_decomposition_m2.o: def_parallel_decomposition.F90
	$(F90) $(F90FLAGS) $(CPPLOCAL_M2) -o def_parallel_decomposition_m2.o -c def_parallel_decomposition.F90

oasis_ping_pong.o: oasis_ping_pong.F90 Makefile
	$(F90) $(F90FLAGS) $(CPPLOCAL_M3) -c oasis_ping_pong.F90

clean:
	-rm -f *.o *.mod *.MOD oasis_ping_pong
	-rm -f i.*.F90 *.L
	-rm -f core core.*

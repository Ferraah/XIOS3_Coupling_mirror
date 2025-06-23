# Compiler and flags
FC = mpiifort
FFLAGS = -g -O0 -fpp 
INCLUDES = -I/scratch/globc/ferrario/XIOS3-trunk-r2754/build_ifort_CERFACS_debug/inc \
		   -I/softs/local_intel/netcdf/4.4.4_phdf5_1.10.4/include \
		   -I/scratch/globc/ferrario/trunk/extern/boost_extraction/include \
		   -I/scratch/globc/ferrario/trunk/extern/blitz
DEFINES = -D__NONE__

# Libraries and paths
LIBS = -L/scratch/globc/ferrario/XIOS3-trunk-r2754/build_ifort_CERFACS_debug/lib \
	   -L/softs/local_intel/netcdf/4.4.4_phdf5_1.10.4/lib \
	   -L/softs/local_intel/phdf5/1.10.4_impi/lib \
	   -lnetcdff -lnetcdf -lhdf5_hl -lhdf5 -lxios -lstdc++

# Source files and objects
COMMON_SRC = grids_utils.F90 field_initializer.F90
OCEAN_SRC = ocean.F90
ATMOS_SRC = atmos.F90
SINGLE_SRC = 12_ping_pong.F90

OCEAN_OBJ = $(COMMON_SRC:.F90=.o) $(OCEAN_SRC:.F90=.o)
ATMOS_OBJ = $(COMMON_SRC:.F90=.o) $(ATMOS_SRC:.F90=.o)
SINGLE_OBJ = $(COMMON_SRC:.F90=.o) $(SINGLE_SRC:.F90=.o)

# Executable names
OCEAN_EXEC = ocean.exe
ATMOS_EXEC = atmos.exe
SINGLE_EXEC = 12_ping_pong.exe

# Rules
all: $(OCEAN_EXEC) $(ATMOS_EXEC)
single: $(SINGLE_EXEC)

$(OCEAN_EXEC): $(OCEAN_OBJ)
	$(FC) $(FFLAGS) -o $@ $^ $(LIBS) $(DEFINES)

$(ATMOS_EXEC): $(ATMOS_OBJ)
	$(FC) $(FFLAGS) -o $@ $^ $(LIBS) $(DEFINES)

$(SINGLE_EXEC): $(SINGLE_OBJ)
	$(FC) $(FFLAGS) -o $@ $^ $(LIBS) $(DEFINES)

%.o: %.F90
	$(FC) $(FFLAGS) $(INCLUDES) $(DEFINES) -c $< -o $@

clean:
	rm -f *.o *.mod $(OCEAN_EXEC) $(ATMOS_EXEC)

.PHONY: all clean
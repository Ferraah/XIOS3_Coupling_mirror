# Compiler and flags
FC = mpiifort
FFLAGS = -g -O0
INCLUDES = -I/scratch/globc/ferrario/trunk/build_ifort_CERFACS_debug/inc \
		   -I/softs/local_intel/netcdf/4.4.4_phdf5_1.10.4/include \
		   -I/scratch/globc/ferrario/trunk/extern/boost_extraction/include \
		   -I/scratch/globc/ferrario/trunk/extern/blitz

# Libraries and paths
LIBS = -L/scratch/globc/ferrario/trunk/build_ifort_CERFACS_debug/lib \
	   -L/softs/local_intel/netcdf/4.4.4_phdf5_1.10.4/lib \
	   -L/softs/local_intel/phdf5/1.10.4_impi/lib \
	   -lnetcdff -lnetcdf -lhdf5_hl -lhdf5 -lxios -lstdc++

# Source files and objects
SRC = 6_points.f90
OBJ = $(SRC:.f90=.o)

# Executable name
EXEC = 6_points.exe

# Rules
all: $(EXEC)

$(EXEC): $(OBJ)
	$(FC) $(FFLAGS) -o $@ $^ $(LIBS)

%.o: %.f90
	$(FC) $(FFLAGS) $(INCLUDES) $(DEFINES) -c $< -o $@

clean:
	rm -f $(OBJ) $(EXEC)

.PHONY: all clean
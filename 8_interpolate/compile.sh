#module purge
#module load compiler/intel/23.2.1
#module load mpi/intelmpi/2021.10.0
#module load lib/phdf5/1.10.4_impi
#module load lib/netcdf-fortran/4.4.4_phdf5_1.10.4


# Explicitly compile grids_utils.f90
mpiifort -o grids_utils.o \
    -I/scratch/globc/ferrario/trunk/build_ifort_CERFACS_debug/inc \
    -I/softs/local_intel/netcdf/4.4.4_phdf5_1.10.4/include \
    -I/scratch/globc/ferrario/trunk/extern/boost_extraction/include \
    -I/scratch/globc/ferrario/trunk/extern/blitz \
    -D__NONE__ -g -O0 \
    -c grids_utils.f90

mpiifort -o 8_interpolate.o \
    -I/scratch/globc/ferrario/trunk/build_ifort_CERFACS_debug/inc \
    -I/softs/local_intel/netcdf/4.4.4_phdf5_1.10.4/include \
    -I/scratch/globc/ferrario/trunk/extern/boost_extraction/include \
    -I/scratch/globc/ferrario/trunk/extern/blitz \
    -D__NONE__ -g -O0 \
    -c 8_interpolate.f90


# Add grids_utils.o to object_files
object_files="8_interpolate.o grids_utils.o"

executable_file="8_interpolate.exe"
mpiifort -g -O0 -o ${executable_file} ${object_files} \
    -L/scratch/globc/ferrario/trunk/build_ifort_CERFACS_debug/lib \
    -L/softs/local_intel/netcdf/4.4.4_phdf5_1.10.4/lib \
    -L/softs/local_intel/phdf5/1.10.4_impi/lib \
    -lnetcdff -lnetcdf -lhdf5_hl -lhdf5 -lxios -lstdc++

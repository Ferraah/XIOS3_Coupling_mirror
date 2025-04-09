#module purge
#module load compiler/intel/23.2.1
#module load mpi/intelmpi/2021.10.0
#module load lib/phdf5/1.10.4_impi
#module load lib/netcdf-fortran/4.4.4_phdf5_1.10.4

for f90_file in $(find . -maxdepth 1 -name "*.f90"); do
    object_file="${f90_file%.f90}.o"
    executable_file="${f90_file%.f90}.exe"

    mpiifort -o ${object_file} \
        -I/scratch/globc/ferrario/last_trunk/build_ifort_CERFACS_prod/inc \
        -I/softs/local_intel/netcdf/4.4.4_phdf5_1.10.4/include \
        -I/scratch/globc/ferrario/trunk/extern/boost_extraction/include \
        -I/scratch/globc/ferrario/trunk/extern/blitz \
        -D__NONE__ -g -O0 \
        -c ${f90_file}

    mpiifort -g -O0 -o ${executable_file} ${object_file} -L/scratch/globc/ferrario/last_trunk/build_ifort_CERFACS_prod/lib -L/softs/local_intel/netcdf/4.4.4_phdf5_1.10.4/lib -L/softs/local_intel/phdf5/1.10.4_impi/lib -lnetcdff -lnetcdf -lhdf5_hl -lhdf5 -lxios -lstdc++
done

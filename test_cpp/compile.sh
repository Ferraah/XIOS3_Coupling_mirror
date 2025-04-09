# module purge
# module load compiler/intel/23.2.1
# module load mpi/intelmpi/2021.10.0
# module load lib/phdf5/1.10.4_impi
# module load lib/netcdf-fortran/4.4.4_phdf5_1.10.4
# module load tools/automake/1.16.1
# module load lib/hwloc/2.1.0

for cpp_file in $(find . -maxdepth 1 -name "*.cpp"); do
    object_file="${cpp_file%.cpp}.o"
    executable_file="${cpp_file%.cpp}.exe"

    # Compile the .cpp file into an object file
    mpicc -c ${cpp_file} -o ${object_file} \
        -I/scratch/globc/ferrario/trunk/build_ifort_CERFACS_debug/inc \
        -I/softs/local_intel/netcdf/4.4.4_phdf5_1.10.4/include \
        -I/scratch/globc/ferrario/trunk/extern/boost_extraction/include \
        -I/scratch/globc/ferrario/trunk/extern/blitz/ \
        -I/scratch/globc/ferrario/trunk/extern/rapidxml/include \
        -I/scratch/globc/ferrario/oasis3-mct/INSTALL_OASIS.kraken_intel23.2.1_intelmpi2021.10.0/include 

    # Link the object file into an executable
    mpicc -o ${executable_file} ${object_file} \
        -L/scratch/globc/ferrario/trunk/build_ifort_CERFACS_debug/lib \
        -L/softs/local_intel/netcdf/4.4.4_phdf5_1.10.4/lib \
        -L/softs/local_intel/phdf5/1.10.4_impi/lib \
        -L/scratch/globc/ferrario/oasis3-mct/INSTALL_OASIS.kraken_intel23.2.1_intelmpi2021.10.0/lib \
        -L/softs/intel/oneapi/compiler/2023.2.1/linux/compiler/lib \
        -lnetcdff -lnetcdf -lhdf5_hl -lhdf5 -lxios -lstdc++  
done
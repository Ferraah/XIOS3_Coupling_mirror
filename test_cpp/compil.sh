#!/bin/bash
export XIOS_HOME=/scratch/globc/ferrario/last_trunk
export XIOS_BUILD=${XIOS_HOME}/build_ifort_CERFACS_prod
mpicxx -g -O0 -w -std=c++11 -c personal.cpp -I./ -I${XIOS_BUILD}/inc -I${XIOS_HOME}/extern/boost_extraction/include -I${XIOS_HOME}/extern/blitz -I${XIOS_HOME}/extern/rapidxml/include/ -I/softs/local_intel/netcdf/4.4.4_phdf5_1.10.4/include
mpicxx -g -O0 -o personal personal.o  -L/scratch/globc/ferrario/last_trunk/build_ifort_CERFACS_prod/lib -L/softs/local_intel/netcdf/4.4.4_phdf5_1.10.4/lib -L/softs/local_intel/phdf5/1.10.4_impi/lib -L${OASIS3_INSTALL}/lib  -L/softs/intel/oneapi/compiler/2023.2.1/linux/compiler/lib/intel64_lin/ -lnetcdff -lnetcdf -lxios -lifcoremt -limf -lsvml -lintlc

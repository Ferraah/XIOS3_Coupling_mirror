#!/bin/bash
export XIOS_HOME=/scratch/globc/ferrario/last_trunk
export XIOS_BUILD=${XIOS_HOME}/build_ifort_CERFACS_prod
mpicxx -w -std=c++11 -c test_tp3.cpp -I./ -I${XIOS_BUILD}/inc -I${XIOS_HOME}/extern/boost_extraction/include -I${XIOS_HOME}/extern/blitz -I${XIOS_HOME}/extern/rapidxml/include/
mpicxx -o test_cpp test_tp3.o  -L/scratch/globc/ferrario/last_trunk/build_ifort_CERFACS_prod/lib -L/softs/local_intel/netcdf/4.4.4_phdf5_1.10.4/lib -L/softs/local_intel/phdf5/1.10.4_impi/lib -L${OASIS3_INSTALL}/lib  -lnetcdff -lnetcdf -lgfortran  -lxios 

#!/bin/ksh
coupler=OASIS # XIOS or OASIS
echo ${coupler}
# Compilation
cp makefile_${coupler} makefile
make clean ; make
\rm -rf work_toy_${coupler} ; mkdir work_toy_${coupler}
mv toy_retraite.exe work_toy_${coupler}/.
cp data_toy/restart.nc work_toy_${coupler}/.
if [ ${coupler} == "XIOS" ]; then
	cp data_toy/iodef.xml work_toy_${coupler}/.
elif [ ${coupler} == "OASIS" ]; then
	cp data_toy/namcouple work_toy_${coupler}/.
	cp data_toy/rmp_grdo_to_grda.nc work_toy_${coupler}/.
fi
cd work_toy_${coupler}
mpirun -np 2 ./toy_retraite.exe

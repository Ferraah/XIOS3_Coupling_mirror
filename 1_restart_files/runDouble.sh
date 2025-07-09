
cp original_data/iodef_1.xml iodef.xml
cp original_data/restart_zerofield.nc restart.nc
cp original_data/restart_zerofield.nc restart_next.nc

# Runs
mpirun -np 2 ./1_cpl_time_params.exe

# The next run will use the restart file
cp restart_next.nc restart.nc
cp original_data/iodef_2.xml iodef.xml

mpirun -np 2 ./1_cpl_time_params.exe
cp restart_next.nc restart.nc

ncdump restart.nc
echo "Completed runDouble.sh"


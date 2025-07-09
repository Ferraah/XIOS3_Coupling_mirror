
cp original_data/iodef_3.xml iodef.xml
cp original_data/restart_zerofield.nc restart.nc
cp original_data/restart_zerofield.nc restart_next.nc

# Runs
mpirun -np 2 ./1_cpl_time_params.exe

# Set back to the original iodef file
ncdump restart_next.nc
echo "Completed runSingle.sh"


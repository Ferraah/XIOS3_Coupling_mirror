cp original_data/restart_zerofield.nc restart.nc
cp original_data/restart_zerofield.nc restart_next.nc
cp original_data/iodef_intro.xml iodef.xml

# Set the iodef file 
mpirun -np 2 ./1_cpl_time_params.exe
ncdump restart_next.nc
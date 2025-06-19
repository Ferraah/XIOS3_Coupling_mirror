cp original_data/grids_low.nc grids.nc
cp original_data/masks_low.nc masks.nc
cp original_data/namcouple_low namcouple
make ocean atmos
time mpirun -np 16 ./ocean : -np 16 ./atmos
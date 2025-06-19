cp original_data/grids_high.nc grids.nc
cp original_data/masks_high.nc masks.nc
cp original_data/namcouple_high namcouple
cp original_data/rmp_t12e_to_icoh_YAC_CONSERV2_A.nc .
cp original_data/rmp_icoh_to_t12e_YAC_CONSERV2_B.nc .
make ocean atmos
time mpirun -np 16 ./ocean : -np 16 ./atmos
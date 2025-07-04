cp original_data/grids_high.nc grids.nc
cp original_data/masks_high.nc masks.nc
cp original_data/namcouple_high namcouple
cp original_data/rmp_t12e_to_icoh_YAC_CONSERV2_A.nc .
cp original_data/rmp_icoh_to_t12e_YAC_CONSERV2_B.nc .
make oasis_ping_pong
time mpirun -np 4 ./oasis_ping_pong ocean_component t12e LR : -np 4 ./oasis_ping_pong atmos_component icoh U
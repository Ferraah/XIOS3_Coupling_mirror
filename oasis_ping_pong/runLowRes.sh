cp original_data/grids_low.nc grids.nc
cp original_data/masks_low.nc masks.nc
cp original_data/namcouple_low namcouple
make oasis_ping_pong 
time mpirun -np 16 ./oasis_ping_pong ocean_component torc LR : -np 16 ./oasis_ping_pong atmos_component lmdz LR
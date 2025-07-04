#!/bin/bash
#SBATCH --job-name=bench_n32_m32
#SBATCH --output=results/out_n32_m32.txt
#SBATCH --error=results/err_n32_m32.txt
#SBATCH --ntasks=64
#SBATCH --time=01:00:00
#SBATCH --partition=bench

module load mpi
module load tools/nco/4.7.6
module load compiler/gcc/11.2.0
module load compiler/intel/23.2.1
module load mpi/intelmpi/2021.10.0
module load lib/netcdf-fortran/4.4.4_phdf5_1.10.4

cd /scratch/globc/ferrario/xios_experiments/benchmarks/oasis

make 

# Folder already created
RUN_DIR="run_32_32"

cp original_data/grids_high.nc "$RUN_DIR/grids.nc"
cp original_data/masks_high.nc "$RUN_DIR/masks.nc"
cp original_data/namcouple_high "$RUN_DIR/namcouple"
#cp oasis_ping_pong "$RUN_DIR/"
#cp -r outputs "$RUN_DIR/" 2>/dev/null || mkdir "$RUN_DIR/outputs"

cd "$RUN_DIR"

if [[ "$1" == "true" ]]; then
    echo "Interpolation is enabled, removing remapping files."
    ls rmp_* 1>/dev/null 2>&1 && rm rmp_*
else
    echo "Interpolation is disabled, copying remapping files."
    [[ -f rmp_t12e_to_icoh_oce_to_atm.nc ]] || cp ../original_data/rmp_t12e_to_icoh_oce_to_atm.nc .
    [[ -f rmp_icoh_to_t12e_atm_to_oce.nc ]] || cp ../original_data/rmp_icoh_to_t12e_atm_to_oce.nc .
fi

echo "Running the ping-pong test with N=32 and M=32"
mpirun -np 32 ../oasis_ping_pong.exe ocean_component t12e LR : -np 32 ../oasis_ping_pong.exe atmos_component icoh U > ../outputs/ocean_times_n32_m32.txt
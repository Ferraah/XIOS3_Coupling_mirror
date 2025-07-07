#!/bin/bash
#SBATCH --job-name=bench_n256_m256
#SBATCH --output=../oasis/results_interp/out_n256_m256.txt
#SBATCH --error=../oasis/results_interp/err_n256_m256.txt
#SBATCH --ntasks=512
#SBATCH --time=06:00:00
#SBATCH --partition=bench
#SBATCH --exclusive
#SBATCH --mem=90G 

module load tools/nco/4.7.6
module load compiler/gcc/11.2.0
module load compiler/intel/23.2.1
module load mpi/intelmpi/2021.10.0
module load lib/netcdf-fortran/4.4.4_phdf5_1.10.4

cd /scratch/globc/ferrario/xios_experiments/benchmarks/oasis

make

# Folder already created
RUN_DIR="run_256_256_interp"

cd "$RUN_DIR"

cp ../original_data/grids_high.nc grids.nc
cp ../original_data/masks_high.nc masks.nc
cp ../original_data/namcouple_high namcouple


# Copy the iodef of corresponding resolution and with interpolation

rm -rf ../outputs_interp/ocean_times_n256_m256.txt

for i in $(seq 1 20); do

    rm -f rmp_*
    echo "Running interpolation iteration $i"
    mpirun -np 256 ../oasis_ping_pong.exe ocean_component t12e LR true : -np 256 ../oasis_ping_pong.exe atmos_component icoh U true >> ../outputs_interp/ocean_times_n256_m256.txt

done


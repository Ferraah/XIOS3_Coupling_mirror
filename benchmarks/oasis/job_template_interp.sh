#!/bin/bash
#SBATCH --job-name=bench_n{{N}}_m{{M}}
#SBATCH --output={{SLURM_OUTPUT}}/out_n{{N}}_m{{M}}.txt
#SBATCH --error={{SLURM_OUTPUT}}/err_n{{N}}_m{{M}}.txt
#SBATCH --ntasks={{NTOT}}
#SBATCH --time={{TIME}}
#SBATCH --partition={{PARTITION}}
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
RUN_DIR="run_{{N}}_{{M}}_interp"

cd "$RUN_DIR"

cp ../original_data/grids_{{RES}}.nc grids.nc
cp ../original_data/masks_{{RES}}.nc masks.nc
cp ../original_data/namcouple_{{RES}} namcouple


# Copy the iodef of corresponding resolution and with interpolation

rm -rf ../outputs_interp/ocean_times_n{{N}}_m{{M}}.txt

for i in $(seq 1 {{INTERP_ITERATIONS}}); do

    rm -f rmp_*
    echo "Running interpolation iteration $i"
    mpirun -np {{N}} ../oasis_ping_pong.exe ocean_component {{GRID_NAME_SRC}} {{GRID_TYPE_SRC}} true : -np {{M}} ../oasis_ping_pong.exe atmos_component {{GRID_NAME_DST}} {{GRID_TYPE_DST}} true >> ../outputs_interp/ocean_times_n{{N}}_m{{M}}.txt

done


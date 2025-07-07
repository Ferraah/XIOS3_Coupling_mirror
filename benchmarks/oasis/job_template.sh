#!/bin/bash
#SBATCH --job-name=bench_n{{N}}_m{{M}}
#SBATCH --output={{SLURM_OUTPUT}}/out_n{{N}}_m{{M}}.txt
#SBATCH --error={{SLURM_OUTPUT}}/err_n{{N}}_m{{M}}.txt
#SBATCH --ntasks={{NTOT}}
#SBATCH --time={{TIME}}
#SBATCH --partition={{PARTITION}}

module load mpi
module load tools/nco/4.7.6
module load compiler/gcc/11.2.0
module load compiler/intel/23.2.1
module load mpi/intelmpi/2021.10.0
module load lib/netcdf-fortran/4.4.4_phdf5_1.10.4

cd /scratch/globc/ferrario/xios_experiments/benchmarks/oasis

make 

# Folder already created
RUN_DIR="run_{{N}}_{{M}}"

cp original_data/grids_{{RES}}.nc "$RUN_DIR/grids.nc"
cp original_data/masks_{{RES}}.nc "$RUN_DIR/masks.nc"
cp original_data/namcouple_{{RES}} "$RUN_DIR/namcouple"

cd "$RUN_DIR"

if [[ "$1" == "true" ]]; then
    echo "Interpolation is enabled, removing remapping files."
    ls rmp_* 1>/dev/null 2>&1 && rm rmp_*
else
    echo "Interpolation is disabled, copying remapping files."
    [[ -f rmp_{{GRID_NAME_SRC}}_to_{{GRID_NAME_DST}}_oce_to_atm.nc ]] || cp ../original_data/rmp_{{GRID_NAME_SRC}}_to_{{GRID_NAME_DST}}_oce_to_atm.nc .
    [[ -f rmp_{{GRID_NAME_DST}}_to_{{GRID_NAME_SRC}}_atm_to_oce.nc ]] || cp ../original_data/rmp_{{GRID_NAME_DST}}_to_{{GRID_NAME_SRC}}_atm_to_oce.nc .
fi

echo "Running the ping-pong test with N={{N}} and M={{M}}"
mpirun -np {{N}} ../oasis_ping_pong.exe ocean_component {{GRID_NAME_SRC}} {{GRID_TYPE_SRC}} false : -np {{M}} ../oasis_ping_pong.exe atmos_component {{GRID_NAME_DST}} {{GRID_TYPE_DST}} false > ../outputs/ocean_times_n{{N}}_m{{M}}.txt
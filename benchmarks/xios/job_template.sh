#!/bin/bash
#SBATCH --job-name=bench_n{{N}}_m{{M}}
#SBATCH --output=results/out_n{{N}}_m{{M}}.txt
#SBATCH --error=results/err_n{{N}}_m{{M}}.txt
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

cd /scratch/globc/ferrario/xios_experiments/benchmarks/xios

make

# Folder already created
RUN_DIR="run_{{N}}_{{M}}"
cd "$RUN_DIR"

if [[ "$1" == "true" ]]; then
    echo "Using iodef with interpolation"
    # Copy the iodef of corresponding resolution and with interpolation
    cp ../original_data/iodef_{{RES}}_interp.xml iodef.xml
else
    # Copy the iodef of corresponding resolution and with weights reading 
    echo "Using iodef without interpolation"
    cp ../original_data/iodef_{{RES}}.xml iodef.xml
fi

echo "Running the ping-pong test with N={{N}} and M={{M}}"
mpirun -np {{N}} ../12_ping_pong.exe oce {{GRID_NAME_SRC}} {{GRID_TYPE_SRC}} : -np {{M}} ../12_ping_pong.exe atm {{GRID_NAME_DST}} {{GRID_TYPE_DST}} > ../outputs/ocean_times_n{{N}}_m{{M}}.txt


# If interpolation is enabled, extract timing
if [[ "$1" == "true" ]]; then
    # Add the time taken for interpolation to output
    grep "compute" xios_client_*.out | awk -F " " '{print $8}'  > ../outputs/interpolations_times_n{{N}}_m{{M}}.txt
fi
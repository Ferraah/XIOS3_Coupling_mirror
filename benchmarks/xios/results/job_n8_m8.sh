#!/bin/bash
#SBATCH --job-name=bench_n8_m8
#SBATCH --output=results/out_n8_m8.txt
#SBATCH --error=results/err_n8_m8.txt
#SBATCH --ntasks=16
#SBATCH --time=01:00:00
#SBATCH --partition=bench
#SBATCH --exclusive
#SBATCH --mem=90G 

module load tools/nco/4.7.6
module load compiler/gcc/11.2.0
module load compiler/intel/23.2.1
module load mpi/intelmpi/2021.10.0
module load lib/netcdf-fortran/4.4.4_phdf5_1.10.4

cd /scratch/globc/ferrario/xios_experiments/12_ping_pong

make

# Create a unique run directory for this N/M combination
RUN_DIR="run_8_8"
mkdir -p "$RUN_DIR"

cd "$RUN_DIR"

if [[ "$1" == "true" ]]; then
    echo "Using iodef with interpolation"
    # Copy the iodef of corresponding resolution and with interpolation
    cp ../original_data/iodef_high_interp.xml iodef.xml
else
    # Copy the iodef of corresponding resolution and with weights reading 
    echo "Using iodef without interpolation"
    cp ../original_data/iodef_high.xml iodef.xml
fi

echo "Running the ping-pong test with N=8 and M=8"
mpirun -np 8 ../12_ping_pong.exe oce t12e LR : -np 8 ../12_ping_pong.exe atm icoh U > ../outputs/ocean_times_n8_m8.txt


# If interpolation is enabled, extract timing
if [[ "$1" == "true" ]]; then
    # Add the time taken for interpolation to output
    grep "compute" xios_client_*.out | awk -F " " '{print $8}'  > ../outputs/interpolations_times_n8_m8.txt
fi
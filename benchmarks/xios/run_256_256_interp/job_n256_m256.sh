#!/bin/bash
#SBATCH --job-name=bench_n256_m256
#SBATCH --output=../xios/results_interp/out_n256_m256.txt
#SBATCH --error=../xios/results_interp/err_n256_m256.txt
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

cd /scratch/globc/ferrario/xios_experiments/benchmarks/xios

make

# Folder already created
RUN_DIR="run_256_256_interp"
cd "$RUN_DIR"

echo "Using iodef with interpolation"
# Copy the iodef of corresponding resolution and with interpolation
cp ../original_data/iodef_high_interp.xml iodef.xml

rm -rf ../outputs_interp/interpolations_times_n256_m256.txt

for i in $(seq 1 20); do
    echo "Running interpolation iteration $i"
    mpirun -np 256 ../12_ping_pong.exe oce true : -np 256 ../12_ping_pong.exe atm true > ../outputs_interp/ocean_times_n256_m256.txt

    # Add the time taken for interpolation from xios log file
    grep "compute" xios_client_*.out | awk -F " " '{print $8}'  >> ../outputs_interp/interpolations_times_n256_m256.txt
done

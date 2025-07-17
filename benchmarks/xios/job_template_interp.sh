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

cd /scratch/globc/ferrario/xios_experiments/benchmarks/xios

make

# Folder already created
RUN_DIR="run_{{N}}_{{M}}_interp"
cd "$RUN_DIR"

echo "Using iodef with interpolation"
# Copy the iodef of corresponding resolution and with interpolation
cp ../original_data/iodef_{{RES}}_interp.xml iodef.xml

rm -rf ../outputs_interp/interpolations_times_n{{N}}_m{{M}}.txt

for i in $(seq 1 {{INTERP_ITERATIONS}}); do
    echo "Running interpolation iteration $i"
    echo "ppn: $((SLURM_NTASKS / SLURM_JOB_NUM_NODES))"

    mpirun -genv I_MPI_PIN_DOMAIN=auto -genv I_MPI_JOB_RESPECT_PROCESS_PLACEMENT=0 \
       -ppn $((SLURM_NTASKS / SLURM_JOB_NUM_NODES)) \
       -np {{N}} ../12_ping_pong.exe oce true : -np {{M}} ../12_ping_pong.exe atm true > ../outputs_interp/ocean_times_n{{N}}_m{{M}}.txt

    # Add the time taken for interpolation from xios log file
    grep "compute" xios_client_*.out | awk -F " " '{print $8}'  >> ../outputs_interp/interpolations_times_n{{N}}_m{{M}}.txt
done

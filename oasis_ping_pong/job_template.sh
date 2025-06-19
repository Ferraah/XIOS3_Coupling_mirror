#!/bin/bash
#SBATCH --job-name=bench_n{{N}}_m{{M}}
#SBATCH --output=results/out_n{{N}}_m{{M}}.txt
#SBATCH --error=results/err_n{{N}}_m{{M}}.txt
#SBATCH --ntasks={{NTOT}}
#SBATCH --time={{TIME}}
#SBATCH --partition={{PARTITION}}

module load mpi

module load tools/nco/4.7.6

module load compiler/gcc/11.2.0

module load compiler/intel/23.2.1

module load mpi/intelmpi/2021.10.0

module load lib/netcdf-fortran/4.4.4_phdf5_1.10.4

cd /scratch/globc/ferrario/xios_experiments/oasis_ping_pong
mpirun -np {{N}} ./ocean : -np {{M}} ./atmos > outputs/ocean_times_n{{N}}_m{{M}}.txt

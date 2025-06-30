#!/bin/bash
#SBATCH --job-name=bench_n1_m1
#SBATCH --output=results/out_n1_m1.txt
#SBATCH --error=results/err_n1_m1.txt
#SBATCH --ntasks=2
#SBATCH --time=00:20:00
#SBATCH --partition=bench
#SBATCH --exclusive

module load mpi
module load tools/nco/4.7.6
module load compiler/gcc/11.2.0
module load compiler/intel/23.2.1
module load mpi/intelmpi/2021.10.0
module load lib/netcdf-fortran/4.4.4_phdf5_1.10.4

cd /scratch/globc/ferrario/xios_experiments/grid_loader
mpirun -np 16 ./loader.exe
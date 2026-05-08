#!/bin/bash
#SBATCH -J inlet_case
#SBATCH -p debug
#SBATCH -N 1
#SBATCH -n 8
#SBATCH -o fluent_output.log
#SBATCH -e fluent_error.log
#SBATCH --exclusive

export FLUENT_GUI=off
export FLUENT_ROOT=/usr/ansys_inc/v221/fluent
export FLUENT_OPENMPI_ROOT=$FLUENT_ROOT/fluent22.1.0/multiport/mpi/lnamd64/openmpi
export PATH=$FLUENT_ROOT/bin:$FLUENT_OPENMPI_ROOT/bin:$PATH
export LD_LIBRARY_PATH=$FLUENT_OPENMPI_ROOT/lib:$LD_LIBRARY_PATH

cd /home/ansysuser/fluent_job/test_case1

echo "=== Starting Fluent job at $(date) ===" > job_debug.log

/usr/ansys_inc/v221/fluent/bin/fluent 2ddp -g -t${SLURM_NTASKS:-8} -mpi=openmpi -i run.jou -wait >> job_debug.log 2>&1

echo "=== Job completed at $(date) ===" >> job_debug.log

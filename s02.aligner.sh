#!/bin/bash
#SBATCH -p compute
#SBATCH --job-name=Align
#SBATCH --mem=64G
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --output=./Logs/s02.aligner.out
#SBATCH --error=./Logs/s02.aligner.err

module load all gencore/3
module load dorado/0.9.6

project=$2
workdir=$1
reference=$3
dorado aligner --threads 32 $reference $workdir/analysis/$project".bam" > $workdir/analysis/$project"_aligned.bam"

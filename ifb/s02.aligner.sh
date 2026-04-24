#!/bin/bash
#SBATCH --partition=fast
#SBATCH --job-name=Align
#SBATCH --mem=64G
#SBATCH --ntasks=1
#SBATCH -t 2-0:00
#SBATCH --cpus-per-task=16
#SBATCH --output=./Logs/s02.aligner.out
#SBATCH --error=./Logs/s02.aligner.err

set -e

module load dorado/1.0.2

project=$2
workdir=$1
reference=$3
dorado aligner --threads 16 $reference $workdir/analysis/$project".bam" > $workdir/analysis/$project"_aligned.bam"

#!/bin/bash
#SBATCH -p nvidia
#SBATCH --gres=gpu:1
#SBATCH --job-name=dorado
#SBATCH --mem=64G
#SBATCH --ntasks=1
#SBATCH -t 4-0:00
#SBATCH --output=./Logs/s01.modbasecalling.out
#SBATCH --error=./Logs/s01.modbasecalling.err

module load all gencore/3
module load dorado/0.9.6

project=$2
workdir=$1
kit_name=$3

dorado basecaller sup@v4.3.0 \
    "$workdir/pod5/" \
    --device "cuda:$CUDA_VISIBLE_DEVICES" --kit-name $kit_name\
    --modified-bases 5mC_5hmC > $workdir/analysis/$project".bam"

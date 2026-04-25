#!/bin/bash
#SBATCH --partition=fast
#SBATCH --job-name=Indexing
#SBATCH --mem=16G
#SBATCH --ntasks=1
#SBATCH -t 1-0:00
#SBATCH --cpus-per-task=8
#SBATCH --output=indexing.out
#SBATCH --error=indexing.err


module load samtools/1.21

#Path to the reference genome
reference="/scratch/rd3725/nanopore/ref/GDDH13_1-1_formatted.fasta"

samtools faidx -@ 8 $reference
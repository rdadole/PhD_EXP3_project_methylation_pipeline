#!/bin/bash
#SBATCH -p compute
#SBATCH --job-name=Pileup_All
#SBATCH --mem=32G
#SBATCH -t 2-0:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8

set -e

# --- Load Modules ---
module load all gencore/3
module load ont-modkit/0.4.3

# --- Parameters ---
workdir=$1
project=$2
barcodes=$3
reference=$4

# --- Command ---
echo "--- Starting Pileup for ALL contexts ---"
if [ "$barcodes" == "NA" ]; then
    echo "Processing non-multiplexed sample"
    input_sorted_bam="$workdir/analysis/${project}_sorted.bam"
    output_bed="$workdir/analysis/${project}_methylation.bed"

    if [ -f "$input_sorted_bam" ]; then
        modkit pileup -t $SLURM_CPUS_PER_TASK "$input_sorted_bam" "$output_bed"
    else
        echo "Error: Input file $input_sorted_bam not found." >&2; exit 1
    fi
else
    barcode_list=($barcodes)
    for barcode_nb in "${barcode_list[@]}"; do
        echo "Processing barcode $barcode_nb"
        input_sorted_bam="$workdir/analysis/${project}_barcode${barcode_nb}_sorted.bam"
        output_bed="$workdir/analysis/${project}_barcode${barcode_nb}_methylation.bed"

        if [ -f "$input_sorted_bam" ]; then
            modkit pileup -t $SLURM_CPUS_PER_TASK "$input_sorted_bam" "$output_bed" &
        else
            echo "Warning: Input file $input_sorted_bam not found. Skipping barcode $barcode_nb."
        fi
    done
    wait # Wait for all background pileup jobs for barcodes to finish
fi
echo "--- Pileup for ALL contexts complete. ---"

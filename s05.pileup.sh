#!/bin/bash
#SBATCH -p compute
#SBATCH --job-name=Pileup
#SBATCH --mem=64G
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --output=./Logs/s05.pileup.out
#SBATCH --error=./Logs/s05.pileup.err

module load all gencore/3
module load ont-modkit/0.4.3

# --- Parameters ---
workdir=$1
project=$2
kit_name=$3 # Passed but not used, which is fine.
barcodes=$4

# --- Command ---
if [ "$barcodes" == "NA" ]; then
    echo "Creating methylation bed file for non-multiplexed sample"

    input_sorted_bam="$workdir/analysis/${project}_sorted.bam"
    output_bed="$workdir/analysis/${project}_methylation.bed"

    if [ -f "$input_sorted_bam" ]; then
        modkit pileup --ignore h -t 16 "$input_sorted_bam" "$output_bed"
    else
        echo "Error: Input file $input_sorted_bam not found."
        exit 1
    fi
else
    # Read the space-separated string of barcodes into a bash array
    barcode_list=($barcodes)
    for barcode_nb in "${barcode_list[@]}"; do
        echo "Creating methylation bed file for barcode $barcode_nb"

        input_sorted_bam="$workdir/analysis/${project}_barcode${barcode_nb}_sorted.bam"
        output_bed="$workdir/analysis/${project}_barcode${barcode_nb}_methylation.bed"

        if [ -f "$input_sorted_bam" ]; then
            modkit pileup --ignore h -t 16 "$input_sorted_bam" "$output_bed"
        else
            echo "Warning: Input file $input_sorted_bam not found. Skipping barcode $barcode_nb."
        fi
    done
fi

echo "Methylation pileup complete."
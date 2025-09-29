#!/bin/bash
#SBATCH -p compute
#SBATCH --job-name=Sort_Index
#SBATCH --mem=16G
#SBATCH --ntasks=1
#SBATCH -t 1-0:00
#SBATCH --cpus-per-task=8
#SBATCH --output=./Logs/s04.sort_and_indexing.out
#SBATCH --error=./Logs/s04.sort_and_indexing.err

module load all gencore/3
module load samtools/1.21

# --- Parameters ---
workdir=$1
project=$2
kit_name=$3
barcodes=$4

# --- Command ---
if [ "$barcodes" == "NA" ]; then
    echo "Processing non-multiplexed sample"
    
    # Define input and output file paths explicitly
    input_bam="$workdir/analysis/${project}_aligned.bam"
    sorted_bam="$workdir/analysis/${project}_sorted.bam"

    if [ -f "$input_bam" ]; then
        echo "Sorting $input_bam..."
        samtools sort -@ 8 "$input_bam" > "$sorted_bam"
        
        echo "Indexing $sorted_bam..."
        samtools index -@ 8 "$sorted_bam"
    else
        echo "Error: Input file $input_bam not found."
        exit 1
    fi
else
    # Read the space-separated string of barcodes into a bash array
    barcode_list=($barcodes)
    for barcode_nb in "${barcode_list[@]}"; do
        echo "Processing barcode $barcode_nb"

        # Define input and output file paths explicitly
        input_bam="$workdir/analysis/${project}_${kit_name}_barcode${barcode_nb}.bam"
        sorted_bam="$workdir/analysis/${project}_barcode${barcode_nb}_sorted.bam"

        # Check if the input file exists before processing
        if [ -f "$input_bam" ]; then
            echo "Sorting $input_bam..."
            samtools sort -@ 8 "$input_bam" > "$sorted_bam"
            
            echo "Indexing $sorted_bam..."
            samtools index -@ 8 "$sorted_bam"
        else
            echo "Warning: Input file $input_bam not found. Skipping barcode $barcode_nb."
        fi
    done
fi

echo "Sorting and indexing complete."
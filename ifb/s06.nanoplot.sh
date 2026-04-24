#!/bin/bash
#SBATCH --partition=fast
#SBATCH --job-name=Nanoplot
#SBATCH --mem=64G
#SBATCH -t 1-0:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --output=./Logs/s06.nanoplot.out
#SBATCH --error=./Logs/s06.nanoplot.err

set -e

module load nanoplot/1.42.0

# --- Parameters ---
workdir=$1
project=$2
barcodes=$3

# --- Command ---
if [ "$barcodes" == "NA" ]; then
    echo "Generating NanoPlot summary for non-multiplexed sample"
    
    input_sorted_bam="$workdir/analysis/${project}_sorted.bam"
    output_dir="$workdir/analysis/${project}_summary_plots"

    if [ -f "$input_sorted_bam" ]; then
        NanoPlot -t 8 --bam "$input_sorted_bam" -o "$output_dir"
    else
        echo "Error: Input file $input_sorted_bam not found."
        exit 1
    fi
else
    # Read the space-separated string of barcodes into a bash array
    barcode_list=($barcodes)
    for barcode_nb in "${barcode_list[@]}"; do
        echo "Generating NanoPlot summary for barcode $barcode_nb"
        
        input_sorted_bam="$workdir/analysis/${project}_barcode${barcode_nb}_sorted.bam"
        output_dir="$workdir/analysis/${project}_barcode${barcode_nb}_summary_plots"

        if [ -f "$input_sorted_bam" ]; then
            NanoPlot -t 8 --bam "$input_sorted_bam" -o "$output_dir"
        else
            echo "Warning: Input file $input_sorted_bam not found. Skipping barcode $barcode_nb."
        fi
    done
fi

echo "NanoPlot analysis complete."

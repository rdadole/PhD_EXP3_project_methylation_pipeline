#!/bin/bash
#SBATCH -p compute
#SBATCH --job-name=Split_barcode
#SBATCH --mem=16G
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --output=./Logs/s03.Split_barcode.out
#SBATCH --error=./Logs/s03.Split_barcode.err

module load all gencore/3
module load dorado/0.9.6

# --- Parameters ---
workdir=$1
project=$2

# --- Command ---
echo "Starting demultiplexing for project: $project"
# Use --output-prefix to add the project name to the output files.
# The output will be named like: <project>_<kit_name>_barcode<XX>.bam
dorado demux \
    --output-dir "$workdir/analysis/" \
    --output-prefix "${project}_" \
    --no-classify \
    "$workdir/analysis/${project}_aligned.bam"

echo "Demultiplexing complete."
#!/bin/bash
#SBATCH --partition=gpu
#SBATCH --gres=gpu:l40s:1
#SBATCH --mem=64G
#SBATCH --ntasks=1
#SBATCH -t 3-0:00
#SBATCH --job-name=dorado_chunk
#SBATCH --output=./Logs/s01.modbasecalling_%a.out
#SBATCH --error=./Logs/s01.modbasecalling_%a.err

set -e


module load dorado/1.0.2

# --- Inputs ---
workdir=$1
project=$2
kit_name=$3
barcodes=$4
CHUNK_ID=${SLURM_ARRAY_TASK_ID} # Captured from Slurm Array

# --- Defined Paths ---
# Point to the specific temporary chunk folder created by the master script
INPUT_DIR="$workdir/pod5_parts/batch_${CHUNK_ID}"
OUTPUT_BAM="$workdir/analysis/${project}_part_${CHUNK_ID}.bam"

echo " Processing Chunk #$CHUNK_ID"
echo "   Input: $INPUT_DIR"
echo "   Output: $OUTPUT_BAM"

# --- Run Dorado ---
# Note: Removed --resume-from logic as parallelization replaces it
BASE_ARGS="basecaller sup@v4.3.0 $INPUT_DIR --device cuda:$CUDA_VISIBLE_DEVICES --modified-bases 5mC_5hmC"

if [ "$barcodes" == "NA" ]; then
    echo "   Config: Non-multiplexed"
    dorado $BASE_ARGS > "$OUTPUT_BAM"
else
    echo "   Config: Multiplexed (Kit: $kit_name)"
    dorado $BASE_ARGS --kit-name $kit_name > "$OUTPUT_BAM"
fi

echo " Chunk $CHUNK_ID completed."
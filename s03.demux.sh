#!/bin/bash
#SBATCH -p compute
#SBATCH --job-name=Split_barcode
#SBATCH --mem=16G
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --output=./Logs/s03.Split_barcode.out
#SBATCH --error=./Logs/s03.Split_barcode.err

set -e

module load all gencore/3
module load dorado/0.9.6

# --- Parameters ---
workdir=$1
project=$2

# --- Command ---
echo "Starting demultiplexing for project: $project"

# Navigate to the analysis directory to simplify file paths for demux and renaming.
cd "$workdir/analysis/"

# Run dorado demux. The --output-dir is no longer needed as we are in the target directory.
# The invalid --output-prefix parameter has been removed.
dorado demux \
    --no-classify -o ./ \
    "${project}_aligned.bam"

echo "Demultiplexing complete. Renaming output files..."

# Loop through the default output files and rename them to include the project prefix.
for f in *_barcode*.bam unclassified.bam; do
    # Check if a file matching the pattern exists to avoid errors.
    if [ -f "$f" ]; then
        # Remove the prefix from the filename.
        # ${f##*_} removes everything from the beginning of the string up to the last underscore.
        # For "KIT_barcode01.bam", this results in "barcode01.bam".
        # For "unclassified.bam" (no underscore), it results in "unclassified.bam".
        new_suffix="${f##*_}"
        
        # Construct the new filename and rename the file.
        mv -- "$f" "${project}_${new_suffix}"
        echo "Renamed $f to ${project}_${new_suffix}"
    fi
done

echo "Renaming complete."
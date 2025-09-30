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

# Navigate to the analysis directory to simplify file paths for demux and renaming.
cd "$workdir/analysis/"

# Run dorado demux. The --output-dir is no longer needed as we are in the target directory.
# The invalid --output-prefix parameter has been removed.
dorado demux \
    --no-classify \
    "./${project}_aligned.bam"

echo "Demultiplexing complete. Renaming output files..."

# Loop through the default output files and rename them to include the project prefix.
# The pattern '*_barcode_*.bam' correctly matches the expected output format of '{kit_name}_barcode_??.bam'.
for f in *_barcode_*.bam unclassified.bam; do
    # Check if a file matching the pattern exists to avoid errors from the shell.
    if [ -f "$f" ]; then
        mv -- "$f" "${project}_$f"
        echo "Renamed $f to ${project}_$f"
    fi
done

echo "Renaming complete."
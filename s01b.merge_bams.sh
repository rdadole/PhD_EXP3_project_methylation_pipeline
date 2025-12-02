#!/bin/bash
#SBATCH --job-name=bam_merge
#SBATCH --mem=64G
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=2:00:00
#SBATCH --output=./Logs/s01b.merge.out
#SBATCH --error=./Logs/s01b.merge.err

set -e
module load samtools # Ensure samtools is available

workdir=$1
project=$2

echo "🧩 Merging parallel chunks for $project..."

# Merge all chunks (part_*.bam) into the final project.bam
# -@ 8 uses 8 threads for compression speed
samtools merge -@ 8 \
    "$workdir/analysis/${project}.bam" \
    "$workdir/analysis/${project}_part_"*.bam

echo "✅ Merged file created: $workdir/analysis/${project}.bam"

# Optional: Clean up chunks to save space (uncomment if desired)
# rm "$workdir/analysis/${project}_part_"*.bam
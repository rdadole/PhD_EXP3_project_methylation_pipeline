#!/bin/bash
#-------------------------------------------------------------------------
# This master script reads a sample sheet and launches an independent 
# pipeline for each row.
#
# Usage: ./s00.master_from_table.sh <path_to_samples.tsv>
#-------------------------------------------------------------------------

set -e # Exit immediately if a command fails

# --- Validate Input ---
SAMPLESHEET=$1
if [ -z "$SAMPLESHEET" ]; then
    echo "Error: Please provide the path to your sample sheet."
    echo "Usage: $0 <path_to_samples.tsv>"
    exit 1
fi

# Get the directory where this script is located to find the worker scripts
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# --- Read Sample Sheet and Launch Jobs ---
# Reads the sample sheet line by line, skipping the header
tail -n +2 "$SAMPLESHEET" | while IFS=$'\t' read -r project workdir reference kit_name sample_barcode; do
    
    # Sanitize the sample_barcode variable to remove any trailing carriage return
    sample_barcode=${sample_barcode%$'\r'}
    
    echo "================================================="
    echo "🚀 Launching pipeline for project: $project"
    echo "   Work Directory: $workdir"
    echo "   Barcodes: $sample_barcode"
    echo "================================================="

    # Define and create project-specific directories for logs and analysis
    LOG_DIR="$workdir/Logs"
    mkdir -p "$LOG_DIR"
    mkdir -p "$workdir/analysis"

    # --- Job Submission ---
    
    # Step A: Basecalling (common for both workflows)
    A=$(sbatch --parsable --job-name="${project}_basecall" \
        --output="$LOG_DIR/s01.modbasecalling.out" \
        --error="$LOG_DIR/s01.modbasecalling.err" \
        "$SCRIPT_DIR/s01.mod_basecalling.sh" "$workdir" "$project" "$kit_name" "$sample_barcode")

    # Step B: Alignment (common for both workflows)
    B=$(sbatch --parsable --dependency=afterok:$A --job-name="${project}_align" \
        --output="$LOG_DIR/s02.aligner.out" \
        --error="$LOG_DIR/s02.aligner.err" \
        "$SCRIPT_DIR/s02.aligner.sh" "$workdir" "$project" "$reference")

    # Conditional logic for multiplexed vs. non-multiplexed
    if [ "$sample_barcode" == "NA" ]; then
        # --- NON-MULTIPLEXED WORKFLOW ---
        echo "   -> Detected non-multiplexed sample (NA). Skipping demultiplexing."

        # Skip demux (C), go straight to indexing (D) depending on alignment (B)
        D=$(sbatch --parsable --dependency=afterok:$B --job-name="${project}_index" \
            --output="$LOG_DIR/s04.indexing.out" \
            --error="$LOG_DIR/s04.indexing.err" \
            "$SCRIPT_DIR/s04.indexing.sh" "$workdir" "$project" "$kit_name" "$sample_barcode")

        E=$(sbatch --parsable --dependency=afterok:$D --job-name="${project}_pileup" \
            --output="$LOG_DIR/s05.pileup.out" \
            --error="$LOG_DIR/s05.pileup.err" \
            "$SCRIPT_DIR/s05.pileup.sh" "$workdir" "$project" "$kit_name" "$sample_barcode" "$reference")

        F=$(sbatch --parsable --dependency=afterok:$E --job-name="${project}_nanoplot" \
            --output="$LOG_DIR/s06.nanoplot.out" \
            --error="$LOG_DIR/s06.nanoplot.err" \
            "$SCRIPT_DIR/s06.nanoplot.sh" "$workdir" "$project" "$kit_name" "$sample_barcode")

    else
        # --- MULTIPLEXED WORKFLOW (Original logic) ---
        echo "   -> Detected multiplexed sample. Including demultiplexing step."

        C=$(sbatch --parsable --dependency=afterok:$B --job-name="${project}_demux" \
            --output="$LOG_DIR/s03.demux.out" \
            --error="$LOG_DIR/s03.demux.err" \
            "$SCRIPT_DIR/s03.demux.sh" "$workdir" "$project" "$kit_name")

        D=$(sbatch --parsable --dependency=afterok:$C --job-name="${project}_index" \
            --output="$LOG_DIR/s04.indexing.out" \
            --error="$LOG_DIR/s04.indexing.err" \
            "$SCRIPT_DIR/s04.indexing.sh" "$workdir" "$project" "$kit_name" "$sample_barcode")

        E=$(sbatch --parsable --dependency=afterok:$D --job-name="${project}_pileup" \
            --output="$LOG_DIR/s05.pileup.out" \
            --error="$LOG_DIR/s05.pileup.err" \
            "$SCRIPT_DIR/s05.pileup.sh" "$workdir" "$project" "$kit_name" "$sample_barcode" "$reference")

        F=$(sbatch --parsable --dependency=afterok:$E --job-name="${project}_nanoplot" \
            --output="$LOG_DIR/s06.nanoplot.out" \
            --error="$LOG_DIR/s06.nanoplot.err" \
            "$SCRIPT_DIR/s06.nanoplot.sh" "$workdir" "$project" "$kit_name" "$sample_barcode")
    fi

    echo "✅ All jobs for project '$project' submitted. Final job ID: $F"
    echo ""

done

echo "🎉 All pipelines have been launched."
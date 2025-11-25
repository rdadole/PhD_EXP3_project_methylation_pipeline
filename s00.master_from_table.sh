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
# MODIFIED: Included 'basecalled' column
tail -n +2 "$SAMPLESHEET" | while IFS=$'\t' read -r project workdir reference kit_name sample_barcode basecalled; do
    
    # Sanitize variables to remove any trailing carriage return
    sample_barcode=${sample_barcode%$'\r'}
    basecalled=${basecalled%$'\r'}

    # Set default for 'basecalled' to 'No' if the column is empty
    if [ -z "$basecalled" ]; then
        basecalled="No"
    fi

    # Convert the basecalled status to lowercase for robust checking
    BASECALLED_STATUS=$(echo "$basecalled" | tr '[:upper:]' '[:lower:]')
    
    echo "================================================="
    echo "🚀 Launching pipeline for project: $project"
    echo "   Work Directory: $workdir"
    echo "   Barcodes: $sample_barcode"
    echo "   Basecalling Status: $basecalled"
    echo "================================================="

    # Define and create project-specific directories for logs and analysis
    LOG_DIR="$workdir/Logs"
    mkdir -p "$LOG_DIR"
    mkdir -p "$workdir/analysis"

    # --- Job Submission ---
    
    # Step A: Conditional Basecalling
    if [ "$BASECALLED_STATUS" == "no" ]; then
        # Basecalling required. Submit s01.
        echo "   -> Basecalling required. Submitting s01.mod_basecalling.sh."
        A=$(sbatch --parsable --job-name="${project}_basecall" \
            --output="$LOG_DIR/s01.modbasecalling.out" \
            --error="$LOG_DIR/s01.modbasecalling.err" \
            "$SCRIPT_DIR/s01.mod_basecalling.sh" "$workdir" "$project" "$kit_name" "$sample_barcode")
        
            # Step B: Alignment (Depends on A, which is either the basecalling Job ID or 0)
        B=$(sbatch --parsable --dependency=afterok:$A --job-name="${project}_align" \
            --output="$LOG_DIR/s02.aligner.out" \
            --error="$LOG_DIR/s02.aligner.err" \
            "$SCRIPT_DIR/s02.aligner.sh" "$workdir" "$project" "$reference")
    else
        # Basecalling skipped. A remains 0, meaning Step B will run immediately.
        echo "   -> Basecalling column is set to '$basecalled'. Skipping basecalling (s01)."
            # Step B: Alignment (Depends on A, which is either the basecalling Job ID or 0)
        B=$(sbatch --parsable  --job-name="${project}_align" \
            --output="$LOG_DIR/s02.aligner.out" \
            --error="$LOG_DIR/s02.aligner.err" \
            "$SCRIPT_DIR/s02.aligner.sh" "$workdir" "$project" "$reference")
    fi



    # Conditional logic for multiplexed vs. non-multiplexed
    if [ "$sample_barcode" == "NA" ]; then
        # --- NON-MULTIPLEXED WORKFLOW ---
        echo "   -> Detected non-multiplexed sample (NA). Skipping demultiplexing."

        # Skip demux (C), go straight to indexing (D) depending on alignment (B)
        D=$(sbatch --parsable --dependency=afterok:$B --job-name="${project}_index" \
            --output="$LOG_DIR/s04.indexing.out" \
            --error="$LOG_DIR/s04.indexing.err" \
            "$SCRIPT_DIR/s04.indexing.sh" "$workdir" "$project" "$sample_barcode")

        # Step E: Parallel Pileup Submission
        echo "   -> Submitting parallel pileup jobs."
        E_all=$(sbatch --parsable --dependency=afterok:$D --job-name="${project}_pileup_all" \
            --output="$LOG_DIR/s05a.pileup_all.out" --error="$LOG_DIR/s05a.pileup_all.err" \
            "$SCRIPT_DIR/s05a.pileup_all.sh" "$workdir" "$project" "$sample_barcode" "$reference")
        
        E_cg=$(sbatch --parsable --dependency=afterok:$D --job-name="${project}_pileup_cg" \
            --output="$LOG_DIR/s05b.pileup_cg.out" --error="$LOG_DIR/s05b.pileup_cg.err" \
            "$SCRIPT_DIR/s05b.pileup_cg.sh" "$workdir" "$project" "$sample_barcode" "$reference")

        E_chg=$(sbatch --parsable --dependency=afterok:$D --job-name="${project}_pileup_chg" \
            --output="$LOG_DIR/s05c.pileup_chg.out" --error="$LOG_DIR/s05c.pileup_chg.err" \
            "$SCRIPT_DIR/s05c.pileup_chg.sh" "$workdir" "$project" "$sample_barcode" "$reference")

        E_chh=$(sbatch --parsable --dependency=afterok:$D --job-name="${project}_pileup_chh" \
            --output="$LOG_DIR/s05d.pileup_chh.out" --error="$LOG_DIR/s05d.pileup_chh.err" \
            "$SCRIPT_DIR/s05d.pileup_chh.sh" "$workdir" "$project" "$sample_barcode" "$reference")

        # Step F: Nanoplot (depends on indexing job finishing)
        F=$(sbatch --parsable --dependency=afterok:$D --job-name="${project}_nanoplot" \
            --output="$LOG_DIR/s06.nanoplot.out" \
            --error="$LOG_DIR/s06.nanoplot.err" \
            "$SCRIPT_DIR/s06.nanoplot.sh" "$workdir" "$project" "$sample_barcode")

    else
        # --- MULTIPLEXED WORKFLOW ---
        echo "   -> Detected multiplexed sample. Including demultiplexing step."

        C=$(sbatch --parsable --dependency=afterok:$B --job-name="${project}_demux" \
            --output="$LOG_DIR/s03.demux.out" \
            --error="$LOG_DIR/s03.demux.err" \
            "$SCRIPT_DIR/s03.demux.sh" "$workdir" "$project" "$kit_name")

        D=$(sbatch --parsable --dependency=afterok:$C --job-name="${project}_index" \
            --output="$LOG_DIR/s04.indexing.out" \
            --error="$LOG_DIR/s04.indexing.err" \
            "$SCRIPT_DIR/s04.indexing.sh" "$workdir" "$project" "$sample_barcode")

        # Step E: Parallel Pileup Submission
        echo "   -> Submitting parallel pileup jobs."
        E_all=$(sbatch --parsable --dependency=afterok:$D --job-name="${project}_pileup_all" \
            --output="$LOG_DIR/s05a.pileup_all.out" --error="$LOG_DIR/s05a.pileup_all.err" \
            "$SCRIPT_DIR/s05a.pileup_all.sh" "$workdir" "$project" "$sample_barcode" "$reference")
        
        E_cg=$(sbatch --parsable --dependency=afterok:$D --job-name="${project}_pileup_cg" \
            --output="$LOG_DIR/s05b.pileup_cg.out" --error="$LOG_DIR/s05b.pileup_cg.err" \
            "$SCRIPT_DIR/s05b.pileup_cg.sh" "$workdir" "$project" "$sample_barcode" "$reference")

        E_chg=$(sbatch --parsable --dependency=afterok:$D --job-name="${project}_pileup_chg" \
            --output="$LOG_DIR/s05c.pileup_chg.out" --error="$LOG_DIR/s05c.pileup_chg.err" \
            "$SCRIPT_DIR/s05c.pileup_chg.sh" "$workdir" "$project" "$sample_barcode" "$reference")

        E_chh=$(sbatch --parsable --dependency=afterok:$D --job-name="${project}_pileup_chh" \
            --output="$LOG_DIR/s05d.pileup_chh.out" --error="$LOG_DIR/s05d.pileup_chh.err" \
            "$SCRIPT_DIR/s05d.pileup_chh.sh" "$workdir" "$project" "$sample_barcode" "$reference")

        # Step F: Nanoplot (depends on indexing job finishing)
        F=$(sbatch --parsable --dependency=afterok:$D --job-name="${project}_nanoplot" \
            --output="$LOG_DIR/s06.nanoplot.out" \
            --error="$LOG_DIR/s06.nanoplot.err" \
            "$SCRIPT_DIR/s06.nanoplot.sh" "$workdir" "$project" "$sample_barcode")
    fi

    echo "✅ All jobs for project '$project' submitted. Final job IDs: $E_all $E_cg $E_chg $E_chh $F"
    echo ""

done

echo "🎉 All pipelines have been launched."

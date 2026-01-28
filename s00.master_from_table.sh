#!/bin/bash
#-------------------------------------------------------------------------
# Usage: ./s00.master_from_table.sh <path_to_samples.tsv>
#-------------------------------------------------------------------------

set -e 

SAMPLESHEET=$1
if [ -z "$SAMPLESHEET" ]; then
    echo "Error: Please provide sample sheet."
    exit 1
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# --- CONFIGURATION ---
NUM_CHUNKS=3  # How many parallel GPU jobs to run per project?

tail -n +2 "$SAMPLESHEET" | while IFS=$'\t' read -r project workdir reference kit_name sample_barcode do_basecalling; do
    
    # Sanitize inputs
    sample_barcode=${sample_barcode%$'\r'}
    do_basecalling=${do_basecalling%$'\r'}
    BASECALLING=$(echo "$do_basecalling" | tr '[:upper:]' '[:lower:]')

    echo "================================================="
    echo "  Project: $project"
    echo "   Workdir: $workdir"
    echo "   Chunks:  $NUM_CHUNKS (if basecalling)"
    echo "================================================="

    LOG_DIR="$workdir/Logs"
    mkdir -p "$LOG_DIR"
    mkdir -p "$workdir/analysis"
    
    DEPENDENCY_FLAG=""

    # --- Step A: Scatter-Gather Basecalling ---
    if [ "$BASECALLING" != "yes" && "$BASECALLING" != "no"]; then
        echo "do_basecalling should be either yes or no, the current value is $BASECALLING"
        exit
    fi
    if [ "$BASECALLING" == "yes" ]; then
        
        echo "   -> preparing $NUM_CHUNKS parallel batches..."
        
        # 1. PREPARE SPLITS (Symlinks, not copy)
        # Create a directory to hold the split folders
        PARTS_DIR="$workdir/pod5_parts"
        rm -rf "$PARTS_DIR" # Clean old splits
        mkdir -p "$PARTS_DIR"
        
        # List all pod5 files
        find "$workdir/pod5" -maxdepth 1 -name "*.pod5" > "$workdir/all_pod5_files.txt"
        
        # Split the list of files into N chunks
        # This creates files named "x00", "x01", "x02"... inside PARTS_DIR containing file paths
        split -d -n l/$NUM_CHUNKS "$workdir/all_pod5_files.txt" "$PARTS_DIR/batch_list_"
        
        # Loop through the lists and create symlink directories
        # We start count at 1 to match Slurm Array indices (1-N)
        count=1
        for listfile in "$PARTS_DIR"/batch_list_*; do
            BATCH_DIR="$PARTS_DIR/batch_$count"
            mkdir -p "$BATCH_DIR"
            
            # Read the list file and symlink each pod5 into the batch folder
            while read -r file; do
                ln -s "$file" "$BATCH_DIR/"
            done < "$listfile"
            
            count=$((count + 1))
        done
        
        # 2. SUBMIT ARRAY JOB (SCATTER)
        # Submits jobs 1 through NUM_CHUNKS
        echo "   -> Submitting Array Job (1-$NUM_CHUNKS)..."
        A_ARRAY=$(sbatch --parsable --array=1-$NUM_CHUNKS --job-name="${project}_basecall" \
            --output="$LOG_DIR/s01.basecall_%a.out" \
            --error="$LOG_DIR/s01.basecall_%a.err" \
            "$SCRIPT_DIR/s01.mod_basecalling.sh" "$workdir" "$project" "$kit_name" "$sample_barcode")

        # 3. SUBMIT MERGE JOB (GATHER)
        # Depends on the entire array finishing (afterok)
        echo "   -> Submitting Merge Job..."
        A_MERGE=$(sbatch --parsable --dependency=afterok:$A_ARRAY --job-name="${project}_merge" \
            --output="$LOG_DIR/s01b.merge.out" \
            --error="$LOG_DIR/s01b.merge.err" \
            "$SCRIPT_DIR/s01b.merge_bams.sh" "$workdir" "$project")

        # Next steps depend on the Merge job
        DEPENDENCY_FLAG="--dependency=afterok:$A_MERGE"

    else
        echo "   -> Basecalling skipped ($basecalled)."
        DEPENDENCY_FLAG=""
    fi

    # --- Step B: Alignment (Depends on Merge or Nothing) ---
    B=$(sbatch --parsable $DEPENDENCY_FLAG --job-name="${project}_align" \
        --output="$LOG_DIR/s02.aligner.out" \
        --error="$LOG_DIR/s02.aligner.err" \
        "$SCRIPT_DIR/s02.aligner.sh" "$workdir" "$project" "$reference")

    # --- Conditional Multiplex Logic ---
    if [ "$sample_barcode" == "NA" ]; then
        # Non-Multiplexed
        echo "   -> Non-multiplexed workflow."
        D=$(sbatch --parsable --dependency=afterok:$B --job-name="${project}_index" \
            --output="$LOG_DIR/s04.indexing.out" \
            --error="$LOG_DIR/s04.indexing.err" \
            "$SCRIPT_DIR/s04.indexing.sh" "$workdir" "$project" "$sample_barcode")
        FINAL_DEP=$D
    else
        # Multiplexed
        echo "   -> Multiplexed workflow."
        C=$(sbatch --parsable --dependency=afterok:$B --job-name="${project}_demux" \
            --output="$LOG_DIR/s03.demux.out" \
            --error="$LOG_DIR/s03.demux.err" \
            "$SCRIPT_DIR/s03.demux.sh" "$workdir" "$project" "$kit_name")

        D=$(sbatch --parsable --dependency=afterok:$C --job-name="${project}_index" \
            --output="$LOG_DIR/s04.indexing.out" \
            --error="$LOG_DIR/s04.indexing.err" \
            "$SCRIPT_DIR/s04.indexing.sh" "$workdir" "$project" "$sample_barcode")
        FINAL_DEP=$D
    fi

    # Step E: Parallel Pileup Submission
    echo "   -> Submitting parallel pileup jobs."
    E_all=$(sbatch --parsable --dependency=afterok:$FINAL_DEP --job-name="${project}_pileup_all" \
        --output="$LOG_DIR/s05a.pileup_all.out" --error="$LOG_DIR/s05a.pileup_all.err" \
        "$SCRIPT_DIR/s05a.pileup_all.sh" "$workdir" "$project" "$sample_barcode" "$reference")
    
    E_cg=$(sbatch --parsable --dependency=afterok:$FINAL_DEP --job-name="${project}_pileup_cg" \
        --output="$LOG_DIR/s05b.pileup_cg.out" --error="$LOG_DIR/s05b.pileup_cg.err" \
        "$SCRIPT_DIR/s05b.pileup_cg.sh" "$workdir" "$project" "$sample_barcode" "$reference")

    E_chg=$(sbatch --parsable --dependency=afterok:$FINAL_DEP --job-name="${project}_pileup_chg" \
        --output="$LOG_DIR/s05c.pileup_chg.out" --error="$LOG_DIR/s05c.pileup_chg.err" \
        "$SCRIPT_DIR/s05c.pileup_chg.sh" "$workdir" "$project" "$sample_barcode" "$reference")

    E_chh=$(sbatch --parsable --dependency=afterok:$FINAL_DEP --job-name="${project}_pileup_chh" \
        --output="$LOG_DIR/s05d.pileup_chh.out" --error="$LOG_DIR/s05d.pileup_chh.err" \
        "$SCRIPT_DIR/s05d.pileup_chh.sh" "$workdir" "$project" "$sample_barcode" "$reference")

    # Step F: Nanoplot (depends on indexing job finishing)
    F=$(sbatch --parsable --dependency=afterok:$FINAL_DEP --job-name="${project}_nanoplot" \
        --output="$LOG_DIR/s06.nanoplot.out" \
        --error="$LOG_DIR/s06.nanoplot.err" \
        "$SCRIPT_DIR/s06.nanoplot.sh" "$workdir" "$project" "$sample_barcode")

    echo " All jobs for project '$project' submitted. Final job IDs: $E_all $E_cg $E_chg $E_chh $F"
    echo ""

done

echo " All pipelines have been launched."

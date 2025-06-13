#!/bin/bash
# Alpine Builder Fix Evolution - 5 parallel instances for 2 hours
# Each instance gets a UUID8 for complete isolation

set -e

# Configuration
INSTANCES=5
DURATION_HOURS=2
MODEL="claude-3-5-sonnet-20241022"
BASE_DIR="$(pwd)"
EVOLUTION_DIR="${BASE_DIR}/alpine-fix-evolution"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create evolution directory
mkdir -p "$EVOLUTION_DIR"
cd "$EVOLUTION_DIR"

# Create the task file with UUID8 isolation instructions
cat > alpine_fix_task.md << 'EOF'
# Alpine Builder Fix Task

## Objective
Fix the Alpine Docker builder to produce a fully functional minimal Elixir VM image that:
1. Successfully runs Elixir code
2. Has proper path configurations
3. Maintains the small size (target: under 30MB compressed)
4. Can be tested and verified

## Your Unique Instance ID: {{INSTANCE_UUID}}

**CRITICAL**: Use your instance UUID ({{INSTANCE_UUID}}) for ALL:
- Docker image names (e.g., elixir-lean-vm-{{INSTANCE_UUID}}:latest)
- Container names
- Output file names
- Test file names
- Any other artifacts that could conflict between instances

## Current Issues to Fix
1. Elixir binary cannot find BEAM files due to incorrect path configuration
2. The elixir script expects files at /usr/local/lib/elixir/ebin/ which doesn't exist
3. The FROM scratch stage may be removing important metadata

## Success Criteria
1. `docker run --rm <your-image> elixir -e 'IO.puts("Hello")'` must work
2. Image size should remain under 30MB compressed
3. All tests must pass
4. Document your approach and solution

## Testing Protocol
1. Create test scripts with your UUID: test_alpine_{{INSTANCE_UUID}}.exs
2. Save outputs to: output/alpine-vm-{{INSTANCE_UUID}}.tar.xz
3. Run verification: The image must execute Elixir code successfully

## Important Files
- lib/elixir_lean_lab/builder/alpine.ex - The builder to fix
- scripts/test_alpine.exs - Reference test script (copy and modify with your UUID)

## Constraints
- Do NOT modify other builders (buildroot, custom, nerves)
- Focus ONLY on making Alpine builder work correctly
- Maintain backward compatibility with the Config structure
- Keep the multi-stage Docker approach

Remember: Your goal is a WORKING Alpine builder, not just one that builds.
EOF

# Function to create and run an instance
run_instance() {
    local instance_num=$1
    local uuid=$(uuidgen | tr '[:upper:]' '[:lower:]' | head -c 8)
    local branch_name="alpine-fix-${uuid}"
    local instance_dir="instance-${uuid}"
    
    echo "Starting instance $instance_num with UUID: $uuid"
    
    # Create a worktree for this instance
    git worktree add "$instance_dir" -b "$branch_name" >/dev/null 2>&1
    
    # Create instance-specific task file
    sed "s/{{INSTANCE_UUID}}/$uuid/g" alpine_fix_task.md > "$instance_dir/TASK.md"
    
    # Create the evolution command for this instance
    cat > "$instance_dir/run_evolution.sh" << EEOF
#!/bin/bash
cd "$EVOLUTION_DIR/$instance_dir"

# Set up instance-specific environment
export DOCKER_IMAGE_PREFIX="elixir-lean-vm-$uuid"
export INSTANCE_UUID="$uuid"

echo "Instance $uuid starting Alpine builder fix evolution..."
echo "Working directory: \$(pwd)"
echo "Duration: $DURATION_HOURS hours"
echo "Model: $MODEL"

# Run the evolution in headless mode
claude --model "$MODEL" --dangerously-skip-permissions << 'PROMPT'
Read the TASK.md file and complete the Alpine builder fix task.

Key points:
1. Use UUID $uuid for all your Docker images, containers, and output files
2. Fix the path issues so Elixir can actually run in the container
3. Test thoroughly - the image must be functional, not just built
4. Document your solution

Start by reading TASK.md and understanding the current issues.
PROMPT

echo "Instance $uuid completed."
EEOF
    
    chmod +x "$instance_dir/run_evolution.sh"
    
    # Run the instance in background
    (
        timeout "${DURATION_HOURS}h" bash "$instance_dir/run_evolution.sh" > "logs/instance-${uuid}.log" 2>&1
        echo "Instance $uuid finished or timed out after $DURATION_HOURS hours"
    ) &
    
    # Store the PID
    echo $! > "pids/instance-${uuid}.pid"
}

# Create directories for logs and PIDs
mkdir -p logs pids

# Start time
START_TIME=$(date +%s)
echo "Starting Alpine Fix Evolution at $(date)"
echo "Instances: $INSTANCES"
echo "Duration: $DURATION_HOURS hours"
echo "Model: $MODEL"
echo "Evolution directory: $EVOLUTION_DIR"
echo ""

# Launch all instances
for i in $(seq 1 $INSTANCES); do
    run_instance $i
    sleep 2  # Small delay between launches
done

echo ""
echo "All $INSTANCES instances launched."
echo "Logs are in: $EVOLUTION_DIR/logs/"
echo "To monitor: tail -f $EVOLUTION_DIR/logs/*.log"
echo ""
echo "Waiting for instances to complete (max $DURATION_HOURS hours)..."

# Wait for all instances to complete
wait

# End time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "Evolution completed at $(date)"
echo "Total duration: $((DURATION / 3600))h $((DURATION % 3600 / 60))m"
echo ""

# Collect results
echo "Collecting results..."
cd "$BASE_DIR"

# Create results summary
cat > "$EVOLUTION_DIR/RESULTS.md" << REOF
# Alpine Fix Evolution Results

Started: $(date -d @$START_TIME)
Ended: $(date -d @$END_TIME)
Duration: $((DURATION / 3600))h $((DURATION % 3600 / 60))m

## Instances

REOF

# Check each instance's results
for uuid_file in $EVOLUTION_DIR/pids/*.pid; do
    if [ -f "$uuid_file" ]; then
        uuid=$(basename "$uuid_file" .pid | cut -d- -f2)
        echo "### Instance $uuid" >> "$EVOLUTION_DIR/RESULTS.md"
        
        # Check if the instance created a working image
        if docker images | grep -q "elixir-lean-vm-$uuid"; then
            echo "- Docker image created: elixir-lean-vm-$uuid" >> "$EVOLUTION_DIR/RESULTS.md"
            
            # Test if it works
            if docker run --rm "elixir-lean-vm-$uuid:latest" elixir -e 'IO.puts("OK")' 2>/dev/null | grep -q "OK"; then
                echo "- **SUCCESS**: Image runs Elixir correctly!" >> "$EVOLUTION_DIR/RESULTS.md"
                
                # Get image size
                SIZE=$(docker images --format "{{.Size}}" "elixir-lean-vm-$uuid:latest")
                echo "- Image size: $SIZE" >> "$EVOLUTION_DIR/RESULTS.md"
            else
                echo "- FAILED: Image does not run Elixir" >> "$EVOLUTION_DIR/RESULTS.md"
            fi
        else
            echo "- No Docker image found" >> "$EVOLUTION_DIR/RESULTS.md"
        fi
        
        echo "" >> "$EVOLUTION_DIR/RESULTS.md"
    fi
done

echo ""
echo "Results saved to: $EVOLUTION_DIR/RESULTS.md"
echo "To review solutions: cd $EVOLUTION_DIR && cat RESULTS.md"
echo ""
echo "To test a specific instance's solution:"
echo "  docker run --rm elixir-lean-vm-<uuid>:latest elixir -e 'IO.puts(\"Hello\")'"
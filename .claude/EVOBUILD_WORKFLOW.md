# EvoBuil Workflow: Parallel Evolution of Elixir Lean Lab

## Purpose

This workflow creates three parallel git branches using worktrees, enabling concurrent exploration of different architectural approaches based on deep recursive insights from the project's recent reflection phase. Each branch represents a different evolutionary path for achieving minimal sufficient Elixir VMs.

## Prerequisites

Before invoking this workflow:
1. Ensure git worktree is available: `git --version` (2.5+)
2. Have GitHub CLI installed: `gh --version`
3. Current branch should be clean: `git status`
4. Review recent reflections: `@./docs/PHILOSOPHY.md`, `@./docs/DEVELOPMENT_PROCESS.md`, `@./docs/NEXT_STEPS.md`

## Workflow Command

```
/execute-workflow evobuild-parallel-evolution
```

## Execution Steps

### Phase 1: Initialize Parallel Branches

```bash
# Generate UUIDs for each evolution branch
UUID1=$(uuidgen | cut -c1-8)
UUID2=$(uuidgen | cut -c1-8)
UUID3=$(uuidgen | cut -c1-8)

# Create branches from current main
git checkout main
git pull origin main
git branch evobuild-$UUID1
git branch evobuild-$UUID2
git branch evobuild-$UUID3

# Set up worktrees
mkdir -p ../elixir-lean-lab-evolutions
git worktree add ../elixir-lean-lab-evolutions/sufficiency-$UUID1 evobuild-$UUID1
git worktree add ../elixir-lean-lab-evolutions/validation-$UUID2 evobuild-$UUID2
git worktree add ../elixir-lean-lab-evolutions/hybrid-$UUID3 evobuild-$UUID3
```

### Phase 2: Evolution Branch Specifications

#### Branch 1: Sufficiency-Focused Evolution (evobuild-$UUID1)
**Thesis**: Implement minimal sufficient functionality based on use-case profiles

**Key References**:
- @./docs/PHILOSOPHY.md - "Sufficiency Over Size" principle
- @./docs/NEXT_STEPS.md - "Use Case Optimization" section
- Recent insight: "BEAM VM needs ~58MB minimum memory"

**Development Focus**:
1. Create use-case profile system:
   ```elixir
   defmodule ElixirLeanLab.Profiles.WebServer do
     @behaviour ElixirLeanLab.Profile
     def required_otp_apps, do: [:kernel, :stdlib, :crypto, :ssl, :inets]
     def optional_otp_apps, do: [:mnesia, :logger]
     def forbidden_otp_apps, do: [:wx, :debugger, :observer]
   end
   ```

2. Implement dynamic OTP loading:
   - Analyze application dependencies at build time
   - Create lazy-loading mechanism for optional components
   - Validate minimal sufficient set

3. Memory optimization focus:
   - Implement heap size tuning
   - Add atom table limits
   - Create binary reference sharing

**Success Metrics**:
- Web server profile: < 80MB with Phoenix
- IoT sensor profile: < 50MB
- Compute worker: < 45MB

#### Branch 2: Validation-First Evolution (evobuild-$UUID2)
**Thesis**: Every feature must be validated before considered complete

**Key References**:
- @./lib/elixir_lean_lab/validator.ex - Validation framework
- @./docs/DEVELOPMENT_PROCESS.md - "Validation Loop" section
- ConPort insight: "validation_driven_development" pattern

**Development Focus**:
1. Extend Validator module:
   ```elixir
   defmodule ElixirLeanLab.Validator.Continuous do
     def monitor_size_growth(image_path, baseline)
     def measure_boot_time(image_path)
     def measure_memory_usage(image_path, workload)
     def calculate_attack_surface(image_path)
   end
   ```

2. Create validation harnesses for each builder:
   - Buildroot: Actual kernel compilation and boot test
   - Nerves: Firmware flash and hardware simulation
   - Custom: Full QEMU boot with application test

3. Implement evidence-based progress tracking:
   - No feature complete without validation proof
   - Automated regression testing
   - Performance baseline enforcement

**Success Metrics**:
- 100% builder validation coverage
- < 5 second boot time for all builders
- Zero false "complete" statuses

#### Branch 3: Hybrid Architecture Evolution (evobuild-$UUID3)
**Thesis**: Combine BEAM's strengths with truly minimal runtimes

**Key References**:
- @./docs/PHILOSOPHY.md - "The Paradox of Minimalism"
- @./docs/NEXT_STEPS.md - "Hybrid Architecture" section
- Recent reflection: "Use BEAM where its strengths matter"

**Development Focus**:
1. Create hybrid builder combining BEAM + Rust/Zig:
   ```elixir
   defmodule ElixirLeanLab.Builder.Hybrid do
     use ElixirLeanLab.Builder.Behavior
     
     def build(config) do
       with {:ok, beam_core} <- build_minimal_beam(config),
            {:ok, native_workers} <- build_native_components(config),
            {:ok, bridge} <- build_port_bridge(config) do
         package_hybrid_system(beam_core, native_workers, bridge)
       end
     end
   end
   ```

2. Implement progressive enhancement:
   - Start with 15MB base (Rust core + minimal BEAM)
   - Hot-load OTP apps on demand
   - Native computation modules via ports

3. Security-first approach:
   - BEAM for coordination only
   - Native code for network-facing components
   - Capability-based security model

**Success Metrics**:
- Base system: < 20MB
- With full OTP: < 60MB
- 10x performance for compute tasks

### Phase 3: Concurrent Development Protocol

Each branch should:

1. **Maintain Validation Discipline**:
   ```bash
   # Before any commit in worktree
   mix test
   ./scripts/validate_builder.sh $BUILDER_TYPE
   git commit -m "feat: $FEATURE [validated: $EVIDENCE]"
   ```

2. **Track Progress with Evidence**:
   ```elixir
   # In each worktree's .claude/PROGRESS.md
   ## Branch: evobuild-$UUID
   ### Completed
   - Feature X: [Evidence: test_results/feature_x.log]
   - Optimization Y: [Benchmark: 15% size reduction]
   
   ### In Progress
   - Feature Z: [Blocker: BEAM minimum memory constraint]
   ```

3. **Cross-Pollinate Insights**:
   - Weekly sync meeting (async via PR comments)
   - Share breakthroughs via ConPort
   - Document failed approaches

### Phase 4: Leverage Claude Code Capabilities

**Latest Claude Code Features** (per Anthropic docs & community):

1. **Multi-file awareness**: Use `/analyze` to understand cross-module dependencies
2. **Semantic search**: Use `/search "lazy loading" --semantic` for finding similar patterns
3. **Concurrent operations**: Open multiple files with `/open lib/**/*.ex` for holistic view
4. **Memory integration**: Use MCP tools to persist insights across sessions

**Critical Analysis Points**:
- Question every size assumption: "Why does BEAM need 58MB?"
- Validate before implementing: "Will lazy loading actually help?"
- Measure everything: "What's the real cost of this feature?"

### Phase 5: Selection Criteria

After 2 weeks of parallel development:

1. **Quantitative Metrics**:
   - Actual VM sizes achieved
   - Boot times measured
   - Memory usage under load
   - Test coverage percentage

2. **Qualitative Assessment**:
   - Code maintainability
   - Architectural elegance
   - Future extensibility
   - Security posture

3. **Selection Process**:
   ```bash
   # Generate comparison report
   ./scripts/compare_evolutions.sh
   
   # Create PR for each branch
   gh pr create --base main --head evobuild-$UUID1 --title "Evolution 1: Sufficiency-Focused"
   gh pr create --base main --head evobuild-$UUID2 --title "Evolution 2: Validation-First"
   gh pr create --base main --head evobuild-$UUID3 --title "Evolution 3: Hybrid Architecture"
   
   # Community review period
   # Select winner or merge best aspects
   ```

## Intelligent Safeguards

1. **Physics Reality Check**: Don't promise what physics won't allow
2. **Validation Enforcement**: Code without proof isn't progress
3. **Insight Preservation**: Use ConPort/Memento for cross-branch learning
4. **Failure Documentation**: Failed approaches are valuable data

## Post-Evolution Protocol

1. **Merge Strategy**:
   - Cherry-pick best features from each branch
   - Create unified architecture document
   - Update all builders with winning patterns

2. **Cleanup**:
   ```bash
   # Remove worktrees
   git worktree remove ../elixir-lean-lab-evolutions/sufficiency-$UUID1
   git worktree remove ../elixir-lean-lab-evolutions/validation-$UUID2
   git worktree remove ../elixir-lean-lab-evolutions/hybrid-$UUID3
   
   # Delete non-selected branches
   git branch -D evobuild-$UUID1  # if not selected
   ```

3. **Knowledge Capture**:
   - Document why winning approach won
   - Archive alternative approaches for future reference
   - Update PHILOSOPHY.md with new insights

## Invocation Checklist

- [ ] Current branch is clean
- [ ] All tests passing
- [ ] Recent reflections reviewed
- [ ] ConPort/Memento accessible
- [ ] 2-week timeline acceptable
- [ ] Ready for parallel thinking

## Final Note

This workflow embodies the key insight from our reflection: **True progress requires parallel exploration with rigorous validation**. Each branch represents not just different code, but different philosophical approaches to the problem of minimal sufficient systems.

Remember: "The best code is not the code that's written, but the code that solves real problems in the real world."

---

*Generated based on deep recursive analysis of Elixir Lean Lab project, incorporating lessons from the "implementation illusion" and the principle of minimal sufficient functionality.*
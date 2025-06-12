# EvoBuil Parallel Workflow: Concurrent Independent Evolution

## Purpose

This workflow creates three parallel git branches using worktrees, enabling three independent instances to concurrently evolve the codebase based on the same insights and goals. Each instance works autonomously on improving the project, creating a diverse sample of development approaches and solutions.

## Core Concept

Rather than topically differentiated branches, we create three **peer instances** that:
- Start from the same baseline
- Have access to the same insights and reflections
- Work toward the same goals
- Develop independently without coordination
- Create natural variation in problem-solving approaches

This mimics having three skilled developers independently improving the codebase, then selecting the best outcomes.

## Prerequisites

Before invoking this workflow:
1. Ensure git worktree is available: `git --version` (2.5+)
2. Have GitHub CLI installed: `gh --version`
3. Current branch should be clean: `git status`
4. Review recent reflections: `@./docs/PHILOSOPHY.md`, `@./docs/DEVELOPMENT_PROCESS.md`, `@./docs/NEXT_STEPS.md`

## Workflow Command

```
/execute-workflow evobuild-parallel-instances
```

## Execution Steps

### Phase 1: Initialize Parallel Instances

```bash
# Generate UUIDs for each evolution instance
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
git worktree add ../elixir-lean-lab-evolutions/instance-$UUID1 evobuild-$UUID1
git worktree add ../elixir-lean-lab-evolutions/instance-$UUID2 evobuild-$UUID2
git worktree add ../elixir-lean-lab-evolutions/instance-$UUID3 evobuild-$UUID3

# Create instance identity files
echo "Instance ID: $UUID1" > ../elixir-lean-lab-evolutions/instance-$UUID1/.instance
echo "Instance ID: $UUID2" > ../elixir-lean-lab-evolutions/instance-$UUID2/.instance
echo "Instance ID: $UUID3" > ../elixir-lean-lab-evolutions/instance-$UUID3/.instance
```

### Phase 2: Shared Context for All Instances

Each instance receives the same briefing:

```markdown
## Development Brief

You are one of three parallel instances working to improve Elixir Lean Lab based on recent insights.

### Key Insights from Reflection:
1. The project achieved 77.5MB VMs but targeted 20-30MB (physics vs. wishful thinking)
2. "Implementation illusion" - code exists but isn't validated
3. Should optimize for "minimal sufficient" not "minimal possible"
4. BEAM VM has ~58MB irreducible complexity
5. Need validation-driven development

### Current State:
- Alpine builder: Verified working (77.5MB)
- Other builders: Implemented but not validated
- Architecture: Good modularity, poor shared abstractions
- Process: Activity ≠ Progress

### Your Mission:
Improve the codebase based on these insights. You have full autonomy to:
- Fix validation gaps
- Improve architecture
- Optimize builders
- Add new features
- Refactor existing code
- Update documentation

### Constraints:
- Respect physics (BEAM's 58MB minimum)
- Validate all claims with evidence
- Focus on real-world functionality
- Maintain code quality

Work independently. Make decisions based on your analysis. Commit frequently with clear messages.
```

### Phase 3: Independent Evolution Protocol

Each instance operates autonomously with:

1. **Decision Autonomy**:
   - Analyze codebase independently
   - Choose own priorities
   - Implement solutions as seen fit
   - No coordination with other instances

2. **Commit Pattern**:
   ```bash
   # Each instance commits with its UUID
   git commit -m "[$UUID] feat: Implement validation for Buildroot builder"
   git commit -m "[$UUID] refactor: Extract common VM packaging logic"
   git commit -m "[$UUID] fix: Correct memory calculation in Custom builder"
   ```

3. **Progress Tracking**:
   ```markdown
   # In each worktree: EVOLUTION_LOG.md
   ## Instance: $UUID
   ### Day 1
   - Analyzed codebase, identified validation gaps
   - Started with Buildroot builder validation
   - Fixed size calculation bug in VM module
   
   ### Day 2
   - Implemented shared behavior for builders
   - Added integration tests
   - Discovered Alpine builder has memory leak
   ```

### Phase 4: Natural Variation Emergence

Expected variations between instances:

- **Priority Differences**: One might focus on validation, another on optimization, third on architecture
- **Solution Approaches**: Different patterns for solving the same problems
- **Discovery Timing**: Bugs/improvements found at different times
- **Code Style**: Natural variations in implementation details
- **Feature Choices**: Different ideas for new capabilities

### Phase 5: Execution Guidelines

For each instance (run in separate terminal/session):

```bash
cd ../elixir-lean-lab-evolutions/instance-$UUID

# Launch Claude Code with full context
claude --working-directory . \
  --instructions "You are instance $UUID. Work autonomously to improve this codebase based on the development brief. Make decisions independently. Commit frequently."

# Or for manual development:
# 1. Review the codebase
# 2. Identify improvements
# 3. Implement changes
# 4. Validate with tests
# 5. Commit with [$UUID] prefix
```

### Phase 6: Parallel Execution Timeline

```
Day 0: Setup and briefing
Days 1-10: Independent development
Day 11: Freeze development
Days 12-13: Analysis and comparison
Day 14: Selection and merge
```

**No Synchronization Points** - Each instance works continuously without checkpoints or coordination.

### Phase 7: Analysis and Selection

After development period:

1. **Quantitative Analysis**:
   ```bash
   # For each instance
   ./scripts/analyze_evolution.sh $UUID
   
   # Metrics collected:
   - Lines changed
   - Tests added/passed
   - Performance improvements
   - Size optimizations achieved
   - Bugs fixed
   - Features added
   ```

2. **Qualitative Analysis**:
   - Code quality improvements
   - Architectural elegance
   - Problem-solving creativity
   - Validation completeness

3. **Comparison Matrix**:
   ```markdown
   | Metric | Instance 1 | Instance 2 | Instance 3 |
   |--------|------------|------------|------------|
   | Validations Added | 15 | 8 | 12 |
   | Size Reduction | 5% | 12% | 8% |
   | Bugs Fixed | 7 | 4 | 9 |
   | Architecture Improvements | Major | Minor | Moderate |
   ```

### Phase 8: Selection Strategy

**Multi-Strategy Selection**:

1. **Cherry-Pick Best Changes**:
   ```bash
   # Select best individual commits from each instance
   git cherry-pick $UUID1~5  # Great validation framework
   git cherry-pick $UUID2~12 # Excellent size optimization
   git cherry-pick $UUID3~8  # Clean architecture refactor
   ```

2. **Merge Entire Best Instance**:
   ```bash
   # If one instance is clearly superior
   git merge evobuild-$UUID2
   ```

3. **Hybrid Approach**:
   ```bash
   # Create new branch combining best elements
   git checkout -b main-evolved
   # Manually integrate best solutions from each
   ```

### Phase 9: Learning Extraction

Post-evolution analysis:

1. **Pattern Recognition**:
   - What improvements did all instances make?
   - What problems did all instances encounter?
   - What unique insights did each discover?

2. **Approach Diversity**:
   - How did solutions differ for same problems?
   - Which approaches were most effective?
   - What unexpected innovations emerged?

3. **Meta-Learning**:
   ```markdown
   ## Evolution Insights
   - Instance 1 focused heavily on testing (risk-averse approach)
   - Instance 2 went deep on optimization (performance-focused)
   - Instance 3 balanced features and fixes (pragmatic approach)
   
   Key Learning: Given same constraints, independent development 
   produces valuable diversity in solutions.
   ```

## Intelligence Amplification

Each instance should leverage:

1. **Full Claude Code Capabilities**:
   - `/plan` before major changes
   - `/search` for understanding codebase
   - `/analyze` for architectural decisions
   - Multi-file awareness for refactoring

2. **MCP Tools**:
   - Query previous decisions
   - Log progress and insights
   - Search for patterns

3. **Validation Tools**:
   - Run tests frequently
   - Benchmark changes
   - Document evidence

## Critical Principles

1. **True Independence**: No peeking at other instances' work
2. **Evidence-Based**: Every claim must be validated
3. **Respect Physics**: Don't promise impossible improvements
4. **Quality Focus**: Better to do few things well than many poorly
5. **Clear Documentation**: Future developers should understand decisions

## Cleanup Protocol

```bash
# After selection and merge
git worktree remove ../elixir-lean-lab-evolutions/instance-$UUID1
git worktree remove ../elixir-lean-lab-evolutions/instance-$UUID2
git worktree remove ../elixir-lean-lab-evolutions/instance-$UUID3

# Keep branches for historical analysis
git push origin evobuild-$UUID1
git push origin evobuild-$UUID2
git push origin evobuild-$UUID3

# Tag the evolution experiment
git tag -a "evobuild-experiment-$(date +%Y%m%d)" -m "Three-instance parallel evolution experiment"
```

## Expected Outcomes

Through parallel independent evolution, we expect:
- Diverse solutions to validation gaps
- Multiple approaches to size optimization
- Natural discovery of different bugs
- Varied architectural improvements
- Rich sample of development strategies

The best outcome: A codebase that incorporates the strongest elements from three independent improvement efforts.

---

*"In parallel evolution, we don't prescribe paths - we create conditions for emergence."*
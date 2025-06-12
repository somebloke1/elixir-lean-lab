# EvoBuil Insights: Intelligence Amplification for Parallel Evolution

## Recent Claude Code Capabilities (2024-2025)

Based on Anthropic documentation and community insights:

### 1. **Plan Mode** (`/plan`)
- Use before implementing to think through approach
- Generates comprehensive implementation strategy
- Example: `/plan Implement lazy OTP loading for web server profile`

### 2. **Semantic Code Understanding**
- Claude Code now understands architectural patterns
- Can identify code smells and suggest refactorings
- Use: "Find all places where we duplicate size calculation logic"

### 3. **Multi-Modal Analysis**
- Can analyze images of architecture diagrams
- Useful for understanding VM memory layouts
- Paste screenshots of `htop` or memory profilers

### 4. **Enhanced MCP Integration**
- Persistent memory across sessions via ConPort/Memento
- Can query previous decisions and rationale
- Example: `@mcp-conport:search_decisions_fts "size optimization"`

### 5. **Concurrent File Operations**
- Can modify multiple files in single operation
- Useful for refactoring across module boundaries
- Pattern: Open all builders → Extract common behavior → Apply changes

## Critical Insights from Recent Reflection

### The Implementation Illusion
**Key Learning**: Code that exists but doesn't work isn't "done"

**Application to EvoBuil**:
- Each branch must prove its claims with evidence
- No feature is complete without validation
- Document what ACTUALLY works, not what SHOULD work

### The 58MB Reality
**Key Learning**: BEAM VM has irreducible complexity (~58MB for hello world)

**Application to EvoBuil**:
- Stop fighting physics with wishful thinking
- Focus on what happens AFTER the 58MB baseline
- Optimize for efficient use of the remaining space

### The Sufficiency Principle
**Key Learning**: Optimize for "minimal sufficient" not "minimal possible"

**Application to EvoBuil**:
- Define sufficiency for each use case
- Remove only what's provably unnecessary
- Validate that removal doesn't break functionality

## Intelligence Amplification Strategies

### 1. **Cross-Branch Learning**
```elixir
# In each worktree, maintain a LEARNINGS.md
defmodule Learnings do
  def capture(insight, evidence) do
    ConPort.log_decision(
      summary: insight,
      rationale: evidence,
      tags: ["evobuild", branch_name()]
    )
  end
end
```

### 2. **Failure Fast, Learn Faster**
- If an approach isn't working by day 3, pivot
- Document why it failed
- Share failure insights across branches immediately

### 3. **Reality-Check Protocol**
Before implementing any optimization:
1. Measure current state
2. Calculate theoretical best case
3. If theory violates physics, stop
4. Implement with continuous measurement
5. Only claim success with evidence

### 4. **Use Claude's Strengths**
- **Pattern Recognition**: "Show me all error handling patterns in our codebase"
- **Code Generation**: Let Claude write boilerplate, focus on architecture
- **Refactoring**: "Extract this pattern into a shared behavior"
- **Testing**: "Generate comprehensive tests for this validation logic"

## Parallel Development Best Practices

### 1. **Daily Standup (Async)**
Each branch creates a daily update:
```markdown
## Day 5 Update - Branch: sufficiency-$UUID

### Progress
- Implemented profile system for web server
- Achieved 75MB with Phoenix (target: 80MB) ✓

### Blockers
- OTP app dependency analysis harder than expected
- Need better tooling for runtime profiling

### Insights
- Profile inheritance could reduce duplication
- Consider trait-based composition pattern
```

### 2. **Cross-Pollination Points**
- **Day 3**: Share first working prototypes
- **Day 7**: Mid-point architecture review
- **Day 10**: Performance benchmark comparison
- **Day 14**: Final demonstration prep

### 3. **Evidence Collection**
```bash
# Standardized evidence structure
evidence/
├── benchmarks/
│   ├── size_day1.json
│   ├── size_day7.json
│   └── size_day14.json
├── validations/
│   ├── boot_test_results.log
│   └── memory_profile.svg
└── decisions/
    └── why_we_chose_X.md
```

## Red Team Thinking

Each branch should challenge its own assumptions:

### Branch 1 (Sufficiency) Challenges:
- "What if use-case profiles are too rigid?"
- "How do we handle apps that span profiles?"
- "Is dynamic loading adding more complexity than value?"

### Branch 2 (Validation) Challenges:
- "Is 100% validation slowing progress too much?"
- "Are we measuring the right things?"
- "Could validation become a bottleneck?"

### Branch 3 (Hybrid) Challenges:
- "Is the complexity worth the size savings?"
- "How do we maintain BEAM's fault tolerance?"
- "What's the security boundary between BEAM and native?"

## Meta-Strategy: Evolution of Evolution

The workflow itself should evolve:
- If all branches hit the same blocker, that's signal
- If one branch significantly outpaces others, analyze why
- If none achieve goals, question the goals

## Integration with Claude Code Commands

### Useful Commands for EvoBuil:
```bash
# Analyze dependencies across modules
/analyze "OTP app usage" --deep

# Find similar patterns across branches
/search "size optimization" --include "**/*.ex" --semantic

# Plan complex refactoring
/plan "Extract common validation logic into shared behavior"

# Get help with specific challenge
/help "How to implement lazy loading in Erlang/OTP"
```

### MCP Queries for Context:
```elixir
# Get previous optimization attempts
@mcp-conport:search_decisions_fts "optimization"

# Find related patterns
@mcp-memento:semantic_search "minimal VM building"

# Track progress
@mcp-conport:log_progress status: "in_progress", 
  description: "Branch 1: Implemented profile system"
```

## Success Amplification

When something works in one branch:
1. Immediately document HOW and WHY
2. Create minimal reproducible example
3. Share with other branches
4. Consider if it invalidates other approaches

## Failure Value Extraction

When something fails:
1. Document what we expected vs. what happened
2. Identify incorrect assumptions
3. Share learning to prevent repeated failure
4. Consider if failure reveals fundamental constraint

---

*"In parallel evolution, diversity of approach is strength, but shared learning is power."*
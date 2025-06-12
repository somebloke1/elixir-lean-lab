#!/bin/bash
# CI script for running all quality checks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track overall status
EXIT_CODE=0

echo "🔍 Running CI checks for Elixir Lean Lab"
echo "========================================"
echo ""

cd "$PROJECT_ROOT"

# Function to run a check
run_check() {
    local name=$1
    local cmd=$2
    
    echo -n "Running $name... "
    
    if eval "$cmd" > /tmp/ci_output_$$.log 2>&1; then
        echo -e "${GREEN}✓ Passed${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
        echo ""
        echo "Output from $name:"
        cat /tmp/ci_output_$$.log
        echo ""
        EXIT_CODE=1
    fi
    
    rm -f /tmp/ci_output_$$.log
}

# Compile check
run_check "compilation" "mix compile --warnings-as-errors"

# Format check
run_check "code formatting" "mix format --check-formatted"

# Tests
echo ""
echo "Running tests..."
if mix test; then
    echo -e "${GREEN}✓ All tests passed${NC}"
else
    echo -e "${RED}✗ Tests failed${NC}"
    EXIT_CODE=1
fi

# Documentation
run_check "documentation generation" "mix docs"

# Dialyzer (if available)
if mix help dialyzer &> /dev/null 2>&1; then
    echo ""
    echo "Running Dialyzer (this may take a while on first run)..."
    if mix dialyzer; then
        echo -e "${GREEN}✓ Dialyzer passed${NC}"
    else
        echo -e "${YELLOW}⚠ Dialyzer warnings${NC} (non-blocking)"
    fi
else
    echo ""
    echo -e "${YELLOW}ℹ Dialyzer not available${NC}"
    echo "  Add {:dialyxir, \"~> 1.0\", only: [:dev], runtime: false} to deps"
fi

# Credo (if available)
if mix help credo &> /dev/null 2>&1; then
    echo ""
    echo "Running Credo..."
    if mix credo --strict; then
        echo -e "${GREEN}✓ Credo passed${NC}"
    else
        echo -e "${YELLOW}⚠ Credo suggestions${NC} (non-blocking)"
    fi
else
    echo ""
    echo -e "${YELLOW}ℹ Credo not available${NC}"
    echo "  Add {:credo, \"~> 1.6\", only: [:dev, :test], runtime: false} to deps"
fi

# Coverage report
echo ""
echo "Generating test coverage..."
if MIX_ENV=test mix test --cover; then
    echo -e "${GREEN}✓ Coverage report generated${NC}"
else
    echo -e "${YELLOW}⚠ Coverage generation failed${NC}"
fi

# Summary
echo ""
echo "========================================"
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ All CI checks passed!${NC}"
else
    echo -e "${RED}❌ Some CI checks failed${NC}"
fi

exit $EXIT_CODE
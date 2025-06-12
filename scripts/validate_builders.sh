#!/bin/bash
# Validation script for Elixir Lean Lab builders
# This script helps validate that all builders work correctly

set -e

echo "=== Elixir Lean Lab Builder Validation ==="
echo

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check dependencies
check_dependency() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 found"
    else
        echo -e "${RED}✗${NC} $1 not found"
        return 1
    fi
}

echo "Checking dependencies..."
echo "----------------------"
check_dependency "docker" || MISSING_DEPS=true
check_dependency "wget" || MISSING_DEPS=true
check_dependency "tar" || MISSING_DEPS=true
check_dependency "make" || MISSING_DEPS=true
check_dependency "mix" || MISSING_DEPS=true
echo

if [ "$MISSING_DEPS" = true ]; then
    echo -e "${RED}Missing dependencies detected. Some tests may fail.${NC}"
    echo
fi

# Function to run specific builder tests
run_builder_test() {
    local builder=$1
    echo -e "${YELLOW}Testing $builder builder...${NC}"
    
    # Run tests with timeout
    if timeout 300 mix test --only "$builder" --exclude slow 2>&1 | tee test_$builder.log; then
        echo -e "${GREEN}✓ $builder tests passed${NC}"
        return 0
    else
        echo -e "${RED}✗ $builder tests failed${NC}"
        return 1
    fi
}

# Run validation based on argument
case "${1:-all}" in
    alpine)
        run_builder_test alpine
        ;;
    buildroot)
        run_builder_test buildroot
        ;;
    nerves)
        run_builder_test nerves
        ;;
    custom)
        run_builder_test custom
        ;;
    all)
        echo "Running all builder validations..."
        echo "================================="
        echo
        
        # Track results
        ALPINE_RESULT="PENDING"
        BUILDROOT_RESULT="PENDING"
        NERVES_RESULT="PENDING"
        CUSTOM_RESULT="PENDING"
        
        # Run each builder test
        if run_builder_test alpine; then
            ALPINE_RESULT="PASSED"
        else
            ALPINE_RESULT="FAILED"
        fi
        echo
        
        if run_builder_test buildroot; then
            BUILDROOT_RESULT="PASSED"
        else
            BUILDROOT_RESULT="FAILED"
        fi
        echo
        
        if run_builder_test nerves; then
            NERVES_RESULT="PASSED"
        else
            NERVES_RESULT="FAILED"
        fi
        echo
        
        if run_builder_test custom; then
            CUSTOM_RESULT="PASSED"
        else
            CUSTOM_RESULT="FAILED"
        fi
        echo
        
        # Summary
        echo "================================="
        echo "Validation Summary"
        echo "================================="
        echo -e "Alpine:    $( [ "$ALPINE_RESULT" = "PASSED" ] && echo -e "${GREEN}$ALPINE_RESULT${NC}" || echo -e "${RED}$ALPINE_RESULT${NC}" )"
        echo -e "Buildroot: $( [ "$BUILDROOT_RESULT" = "PASSED" ] && echo -e "${GREEN}$BUILDROOT_RESULT${NC}" || echo -e "${RED}$BUILDROOT_RESULT${NC}" )"
        echo -e "Nerves:    $( [ "$NERVES_RESULT" = "PASSED" ] && echo -e "${GREEN}$NERVES_RESULT${NC}" || echo -e "${RED}$NERVES_RESULT${NC}" )"
        echo -e "Custom:    $( [ "$CUSTOM_RESULT" = "PASSED" ] && echo -e "${GREEN}$CUSTOM_RESULT${NC}" || echo -e "${RED}$CUSTOM_RESULT${NC}" )"
        ;;
    quick)
        echo "Running quick validation (unit tests only)..."
        mix test --exclude integration --exclude slow
        ;;
    *)
        echo "Usage: $0 [alpine|buildroot|nerves|custom|all|quick]"
        echo
        echo "  alpine     - Test Alpine builder"
        echo "  buildroot  - Test Buildroot builder"
        echo "  nerves     - Test Nerves builder"
        echo "  custom     - Test Custom builder"
        echo "  all        - Test all builders (default)"
        echo "  quick      - Run only fast unit tests"
        exit 1
        ;;
esac

echo
echo "Validation complete. Check test_*.log files for details."
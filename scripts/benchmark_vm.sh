#!/bin/bash
# Benchmark script for Elixir Lean Lab VMs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo -e "${BLUE}Elixir Lean Lab VM Benchmarking${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS] <image-path> [image-path2 ...]"
    echo ""
    echo "Options:"
    echo "  -r, --report FILE    Save benchmark report to file [default: benchmark-report.md]"
    echo "  -m, --memory MB      Memory allocation for VM [default: 256]"
    echo "  -c, --cpus NUM       Number of CPUs for VM [default: 1]"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 ./build/alpine-vm.tar.xz"
    echo "  $0 --report results.md ./build/*.tar.xz"
    echo "  $0 -m 512 -c 2 ./vm1.tar ./vm2.tar"
}

# Default values
REPORT_FILE="benchmark-report.md"
MEMORY=256
CPUS=1
IMAGES=()

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--report)
            REPORT_FILE="$2"
            shift 2
            ;;
        -m|--memory)
            MEMORY="$2"
            shift 2
            ;;
        -c|--cpus)
            CPUS="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
        *)
            IMAGES+=("$1")
            shift
            ;;
    esac
done

if [ ${#IMAGES[@]} -eq 0 ]; then
    echo -e "${RED}Error: No VM images specified${NC}"
    usage
    exit 1
fi

echo -e "${BLUE}🔬 Elixir Lean Lab VM Benchmarking${NC}"
echo -e "Images to test: ${GREEN}${#IMAGES[@]}${NC}"
echo -e "Memory: ${GREEN}${MEMORY}MB${NC}"
echo -e "CPUs: ${GREEN}${CPUS}${NC}"
echo ""

# Check prerequisites
if ! command -v docker &> /dev/null && [[ "${IMAGES[0]}" == *.tar* ]]; then
    echo -e "${YELLOW}⚠️  Docker not found. Docker images cannot be benchmarked.${NC}"
fi

cd "$PROJECT_ROOT"

# Build the benchmark command
BENCHMARK_COMMAND="
images = [
$(printf '  "%s",\n' "${IMAGES[@]}" | sed '$ s/,$//')
]

results = ElixirLeanLab.Benchmark.compare(images)
ElixirLeanLab.Benchmark.generate_report(results, \"$REPORT_FILE\")
"

# Run the benchmark
echo -e "${YELLOW}Running benchmarks...${NC}"
echo "$BENCHMARK_COMMAND" | mix run --no-halt -

echo ""
echo -e "${GREEN}✨ Benchmarking complete!${NC}"
echo -e "Report saved to: ${BLUE}$REPORT_FILE${NC}"
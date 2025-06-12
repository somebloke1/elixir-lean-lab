#!/bin/bash
# Build script for Elixir Lean Lab VMs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
VM_TYPE="alpine"
TARGET_SIZE=30
APP_PATH=""
OUTPUT_DIR="./build"

usage() {
    echo -e "${BLUE}Elixir Lean Lab VM Builder${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --type TYPE      VM type (alpine|buildroot|nerves|custom) [default: alpine]"
    echo "  -s, --size SIZE      Target size in MB [default: 30]"
    echo "  -a, --app PATH       Path to Elixir application to include"
    echo "  -o, --output DIR     Output directory [default: ./build]"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --type alpine --size 25 --app ./my_app"
    echo "  $0 -t alpine -s 20 -a ./hello_world -o ./output"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            VM_TYPE="$2"
            shift 2
            ;;
        -s|--size)
            TARGET_SIZE="$2"
            shift 2
            ;;
        -a|--app)
            APP_PATH="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

echo -e "${BLUE}🚀 Building Elixir Lean Lab VM${NC}"
echo -e "Type: ${GREEN}$VM_TYPE${NC}"
echo -e "Target Size: ${GREEN}${TARGET_SIZE}MB${NC}"
echo -e "Output: ${GREEN}$OUTPUT_DIR${NC}"

if [ -n "$APP_PATH" ]; then
    echo -e "App: ${GREEN}$APP_PATH${NC}"
fi

echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if [ "$VM_TYPE" = "alpine" ]; then
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker is required for Alpine builds${NC}"
        echo "Please install Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    echo -e "${GREEN}✅ Docker is installed${NC}"
fi

if ! command -v elixir &> /dev/null; then
    echo -e "${RED}❌ Elixir is required${NC}"
    echo "Please run ./scripts/setup.sh first"
    exit 1
fi
echo -e "${GREEN}✅ Elixir is installed${NC}"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Build using Elixir
echo ""
echo -e "${BLUE}Building VM...${NC}"

cd "$PROJECT_ROOT"

# Get dependencies if needed
if [ ! -d "deps" ]; then
    echo -e "${YELLOW}Getting dependencies...${NC}"
    mix deps.get
fi

# Compile the project
echo -e "${YELLOW}Compiling project...${NC}"
mix compile

# Build the VM using iex
echo -e "${YELLOW}Building VM image...${NC}"

if [ -n "$APP_PATH" ]; then
    APP_ARG="app: \"$APP_PATH\","
else
    APP_ARG=""
fi

BUILD_COMMAND="
{:ok, artifacts} = ElixirLeanLab.build(
  type: :$VM_TYPE,
  target_size: $TARGET_SIZE,
  $APP_ARG
  output: \"$OUTPUT_DIR\"
)

IO.puts(\"\\nBuild complete!\")
IO.puts(\"Image: #{artifacts.image}\")
IO.puts(\"Size: #{artifacts.size_mb} MB\")
"

echo "$BUILD_COMMAND" | mix run --no-halt -

echo ""
echo -e "${GREEN}✨ VM build complete!${NC}"
echo -e "Output files are in: ${BLUE}$OUTPUT_DIR${NC}"

# List output files
echo ""
echo -e "${YELLOW}Output files:${NC}"
ls -lah "$OUTPUT_DIR"
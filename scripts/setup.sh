#!/bin/bash
# Setup script for Elixir Lean Lab development environment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 Setting up Elixir Lean Lab development environment..."

# Check for required tools
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "❌ Error: $1 is not installed."
        echo "   Please install $1 before running this script."
        return 1
    else
        echo "✅ $1 is installed"
    fi
}

echo ""
echo "Checking prerequisites..."
check_command "elixir" || exit 1
check_command "mix" || exit 1

# Display versions
echo ""
echo "Environment versions:"
elixir --version | head -n 1
echo "Mix version: $(mix --version)"

# Install dependencies
echo ""
echo "Installing dependencies..."
cd "$PROJECT_ROOT"
mix deps.get

# Compile project
echo ""
echo "Compiling project..."
mix compile

# Setup database for ConPort if needed
if [ -d "context_portal" ]; then
    echo ""
    echo "Setting up ConPort database..."
    chmod 755 context_portal/
    if [ -f "context_portal/context.db" ]; then
        chmod 644 context_portal/context.db
    fi
fi

# Run tests to verify setup
echo ""
echo "Running tests to verify setup..."
mix test

# Check code quality tools
echo ""
echo "Checking code quality tools..."
if mix help format &> /dev/null; then
    echo "✅ mix format available"
else
    echo "⚠️  mix format not available"
fi

if mix help credo &> /dev/null 2>&1; then
    echo "✅ credo available"
else
    echo "⚠️  credo not available (optional: mix archive.install hex credo)"
fi

if mix help dialyzer &> /dev/null 2>&1; then
    echo "✅ dialyzer available"
else
    echo "⚠️  dialyzer not available (optional: add to mix.exs dependencies)"
fi

echo ""
echo "✨ Setup complete! You can now:"
echo "   - Run 'iex -S mix' to start an interactive shell"
echo "   - Run 'mix test' to run tests"
echo "   - Run 'mix format' to format code"
echo "   - Run './scripts/demo.sh' to see pipeline examples"
echo ""
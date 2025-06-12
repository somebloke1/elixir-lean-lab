#!/bin/bash
# Setup script for Elixir Lean Lab development environment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Setting up Elixir Lean Lab development environment...${NC}"
echo ""

# Function to check if a command exists
check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✅ $1 is installed${NC}"
        return 0
    else
        echo -e "${RED}❌ $1 is not installed${NC}"
        return 1
    fi
}

# Function to install asdf
install_asdf() {
    echo -e "${YELLOW}📦 Installing asdf version manager...${NC}"
    
    # Check if asdf directory already exists
    if [ -d "$HOME/.asdf" ]; then
        echo -e "${YELLOW}asdf directory already exists. Removing old installation...${NC}"
        rm -rf "$HOME/.asdf"
    fi
    
    # Clone asdf
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
    
    # Add to shell profile
    echo -e "${YELLOW}Adding asdf to shell configuration...${NC}"
    
    # For bash
    if [ -f ~/.bashrc ]; then
        # Check if asdf is already in bashrc
        if ! grep -q "asdf/asdf.sh" ~/.bashrc; then
            echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
            echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
        fi
    fi
    
    # For zsh
    if [ -f ~/.zshrc ]; then
        # Check if asdf is already in zshrc
        if ! grep -q "asdf/asdf.sh" ~/.zshrc; then
            echo '. "$HOME/.asdf/asdf.sh"' >> ~/.zshrc
            echo 'fpath=(${ASDF_DIR}/completions $fpath)' >> ~/.zshrc
            echo 'autoload -Uz compinit && compinit' >> ~/.zshrc
        fi
    fi
    
    # Source asdf for current session
    export ASDF_DIR="$HOME/.asdf"
    . "$HOME/.asdf/asdf.sh"
    
    echo -e "${GREEN}✅ asdf installed successfully${NC}"
}

# First, source asdf if it exists but isn't loaded
if [ -d "$HOME/.asdf" ] && ! command -v asdf &> /dev/null; then
    export ASDF_DIR="$HOME/.asdf"
    . "$HOME/.asdf/asdf.sh"
fi

# Check for asdf
echo -e "${BLUE}Checking for version management tools...${NC}"
if ! command -v asdf &> /dev/null; then
    # asdf not found in PATH
    if [ -d "$HOME/.asdf" ]; then
        echo -e "${YELLOW}asdf is installed but not loaded in your shell.${NC}"
        echo -e "${YELLOW}Loading asdf for this session...${NC}"
        export ASDF_DIR="$HOME/.asdf"
        . "$HOME/.asdf/asdf.sh"
        
        # Check if it's in shell config
        if [ -f ~/.bashrc ] && ! grep -q "asdf/asdf.sh" ~/.bashrc; then
            echo -e "${YELLOW}Adding asdf to ~/.bashrc...${NC}"
            echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
            echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
        fi
        
        if [ -f ~/.zshrc ] && ! grep -q "asdf/asdf.sh" ~/.zshrc; then
            echo -e "${YELLOW}Adding asdf to ~/.zshrc...${NC}"
            echo '. "$HOME/.asdf/asdf.sh"' >> ~/.zshrc
            echo 'fpath=(${ASDF_DIR}/completions $fpath)' >> ~/.zshrc
            echo 'autoload -Uz compinit && compinit' >> ~/.zshrc
        fi
    else
        echo -e "${RED}❌ asdf is not installed${NC}"
        echo -e "${YELLOW}Would you like to install asdf? (recommended) [y/N]${NC}"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            install_asdf
        else
            echo -e "${YELLOW}⚠️  Skipping asdf installation. You'll need to install Elixir/Erlang manually.${NC}"
        fi
    fi
else
    echo -e "${GREEN}✅ asdf is installed${NC}"
fi

# If asdf is available, set up Erlang and Elixir
if command -v asdf &> /dev/null; then
    echo ""
    echo -e "${BLUE}Setting up Erlang and Elixir with asdf...${NC}"
    
    # Add plugins if not already added
    if ! asdf plugin list | grep -q erlang; then
        echo -e "${YELLOW}Adding Erlang plugin...${NC}"
        asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
    fi
    
    if ! asdf plugin list | grep -q elixir; then
        echo -e "${YELLOW}Adding Elixir plugin...${NC}"
        asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git
    fi
    
    # Check for .tool-versions file
    if [ -f "$PROJECT_ROOT/.tool-versions" ]; then
        echo -e "${BLUE}Found .tool-versions file. Installing specified versions...${NC}"
        cd "$PROJECT_ROOT"
        asdf install
    else
        # Create .tool-versions with recommended versions
        echo -e "${YELLOW}Creating .tool-versions file with recommended versions...${NC}"
        cat > "$PROJECT_ROOT/.tool-versions" << EOF
erlang 26.2.1
elixir 1.15.7-otp-26
EOF
        cd "$PROJECT_ROOT"
        
        # Install Erlang dependencies first (for Ubuntu/Debian)
        if command -v apt-get &> /dev/null; then
            echo -e "${YELLOW}Installing Erlang build dependencies (may require sudo)...${NC}"
            sudo apt-get update
            
            # Core build dependencies
            sudo apt-get install -y build-essential autoconf m4 libncurses5-dev \
                libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev \
                unixodbc-dev xsltproc fop libxml2-utils libncurses-dev
            
            # Try to install wxWidgets (package names vary by Debian version)
            if apt-cache show libwxgtk3.2-dev &> /dev/null; then
                echo -e "${YELLOW}Installing wxWidgets 3.2...${NC}"
                sudo apt-get install -y libwxgtk3.2-dev libwxgtk-webview3.2-dev
            elif apt-cache show libwxgtk3.0-gtk3-dev &> /dev/null; then
                echo -e "${YELLOW}Installing wxWidgets 3.0...${NC}"
                sudo apt-get install -y libwxgtk3.0-gtk3-dev libwxgtk-webview3.0-gtk3-dev
            else
                echo -e "${YELLOW}⚠️  wxWidgets development packages not found. GUI features may be limited.${NC}"
            fi
            
            # Try to install Java (package names vary)
            if apt-cache show default-jdk &> /dev/null; then
                sudo apt-get install -y default-jdk
            elif apt-cache show openjdk-17-jdk &> /dev/null; then
                sudo apt-get install -y openjdk-17-jdk
            elif apt-cache show openjdk-11-jdk &> /dev/null; then
                sudo apt-get install -y openjdk-11-jdk
            else
                echo -e "${YELLOW}⚠️  Java JDK not found. Some Erlang features may be limited.${NC}"
            fi
        elif command -v brew &> /dev/null; then
            echo -e "${YELLOW}Installing Erlang build dependencies...${NC}"
            brew install autoconf openssl wxwidgets libxslt fop
        fi
        
        echo -e "${YELLOW}Installing Erlang 26.2.1 (this may take several minutes)...${NC}"
        asdf install erlang 26.2.1
        
        echo -e "${YELLOW}Installing Elixir 1.15.7-otp-26...${NC}"
        asdf install elixir 1.15.7-otp-26
        
        # Set as local versions
        asdf local erlang 26.2.1
        asdf local elixir 1.15.7-otp-26
    fi
    
    echo -e "${GREEN}✅ Erlang and Elixir configured with asdf${NC}"
fi

# Check for Elixir and Mix
echo ""
echo -e "${BLUE}Checking for Elixir installation...${NC}"
if ! check_command "elixir"; then
    echo -e "${RED}❌ Elixir is not installed or not in PATH${NC}"
    echo ""
    echo -e "${YELLOW}Installation options:${NC}"
    echo "1. Use asdf (recommended) - restart this script after installing asdf"
    echo "2. Manual installation:"
    echo "   - macOS: brew install elixir"
    echo "   - Ubuntu/Debian: apt-get install elixir"
    echo "   - Or visit: https://elixir-lang.org/install.html"
    exit 1
fi

if ! check_command "mix"; then
    echo -e "${RED}❌ Mix is not available (should come with Elixir)${NC}"
    exit 1
fi

# Display versions
echo ""
echo -e "${BLUE}Environment versions:${NC}"
echo -e "${GREEN}$(elixir --version | head -n 1)${NC}"
echo -e "${GREEN}Mix version: $(mix --version)${NC}"

# Install dependencies
echo ""
echo -e "${BLUE}Installing project dependencies...${NC}"
cd "$PROJECT_ROOT"

# Ensure Hex is installed
echo -e "${YELLOW}Ensuring Hex package manager is installed...${NC}"
mix local.hex --force

# Ensure rebar is installed (needed for some Erlang dependencies)
echo -e "${YELLOW}Ensuring rebar is installed...${NC}"
mix local.rebar --force

# Get dependencies
echo -e "${YELLOW}Fetching project dependencies...${NC}"
mix deps.get

# Compile project
echo ""
echo -e "${BLUE}Compiling project...${NC}"
mix compile

# Run tests to verify setup
echo ""
echo -e "${BLUE}Running tests to verify setup...${NC}"
if mix test; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
else
    echo -e "${YELLOW}⚠️  Some tests failed. Check the output above.${NC}"
fi

# Check code quality tools
echo ""
echo -e "${BLUE}Checking code quality tools...${NC}"
if mix help format &> /dev/null; then
    echo -e "${GREEN}✅ mix format available${NC}"
else
    echo -e "${YELLOW}⚠️  mix format not available${NC}"
fi

if mix help credo &> /dev/null 2>&1; then
    echo -e "${GREEN}✅ credo available${NC}"
else
    echo -e "${YELLOW}⚠️  credo not available${NC}"
    echo -e "${YELLOW}   To install: mix archive.install hex credo${NC}"
fi

if mix help dialyzer &> /dev/null 2>&1; then
    echo -e "${GREEN}✅ dialyzer available${NC}"
else
    echo -e "${YELLOW}⚠️  dialyzer not available${NC}"
    echo -e "${YELLOW}   To install: add {:dialyxir, "~> 1.0", only: [:dev], runtime: false} to mix.exs${NC}"
fi

# Additional setup instructions
echo ""
echo -e "${BLUE}=== Additional Setup Instructions ===${NC}"
echo ""
echo -e "${YELLOW}For VS Code users:${NC}"
echo "1. Install the ElixirLS extension for Elixir language support"
echo "2. The project already includes .formatter.exs for consistent code formatting"
echo ""
echo -e "${YELLOW}For other editors:${NC}"
echo "1. Vim/Neovim: Consider using vim-elixir and ALE or coc.nvim with elixir-ls"
echo "2. Emacs: Use elixir-mode and optionally alchemist or lsp-mode"
echo "3. IntelliJ: Install the Elixir plugin"
echo ""
echo -e "${YELLOW}Recommended development workflow:${NC}"
echo "1. Run tests continuously: mix test.watch (requires mix_test_watch dependency)"
echo "2. Format on save: Configure your editor to run mix format"
echo "3. Use IEx for interactive development: iex -S mix"
echo "4. Run the demo: ./scripts/demo.sh"
echo ""
echo -e "${GREEN}✨ Setup complete!${NC}"
echo ""
echo -e "${BLUE}Quick start commands:${NC}"
echo "   ${GREEN}iex -S mix${NC}        - Start interactive Elixir shell with project loaded"
echo "   ${GREEN}mix test${NC}          - Run all tests"
echo "   ${GREEN}mix format${NC}        - Format all code files"
echo "   ${GREEN}mix docs${NC}          - Generate documentation (if ex_doc is installed)"
echo "   ${GREEN}./scripts/demo.sh${NC} - Run pipeline demonstrations"
echo "   ${GREEN}./scripts/ci.sh${NC}   - Run full CI suite locally"
echo ""

# Final check for common issues
if [ ! -f "$PROJECT_ROOT/.tool-versions" ]; then
    echo -e "${YELLOW}Note: No .tool-versions file found. The setup script created one with:${NC}"
    echo "   Erlang: 26.2.1"
    echo "   Elixir: 1.15.7-otp-26"
fi

if [ -n "$GITHUB_ACTIONS" ]; then
    echo -e "${BLUE}Running in GitHub Actions environment${NC}"
fi
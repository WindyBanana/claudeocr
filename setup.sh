#!/usr/bin/env bash
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print colored output
print_info() { echo -e "${CYAN}ℹ ${NC}$1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_header() { echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# Check if uv is installed
check_uv() {
    if command -v uv &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Get uv version
get_uv_version() {
    uv --version 2>/dev/null | head -n1 || echo "unknown"
}

# Ask for confirmation
confirm() {
    local prompt="$1"
    local default="${2:-n}"

    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi

    read -p "$prompt" response
    response=${response:-$default}

    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Install uv on Linux
install_uv_linux() {
    print_info "Installing uv for Linux..."
    curl -LsSf https://astral.sh/uv/install.sh | sh

    # Add to PATH for current session
    export PATH="$HOME/.local/bin:$PATH"

    print_warning "You may need to restart your terminal or run:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
}

# Install uv on macOS
install_uv_macos() {
    print_info "Checking for Homebrew..."

    if command -v brew &> /dev/null; then
        print_success "Homebrew found"
        print_info "Installing uv via Homebrew..."
        brew install uv
    else
        print_warning "Homebrew not found. Using curl installer..."
        curl -LsSf https://astral.sh/uv/install.sh | sh

        # Add to PATH for current session
        export PATH="$HOME/.local/bin:$PATH"

        print_warning "You may need to restart your terminal or run:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
}

# Install uv on Windows
install_uv_windows() {
    print_info "Installing uv for Windows..."

    # Check if running in PowerShell or Git Bash
    if [[ -n "$POWERSHELL_DISTRIBUTION_CHANNEL" ]]; then
        # PowerShell
        print_info "Detected PowerShell. Please run this command manually:"
        echo ""
        echo "  powershell -c \"irm https://astral.sh/uv/install.ps1 | iex\""
        echo ""
        print_warning "After installation, restart your terminal."
        return 1
    else
        # Git Bash or similar
        print_info "Installing via curl..."
        curl -LsSf https://astral.sh/uv/install.sh | sh

        print_warning "You may need to restart your terminal."
    fi
}

# Main installation function
install_uv() {
    local os=$(detect_os)

    print_info "Detected OS: $os"

    case "$os" in
        linux)
            install_uv_linux
            ;;
        macos)
            install_uv_macos
            ;;
        windows)
            install_uv_windows
            ;;
        *)
            print_error "Unsupported operating system: $OSTYPE"
            print_info "Please install uv manually from: https://docs.astral.sh/uv/getting-started/installation/"
            return 1
            ;;
    esac

    return 0
}

# Check Python version
check_python() {
    print_info "Checking Python version..."

    if command -v python3 &> /dev/null; then
        local version=$(python3 --version 2>&1 | awk '{print $2}')
        local major=$(echo $version | cut -d. -f1)
        local minor=$(echo $version | cut -d. -f2)

        print_success "Python $version found"

        if [[ $major -eq 3 ]] && [[ $minor -ge 12 ]]; then
            print_success "Python version is compatible (3.12+)"
            return 0
        else
            print_warning "Python 3.12+ recommended (found $version)"
            print_info "The project may still work, but consider upgrading"
            return 0
        fi
    else
        print_error "Python 3 not found"
        print_info "Please install Python 3.12+ from: https://www.python.org/downloads/"
        return 1
    fi
}

# Setup project
setup_project() {
    print_header "Setting Up Project"

    # Check if .env exists
    if [[ ! -f .env ]]; then
        print_info "Creating .env file from template..."
        if [[ -f .env.example ]]; then
            cp .env.example .env
            print_success "Created .env file"
            print_warning "Please edit .env and add your API keys:"
            echo "  ANTHROPIC_API_KEY=your-key-here"
            echo "  OPENAI_API_KEY=your-key-here (optional)"
        else
            print_warning ".env.example not found, creating blank .env"
            touch .env
        fi
    else
        print_success ".env file already exists"
    fi

    # Install dependencies
    print_info "Installing Python dependencies..."
    uv sync
    print_success "Dependencies installed"

    # Create directories
    print_info "Creating required directories..."
    mkdir -p input processed failed review logs
    print_success "Directories created"
}

# Main script
main() {
    print_header "Note Transcriber Setup Script"

    print_info "This script will check for uv and install it if needed."
    echo ""

    # Detect OS
    OS=$(detect_os)
    print_info "Operating System: $OS"

    # Check Python
    if ! check_python; then
        print_error "Python check failed. Please install Python 3.12+ first."
        exit 1
    fi

    echo ""

    # Check if uv is installed
    if check_uv; then
        local version=$(get_uv_version)
        print_success "uv is already installed: $version"
        echo ""

        if confirm "Do you want to proceed with project setup?"; then
            setup_project
            print_success "Setup complete!"
        else
            print_info "Setup cancelled."
            exit 0
        fi
    else
        print_warning "uv is not installed"
        echo ""
        print_info "uv is required to manage Python dependencies for this project."
        print_info "It will be installed to your user directory (no sudo required)."
        echo ""

        case "$OS" in
            linux)
                print_info "Installation method: curl script → ~/.local/bin/"
                ;;
            macos)
                if command -v brew &> /dev/null; then
                    print_info "Installation method: Homebrew"
                else
                    print_info "Installation method: curl script → ~/.local/bin/"
                fi
                ;;
            windows)
                print_info "Installation method: PowerShell script or curl"
                ;;
        esac

        echo ""

        if confirm "Do you want to install uv now?"; then
            if install_uv; then
                print_success "uv installed successfully!"

                # Verify installation
                if check_uv; then
                    local version=$(get_uv_version)
                    print_success "Verified: $version"
                    echo ""

                    if confirm "Do you want to proceed with project setup?"; then
                        setup_project
                        print_success "Setup complete!"
                    else
                        print_info "Setup cancelled. Run this script again when ready."
                        exit 0
                    fi
                else
                    print_warning "uv was installed but not found in PATH."
                    print_info "Please restart your terminal and run this script again."
                    exit 1
                fi
            else
                print_error "Installation failed or was cancelled."
                exit 1
            fi
        else
            print_info "Installation cancelled."
            print_info "You can install uv manually from: https://docs.astral.sh/uv/"
            exit 0
        fi
    fi

    echo ""
    print_header "Next Steps"
    echo ""
    echo "1. Add your API key to .env:"
    echo "   ${CYAN}nano .env${NC}  (or use any text editor)"
    echo ""
    echo "2. Add images to process:"
    echo "   ${CYAN}cp your_photos/*.jpg input/${NC}"
    echo ""
    echo "3. Run the program:"
    echo "   ${CYAN}uv run python main.py${NC}"
    echo ""
    echo "For more information, see:"
    echo "  - README.md - Complete documentation"
    echo "  - QUICK_REFERENCE.md - Quick start guide"
    echo "  - VALIDATION_GUIDE.md - Validation system details"
    echo ""
}

# Run main function
main

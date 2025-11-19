#!/usr/bin/env bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

INSTALL_DIR="/usr/local/bin"
LIB_DIR="/usr/local/lib/backmeup"
REPO_URL="https://raw.githubusercontent.com/metharda/backmeup/main"

echo ""
echo "====== BackMeUp Installer ======"
echo ""

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    log_error "This script only supports Linux"
    exit 1
fi
if [[ $EUID -ne 0 ]] && [[ ! -w "$INSTALL_DIR" ]]; then
    log_warning "This script may require sudo permissions"
    echo ""
fi

if [[ -f "$REPO_ROOT/backmeup.sh" && -f "$SCRIPT_DIR/backup.sh" && -f "$SCRIPT_DIR/cron.sh" ]]; then
    log_info "Running from repository directory"
    log_success "All required files found"
    
    if [[ ! -w "$INSTALL_DIR" ]]; then
        SUDO="sudo"
    else
        SUDO=""
    fi
    
    log_info "Installing BackMeUp..."
    
    $SUDO mkdir -p "$LIB_DIR"
    
    $SUDO cp "$REPO_ROOT/backmeup.sh" "$INSTALL_DIR/backmeup"
    $SUDO cp "$SCRIPT_DIR/backup.sh" "$LIB_DIR/"
    $SUDO cp "$SCRIPT_DIR/cron.sh" "$LIB_DIR/"
    $SUDO cp "$SCRIPT_DIR/install.sh" "$LIB_DIR/"
    $SUDO cp "$SCRIPT_DIR/uninstall.sh" "$LIB_DIR/"
    
    $SUDO chmod +x "$INSTALL_DIR/backmeup"
    $SUDO chmod +x "$LIB_DIR/backup.sh"
    $SUDO chmod +x "$LIB_DIR/cron.sh"
    $SUDO chmod +x "$LIB_DIR/install.sh"
    $SUDO chmod +x "$LIB_DIR/uninstall.sh"
else
    log_info "Downloading from GitHub..."
    if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
        log_error "curl or wget is required"
        echo "Install with: sudo apt-get install curl"
        exit 1
    fi
    DOWNLOAD_CMD=""
    if command -v curl &>/dev/null; then
        DOWNLOAD_CMD="curl -fsSL"
    elif command -v wget &>/dev/null; then
        DOWNLOAD_CMD="wget -qO-"
    fi
    if [[ ! -w "$INSTALL_DIR" ]]; then
        SUDO="sudo"
    else
        SUDO=""
    fi
    log_info "Downloading scripts..."
    
    $SUDO mkdir -p "$LIB_DIR"
    
    $DOWNLOAD_CMD "$REPO_URL/backmeup.sh" | $SUDO tee "$INSTALL_DIR/backmeup" >/dev/null
    $DOWNLOAD_CMD "$REPO_URL/scripts/backup.sh" | $SUDO tee "$LIB_DIR/backup.sh" >/dev/null
    $DOWNLOAD_CMD "$REPO_URL/scripts/cron.sh" | $SUDO tee "$LIB_DIR/cron.sh" >/dev/null
    $DOWNLOAD_CMD "$REPO_URL/scripts/install.sh" | $SUDO tee "$LIB_DIR/install.sh" >/dev/null
    $DOWNLOAD_CMD "$REPO_URL/scripts/uninstall.sh" | $SUDO tee "$LIB_DIR/uninstall.sh" >/dev/null
    
    $SUDO chmod +x "$INSTALL_DIR/backmeup"
    $SUDO chmod +x "$LIB_DIR/backup.sh"
    $SUDO chmod +x "$LIB_DIR/cron.sh"
    $SUDO chmod +x "$LIB_DIR/install.sh"
    $SUDO chmod +x "$LIB_DIR/uninstall.sh"
    
    log_success "Scripts downloaded"
fi

if [[ -f "$INSTALL_DIR/backmeup" ]]; then
    log_success "BackMeUp installed successfully!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "          Installation Complete         "
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Binary:     $INSTALL_DIR/backmeup"
    echo " Library:    $LIB_DIR"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Get started:"
    echo "  backmeup backup start -i"
    echo ""
    echo "For help:"
    echo "  backmeup backup help"
    echo ""
    echo "To uninstall:"
    echo "  backmeup uninstall"
    echo ""
else
    log_error "Installation failed"
    exit 1
fi

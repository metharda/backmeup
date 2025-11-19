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
    
    log_info "Copying scripts..."
    for script in "$SCRIPT_DIR"/*.sh; do
        if [[ -f "$script" ]]; then
            script_name=$(basename "$script")
            $SUDO cp "$script" "$LIB_DIR/"
            $SUDO chmod +x "$LIB_DIR/$script_name"
            log_success "Copied: $script_name"
        fi
    done
    
    $SUDO cp "$REPO_ROOT/backmeup.sh" "$INSTALL_DIR/backmeup"
    $SUDO chmod +x "$INSTALL_DIR/backmeup"
    log_success "Installed: backmeup"
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
    
    log_info "Downloading backmeup.sh..."
    $DOWNLOAD_CMD "$REPO_URL/backmeup.sh" | $SUDO tee "$INSTALL_DIR/backmeup" >/dev/null
    $SUDO chmod +x "$INSTALL_DIR/backmeup"
    log_success "Downloaded: backmeup"
    
    log_info "Fetching script list from GitHub..."
    GITHUB_API="https://api.github.com/repos/metharda/backmeup/contents/scripts"
    
    if command -v curl &>/dev/null; then
        SCRIPT_LIST=$(curl -fsSL "$GITHUB_API" 2>/dev/null | grep '"name"' | grep '\.sh"' | sed 's/.*"name": "\(.*\.sh\)".*/\1/')
    elif command -v wget &>/dev/null; then
        SCRIPT_LIST=$(wget -qO- "$GITHUB_API" 2>/dev/null | grep '"name"' | grep '\.sh"' | sed 's/.*"name": "\(.*\.sh\)".*/\1/')
    fi
    
    if [[ -z "$SCRIPT_LIST" ]]; then
        log_warning "Could not fetch script list from API, using default list..."
        SCRIPT_LIST="backup.sh cron.sh install.sh uninstall.sh ssh_utils.sh logger.sh"
    fi
    
    for script_name in $SCRIPT_LIST; do
        log_info "Downloading $script_name..."
        if $DOWNLOAD_CMD "$REPO_URL/scripts/$script_name" | $SUDO tee "$LIB_DIR/$script_name" >/dev/null 2>&1; then
            $SUDO chmod +x "$LIB_DIR/$script_name"
            log_success "Downloaded: $script_name"
        else
            log_warning "Failed to download: $script_name (skipping)"
        fi
    done
    
    log_success "All scripts downloaded"
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

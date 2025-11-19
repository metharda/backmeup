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

INSTALL_DIR="/usr/local/bin"
LIB_DIR="/usr/local/lib/backmeup"
CONFIG_DIR="${HOME}/.config/backmeup"
CONFIG_FILE="${CONFIG_DIR}/backups.conf"

echo ""
echo "====== BackMeUp Uninstaller ======"
echo ""

if [[ ! -f "$INSTALL_DIR/backmeup" ]]; then
    log_warning "BackMeUp is not installed"
    exit 0
fi
read -p "Are you sure you want to uninstall BackMeUp? (y/N): " confirm
if [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]]; then
    log_info "Uninstall cancelled"
    exit 0
fi
read -p "Remove all backup configurations and scripts? (y/N): " remove_configs
echo ""
if [[ ! -w "$INSTALL_DIR" ]]; then
    SUDO="sudo"
else
    SUDO=""
fi

log_info "Removing BackMeUp binaries..."
$SUDO rm -f "$INSTALL_DIR/backmeup"
log_success "Binary removed"

log_info "Removing library files..."
$SUDO rm -rf "$LIB_DIR"
log_success "Library removed"

if [[ "$remove_configs" == "y" ]] || [[ "$remove_configs" == "Y" ]]; then
    log_info "Removing backup configurations..."
    
    if [[ -f "$CONFIG_FILE" ]]; then
        while IFS='|' read -r name source output script schedule count compression; do
            if [[ -f "$script" ]]; then
                log_info "Removing backup script: $script"
                rm -f "$script"
                
                backmeup_dir="$(dirname "$script")"
                if [[ -d "$backmeup_dir" ]] && [[ "$(basename "$backmeup_dir")" == ".backmeup" ]]; then
                    if [[ -z "$(ls -A "$backmeup_dir" 2>/dev/null)" ]]; then
                        rmdir "$backmeup_dir"
                        log_info "Removed .backmeup directory: $backmeup_dir"
                    fi
                fi
            fi
            
            log_info "Removing cron job for: $name"
            crontab -l 2>/dev/null | grep -v "BackMeUp: backup_${name}" | crontab - 2>/dev/null || true
        done < "$CONFIG_FILE"
        
        log_success "Backup scripts removed"
    fi
    
    if [[ -d "$CONFIG_DIR" ]]; then
        log_info "Removing configuration directory..."
        rm -rf "$CONFIG_DIR"
        log_success "Configuration removed"
    fi
    
    remaining_crons=$(crontab -l 2>/dev/null | grep -i "backmeup" | wc -l | tr -d ' ')
    if [[ "$remaining_crons" -gt 0 ]]; then
        log_warning "Found $remaining_crons remaining BackMeUp cron jobs"
        read -p "Remove all BackMeUp cron jobs? (y/N): " remove_crons
        if [[ "$remove_crons" == "y" ]] || [[ "$remove_crons" == "Y" ]]; then
            crontab -l 2>/dev/null | grep -iv "backmeup" | crontab - 2>/dev/null || true
            log_success "Cron jobs removed"
        fi
    fi
else
    log_warning "Backup configurations kept"
    log_info "Config location: $CONFIG_DIR"
    if [[ -f "$CONFIG_FILE" ]]; then
        backup_count=$(wc -l < "$CONFIG_FILE" | tr -d ' ')
        log_info "Active backups: $backup_count"
    fi
fi
log_success "BackMeUp has been uninstalled"

echo ""
echo "====== Uninstall Complete ======"
echo ""


if [[ "$remove_configs" != "y" ]] && [[ "$remove_configs" != "Y" ]]; then
    echo ""
    log_info "To remove configurations later, run:"
    echo "  rm -rf $CONFIG_DIR"
    echo ""
fi

echo "Thank you for using BackMeUp!"
echo ""

#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

convert_time_period_to_cron() {
    local time_period="$1"
    
    case "$time_period" in
        hourly)
            echo "0 * * * *"
            ;;
        daily)
            echo "0 2 * * *"
            ;;
        weekly)
            echo "0 2 * * 0"
            ;;
        monthly)
            echo "0 2 1 * *"
            ;;
        *)
            echo "$time_period"
            ;;
    esac
}

add(){
    local script_path="$1"
    local time_period="$2"
    
    if [[ -z "$script_path" ]]; then
        log_error "Script path is required"
        return 1
    fi
    
    if [[ -z "$time_period" ]]; then
        log_error "Time period is required"
        return 1
    fi
    
    log_info "$script_path found"
    
    local cron_schedule=$(convert_time_period_to_cron "$time_period")
    local cron_entry="$cron_schedule /usr/bin/env bash $script_path # $(basename "$script_path")"
    
    log_info "Adding cron job..."
    log_info "Cron schedule: $cron_schedule"
    log_info "Cron entry: $cron_entry"
    
    local current_crontab=$(crontab -l 2>/dev/null || echo "")
    
    log_info "Current crontab content:"
    if [[ -z "$current_crontab" ]]; then
        log_info "  (empty)"
    else
        echo "$current_crontab"
    fi
    
    if echo "$current_crontab" | grep -q "$(basename "$script_path")"; then
        log_warning "A cron job for this backup already exists"
        read -p "Do you want to update it? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "Skipped"
            return 0
        fi
        current_crontab=$(echo "$current_crontab" | grep -v "$(basename "$script_path")")
    fi
    
    log_info "Writing to crontab..."
    {
        echo "$current_crontab"
        echo "$cron_entry"
    } | crontab -
    
    if [[ $? -eq 0 ]]; then
        log_success "Cron job added successfully"
        log_info "Schedule: $cron_schedule"
        log_info "Script: $script_path"
        return 0
    else
        log_error "Failed to add cron job"
        return 1
    fi
}

remove(){
    local backup_name="$1"
    local config_file="$HOME/.config/backmeup/backups.conf"
    
    if [[ -z "$backup_name" ]]; then
        log_error "Backup name is required"
        return 1
    fi
    
    local script_path=$(grep "^${backup_name}|" "$config_file" 2>/dev/null | cut -d'|' -f4)
    
    if [[ -z "$script_path" ]]; then
        log_error "Backup '$backup_name' not found in config"
        return 1
    fi
    
    log_info "Removing cron job for: $script_path"
    
    local current_crontab=$(crontab -l 2>/dev/null || echo "")
    
    if ! echo "$current_crontab" | grep -q "$script_path"; then
        log_warning "No cron job found for this backup"
        return 0
    fi
    
    local updated_crontab=$(echo "$current_crontab" | grep -v "$script_path")
    
    echo "$updated_crontab" | crontab -
    
    if [[ $? -eq 0 ]]; then
        log_success "Cron job removed successfully"
        return 0
    else
        log_error "Failed to remove cron job"
        return 1
    fi
}

command(){
    local command=$1
    shift
    case $command in
        "add")
            add "$@"
            ;;
        "remove")
            remove "$@"
            ;;
        "help"|"--help"|"-h")
            echo "Usage: cron.sh <command> [options]"
            echo "Commands:"
            echo "  add <script_path> <time_period>     Add a new cron job"
            echo "  remove <script_path>                 Remove an existing cron job"
            ;;
        "")
            echo "Error: No command specified"
            ;;
        *)
            echo "Error: Unknown command '$command'"
            ;;
    esac
}

command "$@"
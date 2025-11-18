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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${HOME}/.config/backmeup"
CONFIG_FILE="${CONFIG_DIR}/backups.conf"
SCRIPT_PATH=""

init_config() {
    if [[ ! -d "${CONFIG_DIR}" ]]; then
        mkdir -p "${CONFIG_DIR}"
    fi
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        touch "${CONFIG_FILE}"
    fi
}

save_backup_config() {
    local backup_name="$1"
    local source_dir="$2"
    local output_dir="$3"
    local script_path="$4"
    local time_period="$5"
    local backup_count="$6"
    
    init_config
    
    echo "${backup_name}|${source_dir}|${output_dir}|${script_path}|${time_period}|${backup_count}" >> "${CONFIG_FILE}"
}

get_backup_config() {
    local backup_name="$1"
    
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        return 1
    fi
    
    grep "^${backup_name}|" "${CONFIG_FILE}"
}

remove_backup_config() {
    local backup_name="$1"
    
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        return 0
    fi
    
    local temp_file="${CONFIG_FILE}.tmp"
    grep -v "^${backup_name}|" "${CONFIG_FILE}" > "${temp_file}" || true
    mv "${temp_file}" "${CONFIG_FILE}"
}

list_backups() {
    if [[ ! -f "${CONFIG_FILE}" ]] || [[ ! -s "${CONFIG_FILE}" ]]; then
        log_info "No backups configured"
        return 0
    fi
    
    echo ""
    echo "=== Configured Backups ==="
    echo ""
    
    while IFS='|' read -r name source output script schedule count; do
        echo "Name:       $name"
        echo "Source:     $source"
        echo "Output:     $output"
        echo "Schedule:   $schedule"
        echo "Keep:       $count backups"
        echo "Script:     $script"
        echo "---"
    done < "${CONFIG_FILE}"
    
    echo ""
}

expand_path() {
    local path="$1"
    eval echo "$path"
}

validate_directory() {
    local path="$1"
    local name="$2"
    
    if [[ ! -e "$path" ]]; then
        log_error "$name does not exist: $path"
        return 1
    fi
    
    if [[ ! -d "$path" ]]; then
        log_error "$name is not a directory: $path"
        return 1
    fi
    
    return 0
}

show_usage() {
cat << 'EOF'
Usage: backup.sh <command> [options]
Commands:
  start    Set up a new backup schedule
  update   Update existing backup script
  delete   Remove existing backup script
  list     List all backup scripts
  help     Show this help message
EOF
}

create_backup_script_template() {
    local source_dir="$(expand_path "$1")"
    local output_dir="$(expand_path "$2")"
    local time_period="$3"
    local backup_count="${4:-5}"
    local backup_name="${5:-$(basename "$source_dir")}"
    
    if [[ -z "$source_dir" ]]; then
        log_error "Source directory is required"
        return 1
    fi
    
    if [[ -z "$output_dir" ]]; then
        log_error "Output directory is required"
        return 1
    fi
    
    if [[ -z "$time_period" ]]; then
        log_error "Time period is required"
        return 1
    fi
    
    if ! validate_directory "$source_dir" "Source directory"; then
        return 1
    fi
    
    if [[ ! -d "$output_dir" ]]; then
        log_info "Creating output directory: $output_dir"
        mkdir -p "$output_dir" || {
            log_error "Failed to create output directory"
            return 1
        }
    fi
    
    local backmeup_dir="${output_dir}/.backmeup"
    if [[ ! -d "$backmeup_dir" ]]; then
        log_info "Creating .backmeup directory for scripts"
        mkdir -p "$backmeup_dir" || {
            log_error "Failed to create .backmeup directory"
            return 1
        }
    fi
    
    local script_name="backup_${backup_name}.sh"
    local script_path="${backmeup_dir}/${script_name}"
    
    log_info "Creating backup script: $script_path"
    
cat > "$script_path" << 'TEMPLATE_EOF'
#!/usr/bin/env bash

SOURCE="SOURCE_DIR_PLACEHOLDER"
OUTPUT="OUTPUT_DIR_PLACEHOLDER"
BACKUP_COUNT="BACKUP_COUNT_PLACEHOLDER"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${OUTPUT}/$(basename "$SOURCE")_${TIMESTAMP}.tar.gz"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting backup: $SOURCE"

if tar -czf "$BACKUP_FILE" -C "$(dirname "$SOURCE")" "$(basename "$SOURCE")" 2>/dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Backup completed: $(du -h "$BACKUP_FILE" | cut -f1)"
    
    BACKUP_FILES=($(ls -t "${OUTPUT}"/$(basename "$SOURCE")_*.tar.gz 2>/dev/null))
    if [[ ${#BACKUP_FILES[@]} -gt $BACKUP_COUNT ]]; then
        for ((i=$BACKUP_COUNT; i<${#BACKUP_FILES[@]}; i++)); do
            rm -f "${BACKUP_FILES[$i]}"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Removed old backup: $(basename "${BACKUP_FILES[$i]}")"
        done
    fi
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ Backup failed"
    exit 1
fi
TEMPLATE_EOF

    sed -i.bak "s|SOURCE_DIR_PLACEHOLDER|$source_dir|g" "$script_path"
    sed -i.bak "s|OUTPUT_DIR_PLACEHOLDER|$output_dir|g" "$script_path"
    sed -i.bak "s|BACKUP_COUNT_PLACEHOLDER|$backup_count|g" "$script_path"
    rm -f "${script_path}.bak"
    chmod +x "$script_path"
    save_backup_config "$backup_name" "$source_dir" "$output_dir" "$script_path" "$time_period" "$backup_count"
    log_success "Backup script created: $script_path"
    SCRIPT_PATH="$script_path"
}

setup_cron_job() {
    local script_path="$1"
    local time_period="$2"
    
    if [[ ! -f "${SCRIPT_DIR}/cron.sh" ]]; then
        log_error "cron.sh not found"
        return 1
    fi
    
    bash "${SCRIPT_DIR}/cron.sh" add "$script_path" "$time_period"
}

select_time_period() {
    local choice
    echo "" >&2
    echo "Select backup schedule:" >&2
    echo "  1) Hourly       - Every hour" >&2
    echo "  2) Daily        - Every day at 2:00 AM" >&2
    echo "  3) Weekly       - Every Sunday at 2:00 AM" >&2
    echo "  4) Monthly      - First day of month at 2:00 AM" >&2
    echo "  5) Custom       - Enter custom cron format" >&2
    echo "" >&2
    read -p "Choose [1-5]: " choice
    
    case $choice in
        1) echo "hourly" ;;
        2) echo "daily" ;;
        3) echo "weekly" ;;
        4) echo "monthly" ;;
        5)
            echo "" >&2
            echo "Cron format: minute hour day month weekday" >&2
            echo "Examples:" >&2
            echo "  '*/30 * * * *'  - Every 30 minutes" >&2
            echo "  '0 */6 * * *'   - Every 6 hours" >&2
            echo "  '0 9 * * 1-5'   - Weekdays at 9 AM" >&2
            echo "" >&2
            read -p "Enter cron schedule: " custom_cron
            echo "$custom_cron"
            ;;
        *)
            echo "Invalid choice" >&2
            return 1
            ;;
    esac
}

start_backup(){
    local directory=""
    local output_dir=""
    local time_period=""
    local backup_count="5"
    local interactive=false
    
    if [[ $# -eq 0 ]]; then
        interactive=true
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--directory)
                directory="$2"
                shift 2
                ;;
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
            -t|--time-period)
                time_period="$2"
                shift 2
                ;;
            -b|--backup-count)
                backup_count="$2"
                shift 2
                ;;
            -i|--interactive)
                interactive=true
                shift
                ;;
            *)
                log_error "Unknown flag: $1"
                return 1
                ;;
        esac
    done
    
    if [[ "$interactive" == true ]]; then
        echo ""
        echo "=== BackMeUp Interactive Setup ==="
        echo ""
        
        if [[ -z "$directory" ]]; then
            read -p "Source directory to backup: " directory
            directory=$(expand_path "$directory")
        fi
        
        if [[ -z "$output_dir" ]]; then
            read -p "Backup destination directory: " output_dir
            output_dir=$(expand_path "$output_dir")
        fi
        
        if [[ -z "$time_period" ]]; then
            time_period=$(select_time_period)
            if [[ -z "$time_period" ]]; then
                return 1
            fi
        fi
        
        if [[ -z "$backup_count" ]] || [[ "$backup_count" == "5" ]]; then
            read -p "Number of backups to keep (default: 5): " input_count
            backup_count="${input_count:-5}"
        fi
    fi
    
    if [[ -z "$directory" ]] || [[ -z "$output_dir" ]] || [[ -z "$time_period" ]]; then
        log_error "Missing required parameters"
        echo ""
        echo "Usage: backup.sh start [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -d, --directory <path>     Source directory to backup"
        echo "  -o, --output <path>        Backup destination directory"
        echo "  -t, --time-period <time>   Schedule (hourly/daily/weekly/monthly/cron)"
        echo "  -b, --backup-count <num>   Number of backups to keep (default: 5)"
        echo "  -i, --interactive          Interactive mode"
        echo ""
        echo "Examples:"
        echo "  backup.sh start -d ~/Documents -o ~/Backups -t daily"
        echo "  backup.sh start -d ~/Documents -o ~/Backups -t daily -b 10"
        echo "  backup.sh start -i"
        echo "  backup.sh start -d ~/Photos -o /backup -t '0 3 * * *' -b 7"
        echo ""
        return 1
    fi
    
    directory=$(expand_path "$directory")
    output_dir=$(expand_path "$output_dir")
    
    if ! validate_directory "$directory" "Source directory"; then
        return 1
    fi
    
    if [[ -f "${CONFIG_FILE}" ]]; then
        while IFS='|' read -r name source output script schedule count; do
            if [[ "$source" == "$directory" ]] && [[ "$output" == "$output_dir" ]]; then
                log_error "Backup with same source and output already exists: $name"
                echo "Use 'backup update $name' to modify it"
                return 1
            fi
        done < "${CONFIG_FILE}"
    fi
    
    local backup_name="$(basename "$directory")"
    local index=1
    local original_name="$backup_name"
    while get_backup_config "$backup_name" >/dev/null 2>&1; do
        backup_name="${original_name}-${index}"
        ((index++))
    done
    
    echo ""
    log_info "Starting backup setup..."
    log_info "Backup name: $backup_name"
    log_info "Backup name: $backup_name"
    log_info "Source: $directory"
    log_info "Destination: $output_dir"
    log_info "Schedule: $time_period"
    echo ""
    
    create_backup_script_template "$directory" "$output_dir" "$time_period" "$backup_count" "$backup_name"
    
    if [[ $? -eq 0 ]] && [[ -n "$SCRIPT_PATH" ]]; then
        setup_cron_job "$SCRIPT_PATH" "$time_period"
        
        echo ""
        log_success "Backup mechanism setup completed!"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "          Backup Configuration          "
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo " Source:       $directory"
        echo " Destination:  $output_dir"
        echo " Schedule:     $time_period"
        echo " Script:       $SCRIPT_PATH"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo " Quick Commands          "
        echo " Manual backup:  $SCRIPT_PATH"
        echo " View schedule:  crontab -l | grep backmeup"
        echo " Check backups:  ls -lh $output_dir/*.tar.gz"
        echo ""
    else
        log_error "Failed to create backup script"
        return 1
    fi
}

update_backup() {
    local backup_name="$1"
    shift
    
    if [[ -z "$backup_name" ]]; then
        log_error "Backup name is required"
        echo "Usage: backup update <backup_name> [options]"
        echo "Options: -t <time_period> | -b <backup_count>"
        return 1
    fi
    
    local config_line=$(get_backup_config "$backup_name")
    if [[ -z "$config_line" ]]; then
        log_error "Backup '$backup_name' not found"
        echo "Use 'backup list' to see available backups"
        return 1
    fi
    
    IFS='|' read -r name source output script old_schedule old_count <<< "$config_line"
    
    local new_schedule="$old_schedule"
    local new_count="$old_count"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--time-period)
                new_schedule="$2"
                shift 2
                ;;
            -b|--backup-count)
                new_count="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    if [[ ! -f "$script" ]]; then
        log_error "Backup script not found: $script"
        return 1
    fi
    
    sed -i.bak "s|BACKUP_COUNT=\".*\"|BACKUP_COUNT=\"$new_count\"|g" "$script"
    rm -f "${script}.bak"
    
    if [[ "$new_schedule" != "$old_schedule" ]]; then
        bash "${SCRIPT_DIR}/cron.sh" remove "${backup_name}"
        bash "${SCRIPT_DIR}/cron.sh" add "$script" "$new_schedule"
    fi
    
    remove_backup_config "$backup_name"
    save_backup_config "$backup_name" "$source" "$output" "$script" "$new_schedule" "$new_count"
    
    log_success "Backup '$backup_name' updated successfully"
    echo "Schedule: $new_schedule"
    echo "Keep: $new_count backups"
}

delete_backup() {
    local backup_name="$1"
    
    if [[ -z "$backup_name" ]]; then
        log_error "Backup name is required"
        echo "Usage: backup delete <backup_name>"
        return 1
    fi
    
    local config_line=$(get_backup_config "$backup_name")
    if [[ -z "$config_line" ]]; then
        log_error "Backup '$backup_name' not found"
        echo "Use 'backup list' to see available backups"
        return 1
    fi
    
    IFS='|' read -r name source output script schedule count <<< "$config_line"
    
    if [[ -f "$script" ]]; then
        rm -f "$script"
        log_info "Removed backup script: $script"
        
        local backmeup_dir="$(dirname "$script")"
        if [[ -d "$backmeup_dir" ]] && [[ "$(basename "$backmeup_dir")" == ".backmeup" ]]; then
            if [[ -z "$(ls -A "$backmeup_dir" 2>/dev/null)" ]]; then
                rm -rf "$backmeup_dir"
                log_info "Removed empty .backmeup directory: $backmeup_dir"
            fi
        fi
    fi
    
    bash "${SCRIPT_DIR}/cron.sh" remove "${backup_name}" 2>/dev/null || true
    remove_backup_config "$backup_name"
    log_success "Backup '$backup_name' deleted successfully"
}

command(){
    local cmd=$1
    shift
    case $cmd in
        "start")
            start_backup "$@"
            ;;
        "update")
            update_backup "$@"
            ;;
        "delete")
            delete_backup "$@"
            ;;
        "list")
            list_backups
            ;;
        "help"|"")
            show_usage
            ;;
        *)
            echo "Unknown command: $cmd"
            show_usage
            ;;
    esac
}
            
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    command "$@"
fi
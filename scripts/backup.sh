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
    local source_dir="$1"
    local output_dir="$2"
    local time_period="$3"
    local backup_count="${4:-5}"
    
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
    
    if [[ ! -d "$source_dir" ]]; then
        log_error "Source directory does not exist: $source_dir"
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
    
    local source_basename=$(basename "$source_dir")
    local script_name="backup_${source_basename}.sh"
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
    
    KEEP_FROM=$((BACKUP_COUNT + 1))
    ls -t "${OUTPUT}"/$(basename "$SOURCE")_*.tar.gz 2>/dev/null | tail -n +${KEEP_FROM} | xargs rm -f 2>/dev/null
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
    log_success "Backup script created: $script_path"
    echo "$script_path"
}

setup_cron_job() {
    local script_path="$1"
    local time_period="$2"
    
    if [[ ! -f "${SCRIPT_DIR}/cron.sh" ]]; then
        log_error "cron.sh not found"
        return 1
    fi
    
    exec "${SCRIPT_DIR}/cron.sh" add "$script_path" "$time_period"
}

select_time_period() {
    echo ""
    echo "Select backup schedule:"
    echo "  1) Hourly       - Every hour"
    echo "  2) Daily        - Every day at 2:00 AM"
    echo "  3) Weekly       - Every Sunday at 2:00 AM"
    echo "  4) Monthly      - First day of month at 2:00 AM"
    echo "  5) Custom       - Enter custom cron format"
    echo ""
    read -p "Choose [1-5]: " choice
    
    case $choice in
        1) echo "hourly" ;;
        2) echo "daily" ;;
        3) echo "weekly" ;;
        4) echo "monthly" ;;
        5)
            echo ""
            echo "Cron format: minute hour day month weekday"
            echo "Examples:"
            echo "  '*/30 * * * *'  - Every 30 minutes"
            echo "  '0 */6 * * *'   - Every 6 hours"
            echo "  '0 9 * * 1-5'   - Weekdays at 9 AM"
            echo ""
            read -p "Enter cron schedule: " custom_cron
            echo "$custom_cron"
            ;;
        *)
            echo "Invalid choice"
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
        fi
        
        if [[ -z "$output_dir" ]]; then
            read -p "Backup destination directory: " output_dir
        fi
        
        if [[ -z "$time_period" ]]; then
            time_period=$(select_time_period)
            if [[ -z "$time_period" ]]; then
                return 1
            fi
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
    
    echo ""
    log_info "Starting backup setup..."
    log_info "Source: $directory"
    log_info "Destination: $output_dir"
    log_info "Schedule: $time_period"
    echo ""
    
    local script_path=$(create_backup_script_template "$directory" "$output_dir" "$time_period" "$backup_count")
    
    if [[ $? -eq 0 ]] && [[ -n "$script_path" ]]; then
        setup_cron_job "$script_path" "$time_period"
        
        echo ""
        log_success "Backup mechanism setup completed!"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "          Backup Configuration          "
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Source:       $directory"
        echo "Destination:  $output_dir"
        echo "Schedule:     $time_period"
        echo "Script:       $script_path"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "          Quick Commands          "
        echo "  Manual backup:  $script_path"
        echo "  View schedule:  crontab -l | grep backmeup"
        echo "  Check backups:  ls -lh $output_dir/*.tar.gz"
        echo ""
    else
        log_error "Failed to create backup script"
        return 1
    fi
}

command(){
    local command=$1
    shift
    case $command in
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
            list_backups "$@"
            ;;
        "help"|"--help"|"-h")
            show_usage
            ;;
        "")
            echo "Error: No command specified"
            echo ""
            show_usage
            ;;
        *)
            echo "Error: Unknown command: $command"
            echo ""
            show_usage
            ;;
    esac
}
            
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    command "$@"
fi
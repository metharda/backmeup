#!/usr/bin/env bash

if [[ -z "${RED}" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
fi

if ! declare -f log_info >/dev/null 2>&1; then
    log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
    log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
    log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
    log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${HOME}/.config/backmeup"
CONFIG_FILE="${CONFIG_DIR}/backups.conf"
SCRIPT_PATH=""

if [[ -f "${SCRIPT_DIR}/ssh_utils.sh" ]]; then
    source "${SCRIPT_DIR}/ssh_utils.sh"
fi

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
    local compression_method="${7:-tar.gz}"
    local remote_enabled="${8:-false}"
    local remote_user="${9:-}"
    local remote_host="${10:-}"
    local remote_path="${11:-}"
    local delete_after="${12:-false}"
    
    init_config
    
    echo "${backup_name}|${source_dir}|${output_dir}|${script_path}|${time_period}|${backup_count}|${compression_method}|${remote_enabled}|${remote_user}|${remote_host}|${remote_path}|${delete_after}" >> "${CONFIG_FILE}"
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
    
    while IFS='|' read -r name source output script schedule count compression remote_enabled remote_user remote_host remote_path delete_after; do
        echo "Name:       $name"
        echo "Source:     $source"
        echo "Output:     $output"
        echo "Schedule:   $schedule"
        echo "Keep:       $count backups"
        echo "Format:     ${compression:-tar.gz}"
        if [[ "$remote_enabled" == "true" ]]; then
            echo "Remote:     ${remote_user}@${remote_host}:${remote_path} (scp)"
            if [[ "$delete_after" == "true" ]]; then
                echo "Option:     Delete local after transfer"
            fi
        fi
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

check_compression_tool() {
    local compression="$1"
    local tool_name=""
    local package_name=""
    
    case "$compression" in
        "tar.gz")
            tool_name="gzip"
            package_name="gzip"
            ;;
        "tar.bz2")
            tool_name="bzip2"
            package_name="bzip2"
            ;;
        "tar.xz")
            tool_name="xz"
            package_name="xz-utils"
            ;;
        "zip")
            tool_name="zip"
            package_name="zip"
            ;;
    esac
    
    if ! type "$tool_name" >/dev/null 2>&1; then
        log_warning "Compression tool '$tool_name' is not installed."
        echo ""
        read -p "Would you like to install it now? (y/n): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            log_info "Installing $tool_name..."
            
            if command -v apt-get &>/dev/null; then
                sudo apt-get update && sudo apt-get install -y "$package_name"
            elif command -v yum &>/dev/null; then
                sudo yum install -y "$package_name"
            elif command -v dnf &>/dev/null; then
                sudo dnf install -y "$package_name"
            else
                log_error "No supported package manager found. Please install '$tool_name' manually."
                return 1
            fi
            
            if [[ $? -eq 0 ]]; then
                if ! type "$tool_name" >/dev/null 2>&1; then
                    log_error "Installation reported success but $tool_name is still not available"
                    return 1
                fi
                log_success "$tool_name installed successfully"
            else
                log_error "Failed to install $tool_name"
                return 1
            fi
        else
            log_error "Cannot create backup without $tool_name"
            return 1
        fi
    fi
    
    return 0
}

show_usage() {
cat << 'EOF'
Usage: backup.sh <command> [options]
Commands:
  start    Set up a new backup schedule
  create   Create a one-time backup (no schedule)
  restore  Restore from a backup archive
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
    local compression_method="${6:-tar.gz}"
    local remote_enabled="${7:-false}"
    local remote_user="${8:-}"
    local remote_host="${9:-}"
    local remote_path="${10:-}"
    local delete_after="${11:-false}"
    
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
    
    if ! check_compression_tool "$compression_method"; then
        log_error "Compression tool check failed - aborting"
        return 1
    fi
    
cat > "$script_path" << 'TEMPLATE_EOF'
#!/usr/bin/env bash

SOURCE="SOURCE_DIR_PLACEHOLDER"
OUTPUT="OUTPUT_DIR_PLACEHOLDER"
BACKUP_COUNT="BACKUP_COUNT_PLACEHOLDER"
COMPRESSION="COMPRESSION_METHOD_PLACEHOLDER"
REMOTE_ENABLED="REMOTE_ENABLED_PLACEHOLDER"
REMOTE_USER="REMOTE_USER_PLACEHOLDER"
REMOTE_HOST="REMOTE_HOST_PLACEHOLDER"
REMOTE_PATH="REMOTE_PATH_PLACEHOLDER"
DELETE_AFTER="DELETE_AFTER_PLACEHOLDER"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

declare -A COMPRESSION_MAP=(
    ["tar.gz"]=".tar.gz|z"
    ["tar.bz2"]=".tar.bz2|j"
    ["tar.xz"]=".tar.xz|J"
    ["zip"]=".zip|zip"
)

IFS='|' read -r EXT FLAG <<< "${COMPRESSION_MAP[$COMPRESSION]:-".tar.gz|z"}"
BACKUP_FILE="${OUTPUT}/$(basename "$SOURCE")_${TIMESTAMP}${EXT}"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting backup: $SOURCE"

# Execute backup
if [[ "$FLAG" == "zip" ]]; then
    cd "$(dirname "$SOURCE")" && zip -r "$BACKUP_FILE" "$(basename "$SOURCE")" >/dev/null
else
    tar -c${FLAG}f "$BACKUP_FILE" -C "$(dirname "$SOURCE")" "$(basename "$SOURCE")" 2>/dev/null
fi

if [[ $? -eq 0 ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Backup completed: $(du -h "$BACKUP_FILE" | cut -f1)"
    BACKUP_FILES=($(ls -t "${OUTPUT}"/$(basename "$SOURCE")_*${EXT} 2>/dev/null))
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

# Remote Transfer
if [[ "$REMOTE_ENABLED" == "true" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting remote transfer to ${REMOTE_HOST}..."
    
    scp -o BatchMode=yes "$BACKUP_FILE" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"
    
    if [[ $? -eq 0 ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Remote transfer successful"
        
        # Remote Rotation - cleanup old backups on remote server
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking remote backups for rotation..."
        REMOTE_BASENAME=$(basename "$SOURCE")
        
        ssh -o BatchMode=yes "${REMOTE_USER}@${REMOTE_HOST}" bash -s <<REMOTE_SCRIPT
cd "${REMOTE_PATH}" 2>/dev/null || exit 0
echo "Searching for: ${REMOTE_BASENAME}_*${EXT}"
BACKUP_FILES=(\$(ls -t ${REMOTE_BASENAME}_*${EXT} 2>/dev/null))
COUNT=\${#BACKUP_FILES[@]}
KEEP=${BACKUP_COUNT}

echo "Found \$COUNT backups in ${REMOTE_PATH}"
if [ \$COUNT -gt \$KEEP ]; then
    echo "Keeping \$KEEP, removing \$((\$COUNT - \$KEEP))"
    for ((i=\$KEEP; i<\$COUNT; i++)); do
        rm -f "\${BACKUP_FILES[\$i]}"
        echo "Removed: \${BACKUP_FILES[\$i]}"
    done
else
    echo "No rotation needed (keeping \$KEEP)"
fi
REMOTE_SCRIPT
        
        if [[ "$DELETE_AFTER" == "true" ]]; then
            rm -f "$BACKUP_FILE"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Removed local backup file"
        fi
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ Remote transfer failed"
        # Don't fail the whole script if remote transfer fails, but log it
    fi
fi
TEMPLATE_EOF

    sed -i.bak "s|SOURCE_DIR_PLACEHOLDER|$source_dir|g" "$script_path"
    sed -i.bak "s|OUTPUT_DIR_PLACEHOLDER|$output_dir|g" "$script_path"
    sed -i.bak "s|BACKUP_COUNT_PLACEHOLDER|$backup_count|g" "$script_path"
    sed -i.bak "s|COMPRESSION_METHOD_PLACEHOLDER|$compression_method|g" "$script_path"
    sed -i.bak "s|REMOTE_ENABLED_PLACEHOLDER|$remote_enabled|g" "$script_path"
    sed -i.bak "s|REMOTE_USER_PLACEHOLDER|$remote_user|g" "$script_path"
    sed -i.bak "s|REMOTE_HOST_PLACEHOLDER|$remote_host|g" "$script_path"
    sed -i.bak "s|REMOTE_PATH_PLACEHOLDER|$remote_path|g" "$script_path"
    sed -i.bak "s|DELETE_AFTER_PLACEHOLDER|$delete_after|g" "$script_path"
    rm -f "${script_path}.bak"
    chmod +x "$script_path"
    save_backup_config "$backup_name" "$source_dir" "$output_dir" "$script_path" "$time_period" "$backup_count" "$compression_method" "$remote_enabled" "$remote_user" "$remote_host" "$remote_path" "$delete_after"
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

select_compression_method() {
    local choice
    echo "" >&2
    echo "Select compression method:" >&2
    echo "  1) tar.gz (Default) - Good balance of speed and size" >&2
    echo "  2) zip              - Widely supported" >&2
    echo "  3) tar.bz2          - Better compression, slower" >&2
    echo "  4) tar.xz           - Best compression, slowest" >&2
    echo "" >&2
    read -p "Choose [1-4] (default: 1): " choice
    
    case $choice in
        1|"") echo "tar.gz" ;;
        2) echo "zip" ;;
        3) echo "tar.bz2" ;;
        4) echo "tar.xz" ;;
        *)
            echo "Invalid choice, defaulting to tar.gz" >&2
            echo "tar.gz"
            ;;
    esac
}

start_backup(){
    local directory=""
    local output_dir=""
    local time_period=""
    local backup_count="5"
    local compression_method="tar.gz"
    local remote_enabled="false"
    local remote_user=""
    local remote_host=""
    local remote_path=""
    local delete_after="false"
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
            -c|--compression)
                compression_method="$2"
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
        
        if [[ -z "$compression_method" ]] || [[ "$compression_method" == "tar.gz" ]]; then
            compression_method=$(select_compression_method)
        fi
        
        echo ""
        read -p "Enable remote backup? [y/N]: " enable_remote
        if [[ "$enable_remote" =~ ^[Yy]$ ]]; then
            remote_enabled="true"
            
            if ! check_ssh_key; then
                echo "No SSH key found. Generating one..."
                generate_ssh_key
            fi
            
            read -p "Remote User (e.g., root): " remote_user
            read -p "Remote Host (e.g., 192.168.1.50): " remote_host
            read -p "Remote Path (e.g., /var/backups): " remote_path
            
            while [[ -z "$remote_path" ]]; do
                echo ""
                log_warning "Remote path cannot be empty!"
                read -p "Remote Path (e.g., /var/backups): " remote_path
            done
            
            echo ""
            echo "Testing connection..."
            if ! test_ssh_connection "$remote_user" "$remote_host"; then
                echo "Connection failed or password required."
                read -p "Do you want to copy your SSH key to the server? [Y/n]: " copy_key
                if [[ "$copy_key" =~ ^[Yy]$ ]] || [[ -z "$copy_key" ]]; then
                    copy_ssh_key "$remote_user" "$remote_host"
                fi
            else
                echo "Connection successful!"
            fi
            
            read -p "Delete local backup after successful transfer? [y/N]: " del_choice
            if [[ "$del_choice" =~ ^[Yy]$ ]]; then
                delete_after="true"
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
        echo "  -c, --compression <type>   Compression method (tar.gz/zip/tar.bz2/tar.xz)"
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
    
    directory=$(expand_path "$directory" | sed 's:/*$::')
    [[ -z "$directory" ]] && directory="/"
    output_dir=$(expand_path "$output_dir" | sed 's:/*$::')
    [[ -z "$output_dir" ]] && output_dir="/"
    
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
    log_info "Source: $directory"
    log_info "Destination: $output_dir"
    log_info "Schedule: $time_period"
    log_info "Compression: $compression_method"
    if [[ "$remote_enabled" == "true" ]]; then
        log_info "Remote: $remote_user@$remote_host:$remote_path (scp)"
        if [[ "$delete_after" == "true" ]]; then
            log_info "Option: Delete local after transfer"
        fi
    fi
    echo ""
    
    create_backup_script_template "$directory" "$output_dir" "$time_period" "$backup_count" "$backup_name" "$compression_method" "$remote_enabled" "$remote_user" "$remote_host" "$remote_path" "$delete_after"
    
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
        echo " Format:       $compression_method"
        if [[ "$remote_enabled" == "true" ]]; then
            echo " Remote:       $remote_user@$remote_host:$remote_path"
        fi
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

restore_backup() {
    local backup_file=""
    local output_dir=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--file)
                backup_file="$2"
                shift 2
                ;;
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
            *)
                log_error "Unknown flag: $1"
                return 1
                ;;
        esac
    done
    
    if [[ -z "$backup_file" ]] || [[ -z "$output_dir" ]]; then
        log_error "Missing required parameters"
        echo ""
        echo "Usage: backup.sh restore [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -f, --file <path>          Backup archive file"
        echo "  -o, --output <path>        Restore destination directory"
        echo ""
        echo "Example:"
        echo "  backup.sh restore -f ~/Backups/Documents_20231118_120000.tar.gz -o ~/Restored"
        echo ""
        return 1
    fi
    
    backup_file=$(expand_path "$backup_file")
    output_dir=$(expand_path "$output_dir")
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file does not exist: $backup_file"
        return 1
    fi
    
    if [[ ! -d "$output_dir" ]]; then
        log_info "Creating output directory: $output_dir"
        mkdir -p "$output_dir" || {
            log_error "Failed to create output directory"
            return 1
        }
    fi
    
    local cmd=""
    local compression_type=""
    
    if [[ "$backup_file" =~ \.zip$ ]]; then
        cmd="unzip -o"
        compression_type="zip"
    elif [[ "$backup_file" =~ \.tar\.gz$ ]] || [[ "$backup_file" =~ \.tgz$ ]]; then
        cmd="tar -xzf"
        compression_type="tar.gz"
    elif [[ "$backup_file" =~ \.tar\.bz2$ ]]; then
        cmd="tar -xjf"
        compression_type="tar.bz2"
    elif [[ "$backup_file" =~ \.tar\.xz$ ]]; then
        cmd="tar -xJf"
        compression_type="tar.xz"
    else
        log_error "Unsupported backup file format. Supported: .tar.gz, .zip, .tar.bz2, .tar.xz"
        return 1
    fi
    
    if ! check_compression_tool "$compression_type"; then
        return 1
    fi
    
    # Special check for unzip if it's a zip file
    if [[ "$compression_type" == "zip" ]] && ! command -v unzip &>/dev/null; then
        log_warning "unzip tool not found."
        read -p "Would you like to install it now? (y/n): " choice
        if [[ "$choice" == "y" ]] || [[ "$choice" == "Y" ]]; then
            log_info "Installing unzip..."
            if command -v apt-get &>/dev/null; then
                sudo apt-get update && sudo apt-get install -y unzip
            elif command -v yum &>/dev/null; then
                sudo yum install -y unzip
            elif command -v dnf &>/dev/null; then
                sudo dnf install -y unzip
            else
                log_error "No supported package manager found. Please install 'unzip' manually."
                return 1
            fi
            
            if [[ $? -ne 0 ]]; then
                log_error "Failed to install unzip"
                return 1
            fi
            log_success "unzip installed successfully"
        else
            log_error "Cannot restore backup without unzip"
            return 1
        fi
    fi
    
    local backup_size=$(du -h "$backup_file" | cut -f1)
    
    echo ""
    log_info "Restoring backup..."
    log_info "Backup file: $backup_file"
    log_info "Size: $backup_size"
    log_info "Destination: $output_dir"
    log_warning "This may take a while depending on the size..."
    echo ""
    
    log_info "Extracting archive..."
    local success=false
    
    if [[ "$backup_file" =~ \.zip$ ]]; then
        if $cmd "$backup_file" -d "$output_dir" >/dev/null; then
            success=true
        fi
    else
        if $cmd "$backup_file" -C "$output_dir" 2>/dev/null; then
            success=true
        fi
    fi
    
    if [[ "$success" == true ]]; then
        echo ""
        log_success "Restore completed successfully!"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "          Restore Information          "
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo " Backup file:  $backup_file"
        echo " Restored to:  $output_dir"
        echo " Size:         $backup_size"
        echo " Timestamp:    $(date '+%Y-%m-%d %H:%M:%S')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        return 0
    else
        log_error "Restore failed"
        return 1
    fi
}

create_onetime_backup() {
    local directory=""
    local output_dir=""
    local compression_method="tar.gz"
    
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
            -c|--compression)
                compression_method="$2"
                shift 2
                ;;
            *)
                log_error "Unknown flag: $1"
                return 1
                ;;
        esac
    done
    
    if [[ -z "$directory" ]] || [[ -z "$output_dir" ]]; then
        log_error "Missing required parameters"
        echo ""
        echo "Usage: backup.sh create [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -d, --directory <path>     Source directory to backup"
        echo "  -o, --output <path>        Backup destination directory"
        echo "  -c, --compression <type>   Compression method (tar.gz/zip/tar.bz2/tar.xz)"
        echo ""
        echo "Example:"
        echo "  backup.sh create -d ~/Documents -o ~/Backups"
        echo ""
        return 1
    fi
    
    directory=$(expand_path "$directory" | sed 's:/*$::')
    [[ -z "$directory" ]] && directory="/"
    output_dir=$(expand_path "$output_dir" | sed 's:/*$::')
    [[ -z "$output_dir" ]] && output_dir="/"
    
    if ! validate_directory "$directory" "Source directory"; then
        return 1
    fi
    
    if [[ ! -d "$output_dir" ]]; then
        log_info "Creating output directory: $output_dir"
        mkdir -p "$output_dir" || {
            log_error "Failed to create output directory"
            return 1
        }
    fi
    
    if ! check_compression_tool "$compression_method"; then
        return 1
    fi
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local ext=".tar.gz"
    local cmd="tar -czf"
    
    case $compression_method in
        "zip")
            ext=".zip"
            cmd="zip -r"
            ;;
        "tar.bz2")
            ext=".tar.bz2"
            cmd="tar -cjf"
            ;;
        "tar.xz")
            ext=".tar.xz"
            cmd="tar -cJf"
            ;;
        "tar.gz")
            ext=".tar.gz"
            cmd="tar -czf"
            ;;
        *)
            log_error "Unsupported compression method: $compression_method"
            return 1
            ;;
    esac
    
    local backup_file="${output_dir}/$(basename "$directory")_${timestamp}${ext}"
    
    echo ""
    log_info "Creating one-time backup..."
    log_info "Source: $directory"
    log_info "Destination: $backup_file"
    log_info "Compression: $compression_method"
    
    log_info "Calculating directory size..."
    local dir_size=$(du -sh "$directory" 2>/dev/null | cut -f1)
    log_info "Directory size: $dir_size"
    log_warning "This may take a while depending on the size..."
    echo ""
    
    log_info "Creating backup archive..."
    local success=false
    if [[ "$compression_method" == "zip" ]]; then
        if cd "$(dirname "$directory")" && $cmd "$backup_file" "$(basename "$directory")" >/dev/null; then
            success=true
        fi
    else
        if $cmd "$backup_file" -C "$(dirname "$directory")" "$(basename "$directory")" 2>/dev/null; then
            success=true
        fi
    fi
    
    if [[ "$success" == true ]]; then
        local backup_size=$(du -h "$backup_file" | cut -f1)
        echo ""
        log_success "Backup completed successfully!"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "          Backup Information          "
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo " Source:       $directory"
        echo " Backup file:  $backup_file"
        echo " Size:         $backup_size"
        echo " Timestamp:    $(date '+%Y-%m-%d %H:%M:%S')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        return 0
    else
        log_error "Backup failed"
        return 1
    fi
}

command(){
    local cmd=$1
    shift
    case $cmd in
        "start")
            start_backup "$@"
            ;;
        "create")
            create_onetime_backup "$@"
            ;;
        "restore")
            restore_backup "$@"
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
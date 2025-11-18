#!/usr/bin/env bash
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts"

show_usage() {
cat << 'EOF'
 ____             _                 
|  _ \           | |                           
| |_) | __ _  ___| | ___ __ ___   ___  _   _ _ __  
|  _ < / _` |/ __| |/ / '_ ` _ \ / _ \| | | | '_ \ 
| |_) | (_| | (__|   <| | | | | |  __/| |_| | |_) |
|____/ \__,_|\___|_|\_\_| |_| |_|\___| \__,_| .__/ 
                                            | |    
                                            |_|    
BackMeUp - Automated Backup Solution

Usage: backmeup <command> [options]

Commands:
  backup <start|update|delete|list|create|restore>  Manage backups
  help                                              Show this help message

"backup start" Options:
  -d, --directory <path>     Source directory to backup
  -o, --output <path>        Backup destination directory
  -t, --time-period <time>   Schedule (hourly/daily/weekly/monthly/cron)
  -b, --backup-count <num>   Number of backups to keep (default: 5)
  -i, --interactive          Interactive mode

Examples:
    backmeup backup start -i
    backmeup backup start -d ~/Documents -o ~/Backups -t daily
    backmeup backup start -d ~/Photos -o /backup -t "0 3 * * *" -b 10
    backmeup backup create -d ~/Documents -o ~/Backups
    backmeup backup restore -f ~/Backups/Documents_20231118_120000.tar.gz -o ~/Restored
EOF
}

handle_command(){
    local cmd=$1
    shift
    case $cmd in
        "backup")
            exec bash "${SCRIPT_DIR}/backup.sh" "$@"
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            echo "Unknown command: $cmd"
            echo "Use 'backmeup help' to see available commands."
            exit 1
            ;;
    esac
}
main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 0
    fi

    handle_command "$@"
}
main "$@"
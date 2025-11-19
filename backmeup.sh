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

# Determine script directory (works for both installed and local execution)
if [[ -d "/usr/local/lib/backmeup" ]]; then
    SCRIPT_DIR="/usr/local/lib/backmeup"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts"
fi

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
  backup <start|update|delete|list>  Manage backups
  test                               Run test suite
  uninstall                          Uninstall BackMeUp
  help                               Show this help message

"backup start" Options:
  -d, --directory <path>     Source directory to backup
  -o, --output <path>        Backup destination directory
  -t, --time-period <time>   Schedule (hourly/daily/weekly/monthly/cron)
  -c, --compression <type>   Compression format (tar.gz/tar.bz2/tar.xz/zip)
  -b, --backup-count <num>   Number of backups to keep (default: 5)
  -i, --interactive          Interactive mode

Examples:
    backmeup backup start -i
    backmeup backup start -d ~/Documents -o ~/Backups -t daily
    backmeup backup start -d ~/Photos -o /backup -t "0 3 * * *" -b 10
    backmeup backup list
    backmeup test
    backmeup uninstall
EOF
}

handle_command() {
    case "$1" in
        backup)
            shift
            source "${SCRIPT_DIR}/backup.sh"
            if [[ $# -eq 0 ]]; then
                start_backup
            else
                start_backup "$@"
            fi
            ;;
        test)
            if [[ -f "${SCRIPT_DIR}/../test/test.sh" ]]; then
                "${SCRIPT_DIR}/../test/test.sh"
            elif [[ -f "/usr/local/lib/backmeup/../test/test.sh" ]]; then
                /usr/local/lib/backmeup/../test/test.sh
            else
                echo "Error: Test suite not found"
                exit 1
            fi
            ;;
        uninstall)
            if [[ -f "/usr/local/lib/backmeup/uninstall.sh" ]]; then
                /usr/local/lib/backmeup/uninstall.sh
            else
                echo "Error: Uninstaller not found"
                exit 1
            fi
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            echo "Error: Unknown command '$1'"
            echo ""
            show_usage
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
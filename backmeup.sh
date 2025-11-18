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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
Usage: backmeup <command> [options]
Available commands:
  backup    Start a backup process
  delete    Delete an existing backup
  update    Update backup settings
EOF
}
command(){
    local command=$1
    shift
    case $command in
        "backup")
            exec ${SCRIPT_DIR}/backup.sh "$command" "$@"
            ;;
        "help")
            show_usage
            ;;
        *)
            echo "Unknown command: $1, use 'help' to see available commands."
            ;;
    esac
}
main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 0
    fi

    local command="$1"
    shift

    command "$command" "$@"
}
main "$@"
#!/usr/bin/env bash

rotate_log() {
    local log_file="$1"
    local max_size_mb="${2:-10}" 
    
    if [[ ! -f "$log_file" ]]; then
        return 0
    fi
    

    local size_mb=$(du -m "$log_file" 2>/dev/null | cut -f1)
    
    if [[ $size_mb -ge $max_size_mb ]]; then
        local timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        > "$log_file"
        echo "[$timestamp] [INFO] Log rotation performed: file exceeded ${max_size_mb}MB limit" >> "$log_file"
    fi
}

logger() {
    local level="$1"
    local message="$2"
    local log_file="$3"
    
    
    rotate_log "$log_file" 10
    
    message="${message//$'\n'/ }"
    message="${message//$'\r'/ }"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$log_file"
}

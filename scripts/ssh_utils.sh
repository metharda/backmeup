#!/usr/bin/env bash
# SSH Utilities for BackMeUp

check_ssh_key() {
    local key_path="${HOME}/.ssh/id_rsa"
    if [[ -f "$key_path" ]]; then
        return 0
    fi
    if [[ -f "${HOME}/.ssh/id_ed25519" ]]; then
        return 0
    fi
    return 1
}

generate_ssh_key() {
    local key_type="rsa"
    local key_path="${HOME}/.ssh/id_rsa"
    
    if ssh-keygen -t ed25519 -? &>/dev/null; then
        key_type="ed25519"
        key_path="${HOME}/.ssh/id_ed25519"
    fi

    echo "Generating SSH key ($key_type)..."
    ssh-keygen -t "$key_type" -f "$key_path" -N "" -q
    
    if [[ $? -eq 0 ]]; then
        echo "SSH key generated at $key_path"
        return 0
    else
        echo "Failed to generate SSH key"
        return 1
    fi
}

copy_ssh_key() {
    local user="$1"
    local host="$2"
    local port="${3:-22}"
    
    echo "Copying SSH key to ${user}@${host}..."
    echo "You may be asked for the remote user's password."
    
    ssh-copy-id -p "$port" "${user}@${host}"
    
    if [[ $? -eq 0 ]]; then
        echo "SSH key copied successfully!"
        return 0
    else
        echo ""
        echo "----------------------------------------------------------------"
        echo "Automatic key copy failed."
        echo "This usually means the remote server disabled password login."
        echo ""
        echo "To fix this, run this command on the REMOTE SERVER (${host}):"
        echo ""
        local pub_key=$(cat "${HOME}/.ssh/id_rsa.pub" 2>/dev/null || cat "${HOME}/.ssh/id_ed25519.pub" 2>/dev/null)
        if [[ -n "$pub_key" ]]; then
            echo "echo \"$pub_key\" >> ~/.ssh/authorized_keys"
        else
            echo "Error: Could not read public key to display."
        fi
        echo ""
        echo "----------------------------------------------------------------"
        echo ""
        read -p "Press Enter after you have done this to continue..."
        return 0
    fi
}

test_ssh_connection() {
    local user="$1"
    local host="$2"
    local port="${3:-22}"
    local accept_host_key="${4:-false}"
    
    log_info "Testing SSH connection to ${user}@${host}..."
    
    if [[ "$accept_host_key" == "true" ]]; then
        ssh-keyscan -H -p "$port" "$host" >> ~/.ssh/known_hosts 2>/dev/null
    fi
    
    local ssh_output
    local ssh_opts="-p $port -o ConnectTimeout=5"
    
    ssh_output=$(ssh $ssh_opts -o BatchMode=yes "${user}@${host}" "echo 'Connection successful'" 2>&1)
    local ssh_exit=$?
    
    if [[ $ssh_exit -eq 0 ]]; then
        log_success "SSH connection successful (key-based authentication)"
        return 0
    fi
    
    if echo "$ssh_output" | grep -q "Host key verification failed"; then
        log_warning "Host key verification failed - host is not in known_hosts"
        echo ""
        echo "The authenticity of host cannot be established."
        read -p "Do you want to add this host to known_hosts? [Y/n]: " add_host
        if [[ "$add_host" =~ ^[Yy]$ ]] || [[ -z "$add_host" ]]; then
            log_info "Adding host key..."
            ssh-keyscan -H -p "$port" "$host" >> ~/.ssh/known_hosts 2>/dev/null
            
            ssh_output=$(ssh $ssh_opts -o BatchMode=yes "${user}@${host}" "echo 'Connection successful'" 2>&1)
            ssh_exit=$?
            
            if [[ $ssh_exit -eq 0 ]]; then
                log_success "SSH connection successful (key-based authentication)"
                return 0
            fi
        else
            log_error "Cannot continue without accepting host key"
            return 5
        fi
    fi
    
    if echo "$ssh_output" | grep -qi "Permission denied"; then
        log_warning "Key-based authentication failed"
        echo ""
        read -p "Would you like to try password authentication? [Y/n]: " try_password
        
        if [[ "$try_password" =~ ^[Yy]$ ]] || [[ -z "$try_password" ]]; then
            log_info "Attempting password authentication..."
            echo "Please enter the password for ${user}@${host}"
            
            if ssh $ssh_opts -o PreferredAuthentications=password "${user}@${host}" "echo 'Connection successful'" 2>/dev/null; then
                log_success "SSH connection successful (password authentication)"
                log_warning "Password authentication works, but key-based auth is recommended"
                echo ""
                echo "For automated backups, you should set up SSH key authentication."
                read -p "Would you like to copy your SSH key now? [Y/n]: " copy_now
                if [[ "$copy_now" =~ ^[Yy]$ ]] || [[ -z "$copy_now" ]]; then
                    if ! check_ssh_key; then
                        log_info "Generating SSH key first..."
                        generate_ssh_key
                    fi
                    copy_ssh_key "$user" "$host" "$port"
                    return 0
                else
                    log_warning "Continuing with password authentication (not ideal for automation)"
                    return 0
                fi
            else
                log_error "Password authentication also failed"
                return 2
            fi
        else
            log_error "SSH key is not authorized on the remote server"
            return 2
        fi
    fi
    
    if echo "$ssh_output" | grep -q "Connection refused"; then
        log_error "SSH connection failed: Connection refused"
        log_warning "The remote server is not accepting connections on port $port"
        return 3
    elif echo "$ssh_output" | grep -q "Connection timed out\|timed out"; then
        log_error "SSH connection failed: Connection timed out"
        log_warning "Cannot reach the remote server (check network/firewall)"
        return 4
    elif echo "$ssh_output" | grep -q "No route to host"; then
        log_error "SSH connection failed: No route to host"
        log_warning "Cannot reach the remote server (check network)"
        return 5
    else
        log_error "SSH connection failed: Unknown error"
        echo ""
        echo "Debug output:"
        echo "$ssh_output"
        return 1
    fi
}

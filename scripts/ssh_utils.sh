#!/usr/bin/env bash

# SSH Utilities for BackMeUp

check_ssh_key() {
    local key_path="${HOME}/.ssh/id_rsa"
    if [[ -f "$key_path" ]]; then
        return 0
    fi
    # Check for other common key types
    if [[ -f "${HOME}/.ssh/id_ed25519" ]]; then
        return 0
    fi
    return 1
}

generate_ssh_key() {
    local key_type="rsa"
    local key_path="${HOME}/.ssh/id_rsa"
    
    # Prefer ed25519 if available (more modern/secure)
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
        echo "⚠️  Automatic key copy failed."
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
        return 0 # Return success so the script continues, assuming user fixed it
    fi
}

test_ssh_connection() {
    local user="$1"
    local host="$2"
    local port="${3:-22}"
    
    echo "Testing connection to ${user}@${host}..."
    ssh -p "$port" -o BatchMode=yes -o ConnectTimeout=5 "${user}@${host}" "echo 'Connection successful'" 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

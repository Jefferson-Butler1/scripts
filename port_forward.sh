#!/bin/zsh

# SSH host alias for MBP
MBP_HOST="MBP"

# Ports to forward
PORTS=(9191 9090 8080 9292)

# Function to check if a port is already in use
port_is_free() {
    ! nc -z localhost $1 2>/dev/null
}

# Build the SSH command with port forwarding
SSH_CMD="ssh -N"
for PORT in "${PORTS[@]}"; do
    if port_is_free $PORT; then
        SSH_CMD+=" -L ${PORT}:localhost:${PORT}"
    else
        echo "Warning: Port $PORT is already in use. Skipping."
    fi
done
SSH_CMD+=" ${MBP_HOST}"

# Start the SSH connection
echo "Starting SSH connection to MBP with port forwarding..."
echo "Forwarded ports: ${PORTS[*]}"
echo "Press Ctrl+C to stop the connection"

eval $SSH_CMD

echo "SSH connection closed."

#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: $0 -u <username> -h <remote_host> [-k <ssh_key_path>] [-l <local_user>]"
    echo ""
    echo "Options:"
    echo "  -u, --user       Username on remote server"
    echo "  -h, --host       Remote server IP address or hostname"
    echo "  -k, --key        Path to SSH key (default: ~/.ssh/id_rsa)"
    echo "  -l, --local-user Local user to run service as (default: current user)"
    echo "  --help           Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -u abakken -h 10.0.0.100"
    echo "  $0 -u abakken -h myserver.example.com -k ~/.ssh/my_key"
    exit 1
}

REMOTE_USER=""
REMOTE_HOST=""
SSH_KEY="$HOME/.ssh/id_rsa"
LOCAL_USER="$USER"

while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--user)
            REMOTE_USER="$2"
            shift 2
            ;;
        -h|--host)
            REMOTE_HOST="$2"
            shift 2
            ;;
        -k|--key)
            SSH_KEY="$2"
            shift 2
            ;;
        -l|--local-user)
            LOCAL_USER="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

if [[ -z "$REMOTE_USER" || -z "$REMOTE_HOST" ]]; then
    echo "Error: Both username (-u) and host (-h) are required"
    echo ""
    usage
fi

# Expand ~ in SSH_KEY path
SSH_KEY="${SSH_KEY/#\~/$HOME}"

if [[ ! -f "$SSH_KEY" ]]; then
    echo "Warning: SSH key not found at $SSH_KEY"
    echo "Make sure the key exists before starting the service."
fi

echo "Installing phonehome service..."
echo "  Local user: $LOCAL_USER"
echo "  Remote host: $REMOTE_HOST"
echo "  Remote user: $REMOTE_USER"
echo "  SSH key: $SSH_KEY"
echo ""

# Check for autossh
if ! command -v autossh &> /dev/null; then
    echo "autossh not found. Installing..."
    sudo apt-get update && sudo apt-get install -y autossh
fi

# Create config directory
sudo mkdir -p /etc/phonehome

# Generate config from template
echo "Creating configuration file..."
sed -e "s|__LOCAL_USER__|${LOCAL_USER}|g" \
    -e "s|__REMOTE_HOST__|${REMOTE_HOST}|g" \
    -e "s|__REMOTE_USER__|${REMOTE_USER}|g" \
    -e "s|__SSH_KEY__|${SSH_KEY}|g" \
    "$SCRIPT_DIR/phonehome.config.template" | sudo tee /etc/phonehome/phonehome.config > /dev/null

sudo chmod 600 /etc/phonehome/phonehome.config

# Install systemd service
echo "Installing systemd service..."
sudo cp "$SCRIPT_DIR/phonehome.service" /etc/systemd/system/phonehome.service
sudo chmod 644 /etc/systemd/system/phonehome.service

# Reload systemd and enable service
echo "Enabling service..."
sudo systemctl daemon-reload
sudo systemctl enable phonehome

echo ""
echo "Installation complete!"
echo ""
echo "Commands:"
echo "  sudo systemctl start phonehome    # Start the service"
echo "  sudo systemctl status phonehome   # Check status"
echo "  sudo journalctl -u phonehome -f   # View logs"
echo ""
echo "IMPORTANT: For access from other machines on the remote network,"
echo "add this to /etc/ssh/sshd_config on $REMOTE_HOST:"
echo ""
echo "    GatewayPorts clientspecified"
echo ""
echo "Then restart sshd: sudo systemctl restart sshd"

#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to print messages with timestamp
log() {
    echo -e "[$(date +"%Y-%m-%d %T")] $*"
}

# Function to check if a service exists and is active
service_exists_and_active() {
    systemctl is-active --quiet "$1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log "Please run this script as root."
    exit 1
fi

log "Starting Tailscale installation and HTTPS configuration for Proxmox."

# Check if this is a Proxmox VE or Proxmox Backup Server system
if [ -f "/etc/pve/.members" ] || [ -d "/etc/pve/nodes" ]; then
    SYSTEM_TYPE="PVE"
    log "Detected Proxmox VE system."
elif [ -f "/etc/proxmox-backup/proxmox-backup.cfg" ] || [ -d "/etc/proxmox-backup" ]; then
    SYSTEM_TYPE="PBS"
    log "Detected Proxmox Backup Server system."
else
    SYSTEM_TYPE="UNKNOWN"
    log "Warning: This doesn't appear to be a Proxmox VE or Proxmox Backup Server system."
    log "The script will continue, but some Proxmox-specific operations may fail."
fi

# Update package lists
log "Updating package lists..."
apt update

# Install dependencies
log "Installing dependencies..."
apt install -y curl jq

# Check if Tailscale is already installed
if command -v tailscale &> /dev/null; then
    log "Tailscale is already installed. Skipping installation."
else
    # Install Tailscale
    log "Installing Tailscale..."
    if ! curl -fsSL https://tailscale.com/install.sh | sh; then
        log "Failed to install Tailscale. Please check your internet connection and try again."
        exit 1
    fi
fi

# Prompt for hostname
read -p "Enter the desired hostname for your Proxmox server (e.g., prox): " TS_HOSTNAME

# Start Tailscale and prompt for authentication
log "Starting Tailscale with hostname '$TS_HOSTNAME'..."
tailscale up --hostname="$TS_HOSTNAME"

log "Please authenticate your Proxmox server in the Tailscale web interface."
read -p "After authentication, press Enter to continue..."

# Add a timeout for Tailscale connection
TIMEOUT=300
START_TIME=$(date +%s)
while true; do
    if tailscale status --json | jq -e '.Self.Online == true' >/dev/null; then
        log "Tailscale is connected."
        break
    else
        CURRENT_TIME=$(date +%s)
        if [ $((CURRENT_TIME - START_TIME)) -ge $TIMEOUT ]; then
            log "Timed out waiting for Tailscale to connect. Please check your Tailscale configuration."
            exit 1
        fi
        log "Waiting for Tailscale to connect..."
        sleep 5
    fi
done

# Retrieve the MagicDNS domain name
log "Retrieving Tailscale domain..."
TS_DOMAIN=$(tailscale status --json | jq -r '.Self.DNSName' | sed "s/$TS_HOSTNAME\.//")

if [ -z "$TS_DOMAIN" ] || [[ "$TS_DOMAIN" == "null" ]]; then
    log "Unable to detect Tailscale domain."
    read -p "Please enter your Tailscale domain (e.g., example.ts.net): " TS_DOMAIN
else
    log "Detected Tailscale domain: $TS_DOMAIN"
    read -p "Is this correct? (y/n): " confirm_domain
    if [ "$confirm_domain" != "y" ] && [ "$confirm_domain" != "Y" ]; then
        read -p "Please enter your Tailscale domain (e.g., example.ts.net): " TS_DOMAIN
    fi
fi

# Full hostname
full_hostname="${TS_HOSTNAME}.${TS_DOMAIN}"

# Obtain TLS certificate
log "Obtaining TLS certificate for ${full_hostname}..."

# Remove the trailing dot if it exists
cert_hostname="${full_hostname%%.}"

# Explanation:
# This line uses parameter expansion to remove a trailing dot:
# 1. ${variable%%pattern} removes the longest matching suffix pattern
# 2. The '.' in %%. is escaped to match a literal dot
# 3. If there's a trailing dot, it's removed; if not, the string is unchanged
#
# How it works step by step:
# - If full_hostname = "example.com.":
#   1. %% looks for the longest suffix matching '.'
#   2. It finds the trailing dot and removes it
#   3. cert_hostname becomes "example.com"
# - If full_hostname = "example.com":
#   1. %% looks for a suffix ending in '.'
#   2. No such suffix is found
#   3. cert_hostname remains "example.com"

if ! tailscale cert "${cert_hostname}"; then
    log "Failed to obtain TLS certificate. Error: $?"
    log "Please check your Tailscale configuration and try again."
    exit 1
fi

# Check if certificate files exist before copying
if [ ! -f "$cert_hostname.crt" ] || [ ! -f "$cert_hostname.key" ]; then
    log "Certificate files not found. Please check if the certificate was obtained successfully."
    exit 1
fi

# Determine Proxmox node name and certificate paths
NODE_NAME=$(hostname)
PVE_CERT_DIR="/etc/pve/nodes/$NODE_NAME"
PBS_CERT_DIR="/etc/proxmox-backup"

# Backup and install certificates based on system type
log "Backing up existing certificates and installing new ones..."

case $SYSTEM_TYPE in
    "PVE")
        # Backup existing PVE certificates
        if [ -f "$PVE_CERT_DIR/pveproxy-ssl.pem" ]; then
            cp "$PVE_CERT_DIR/pveproxy-ssl.pem" "$PVE_CERT_DIR/pveproxy-ssl.pem.backup.$(date +%F_%T)"
            log "Backed up existing PVE certificate."
        fi
        if [ -f "$PVE_CERT_DIR/pveproxy-ssl.key" ]; then
            cp "$PVE_CERT_DIR/pveproxy-ssl.key" "$PVE_CERT_DIR/pveproxy-ssl.key.backup.$(date +%F_%T)"
            log "Backed up existing PVE key."
        fi

        # Install new PVE certificates
        log "Installing new TLS certificate for Proxmox VE..."
        if ! cp "$cert_hostname.crt" "$PVE_CERT_DIR/pveproxy-ssl.pem"; then
            log "Error: Failed to copy certificate. Please check permissions and directory existence."
            exit 1
        fi
        if ! cp "$cert_hostname.key" "$PVE_CERT_DIR/pveproxy-ssl.key"; then
            log "Error: Failed to copy key. Please check permissions and directory existence."
            exit 1
        fi
        ;;
    "PBS")
        # Backup existing PBS certificates
        if [ -f "$PBS_CERT_DIR/proxy.pem" ]; then
            cp "$PBS_CERT_DIR/proxy.pem" "$PBS_CERT_DIR/proxy.pem.backup.$(date +%F_%T)"
            log "Backed up existing PBS certificate."
        fi
        if [ -f "$PBS_CERT_DIR/proxy.key" ]; then
            cp "$PBS_CERT_DIR/proxy.key" "$PBS_CERT_DIR/proxy.key.backup.$(date +%F_%T)"
            log "Backed up existing PBS key."
        fi

        # Install new PBS certificates
        log "Installing new TLS certificate for Proxmox Backup Server..."
        if ! cp "$cert_hostname.crt" "$PBS_CERT_DIR/proxy.pem"; then
            log "Error: Failed to copy certificate. Please check permissions and directory existence."
            exit 1
        fi
        if ! cp "$cert_hostname.key" "$PBS_CERT_DIR/proxy.key"; then
            log "Error: Failed to copy key. Please check permissions and directory existence."
            exit 1
        fi
        ;;
    *)
        log "Warning: Unknown system type. Skipping certificate installation."
        log "You may need to manually install the certificates from:"
        log "  Certificate: $cert_hostname.crt"
        log "  Key: $cert_hostname.key"
        ;;
esac

# Restart appropriate service based on the system type
log "Attempting to restart appropriate service..."
case $SYSTEM_TYPE in
    "PVE")
        if service_exists_and_active "pveproxy.service"; then
            if ! systemctl restart pveproxy.service; then
                log "Warning: Failed to restart pveproxy.service. You may need to restart it manually."
            else
                log "Successfully restarted pveproxy.service."
            fi
        else
            log "Warning: pveproxy.service not found or not active."
        fi
        ;;
    "PBS")
        if service_exists_and_active "proxmox-backup-proxy.service"; then
            if ! systemctl restart proxmox-backup-proxy.service; then
                log "Warning: Failed to restart proxmox-backup-proxy.service. You may need to restart it manually."
            else
                log "Successfully restarted proxmox-backup-proxy.service."
            fi
        else
            log "Warning: proxmox-backup-proxy.service not found or not active."
        fi
        ;;
    *)
        log "No Proxmox-specific service found to restart."
        log "You may need to manually configure your web server to use the new certificates."
        ;;
esac

# Set up automatic certificate renewal
log "Setting up automatic certificate renewal."

# Renewal script path
RENEW_SCRIPT="/usr/local/bin/renew_tailscale_cert.sh"

# Create renewal script with error handling
cat <<EOF > "$RENEW_SCRIPT"
#!/bin/bash
set -e

# System type detected during initial setup
SYSTEM_TYPE="$SYSTEM_TYPE"

# Get current node name and paths
NODE_NAME=\$(hostname)
PVE_CERT_DIR="/etc/pve/nodes/\$NODE_NAME"
PBS_CERT_DIR="/etc/proxmox-backup"
CERT_HOSTNAME="$cert_hostname"

# Obtain new certificate
if ! tailscale cert "\$CERT_HOSTNAME"; then
    echo "Failed to renew certificate"
    exit 1
fi

# Install certificate and restart services based on system type
case \$SYSTEM_TYPE in
    "PVE")
        cp "\$CERT_HOSTNAME.crt" "\$PVE_CERT_DIR/pveproxy-ssl.pem"
        cp "\$CERT_HOSTNAME.key" "\$PVE_CERT_DIR/pveproxy-ssl.key"
        systemctl restart pveproxy.service
        ;;
    "PBS")
        cp "\$CERT_HOSTNAME.crt" "\$PBS_CERT_DIR/proxy.pem"
        cp "\$CERT_HOSTNAME.key" "\$PBS_CERT_DIR/proxy.key"
        systemctl restart proxmox-backup-proxy.service
        ;;
    *)
        echo "Unknown system type: \$SYSTEM_TYPE"
        exit 1
        ;;
esac

echo "Certificate renewed successfully for \$SYSTEM_TYPE"
EOF

# Check if the renewal script was created successfully
if [ ! -f "$RENEW_SCRIPT" ]; then
    log "Failed to create the renewal script. Please check your system's write permissions."
    exit 1
fi

# Make the renewal script executable
chmod +x "$RENEW_SCRIPT"

# Add cron job for automatic renewal
(crontab -l 2>/dev/null; echo "0 0 1 * * $RENEW_SCRIPT") | crontab -

log "Automatic certificate renewal set up with cron."

# Adjust the final message based on the system type
case $SYSTEM_TYPE in
    "PVE")
        log "Configuration complete. You can now access Proxmox VE at https://$cert_hostname:8006/"
        ;;
    "PBS")
        log "Configuration complete. You can now access Proxmox Backup Server at https://$cert_hostname:8007/"
        ;;
    *)
        log "Configuration complete. Please check your system's configuration for the correct access URL."
        ;;
esac

# Final message
echo -e "\nPlease ensure the following:"
echo "- MagicDNS is enabled in your Tailscale admin console."
echo "- You can access the appropriate URL from devices connected to your Tailscale network."
echo -e "\nIf you encounter any issues, please check the logs or ask for assistance."

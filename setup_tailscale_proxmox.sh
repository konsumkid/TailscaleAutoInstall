#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to print messages with timestamp
log() {
    echo -e "[$(date +"%Y-%m-%d %T")] $*"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log "Please run this script as root."
    exit 1
fi

log "Starting Tailscale installation and HTTPS configuration for Proxmox."

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
    if tailscale status | grep -q "100\."; then
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
FULL_HOSTNAME="$TS_HOSTNAME.$TS_DOMAIN"

# Add error handling for certificate obtainment
log "Obtaining TLS certificate for $FULL_HOSTNAME..."
if ! tailscale cert "$FULL_HOSTNAME"; then
    log "Failed to obtain TLS certificate. Please check your Tailscale configuration and try again."
    exit 1
fi

# Check if certificate files exist before copying
if [ ! -f "$FULL_HOSTNAME.crt" ] || [ ! -f "$FULL_HOSTNAME.key" ]; then
    log "Certificate files not found. Please check if the certificate was obtained successfully."
    exit 1
fi

# Backup existing certificates
log "Backing up existing Proxmox certificates..."
cp /etc/pve/local/pveproxy-ssl.pem "/etc/pve/local/pveproxy-ssl.pem.backup.$(date +%F_%T)"
cp /etc/pve/local/pveproxy-ssl.key "/etc/pve/local/pveproxy-ssl.key.backup.$(date +%F_%T)"

# Install the new certificate and key
log "Installing new TLS certificate..."
cp "$FULL_HOSTNAME.crt" /etc/pve/local/pveproxy-ssl.pem
cp "$FULL_HOSTNAME.key" /etc/pve/local/pveproxy-ssl.key

# Restart pveproxy service
log "Restarting Proxmox proxy service..."
systemctl restart pveproxy

# Set up automatic certificate renewal
log "Setting up automatic certificate renewal."

# Renewal script path
RENEW_SCRIPT="/usr/local/bin/renew_tailscale_cert.sh"

# Create renewal script
cat <<EOF > "$RENEW_SCRIPT"
#!/bin/bash
# Renew Tailscale TLS certificate for Proxmox

# Obtain new certificate
tailscale cert $FULL_HOSTNAME

# Backup existing certificates
cp /etc/pve/local/pveproxy-ssl.pem "/etc/pve/local/pveproxy-ssl.pem.backup.\$(date +%F_%T)"
cp /etc/pve/local/pveproxy-ssl.key "/etc/pve/local/pveproxy-ssl.key.backup.\$(date +%F_%T)"

# Install new certificate
cp $FULL_HOSTNAME.crt /etc/pve/local/pveproxy-ssl.pem
cp $FULL_HOSTNAME.key /etc/pve/local/pveproxy-ssl.key

# Restart pveproxy service
systemctl restart pveproxy
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

log "Configuration complete. You can now access Proxmox at https://$FULL_HOSTNAME:8006/"

# Final message
echo -e "\nPlease ensure the following:"
echo "- MagicDNS is enabled in your Tailscale admin console."
echo "- You can access https://$FULL_HOSTNAME:8006/ from devices connected to your Tailscale network."
echo -e "\nIf you encounter any issues, please check the logs or ask for assistance."

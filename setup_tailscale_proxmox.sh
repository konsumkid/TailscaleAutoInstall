#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to print messages with timestamp
log() {
    echo -e "[$(date +"%Y-%m-%d %T")] $*"
}

# Function to check if a service exists and is active
service_exists_and_active() {
    if [ "$SYSTEMD_AVAILABLE" -eq 1 ]; then
        systemctl is-active --quiet "$1"
    else
        return 1
    fi
}

# Function to reset DNS to public resolvers
fix_dns_settings() {
    log "Resetting DNS settings to public resolvers..."
    if [ -f /etc/resolv.conf ]; then
        cp /etc/resolv.conf "/etc/resolv.conf.bak.$(date +%F_%T)"
        cat <<EOF >/etc/resolv.conf
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
        log "DNS settings updated."
    else
        log "Unable to find /etc/resolv.conf. Skipping DNS reset."
    fi
}

# Function to verify internet connectivity and DNS resolution
check_internet_connectivity() {
    log "Checking internet connectivity..."
    if ! ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1; then
        log "Unable to reach the internet."
        read -r -p "Attempt to reset DNS settings? (y/n): " fix_net
        if [ "$fix_net" = "y" ] || [ "$fix_net" = "Y" ]; then
            fix_dns_settings
        else
            log "Please verify your network connection and try again."
        fi
        exit 1
    fi

    if ! ping -c 1 -W 3 tailscale.com >/dev/null 2>&1; then
        log "DNS resolution failed. Old Tailscale settings may be interfering."
        read -r -p "Reset DNS settings to public resolvers? (y/n): " fix_dns
        if [ "$fix_dns" = "y" ] || [ "$fix_dns" = "Y" ]; then
            fix_dns_settings
            if ! ping -c 1 -W 3 tailscale.com >/dev/null 2>&1; then
                log "DNS still failing after reset. Please check your network manually."
                exit 1
            fi
        else
            log "Please check your DNS configuration before continuing."
            exit 1
        fi
    fi
    log "Internet connectivity looks good."
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log "Please run this script as root."
    exit 1
fi

# Path to the certificate renewal helper script
RENEW_SCRIPT="/usr/local/bin/renew_tailscale_cert.sh"

# Remove old renewal script and cron entry if they exist
if [ -f "$RENEW_SCRIPT" ]; then
    log "Old renewal script detected. Removing it."
    rm -f "$RENEW_SCRIPT"
    crontab -l 2>/dev/null | grep -v "$RENEW_SCRIPT" | crontab -
fi

CONTAINER_TYPE="host"
if command -v systemd-detect-virt >/dev/null; then
    ct=$(systemd-detect-virt --container || true)
    if [ "$ct" != "none" ] && [ -n "$ct" ]; then
        CONTAINER_TYPE="$ct"
        log "Detected container environment: $CONTAINER_TYPE"
    fi
fi

if command -v systemctl >/dev/null && [ -d /run/systemd/system ]; then
    SYSTEMD_AVAILABLE=1
else
    SYSTEMD_AVAILABLE=0
    log "Warning: systemctl not available. Service restarts will be skipped."
fi

log "Starting Tailscale installation and HTTPS configuration for Proxmox."

# Ensure network connectivity before proceeding
check_internet_connectivity

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
read -r -p "Enter the desired hostname for your Proxmox server (e.g., prox): " TS_HOSTNAME

# Start Tailscale and prompt for authentication
log "Starting Tailscale with hostname '$TS_HOSTNAME'..."
tailscale up --hostname="$TS_HOSTNAME"

log "Please authenticate your Proxmox server in the Tailscale web interface."
read -r -p "After authentication, press Enter to continue..."

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
    read -r -p "Please enter your Tailscale domain (e.g., example.ts.net): " TS_DOMAIN
else
    log "Detected Tailscale domain: $TS_DOMAIN"
    read -r -p "Is this correct? (y/n): " confirm_domain
    if [ "$confirm_domain" != "y" ] && [ "$confirm_domain" != "Y" ]; then
        read -r -p "Please enter your Tailscale domain (e.g., example.ts.net): " TS_DOMAIN
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

# Detect whether this system is running Proxmox VE or Proxmox Backup Server
if [ -f "/etc/pve/pve.cfg" ]; then
    SYSTEM_TYPE="PVE"
    log "Detected Proxmox VE system."
elif [ -f "/etc/proxmox-backup/proxmox-backup.cfg" ]; then
    SYSTEM_TYPE="PBS"
    log "Detected Proxmox Backup Server system."
else
    SYSTEM_TYPE="UNKNOWN"
    log "Warning: This doesn't appear to be a Proxmox VE or Proxmox Backup Server system."
    log "The script will continue, but some Proxmox-specific operations may fail."
fi

# Backup existing certificates
log "Backing up existing Proxmox certificates..."
if [ -f "$PVE_CERT_DIR/pveproxy-ssl.pem" ]; then
    cp "$PVE_CERT_DIR/pveproxy-ssl.pem" "$PVE_CERT_DIR/pveproxy-ssl.pem.backup.$(date +%F_%T)"
else
    log "Warning: $PVE_CERT_DIR/pveproxy-ssl.pem not found. Skipping backup."
fi

if [ -f "$PVE_CERT_DIR/pveproxy-ssl.key" ]; then
    cp "$PVE_CERT_DIR/pveproxy-ssl.key" "$PVE_CERT_DIR/pveproxy-ssl.key.backup.$(date +%F_%T)"
else
    log "Warning: $PVE_CERT_DIR/pveproxy-ssl.key not found. Skipping backup."
fi

# Install the new certificate and key
log "Installing new TLS certificate..."
if ! cp "$cert_hostname.crt" "$PVE_CERT_DIR/pveproxy-ssl.pem"; then
    log "Error: Failed to copy certificate. Please check permissions and file existence."
    exit 1
fi

if ! cp "$cert_hostname.key" "$PVE_CERT_DIR/pveproxy-ssl.key"; then
    log "Error: Failed to copy key. Please check permissions and file existence."
    exit 1
fi

# Handle Proxmox Backup Server certificates
if [ "$SYSTEM_TYPE" = "PBS" ]; then
    log "Installing PBS certificates..."
    cp "$cert_hostname.crt" "$PBS_CERT_DIR/proxy-cert.pem"
    cp "$cert_hostname.key" "$PBS_CERT_DIR/proxy-key.pem"
fi

# Restart appropriate service based on the system type
log "Attempting to restart appropriate service..."
if [ "$SYSTEMD_AVAILABLE" -eq 1 ]; then
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
else
    log "systemctl not available; skipping service restarts."
fi

# Set up automatic certificate renewal
log "Setting up automatic certificate renewal."

# Renewal script path already defined earlier

# Create renewal script with error handling
cat <<EOF > "$RENEW_SCRIPT"
#!/bin/bash
set -e

# Get current node name and paths
NODE_NAME=\$(hostname)
PVE_CERT_DIR="/etc/pve/nodes/\$NODE_NAME"
PBS_CERT_DIR="/etc/proxmox-backup"

# Detect systemd availability
if command -v systemctl >/dev/null && [ -d /run/systemd/system ]; then
    SYSTEMD_AVAILABLE=1
else
    SYSTEMD_AVAILABLE=0
fi

# Obtain new certificate
if ! tailscale cert "$cert_hostname"; then
    echo "Failed to renew certificate"
    exit 1
fi

# Install new certificate
cp "$cert_hostname.crt" "$PVE_CERT_DIR/pveproxy-ssl.pem"
cp "$cert_hostname.key" "$PVE_CERT_DIR/pveproxy-ssl.key"

# Restart Proxmox services
if [ "\$SYSTEMD_AVAILABLE" -eq 1 ]; then
    systemctl restart pveproxy.service
    systemctl restart pvedaemon.service
fi

# Handle PBS if installed
if [ -f "/etc/proxmox-backup/proxmox-backup.cfg" ]; then
    cp "$cert_hostname.crt" "$PBS_CERT_DIR/proxy-cert.pem"
    cp "$cert_hostname.key" "$PBS_CERT_DIR/proxy-key.pem"
    if [ "\$SYSTEMD_AVAILABLE" -eq 1 ]; then
        systemctl restart proxmox-backup-proxy.service
    fi
fi
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

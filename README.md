# Tailscale Proxmox Setup

## Description
This script automates the process of installing Tailscale on a Proxmox server and configuring HTTPS access using Tailscale's MagicDNS and certificate features.

## Features
- Installs Tailscale on Proxmox
- Configures HTTPS access using Tailscale's MagicDNS
- Sets up automatic certificate renewal
- Provides easy access to Proxmox web interface through Tailscale network

## Prerequisites
- A Proxmox server
- Root access to the Proxmox server
- A Tailscale account

## Installation
1. Clone this repository:
   ```
   git clone https://github.com/yourusername/tailscale-proxmox-setup.git
   ```
2. Navigate to the project directory:
   ```
   cd tailscale-proxmox-setup
   ```
3. Make the script executable:
   ```
   chmod +x setup_tailscale_proxmox.sh
   ```
4. Run the script:
   ```
   sudo ./setup_tailscale_proxmox.sh
   ```

## Usage
Follow the prompts in the script to:
1. Install Tailscale
2. Set up your Proxmox hostname
3. Authenticate with Tailscale
4. Configure HTTPS access

After completion, you can access your Proxmox web interface at `https://your-hostname.your-tailnet-domain:8006`

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments
- Tailscale for their excellent VPN solution
- Proxmox team for their powerful virtualization platform

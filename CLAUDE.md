# CLAUDE.md - AI Assistant Guide

This document provides guidance for AI assistants working with the TailscaleAutoInstall repository.

## Project Overview

**TailscaleAutoInstall** is a bash automation script that installs Tailscale on Proxmox servers and configures HTTPS access using Tailscale's MagicDNS and certificate features.

### Purpose
- Automate Tailscale installation on Proxmox VE and Proxmox Backup Server
- Configure HTTPS access via Tailscale certificates
- Set up automatic certificate renewal via cron

### Target Environment
- Proxmox VE (PVE) or Proxmox Backup Server (PBS)
- Debian-based Linux systems
- Requires root access

## Repository Structure

```
TailscaleAutoInstall/
├── README.md                    # User-facing documentation
├── setup_tailscale_proxmox.sh   # Main automation script (~300 lines)
└── CLAUDE.md                    # This file - AI assistant guide
```

## Main Script Architecture

The script `setup_tailscale_proxmox.sh` follows this execution flow:

1. **Initialization** (lines 1-35)
   - Sets strict mode with `set -e`
   - Defines helper functions (`log`, `service_exists_and_active`)
   - Root permission check
   - **System type detection** (PVE vs PBS vs UNKNOWN)

2. **Dependency Installation** (lines 37-55)
   - Updates package lists
   - Installs `curl` and `jq`
   - Installs Tailscale (if not present)

3. **Tailscale Configuration** (lines 57-83)
   - Prompts for hostname
   - Starts Tailscale with user authentication
   - Waits for connection with 5-minute timeout

4. **Certificate Management** (lines 85-196)
   - Retrieves MagicDNS domain
   - Obtains TLS certificate
   - Conditional backup and installation based on system type (PVE or PBS)

5. **Service Restart** (lines 198-227)
   - Restarts appropriate services based on system type

6. **Automatic Renewal Setup** (lines 229-307)
   - Creates system-type-aware renewal script at `/usr/local/bin/renew_tailscale_cert.sh`
   - Configures monthly cron job

## Code Conventions

### Shell Script Standards

- **Shebang**: Always use `#!/bin/bash`
- **Error Handling**: Use `set -e` at script start
- **Logging**: Use the `log()` function for all output messages
  ```bash
  log "Your message here"
  ```
- **User Input**: Use `read -p` for interactive prompts
- **Command Checks**: Use `command -v <cmd> &> /dev/null` to check if commands exist
- **Service Checks**: Use the `service_exists_and_active()` helper function

### Variable Naming

- **UPPERCASE**: Environment variables and constants (e.g., `TS_HOSTNAME`, `PVE_CERT_DIR`)
- **lowercase**: Local/temporary variables (e.g., `cert_hostname`, `full_hostname`)
- **NODE_NAME**: System hostname variable
- **SYSTEM_TYPE**: Values are `PVE`, `PBS`, or `UNKNOWN`

### Path Conventions

| Path | Purpose |
|------|---------|
| `/etc/pve/nodes/$NODE_NAME/` | PVE certificate directory |
| `/etc/proxmox-backup/` | PBS certificate directory |
| `/usr/local/bin/renew_tailscale_cert.sh` | Auto-renewal script |

### Certificate File Names

- PVE: `pveproxy-ssl.pem` (cert), `pveproxy-ssl.key` (key)
- PBS: `proxy.pem` (cert), `proxy.key` (key)

## Development Workflows

### Testing Changes

Since this script requires root access and modifies system services, testing should be done:

1. **Syntax Check**:
   ```bash
   bash -n setup_tailscale_proxmox.sh
   ```

2. **ShellCheck Linting**:
   ```bash
   shellcheck setup_tailscale_proxmox.sh
   ```

3. **Manual Testing**: Test on a non-production Proxmox instance

### Making Changes

1. Keep backward compatibility with existing installations
2. Maintain the logging pattern using `log()`
3. Add error handling for any new operations
4. Test on both PVE and PBS if changes affect system type detection

### Git Workflow

- Commit messages should describe what changed and why
- Keep commits atomic (one logical change per commit)
- Test syntax before committing

## Important Considerations

### Security

- Script requires root privileges
- Handles TLS certificates - never log certificate contents
- Backup files are created with timestamps to prevent data loss

### Notes

- **Trailing Dot Removal**: The script uses `${full_hostname%%.}` expansion to remove trailing dots from DNS names (see comments in script).
- **Timeout**: 5-minute (300 second) timeout for Tailscale connection.
- **System Type Detection**: Uses directory/file existence checks (`/etc/pve/nodes`, `/etc/proxmox-backup`) rather than config file checks for more reliable detection.

### Dependencies

- `curl` - For downloading Tailscale installer
- `jq` - For parsing Tailscale JSON output
- `systemctl` - For service management
- `crontab` - For automatic renewal scheduling

## Common Tasks for AI Assistants

### Adding a New Feature

1. Identify where in the execution flow it belongs
2. Add appropriate `log()` statements
3. Include error handling with meaningful messages
4. Update `README.md` if user-visible behavior changes

### Fixing Bugs

1. Understand the current behavior and expected behavior
2. Check if the bug affects both PVE and PBS
3. Consider backward compatibility with existing installations
4. Add regression prevention (additional checks if appropriate)

### Code Review Checklist

- [ ] Uses `log()` for user-facing messages
- [ ] Includes error handling for new operations
- [ ] Variables follow naming conventions
- [ ] No hardcoded paths that should be variables
- [ ] Backward compatible with existing installations
- [ ] ShellCheck passes without errors

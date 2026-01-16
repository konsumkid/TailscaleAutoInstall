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
├── setup_tailscale_proxmox.sh   # Main automation script (276 lines)
└── CLAUDE.md                    # This file - AI assistant guide
```

## Main Script Architecture

The script `setup_tailscale_proxmox.sh` follows this execution flow:

1. **Initialization** (lines 1-20)
   - Sets strict mode with `set -e`
   - Defines helper functions (`log`, `service_exists_and_active`)
   - Root permission check

2. **Dependency Installation** (lines 22-42)
   - Updates package lists
   - Installs `curl` and `jq`
   - Installs Tailscale (if not present)

3. **Tailscale Configuration** (lines 44-70)
   - Prompts for hostname
   - Starts Tailscale with user authentication
   - Waits for connection with 5-minute timeout

4. **Certificate Management** (lines 72-161)
   - Retrieves MagicDNS domain
   - Obtains TLS certificate
   - Backs up existing Proxmox certificates
   - Installs new certificates

5. **System Type Detection** (lines 162-204)
   - Detects PVE vs PBS vs unknown
   - Restarts appropriate services

6. **Automatic Renewal Setup** (lines 206-276)
   - Creates renewal script at `/usr/local/bin/renew_tailscale_cert.sh`
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
- PBS: `proxy-cert.pem` (cert), `proxy-key.pem` (key)

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

### Known Quirks

1. **Line 156-160**: PBS certificate handling occurs before system type detection (lines 162-173). This is a potential bug - PBS certificates are copied based on `$SYSTEM_TYPE` which may not be set yet.

2. **Trailing Dot Removal** (lines 93-111): Extensive comments explain the `${full_hostname%%.}` expansion for removing trailing dots from DNS names.

3. **Timeout**: 5-minute (300 second) timeout for Tailscale connection.

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

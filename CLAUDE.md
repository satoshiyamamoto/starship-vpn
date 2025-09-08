# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Starship VPN Module is a single-file Bash script for Starship prompt that detects VPN connections. It's a performance-optimized module supporting multiple VPN clients (Cisco AnyConnect, FortiClient, Tailscale, WireGuard, ZeroTier).

## File Structure

- `starship-vpn.sh` - Main executable script containing all VPN detection logic
- `README.md` - Complete documentation and usage instructions

## Common Commands

### Testing the Script
```bash
# Basic VPN detection
./starship-vpn.sh detect

# Check connection status (for Starship 'when' condition)
./starship-vpn.sh connected

# Get prompt output
./starship-vpn.sh prompt

# Cache management
./starship-vpn.sh cache clear
./starship-vpn.sh cache status

# Toggle VPN module on/off
source <(./starship-vpn.sh toggle)

# Show help
./starship-vpn.sh help
```

### Development and Debugging
```bash
# Make script executable after changes
chmod +x starship-vpn.sh

# Test interface detection manually
ifconfig -l | grep -oE '(wg[0-9]+|tailscale[0-9]*|utun[0-9]+|zt[a-z0-9]+)'

# Check for active VPN interfaces with IPs
for iface in $(ifconfig -l | grep -oE '(wg[0-9]+|tailscale[0-9]*|utun[0-9]+|zt[a-z0-9]+)'); do
  echo "=== $iface ==="
  ifconfig $iface 2>/dev/null | grep "inet "
done

# Check FortiClient status
scutil --nc list | grep forticlient

# Check Cisco status
echo "state" | /opt/cisco/secureclient/bin/vpn -s

# Clear all caches and test fresh detection
./starship-vpn.sh cache clear && rm -f ~/.cache/starship/vpn_connected && ./starship-vpn.sh

# Test connection check performance
time ./starship-vpn.sh connected
```

## Architecture

### Core Components

1. **VPN Detection Engine** (`vpn_detect` function):
   - Interface-based detection using single `ifconfig` call with regex filtering
   - IP address validation to prevent false positives on inactive interfaces
   - Service-based detection via `scutil --nc` (FortiClient) and Cisco CLI
   - Dual-cache system with separate TTLs (5s for display, 2s for connection checks)
   - Multi-VPN display support with configurable separators

2. **Configuration System**:
   - In-script variables at top of file for customization:
     - `VPN_SHOW_IP` - Show/hide IP addresses
     - `VPN_SHOW_VENDOR` - Show/hide vendor prefixes
     - `VPN_SHOW_ALL` - Display all VPNs vs first only
     - `VPN_SEPARATOR` - Multi-VPN separator string
     - `VPN_CACHE_TTL` - Cache timeout for display (5 seconds)
     - `VPN_CACHE_TTL_CONNECTED` - Cache timeout for connection checks (2 seconds)

3. **Performance Optimizations**:
   - Fast-mode-only architecture (no detailed mode)
   - Single `ifconfig` call per check instead of per-interface calls
   - Real-time connection checks with shorter cache TTL
   - Interface validation with IP address confirmation
   - Early exit when `VPN_SHOW_ALL=false`
   - Short command timeouts (0.3s)
   - Dual-cache system to balance performance and accuracy

### VPN Detection Methods

- **Tailscale**: IP range detection (100.x.x.x) on any interface
- **WireGuard**: Interface name pattern (`wg[0-9]+`)
- **ZeroTier**: Interface name pattern (`zt[a-z0-9]+`)
- **FortiClient**: Service status via `scutil --nc list`
- **Cisco AnyConnect**: CLI status check via `/opt/cisco/secureclient/bin/vpn`

### Cache System

Cache file locations:
- Display cache: `${XDG_CACHE_HOME:-$HOME/.cache}/starship/vpn_cache`
- Connection cache: `${XDG_CACHE_HOME:-$HOME/.cache}/starship/vpn_connected`

Cache behavior:
- Display cache: 5-second TTL, stores formatted output string
- Connection cache: 2-second TTL, stores connection status (0/1)
- Cross-platform timestamp handling (macOS/Linux)
- Connection checks use shorter TTL to prevent stale status after long processes

## Configuration Notes

The script uses in-file configuration variables rather than external config files for simplicity. All customization is done by editing the top section of `starship-vpn.sh`.

Environment variable `STARSHIP_VPN_ENABLED=true` controls module activation in Starship.

## Platform Compatibility

- **Primary**: macOS (full support)
- **Secondary**: Linux (interface detection works, service detection may need adaptation)
- Shell compatibility: bash and zsh
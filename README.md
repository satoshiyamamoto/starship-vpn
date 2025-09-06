# Starship VPN Module

A custom VPN detection module for [Starship](https://starship.rs/) prompt, created with vibe coding sessions. This module provides real-time VPN connection status in your terminal prompt.

## Features

- **Multi-VPN Support**: Detects Cisco AnyConnect, FortiClient, Tailscale, WireGuard, ZeroTier, and generic VPNs
- **Configurable Display**: Show/hide IP addresses, vendor prefixes, and customize separators
- **Performance Optimized**: Uses caching mechanism for fast prompt rendering
- **Environment Control**: Toggle display via environment variables
- **Cross-Shell Compatible**: Works with both bash and zsh

## Supported VPN Clients

| VPN Client | Prefix | Detection Method |
|------------|--------|------------------|
| Cisco AnyConnect/Secure Client | `cisco` | Process + CLI state check |
| FortiClient | `forticlient` | Network configuration |
| Tailscale | `tailscale` | IP range (100.x.x.x) |
| WireGuard | `wireguard` | Interface name pattern |
| ZeroTier | `zerotier` | Interface name pattern |
| Generic VPN | `vpn` | Private IP ranges |

## Installation

1. Clone or download the script:
   ```bash
   git clone https://github.com/satoshiyamamoto/starship-vpn.git
   ```

2. Make the script executable:
   ```bash
   chmod +x starship-vpn/starship-vpn.sh
   ```

3. Create a symlink (optional):
   ```bash
   ln -s /path/to/starship-vpn/starship-vpn.sh ~/.config/starship-vpn.sh
   ```

4. Add the custom module to your `starship.toml`:
   ```toml
   [custom.vpn]
   disabled = false
   command = "~/.config/starship-vpn.sh prompt"
   when = """
   test "${STARSHIP_VPN_ENABLED:-false}" = "true" && ~/.config/starship-vpn.sh connected
   """
   symbol = "🔒"
   style = "bg:#1d2230"
   format = '[[ $symbol$output ](fg:#769ff0 bg:#1d2230)]($style)'
   ```

5. Enable the module:
   ```bash
   export STARSHIP_VPN_ENABLED=true
   ```

## Configuration

The script supports several configuration options:

```bash
# Configuration variables (edit script)
VPN_SHOW_IP=false          # Show IP addresses/server info
VPN_SHOW_VENDOR=true       # Show VPN vendor prefixes
VPN_SHOW_ALL=true          # Show all VPNs or just first
VPN_SEPARATOR=" | "        # Separator between multiple VPNs
VPN_CACHE_TTL=5           # Cache TTL in seconds
```

### Display Options

| VPN_SHOW_IP | VPN_SHOW_VENDOR | Display Example |
|-------------|-----------------|-----------------|
| `false` | `false` | 🔒 (symbol only) |
| `false` | `true` | 🔒 cisco |
| `true` | `false` | 🔒 vpn.company.com |
| `true` | `true` | 🔒 cisco:vpn.company.com |

### Separator Options

Choose from various separators for multiple VPN connections:
- `" | "` (default): cisco | tailscale
- `" · "`: cisco · tailscale
- `" / "`: cisco / tailscale
- `" • "`: cisco • tailscale
- `", "`: cisco, tailscale

## Usage

### Command Line Interface

```bash
# Basic VPN detection
./starship-vpn.sh detect

# Check connection status
./starship-vpn.sh connected

# Get prompt output
./starship-vpn.sh prompt

# Count active connections
./starship-vpn.sh count

# Show only VPN types
./starship-vpn.sh types

# Cache management
./starship-vpn.sh cache clear
./starship-vpn.sh cache status

# Toggle module on/off
source <(./starship-vpn.sh toggle)

# Show help
./starship-vpn.sh help
```

### Environment Variables

```bash
# Enable/disable the module
export STARSHIP_VPN_ENABLED=true    # Enable
unset STARSHIP_VPN_ENABLED          # Disable (default)
```

## Performance

- **Caching**: 5-second cache to minimize system calls
- **Optimized Detection**: Efficient VPN client detection logic
- **Conditional Display**: Only runs when environment variable is set

## Platform Support

- **macOS**: Full support (primary development platform)
- **Linux**: Partial support (may require adaptation for specific distributions)

## Development

This module was created through vibe coding sessions, iteratively improving VPN detection logic and user experience based on real-world usage scenarios.

### Key Development Phases

1. **Initial Implementation**: Basic Powerlevel10k compatibility
2. **Multi-VPN Support**: Added detection for various VPN clients
3. **Performance Optimization**: Implemented caching and efficient detection
4. **User Experience**: Added configuration options and environment controls
5. **Bug Fixes**: Resolved false detection and edge cases

## Contributing

Feel free to submit issues, feature requests, or pull requests. This project benefits from community feedback and real-world testing scenarios.

## License

MIT License - feel free to use and modify as needed.

## Acknowledgments

- Inspired by Powerlevel10k's vpn_ip module
- Built for the Starship prompt ecosystem
- Created through collaborative vibe coding sessions
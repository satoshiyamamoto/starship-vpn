# Starship VPN Module

A fast, lightweight VPN detection module for [Starship](https://starship.rs/) prompt. This module provides real-time VPN connection status in your terminal prompt with optimized performance for multiple VPN environments.

## Features

- **Multi-VPN Support**: Detects Cisco AnyConnect, FortiClient, Tailscale, WireGuard, ZeroTier
- **High Performance**: Fast mode optimized for ultra-quick prompt rendering
- **Multiple VPN Display**: Show all connected VPNs simultaneously
- **Configurable Display**: Customize IP visibility, vendor prefixes, and separators
- **Smart Caching**: Dual-cache system with configurable TTL for optimal performance
- **Environment Control**: Control display via environment variables
- **Cross-Shell Compatible**: Works with both bash and zsh

## Supported VPN Clients

| VPN Client | Prefix | Detection Method | Example Output |
|------------|--------|------------------|----------------|
| Cisco AnyConnect/Secure Client | `cisco` | CLI state check | `cisco` |
| FortiClient | `forticlient` | Network configuration | `forticlient` |
| Tailscale | `tailscale` | IP range (100.x.x.x) | `tailscale` |
| WireGuard | `wireguard` | Interface name pattern | `wireguard` |
| ZeroTier | `zerotier` | Interface name pattern | `zerotier` |

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/satoshiyamamoto/starship-vpn.git
   cd starship-vpn
   ```

2. Make the script executable:
   ```bash
   chmod +x starship-vpn.sh
   ```

3. Add the custom module to your `starship.toml`:
   ```toml
   [custom.vpn]
   disabled = false
   command = "~/Projects/src/github.com/satoshiyamamoto/starship-vpn/starship-vpn.sh prompt"
   when = """
   test "${STARSHIP_VPN_ENABLED:-false}" = "true" && ~/Projects/src/github.com/satoshiyamamoto/starship-vpn/starship-vpn.sh connected
   """
   symbol = ""
   style = "bg:#394260"
   format = '[[ $symbol $output ](fg:#769ff0 bg:#394260)]($style)'
   ignore_timeout = true  # Recommended for consistent performance
   ```

4. Enable the module:
   ```bash
   export STARSHIP_VPN_ENABLED=true
   ```

## Configuration

The script supports several configuration options (edit the script file):

```bash
# Configuration - Fast Mode with Multi-VPN Support
VPN_SHOW_IP=false           # Set to true to show IP addresses
VPN_SHOW_VENDOR=true        # Set to false to hide VPN vendor prefixes  
VPN_SHOW_ALL=true           # Show all connected VPNs
VPN_SEPARATOR=" | "         # Separator between multiple VPNs
VPN_CACHE_TTL=5             # Cache TTL for prompt display (seconds)
VPN_CACHE_TTL_CONNECTED=2   # Cache TTL for connection check (seconds)
```

### Display Examples

#### Multiple VPN Connections
**Connected to**: Cisco AnyConnect, FortiClient, Tailscale

| Configuration | Display Output |
|---------------|----------------|
| Default | `cisco | forticlient | tailscale` |
| `VPN_SHOW_VENDOR=false` | (symbol only) |
| `VPN_SHOW_IP=true` | `cisco:Connected | forticlient | tailscale:100.64.1.1` |
| `VPN_SEPARATOR=" • "` | `cisco • forticlient • tailscale` |
| `VPN_SHOW_ALL=false` | `cisco` (first VPN only) |

#### Separator Options

Choose from various separators for multiple VPN connections:
- `" | "` (default): `cisco | tailscale`
- `" · "`: `cisco · tailscale` 
- `" / "`: `cisco / tailscale`
- `" • "`: `cisco • tailscale`
- `", "`: `cisco, tailscale`

## Usage

### Command Line Interface

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

# Show help
./starship-vpn.sh help
```

### Environment Variables

```bash
# Enable/disable the module
export STARSHIP_VPN_ENABLED=true    # Enable
unset STARSHIP_VPN_ENABLED          # Disable (default)
```

## Performance Optimizations

- **Fast Mode Only**: Simplified implementation for maximum speed
- **Dual-Cache System**: Separate caches for prompt display (5s) and connection check (2s)
- **Real-time Connection Check**: Cache-free option for accurate status after long processes
- **Single ifconfig Call**: Optimized to make only one system call per check
- **Early Exit**: Stops detection at first VPN when `VPN_SHOW_ALL=false`
- **Optimized Detection**: Efficient interface scanning with regex filtering
- **Short Timeouts**: 0.3 second timeouts for external commands
- **Interface Pre-filtering**: Only scans relevant VPN interfaces

### Performance Benchmarks

- **Cache hit**: ~1ms response time
- **Connection check (with cache)**: ~130-180ms for real-time accuracy
- **Cold detection**: ~50-200ms depending on VPN count
- **Multiple VPN detection**: ~100-300ms for 3+ concurrent VPNs
- **With `ignore_timeout = true`**: No impact on prompt rendering speed

## Troubleshooting

### Common Issues

1. **Timeout warnings**: Add `ignore_timeout = true` to your custom.vpn module
2. **Missing VPN detection**: Check if your VPN creates standard interfaces
3. **Slow prompt**: Enable caching and consider setting `VPN_SHOW_ALL=false`
4. **VPN showing after long processes**: Fixed in latest version with real-time connection checks
5. **False positives on utun interfaces**: Now validates interfaces have active IP addresses

### Debug Commands

```bash
# Check what interfaces are detected
ifconfig -l | grep -oE '(wg[0-9]+|tailscale[0-9]*|utun[0-9]+|zt[a-z0-9]+)'

# Check FortiClient status
scutil --nc list | grep forticlient

# Check Cisco status  
echo "state" | /opt/cisco/secureclient/bin/vpn -s

# Clear cache and test
./starship-vpn.sh cache clear && ./starship-vpn.sh
```

## Platform Support

- **macOS**: Full support (primary development platform)
- **Linux**: Partial support (interface detection works, service detection may need adaptation)

## Development History

This module evolved through multiple iterations:

1. **Initial Implementation**: Basic Powerlevel10k compatibility
2. **Multi-VPN Support**: Added detection for various VPN clients  
3. **Performance Crisis**: Addressed timeout issues with heavy optimization
4. **Fast Mode Implementation**: Simplified to fast-mode-only architecture
5. **Multi-VPN Display**: Added support for showing multiple simultaneous VPNs
6. **Precision Tuning**: Removed false positives and duplicate detections
7. **Cache Accuracy Fix**: Implemented dual-cache system with shorter TTL for connection checks
8. **Interface Validation**: Added IP address validation to eliminate false positives from inactive interfaces

## Contributing

Feel free to submit issues, feature requests, or pull requests. This project benefits from community feedback and real-world testing scenarios.

## License

MIT License - feel free to use and modify as needed.

## Acknowledgments

- Inspired by Powerlevel10k's vpn_ip module
- Built for the Starship prompt ecosystem
- Optimized through real-world usage and performance testing
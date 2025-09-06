#!/usr/bin/env bash

# VPN IP Detection Script
# Compatible with Powerlevel10k vpn module functionality
# Supports: Cisco AnyConnect, FortiClient, Tailscale, WireGuard, ZeroTier, and generic VPNs
# Compatible with both bash and zsh
# Optimized for fast Starship prompt rendering

# Configuration
VPN_SHOW_IP=false       # Set to false to show only text (like p10k default)
VPN_SHOW_VENDOR=true    # Set to false to hide VPN vendor prefixes
VPN_SHOW_ALL=true       # Set to true to show all VPN IPs
VPN_SEPARATOR=" | "     # Separator between multiple VPNs: " | ", " · ", " / ", " • ", ", "
VPN_CACHE_TTL=5         # Cache TTL in seconds
VPN_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/starship"
VPN_CACHE_FILE="$VPN_CACHE_DIR/vpn_cache"

# VPN Type Prefixes (constants)
readonly VPN_PREFIX_CISCO="cisco"
readonly VPN_PREFIX_FORTICLIENT="forticlient"
readonly VPN_PREFIX_TAILSCALE="tailscale"
readonly VPN_PREFIX_WIREGUARD="wireguard"
readonly VPN_PREFIX_ZEROTIER="zerotier"
readonly VPN_PREFIX_GENERIC="vpn"

# Cache functions for performance
vpn_cache_valid() {
    if [[ ! -f "$VPN_CACHE_FILE" ]]; then
        return 1
    fi

    local cache_time
    # macOS uses stat -f %m, Linux uses stat -c %Y
    if [[ "$OSTYPE" == "darwin"* ]]; then
        cache_time=$(stat -f %m "$VPN_CACHE_FILE" 2>/dev/null || echo 0)
    else
        cache_time=$(stat -c %Y "$VPN_CACHE_FILE" 2>/dev/null || echo 0)
    fi

    [[ $(($(date +%s) - cache_time)) -lt $VPN_CACHE_TTL ]]
}

vpn_cache_read() {
    [[ -f "$VPN_CACHE_FILE" ]] && cat "$VPN_CACHE_FILE"
}

vpn_cache_write() {
    if ! mkdir -p "$VPN_CACHE_DIR" 2>/dev/null; then
        return 1
    fi
    if ! echo "$1" > "$VPN_CACHE_FILE" 2>/dev/null; then
        return 1
    fi
    return 0
}

vpn_detect() {
    # Check cache first for fast response
    if vpn_cache_valid; then
        vpn_cache_read
        return
    fi

    local vpn_ips=""
    local vpn_type=""
    local ip=""
    local iface=""

    # Check Cisco AnyConnect specifically (it doesn't always create typical VPN interfaces)
    if command -v /opt/cisco/secureclient/bin/vpn >/dev/null 2>&1; then
        local cisco_state=$(echo "state" | timeout 2 /opt/cisco/secureclient/bin/vpn -s 2>/dev/null | grep "接続中" | head -1)
        if [[ -n "$cisco_state" ]]; then
            # Try to extract server info
            local cisco_info=$(echo "stats" | timeout 2 /opt/cisco/secureclient/bin/vpn -s 2>/dev/null | grep -E "notice:.*に接続されています" | sed 's/.*notice: //;s/に接続されています.*//' | head -1)
            if [[ -n "$cisco_info" ]]; then
                if [[ "$VPN_SHOW_IP" == true ]]; then
                    if [[ "$VPN_SHOW_VENDOR" == true ]]; then
                        vpn_ips="${VPN_PREFIX_CISCO}:${cisco_info}"
                    else
                        vpn_ips="${cisco_info}"
                    fi
                else
                    if [[ "$VPN_SHOW_VENDOR" == true ]]; then
                        vpn_ips="${VPN_PREFIX_CISCO}"
                    else
                        vpn_ips=" "  # Space to trigger display but show only symbol
                    fi
                fi
            else
                if [[ "$VPN_SHOW_IP" == true ]]; then
                    if [[ "$VPN_SHOW_VENDOR" == true ]]; then
                        vpn_ips="${VPN_PREFIX_CISCO}:Connected"
                    else
                        vpn_ips="Connected"
                    fi
                else
                    if [[ "$VPN_SHOW_VENDOR" == true ]]; then
                        vpn_ips="${VPN_PREFIX_CISCO}"
                    else
                        vpn_ips=" "  # Space to trigger display but show only symbol
                    fi
                fi
            fi
        fi
    fi

    # Get all network interfaces with IPs (skip if Cisco already found and show_all is false)
    if [[ -z "$vpn_ips" ]] || [[ "$VPN_SHOW_ALL" == true ]]; then
        # If we have Cisco VPN and are showing all, add separator
        local need_separator=false
        if [[ -n "$vpn_ips" ]] && [[ "$VPN_SHOW_ALL" == true ]]; then
            need_separator=true
        fi
        for iface in $(ifconfig -l 2>/dev/null); do
            # Check if interface matches VPN pattern
            # Powerlevel10k pattern: (gpd|wg|(.*tun)|tailscale)[0-9]*|(zt.*)
            if [[ "$iface" =~ ^(gpd|wg|tailscale)[0-9]*$ ]] || \
               [[ "$iface" =~ tun[0-9]*$ ]] || \
               [[ "$iface" =~ ^zt ]] || \
               [[ "$iface" =~ ^utun[0-9]+$ ]]; then

                # Get IP address for this interface
                ip=$(ifconfig "$iface" 2>/dev/null | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | head -1)

                if [[ -n "$ip" ]]; then
                    # Determine VPN type based on IP range or interface name
                    vpn_type=""

                    # Tailscale uses 100.x.x.x range
                    if [[ "$ip" =~ ^100\. ]]; then
                        vpn_type="$VPN_PREFIX_TAILSCALE"
                    # WireGuard interfaces
                    elif [[ "$iface" =~ ^wg ]]; then
                        vpn_type="$VPN_PREFIX_WIREGUARD"
                    # ZeroTier interfaces
                    elif [[ "$iface" =~ ^zt ]]; then
                        vpn_type="$VPN_PREFIX_ZEROTIER"
                    # Check for FortiClient VPN (must be actually Connected, not just Disconnected)
                    elif scutil --nc list 2>/dev/null | grep -E "Connected.*forticlient" >/dev/null && [[ "$ip" =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.) ]]; then
                        vpn_type="$VPN_PREFIX_FORTICLIENT"
                    # Check for Cisco AnyConnect via running processes and private IP
                    elif ps aux 2>/dev/null | grep -E "(cisco|anyconnect)" | grep -v grep >/dev/null && [[ "$ip" =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.) ]]; then
                        # Double-check that this isn't a FortiClient interface (FortiClient takes precedence)
                        if ! scutil --nc list 2>/dev/null | grep -E "Connected.*forticlient" >/dev/null && \
                           ! scutil --nc list 2>/dev/null | grep -E "Disconnected.*forticlient" >/dev/null; then
                            vpn_type="$VPN_PREFIX_CISCO"
                        fi
                    # Generic VPN (private IP ranges) - only if no known VPN service claims it
                    elif [[ "$ip" =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.) ]]; then
                        # Skip if this looks like a stale FortiClient interface
                        if ! scutil --nc list 2>/dev/null | grep -E "Disconnected.*forticlient" >/dev/null; then
                            vpn_type="$VPN_PREFIX_GENERIC"
                        fi
                    fi

                    if [[ -n "$vpn_type" ]]; then
                        if [[ "$VPN_SHOW_IP" == true ]]; then
                            if [[ -n "$vpn_ips" ]] || [[ "$need_separator" == true ]]; then
                                vpn_ips="${vpn_ips}${VPN_SEPARATOR}"
                                need_separator=false
                            fi
                            if [[ "$VPN_SHOW_VENDOR" == true ]]; then
                                vpn_ips="${vpn_ips}${vpn_type}:${ip}"
                            else
                                vpn_ips="${vpn_ips}${ip}"
                            fi
                        else
                            if [[ "$VPN_SHOW_VENDOR" == true ]]; then
                                if [[ -n "$vpn_ips" ]] || [[ "$need_separator" == true ]]; then
                                    vpn_ips="${vpn_ips}${VPN_SEPARATOR}"
                                    need_separator=false
                                fi
                                vpn_ips="${vpn_ips}${vpn_type}"
                            else
                                # Just show symbol (no text)
                                if [[ -z "$vpn_ips" ]]; then
                                    vpn_ips=" "  # Space to trigger display but show only symbol
                                fi
                            fi
                        fi

                        # If not showing all, break after first VPN
                        if [[ "$VPN_SHOW_ALL" == false ]] && [[ -n "$vpn_ips" ]]; then
                            break
                        fi
                    fi
                fi
            fi
        done
    fi

    # Output result and cache it (without icon - managed by starship.toml)
    local result=""
    if [[ -n "$vpn_ips" ]]; then
        # If VPN_SHOW_IP is false and we only have a space, output empty string for symbol-only display
        if [[ "$VPN_SHOW_IP" == false ]] && [[ "$vpn_ips" == " " ]]; then
            result=""
        else
            result="${vpn_ips}"
        fi
    fi

    # Cache the result for next time
    vpn_cache_write "$result"

    # Output the result - empty output still triggers display with symbol
    echo "$result"
}

# Function to check if VPN is connected (returns 0 if connected, 1 if not)
vpn_connected() {
    local result=$(vpn_detect)
    [[ -n "$result" ]] && return 0 || return 1
}

# Function to get VPN status for prompt integration
vpn_prompt() {
    local result=$(vpn_detect)
    [[ -n "$result" ]] && echo "$result"
}

# Function to get VPN count
vpn_count() {
    local result=$(vpn_detect)
    if [[ -n "$result" ]]; then
        # Count the number of VPN types (count colons)
        echo "$result" | grep -o ":" | wc -l | tr -d ' '
    else
        echo "0"
    fi
}

# Function to get only VPN types (no IPs)
vpn_types() {
    local result=$(vpn_detect)
    if [[ -n "$result" ]]; then
        # Extract only the VPN types
        echo "$result" | sed 's/:[^ ]*//g'
    fi
}

# Main execution (when script is run directly)
# Compatible with both bash and zsh script detection
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ "${(%):-%N}" == "${0}" ]]; then
    case "${1:-detect}" in
        "detect"|"")
            vpn_detect
            ;;
        "connected")
            if vpn_connected; then
                echo "Connected"
                exit 0
            else
                echo "Disconnected"
                exit 1
            fi
            ;;
        "prompt")
            vpn_prompt
            ;;
        "count")
            vpn_count
            ;;
        "types")
            vpn_types
            ;;
        "cache")
            case "${2:-status}" in
                "clear")
                    rm -f "$VPN_CACHE_FILE" && echo "Cache cleared"
                    ;;
                "status")
                    if vpn_cache_valid; then
                        local cache_time
                        if [[ "$OSTYPE" == "darwin"* ]]; then
                            cache_time=$(stat -f %m "$VPN_CACHE_FILE" 2>/dev/null || echo 0)
                        else
                            cache_time=$(stat -c %Y "$VPN_CACHE_FILE" 2>/dev/null || echo 0)
                        fi
                        echo "Cache is valid (timestamp: $cache_time)"
                        echo "Content: $(vpn_cache_read)"
                    else
                        echo "Cache is invalid or missing"
                    fi
                    ;;
                *)
                    echo "Usage: $0 cache [clear|status]"
                    ;;
            esac
            ;;
        "toggle")
            current_state="${STARSHIP_VPN_ENABLED:-false}"
            if [[ "$current_state" == "true" ]]; then
                echo "unset STARSHIP_VPN_ENABLED"
                echo "# VPN module disabled (default)" >&2
            else
                echo "export STARSHIP_VPN_ENABLED=true"
                echo "# VPN module enabled" >&2
            fi
            ;;
        "help"|"-h"|"--help")
            echo "VPN IP Detection Script (Optimized for Starship)"
            echo ""
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  detect    Show VPN connection with icon and details (default)"
            echo "  connected Check if any VPN is connected"
            echo "  prompt    Show VPN info for prompt integration"
            echo "  count     Show number of active VPN connections"
            echo "  types     Show only VPN types (no IPs)"
            echo "  cache     Manage cache (clear|status)"
            echo "  toggle    Toggle VPN module on/off (use with source)"
            echo "  help      Show this help message"
            echo ""
            echo "Configuration (edit script):"
            echo "  VPN_SHOW_IP=true/false     Show IP addresses/server info"
            echo "  VPN_SHOW_VENDOR=true/false Show VPN vendor prefixes"
            echo "  VPN_SHOW_ALL=true/false    Show all VPNs or just first"
            echo "  VPN_SEPARATOR=\" | \"        Separator between multiple VPNs"
            echo "  VPN_CACHE_TTL=5            Cache TTL in seconds"
            echo ""
            echo "Environment Variables:"
            echo "  STARSHIP_VPN_ENABLED=true  Enable VPN module (disabled by default)"
            echo ""
            echo "Toggle Usage:"
            echo "  source <(~/.config/starship-vpn.sh toggle)  # Toggle on/off"
            echo "  Note: Uses Starship's 'when' condition for control"
            echo "  Default: Disabled (requires STARSHIP_VPN_ENABLED=true to show)"
            echo ""
            echo "Performance:"
            echo "  - Uses 5-second cache for fast repeated calls"
            echo "  - Optimized 'when' condition in Starship config"
            echo "  - Compatible with both bash and zsh"
            echo ""
            echo "Supported VPNs (Prefix: Description):"
            echo "  $VPN_PREFIX_CISCO         Cisco AnyConnect/Secure Client"
            echo "  $VPN_PREFIX_FORTICLIENT   FortiClient"
            echo "  $VPN_PREFIX_TAILSCALE     Tailscale"
            echo "  $VPN_PREFIX_WIREGUARD     WireGuard"
            echo "  $VPN_PREFIX_ZEROTIER      ZeroTier"
            echo "  $VPN_PREFIX_GENERIC           Generic VPN"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
fi

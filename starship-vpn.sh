#!/usr/bin/env bash

# Starship VPN Detection Script - Fast Mode Only
# Optimized for ultra-fast prompt rendering
# Supports: Cisco AnyConnect, FortiClient, Tailscale, WireGuard, ZeroTier, and generic VPNs
# Compatible with both bash and zsh

# Configuration - Fast Mode with Multi-VPN Support
VPN_SHOW_IP=false       # Set to false to show only text (like p10k default)
VPN_SHOW_VENDOR=true    # Set to false to hide VPN vendor prefixes
VPN_SHOW_ALL=true       # Show all connected VPNs
VPN_SEPARATOR=" | "     # Separator between multiple VPNs
VPN_CACHE_TTL=5         # Cache TTL in seconds
VPN_CACHE_TTL_CONNECTED=2  # Shorter TTL for connection check (when condition)
VPN_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/starship"
VPN_CACHE_FILE="$VPN_CACHE_DIR/vpn_cache"
VPN_CACHE_FILE_CONNECTED="$VPN_CACHE_DIR/vpn_connected"

# VPN Type Prefixes (constants)
readonly VPN_PREFIX_CISCO="cisco"
readonly VPN_PREFIX_FORTICLIENT="forticlient"
readonly VPN_PREFIX_TAILSCALE="tailscale"
readonly VPN_PREFIX_WIREGUARD="wireguard"
readonly VPN_PREFIX_ZEROTIER="zerotier"
readonly VPN_PREFIX_GENERIC="vpn"

# Cache functions
vpn_cache_valid() {
    [[ -f "$VPN_CACHE_FILE" ]] || return 1
    
    local cache_time
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
    mkdir -p "$VPN_CACHE_DIR" 2>/dev/null || return 1
    echo "$1" > "$VPN_CACHE_FILE" 2>/dev/null
}

# Fast VPN detection with multi-VPN support
vpn_detect() {
    # Check cache first
    if vpn_cache_valid; then
        vpn_cache_read
        return
    fi
    
    local results=()
    local detected_ips=()
    local has_tailscale=false
    local has_cisco=false
    local has_forticlient=false
    
    # Quick interface scan for common VPNs
    for iface in $(ifconfig -l 2>/dev/null | grep -oE '(wg[0-9]+|tailscale[0-9]*|utun[0-9]+|zt[a-z0-9]+|gpd[0-9]+|tun[0-9]+)'); do
        local ip=$(ifconfig "$iface" 2>/dev/null | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | head -1)
        
        if [[ -n "$ip" ]]; then
            local vpn_type=""
            local vpn_entry=""
            
            # Fast type detection with service-specific IP ranges
            if [[ "$ip" =~ ^100\. ]]; then
                vpn_type="$VPN_PREFIX_TAILSCALE"
                has_tailscale=true
            elif [[ "$iface" =~ ^wg ]]; then
                vpn_type="$VPN_PREFIX_WIREGUARD"
            elif [[ "$iface" =~ ^zt ]]; then
                vpn_type="$VPN_PREFIX_ZEROTIER"
            fi
            
            # Only add if we have a specific VPN type (not generic)
            if [[ -n "$vpn_type" ]]; then
                if [[ "$VPN_SHOW_IP" == true ]]; then
                    vpn_entry="${VPN_SHOW_VENDOR:+${vpn_type}:}${ip}"
                else
                    vpn_entry="${VPN_SHOW_VENDOR:+${vpn_type}}"
                fi
                results+=("$vpn_entry")
                detected_ips+=("$ip")
                
                # Early exit if not showing all VPNs
                if [[ "$VPN_SHOW_ALL" != true ]]; then
                    break
                fi
            fi
        fi
    done
    
    # Check for service-based VPNs (FortiClient and Cisco)
    if ([[ ${#results[@]} -eq 0 ]] || [[ "$VPN_SHOW_ALL" == true ]]); then
        # Check FortiClient via scutil
        if scutil --nc list 2>/dev/null | grep -q "Connected.*com\.fortinet\.forticlient"; then
            local forticlient_entry="${VPN_SHOW_VENDOR:+${VPN_PREFIX_FORTICLIENT}}"
            results+=("$forticlient_entry")
            has_forticlient=true
        fi
        
        # Check Cisco AnyConnect
        if command -v /opt/cisco/secureclient/bin/vpn >/dev/null 2>&1; then
            if echo "state" | timeout 0.5 /opt/cisco/secureclient/bin/vpn -s 2>/dev/null | grep -q "接続中"; then
                local cisco_entry="${VPN_SHOW_VENDOR:+${VPN_PREFIX_CISCO}}"
                results+=("$cisco_entry")
                has_cisco=true
            fi
        fi
    fi
    
    # Combine results
    local final_result=""
    if [[ ${#results[@]} -gt 0 ]]; then
        # Join array elements with separator
        local IFS="$VPN_SEPARATOR"
        final_result="${results[*]}"
    fi
    
    # Cache and output result
    vpn_cache_write "$final_result"
    echo "$final_result"
}

# Fast connection check for Starship 'when' condition
vpn_connected() {
    # Use shorter TTL cache for connection check
    # This balances performance with accuracy
    
    # Check cache with shorter TTL
    if [[ -f "$VPN_CACHE_FILE_CONNECTED" ]]; then
        local cache_time
        if [[ "$OSTYPE" == "darwin"* ]]; then
            cache_time=$(stat -f %m "$VPN_CACHE_FILE_CONNECTED" 2>/dev/null || echo 0)
        else
            cache_time=$(stat -c %Y "$VPN_CACHE_FILE_CONNECTED" 2>/dev/null || echo 0)
        fi
        
        if [[ $(($(date +%s) - cache_time)) -lt $VPN_CACHE_TTL_CONNECTED ]]; then
            [[ "$(cat "$VPN_CACHE_FILE_CONNECTED")" == "1" ]] && return 0 || return 1
        fi
    fi
    
    # Perform actual check
    local connected=0
    
    # Single ifconfig call with optimized parsing
    local ifconfig_output=$(ifconfig 2>/dev/null)
    
    # Check for WireGuard or ZeroTier (fast check by interface name)
    if echo "$ifconfig_output" | grep -qE '^(wg[0-9]+|zt[a-z0-9]+):'; then
        connected=1
    # Check for Tailscale IP (100.x.x.x)
    elif echo "$ifconfig_output" | grep -q "inet 100\."; then
        connected=1
    # Quick FortiClient check
    elif scutil --nc list 2>/dev/null | grep -q "Connected.*com\.fortinet\.forticlient"; then
        connected=1
    # Quick Cisco check
    elif command -v /opt/cisco/secureclient/bin/vpn >/dev/null 2>&1; then
        if echo "state" | timeout 0.3 /opt/cisco/secureclient/bin/vpn -s 2>/dev/null | grep -q "接続中"; then
            connected=1
        fi
    fi
    
    # Cache result
    mkdir -p "$VPN_CACHE_DIR" 2>/dev/null
    echo "$connected" > "$VPN_CACHE_FILE_CONNECTED" 2>/dev/null
    
    [[ $connected -eq 1 ]] && return 0 || return 1
}

# Simple prompt function
vpn_prompt() {
    local result=$(vpn_detect)
    [[ -n "$result" ]] && echo "$result"
}

# Main execution
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
        "cache")
            case "${2:-status}" in
                "clear")
                    rm -f "$VPN_CACHE_FILE" && echo "Cache cleared"
                    ;;
                "status")
                    if vpn_cache_valid; then
                        echo "Cache is valid"
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
                echo "# VPN module disabled" >&2
            else
                echo "export STARSHIP_VPN_ENABLED=true"
                echo "# VPN module enabled" >&2
            fi
            ;;
        "help"|"-h"|"--help")
            echo "Starship VPN Detection Script - Fast Mode"
            echo ""
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  detect    Show VPN connection (default)"
            echo "  connected Check if any VPN is connected"
            echo "  prompt    Show VPN info for prompt"
            echo "  cache     Manage cache (clear|status)"
            echo "  toggle    Toggle VPN module on/off"
            echo "  help      Show this help"
            echo ""
            echo "Configuration (edit script):"
            echo "  VPN_SHOW_IP=true/false     Show IP addresses"
            echo "  VPN_SHOW_VENDOR=true/false Show VPN vendor prefixes"
            echo "  VPN_SHOW_ALL=true/false    Show all VPNs or just first"
            echo "  VPN_SEPARATOR=\" | \"        Separator between multiple VPNs"
            echo "  VPN_CACHE_TTL=10           Cache TTL in seconds"
            echo ""
            echo "Environment:"
            echo "  STARSHIP_VPN_ENABLED=true  Enable VPN module"
            echo ""
            echo "Supported VPNs:"
            echo "  - Cisco AnyConnect/Secure Client"
            echo "  - FortiClient"
            echo "  - Tailscale (100.x.x.x)"
            echo "  - WireGuard (wg interfaces)"
            echo "  - ZeroTier (zt interfaces)"
            echo "  - Generic VPN (private IP ranges)"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
fi
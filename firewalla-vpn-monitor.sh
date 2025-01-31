#!/bin/bash

# ===================================================================
# Firewalla VPN Monitor Script
# ===================================================================
# This script continuously monitors a WireGuard VPN connection 
# on Firewalla and automatically restarts it if necessary.
#
# HOW TO USE:
# 1. Save this script to a file (e.g., ~/firewalla-vpn-monitor.sh).
# 2. Make the script executable: chmod +x ~/firewalla-vpn-monitor.sh
# 3. Run it in the background: nohup ~/firewalla-vpn-monitor.sh &
# 4. (Optional) Add it to system startup using systemd (instructions below).
#
# This script will:
# ✅ Monitor the WireGuard VPN connection
# ✅ Detect when the VPN is inactive (no handshake for 2+ minutes)
# ✅ Check if VPN traffic is passing (using a ping test)
# ✅ If VPN is down for 5+ minutes, reload its configuration
# ✅ Recreate the WireGuard configuration to handle PIA token expiration
# ===================================================================

# CONFIGURATION
INTERFACE="vpn_SWISS_PIA"   # The name of your WireGuard VPN interface
CHECK_INTERVAL=60           # How often to check the VPN (seconds)
DOWN_TIME=0                 # Tracks how long the VPN has been down
MAX_DOWN_TIME=300           # Time before restarting the VPN (seconds)
PIA_SCRIPT="/home/pi/pia-firewalla.sh"  # Script to regenerate WireGuard config
PIA_CONF_PATH="/etc/wireguard/$INTERFACE.conf"  # Adjust this path as needed

# VPN connectivity check target (Quad9 DNS, known to be stable)
VPN_CHECK_IP="9.9.9.9"

echo "Starting Firewalla VPN Monitor..."

while true; do
    # ===================================================================
    # STEP 1: Check the last WireGuard handshake
    # ===================================================================
    # The latest handshake timestamp tells us when the VPN last communicated.
    # If there's no handshake for more than 120 seconds, assume VPN is down.
    HANDSHAKE_TIME=$(sudo wg show "$INTERFACE" latest-handshakes | awk '{print $2}')
    CURRENT_TIME=$(date +%s)

    if [[ -z "$HANDSHAKE_TIME" ]] || (( CURRENT_TIME - HANDSHAKE_TIME > 120 )); then
        echo "$(date): No recent handshake from WireGuard!"
        ((DOWN_TIME+=CHECK_INTERVAL))
    else
        echo "$(date): WireGuard handshake is active"

        # ===================================================================
        # STEP 2: Verify VPN is passing traffic (Ping Test)
        # ===================================================================
        # Even if a handshake exists, we confirm the VPN is actually routing traffic.
        if ping -c 3 -I "$INTERFACE" "$VPN_CHECK_IP" &>/dev/null; then
            echo "$(date): VPN connectivity is working"
            DOWN_TIME=0  # Reset counter if all checks pass
        else
            echo "$(date): VPN interface exists, handshake is recent, but no internet!"
            ((DOWN_TIME+=CHECK_INTERVAL))
        fi
    fi

    # ===================================================================
    # STEP 3: Restart VPN if it's been down for too long
    # ===================================================================
    # If the VPN has been inactive for 5+ minutes, regenerate the config and reload WireGuard.
    if [ $DOWN_TIME -ge $MAX_DOWN_TIME ]; then
        echo "$(date): VPN has been down for $((MAX_DOWN_TIME / 60)) minutes! Restarting VPN..."

        # ===================================================================
        # 3.1: Run PIA script to regenerate WireGuard config
        # ===================================================================
        # WHY IS THIS NECESSARY?
        # PIA (Private Internet Access) uses authentication tokens for WireGuard VPN access.
        # These tokens have a limited lifespan. When they expire, the VPN will stop working,
        # even if the connection was previously valid.
        #
        # The PIA script ensures:
        # - A new authentication token is retrieved
        # - The WireGuard `.conf` file is updated with a new token
        # - Firewalla is using the latest PIA VPN server information
        #
        # If PIA authentication fails, this step prevents the VPN from getting stuck
        # with an expired token.
        sudo "$PIA_SCRIPT"

        # ===================================================================
        # 3.2: Apply the new WireGuard configuration
        # ===================================================================
        # Instead of trying to extract the active WireGuard config (which does NOT work),
        # we directly load the fresh PIA-generated config file.
        # This ensures Firewalla is using the latest authentication credentials.
        if [[ -f "$PIA_CONF_PATH" ]]; then
            sudo wg syncconf "$INTERFACE" "$PIA_CONF_PATH"
        else
            echo "$(date): ERROR: WireGuard config file not found: $PIA_CONF_PATH"
        fi

        # Reset counter after restarting the VPN
        DOWN_TIME=0
    fi

    # Wait before checking again
    sleep $CHECK_INTERVAL
done


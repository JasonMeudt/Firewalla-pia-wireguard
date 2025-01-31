pia-firewalla.sh - A script to set up and configure PIA WireGuard on Firewalla
#

# ========================================================
# USAGE:
#
# This script automates the setup of **Private Internet Access (PIA) WireGuard VPN** on Firewalla.
#
# ✅ **What this script does:**
# 1. **Clones/updates** the `pia-wg` repository (which handles PIA authentication)
# 2. **Runs `pia-wg.sh -r -c`** to generate a **new WireGuard configuration** (required because PIA tokens expire)
# 3. **Copies the generated `.conf` file** to Firewalla’s **WireGuard profile directories**
# 4. **Generates Firewalla-specific WireGuard support files**:
#    - `.endpoint_routes`
#    - `.json`
#    - `.settings`
#
# ✅ **How to use this script:**
# 1. **Copy this script to Firewalla and make it executable:**
#    ```bash
#    chmod +x pia-firewalla.sh
#    ```
# 2. **Run the script:**
#    ```bash
#    sudo ./pia-firewalla.sh
#    ```
# 3. **Once the script completes, go to the Firewalla GUI and manually activate the WireGuard profile.**


firewalla-vpn-monitor.sh - a script to reload a new wireguard configuration if the PIA token expires.

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

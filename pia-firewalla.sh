#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name: pia-firewalla.sh
#
# Purpose:
#   This script automates the process of setting up Private Internet Access (PIA)
#   WireGuard VPN on a Firewalla system. It:
#
#   1. **Clones or updates** the pia-wg repository from GitHub into /home/pi/pia-wg.
#   2. **Ensures the pia-wg.sh script is executable**.
#   3. **Runs pia-wg.sh** to generate a WireGuard configuration file (`pia.conf`).
#   4. **Parses the output** to determine the VPN region.
#   5. **Copies the WireGuard config** to Firewalla’s wg_profile directory.
#   6. **Ensures JSON and settings files are created** for Firewalla compatibility.
#
# Usage:
#   - Run the script manually: `./pia-firewalla.sh`
#   - Schedule with cron: `crontab -e`
#       Example (run every hour): `0 * * * * /home/pi/pia-firewalla.sh`
#
# Configuration:
#   - The `pia-wg.sh` script’s configuration settings are located in:
#     `/etc/pia-wg/pia-wg.conf`
#
# Output Files:
#   - `/home/pi/.config/pia-wg/pia.conf` (Primary WireGuard config)
#   - `/home/pi/.firewalla/run/wg_profile/WG_<Region>.conf` (Firewalla WG profile)
#   - `/home/pi/.firewalla/run/wg_profile/WG_<Region>.json` (WG JSON config)
#   - `/home/pi/.firewalla/run/wg_profile/WG_<Region>.settings` (WG settings)
#
# Notes:
#   - This script requires Git and WireGuard installed.
#   - If pia-wg.sh fails, manually check the logs in `/tmp/pia-wg-output.log`.
# -----------------------------------------------------------------------------

set -euo pipefail  # Exit on errors, prevent uninitialized variables

# --- Configuration Variables ---
REPO_URL="https://github.com/triffid/pia-wg.git"
REPO_DIR="/home/pi/pia-wg"
PIAWG_SCRIPT="wg-pia.sh"
PIA_CONFIG_SOURCE="/home/pi/.config/pia-wg/pia.conf"
LOG_FILE="/tmp/pia-wg-output.log"

# Firewalla WireGuard profile paths
DEST1="/home/pi/.firewalla/run/wg_profile"
DEST2="/media/home-rw/overlay/pi/.firewalla/run/wg_profile"

# --- Initialize Log File ---
: > "$LOG_FILE"  # Clear previous logs

# Logging helper function
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# --- Step 1: Clone or Update the pia-wg Repository ---
if [[ ! -d "$REPO_DIR" ]]; then
  log "Cloning pia-wg repository..."
  git clone "$REPO_URL" "$REPO_DIR"
else
  log "Repository exists. Checking for updates..."
  pushd "$REPO_DIR" >/dev/null
  git fetch --all
  git checkout main || git checkout master
  if [[ -n "$(git status --porcelain)" ]]; then
    log "Local changes detected. Resetting to match remote..."
    git reset --hard origin/main || git reset --hard origin/master
  fi
  git pull --rebase
  popd >/dev/null
fi

# --- Step 2: Ensure the WireGuard Setup Script is Executable ---
log "Making $PIAWG_SCRIPT executable..."
chmod +x "${REPO_DIR}/pia-wg.sh"

# --- Step 3: Run WireGuard Setup Script ---
log "Running $PIAWG_SCRIPT -r -c..."
pushd "$REPO_DIR" >/dev/null
./pia-wg.sh -r -c 2>&1 | tee "$LOG_FILE"  # Run script and log output
popd >/dev/null

# --- Step 4: Verify WireGuard Config is Created ---
log "Checking for $PIA_CONFIG_SOURCE..."
RETRIES=10
while [[ ! -f "$PIA_CONFIG_SOURCE" && $RETRIES -gt 0 ]]; do
  log "Waiting for pia.conf to be generated... ($RETRIES retries left)"
  sleep 1
  (( RETRIES-- ))
done

if [[ ! -f "$PIA_CONFIG_SOURCE" ]]; then
  log "ERROR: $PIA_CONFIG_SOURCE not found! Check logs at $LOG_FILE."
  exit 1
fi
log "WireGuard configuration found: $PIA_CONFIG_SOURCE"

# --- Step 5: Parse VPN Region from Log Output ---
log "Parsing VPN region from script output..."
registering_line=$(grep -E "Registering public key with " "$LOG_FILE" || true)
WG_CONFIG_NAME="WG_PIA"

if [[ -n "$registering_line" ]]; then
    region=$(grep -oP "(?<=with ).*?(?= [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)" <<< "$registering_line")
    region_no_spaces=${region// /}
    combined="WG_${region_no_spaces}"
    WG_CONFIG_NAME=$(echo "$combined" | cut -c1-10)  # Truncate to 10 chars
    log "Parsed region: $region -> Config Name: $WG_CONFIG_NAME"
else
    log "WARNING: Could not parse region. Using default name: $WG_CONFIG_NAME"
fi

FINAL_NAME="${WG_CONFIG_NAME}.conf"

# --- Step 6: Copy Configuration to Firewalla ---
log "Copying WireGuard configuration to Firewalla..."
cp -f "$PIA_CONFIG_SOURCE" "$DEST1/$FINAL_NAME"
cp -f "$PIA_CONFIG_SOURCE" "$DEST2/$FINAL_NAME"

# --- Step 7: Generate Firewalla JSON Configuration ---
generate_json_from_conf() {
    local conf_file="$1"
    local json_file="${conf_file%.conf}.json"

    log "Generating JSON configuration from $conf_file..."

    local private_key=$(awk -F ' = ' '/PrivateKey/ {print $2}' "$conf_file")
    local address=$(awk -F ' = ' '/Address/ {print $2}' "$conf_file")
    local dns_servers=$(awk -F ' = ' '/DNS/ {print $2}' "$conf_file")
    local public_key=$(awk -F ' = ' '/PublicKey/ {print $2}' "$conf_file")
    local endpoint=$(awk -F ' = ' '/Endpoint/ {print $2}' "$conf_file")

    # Force allowedIPs to "0.0.0.0/0"
    local allowed_ips="0.0.0.0/0"

    if [[ -z "$private_key" || -z "$public_key" || -z "$address" || -z "$endpoint" ]]; then
        log "ERROR: Missing essential WireGuard fields! Skipping JSON generation."
        return 1
    fi

    local dns_json="[]"
    if [[ -n "$dns_servers" ]]; then
        IFS=', ' read -r -a dns_array <<< "$dns_servers"
        dns_json=$(printf '"%s",' "${dns_array[@]}")
        dns_json="[${dns_json%,}]"  
    fi

    local json="{\"peers\":[{\"publicKey\":\"$public_key\",\"endpoint\":\"$endpoint\",\"persistentKeepalive\":20,\"allowedIPs\":[\"$allowed_ips\"]}],\"addresses\":[\"$address\"],\"privateKey\":\"$private_key\",\"dns\":$dns_json}"

    echo "$json" > "$json_file"
    log "JSON saved to $json_file"
}

generate_json_from_conf "$DEST1/$FINAL_NAME"
generate_json_from_conf "$DEST2/$FINAL_NAME"

log "Setup complete. WireGuard configuration copied as $FINAL_NAME."
exit 0

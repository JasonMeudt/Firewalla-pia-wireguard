#!/bin/bash
#
# pia-firewalla.sh - A script to set up and configure PIA WireGuard on Firewalla
#

# ========================================================
# **USAGE:**
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
#
# ========================================================

# ==========================
# 🔹 DEFINE VARIABLES
# ==========================

# Git repository for `pia-wg`, a tool for PIA WireGuard setup
REPO_URL="https://github.com/triffid/pia-wg"
INSTALL_DIR="/home/pi/pia-wg"

# Location where `pia-wg.sh` generates the WireGuard configuration file
PIA_CONF_SOURCE="/home/pi/.config/pia-wg/pia.conf"

# Firewalla's **WireGuard Profile Directories** (where VPN config files are stored)
WG_PROFILE_DIR_1="/home/pi/.firewalla/run/wg_profile/"
WG_PROFILE_DIR_2="/media/home-rw/overlay/pi/.firewalla/run/wg_profile/"

# WireGuard configuration name (must be **≤ 10 characters**)
WG_CONFIG_NAME="SWISS_PIA"

# Ensure required directories exist
mkdir -p "$(dirname "$PIA_CONF_SOURCE")"
mkdir -p "$WG_PROFILE_DIR_1"
mkdir -p "$WG_PROFILE_DIR_2"

# ==========================
# 🔹 CLONE OR UPDATE PIA-WG REPOSITORY
# ==========================
echo "Cloning or updating the PIA-WG repository..."

if [ -d "$INSTALL_DIR" ]; then
    echo "Repository already exists. Pulling latest updates..."
    cd "$INSTALL_DIR" && git pull
else
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# ==========================
# 🔹 RUN PIA-WG SETUP SCRIPT
# ==========================
cd "$INSTALL_DIR" || exit 1
chmod +x pia-wg.sh

echo "Running PIA-WG setup script..."
./pia-wg.sh -r -c

# Wait briefly to ensure PIA setup completes
sleep 2

# ==========================
# 🔹 VERIFY PIA CONFIG EXISTS
# ==========================
echo "Ensuring the PIA WireGuard config is generated..."

if [ -f "$PIA_CONF_SOURCE" ]; then
    echo "Copying PIA WireGuard config to Firewalla directories..."

    # Copy the PIA-generated WireGuard config to **both Firewalla profile directories**
    cp "$PIA_CONF_SOURCE" "$WG_PROFILE_DIR_1/$WG_CONFIG_NAME.conf"
    cp "$PIA_CONF_SOURCE" "$WG_PROFILE_DIR_2/$WG_CONFIG_NAME.conf"

    # ==========================
    # 🔹 EXTRACT CONFIGURATION VALUES
    # ==========================
    # Parse values from the WireGuard `.conf` file
    PRIVATE_KEY=$(awk -F' = ' '/PrivateKey/ {print $2}' "$PIA_CONF_SOURCE")
    ADDRESS=$(awk -F' = ' '/Address/ {print $2}' "$PIA_CONF_SOURCE" | cut -d ',' -f1)
    DNS_SERVERS=$(awk -F' = ' '/DNS/ {print $2}' "$PIA_CONF_SOURCE")
    PUBLIC_KEY=$(awk -F' = ' '/PublicKey/ {print $2}' "$PIA_CONF_SOURCE")
    ALLOWED_IPS=$(awk -F' = ' '/AllowedIPs/ {print $2}' "$PIA_CONF_SOURCE")
    ENDPOINT=$(awk -F' = ' '/Endpoint/ {print $2}' "$PIA_CONF_SOURCE")
    KEEPALIVE="20"  # Default keepalive interval

    # Validate extracted values
    [[ -z "$PRIVATE_KEY" ]] && { echo "❌ Error: PrivateKey is missing!"; exit 1; }
    [[ -z "$ADDRESS" ]] && { echo "❌ Error: Address is missing!"; exit 1; }
    [[ -z "$DNS_SERVERS" ]] && { echo "❌ Error: DNS is missing!"; exit 1; }
    [[ -z "$PUBLIC_KEY" ]] && { echo "❌ Error: PublicKey is missing!"; exit 1; }
    [[ -z "$ALLOWED_IPS" ]] && { echo "❌ Error: AllowedIPs is missing!"; exit 1; }
    [[ -z "$ENDPOINT" ]] && { echo "❌ Error: Endpoint is missing!"; exit 1; }

    # ==========================
    # 🔹 GENERATE FIREWALLA JSON SETTINGS
    # ==========================
    echo "Generating Firewalla JSON settings file..."
    
    # Convert DNS servers into a JSON array
    IFS=',' read -ra DNS_ARRAY <<< "$DNS_SERVERS"
    DNS_JSON=$(printf '"%s",' "${DNS_ARRAY[@]}")
    DNS_JSON="[${DNS_JSON%,}]"

    JSON_CONTENT=$(cat <<EOF
{
  "privateKey": "$PRIVATE_KEY",
  "addresses": ["$ADDRESS"],
  "dns": $DNS_JSON,
  "peers": [
    {
      "persistentKeepalive": $KEEPALIVE,
      "publicKey": "$PUBLIC_KEY",
      "allowedIPs": ["$ALLOWED_IPS"],
      "endpoint": "$ENDPOINT"
    }
  ]
}
EOF
)

    echo "$JSON_CONTENT" > "$WG_PROFILE_DIR_1/$WG_CONFIG_NAME.json"
    echo "$JSON_CONTENT" > "$WG_PROFILE_DIR_2/$WG_CONFIG_NAME.json"

    # ==========================
    # 🔹 GENERATE FIREWALLA SETTINGS FILE
    # ==========================
    echo "Generating Firewalla settings file..."
    CURRENT_TIMESTAMP=$(date +%s.%N)

    SETTINGS_CONTENT=$(cat <<EOF
{
  "serverSubnets": [],
  "overrideDefaultRoute": true,
  "routeDNS": true,
  "strictVPN": true,
  "createdDate": $CURRENT_TIMESTAMP,
  "displayName": "$WG_CONFIG_NAME",
  "subtype": "wireguard"
}
EOF
)

    echo "$SETTINGS_CONTENT" > "$WG_PROFILE_DIR_1/$WG_CONFIG_NAME.settings"
    echo "$SETTINGS_CONTENT" > "$WG_PROFILE_DIR_2/$WG_CONFIG_NAME.settings"

    # Create empty `.endpoint_routes` files
    touch "$WG_PROFILE_DIR_1/$WG_CONFIG_NAME.endpoint_routes"
    touch "$WG_PROFILE_DIR_2/$WG_CONFIG_NAME.endpoint_routes"

    echo "✅ Firewalla WireGuard setup complete!"
else
    echo "❌ Error: PIA WireGuard config not found at $PIA_CONF_SOURCE"
    exit 1
fi

# ==========================
# 🔹 FINAL CONFIRMATION
# ==========================
echo "Setup complete! Go to the Firewalla GUI and activate the WireGuard profile manually."


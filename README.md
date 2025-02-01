# PIA WireGuard Setup and Monitoring for Firewalla

This repository contains two scripts for automating the setup and maintenance of **Private Internet Access (PIA) WireGuard VPN** on Firewalla.

## 📜 Scripts Overview

### 🔹 `pia-firewalla.sh` - Setup and Configure PIA WireGuard on Firewalla

This script automates the process of setting up **PIA WireGuard VPN** on Firewalla.

#### ✅ Features:

- **Clones or updates** the `pia-wg` repository (handles PIA authentication)
- **Generates a new WireGuard configuration** (since PIA tokens expire regularly)
- **Copies the `.conf` file** to Firewalla’s WireGuard profile directories
- **Creates Firewalla-specific support files:**
  - `.endpoint_routes`
  - `.json`
  - `.settings`

#### 🚀 How to Use:

1. Copy this script to Firewalla and make it executable:
   ```bash
   chmod +x pia-firewalla.sh
   ```
2. Run the script:
   ```bash
   sudo ./pia-firewalla.sh
   ```
3. Once completed, go to the Firewalla GUI and manually activate the WireGuard profile.

---

### 🔹 `firewalla-vpn-monitor.sh` - Monitor and Reload WireGuard on Token Expiration

This script continuously monitors the WireGuard VPN connection on Firewalla and **automatically restarts it if necessary**.

#### ✅ Features:

- **Monitors** the WireGuard VPN connection
- **Detects inactivity** (no handshake for 2+ minutes)
- **Checks VPN traffic** (via a ping test)
- **If the VPN is down for 5+ minutes, reloads the configuration**
- **Regenerates WireGuard configuration when the PIA token expires**

#### 🚀 How to Use:

1. Save this script to a file (e.g., `~/firewalla-vpn-monitor.sh`).
2. Make the script executable:
   ```bash
   chmod +x ~/firewalla-vpn-monitor.sh
   ```
3. Run it in the background:
   ```bash
   nohup ~/firewalla-vpn-monitor.sh &
   ```
4. *(Optional)* Add it to system startup using systemd (see instructions below).

---

## 🔧 Systemd Setup (Optional)

For automatic startup and monitoring, you can create a systemd service:

1. Create a new systemd service file:
   ```bash
   sudo nano /etc/systemd/system/firewalla-vpn-monitor.service
   ```
2. Add the following content:
   ```ini
   [Unit]
   Description=Firewalla VPN Monitor
   After=network.target

   [Service]
   ExecStart=/path/to/firewalla-vpn-monitor.sh
   Restart=always
   User=root

   [Install]
   WantedBy=multi-user.target
   ```
3. Save and exit, then enable the service:
   ```bash
   sudo systemctl enable firewalla-vpn-monitor
   sudo systemctl start firewalla-vpn-monitor
   ```

Now, the monitoring script will run automatically on system startup.

---

## 📜 License

This project is licensed under the MIT License.

---

## 💡 Contributions

Pull requests and improvements are welcome! If you find issues, please open an issue on GitHub.

---

## 🔗 Related Resources

- [Private Internet Access (PIA) WireGuard Setup](https://www.privateinternetaccess.com/)
- [Firewalla Official Site](https://firewalla.com/)

---

## 📥 Download Instructions

To download this file directly from GitHub:

1. Navigate to the repository on GitHub.
2. Click on the `README.md` file.
3. Click the **Raw** button.
4. Right-click anywhere on the page and select **Save As** to download the file.

Alternatively, you can clone the repository and access the file locally:

```bash
 git clone <repository-url>
 cd <repository-name>
```

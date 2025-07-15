#!/bin/bash

# Puck Server Installation Script
# This script automates the installation of a Puck game server

set -e  # Exit on any error

echo "=== Puck Server Installation Script ==="
echo "Starting installation process..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

echo
echo "Step 1: Creating installation directories..."
mkdir -p /srv/puckserver
echo "✓ Directory created"

echo
echo "Step 2: Updating system and installing dependencies..."
apt update && apt upgrade -y
apt install -y software-properties-common

echo
echo "Step 3: Creating swapfile..."
echo "Creating 500MB swapfile for better system performance..."
fallocate -l 500M /swapfile
dd if=/dev/zero of=/swapfile bs=1M count=500
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
echo "✓ Swapfile created and activated"

echo
echo "Step 4: Adding non-free repository..."
apt-add-repository -y non-free
dpkg --add-architecture i386

echo
echo "Step 5: Installing SteamCMD..."
apt update
# Pre-accept the Steam license to avoid interactive prompts
echo steam steam/question select "I AGREE" | debconf-set-selections
echo steam steam/license note '' | debconf-set-selections
apt install -y steamcmd
echo "✓ SteamCMD installed"

echo
echo "Step 6: Installing Puck server via SteamCMD..."
echo "This may take a few minutes depending on your internet connection..."
/usr/games/steamcmd +force_install_dir /srv/puckserver +login anonymous +app_update 3481440 +quit

# Check if installation was successful
if [ $? -eq 0 ]; then
    echo "✓ Puck server installed successfully"
else
    echo "✗ Puck server installation failed"
    exit 1
fi

echo
echo "Step 7: Creating service user and setting permissions..."
useradd -r puck 2>/dev/null || echo "User 'puck' already exists"
chown -R puck:puck /srv/puckserver
echo "✓ User created and permissions set"

echo
echo "Step 8: Creating systemd service..."
cat > /etc/systemd/system/puck@.service << 'EOF'
[Unit]
Description=Puck Server

[Service]
WorkingDirectory=/srv/puckserver
User=puck
ExecStart=/srv/puckserver/start_server.sh --serverConfigurationPath %i.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo "✓ Systemd service created and reloaded"

# Function to ask yes/no questions
ask_yes_no() {
    while true; do
        read -p "$1 (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

echo
echo "Step 9: Optional - Install btop (recommended system monitoring tool)..."
if ask_yes_no "Would you like to install btop?"; then
    apt install -y btop
    echo "✓ btop installed"
else
    echo "✓ btop installation skipped"
fi

echo
echo "Step 10: Collecting server configuration..."
echo "Please provide the following information for your servers:"
echo

read -p "Enter name for Server 1: " server1_name
read -p "Enter name for Server 2: " server2_name
read -p "Enter your steamID64 (check at https://steamid.io): " steam_id
read -p "Enter server password (optional, leave empty to skip): " password

# Set password field - empty quotes if no password provided
if [ -z "$password" ]; then
    password_field='""'
else
    password_field="\"$password\""
fi

echo
echo "Step 11: Creating server configuration files..."

# Create server1.json
cat > /srv/puckserver/server1.json << EOF
{
  "port": 7777,
  "pingPort": 7778,
  "name": "$server1_name",
  "maxPlayers": 20,
  "password": $password_field,
  "voip": false,
  "isPublic": true,
  "adminSteamIds": ["$steam_id"],
  "reloadBannedSteamIds": true,
  "usePuckBannedSteamIds": true,
  "printMetrics": true,
  "kickTimeout": 1800,
  "sleepTimeout": 900,
  "joinMidMatchDelay": 10,
  "targetFrameRate": 380,
  "serverTickRate": 360,
  "clientTickRate": 360,
  "startPaused": false,
  "allowVoting": true,
  "phaseDurationMap": {
    "Warmup": 600,
    "FaceOff": 3,
    "Playing": 300,
    "BlueScore": 5,
    "RedScore": 5,
    "Replay": 10,
    "PeriodOver": 15,
    "GameOver": 15
  },
  "mods": [
  {
    "id": 3497097214,
    "enabled": true,
    "clientRequired": false
  },
  {
    "id": 3497344177,
    "enabled": true,
    "clientRequired": false
  },
  {
    "id": 3503065207,
    "enabled": true,
    "clientRequired": true
  }
]
}
EOF

# Create server2.json (different port numbers)
cat > /srv/puckserver/server2.json << EOF
{
  "port": 7779,
  "pingPort": 7780,
  "name": "$server2_name",
  "maxPlayers": 20,
  "password": $password_field,
  "voip": false,
  "isPublic": true,
  "adminSteamIds": ["$steam_id"],
  "reloadBannedSteamIds": true,
  "usePuckBannedSteamIds": true,
  "printMetrics": true,
  "kickTimeout": 1800,
  "sleepTimeout": 900,
  "joinMidMatchDelay": 10,
  "targetFrameRate": 380,
  "serverTickRate": 360,
  "clientTickRate": 360,
  "startPaused": false,
  "allowVoting": true,
  "phaseDurationMap": {
    "Warmup": 600,
    "FaceOff": 3,
    "Playing": 300,
    "BlueScore": 5,
    "RedScore": 5,
    "Replay": 10,
    "PeriodOver": 15,
    "GameOver": 15
  },
  "mods": [
  {
    "id": 3497097214,
    "enabled": true,
    "clientRequired": false
  },
  {
    "id": 3497344177,
    "enabled": true,
    "clientRequired": false
  },
  {
    "id": 3503065207,
    "enabled": true,
    "clientRequired": true
  }
]
}
EOF

# Set proper ownership for config files
chown puck:puck /srv/puckserver/server1.json
chown puck:puck /srv/puckserver/server2.json

echo "✓ Server configuration files created"

echo
echo "=== Installation Complete! ==="
echo
echo "Server configurations created:"
echo "- Server 1: $server1_name (ports 7777/7778)"
echo "- Server 2: $server2_name (ports 7779/7780)"
echo "- Admin Steam ID: $steam_id"
if [ -z "$password" ]; then
    echo "- Password: None (public servers)"
else
    echo "- Password: Set"
fi
echo
echo "To start your servers:"
echo "systemctl start puck@server1    # Start server 1"
echo "systemctl start puck@server2    # Start server 2"
echo
echo "To check status:"
echo "systemctl status puck@server1   # Check server 1"
echo "systemctl status puck@server2   # Check server 2"
echo
echo "Optional: You may want to reboot the system to apply all updates."
echo "Use: systemctl reboot and start the servers again."
echo
echo "See you on the ice!"

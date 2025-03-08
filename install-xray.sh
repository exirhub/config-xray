#!/bin/bash

# Update and install required packages
apt update && apt upgrade -y
apt install -y curl unzip jq

# Download and install XRay
mkdir -p /etc/xray
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# Define UUID and Port
UUID="b1ecf833-9387-4fa4-ace1-6644facbbb6a"
PORT="8443"

# Set XRay config file path
CONFIG_PATH="/usr/local/etc/xray/config.json"

# Create XRay server config with TCP transmission on port 8443 (No TLS)
cat > $CONFIG_PATH <<EOF
{
  "inbounds": [
    {
      "port": $PORT,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "none"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

# Set proper file permissions
chmod 600 $CONFIG_PATH

# Enable and start XRay service
systemctl enable xray
systemctl start xray

# Display success message
echo "✅ XRay installed successfully with TCP transmission on port $PORT."
echo "🔑 UUID: $UUID"

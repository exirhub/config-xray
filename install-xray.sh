#!/bin/bash

# Update and install required packages
apt update && apt upgrade -y
apt install -y curl unzip jq

# Download and install XRay
mkdir -p /etc/xray
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# Generate UUID for XRay client
UUID=$(cat /proc/sys/kernel/random/uuid)

# Fetch base domain from API (Replace with your actual API URL)
API_URL="http://api.exirvpn.com:1643/api/rest/githubdomains"
API_RESPONSE=$(curl -s "$API_URL")

# Extract values from API response
BASE_DOMAIN=$(echo "$API_RESPONSE" | jq -r '.domain')

# Check if base domain was received
if [[ -z "$BASE_DOMAIN" || "$BASE_DOMAIN" == "null" ]]; then
    echo "❌ Error: Could not retrieve base domain from API."
    exit 1
fi

# Get server's public IP
SERVER_IP=$(curl -s4 ifconfig.me)

# Convert IP to subdomain (replace dots with dashes)
SUBDOMAIN="${SERVER_IP//./-}.$BASE_DOMAIN"

# Set paths for certificates
CERT_PATH="/etc/xray/cert.pem"
KEY_PATH="/etc/xray/key.pem"

# GitHub Repo URL (Replace with your repo)
GITHUB_REPO="https://raw.githubusercontent.com/exirhub/config-xray/main"

# Download certs from GitHub if not found locally
if [[ ! -f "$CERT_PATH" || ! -f "$KEY_PATH" ]]; then
    echo "⚡ Downloading SSL certificates from GitHub..."
    
    curl -o "$CERT_PATH" "$GITHUB_REPO/cert.pem"
    curl -o "$KEY_PATH" "$GITHUB_REPO/key.pem"
    
    # Verify if the files were downloaded successfully
    if [[ ! -f "$CERT_PATH" || ! -f "$KEY_PATH" ]]; then
        echo "❌ Error: Failed to download SSL certificate files from GitHub."
        exit 1
    fi
fi

# Set correct permissions
chmod 600 "$CERT_PATH" "$KEY_PATH"

# Create XRay server config
cat > /etc/xray/config.json <<EOF
{
  "inbounds": [
    {
      "port": 443,
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
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "$CERT_PATH",
              "keyFile": "$KEY_PATH"
            }
          ]
        },
        "wsSettings": {
          "path": "/ws",
          "headers": {
            "Host": "$SUBDOMAIN"
          }
        }
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

# Enable and restart XRay service
systemctl enable xray
systemctl restart xray

# Display connection details
echo "✅ XRay VLESS + WS + TLS Installed!"
echo "🔑 UUID: $UUID"
echo "🌐 Base Domain: $BASE_DOMAIN"
echo "🌐 Subdomain: $SUBDOMAIN"
echo "🔗 WebSocket Path: /ws"
echo "⚡ Cloudflare Origin SSL has been downloaded from GitHub!"

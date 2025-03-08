#!/bin/bash

# Update and install required packages
apt update && apt upgrade -y
apt install -y curl unzip jq

# Download and install XRay
mkdir -p /etc/xray
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --version latest

# Generate UUID for XRay client
UUID=$(cat /proc/sys/kernel/random/uuid)

# Fetch domain from API (Replace with your actual API URL)
API_URL="https://api.exirvpn.com/api/rest/githubdomains"
API_RESPONSE=$(curl -s "$API_URL")

# Extract values from API response
DOMAIN=$(echo "$API_RESPONSE" | jq -r '.domain')

# Check if domain was received
if [[ -z "$DOMAIN" || "$DOMAIN" == "null" ]]; then
    echo "❌ Error: Could not retrieve domain from API."
    exit 1
fi

# Set paths for certificates
CERT_PATH="/etc/xray/cert.pem"
KEY_PATH="/etc/xray/key.pem"

# Ask the user to paste Cloudflare Origin Certificate manually
echo "⚡ Please paste your Cloudflare Origin Certificate (Press Enter to finish):"
cat > "$CERT_PATH"

echo "⚡ Please paste your Cloudflare Origin Private Key (Press Enter to finish):"
cat > "$KEY_PATH"

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
            "Host": "$DOMAIN"
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
echo "🌐 Domain: $DOMAIN"
echo "🔗 WebSocket Path: /ws"
echo "⚡ Cloudflare Origin SSL has been set up manually!"

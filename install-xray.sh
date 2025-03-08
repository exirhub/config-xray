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
API_URL="https://api.exirvpn.com/get-domain"
DOMAIN=$(curl -s "$API_URL" | jq -r '.domain')

# Check if the domain was received
if [[ -z "$DOMAIN" || "$DOMAIN" == "null" ]]; then
    echo "❌ Error: Could not retrieve domain from API."
    exit 1
fi

# Install acme.sh for SSL certificates
curl https://get.acme.sh | sh -s email=your@email.com
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

# Issue SSL certificate
~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone
~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
    --key-file /etc/xray/key.pem \
    --fullchain-file /etc/xray/cert.pem

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
              "certificateFile": "/etc/xray/cert.pem",
              "keyFile": "/etc/xray/key.pem"
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

# Enable and start XRay service
systemctl enable xray
systemctl restart xray

# Display connection details
echo "✅ XRay VLESS + WS + TLS Installed!"
echo "🔑 UUID: $UUID"
echo "🌐 Domain: $DOMAIN"
echo "🔗 WebSocket Path: /ws"

cat << 'EOF' > lockdown.sh
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

echo "=================================================="
echo "          DEBIAN 13 SLAM THE DOOR SHUT            "
echo "=================================================="
echo ""

# 1. Prompt for Public SSH Key
echo "👉 Step 1: Paste your public SSH key (e.g., ssh-ed25519 AAA...):"
read -r PUBLIC_KEY
if [[ -z "$PUBLIC_KEY" ]]; then
    echo "❌ Error: Public key cannot be empty. Exiting."
    exit 1
fi

# 2. Prompt for Tailscale Auth Key
echo ""
echo "👉 Step 2: Paste your Tailscale Auth Key (tskey-auth-...):"
read -r TS_KEY
if [[ -z "$TS_KEY" ]]; then
    echo "❌ Error: Tailscale key cannot be empty. Exiting."
    exit 1
fi

echo ""
echo "⏳ Running system updates and installing dependencies..."
apt-get update && apt-get upgrade -y > /dev/null
apt-get install -y curl ufw > /dev/null

# 3. Inject the Public SSH Key
mkdir -p /root/.ssh
echo "$PUBLIC_KEY" > /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

# 4. Hardening SSH for Debian 13
mkdir -p /etc/ssh/sshd_config.d/
cat << 'OUTER' > /etc/ssh/sshd_config.d/99-hardened.conf
PasswordAuthentication no
PermitRootLogin prohibit-password
OUTER
systemctl restart ssh

# 5. Install and Authenticate Tailscale
echo "⏳ Connecting to your Tailnet..."
curl -fsSL https://tailscale.com/install.sh | sh > /dev/null
tailscale up --authkey="$TS_KEY" --accept-dns=false

# 6. Configure Firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow in on lo
ufw allow in on tailscale0
ufw allow 443/tcp
ufw allow 22/tcp 

# 7. Enable Firewall
echo "y" | ufw enable

echo ""
echo "=================================================="
echo " SUCCESS: System hardened! Tailscale is live.     "
echo "=================================================="
EOF

# Execute the script safely
bash lockdown.sh

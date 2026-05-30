cat << 'EOF' > safe_lockdown.sh
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

echo "=================================================="
echo "          DEBIAN 13 LOCKDOWN INITIALIZED          "
echo "=================================================="
echo ""

# 1. Prompt for Public SSH Key 
echo "👉 Step 1: Paste your public SSH key (starts with ssh-ed25519 or ssh-rsa):"
read -r PUBLIC_KEY < /dev/tty

if [[ -z "$PUBLIC_KEY" || ! "$PUBLIC_KEY" =~ ^ssh- ]]; then
    echo "❌ Error: Invalid or empty SSH key. Exiting to prevent lockout."
    exit 1
fi

# 2. Prompt for Tailscale Key
echo ""
echo "👉 Step 2: Paste your Tailscale key OR the entire 'Generate Install Script' line:"
read -r INPUT_KEY < /dev/tty

# Smart filter: Strip away the curl command if they pasted the whole line
TS_KEY="${INPUT_KEY##*--auth-key=}"
# Strip away any accidental trailing spaces
TS_KEY="${TS_KEY%% *}"

if [[ -z "$TS_KEY" || ! "$TS_KEY" =~ ^tskey- ]]; then
    echo "❌ Error: Could not find a valid Tailscale key (should start with tskey-). Exiting."
    exit 1
fi

echo ""
echo "⏳ Key accepted! Processing system updates and installations..."
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

# 6. Setup Hybrid Firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow in on lo
ufw allow in on tailscale0
ufw allow 443/tcp
ufw allow 22/tcp  # Kept open temporarily for verification

# 7. Enable Firewall
echo "y" | ufw enable

echo ""
echo "=================================================="
echo " SUCCESS: System hardened! Tailscale is live.     "
echo "=================================================="
EOF

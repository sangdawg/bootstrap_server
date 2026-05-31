#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# Define your custom SSH port (20K range)
SSH_PORT=22022

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

echo ""
echo "⏳ Key accepted! Processing system updates and installations..."
apt-get update && apt-get upgrade -y > /dev/null
apt-get install -y curl ufw > /dev/null

# 2. Inject the Public SSH Key
mkdir -p /root/.ssh
echo "$PUBLIC_KEY" > /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

# 3. Hardening SSH & Changing Port
mkdir -p /etc/ssh/sshd_config.d/
cat << OUTER > /etc/ssh/sshd_config.d/99-hardened.conf
Port $SSH_PORT
PasswordAuthentication no
PermitRootLogin prohibit-password
OUTER

# Restart SSH to apply changes
systemctl restart ssh

# 4. Setup UFW Firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow in on lo
ufw allow $SSH_PORT/tcp comment 'Custom SSH Port'

# Enable Firewall
echo "y" | ufw enable

# 5. Fetch Public IP for the connection string
SERVER_IP=$(curl -s https://ifconfig.me || curl -s https://api.ipify.org)

echo ""
echo "=================================================="
echo " SUCCESS: System hardened and SSH port moved!     "
echo "=================================================="
echo ""
echo "🔒 Password login is DISABLED."
echo "🔒 Root login is ONLY allowed via your SSH key."
echo ""
echo "👉 Use this command to connect to your server:"
echo "   ssh -p $SSH_PORT root@${SERVER_IP:-<SERVER_IP>}"
echo "=================================================="

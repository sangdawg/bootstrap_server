#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# Define your custom SSH port (20K range)
SSH_PORT=22047

echo "=================================================="
echo "      LOCK DOWN HOST NO ROOT SSH                  "
echo "=================================================="
echo ""

# 1. Prompt for Public SSH Key 
echo "👉 Step 1: Paste your public SSH key (starts with ssh-ed25519 or ssh-rsa):"
read -r PUBLIC_KEY < /dev/tty

if [[ -z "$PUBLIC_KEY" || ! "$PUBLIC_KEY" =~ ^ssh- ]]; then
    echo "❌ Error: Invalid or empty SSH key. Exiting."
    exit 1
fi

# 2. Prompt for New Username
echo ""
echo "👉 Step 2: Enter the new admin username:"
read -r NEW_USER < /dev/tty

if [[ ! "$NEW_USER" =~ ^[a-z][-a-z0-9_]*$ ]]; then
    echo "❌ Error: Invalid username format."
    exit 1
fi

echo ""
echo "⏳ Processing base system updates and dependencies..."
apt-get update && apt-get upgrade -y > /dev/null
apt-get install -y curl ufw sudo > /dev/null

# 3. Setup Root SSH Key
mkdir -p /root/.ssh
echo "$PUBLIC_KEY" > /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

# 4. Create New User & Mirror SSH Key
if id "$NEW_USER" &>/dev/null; then
    echo "⚠️ User $NEW_USER already exists."
else
    useradd -m -s /bin/bash "$NEW_USER"
fi

# Inject key into user's home
USER_HOME=$(eval echo "~$NEW_USER")
mkdir -p "$USER_HOME/.ssh"
echo "$PUBLIC_KEY" > "$USER_HOME/.ssh/authorized_keys"
chown -R "$NEW_USER:$NEW_USER" "$USER_HOME/.ssh"
chmod 700 "$USER_HOME/.ssh"
chmod 600 "$USER_HOME/.ssh/authorized_keys"

# 5. Add User to Sudo Group (Enforces Password Requirement)
usermod -aG sudo "$NEW_USER"

# 6. FORCE User Password Creation right now
echo ""
echo "👉 Step 3: Set an internal sudo password for '$NEW_USER':"
passwd "$NEW_USER"

# 7. Hardening SSH Configuration
mkdir -p /etc/ssh/sshd_config.d/
cat << OUTER > /etc/ssh/sshd_config.d/99-hardened.conf
Port $SSH_PORT
PasswordAuthentication no
PermitRootLogin prohibit-password
OUTER

systemctl restart ssh

# 8. Setup UFW Firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow in on lo
ufw allow $SSH_PORT/tcp comment 'Custom SSH Port'
echo "y" | ufw enable

# 9. Smart Network Detection (Grabs both IPv4 and IPv6)
IPV4_ADDR=$(curl -4 -s https://ifconfig.me || curl -4 -s https://api.ipify.org)
IPV6_ADDR=$(curl -6 -s https://ifconfig.me || curl -6 -s https://api.ipify.org)

echo ""
echo "=================================================="
echo " SUCCESS: System is fully locked down and ready! "
echo "=================================================="
echo ""
echo "🔒 SSH Network Access: Key-Only (No passwords allowed)"
echo "🔒 Local Escalation: 'sudo' commands require the password you just set."
echo ""
echo "👉 Connect via IPv4 (Recommended if local network is v4-only):"
if [ -not -z "$IPV4_ADDR" ]; then
    echo "   ssh -p $SSH_PORT ${NEW_USER}@${IPV4_ADDR}"
else
    echo "   (No public IPv4 detected or curl timed out)"
fi
echo ""
echo "👉 Connect via IPv6:"
if [ -not -z "$IPV6_ADDR" ]; then
    echo "   ssh -p $SSH_PORT ${NEW_USER}@[${IPV6_ADDR}]"
else
    echo "   (No public IPv6 detected)"
fi
echo "=================================================="

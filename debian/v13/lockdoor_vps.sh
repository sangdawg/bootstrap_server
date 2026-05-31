#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# Define your custom SSH port (20K range)
SSH_PORT=22047

echo "=================================================="
echo "          DEBIAN LOCK DOWN NO ROOT                "
echo "=================================================="
echo ""

# 1. Prompt for Public SSH Key 
echo "👉 Step 1: Paste your public SSH key (starts with ssh-ed25519 or ssh-rsa):"
read -r PUBLIC_KEY < /dev/tty

if [[ -z "$PUBLIC_KEY" || ! "$PUBLIC_KEY" =~ ^ssh- ]]; then
    echo "❌ Error: Invalid or empty SSH key. Exiting to prevent lockout."
    exit 1
fi

# 2. Prompt for New Username
echo ""
echo "👉 Step 2: Enter the new username to create:"
read -r NEW_USER < /dev/tty

# Validate username format (lowercase, alphanumeric, starts with a letter)
if [[ ! "$NEW_USER" =~ ^[a-z][-a-z0-9_]*$ ]]; then
    echo "❌ Error: Invalid username. Use lowercase letters, numbers, hyphens, or underscores."
    exit 1
fi

echo ""
echo "⏳ Base requirements met. Processing system updates and tools..."
apt-get update && apt-get upgrade -y > /dev/null
apt-get install -y curl ufw sudo > /dev/null

# 3. Setup Root SSH Key
mkdir -p /root/.ssh
echo "$PUBLIC_KEY" > /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

# 4. Create New User & Mirror SSH Key
if id "$NEW_USER" &>/dev/null; then
    echo "⚠️ User $NEW_USER already exists. Skipping user creation, updating keys..."
else
    # Create user with a disabled password (key-only access)
    useradd -m -s /bin/bash "$NEW_USER"
fi

# Inject key into the new user's home directory
USER_HOME=$(eval echo "~$NEW_USER")
mkdir -p "$USER_HOME/.ssh"
echo "$PUBLIC_KEY" > "$USER_HOME/.ssh/authorized_keys"

# Critically important: Fix ownership and permissions for the new user
chown -R "$NEW_USER:$NEW_USER" "$USER_HOME/.ssh"
chmod 700 "$USER_HOME/.ssh"
chmod 600 "$USER_HOME/.ssh/authorized_keys"

# 5. Grant Passwordless Sudo Privileges
echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$NEW_USER"
chmod 440 "/etc/sudoers.d/$NEW_USER"

# 6. Hardening SSH & Changing Port
mkdir -p /etc/ssh/sshd_config.d/
cat << OUTER > /etc/ssh/sshd_config.d/99-hardened.conf
Port $SSH_PORT
PasswordAuthentication no
PermitRootLogin prohibit-password
OUTER

# Restart SSH to apply changes
systemctl restart ssh

# 7. Setup UFW Firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow in on lo
ufw allow $SSH_PORT/tcp comment 'Custom SSH Port'

# Enable Firewall
echo "y" | ufw enable

# 8. Fetch Public IP for the connection string
SERVER_IP=$(curl -s https://ifconfig.me || curl -s https://api.ipify.org)

echo ""
echo "=================================================="
echo " SUCCESS: System hardened & Admin User Provisioned!"
echo "=================================================="
echo ""
echo "🔒 Password login is DISABLED for all accounts."
echo "🔒 Sudo rights granted to '$NEW_USER' without password."
echo ""
echo "👉 Connect as Root:"
echo "   ssh -p $SSH_PORT root@${SERVER_IP:-<SERVER_IP>}"
echo ""
echo "👉 Connect as $NEW_USER:"
echo "   ssh -p $SSH_PORT ${NEW_USER}@${SERVER_IP:-<SERVER_IP>}"
echo "=================================================="

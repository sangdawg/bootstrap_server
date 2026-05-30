#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# 1. Update system and ensure basic tools are present
apt-get update && apt-get upgrade -y
apt-get install -y curl ufw

# 2. Inject your Public SSH Key
mkdir -p /root/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDYOURACTUALPUBLICKEYHERE..." > /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

# 3. Modern Debian 13 SSH Hardening (Drop-in file method)
mkdir -p /etc/ssh/sshd_config.d/
cat << 'EOF' > /etc/ssh/sshd_config.d/99-hardened.conf
PasswordAuthentication no
PermitRootLogin prohibit-password
EOF
systemctl restart ssh

# 4. Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# 5. Authenticate Tailscale
tailscale up --authkey=tskey-auth-kXXXXX-XXXXXXXXXXXXX --accept-dns=false

# 6. Establish the Hybrid Firewall (UFW)
ufw default deny incoming
ufw default allow outgoing
ufw allow in on lo             # Allow internal loopback
ufw allow in on tailscale0     # Allow ALL traffic over your secure Tailnet
ufw allow 443/tcp              # Open Port 443 to the public for VLESS Reality

# 7. Arm the firewall
echo "y" | ufw enable


sudo mkdir -p /etc/apt/keyrings &&
   sudo curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc &&
   sudo chmod a+r /etc/apt/keyrings/sagernet.asc &&
   echo '
Types: deb
URIs: https://deb.sagernet.org/
Suites: *
Components: *
Enabled: yes
Signed-By: /etc/apt/keyrings/sagernet.asc
' | sudo tee /etc/apt/sources.list.d/sagernet.sources &&
   sudo apt-get update &&
   sudo apt-get install sing-box # or sing-box-beta

# Force the system to load sing-box on boot
sudo systemctl enable sing-box

# Fire up the service
sudo systemctl start sing-box

# Check the service status
sudo systemctl status sing-box --no-pager

# Check port 443 binding. Should see port 443 bound to the singboox process. 
sudo ss -tlnp | grep sing-box

# UFW hole punching for mesh VPN and singbox

sudo ufw allow 443/tcp comment 'Singbox inbound'

# Tailscale connection port
sudo ufw allow 41641/udp comment 'Tailscale Direct P2P Coordination'

# Grant trust to the internal Tailscale virtual network card
sudo ufw allow in on tailscale0 comment 'Trust all internal Tailscale mesh traffic'

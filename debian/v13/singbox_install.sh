
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

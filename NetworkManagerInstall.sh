sudo apt install network-manager -y
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

# remove ifupdown completely
sudo apt purge ifupdown
sudo apt autoremove

# allow networkmanager to completely take over the role of ifupdown package
sudo sed -i 's/^managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf

# restart it
sudo systemctl restart NetworkManager

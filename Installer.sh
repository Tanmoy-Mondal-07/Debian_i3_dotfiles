#!/bin/bash
set -e

sudo apt update

echo "[1/4] Installing i3 lightdm rofi glow polybar alacritty fastfetch"
sudo apt install i3 lightdm rofi glow polybar alacritty fastfetch -y

echo "[2/4] Installing JetBrains fonts"
echo "[1/8] Removing conflicting JetBrains fonts (apt)"
sudo apt purge -y fonts-jetbrains-mono || true

echo "[2/8] Removing user and system font caches"
rm -rf ~/.cache/fontconfig
sudo rm -rf /var/cache/fontconfig/*

echo "[3/8] Removing old Nerd Font installs"
rm -rf ~/.local/share/fonts/JetBrains*
sudo rm -rf /usr/share/fonts/JetBrains*

echo "[4/8] Installing dependencies"
sudo apt install -y curl unzip fontconfig

echo "[5/8] Installing JetBrains Mono Nerd Font (user-local)"
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
curl -fLo JetBrainsMono.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip -o JetBrainsMono.zip
rm JetBrainsMono.zip

echo "[6/8] Forcing fontconfig rebuild"
fc-cache -r
fc-cache -fv

echo "[7/8] Forcing Nerd Font as default monospace"
mkdir -p ~/.config/fontconfig
cat > ~/.config/fontconfig/fonts.conf << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <alias>
    <family>monospace</family>
    <prefer>
      <family>JetBrainsMono Nerd Font</family>
    </prefer>
  </alias>
</fontconfig>
EOF

echo "[8/8] Final verification"
fc-match monospace
fc-list | grep -i "JetBrainsMono Nerd" || true

echo "[3/4] Installing NetworkManager"
sudo apt install network-manager -y

echo "[1/4] enable and start NetworkManager"
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

echo "[2/4] remove ifupdown completely"
sudo apt purge ifupdown
sudo apt autoremove

echo "[3/4] allow networkmanager to completely take over the role of ifupdown package"
sudo sed -i 's/^managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf

echo "[3/4] restart NetworkManager"
sudo systemctl restart NetworkManager

echo "[4/4] setting up config files"
cp -r ./config/. ~/
chmod +x ~/.config/scripts/gemini.sh
chmod +x ~/.config/rofi/rofiPowerMenu.sh
chmod +x ~/.config/rofi/network_manager.sh

echo "Reboot the Os"
sudo reboot
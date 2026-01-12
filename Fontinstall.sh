#!/bin/bash
set -e

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

echo "DONE. Log out and log back in."

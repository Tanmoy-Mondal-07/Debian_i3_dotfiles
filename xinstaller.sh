#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

sudo apt update
sudo apt install -y --no-install-recommends \
  i3 lightdm rofi glow polybar alacritty fastfetch \
  network-manager curl unzip fontconfig fzf fdfind neovim

# Fonts
sudo apt purge -y fonts-jetbrains-mono || true
rm -rf ~/.cache/fontconfig ~/.local/share/fonts/JetBrains*
sudo rm -rf /var/cache/fontconfig/* /usr/share/fonts/JetBrains*

mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts || exit 1
curl -fLo JetBrainsMono.zip \
  https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip -o JetBrainsMono.zip
rm JetBrainsMono.zip
fc-cache -fv

# NetworkManager
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager
sudo apt purge -y ifupdown
sudo mkdir -p /etc/NetworkManager/conf.d
echo -e "[ifupdown]\nmanaged=true" | sudo tee /etc/NetworkManager/conf.d/10-ifupdown.conf
sudo systemctl restart NetworkManager

# Configs
cp -r "$SCRIPT_DIR/config/." ~/
chmod +x ~/.config/scripts/*.sh ~/.config/rofi/*.sh

read -rp "Reboot now? [y/N]: " ans
[[ "$ans" =~ ^[Yy]$ ]] && sudo reboot

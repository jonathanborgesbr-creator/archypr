#!/bin/bash

# Este script instala um ambiente de desktop Hyprland completo no Arch Linux
# com as configurações e ferramentas essenciais.

# Certifique-se de que a sincronização do banco de dados está atualizada antes de prosseguir
sudo pacman -Syy --noconfirm

# Pacotes do Hyprland e Essenciais Wayland
HYPRLAND_PKGS="
    hyprland hyprlock hypridle hyprcursor hyprpaper hyprpicker waybar kitty
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    qt5-wayland qt6-wayland polkit-kde-agent
"

# Utilidades, Arquivos e Ferramentas Gráficas
UTILS_PKGS="
    dolphin dolphin-plugins ark kio-admin dunst cliphist xdg-user-dirs
    kde-cli-tools kate gparted nano pavucontrol-gtk
"

# Áudio, Mídia e Multimídia
MEDIA_PKGS="
    mpv ffmpeg
    pipewire pipewire-pulse pipewire-jack pipewire-alsa wireplumber
    gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly
"

# Jogos, Rede e Conectividade
SYSTEM_PKGS="
    gamescope gamemode
    networkmanager network-manager-applet
    bluez bluez-utils blueman
"

# Temas e Fontes
THEME_FONTS_PKGS="
    breeze breeze5 breeze-gtk papirus-icon-theme
    ttf-font-awesome ttf-jetbrains-mono-nerd ttf-opensans ttf-dejavu noto-fonts ttf-roboto
"

# Combina todas as listas em uma única instalação
ALL_PKGS="$HYPRLAND_PKGS $UTILS_PKGS $MEDIA_PKGS $SYSTEM_PKGS $THEME_FONTS_PKGS"

# Executa a instalação de todos os pacotes com confirmação automática
echo "Iniciando a instalação de todos os pacotes..."
sudo pacman -S --noconfirm $ALL_PKGS

echo "Instalação concluída. Verifique se há erros acima."

# Fim do script

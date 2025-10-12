#!/bin/bash

# Define o usuário que invocou o sudo (CRÍTICO para as permissões dos dotfiles)
if [ -z "$SUDO_USER" ]; then
    echo "Erro: Este script deve ser executado com sudo (ex: sudo ./instalador.sh)."
    exit 1
fi
USUARIO="$SUDO_USER"

# Define a localização do repositório clonado (onde o script está sendo executado)
# Esta variável é usada para encontrar a sua pasta .config e outros dotfiles (AGORA IGNORADA)
DOTFILES_DIR=$(pwd)

# ===============================================
# 1. ATUALIZAÇÃO E YAY (Base do Sistema)
# ===============================================

echo "--> 1/5: Atualizando o sistema e instalando YAY..."

# Atualiza e instala ferramentas base
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm git base-devel

# Instalação do YAY como usuário normal
su - "$USUARIO" << EOF
    echo "Clonando e instalando o yay..."
    cd /tmp/
    rm -rf yay
    git clone https://aur.archlinux.org/yay
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
EOF

if ! su - "$USUARIO" -c "command -v yay > /dev/null"; then
    echo "ERRO CRÍTICO: O yay não foi instalado corretamente."
    exit 1
fi

# ===============================================
# 2. INSTALAÇÃO PRINCIPAL (Core Hyprland, Apps, Audio, Rede)
# ===============================================

echo "--> 2/5: Instalando Hyprland, utilitários, áudio e rede..."

# Instalando TODOS os pacotes necessários do repositório oficial (PACMAN)
sudo pacman -S --noconfirm \
    hyprland hyprlock hypridle hyprcursor hyprpaper hyprpicker waybar kitty \
    rofi-wayland dolphin dolphin-plugins ark kio-admin polkit-kde-agent qt5-wayland qt6-wayland \
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk dunst cliphist mpv xdg-user-dirs \
    ttf-font-awesome ttf-jetbrains-mono-nerd ttf-opensans ttf-dejavu noto-fonts ttf-roboto \
    breeze breeze5 breeze-gtk papirus-icon-theme kde-cli-tools kate gparted gamescope gamemode \
    pipewire pipewire-pulse pipewire-jack pipewire-alsa wireplumber \
    gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly \
    ffmpeg nano pavucontrol-gtk bluez bluez-utils blueman \
    networkmanager network-manager-applet \
    archlinux-xdg-menu

# Habilitando Serviços Essenciais (SYSTEMCTL)
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth.service
su - "$USUARIO" -c "systemctl --user --now enable pipewire.socket pipewire-pulse.service wireplumber.service" 

# ===============================================
# 3. NVIDIA E CONFIGURAÇÕES DE SISTEMA
# ===============================================

echo "--> 3/5: Instalando drivers NVIDIA e configurando DRM..."

# Instalação NVIDIA
sudo pacman -S --noconfirm nvidia nvidia-settings nvidia-utils linux-headers lib32-nvidia-utils

# Habilita Kernel Mode Setting (modeset=1) para Wayland/Hyprland
echo -e "options nvidia-drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf
sudo mkinitcpio -P # Reconstrói o initramfs

# Configurações KDE/Dolphin e XDG
su - "$USUARIO" -c "xdg-user-dirs-update --force"
su - "$USUARIO" -c "XDG_MENU_PREFIX=arch- kbuildsycoca6"

# ===============================================
# 4. APLICATIVOS VIA AUR (yay)
# ===============================================

echo "--> 4/5: Instalando aplicativos via AUR (Yay)..."

# Instala pacotes do AUR como usuário normal
su - "$USUARIO" << EOF
    yay -S --noconfirm hyprshot wlogout qview visual-studio-code-bin firefox-bin nwg-look qt5ct-kde qt6ct-kde heroic-games-launcher
EOF

# ===============================================
# 5. FINALIZAÇÕES, PERMISSÕES E CONFIGURAÇÕES DE SISTEMA
# (PARTE DE CÓPIA DE DOTFILES REMOVIDA)
# ===============================================

echo "--> 5/5: Configurando permissões de GPU e layout de teclado..."

# Permissão para Gamescope
sudo setcap 'CAP_SYS_NICE=eip' $(which gamescope)

# Adiciona o usuário ao grupo 'render'
sudo gpasswd -a $USUARIO render

# Configura o layout de teclado
sudo localectl set-x11-keymap br abnt2


echo "======================================================"
echo "Instalação concluída! Você DEVE reiniciar o sistema agora."
echo "Execute: reboot"
echo "======================================================"

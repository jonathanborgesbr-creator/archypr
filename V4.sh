#!/bin/bash

# Define a variável USER para ser o usuário que invocou o sudo (muito importante para a seção yay)
if [ -z "$SUDO_USER" ]; then
    echo "Erro: Este script deve ser executado com sudo."
    exit 1
fi
USUARIO="$SUDO_USER"

# ===============================================
# 1. ATUALIZAÇÃO E FERRAMENTAS
# ===============================================

echo "--> 1/7: Atualizando o sistema e instalando ferramentas base..."
# Sincroniza e atualiza o sistema ANTES de instalar qualquer coisa.
sudo pacman -Syu --noconfirm

# Instala Git e base-devel (necessário para compilar yay)
sudo pacman -S --noconfirm git base-devel

# ===============================================
# 2. INSTALAÇÃO DO YAY (CORREÇÃO CRÍTICA)
# ===============================================

echo "--> 2/7: Instalando o YAY (AUR helper) como usuário normal ($USUARIO)..."

# Usamos 'Here Document' (EOF) com 'su' para garantir que os comandos de CD e GIT
# sejam executados corretamente no shell do usuário sem privilégios (makepkg).
su - "$USUARIO" << EOF
    echo "Clonando e instalando o yay..."
    cd /tmp/
    # Garante que a pasta não exista de uma tentativa anterior
    rm -rf yay

    git clone https://aur.archlinux.org/yay
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
    echo "YAY instalado com sucesso."
EOF

# Verifica se a instalação do yay funcionou antes de prosseguir
if ! su - "$USUARIO" -c "command -v yay > /dev/null"; then
    echo "ERRO CRÍTICO: O yay não foi instalado corretamente. Não é possível prosseguir com a seção 7."
    exit 1
fi

# ===============================================
# 3. ÁUDIO (PIPEWIRE) E SERVIÇOS DE REDE
# ===============================================

echo "--> 3/7: Instalando e habilitando PipeWire e serviços de Bluetooth/Wi-Fi..."

# Instala PipeWire e utilitários
sudo pacman -S --noconfirm pipewire pipewire-pulse pipewire-jack pipewire-alsa wireplumber \
    gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly \
    ffmpeg nano pavucontrol-gtk

# HABILITA E INICIA OS SERVIÇOS DE REDE/BLUETOOTH
# NetworkManager (Wi-Fi e Rede) e Bluetooth.service
sudo systemctl enable --now NetworkManager bluetooth

# Habilita e inicia os serviços de áudio para o usuário
su - "$USUARIO" -c "systemctl --user --now enable pipewire.socket pipewire-pulse.service wireplumber.service"

# ===============================================
# 4. AMBIENTE HYPRLAND E UTILITÁRIOS (pacman)
# ===============================================

echo "--> 4/7: Instalando Hyprland, Dolphin, Bluetooth, Wi-Fi e utilitários base..."

# Core Hyprland e utilitários de sistema (Dolphin, polkit, portais, fontes, temas)
sudo pacman -S --noconfirm hyprland hyprlock hypridle hyprcursor hyprpaper hyprpicker waybar kitty \
    rofi-wayland dolphin dolphin-plugins ark kio-admin polkit-kde-agent qt5-wayland qt6-wayland \
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk dunst cliphist mpv xdg-user-dirs \
    ttf-font-awesome ttf-jetbrains-mono-nerd ttf-opensans ttf-dejavu noto-fonts ttf-roboto \
    breeze breeze5 breeze-gtk **breeze-gtk-dark kde-gtk-config** papirus-icon-theme kde-cli-tools kate \
    networkmanager networkmanager-applet bluedevil

# Aplica configurações de diretório XDG
su - "$USUARIO" -c "xdg-user-dirs-update --force"

# ===============================================
# 5. NVIDIA (Kernel Padrão)
# ===============================================

echo "--> 5/7: Instalando drivers NVIDIA e configurando Wayland/DRM..."

sudo pacman -S --noconfirm nvidia nvidia-settings nvidia-utils linux-headers lib32-nvidia-utils

# Habilita Kernel Mode Setting (modeset=1) para Wayland/Hyprland
echo -e "options nvidia-drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf

# Reconstrói o initramfs para aplicar a nova configuração do kernel (DRM)
sudo mkinitcpio -P

# ===============================================
# 6. CONFIGURAÇÃO DE MENUS, CACHE, KDEGOBALS E TEMA DARK
# ===============================================

echo "--> 6/7: Configurando menus, cache do Dolphin, kdeglobals e tema dark..."

# Instala ferramentas necessárias e recria o cache (executado como usuário normal)
sudo pacman -S --noconfirm archlinux-xdg-menu
su - "$USUARIO" -c "XDG_MENU_PREFIX=arch- kbuildsycoca6"

# CRIAÇÃO E CONFIGURAÇÃO DO ARQUIVO KDEGLOBALS (Tema Dark)
# Configura o terminal, tema de ícones e esquema de cores para Dark.
su - "$USUARIO" -c "
cat << EOF > ~/.config/kdeglobals
[General]
TerminalApplication=kitty

[Icons]
Theme=Papirus-Dark
ColorScheme=BreezeDark

[KDE]
widgetStyle=qt6ct-style
EOF
"

# CRIAÇÃO DOS ARQUIVOS DE CONFIGURAÇÃO DE TEMA QT/GTK
# Garante que o Breeze Dark seja usado como tema padrão e define o esquema de cores.
su - "$USUARIO" -c "
cat << EOF > ~/.config/kcmshellrc
[KCM System Settings]
kdeglobalsTheme=BreezeDark
EOF

cat << EOF > ~/.config/kdegui5rc
[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
EOF

# Define o esquema de cores e o tema GTK preferencial para dark
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
gsettings set org.gnome.desktop.interface gtk-theme 'Breeze-Dark'
"

# ===============================================
# 7. APLICATIVOS VIA AUR (yay)
# ===============================================

echo "--> 7/7: Instalando aplicativos via AUR (Yay)..."

# Instala pacotes do AUR, incluindo os configuradores de estilo Qt para KDE.
su - "$USUARIO" << EOF
    yay -S --noconfirm hyprshot wlogout qview visual-studio-code-bin firefox-bin nwg-look qt5ct-kde qt6ct-kde
EOF


echo "======================================================"
echo "Instalação concluída! Você DEVE reiniciar o sistema agora."
echo "======================================================"
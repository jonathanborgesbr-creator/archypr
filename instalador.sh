#!/bin/bash

# ======================================================================
# INSTALADOR AVANÇADO: Hyprland + Dotfiles BHlmaoMSD + Drivers Inteligentes
# Suporte NVIDIA/AMD automático, AUR, Proton GE, Vulkan, DXVK
# Rodável múltiplas vezes
# ======================================================================

# --- Cores ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

SCRIPT_DIR="$(pwd)"

separator() {
    echo -e "\n${YELLOW}------------------------------------------------------${NC}"
}

# ----------------------------------------------------------------------
# 0. Verifica usuário
# ----------------------------------------------------------------------
separator
USUARIO=$(whoami)
if [ "$USUARIO" == "root" ]; then
    echo -e "${RED}Execute o script como usuário normal, não root.${NC}"
    exit 1
fi
echo -e "${GREEN}Usuário detectado: $USUARIO${NC}"
HOME_DESTINO="$HOME"

# ----------------------------------------------------------------------
# 1. Atualiza sistema e instala pacotes básicos
# ----------------------------------------------------------------------
separator
echo -e "${GREEN}Atualizando sistema e instalando pacotes básicos...${NC}"
sudo pacman -Syu --needed --noconfirm git base-devel

# ----------------------------------------------------------------------
# 2. Instala yay se não existir
# ----------------------------------------------------------------------
separator
if ! command -v yay &>/dev/null; then
    echo -e "${GREEN}Instalando yay (AUR Helper)${NC}"
    cd /tmp || exit 1
    rm -rf yay
    git clone https://aur.archlinux.org/yay.git
    cd yay || exit 1
    makepkg -si --noconfirm
    cd .. && rm -rf yay
else
    echo -e "${GREEN}yay já instalado.${NC}"
fi

# ----------------------------------------------------------------------
# 3. Função para instalar pacotes se não estiverem presentes
# ----------------------------------------------------------------------
install_if_missing() {
    local pkg_manager="$1"; shift
    local packages=("$@")
    for pkg in "${packages[@]}"; do
        if [[ "$pkg_manager" == "pacman" ]]; then
            if ! pacman -Qi "$pkg" &>/dev/null; then
                sudo pacman -S --needed --noconfirm "$pkg"
            else
                echo -e "${GREEN}$pkg já instalado.${NC}"
            fi
        elif [[ "$pkg_manager" == "aur" ]]; then
            if ! yay -Qi "$pkg" &>/dev/null; then
                yay -S --needed --noconfirm "$pkg"
            else
                echo -e "${GREEN}$pkg (AUR) já instalado.${NC}"
            fi
        fi
    done
}

# ----------------------------------------------------------------------
# 4. Pacotes essenciais (pacman)
# ----------------------------------------------------------------------
separator
BATCH1=( hyprland hyprlock hypridle hyprcursor hyprpaper hyprpicker waybar kitty rofi-wayland dunst cliphist xdg-desktop-portal-hyprland xdg-desktop-portal-gtk nano xdg-user-dirs archlinux-xdg-menu )
install_if_missing pacman "${BATCH1[@]}"

BATCH2=( networkmanager bluez bluez-utils blueberry )
install_if_missing pacman "${BATCH2[@]}"

BATCH3=( ttf-font-awesome ttf-jetbrains-mono-nerd ttf-opensans ttf-dejavu noto-fonts ttf-roboto breeze breeze5 breeze-gtk papirus-icon-theme kde-cli-tools kate gparted gamescope gamemode )
install_if_missing pacman "${BATCH3[@]}"

BATCH4=( pipewire pipewire-pulse pipewire-jack pipewire-alsa wireplumber gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly ffmpeg mpv pavucontrol dolphin dolphin-plugins ark kio-admin polkit-kde-agent qt5-wayland qt6-wayland )
install_if_missing pacman "${BATCH4[@]}"

# ----------------------------------------------------------------------
# 5. Pacotes AUR extras
# ----------------------------------------------------------------------
separator
AUR_PACKAGES=( hyprshot wlogout qview nwg-look qt5ct-kde qt6ct-kde heroic-games-launcher proton-ge-custom wine-ge-custom dxvk-bin vkd3d-proton-bin )
install_if_missing aur "${AUR_PACKAGES[@]}"

# ----------------------------------------------------------------------
# 6. Clonagem e instalação de dotfiles BHlmaoMSD
# ----------------------------------------------------------------------
separator
DOTFILES_REPO="https://github.com/BHlmaoMSD/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles_temp"

rm -rf "$DOTFILES_DIR"
git clone "$DOTFILES_REPO" "$DOTFILES_DIR"

# Copia configs, mantendo backups
if [ -d "$DOTFILES_DIR/.config" ]; then
    echo -e "${GREEN}Atualizando ~/.config com dotfiles BHlmaoMSD${NC}"
    for dir in "$DOTFILES_DIR/.config/"*; do
        base=$(basename "$dir")
        if [ -d "$HOME/.config/$base" ]; then
            mv "$HOME/.config/$base" "$HOME/.config/${base}_backup_$(date +%F_%H%M)"
        fi
        rsync -avh --no-perms "$dir" "$HOME/.config/"
    done
fi

# Copia scripts
if [ -d "$DOTFILES_DIR/bin" ]; then
    mkdir -p "$HOME/.local/bin"
    rsync -avh --no-perms "$DOTFILES_DIR/bin/" "$HOME/.local/bin/"
    chmod -R +x "$HOME/.local/bin"
fi

chown -R "$USUARIO:$USUARIO" "$HOME/.config" "$HOME/.local/bin"
rm -rf "$DOTFILES_DIR"

# ----------------------------------------------------------------------
# 7. Habilitando serviços
# ----------------------------------------------------------------------
separator
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth.service
systemctl --user enable --now wireplumber

# ----------------------------------------------------------------------
# 8. Detecta GPU e instala drivers adequados
# ----------------------------------------------------------------------
separator
GPU_VENDOR=$(lspci | grep -E "VGA|3D" | awk '{print $5}' | head -n1 | tr '[:upper:]' '[:lower:]')

if [[ "$GPU_VENDOR" == *"nvidia"* ]]; then
    echo -e "${GREEN}GPU NVIDIA detectada. Instalando drivers e Vulkan...${NC}"
    NVIDIA_PACKAGES=( nvidia nvidia-utils nvidia-settings lib32-nvidia-utils vulkan-icd-loader lib32-vulkan-icd-loader vulkan-tools )
    install_if_missing pacman "${NVIDIA_PACKAGES[@]}"
    sudo bash -c 'echo "options nvidia_drm modeset=1" > /etc/modprobe.d/nvidia.conf'
    sudo sed -i 's/^MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf
    sudo mkinitcpio -P
elif [[ "$GPU_VENDOR" == *"amd"* ]]; then
    echo -e "${GREEN}GPU AMD detectada. Instalando drivers e Vulkan...${NC}"
    AMD_PACKAGES=( xf86-video-amdgpu mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon vulkan-tools )
    install_if_missing pacman "${AMD_PACKAGES[@]}"
else
    echo -e "${YELLOW}GPU não NVIDIA/AMD detectada ou não identificada. Pule instalação de drivers gráficos.${NC}"
fi

# ----------------------------------------------------------------------
# 9. Conclusão
# ----------------------------------------------------------------------
separator
echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}✔️ Instalação COMPLETA com suporte inteligente a GPU, Hyprland e dotfiles BHlmaoMSD${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "${YELLOW}➡️ REINICIE O SISTEMA para aplicar todos os drivers e configurações.${NC}"
echo ""
#!/bin/bash

# Define cores
GREEN='\033[0;32m'
RED='\033[0;0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Salva o diretório de trabalho original do script
SCRIPT_DIR="$(pwd)"

# Função para exibir uma linha de separação
separator() {
    echo -e "\n${YELLOW}------------------------------------------------------${NC}"
}

# --- 0. Preparação e Atualização do Sistema ---
separator
echo -e "${GREEN}--- 0. Preparando o Sistema e Atualizando (Automático) ---${NC}"
echo "Será solicitada sua senha para instalar pacotes essenciais e atualizar o sistema. A instalação será automática (--noconfirm)."
sudo pacman -S --needed --noconfirm git base-devel && sudo pacman -Syu --noconfirm
INSTALL_STATUS=$?
if [ $INSTALL_STATUS -ne 0 ]; then
    echo -e "\n${RED}--- ERRO CRÍTICO ---${NC}"
    echo -e "${RED}Não foi possível instalar pacotes básicos ou atualizar o sistema.${NC}"
    exit 1
fi
echo -e "${GREEN}Etapa anterior concluída com êxito.${NC}"

# --- 1. Determinar o usuário atual e Variáveis de Diretório ---
separator
echo -e "${GREEN}--- 1. Verificação de Usuário e Diretórios ---${NC}"
USUARIO=$(whoami)
if [ "$USUARIO" == "root" ]; then
    echo -e "${RED}ERRO: Por favor, execute este script como seu usuário normal, não como root.${NC}"
    exit 1
fi
echo -e "${GREEN}Usuário detectado: $USUARIO${NC}"

# Definição das variáveis de diretório
HOME_DESTINO="$HOME"
CONFIG_ORIGEM="$SCRIPT_DIR/.config" 

# Validação do Diretório de Configuração
if [ ! -d "$CONFIG_ORIGEM" ]; then
    echo -e "${RED}ERRO: Diretório de configuração '$CONFIG_ORIGEM' não encontrado.${NC}"
    exit 1
fi

# --- 2. Instalação do 'yay' (AUR helper) ---
separator
echo -e "${GREEN}--- 2. Instalando o 'yay' (AUR Helper) (Automático) ---${NC}"
cd /tmp/ || exit 1
rm -rf yay

if git clone https://aur.archlinux.org/yay; then
    cd yay || exit 1
    makepkg -si --noconfirm
    cd .. && rm -rf yay
    echo -e "${GREEN}yay instalado com sucesso!${NC}"
else
    echo -e "${RED}Falha ao instalar o yay.${NC}"
fi

# --- 3. Instalação de Pacotes Essenciais (pacman) EM LOTES ---
separator
echo -e "${GREEN}--- 3. Instalação de Pacotes Essenciais (pacman) em Lotes ---${NC}"

install_batch() {
    local batch_name="$1"
    shift
    local packages=("$@")

    echo -e "\n${YELLOW}Iniciando a instalação do lote: $batch_name${NC}"
    sudo pacman -S --needed --noconfirm "${packages[@]}"
}

BATCH1_PACKAGES=( hyprland hyprlock hypridle hyprcursor hyprpaper hyprpicker waybar kitty rofi-wayland dunst cliphist xdg-desktop-portal-hyprland xdg-desktop-portal-gtk nano xdg-user-dirs archlinux-xdg-menu )
install_batch "BÁSICO (Hyprland, Waybar, Kitty)" "${BATCH1_PACKAGES[@]}"

BATCH2_PACKAGES=( networkmanager bluez bluez-utils blueberry )
install_batch "REDE e BLUETOOTH" "${BATCH2_PACKAGES[@]}"

BATCH3_PACKAGES=( ttf-font-awesome ttf-jetbrains-mono-nerd ttf-opensans ttf-dejavu noto-fonts ttf-roboto breeze breeze5 breeze-gtk papirus-icon-theme kde-cli-tools kate gparted gamescope gamemode )
install_batch "FONTES, TEMAS e FERRAMENTAS" "${BATCH3_PACKAGES[@]}"

BATCH4_PACKAGES=( pipewire pipewire-pulse pipewire-jack pipewire-alsa wireplumber gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly ffmpeg mpv pavucontrol dolphin dolphin-plugins ark kio-admin polkit-kde-agent qt5-wayland qt6-wayland )
install_batch "ÁUDIO, ARQUIVOS e CODECS" "${BATCH4_PACKAGES[@]}"

# --- 5. AUR Extras ---
separator
echo -e "${GREEN}--- 5. Instalando Pacotes AUR Extras ---${NC}"
yay -S --needed --noconfirm hyprshot wlogout qview nwg-look qt5ct-kde qt6ct-kde heroic-games-launcher

# --- 6. Copiando Configs ---
separator
echo -e "${GREEN}--- 6. Copiando Arquivos de Configuração ---${NC}"
xdg-user-dirs-update --force
\cp -rf "$CONFIG_ORIGEM" "$HOME_DESTINO/"
chown -R "$USUARIO:$USUARIO" "$HOME_DESTINO/.config"

# --- 7. Serviços ---
separator
echo -e "${GREEN}--- 7. Habilitando Serviços ---${NC}"
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth.service
systemctl --user enable --now wireplumber

# ======================================================================
# 🔥🔥🔥 8. INSTALAÇÃO FINAL – NVIDIA + VULKAN + DXVK + PROTON GE 🔥🔥🔥
# ======================================================================
separator
echo -e "${GREEN}--- 8. Instalando Drivers NVIDIA + Vulkan + DXVK + Proton-GE (Última Etapa) ---${NC}"

NVIDIA_PACKAGES=(
    nvidia
    nvidia-utils
    nvidia-settings
    lib32-nvidia-utils
    vulkan-icd-loader
    lib32-vulkan-icd-loader
    vulkan-tools
)

sudo pacman -S --needed --noconfirm "${NVIDIA_PACKAGES[@]}"
echo -e "${GREEN}Drivers NVIDIA instalados.${NC}"

# DRM KMS
sudo bash -c 'echo "options nvidia_drm modeset=1" > /etc/modprobe.d/nvidia.conf'

# mkinitcpio
sudo sed -i 's/^MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf
sudo mkinitcpio -P

# DXVK + VKD3D
yay -S --needed --noconfirm dxvk-bin vkd3d-proton-bin

# Proton-GE + Wine-GE
yay -S --needed --noconfirm proton-ge-custom wine-ge-custom

echo -e "${GREEN}NVIDIA + Vulkan + DXVK + Proton GE instalados.${NC}"

# ======================================================================

# --- 9. Conclusão ---
separator
echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}✔️ Instalação COMPLETA com Suporte NVIDIA + Heroic + Hyprland${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "${YELLOW}➡️ REINICIE O SISTEMA AGORA para ativar o driver NVIDIA.${NC}"
echo ""
#!/bin/bash

# Define a cor verde para mensagens de sucesso e cor vermelha para erros
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- 1. Determinar o usuário atual (para uso em gpasswd) ---
USUARIO=$(whoami)
if [ "$USUARIO" == "root" ]; then
    echo -e "${RED}ERRO: Por favor, execute este script como seu usuário normal, não como root.${NC}"
    exit 1
fi
echo -e "${GREEN}Usuário detectado: $USUARIO${NC}"

# --- 2. Instalação do 'yay' (AUR helper) ---
echo -e "\n${GREEN}--- 2. Instalando o 'yay' (AUR Helper) ---${NC}"
cd /tmp/ || { echo -e "${RED}Erro: Não foi possível mudar para /tmp/${NC}"; exit 1; }
echo "Removendo instalações anteriores do yay..."
rm -rf yay

echo "Clonando o repositório do yay..."
if git clone https://aur.archlinux.org/yay 2>/dev/null; then
    cd yay || { echo -e "${RED}Erro: Não foi possível mudar para /tmp/yay/${NC}"; exit 1; }
    echo "Compilando e instalando o yay..."
    # 'makepkg' deve ser executado pelo usuário, não com sudo
    if makepkg -si --noconfirm; then
        echo -e "${GREEN}yay instalado com sucesso!${NC}"
        cd ..
        echo "Limpando arquivos temporários do yay..."
        rm -rf yay
    else
        echo -e "${RED}ERRO: Falha ao compilar e instalar o yay. Abortando.${NC}"
        exit 1
    fi
else
    echo -e "${RED}ERRO: Falha ao clonar o repositório do yay. Verifique sua conexão com a internet e se o 'git' está instalado. Abortando.${NC}"
    exit 1
fi

# --- 3. Instalação de Pacotes Essenciais (pacman) ---
echo -e "\n${GREEN}--- 3. Instalação de Pacotes Essenciais (pacman) ---${NC}"
PACMAN_PACKAGES=(
    hyprland hyprlock hypridle hyprcursor hyprpaper hyprpicker waybar kitty
    rofi-wayland dolphin dolphin-plugins ark kio-admin polkit-kde-agent
    qt5-wayland qt6-wayland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    dunst cliphist mpv xdg-user-dirs ttf-font-awesome ttf-jetbrains-mono-nerd
    ttf-opensans ttf-dejavu noto-fonts ttf-roboto breeze breeze5 breeze-gtk
    papirus-icon-theme kde-cli-tools kate gparted gamescope gamemode
    pipewire pipewire-pulse pipewire-jack pipewire-alsa wireplumber gstreamer
    gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly ffmpeg
    nano pavucontrol-gtk bluez bluez-utils blueman networkmanager
    network-manager-applet archlinux-xdg-menu
)

echo "Iniciando a instalação dos pacotes via pacman..."
sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"

# Verifica o sucesso do pacman
if [ $? -ne 0 ]; then
    echo -e "${RED}AVISO: Alguns pacotes do pacman podem não ter sido instalados corretamente. Continuando...${NC}"
fi

# --- 4. Instalação e Configuração dos Drivers NVIDIA ---
echo -e "\n${GREEN}--- 4. Instalação e Configuração dos Drivers NVIDIA ---${NC}"
NVIDIA_PACKAGES=(
    nvidia nvidia-settings nvidia-utils linux-headers lib32-nvidia-utils
)
echo "Instalando pacotes NVIDIA..."
sudo pacman -S --needed --noconfirm "${NVIDIA_PACKAGES[@]}"

echo "Habilitando modeset para NVIDIA DRM..."
echo "options nvidia-drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf

echo "Recriando a imagem initramfs..."
sudo mkinitcpio -P

# --- 5. Instalação de Pacotes Adicionais (yay - AUR) ---
echo -e "\n${GREEN}--- 5. Instalação de Pacotes Adicionais (yay - AUR) ---${NC}"
YAY_PACKAGES=(
    hyprshot wlogout qview visual-studio-code-bin firefox-bin nwg-look
    qt5ct-kde qt6ct-kde heroic-games-launcher
)

echo "Iniciando a instalação dos pacotes via yay (AUR)..."
# O yay NÃO deve ser executado com sudo.
yay -S --needed --noconfirm "${YAY_PACKAGES[@]}"

# Verifica o sucesso do yay
if [ $? -ne 0 ]; then
    echo -e "${RED}AVISO: Alguns pacotes do yay (AUR) podem não ter sido instalados corretamente. Continuando...${NC}"
fi

# --- 6. Configurações Finais do Sistema ---
echo -e "\n${GREEN}--- 6. Configurações Finais do Sistema ---${NC}"

echo "Atualizando diretórios de usuário padrão (Downloads, Documents, etc.)..."
xdg-user-dirs-update --force

echo "Reconstruindo o cache do KBuildsycoca6..."
# Comando que o seu script original solicitou
XDG_MENU_PREFIX=arch- kbuildsycoca6

echo "Configurando capacidades do gamescope para melhor performance..."
# Nota: O 'which gamescope' garante que o caminho correto seja usado.
sudo setcap 'CAP_SYS_NICE=eip' $(which gamescope)

echo "Adicionando o usuário $USUARIO ao grupo 'render' (necessário para aceleração gráfica/gamescope)..."
# 'gpasswd' precisa do comando 'sudo' para modificar grupos.
if sudo gpasswd -a $USUARIO render; then
    echo -e "${GREEN}Usuário $USUARIO adicionado ao grupo render com sucesso!${NC}"
else
    echo -e "${RED}AVISO: Falha ao adicionar $USUARIO ao grupo render. Você precisará fazer isso manualmente.${NC}"
fi

echo "Configurando o layout do teclado para ABNT2 (Brasil)..."
sudo localectl set-x11-keymap br abnt2

# --- 7. Conclusão ---
echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}✔️ Instalação e Configuração Concluídas!${NC}"
echo -e "${GREEN}======================================================${NC}"
echo "1. ${RED}REINICIE SEU SISTEMA${NC} para que as alterações do kernel (NVIDIA) e as configurações de grupo (render) entrem em vigor."
echo "2. Após reiniciar, você deve conseguir iniciar o ${GREEN}Hyprland${NC}."
echo "3. Lembre-se de configurar e habilitar serviços como ${GREEN}NetworkManager, Bluetooth e WirePlumber${NC} (para áudio) se não estiverem ativos:"
echo -e "   - sudo systemctl enable --now NetworkManager"
echo -e "   - sudo systemctl enable --now bluetooth"
echo -e "   - sudo systemctl enable --now wireplumber"
echo ""

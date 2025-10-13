#!/bin/bash

# Define cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Função para exibir uma linha de separação
separator() {
    echo -e "\n${YELLOW}------------------------------------------------------${NC}"
}

# --- 1. Determinar o usuário atual (para uso em gpasswd) ---
separator
echo -e "${GREEN}--- 1. Verificação de Usuário ---${NC}"
USUARIO=$(whoami)
if [ "$USUARIO" == "root" ]; then
    echo -e "${RED}ERRO: Por favor, execute este script como seu usuário normal, não como root.${NC}"
    exit 1
fi
echo -e "${GREEN}Usuário detectado: $USUARIO${NC}"

# --- 2. Instalação do 'yay' (AUR helper) ---
separator
echo -e "${GREEN}--- 2. Instalando o 'yay' (AUR Helper) ---${NC}"
cd /tmp/ || { echo -e "${RED}Erro: Não foi possível mudar para /tmp/${NC}"; exit 1; }
echo "Removendo instalações anteriores do yay..."
rm -rf yay

echo "Clonando o repositório do yay..."
if git clone https://aur.archlinux.org/yay 2>/dev/null; then
    cd yay || { echo -e "${RED}Erro: Não foi possível mudar para /tmp/yay/${NC}"; exit 1; }
    echo "Compilando e instalando o yay..."
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

# --- 3. Instalação de Pacotes Essenciais (pacman) EM LOTES ---
separator
echo -e "${GREEN}--- 3. Instalação de Pacotes Essenciais (pacman) em Lotes ---${NC}"

echo "Sincronizando bancos de dados do pacman..."
sudo pacman -Sy --noconfirm

# Pacote de função para lidar com a instalação em lotes
install_batch() {
    local batch_name="$1"
    shift
    local packages=("$@")

    echo -e "\n${YELLOW}Iniciando a instalação do lote: $batch_name (${#packages[@]} pacotes)${NC}"
    sudo pacman -S --needed --noconfirm "${packages[@]}"
    INSTALL_STATUS=$?

    if [ $INSTALL_STATUS -ne 0 ]; then
        echo -e "${RED}AVISO CRÍTICO: Falha na instalação do lote '$batch_name'. Por favor, verifique erros. Código de saída: $INSTALL_STATUS${NC}"
        echo "Pacotes que falharam: ${packages[*]}"
    else
        echo -e "${GREEN}Lote '$batch_name' instalado com sucesso.${NC}"
    fi
}

# LOTE 1: BÁSICO, AMBIENTE HYPRLAND e TERMINAL
BATCH1_PACKAGES=(
    hyprland hyprlock hypridle hyprcursor hyprpaper hyprpicker waybar kitty
    rofi-wayland dunst cliphist xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    nano xdg-user-dirs archlinux-xdg-menu
)
install_batch "BÁSICO (Hyprland, Waybar, Kitty)" "${BATCH1_PACKAGES[@]}"

# LOTE 2: FONTES, TEMAS, FERRAMENTAS DE SISTEMA e GAMING
BATCH2_PACKAGES=(
    ttf-font-awesome ttf-jetbrains-mono-nerd ttf-opensans ttf-dejavu noto-fonts ttf-roboto
    breeze breeze5 breeze-gtk papirus-icon-theme
    kde-cli-tools kate gparted gamescope gamemode
    networkmanager network-manager-applet
)
install_batch "FONTES, TEMAS e FERRAMENTAS" "${BATCH2_PACKAGES[@]}"

# LOTE 3: ÁUDIO, VÍDEO, BLUETOOTH e ARQUIVOS
BATCH3_PACKAGES=(
    pipewire pipewire-pulse pipewire-jack pipewire-alsa wireplumber
    gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly
    ffmpeg mpv pavucontrol
    blueman
    dolphin dolphin-plugins ark kio-admin polkit-kde-agent
    qt5-wayland qt6-wayland
)
install_batch "ÁUDIO, ARQUIVOS e CODECS" "${BATCH3_PACKAGES[@]}"


# --- 4. Instalação e Configuração dos Drivers NVIDIA ---
separator
echo -e "${GREEN}--- 4. Instalação e Configuração dos Drivers NVIDIA ---${NC}"
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
separator
echo -e "${GREEN}--- 5. Instalação de Pacotes Adicionais (yay - AUR) ---${NC}"
YAY_PACKAGES=(
    hyprshot wlogout qview visual-studio-code-bin firefox-bin nwg-look
    qt5ct-kde qt6ct-kde heroic-games-launcher
)

echo "Iniciando a instalação dos pacotes via yay (AUR)..."
yay -S --needed --noconfirm "${YAY_PACKAGES[@]}"

if [ $? -ne 0 ]; then
    echo -e "${RED}AVISO: Alguns pacotes do yay (AUR) podem não ter sido instalados corretamente. Continuando...${NC}"
fi

# --- 6. Configurações Finais do Sistema (Local, Usuário, Pastas) ---
separator
echo -e "${GREEN}--- 6. Configurações Finais do Sistema (Local, Usuário, Pastas) ---${NC}"

# 🌟 NOVO PASSO: Cópia e Substituição dos Arquivos de Configuração (.config) 🌟
echo -e "\n${YELLOW}Iniciando a cópia dos arquivos de configuração (.config)...${NC}"
# Assumindo que o script 'vf.sh' está em 'archypr' e a pasta '.config' está em 'archypr'
CONFIG_SOURCE=".config"
CONFIG_DEST="/home/$USUARIO/"

if [ -d "$CONFIG_SOURCE" ]; then
    # O comando 'cp -rf' copia recursivamente e força a substituição se o destino existir.
    # Copia a pasta .config e seu conteúdo para /home/USUARIO/, substituindo o que estiver lá.
    echo "Copiando $CONFIG_SOURCE para $CONFIG_DEST (Substituir se existir)..."
    if cp -rf "$CONFIG_SOURCE" "$CONFIG_DEST"; then
        echo -e "${GREEN}Cópia do .config concluída com sucesso!${NC}"
    else
        echo -e "${RED}ERRO CRÍTICO: Falha ao copiar a pasta .config. Verifique as permissões.${NC}"
    fi
else
    echo -e "${RED}AVISO: A pasta de origem $CONFIG_SOURCE não foi encontrada. Ignorando a cópia do .config.${NC}"
fi
# FIM DO NOVO PASSO 🌟

# Criação das pastas de usuário
if command -v xdg-user-dirs-update &> /dev/null; then
    echo "Atualizando diretórios de usuário padrão (Downloads, Documents, etc.)..."
    xdg-user-dirs-update --force
    echo -e "${GREEN}Pastas de usuário atualizadas/criadas com sucesso.${NC}"
else
    echo -e "${RED}AVISO: O comando 'xdg-user-dirs-update' não foi encontrado. O pacote 'xdg-user-dirs' pode não ter sido instalado.${NC}"
fi

echo "Reconstruindo o cache do KBuildsycoca6..."
XDG_MENU_PREFIX=arch- kbuildsycoca6

echo "Configurando capacidades do gamescope para melhor performance..."
if command -v gamescope &> /dev/null; then
    sudo setcap 'CAP_SYS_NICE=eip' $(which gamescope)
else
    echo -e "${RED}AVISO: O comando 'gamescope' não foi encontrado. As capacidades não puderam ser definidas.${NC}"
fi

echo "Adicionando o usuário $USUARIO ao grupo 'render' (necessário para aceleração gráfica/gamescope)..."
if sudo gpasswd -a $USUARIO render; then
    echo -e "${GREEN}Usuário $USUARIO adicionado ao grupo render com sucesso!${NC}"
else
    echo -e "${RED}AVISO: Falha ao adicionar $USUARIO ao grupo render. Você precisará fazer isso manualmente.${NC}"
fi

echo "Configurando o layout do teclado para ABNT2 (Brasil)..."
sudo localectl set-x11-keymap br abnt2

# --- 7. Habilitação de Serviços Críticos (systemctl) ---
separator
echo -e "${GREEN}--- 7. Habilitação de Serviços Críticos (systemctl) ---${NC}"

# Função para habilitar SERVIÇOS DE SISTEMA (Requer sudo)
enable_service() {
    local service_name="$1"
    echo "Habilitando e iniciando o serviço $service_name (SYSTEM SERVICE)..."
    if [ -f "/usr/lib/systemd/system/$service_name.service" ]; then
        if sudo systemctl enable --now "$service_name"; then
            echo -e "${GREEN}Serviço $service_name habilitado e iniciado com sucesso.${NC}"
        else
            echo -e "${RED}AVISO: Falha ao habilitar/iniciar o serviço $service_name (SYSTEM). O systemctl retornou um erro.${NC}"
        fi
    else
        echo -e "${RED}AVISO: O arquivo do serviço $service_name.service (SYSTEM) não foi encontrado. O pacote pode não ter sido instalado.${NC}"
    fi
}

# Função para habilitar SERVIÇOS DE USUÁRIO (Não requer sudo)
enable_user_service() {
    local service_name="$1"
    echo "Habilitando e iniciando o serviço $service_name (USER SERVICE)..."
    if systemctl --user enable --now "$service_name"; then
        echo -e "${GREEN}Serviço $service_name habilitado e iniciado com sucesso como USER SERVICE.${NC}"
    else
        echo -e "${RED}AVISO: Falha ao habilitar/iniciar o serviço $service_name como USER SERVICE. Verifique o systemctl --user.${NC}"
    fi
}

# Habilita os serviços principais
enable_service "NetworkManager"
enable_service "bluetooth"
enable_user_service "wireplumber"


# --- 8. Conclusão ---
separator
echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}✔️ Instalação e Configuração Concluídas!${NC}"
echo -e "${GREEN}======================================================${NC}"
echo "1. ${RED}REINICIE SEU SISTEMA${NC} para que as alterações do kernel (NVIDIA) e as configurações de grupo (render) entrem em vigor."
echo "2. Após reiniciar, você deve conseguir iniciar o ${GREEN}Hyprland${NC}."
echo ""

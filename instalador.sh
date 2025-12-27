#!/bin/bash

# Define cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Salva o diretório de trabalho original do script
SCRIPT_DIR="$(pwd)"

# Função para exibir uma linha de separação
separator() {
    echo -e "\n${YELLOW}------------------------------------------------------${NC}"
}

# --- NOVA FUNÇÃO: Pausa para confirmação do usuário com tratamento de erro ---
confirmar_proxima_etapa() {
    local proxima_acao="$1"
    local status_anterior=$2

    # Se a etapa anterior falhou
    if [ "$status_anterior" -ne 0 ]; then
        echo -e "\n${YELLOW}A etapa anterior encontrou um erro. Status: $status_anterior${NC}"
        while true; do
            read -p "Deseja ignorar este erro e continuar para a ${proxima_acao}? (s/N): " resposta
            resposta=${resposta:-N} # Padrão é 'Não'
            case $resposta in
                [Ss]* ) echo -e "${YELLOW}Continuando, mas o sistema pode ficar em um estado inconsistente.${NC}"; return 0;;
                [Nn]* ) echo -e "\n${RED}Operação abortada pelo usuário devido a erro anterior.${NC}"; exit 1;;
                * ) echo "Resposta inválida. Por favor, digite 's' para sim ou 'N' para não.";;
            esac
        done
    fi
    
    # Se a etapa anterior foi bem-sucedida
    echo -e "\n${GREEN}Etapa anterior concluída com êxito.${NC}"
    
    while true; do
        read -p "Deseja prosseguir para a ${proxima_acao}? (S/n): " resposta
        resposta=${resposta:-S} # Padrão é 'Sim'
        case $resposta in
            [Ss]* ) return 0;; # Continua
            [Nn]* ) echo -e "\n${RED}Operação abortada pelo usuário.${NC}"; exit 0;;
            * ) echo "Resposta inválida. Por favor, digite 'S' para sim ou 'n' para não.";;
        esac
    done
}

# --- 0. Preparação e Atualização do Sistema ---
separator
echo -e "${GREEN}--- 0. Preparando o Sistema e Atualizando ---${NC}"
echo "Será solicitada sua senha para instalar pacotes essenciais e atualizar o sistema."
sudo pacman -S --needed git base-devel && sudo pacman -Syu
INSTALL_STATUS=$?
if [ $INSTALL_STATUS -ne 0 ]; then
    echo -e "\n${RED}--- ERRO CRÍTICO ---${NC}"
    echo -e "${RED}Não foi possível instalar pacotes básicos ou atualizar o sistema.${NC}"
    echo -e "${YELLOW}Verifique sua conexão com a internet e os espelhos do pacman. O script não pode continuar.${NC}"
    exit 1
fi
confirmar_proxima_etapa "verificação de usuário" $INSTALL_STATUS

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
    echo -e "${RED}ERRO: Diretório de configuração '$CONFIG_ORIGEM' não encontrado em $(pwd).${NC}"
    echo -e "${RED}Verifique se o script está sendo executado no diretório correto.${NC}"
    exit 1
fi

# --- 2. Instalação do 'yay' (AUR helper) ---
separator
echo -e "${GREEN}--- 2. Instalando o 'yay' (AUR Helper) ---${NC}"
cd /tmp/ || { echo -e "${RED}Erro: Não foi possível mudar para /tmp/${NC}"; exit 1; }
rm -rf yay

if git clone https://aur.archlinux.org/yay; then
    cd yay || { echo -e "${RED}Erro: Não foi possível mudar para /tmp/yay/${NC}"; exit 1; }
    echo "Compilando e instalando o yay (será necessária sua confirmação)..."
    makepkg -si
    INSTALL_STATUS=$?
    if [ $INSTALL_STATUS -eq 0 ]; then
        echo -e "${GREEN}yay instalado com sucesso!${NC}"
        cd .. && rm -rf yay
    else
        echo -e "\n${RED}--- ERRO NA INSTALAÇÃO ---${NC}"
        echo -e "${RED}Falha ao compilar e instalar o yay.${NC}"
        echo -e "${YELLOW}Motivo:${NC} Verifique se as dependências do grupo 'base-devel' foram instaladas corretamente.${NC}"
    fi
else
    echo -e "\n${RED}--- ERRO DE DOWNLOAD ---${NC}"
    echo -e "${RED}Falha ao clonar o repositório do yay.${NC}"
    echo -e "${YELLOW}Motivo:${NC} Verifique sua conexão com a internet ou se o 'git' está instalado.${NC}"
    INSTALL_STATUS=1
fi
confirmar_proxima_etapa "instalação de pacotes do Lote 1" $INSTALL_STATUS

# --- 3. Instalação de Pacotes Essenciais (pacman) EM LOTES ---
separator
echo -e "${GREEN}--- 3. Instalação de Pacotes Essenciais (pacman) em Lotes ---${NC}"

install_batch() {
    local batch_name="$1"
    shift
    local packages_str="$*"
    local packages=("$@")

    echo -e "\n${YELLOW}Iniciando a instalação do lote: $batch_name (${#packages[@]} pacotes)${NC}"
    sudo pacman -S --needed "${packages[@]}"
    INSTALL_STATUS=$?

    if [ $INSTALL_STATUS -ne 0 ]; then
        echo -e "\n${RED}--- ERRO NA INSTALAÇÃO ---${NC}"
        echo -e "${RED}O lote '$batch_name' não pôde ser instalado.${NC}"
        echo -e "${YELLOW}Motivo:${NC} Pacman retornou um erro (pacote não encontrado, conflito, etc.)."
        echo -e "\n${YELLOW}Para diagnosticar, execute o seguinte comando manualmente em outro terminal:${NC}"
        echo -e "sudo pacman -S --needed $packages_str\n"
        return 1
    else
        echo -e "${GREEN}Lote '$batch_name' instalado com sucesso.${NC}"
        return 0
    fi
}

# LOTE 1
BATCH1_PACKAGES=( hyprland hyprlock hypridle hyprcursor hyprpaper hyprpicker waybar kitty rofi-wayland dunst cliphist xdg-desktop-portal-hyprland xdg-desktop-portal-gtk nano xdg-user-dirs archlinux-xdg-menu )
install_batch "BÁSICO (Hyprland, Waybar, Kitty)" "${BATCH1_PACKAGES[@]}"
confirmar_proxima_etapa "instalação do Lote 2 (Fontes e Ferramentas)" $?

# LOTE 2
BATCH2_PACKAGES=( ttf-font-awesome ttf-jetbrains-mono-nerd ttf-opensans ttf-dejavu noto-fonts ttf-roboto breeze breeze5 breeze-gtk papirus-icon-theme kde-cli-tools kate gparted gamescope gamemode networkmanager network-manager-applet )
install_batch "FONTES, TEMAS e FERRAMENTAS" "${BATCH2_PACKAGES[@]}"
confirmar_proxima_etapa "instalação do Lote 3 (Áudio e Arquivos)" $?

# LOTE 3
BATCH3_PACKAGES=( pipewire pipewire-pulse pipewire-jack pipewire-alsa wireplumber gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly ffmpeg mpv pavucontrol blueman dolphin dolphin-plugins ark kio-admin polkit-kde-agent qt5-wayland qt6-wayland )
install_batch "ÁUDIO, ARQUIVOS e CODECS" "${BATCH3_PACKAGES[@]}"
confirmar_proxima_etapa "instalação dos drivers NVIDIA" $?

# --- 4. Instalação e Configuração dos Drivers NVIDIA (ATUALIZADO 2025) ---
separator
echo -e "${GREEN}--- 4. Verificação e Instalação dos Drivers NVIDIA ---${NC}"

# Verificação de hardware NVIDIA
if lspci | grep -Ei 'vga|3d|display' | grep -i nvidia > /dev/null; then
    echo -e "${YELLOW}Placa NVIDIA detectada. Prosseguindo com instalação dos drivers proprietários (série 590+ com open kernel modules).${NC}"

    # Pacotes padrão (open kernel modules por default em 2025 para RTX 40xx)
    NVIDIA_PACKAGES=(nvidia nvidia-utils nvidia-settings lib32-nvidia-utils)

    echo "Instalando pacotes NVIDIA..."
    sudo pacman -S --needed "${NVIDIA_PACKAGES[@]}"
    INSTALL_STATUS=$?

    if [ $INSTALL_STATUS -ne 0 ]; then
        echo -e "\n${RED}--- ERRO NA INSTALAÇÃO DOS PACOTES NVIDIA ---${NC}"
        echo -e "${RED}Não foi possível instalar os drivers NVIDIA.${NC}"
        echo -e "${YELLOW}Você pode tentar manualmente depois: sudo pacman -S nvidia nvidia-utils nvidia-settings lib32-nvidia-utils${NC}"
        confirmar_proxima_etapa "instalação de pacotes do AUR via yay" $INSTALL_STATUS
    else
        echo -e "${GREEN}Pacotes NVIDIA instalados com sucesso.${NC}"

        # Configurações essenciais (modeset=1 e fbdev=1 já default em drivers recentes)
        echo -e "${YELLOW}Configurando parâmetros NVIDIA...${NC}"
        echo "options nvidia_drm modeset=1 fbdev=1" | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null

        # Módulos no mkinitcpio
        if grep -q "^MODULES=" /etc/mkinitcpio.conf; then
            sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
        else
            echo 'MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)' | sudo tee -a /etc/mkinitcpio.conf > /dev/null
        fi
        sudo mkinitcpio -P

        # GRUB mais robusto: adiciona parâmetros substituindo "quiet" se existir
        if ! grep -q "nvidia_drm.modeset=1" /etc/default/grub; then
            sudo sed -i '/GRUB_CMDLINE_LINUX_DEFAULT=/ s/quiet"/nvidia_drm.modeset=1 nvidia_drm.fbdev=1 quiet"/' /etc/default/grub || \
            sudo sed -i '/GRUB_CMDLINE_LINUX_DEFAULT=/ s/"/ nvidia_drm.modeset=1 nvidia_drm.fbdev=1"/' /etc/default/grub
            sudo grub-mkconfig -o /boot/grub/grub.cfg
            echo -e "${GREEN}GRUB atualizado com parâmetros NVIDIA.${NC}"
        fi

        echo -e "\n${GREEN}Configuração NVIDIA concluída!${NC}"
        echo -e "${YELLOW}REINICIE O SISTEMA para ativar os drivers.${NC}"
    fi
else
    echo -e "${YELLOW}Nenhuma placa NVIDIA detectada. Pulando instalação de drivers NVIDIA.${NC}"
    INSTALL_STATUS=0
fi

confirmar_proxima_etapa "instalação de pacotes do AUR via yay" $INSTALL_STATUS

# --- 5. Instalação de Pacotes Adicionais (yay - AUR) ---
separator
echo -e "${GREEN}--- 5. Instalação de Pacotes Adicionais (yay - AUR) ---${NC}"
YAY_PACKAGES_STR="hyprshot wlogout qview visual-studio-code-bin firefox-bin nwg-look qt5ct-kde qt6ct-kde heroic-games-launcher"
YAY_PACKAGES=( $YAY_PACKAGES_STR )

echo "Iniciando a instalação dos pacotes via yay (AUR)..."
yay -S --needed "${YAY_PACKAGES[@]}"
INSTALL_STATUS=$?

if [ $INSTALL_STATUS -ne 0 ]; then
    echo -e "\n${RED}--- ERRO NA INSTALAÇÃO DO AUR ---${NC}"
    echo -e "${RED}Um ou mais pacotes do AUR não foram instalados.${NC}"
    echo -e "${YELLOW}Motivo:${NC} A compilação pode ter falhado ou o pacote não foi encontrado."
    echo -e "\n${YELLOW}Para diagnosticar, execute o seguinte comando manualmente:${NC}"
    echo -e "yay -S --needed $YAY_PACKAGES_STR\n"
fi
confirmar_proxima_etapa "configuração final do sistema" $INSTALL_STATUS

# --- 6. Configurações Finais do Sistema (ATUALIZADO) ---
separator
echo -e "${GREEN}--- 6. Configurações Finais do Sistema ---${NC}"

# Criação de pastas XDG
echo "Garantindo que as pastas de usuário (Documentos, Downloads, etc.) existam..."
xdg-user-dirs-update --force
XDG_DIRS_STATUS=$?

# Validação do arquivo XDG
if [ -f "$HOME_DESTINO/.config/user-dirs.dirs" ]; then
    echo -e "${GREEN}Arquivo de configuração XDG encontrado.${NC}"
else
    echo -e "${RED}AVISO: Arquivo ~/.config/user-dirs.dirs não encontrado.${NC}"
fi

# Cópia de configurações
echo -e "\n${YELLOW}Copiando arquivos de configuração para $HOME_DESTINO/.config ...${NC}"
\cp -rf "$CONFIG_ORIGEM" "$HOME_DESTINO/"
COPY_STATUS=$?

if [ $COPY_STATUS -ne 0 ]; then
    echo -e "${RED}ERRO: Falha ao copiar configurações.${NC}"
    confirmar_proxima_etapa "próximos ajustes do sistema" $COPY_STATUS
fi

# Permissões
chown -R "$USUARIO:$USUARIO" "$HOME_DESTINO/.config"
echo -e "${GREEN}Configurações copiadas e permissões ajustadas.${NC}"

# Reconstrução do cache KDE (executada duas vezes para maior confiabilidade)
echo "Reconstruindo cache do KDE (kbuildsycoca6)..."
XDG_MENU_PREFIX=arch- kbuildsycoca6
XDG_MENU_PREFIX=arch- kbuildsycoca6  # Segunda execução garante atualização

# Gamescope capabilities
if command -v gamescope &> /dev/null; then
    sudo setcap 'CAP_SYS_NICE=eip' "$(which gamescope)"
fi

# Layout de teclado ABNT2
sudo localectl set-x11-keymap br abnt2

confirmar_proxima_etapa "habilitação de serviços do sistema" 0

# --- 7. Habilitação de Serviços Críticos (systemctl) ---
separator
echo -e "${GREEN}--- 7. Habilitação de Serviços Críticos (systemctl) ---${NC}"

enable_service() {
    local service_name="$1"
    echo "Habilitando o serviço de sistema: $service_name..."
    sudo systemctl enable --now "$service_name"
}

enable_user_service() {
    local service_name="$1"
    echo "Habilitando o serviço de usuário: $service_name..."
    systemctl --user enable --now "$service_name"
}

enable_service "NetworkManager"
enable_service "bluetooth"
enable_user_service "wireplumber"

# --- 8. Conclusão ---
separator
echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}✔️ Instalação e Configuração Concluídas!${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "1. ${RED}REINICIE SEU SISTEMA${NC} para ativar todas as alterações (especialmente drivers NVIDIA)."
echo -e "2. Após reboot, inicie o Hyprland."
echo -e "3. Se as pastas 'Locais' não aparecerem no Dolphin, execute: ${RED}XDG_MENU_PREFIX=arch- kbuildsycoca6${NC}"
echo ""
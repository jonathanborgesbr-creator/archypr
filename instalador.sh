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


# --- 4. Instalação e Configuração dos Drivers NVIDIA ---
separator
echo -e "${GREEN}--- 4. Instalação e Configuração dos Drivers NVIDIA ---${NC}"
NVIDIA_PACKAGES_STR="nvidia nvidia-settings nvidia-utils linux-headers lib32-nvidia-utils"
NVIDIA_PACKAGES=( $NVIDIA_PACKAGES_STR )
echo "Instalando pacotes NVIDIA..."
sudo pacman -S --needed "${NVIDIA_PACKAGES[@]}"
INSTALL_STATUS=$?

if [ $INSTALL_STATUS -eq 0 ]; then
    echo "Habilitando modeset para NVIDIA DRM..."
    echo "options nvidia-drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf
    echo "Recriando a imagem initramfs..."
    sudo mkinitcpio -P
else
    echo -e "\n${RED}--- ERRO NA INSTALAÇÃO ---${NC}"
    echo -e "${RED}Os drivers da NVIDIA não puderam ser instalados.${NC}"
    echo -e "${YELLOW}Motivo:${NC} Verifique se sua placa é compatível ou se os pacotes estão disponíveis."
    echo -e "\n${YELLOW}Para diagnosticar, execute o seguinte comando manualmente:${NC}"
    echo -e "sudo pacman -S --needed $NVIDIA_PACKAGES_STR\n"
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


# --- 6. Configurações Finais do Sistema (Incluindo a Cópia de Configurações) ---
separator
echo -e "${GREEN}--- 6. Configurações Finais do Sistema ---${NC}"

# Bloco de Cópia e Permissões (Integrado do script original)
echo -e "\n${YELLOW}Copiando arquivos de configuração ($CONFIG_ORIGEM) para $HOME_DESTINO/ (Sobrescrevendo se existir)...${NC}"

# Comando de cópia.
# '\cp': Garante que nenhum alias (como 'cp -i') interfira.
# '-r': Copia recursivamente.
# '-f': Força a sobrescrita de arquivos existentes.
\cp -rf "$CONFIG_ORIGEM" "$HOME_DESTINO/"
COPY_STATUS=$?

if [ $COPY_STATUS -ne 0 ]; then
    echo -e "${RED}ERRO: Falha ao copiar os arquivos de configuração.${NC}"
    # Não interrompe, mas avisa e usa o mecanismo de confirmação
    confirmar_proxima_etapa "próximos ajustes do sistema" $COPY_STATUS
fi

# Ajuste de Permissões
if [ "$EUID" -ne 0 ]; then
    echo -e "\n${YELLOW}Ajustando permissões para o usuário $USUARIO (operação local)...${NC}"
    chown -R "$USUARIO:$USUARIO" "$HOME_DESTINO/.config"
else
    # Se o script foi executado como root/sudo
    echo -e "\n${YELLOW}Permissões mantidas (Script executado como root).${NC}"
fi

echo -e "${GREEN}Configurações copiadas e sobrescritas com sucesso para $HOME_DESTINO/.config${NC}"


# Restante das Configurações Finais
echo "Atualizando diretórios de usuário padrão..."
xdg-user-dirs-update --force

echo "Reconstruindo o cache do KBuildsycoca6..."
XDG_MENU_PREFIX=arch- kbuildsycoca6

echo "Configurando capacidades do gamescope..."
if command -v gamescope &> /dev/null; then
    sudo setcap 'CAP_SYS_NICE=eip' "$(which gamescope)"
else
    echo -e "${RED}AVISO: O comando 'gamescope' não foi encontrado. As capacidades não puderam ser definidas.${NC}"
fi

echo "Adicionando o usuário $USUARIO ao grupo 'render'..."
sudo gpasswd -a "$USUARIO" render

echo "Configurando o layout do teclado para ABNT2 (Brasil)..."
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
echo -e "1. ${RED}REINICIE SEU SISTEMA${NC} para que todas as alterações entrem em vigor."
echo -e "2. Após reiniciar, você deve conseguir iniciar o ${GREEN}Hyprland${NC}."
echo ""
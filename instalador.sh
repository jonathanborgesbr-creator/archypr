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

# --- 0. Preparação e Atualização do Sistema ---
separator
echo -e "${GREEN}--- 0. Preparando o Sistema e Atualizando (Automático) ---${NC}"
echo "Será solicitada sua senha para instalar pacotes essenciais e atualizar o sistema. A instalação será automática (--noconfirm)."
# Adicionado --noconfirm para pacman -Syu
sudo pacman -S --needed --noconfirm git base-devel && sudo pacman -Syu --noconfirm
INSTALL_STATUS=$?
if [ $INSTALL_STATUS -ne 0 ]; then
    echo -e "\n${RED}--- ERRO CRÍTICO ---${NC}"
    echo -e "${RED}Não foi possível instalar pacotes básicos ou atualizar o sistema.${NC}"
    echo -e "${YELLOW}Verifique sua conexão com a internet e os espelhos do pacman. O script não pode continuar.${NC}"
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
    echo -e "${RED}ERRO: Diretório de configuração '$CONFIG_ORIGEM' não encontrado em $(pwd).${NC}"
    echo -e "${RED}Verifique se o script está sendo executado no diretório correto.${NC}"
    exit 1
fi

# --- 2. Instalação do 'yay' (AUR helper) ---
separator
echo -e "${GREEN}--- 2. Instalando o 'yay' (AUR Helper) (Automático) ---${NC}"
cd /tmp/ || { echo -e "${RED}Erro: Não foi possível mudar para /tmp/${NC}"; exit 1; }
rm -rf yay

if git clone https://aur.archlinux.org/yay; then
    cd yay || { echo -e "${RED}Erro: Não foi possível mudar para /tmp/yay/${NC}"; exit 1; }
    echo "Compilando e instalando o yay (será automática com --noconfirm)..."
    # Adicionado --noconfirm ao makepkg -si
    makepkg -si --noconfirm
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
echo -e "${GREEN}Continuando para a próxima etapa, mesmo se a anterior tiver falhado.${NC}"


# --- 3. Instalação de Pacotes Essenciais (pacman) EM LOTES ---
separator
echo -e "${GREEN}--- 3. Instalação de Pacotes Essenciais (pacman) em Lotes (Automático) ---${NC}"

install_batch() {
    local batch_name="$1"
    shift
    local packages_str="$*"
    local packages=("$@")

    echo -e "\n${YELLOW}Iniciando a instalação do lote: $batch_name (${#packages[@]} pacotes)${NC}"
    # Adicionado --noconfirm para pacman -S
    sudo pacman -S --needed --noconfirm "${packages[@]}"
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

# LOTE 1 (MODIFICADO: 'firefox' removido)
BATCH1_PACKAGES=( hyprland hyprlock hypridle hyprcursor hyprpaper hyprpicker waybar kitty rofi-wayland dunst cliphist xdg-desktop-portal-hyprland xdg-desktop-portal-gtk nano xdg-user-dirs archlinux-xdg-menu )
install_batch "BÁSICO (Hyprland, Waybar, Kitty)" "${BATCH1_PACKAGES[@]}"
echo -e "${GREEN}Continuando para a próxima etapa, mesmo se a anterior tiver falhado.${NC}"

# LOTE 2 (Rede e Bluetooth)
BATCH2_PACKAGES=( networkmanager bluez bluez-utils blueberry )
install_batch "REDE e BLUETOOTH" "${BATCH2_PACKAGES[@]}"
echo -e "${GREEN}Continuando para a próxima etapa...${NC}"

# LOTE 3
BATCH3_PACKAGES=( ttf-font-awesome ttf-jetbrains-mono-nerd ttf-opensans ttf-dejavu noto-fonts ttf-roboto breeze breeze5 breeze-gtk papirus-icon-theme kde-cli-tools kate gparted gamescope gamemode )
install_batch "FONTES, TEMAS e FERRAMENTAS" "${BATCH3_PACKAGES[@]}"
echo -e "${GREEN}Continuando para a próxima etapa, mesmo se a anterior tiver falhado.${NC}"

# LOTE 4
BATCH4_PACKAGES=( pipewire pipewire-pulse pipewire-jack pipewire-alsa wireplumber gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly ffmpeg mpv pavucontrol dolphin dolphin-plugins ark kio-admin polkit-kde-agent qt5-wayland qt6-wayland )
install_batch "ÁUDIO, ARQUIVOS e CODECS" "${BATCH4_PACKAGES[@]}"
echo -e "${GREEN}Continuando para a próxima etapa, mesmo se a anterior tiver falhado.${NC}"


# --- 4. Instalação dos Drivers Gráficos Open-Source (Mesa) ---
separator
echo -e "${GREEN}--- 4. Instalação dos Drivers Gráficos Open-Source (Mesa) (Automático) ---${NC}"
MESA_PACKAGES_STR="mesa lib32-mesa vulkan-drivers lib32-vulkan-drivers libva-mesa-driver lib32-libva-mesa-driver"
MESA_PACKAGES=( $MESA_PACKAGES_STR )
echo "Instalando pacotes MESA (Intel, AMD, Nouveau) (Automático)..."
# Adicionado --noconfirm para pacman -S
sudo pacman -S --needed --noconfirm "${MESA_PACKAGES[@]}"
INSTALL_STATUS=$?

if [ $INSTALL_STATUS -ne 0 ]; then
    echo -e "\n${RED}--- ERRO NA INSTALAÇÃO ---${NC}"
    echo -e "${RED}Os drivers MESA não puderam ser instalados.${NC}"
    echo -e "${YELLOW}Motivo:${NC} Verifique sua conexão ou se os pacotes estão disponíveis."
    echo -e "\n${YELLOW}Para diagnosticar, execute o seguinte comando manualmente:${NC}"
    echo -e "sudo pacman -S --needed $MESA_PACKAGES_STR\n"
fi
echo -e "${GREEN}Drivers MESA instalados. Continuando para a próxima etapa.${NC}"


# --- 5. Instalação de Pacotes Adicionais (yay - AUR) ---
separator
echo -e "${GREEN}--- 5. Instalação de Pacotes Adicionais (yay - AUR) (Automático) ---${NC}"
# MODIFICADO: 'visual-studio-code-bin' removido
YAY_PACKAGES_STR="hyprshot wlogout qview nwg-look qt5ct-kde qt6ct-kde heroic-games-launcher"
YAY_PACKAGES=( $YAY_PACKAGES_STR )

echo "Iniciando a instalação dos pacotes via yay (AUR) (Automático)..."
# Adicionado --noconfirm para yay -S
yay -S --needed --noconfirm "${YAY_PACKAGES[@]}"
INSTALL_STATUS=$?

if [ $INSTALL_STATUS -ne 0 ]; then
    echo -e "\n${RED}--- ERRO NA INSTALAÇÃO DO AUR ---${NC}"
    echo -e "${RED}Um ou mais pacotes do AUR não foram instalados.${NC}"
    echo -e "${YELLOW}Motivo:${NC} A compilação pode ter falhado ou o pacote não foi encontrado."
    echo -e "\n${YELLOW}Para diagnosticar, execute o seguinte comando manualmente:${NC}"
    echo -e "yay -S --needed $YAY_PACKAGES_STR\n"
fi
echo -e "${GREEN}Continuando para a próxima etapa, mesmo se a anterior tiver falhado.${NC}"


# --- 6. Configurações Finais do Sistema (Incluindo a Cópia de Configurações) ---
separator
echo -e "${GREEN}--- 6. Configurações Finais do Sistema ---${NC}"

# REFORÇO: Etapa para garantir a criação inicial das pastas XDG antes da cópia de configs
echo "Garantindo que as pastas de usuário (Documentos, Downloads, etc.) existam..."
xdg-user-dirs-update --force
XDG_DIRS_STATUS=$?
if [ $XDG_DIRS_STATUS -ne 0 ]; then
    echo -e "${RED}AVISO: Falha ao criar os diretórios de usuário XDG (status: $XDG_DIRS_STATUS). A operação continuará.${NC}"
fi

# NOVO: Validação do arquivo de configuração principal
if [ -f "$HOME_DESTINO/.config/user-dirs.dirs" ]; then
    echo -e "${GREEN}Arquivo de configuração XDG (user-dirs.dirs) encontrado.${NC}"
else
    echo -e "${RED}AVISO: O arquivo ~/.config/user-dirs.dirs NÃO foi encontrado após a atualização XDG.${NC}"
    echo -e "${YELLOW}Isso pode fazer com que as pastas não apareçam corretamente na seção 'Locais' do Dolphin.${NC}"
fi

# Bloco de Cópia e Permissões (Integrado do script original)
echo -e "\n${YELLOW}Copiando arquivos de configuração ($CONFIG_ORIGEM) para $HOME_DESTINO/ (Sobrescrevendo se existir)...${NC}"
\cp -rf "$CONFIG_ORIGEM" "$HOME_DESTINO/"
COPY_STATUS=$?

if [ $COPY_STATUS -ne 0 ]; then
    echo -e "${RED}ERRO: Falha ao copiar os arquivos de configuração.${NC}"
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
echo "Reconstruindo o cache do KBuildsycoca6..."
XDG_MENU_PREFIX=arch- kbuildsycoca6
KBUILD_STATUS=$?

if [ $KBUILD_STATUS -eq 0 ]; then
    echo -e "${GREEN}kbuildsycoca6 executado com sucesso.${NC}"
else
    echo -e "${YELLOW}AVISO: kbuildsycoca6 retornou erro (Status: $KBUILD_STATUS).${NC}"
    echo -e "${YELLOW}Isso é comum se executado fora de uma sessão gráfica completa.${NC}"
    echo -e "${RED}Se as pastas não aparecerem no Dolphin após o reboot, execute-o manualmente em um terminal:${NC}"
    echo -e "${RED}XDG_MENU_PREFIX=arch- kbuildsycoca6${NC}"
fi

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
echo -e "${GREEN}Continuando para a próxima etapa, mesmo se a anterior tiver falhado.${NC}"


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

# Habilita NetworkManager e Bluetooth
enable_service "NetworkManager"
enable_service "bluetooth.service"
enable_user_service "wireplumber"


# --- 8. Conclusão ---
separator
echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}✔️ Instalação e Configuração Concluídas!${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "1. ${RED}REINICIE SEU SISTEMA${NC} para que todas as alterações entrem em vigor."
echo -e "2. Após reiniciar, você deve conseguir iniciar o ${GREEN}Hyprland${NC}."
echo -e "3. Se as pastas de usuário (Locais) ainda não aparecerem no Dolphin, execute em um terminal:"
echo -e "   ${RED}XDG_MENU_PREFIX=arch- kbuildsycoca6${NC} e reinicie o Dolphin."
echo ""

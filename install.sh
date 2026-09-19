#!/bin/bash
# ==============================================================
# install.sh — Instalación automatizada de Hermes Agent (Docker)
#   en un VPS Debian 13. Pensado para ejecutarse tras un
#   `git clone` del repositorio en el propio VPS.
#
# Uso:
#   git clone https://github.com/TU_USUARIO/hermes-ctf-setup.git
#   cd hermes-ctf-setup
#   ./install.sh
# ==============================================================

set -euo pipefail

BOLD="\033[1m"; GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; RESET="\033[0m"
log()  { echo -e "${GREEN}[install]${RESET} $1"; }
warn() { echo -e "${YELLOW}[install]${RESET} $1"; }
err()  { echo -e "${RED}[install]${RESET} $1" >&2; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

# --------------------------------------------------------------
# 0. Comprobaciones previas
# --------------------------------------------------------------
if [ "$(id -u)" -eq 0 ]; then
    warn "Ejecutando como root. Funcionará, pero se recomienda un usuario con sudo."
fi

if ! grep -qi "debian" /etc/os-release 2>/dev/null; then
    warn "No se detectó Debian. El script continúa, pero solo está probado en Debian 13."
fi

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
fi

# --------------------------------------------------------------
# 1. Actualizar sistema
# --------------------------------------------------------------
log "Actualizando paquetes del sistema..."
$SUDO apt update -qq && $SUDO apt upgrade -y -qq
$SUDO apt install -y -qq ca-certificates curl gnupg git

# --------------------------------------------------------------
# 2. Swap (solo si no existe ya alguna)
# --------------------------------------------------------------
if [ "$(/sbin/swapon --show | wc -l)" -eq 0 ]; then
    log "No hay swap activa. Creando 2G de swap..."
    $SUDO fallocate -l 2G /swapfile
    $SUDO chmod 600 /swapfile
    $SUDO /sbin/mkswap /swapfile >/dev/null
    $SUDO /sbin/swapon /swapfile
    if ! grep -q "/swapfile" /etc/fstab; then
        echo '/swapfile none swap sw 0 0' | $SUDO tee -a /etc/fstab >/dev/null
    fi
    log "Swap de 2G creada y activada."
else
    log "Swap ya existente detectada, se omite este paso."
fi

# --------------------------------------------------------------
# 3. Instalar Docker Engine (si no está instalado)
# --------------------------------------------------------------
if command -v docker >/dev/null 2>&1; then
    log "Docker ya está instalado ($(docker --version)). Se omite instalación."
else
    log "Instalando Docker Engine..."
    $SUDO install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    $SUDO chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null

    $SUDO apt update -qq
    $SUDO apt install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    log "Docker instalado correctamente."
fi

if [ -n "$SUDO" ] && ! groups "$USER" | grep -q docker; then
    log "Añadiendo $USER al grupo docker (necesitarás re-loguear para que aplique sin sudo)..."
    $SUDO usermod -aG docker "$USER" || true
    newgrp docker
fi

DOCKER_CMD="docker"
if [ -n "$SUDO" ] && ! groups "$USER" | grep -q docker; then
    DOCKER_CMD="sudo docker"
fi
COMPOSE_CMD="$DOCKER_CMD compose"

# --------------------------------------------------------------
# 4. Estructura de carpetas
# --------------------------------------------------------------
log "Preparando estructura de carpetas..."
mkdir -p workspace vpn

# --------------------------------------------------------------
# 5. Archivo .env
# --------------------------------------------------------------
if [ ! -f .env ]; then
    if [ -f env.example ]; then
        cp env.example .env
        log "Creado .env a partir de env.example."
    else
        err "No se encontró env.example en el repositorio. Abortando."
        exit 1
    fi

    echo
    warn "IMPORTANTE: debes rellenar .env con tu API key antes de continuar."
    echo

    # Modo interactivo: si hay terminal, pregunta la API key directamente
    if [ -t 0 ]; then
        read -rp "Introduce tu ANTHROPIC_API_KEY (o pulsa Enter para editarlo tú luego): " API_KEY
        if [ -n "${API_KEY:-}" ]; then
            sed -i "s|^ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=${API_KEY}|" .env
            log "API key guardada en .env."
        else
            warn "Recuerda editar .env manualmente antes de que el agente use la API."
        fi
    else
        warn "Ejecución no interactiva detectada. Edita .env manualmente: nano .env"
    fi
else
    log ".env ya existe, no se sobreescribe."
fi

# --------------------------------------------------------------
# 6. Aviso sobre configuración VPN (opcional)
# --------------------------------------------------------------
OVPN_COUNT=$(find vpn -maxdepth 1 -name "*.ovpn" 2>/dev/null | wc -l)
if [ "$OVPN_COUNT" -eq 0 ]; then
    warn "No hay ningún .ovpn en ./vpn — el contenedor arrancará SIN túnel VPN."
    warn "Puedes añadirlo luego con: cp tu_lab.ovpn vpn/ && docker compose up -d --force-recreate"
else
    log "Configuración VPN detectada en ./vpn ($OVPN_COUNT archivo/s)."
fi

# --------------------------------------------------------------
# 7. Build + up
# --------------------------------------------------------------
log "Construyendo la imagen (esto puede tardar unos minutos)..."
$COMPOSE_CMD build

log "Levantando el contenedor..."
$COMPOSE_CMD up -d

# --------------------------------------------------------------
# 8. Resumen final
# --------------------------------------------------------------
sleep 2
echo
log "=========================================================="
log " Instalación completada."
log "=========================================================="
$COMPOSE_CMD ps
echo
log "Comandos útiles:"
echo "  Ver logs:            $COMPOSE_CMD logs -f hermes-agent"
echo "  Entrar a la CLI:     docker exec -it hermes-agent hermes chat"
echo "  Entrar a bash:       docker exec -it hermes-agent bash"
echo "  Portal web (túnel):  ssh -L 8420:localhost:8420 $(whoami)@TU_IP_DEL_VPS"
echo
if ! grep -q "^ANTHROPIC_API_KEY=sk-ant-" .env 2>/dev/null; then
    warn "No olvides comprobar que .env tiene una API key válida:  nano .env"
    warn "y luego reiniciar con:  $COMPOSE_CMD up -d --force-recreate"
fi
log "Listo. ¡A por los CTFs!"

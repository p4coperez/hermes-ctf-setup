#!/usr/bin/env bash

set -euo pipefail

# 1. Cargar el archivo .env si existe
ENV_FILE=".env"

if [ -f "$ENV_FILE" ]; then
    echo "=== Cargando variables desde $ENV_FILE ==="
    PORT_IN_ENV=$(grep -v '^#' "$ENV_FILE" | grep -E '^HERMES_WEBUI_PORT=' | cut -d '=' -f 2- | tr -d ' "' || true)
    if [ -n "$PORT_IN_ENV" ]; then
        PORT="$PORT_IN_ENV"
    fi
fi

# Valor por defecto si no se encontró PORT en .env
PORT="${PORT:-8420}"

echo "=== Puerto configurado: $PORT (Solo acceso local: 127.0.0.1) ==="

# 2. Instalar ttyd solo si no está instalado previamente
if command -v ttyd &>/dev/null; then
    echo "=== ttyd ya está instalado ($(ttyd -v)). Omitiendo paso de compilación. ==="
else
    echo "=== Instalando dependencias de compilación ==="
    sudo apt-get update -y
    sudo apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        git \
        libjson-c-dev \
        libwebsockets-dev

    SRC_DIR="/tmp/ttyd-src"

    echo "=== Descargando y compilando ttyd desde código fuente ==="
    rm -rf "$SRC_DIR"

    git clone --depth 1 --branch main https://github.com/tsl0922/ttyd.git "$SRC_DIR"
    cd "$SRC_DIR"

    mkdir -p build && cd build
    cmake ..
    make -j"$(nproc)"
    sudo make install

    # Limpieza del directorio temporal
    cd /
    rm -rf "$SRC_DIR"

    echo "=== ttyd instalado correctamente ==="
fi

echo "=== Verificando instalación de ttyd ==="
ttyd -v

echo "=== Iniciando hermes-agent en 127.0.0.1:$PORT ==="
echo "Accede desde tu navegador local en: http://127.0.0.1:$PORT"
echo " Portal web (túnel):  ssh -L $PORT:localhost:$PORT $(whoami)@TU_IP_DEL_VPS"
# 3. Ejecutar ttyd vinculando la interfaz 127.0.0.1
exec ttyd -i 127.0.0.1 -p "$PORT" docker exec -i hermes-agent hermes chat
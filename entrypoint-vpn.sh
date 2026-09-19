#!/bin/bash
set -e

VPN_CONF_DIR="/vpn"
VPN_CONF_FILE=$(find "$VPN_CONF_DIR" -maxdepth 1 -name "*.ovpn" 2>/dev/null | head -n 1)

if [ -n "$VPN_CONF_FILE" ]; then
    echo "[entrypoint] Configuración OpenVPN encontrada: $VPN_CONF_FILE"

    if [ ! -e /dev/net/tun ]; then
        echo "[entrypoint] ERROR: /dev/net/tun no está disponible."
        echo "[entrypoint] Añade 'cap_add: NET_ADMIN' y el device /dev/net/tun"
        echo "[entrypoint] en docker-compose.yml. Continuando sin VPN..."
    else
        echo "[entrypoint] Levantando túnel OpenVPN en segundo plano..."
        openvpn --config "$VPN_CONF_FILE" \
                --daemon \
                --log /workspace/openvpn.log \
                --auth-nocache

        # Espera a que la interfaz tun0 esté activa (máx 30s)
        for i in $(seq 1 30); do
            if ip addr show tun0 >/dev/null 2>&1; then
                echo "[entrypoint] Túnel VPN activo (tun0):"
                ip -4 addr show tun0
                break
            fi
            sleep 1
        done

        if ! ip addr show tun0 >/dev/null 2>&1; then
            echo "[entrypoint] AVISO: tun0 no llegó a activarse en 30s."
            echo "[entrypoint] Revisa /workspace/openvpn.log para diagnosticar."
        fi
    fi
else
    echo "[entrypoint] No se encontró ningún .ovpn en /vpn — arrancando sin VPN."
fi


# Si se pasaron argumentos al contenedor ($@), ejecutarlos. Si no, esperar el proceso en primer plano.
if [ $# -gt 0 ]; then
    echo "[entrypoint] Ejecutando Hermes Gateway: $@"
    exec "$@"
else
    # Mantiene el contenedor vivo escuchando las tareas en segundo plano
    echo "[entrypoint] Contenedor listo y escuchando eventos."
    wait -n
fi



# Tutorial: Hermes Agent en Docker sobre Debian 13 (VPS 2 GB RAM)

Guía completa para desplegar Hermes Agent en un contenedor Docker, con
herramientas de seguridad ofensiva y soporte de túnel OpenVPN para
conectar a labs de CTF (HackTheBox, TryHackMe, etc.).

**Arquitectura**: el VPS anfitrión solo corre Docker. Todo lo demás
(Hermes Agent, el toolkit de pentest, el túnel VPN) vive aislado
dentro de un único contenedor.

---

## Instalación rápida (recomendada): GitHub + un solo script

Si ya tienes estos archivos en un repositorio de GitHub, la
instalación completa en el VPS se reduce a esto:

```bash
git clone https://github.com/tu-usuario/tu-repo.git hermes-setup
cd hermes-setup
chmod +x install.sh
./install.sh
```

`install.sh` hace TODO automáticamente:

1. Actualiza el sistema (`apt update && upgrade`).
2. Crea 2 GB de swap si no existe.
3. Instala Docker Engine si no está presente (idempotente: si ya
   está instalado, lo detecta y lo omite).
4. Crea las carpetas `workspace/` y `vpn/`.
5. Si no existe `.env`, lo genera desde `env.example` y te ofrece
   abrirlo con `nano` ahí mismo para que pongas tu API key.
6. Avisa si no hay ningún `.ovpn` en `vpn/` (puedes añadirlo después).
7. Construye la imagen (`docker compose build`) y levanta el
   contenedor (`docker compose up -d`).
8. Te muestra al final los comandos clave para empezar a usarlo.

Es seguro volver a ejecutarlo (`./install.sh` de nuevo) si algo falla
a mitad de camino — no repite pasos ya hechos.

### Preparar el repositorio en tu máquina local, antes de subirlo

```bash
mkdir hermes-setup && cd hermes-setup
# copia aquí: Dockerfile, entrypoint-vpn.sh, docker-compose.yml,
# env.example, install.sh, gitignore (renómbralo a .gitignore)

mv gitignore .gitignore
mkdir -p workspace vpn
touch workspace/.gitkeep vpn/.gitkeep

git init
git add .
git commit -m "Setup inicial de Hermes Agent"
git branch -M main
git remote add origin https://github.com/tu-usuario/tu-repo.git
git push -u origin main
```

El `.gitignore` incluido ya está configurado para que **nunca subas**
tu `.env` real (con tu API key) ni tus archivos `.ovpn` (credenciales
de VPN) — solo se suben las plantillas y el código. Cada vez que
clones el repo en un VPS nuevo, `install.sh` te vuelve a pedir esos
datos localmente, donde deben estar.

> **Importante**: revisa dos veces que `.env` y `vpn/*.ovpn` no
> aparezcan en `git status` antes de tu primer `git push`. Si alguna
> vez subes una API key por error, revócala inmediatamente desde el
> panel del proveedor (Anthropic/OpenAI/OpenRouter), no basta con
> borrarla del repo después.

---

## Instalación manual paso a paso (alternativa)

Si prefieres entender/ejecutar cada paso a mano en vez de usar
`install.sh`, sigue esta sección.

---

## 0. Requisitos previos

- VPS con Debian 13, 2 GB RAM, acceso root o sudo.
- Una API key de un proveedor LLM con modelo de ≥64.000 tokens de
  contexto (Anthropic, OpenAI u OpenRouter).
- Si vas a usar VPN: tu archivo `.ovpn` descargado de HTB/THM (y
  usuario/contraseña si el lab lo requiere).

---

## 1. Preparar el sistema

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg git
```

Añade 1-2 GB de swap (recomendable con solo 2 GB de RAM):

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

---

## 2. Instalar Docker Engine

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Verifica:

```bash
sudo docker run hello-world
```

(Opcional) Para no usar `sudo` en cada comando:

```bash
sudo usermod -aG docker $USER
# cierra sesión y vuelve a entrar para que aplique
```

---

## 3. Crear la estructura del proyecto

```bash
mkdir -p ~/hermes-setup/{workspace,vpn}
cd ~/hermes-setup
```

Coloca aquí los 4 archivos ya preparados:

| Archivo | Función |
|---|---|
| `Dockerfile` | Extiende la imagen de Hermes Agent con nmap, gobuster, sqlmap, OpenVPN, pwntools, etc. |
| `entrypoint-vpn.sh` | Levanta el túnel OpenVPN al arrancar (si hay `.ovpn` en `/vpn`) y luego lanza Hermes |
| `docker-compose.yml` | Orquesta el build, límites de RAM/CPU y permisos de red para la VPN |
| `.env.example` | Plantilla de variables de entorno |

```bash
chmod +x entrypoint-vpn.sh
cp .env.example .env
nano .env    # rellena tu API key real y el resto de valores
```

---

## 4. Añadir tu configuración VPN (opcional, para CTFs)

Copia tu archivo del lab dentro de `vpn/`:

```bash
cp /ruta/donde/lo/descargaste/lab_XXXXX.ovpn ~/hermes-setup/vpn/
```

Si tu VPN pide usuario y contraseña además del certificado, crea:

```bash
cat > ~/hermes-setup/vpn/auth.txt <<'EOF'
tu_usuario
tu_contraseña
EOF
chmod 600 ~/hermes-setup/vpn/auth.txt
```

Y avísame si quieres que ajuste `entrypoint-vpn.sh` para que use
`--auth-user-pass /vpn/auth.txt` automáticamente cuando detecte ese
archivo.

Si no vas a usar VPN por ahora, simplemente deja `vpn/` vacía — el
`entrypoint-vpn.sh` detecta que no hay `.ovpn` y arranca Hermes sin
túnel.

---

## 5. Construir y levantar el contenedor

```bash
docker compose build
docker compose up -d
docker compose logs -f hermes-agent
```

En los logs deberías ver algo así si hay VPN configurada:

```
[entrypoint] Configuración OpenVPN encontrada: /vpn/lab_XXXXX.ovpn
[entrypoint] Levantando túnel OpenVPN en segundo plano...
[entrypoint] Túnel VPN activo (tun0):
    inet 10.10.14.23/23 ...
```

Corta el seguimiento de logs con `Ctrl+C` (el contenedor sigue
corriendo en segundo plano).

---

## 6. Verificar que todo funciona

Entra al contenedor:

```bash
docker exec -it hermes-agent bash
```

Dentro, comprueba herramientas y red:

```bash
nmap --version
ip addr show tun0        # si usas VPN, debe mostrar la interfaz activa
ping -c 3 10.10.10.5     # sustituye por la IP de tu lab
```

Sal con `exit` y abre la sesión de chat del agente:

```bash
docker exec -it hermes-agent hermes chat
```

---

## 7b. Acceso desde fuera del contenedor: Telegram y portal web

Aparte de la CLI (`hermes chat`), tienes dos formas más de hablar con
el agente sin tener que entrar por SSH cada vez.

### Opción A — Bot de Telegram

1. Habla con **@BotFather** en Telegram, crea un bot nuevo (`/newbot`)
   y copia el token que te da.
2. Habla con **@userinfobot** para obtener tu propio user id numérico
   (así solo tú puedes usar el bot, no cualquiera que lo encuentre).
3. En tu `.env`:

   ```
   TELEGRAM_BOT_TOKEN=el_token_que_te_dio_botfather
   TELEGRAM_ALLOWED_USER_IDS=tu_user_id
   ```

4. Reinicia el contenedor:

   ```bash
   docker compose up -d --force-recreate
   ```

5. Escríbele a tu bot en Telegram — debería responder ya conectado al
   mismo agente que corre en el contenedor, con acceso al mismo
   `/workspace`, mismas herramientas y mismo túnel VPN si está activo.

Esto es cómodo para lanzar tareas cortas o recibir avisos desde el
móvil, pero para sesiones largas de CTF la CLI o el portal web dan
mejor visibilidad del output.

### Opción B — Portal web (vía túnel SSH)

El portal web de Hermes queda expuesto **solo en `127.0.0.1:8420`
del propio VPS** (así está configurado en `docker-compose.yml`) —
no es accesible directamente desde internet, por seguridad.

Para acceder a Hermes por la web:

```bash
bash start_hermes_chat.sh
```

Para acceder desde tu ordenador, abre un túnel SSH:

```bash
ssh -L 8420:localhost:8420 tu_usuario@ip-de-tu-vps
```

Deja esa terminal abierta y, en tu navegador local, entra a:

```
http://localhost:8420
```

Usa la contraseña que definiste en `.env`
(`HERMES_WEBUI_PASSWORD`). Se usa para acceder a la API del agente hermes


---

## 7. Primer uso con el agente

Dentro de la sesión `hermes chat`, prueba algo simple primero:

```
Haz ping a 10.10.10.5 y dime si responde, usando el terminal.
```

Si responde correctamente, ya tienes conectividad completa:
VPS → Docker → túnel VPN → red del lab.

Para tareas de reconocimiento:

```
Escanea 10.10.10.5 con nmap (todos los puertos), guarda el resultado
en /workspace/recon.txt y resume los servicios encontrados.
```

Si instalaste el skill de pentest web, actívalo explícitamente:

```
Usa el skill de pentest web contra http://10.10.10.5
```

El agente te pedirá confirmación por escrito de que tienes
autorización para el objetivo antes de lanzar el primer escaneo
activo — esto es intencional y no se puede saltar.

---

## 8. Operación diaria

```bash
# Ver estado
docker compose ps

# Ver logs
docker compose logs -f hermes-agent

# Reiniciar (mantiene memoria/skills persistentes)
docker compose restart

# Reconstruir tras cambiar el Dockerfile
docker compose up -d --build

# Parar sin borrar nada
docker compose stop

# Borrar todo, incluida la memoria persistente (¡cuidado!)
docker compose down -v
```

---

## 9. Solución de problemas comunes

**`tun0` no aparece / VPN no conecta**
- Revisa `workspace/openvpn.log` dentro del contenedor.
- Confirma que `devices: /dev/net/tun` y `cap_add: NET_ADMIN` están
  en `docker-compose.yml` (ya vienen incluidos).
- Verifica que el `.ovpn` no haya caducado (los de HTB expiran cada
  pocas horas/días).

**El agente se queda sin memoria (OOM) con varios subagentes**
- Baja `HERMES_MAX_SUBAGENTS` a `1` en `.env`.
- Sube `mem_limit` en `docker-compose.yml` si tu VPS lo permite.

**"Modelo rechazado al arrancar"**
- El modelo configurado tiene menos de 64.000 tokens de contexto.
  Cambia `HERMES_MODEL` en `.env` por uno compatible.

---

## 10. Buenas prácticas de seguridad

- No expongas el puerto de Hermes (8420) públicamente; déjalo
  comentado en `docker-compose.yml` salvo que uses un reverse proxy
  con autenticación.
- Usa siempre `HERMES_PENTEST_SCOPE` en `.env` para limitar
  explícitamente contra qué IPs/dominios puede actuar el agente.
- No reutilices este mismo contenedor para tareas que no sean tu
  laboratorio — mantenlo dedicado a CTFs/pentesting autorizado.
- Revisa `docker compose logs` periódicamente las primeras veces,
  hasta que confíes en el criterio del agente al ejecutar comandos.

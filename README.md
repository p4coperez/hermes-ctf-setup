# hermes-ctf-setup

Despliegue automatizado de **Hermes Agent** en Docker sobre un VPS
Debian 13, con toolkit de seguridad ofensiva (nmap, gobuster,
sqlmap, pwntools...) y soporte de túnel OpenVPN para labs de
HackTheBox / TryHackMe.

Todo se instala con **un solo comando** una vez subido el repo a
GitHub y clonado en el VPS.

---

## Estructura del repositorio

```
hermes-ctf-setup/
├── install.sh              # Script de instalación en una sola ejecución
├── Dockerfile               # Imagen: Hermes Agent + toolkit + OpenVPN
├── entrypoint-vpn.sh         # Levanta el túnel VPN antes de arrancar Hermes
├── docker-compose.yml        # Orquestación, límites de RAM/CPU, permisos de red
├── env.example                # Plantilla de variables de entorno (API keys, etc.)
├── .gitignore                 # Evita subir secretos (.env, vpn/, workspace/)
├── vpn/.gitkeep                 # Carpeta para tus .ovpn (vacía en el repo)
├── workspace/.gitkeep            # Carpeta de trabajo del agente (vacía en el repo)
└── tutorial-instalacion-hermes-agent.md   # Tutorial detallado paso a paso
```

---

## 1. Preparar el repositorio en tu máquina local

Descarga los archivos generados y organízalos así antes de subirlos:

```bash
mkdir hermes-ctf-setup && cd hermes-ctf-setup

# copia aquí: install.sh, Dockerfile, entrypoint-vpn.sh,
# docker-compose.yml, env.example, README.md,
# tutorial-instalacion-hermes-agent.md

mkdir -p vpn workspace
touch vpn/.gitkeep workspace/.gitkeep

# el archivo .gitignore lo descargaste como "dot-gitignore":
mv dot-gitignore .gitignore

chmod +x install.sh entrypoint-vpn.sh
```

## 2. Subir a GitHub

```bash
git init
git add .
git commit -m "Setup inicial de Hermes Agent para CTFs"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/hermes-ctf-setup.git
git push -u origin main
```

> **Importante:** `.gitignore` ya excluye `.env`, `vpn/*` y
> `workspace/*` — nunca subas tu API key ni tus archivos `.ovpn` a
> un repo, aunque sea privado.

Si el repo es público, revísalo dos veces antes de cada `git push`
(`git status`) para confirmar que no se cuela ningún secreto.

## 3. Clonar y ejecutar en el VPS (instalación en 1 paso)

```bash
ssh tu_usuario@ip-del-vps

git clone https://github.com/TU_USUARIO/hermes-ctf-setup.git
cd hermes-ctf-setup
./install.sh
```

El script `install.sh` hace, sin intervención manual salvo la API
key:

1. Actualiza el sistema (`apt update/upgrade`).
2. Crea 2 GB de swap si no existe ya ninguna.
3. Instala Docker Engine + Compose si no están presentes
   (si ya existen, no los reinstala — el script es idempotente,
   puedes volver a ejecutarlo sin miedo).
4. Crea `workspace/` y `vpn/`.
5. Genera `.env` a partir de `env.example` y te pide la API key por
   terminal (si ejecutas en modo interactivo).
6. Avisa si no hay ningún `.ovpn` en `vpn/` (puedes añadirlo después
   sin problema).
7. Construye la imagen Docker (Hermes Agent + toolkit + OpenVPN).
8. Levanta el contenedor con `docker compose up -d`.
9. Imprime un resumen con los comandos útiles para empezar a usarlo.

Al terminar, ya puedes hacer:

```bash
docker exec -it hermes-agent hermes chat
```

## 4. Actualizaciones futuras

Cuando cambies algo en el repo (por ejemplo, añadas una herramienta
al `Dockerfile`):

```bash
# en tu máquina local
git add . && git commit -m "Añadir herramienta X" && git push

# en el VPS
cd hermes-ctf-setup
git pull
docker compose up -d --build
```

## 5. Más detalles

Para la explicación paso a paso de cada pieza (VPN, Telegram, portal
web, troubleshooting), consulta
`tutorial-instalacion-hermes-agent.md` en este mismo repo.

## 6. Seguridad — antes de subir el repo, revisa

- [ ] `.env` **no** está en el repo (solo `env.example`).
- [ ] Ningún archivo `.ovpn` ni `auth.txt` está en el repo.
- [ ] Si el repo es público, no hay IPs/dominios sensibles en los
      comentarios o en `HERMES_PENTEST_SCOPE` de `env.example`.
- [ ] `HERMES_WEBUI_PASSWORD` en tu `.env` real (no el example) es
      una contraseña fuerte, no la de ejemplo.

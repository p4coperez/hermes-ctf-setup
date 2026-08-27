FROM nousresearch/hermes-agent:latest

# --- Herramientas de reconocimiento y explotación para CTFs ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    nmap \
    gobuster \
    sqlmap \
    netcat-openbsd \
    curl \
    wget \
    dnsutils \
    whois \
    net-tools \
    iputils-ping \
    openvpn \
    iproute2 \
    python3 \
    python3-pip \
    python3-venv \
    git \
    unzip \
    jq \
    && rm -rf /var/lib/apt/lists/*

# --- Entorno Python para pwntools / scripting de exploits ---
RUN python3 -m venv /opt/ctf-venv \
    && /opt/ctf-venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/ctf-venv/bin/pip install --no-cache-dir pwntools requests

ENV PATH="/opt/ctf-venv/bin:${PATH}"

# --- Carpeta para configuraciones OpenVPN (HTB/THM .ovpn) ---
RUN mkdir -p /vpn
VOLUME ["/vpn"]

# --- Script de arranque: levanta OpenVPN si hay un .ovpn presente ---
COPY entrypoint-vpn.sh /usr/local/bin/entrypoint-vpn.sh
RUN chmod +x /usr/local/bin/entrypoint-vpn.sh

ENTRYPOINT ["/usr/local/bin/entrypoint-vpn.sh"]

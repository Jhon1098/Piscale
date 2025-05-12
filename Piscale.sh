#!/usr/bin/env bash

# Pegando a TS-Key para colocar na variável do Taislcale.
#echo "Chave de Acesso do Taislcale"
#read TSKEY

# Senha da Interface do Pihole.
echo "Senha do Pihole"
read PassPI

# Definindo o Timezone
echo "Qual o Timezone do Pihole?"
read Timezone

Host=$(hostname)

all_in=$(cat <<EOF
# More info at https://github.com/pi-hole/docker-pi-hole/ and https://docs.pi-hole.net/
services:
    pihole:
      container_name: pihole
      image: pihole/pihole:latest
      hostname: "${Host}"
      ports:
      # DNS Ports
        - "53:53/tcp"
        - "53:53/udp"
      # Default HTTP Port
        - "8081:80/tcp"
      # Default HTTPs Port. FTL will generate a self-signed certificate
        - "4434:443/tcp"
      # Uncomment the line below if you are using Pi-hole as your DHCP server
        #- "67:67/udp"
      # Uncomment the line below if you are using Pi-hole as your NTP server
        #- "123:123/udp"
      environment:
      # Set the appropriate timezone for your location (https://en.wikipedia.org/wiki/List_of_tz_database_time_zones), e.g:
        TZ: "${Timezone}"
      # Set a password to access the web interface. Not setting one will result in a random password being assigned
        FTLCONF_webserver_api_password: "${PassPI}"
      # If using Docker's default `bridge` network setting the dns listening mode should be set to 'all'
        FTLCONF_dns_listeningMode: 'all'
      # Volumes store your data between container upgrades
      volumes:
      # For persisting Pi-hole's databases and common configuration file
        - ./etc-pihole:/etc/pihole
      # Uncomment the below if you have custom dnsmasq config files that you want to persist. Not needed for most starting fresh with Pi-hole v6. If you're upgrading from v5 you and have used this directory before, you should keep it en>
        - ./etc-dnsmasq.d:/etc/dnsmasq.d
      cap_add:
      # See https://github.com/pi-hole/docker-pi-hole#note-on-capabilities
      # Required if you are using Pi-hole as your DHCP server, else not needed
        - NET_ADMIN
      # Required if you are using Pi-hole as your NTP client to be able to set the host's system time
        - SYS_TIME
      # Optional, if Pi-hole should get some more processing time
        - SYS_NICE
      restart: unless-stopped

    tailscale:
      container_name: tailscaled
      volumes:
          - ./var/lib:/var/lib
          - ./dev/net/tun:/dev/net/tun
      network_mode: host
      cap_add:
          - NET_ADMIN
          - NET_RAW
      environment:
#          - TS_AUTHKEY=${TSKEY}
      image: tailscale/tailscale
      restart: unless-stopped
EOF
)
echo "Atualizando o sistema."
apt update && apt full-upgrade -y

echo "Instalandos os pacotes."
apt install git wget curl ssh docker docker-compose

echo "Criando os diretórios e arquivos."
mkdir /home/$USER/Docker /home/$USER/Docker/Piscale

echo -e "$all_in" > ~/Docker/Piscale/docker-compose.yaml

echo "Subindo Container"
cd ~/Docker/Piscale
docker-compose up -d
cd $HOME

# Executa o comando "tailscale up" dentro do container e captura a saída
output=$(docker exec -i tailscaled tailscale up)

# Verifica se a saída tem um link de autenticação
auth_url=$(echo "$output" | grep -Eo 'https://login.tailscale.com/[^ ]+')
if [ -n "$auth_url" ]; then
    echo "Por favor, abra este link no navegador para autenticar o Tailscale:"
    echo "$auth_url"
else
    echo "Não foi possível encontrar o link de autenticação. Verifique o output acima."
fi

# Aguarda o login ser concluído
echo "Aguardando autenticação..."

while true; do
    status=$(docker exec "$CONTAINER_NAME" tailscale status 2>&1)
    if echo "$status" | grep -q "Logged in as"; then
        echo "✅ Tailscale autenticado com sucesso!"
        break
    else
        echo "⏳ Ainda aguardando login... (Ctrl+C para cancelar)"
        sleep 3
    fi
done

echo "Container Rodando."
echo "Script Concluido."

#!/bin/bash
export LC_ALL=C
export UUID=${UUID:-'39e8b439-06be-4783-ad52-6357fc5e8743'}         
export NEZHA_SERVER=${NEZHA_SERVER:-''}             
export NEZHA_PORT=${NEZHA_PORT:-'5555'}            
export NEZHA_KEY=${NEZHA_KEY:-''}
export PASSWORD=${PASSWORD:-'admin'}
export PORT1=${PORT1:-''}  
export PORT2=${PORT2:-''}  
export PORT3=${PORT3:-''}  
export CHAT_ID=${CHAT_ID:-''} 
export BOT_TOKEN=${BOT_TOKEN:-''} 
export SUB_TOKEN=${SUB_TOKEN:-'sub'}

HOSTNAME=$(hostname)
USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')

[[ "$HOSTNAME" == "s1.ct8.pl" ]] && WORKDIR="$HOME/domains/${USERNAME}.ct8.pl/logs" && FILE_PATH="${HOME}/domains/${USERNAME}.ct8.pl/public_html" || WORKDIR="$HOME/domains/${USERNAME}.serv00.net/logs" && FILE_PATH="${HOME}/domains/${USERNAME}.serv00.net/public_html"

rm -rf "$WORKDIR" && mkdir -p "$WORKDIR" "$FILE_PATH" && chmod 777 "$WORKDIR" "$FILE_PATH" >/dev/null 2>&1

bash -c 'ps aux | grep $(whoami) | grep -v "sshd\|bash\|grep" | awk "{print \$2}" | xargs -r kill -9 >/dev/null 2>&1' >/dev/null 2>&1

generate_ports() {
  while true; do
    PORT1=$(shuf -i 10000-65535 -n 1)
    PORT2=$(shuf -i 10000-65535 -n 1)
    PORT3=$(shuf -i 10000-65535 -n 1)
    if [[ "$PORT1" -ne "$PORT2" && "$PORT1" -ne "$PORT3" && "$PORT2" -ne "$PORT3" ]]; then
      break
    fi
  done
}

generate_ports
export PORT1
export PORT2
export PORT3

clear
echo -e "\e[1;35m正在安装中,请稍等...\e[0m"

# Generate certificate
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout $WORKDIR/server.key -out $WORKDIR/server.crt -subj "/CN=bing.com" -days 36500

# Generate configuration files
for PORT in $PORT1 $PORT2 $PORT3; do
  CONFIG_FILE="config_${PORT}.json"
  cat > $WORKDIR/$CONFIG_FILE <<EOL
{
  "server": "[::]:$PORT",
  "users": {
    "$UUID": "$PASSWORD"
  },
  "certificate": "$WORKDIR/server.crt",
  "private_key": "$WORKDIR/server.key",
  "congestion_control": "bbr",
  "alpn": ["h3", "spdy/3.1"],
  "udp_relay_ipv6": true,
  "zero_rtt_handshake": false,
  "dual_stack": true,
  "auth_timeout": "3s",
  "task_negotiation_timeout": "3s",
  "max_idle_time": "10s",
  "max_external_packet_size": 1500,
  "gc_interval": "3s",
  "gc_lifetime": "15s",
  "log_level": "warn"
}
EOL
done

# Function to install keepalive service
install_keepalive() {
    echo -e "\n\e[1;35m正在安装保活服务中,请稍等......\e[0m"
    keep_path="$HOME/domains/keep.${USERNAME}.serv00.net/public_nodejs"
    [ -d "$keep_path" ] || mkdir -p "$keep_path"
    app_file_url="https://tuic.2go.us.kg/app.js"

    if command -v curl &> /dev/null; then
        curl -s -o "${keep_path}/app.js" "$app_file_url"
    elif command -v wget &> /dev/null; then
        wget -q -O "${keep_path}/app.js" "$app_file_url"
    else
        echo -e "\n\e[1;33m警告: 文件下载失败,请手动从https://tuic.2go.us.kg/app.js下载文件,并将文件上传到${keep_path}目录下\e[0m"
        return
    fi

    cat > ${keep_path}/.env <<EOF
UUID=${UUID}
SUB_TOKEN=${SUB_TOKEN}
TELEGRAM_CHAT_ID=${CHAT_ID}
TELEGRAM_BOT_TOKEN=${BOT_TOKEN}
NEZHA_SERVER=${NEZHA_SERVER}
NEZHA_PORT=${NEZHA_PORT}
NEZHA_KEY=${NEZHA_KEY}
EOF

    devil www add keep.${USERNAME}.serv00.net nodejs /usr/local/bin/node18 > /dev/null 2>&1
    devil ssl www add $HOST_IP le le keep.${USERNAME}.serv00.net > /dev/null 2>&1
    cd ${keep_path} && npm install dotenv axios --silent > /dev/null 2>&1

    devil www restart keep.${USERNAME}.serv00.net 2>&1 && echo -e "\e[1;32m\n全自动保活服务安装成功\n\e[0m" || echo -e "\e[1;91m安装失败，请重试\e[0m"
}

# Output the configuration links
HOST_IP="127.0.0.1"
echo -e "\e[1;32m本机IP: $HOST_IP\033[0m"

for PORT in $PORT1 $PORT2 $PORT3; do
  CONFIG_FILE="${FILE_PATH}/${SUB_TOKEN}_tuic_${PORT}.log"
  NAME="$HOST_IP-TUIC-$PORT"

  cat > $CONFIG_FILE <<EOF
tuic://$UUID:$PASSWORD@$HOST_IP:$PORT?congestion_control=bbr&alpn=h3&sni=www.bing.com&udp_relay_mode=native&allow_insecure=1#$NAME
EOF

  echo -e "\n\e[1;33mTUIC 配置: \033[0m\n"
  cat << EOF
- name: $NAME
  type: tuic
  server: $HOST_IP
  port: $PORT
  uuid: $UUID
  password: $PASSWORD
  alpn: [h3]
  disable-sni: true
  udp-relay-mode: native
  congestion-controller: bbr
  sni: www.bing.com
  skip-cert-verify: true
EOF

done

install_keepalive
echo -e "\e[1;32m脚本执行完成\033[0m"

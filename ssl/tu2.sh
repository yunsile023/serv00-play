#!/bin/bash
export LC_ALL=C
export UUID=${UUID:-'87bf5ca0-6d29-434e-bf3c-4ef66e68d1c8'}         
export NEZHA_SERVER=${NEZHA_SERVER:-''}             
export NEZHA_PORT=${NEZHA_PORT:-'5555'}            
export NEZHA_KEY=${NEZHA_KEY:-''}
export PASSWORD=${PASSWORD:-'admin'} 
export CHAT_ID=${CHAT_ID:-'7816805338'} 
export BOT_TOKEN=${BOT_TOKEN:-'7904127530:AAEvop-tjPB9C_yNTsdjuNDwIN5oiuqNtxk'} 
export SUB_TOKEN=${SUB_TOKEN:-'sub'}
PORTS=(49477 51996 61757)  # 定义三个端口
HOSTNAME=$(hostname)
USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
[[ "$HOSTNAME" == "s1.ct8.pl" ]] && WORKDIR="$HOME/domains/${USERNAME}.ct8.pl/logs" && FILE_PATH="${HOME}/domains/${USERNAME}.ct8.pl/public_html" || WORKDIR="$HOME/domains/${USERNAME}.serv00.net/logs" && FILE_PATH="${HOME}/domains/${USERNAME}.serv00.net/public_html"
rm -rf "$WORKDIR" && mkdir -p "$WORKDIR" "$FILE_PATH" && chmod 777 "$WORKDIR" "$FILE_PATH" >/dev/null 2>&1
bash -c 'ps aux | grep $(whoami) | grep -v "sshd\|bash\|grep" | awk "{print \$2}" | xargs -r kill -9 >/dev/null 2>&1' >/dev/null 2>&1


clear
echo -e "\e[1;35m正在安装中,请稍等...\e[0m"
ARCH=$(uname -m) && DOWNLOAD_DIR="." && mkdir -p "$DOWNLOAD_DIR" && FILE_INFO=()
if [ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
    FILE_INFO=("https://github.com/etjec4/tuic/releases/download/tuic-server-1.0.0/tuic-server-1.0.0-x86_64-unknown-freebsd.sha256sum web")
elif [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "x86" ]; then
    FILE_INFO=("https://github.com/etjec4/tuic/releases/download/tuic-server-1.0.0/tuic-server-1.0.0-x86_64-unknown-freebsd web")
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi
declare -A FILE_MAP
generate_random_name() {
    local chars=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890
    local name=""
    for i in {1..6}; do
        name="$name${chars:RANDOM%${#chars}:1}"
    done
    echo "$name"
}

download_with_fallback() {
    local URL=$1
    local NEW_FILENAME=$2

    curl -L -sS --max-time 2 -o "$NEW_FILENAME" "$URL" &
    CURL_PID=$!
    CURL_START_SIZE=$(stat -c%s "$NEW_FILENAME" 2>/dev/null || echo 0)
    
    sleep 1

    CURL_CURRENT_SIZE=$(stat -c%s "$NEW_FILENAME" 2>/dev/null || echo 0)
    
    if [ "$CURL_CURRENT_SIZE" -le "$CURL_START_SIZE" ]; then
        kill $CURL_PID 2>/dev/null
        wait $CURL_PID 2>/dev/null
        wget -q -O "$NEW_FILENAME" "$URL" 2>/dev/null
        echo -e "\e[1;32mDownloading $NEW_FILENAME by wget\e[0m"
    else
        wait $CURL_PID 2>/dev/null
        echo -e "\e[1;32mDownloading $NEW_FILENAME by curl\e[0m"
    fi
}

for entry in "${FILE_INFO[@]}"; do
    URL=$(echo "$entry" | cut -d ' ' -f 1)
    RANDOM_NAME=$(generate_random_name)
    NEW_FILENAME="$DOWNLOAD_DIR/$RANDOM_NAME"
    
    download_with_fallback "$URL" "$NEW_FILENAME"
    
    chmod +x "$NEW_FILENAME"
    FILE_MAP[$(echo "$entry" | cut -d ' ' -f 2)]="$NEW_FILENAME"
done
wait

# Generate cert
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout $WORKDIR/server.key -out $WORKDIR/server.crt -subj "/CN=bing.com" -days 36500

# Generate multiple configuration files
for PORT in "${PORTS[@]}"; do
cat > "config_$PORT.json" <<EOL
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

echo -e "\e[1;32mGenerated config_$PORT.json\e[0m"
done
# Output links for V2RayN
for PORT in "${PORTS[@]}"; do
    V2RAY_LINK="tuic://$UUID%3A$PASSWORD@$HOSTNAME:$PORT?sni=www.bing.com&alpn=h3&congestion_control=bbr#PL-${HOSTNAME}-tuic"
    echo -e "\e[1;32mYou can copy the following link to V2RayN for port $PORT:\e[0m"
    echo -e "\e[1;32m$V2RAY_LINK\e[0m"
done

# Check UDP port status
for PORT in "${PORTS[@]}"; do
    timeout 2 bash -c "echo > /dev/udp/127.0.0.1/$PORT" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "\e[1;32mUDP Port $PORT is running successfully.\e[0m"
    else
        echo -e "\e[1;31mUDP Port $PORT failed to start. Check logs.\e[0m"
    fi
done

echo -e "\e[1;32mAll instances are running successfully!\e[0m"

# Run multiple instances
for PORT in "${PORTS[@]}"; do
    nohup ./${FILE_MAP[web]} -c "config_$PORT.json" >$WORKDIR/log_tuic_$PORT.log 2>&1 &
    echo -e "\e[1;32mInstance running on port $PORT\e[0m"
done

install_keepalive () {
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

    # 循环处理每个端口，生成不同的 .env 文件
    for PORT in "${PORTS[@]}"; do
        cat > ${keep_path}/.env <<EOF
UUID=${UUID}
SUB_TOKEN=${SUB_TOKEN}
TELEGRAM_CHAT_ID=${CHAT_ID}
TELEGRAM_BOT_TOKEN=${BOT_TOKEN}
NEZHA_SERVER=${NEZHA_SERVER}
NEZHA_PORT=$PORT
NEZHA_KEY=${NEZHA_KEY}
EOF

        devil www add ${USERNAME}.serv00.net php > /dev/null 2>&1
        devil www add keep.${USERNAME}.serv00.net nodejs /usr/local/bin/node18 > /dev/null 2>&1
        devil ssl www add $HOST_IP le le keep.${USERNAME}.serv00.net > /dev/null 2>&1
        ln -fs /usr/local/bin/node18 ~/bin/node > /dev/null 2>&1
        ln -fs /usr/local/bin/npm18 ~/bin/npm > /dev/null 2>&1
        mkdir -p ~/.npm-global
        npm config set prefix '~/.npm-global'
        echo 'export PATH=~/.npm-global/bin:~/bin:$PATH' >> $HOME/.bash_profile && source $HOME/.bash_profile
        rm -rf $HOME/.npmrc > /dev/null 2>&1
        cd ${keep_path} && npm install dotenv axios --silent > /dev/null 2>&1
        rm $HOME/domains/keep.${USERNAME}.serv00.net/public_nodejs/public/index.html > /dev/null 2>&1
        devil www options keep.${USERNAME}.serv00.net sslonly on > /dev/null 2>&1
        if devil www restart keep.${USERNAME}.serv00.net 2>&1 | grep -q "succesfully"; then
            echo -e "\e[1;32m\n全自动保活服务安装成功\n\e[0m"
            echo -e "\e[1;32m=======================================================\e[0m"
            echo -e "\e[1;35m\n访问 https://keep.${USERNAME}.serv00.net/status 查看进程状态\n\e[0m"
            echo -e "\e[1;33m访问 https://keep.${USERNAME}.serv00.net/start 调起保活程序\n\e[0m"
            echo -e "\e[1;35m访问 https://keep.${USERNAME}.serv00.net/list 全部进程列表\n\e[0m"
            echo -e "\e[1;35m访问 https://keep.${USERNAME}.serv00.net/stop 结束进程和保活\n\e[0m"
            echo -e "\e[1;32m=======================================================\e[0m"
            echo -e "\e[1;33m如发现掉线访问https://keep.${USERNAME}.serv00.net/start唤醒,或者用https://console.cron-job.org在线访问网页自动唤醒\n\e[0m"
            echo -e "\e[1;35m如果需要Telegram通知，请先在Telegram @Botfather 申请 Bot-Token，并带CHAT_ID和BOT_TOKEN环境变量运行\n\n\e[0m"
        else
            echo -e "\e[1;91m全自动保活服务安装失败,请删除所有文件夹后重试\n\e[0m"
        fi
    done
}


run() {
  # 循环处理每个端口
  for PORT in "${PORTS[@]}"; do
    if [ -e "$(basename ${FILE_MAP[npm]})" ]; then
      tlsPorts=("443" "8443" "2096" "2087" "2083" "2053")
      if [[ "${tlsPorts[*]}" =~ "${NEZHA_PORT}" ]]; then
        NEZHA_TLS="--tls"
      else
        NEZHA_TLS=""
      fi
      if [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_PORT" ] && [ -n "$NEZHA_KEY" ]; then
        export TMPDIR=$(pwd)
        nohup ./"$(basename ${FILE_MAP[npm]})" -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 & 
        sleep 1
        pgrep -x "$(basename ${FILE_MAP[npm]})" > /dev/null && echo -e "\e[1;32m$(basename ${FILE_MAP[npm]}) is running\e[0m" || { 
          echo -e "\e[1;35m$(basename ${FILE_MAP[npm]}) is not running, restarting...\e[0m"; 
          pkill -f "$(basename ${FILE_MAP[npm]})" && nohup ./"$(basename ${FILE_MAP[npm]})" -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 & 
          sleep 2; 
          echo -e "\e[1;32m"$(basename ${FILE_MAP[npm]})" restarted\e[0m"; 
        }
      else
        echo -e "\e[1;35mNEZHA variable is empty, skipping running\e[0m"
      fi
    fi

    if [ -e "$(basename ${FILE_MAP[web]})" ]; then
      # 使用动态配置文件：config_$PORT.json
      nohup ./"$(basename ${FILE_MAP[web]})" -c "config_$PORT.json" >/dev/null 2>&1 &
      sleep 1
      pgrep -x "$(basename ${FILE_MAP[web]})" > /dev/null && echo -e "\e[1;32m$(basename ${FILE_MAP[web]}) is running\e[0m" || { 
        echo -e "\e[1;35m$(basename ${FILE_MAP[web]}) is not running, restarting...\e[0m"; 
        pkill -f "$(basename ${FILE_MAP[web]})" && nohup ./"$(basename ${FILE_MAP[web]})" -c "config_$PORT.json" >/dev/null 2>&1 & 
        sleep 2; 
        echo -e "\e[1;32m$(basename ${FILE_MAP[web]}) restarted\e[0m"; 
      }
    fi
  done
  rm -rf "$(basename ${FILE_MAP[web]})" "$(basename ${FILE_MAP[npm]})"
}
run


get_ip() {
  IP_LIST=($(devil vhost list | awk '/^[0-9]+/ {print $1}'))
  API_URL="https://status.eooce.com/api"
  IP=""
  THIRD_IP=${IP_LIST[2]}
  RESPONSE=$(curl -s --max-time 2 "${API_URL}/${THIRD_IP}")
  if [[ $(echo "$RESPONSE" | jq -r '.status') == "Available" ]]; then
      IP=$THIRD_IP
  else
      FIRST_IP=${IP_LIST[0]}
      RESPONSE=$(curl -s --max-time 2 "${API_URL}/${FIRST_IP}")
      
      if [[ $(echo "$RESPONSE" | jq -r '.status') == "Available" ]]; then
          IP=$FIRST_IP
      else
          IP=${IP_LIST[1]}
      fi
  fi
echo "$IP"
}

HOST_IP=$(get_ip)
echo -e "\e[1;32m本机IP: $HOST_IP\033[0m"

ISP=$(curl -s --max-time 2 https://speed.cloudflare.com/meta | awk -F\" '{print $26}' | sed -e 's/ /_/g' || echo "0")
get_name() { if [ "$HOSTNAME" = "s1.ct8.pl" ]; then SERVER="CT8"; else SERVER=$(echo "$HOSTNAME" | cut -d '.' -f 1); fi; echo "$SERVER"; }
NAME=$ISP-$(get_name)-tuic

echo -e "\e[1;32mTuic安装成功\033[0m\n"
echo -e "\e[1;33mV2rayN 或 Nekobox等直接可以导入使用,跳过证书验证需设置为true\033[0m\n"
cat > ${FILE_PATH}/${SUB_TOKEN}_tuic.log <<EOF
tuic://$UUID:$PASSWORD@$HOST_IP:$PORT?congestion_control=bbr&alpn=h3&sni=www.bing.com&udp_relay_mode=native&allow_insecure=1#$NAME
EOF
cat ${FILE_PATH}/${SUB_TOKEN}_tuic.log
echo -e "\n\e[1;33mClash: \033[0m"
cat << EOF
- name: $NAME
  type: tuic
  server: $HOST_IP
  port: $PORT                                                          
  uuid: $UUID
  password: $PASSWORD
  alpn: [h3]
  disable-sni: true
  reduce-rtt: true
  udp-relay-mode: native
  congestion-controller: bbr
  sni: www.bing.com                                
  skip-cert-verify: true
EOF
echo -e "\n\e[1;35m节点订阅链接: https://${USERNAME}.serv00.net/${SUB_TOKEN}_tuic.log  适用于V2ranN/Nekobox/Karing/小火箭/sterisand/Loon 等\033[0m\n"
rm -rf config.json fake_useragent_0.2.0.json
install_keepalive
echo -e "\e[1;35m老王serv00|CT8单协议tuic无交互一键安装脚本[0m"
echo -e "\e[1;35m脚本地址：https://github.com/eooce/scripts\e[0m"
echo -e "\e[1;35m反馈论坛：https://bbs.vps8.me\e[0m"
echo -e "\e[1;35mTG反馈群组：https://t.me/vps888\e[0m"
echo -e "\e[1;35m转载请著名出处，请勿滥用\e[0m\n"
echo -e "\e[1;32mRuning done!\033[0m"

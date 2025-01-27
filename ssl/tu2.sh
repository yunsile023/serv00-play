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

check_binexec_and_port () {
  port_list=$(devil port list)
  tcp_ports=$(echo "$port_list" | grep -c "tcp")
  udp_ports=$(echo "$port_list" | grep -c "udp")

  if [[ $udp_ports -lt 3 ]]; then
      echo -e "\e[1;91m没有足够的UDP端口,正在调整...\e[0m"

      if [[ $tcp_ports -ge 3 ]]; then
          tcp_port_to_delete=$(echo "$port_list" | awk '/tcp/ {print $1}' | head -n 1)
          devil port del tcp $tcp_port_to_delete
          echo -e "\e[1;32m已删除TCP端口: $tcp_port_to_delete\e[0m"
      fi

      for i in {1..3}; do
          while true; do
              udp_port=$(shuf -i 10000-65535 -n 1)
              result=$(devil port add udp $udp_port 2>&1)
              if [[ $result == *"succesfully"* ]]; then
                  echo -e "\e[1;32m已添加UDP端口: $udp_port"
                  eval "udp_port${i}=$udp_port"
                  break
              else
                  echo -e "\e[1;33m端口 $udp_port 不可用，尝试其他端口...\e[0m"
              fi
          done
      done

      echo -e "\e[1;32m端口已调整完成, 将断开SSH连接, 请重新连接SSH并重新执行脚本\e[0m"
      devil binexec on >/dev/null 2>&1
      kill -9 $(ps -o ppid= -p $$) >/dev/null 2>&1
  else
      udp_ports=$(echo "$port_list" | awk '/udp/ {print $1}')
      udp_port1=$(echo "$udp_ports" | sed -n '1p')
      udp_port2=$(echo "$udp_ports" | sed -n '2p')
      udp_port3=$(echo "$udp_ports" | sed -n '3p')

      echo -e "\e[1;35m当前UDP端口: $udp_port1, $udp_port2, $udp_port3\e[0m"
  fi

  export PORT1=$udp_port1
  export PORT2=$udp_port2
  export PORT3=$udp_port3
}
check_binexec_and_port

clear
echo -e "\e[1;35m正在安装中,请稍等...\e[0m"
ARCH=$(uname -m) && DOWNLOAD_DIR="." && mkdir -p "$DOWNLOAD_DIR" && FILE_INFO=()
if [ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
    FILE_INFO=("https://github.com/etjec4/tuic/releases/download/tuic-server-1.0.0/tuic-server-1.0.0-x86_64-unknown-freebsd.sha256sum web" "https://github.com/eooce/test/releases/download/ARM/swith npm")
elif [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "x86" ]; then
    FILE_INFO=("https://github.com/etjec4/tuic/releases/download/tuic-server-1.0.0/tuic-server-1.0.0-x86_64-unknown-freebsd web" "https://github.com/eooce/test/releases/download/freebsd/npm npm")
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

# Generate configuration files
for port in $PORT1 $PORT2 $PORT3; do
  cat > config_$port.json <<EOL
{
  "server": "[::]:$port",
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

install_keepalive () {
    echo -e "\n\e[1;35m正在安装保活服务中,请稍等......\e[0m"
    keep_path="$HOME/domains/keep.${USERNAME}.serv00.net/public_nodejs"
    [ -d "$keep_path" ] || mkdir -p "$keep_path"
    app_file_url="https://tuic.2go.us.kg/app.js"

    # 下载 app.js 文件
    echo -e "\e[1;32m正在下载 app.js 文件...\e[0m"
    if command -v curl &> /dev/null; then
        curl -s -o "${keep_path}/app.js" "$app_file_url" || { echo -e "\e[1;91mcurl 下载失败, 尝试使用 wget...\e[0m"; wget -q -O "${keep_path}/app.js" "$app_file_url"; }
    elif command -v wget &> /dev/null; then
        wget -q -O "${keep_path}/app.js" "$app_file_url" || { echo -e "\e[1;91mwget 下载失败, 请手动下载文件。\e[0m"; return; }
    else
        echo -e "\e[1;91m未找到 curl 或 wget, 无法下载 app.js 文件。\e[0m"
        echo -e "\e[1;33m请手动从以下链接下载文件并上传到 ${keep_path} 目录：\e[0m"
        echo -e "\e[1;35m$app_file_url\e[0m"
        return
    fi

    # 检查 app.js 是否下载成功
    if [ ! -f "${keep_path}/app.js" ]; then
        echo -e "\e[1;91mapp.js 文件下载失败，请手动下载并上传到 ${keep_path} 目录。\e[0m"
        return
    else
        echo -e "\e[1;32mapp.js 文件下载成功。\e[0m"
    fi

    # 配置 .env 文件
    cat > ${keep_path}/.env <<EOF
UUID=${UUID}
SUB_TOKEN=${SUB_TOKEN}
TELEGRAM_CHAT_ID=${CHAT_ID}
TELEGRAM_BOT_TOKEN=${BOT_TOKEN}
NEZHA_SERVER=${NEZHA_SERVER}
NEZHA_PORT=${NEZHA_PORT}
NEZHA_KEY=${NEZHA_KEY}
EOF

    # 配置 Node.js 环境
    echo -e "\e[1;32m正在配置 Node.js 环境...\e[0m"
    devil www add ${USERNAME}.serv00.net php > /dev/null 2>&1
    devil www add keep.${USERNAME}.serv00.net nodejs /usr/local/bin/node18 > /dev/null 2>&1
    devil ssl www add $HOST_IP le le keep.${USERNAME}.serv00.net > /dev/null 2>&1
    ln -fs /usr/local/bin/node18 ~/bin/node > /dev/null 2>&1
    ln -fs /usr/local/bin/npm18 ~/bin/npm > /dev/null 2>&1
    mkdir -p ~/.npm-global
    npm config set prefix '~/.npm-global'
    echo 'export PATH=~/.npm-global/bin:~/bin:$PATH' >> $HOME/.bash_profile && source $HOME/.bash_profile
    rm -rf $HOME/.npmrc > /dev/null 2>&1

    # 安装依赖
    echo -e "\e[1;32m正在安装 Node.js 依赖...\e[0m"
    cd ${keep_path} && npm install dotenv axios --silent > /dev/null 2>&1

    # 删除默认的 index.html
    rm $HOME/domains/keep.${USERNAME}.serv00.net/public_nodejs/public/index.html > /dev/null 2>&1

    # 启用 SSL
    devil www options keep.${USERNAME}.serv00.net sslonly on > /dev/null 2>&1

    # 重启 Node.js 服务
    echo -e "\e[1;32m正在重启 Node.js 服务...\e[0m"
    if devil www restart keep.${USERNAME}.serv00.net 2>&1 | grep -q "succesfully"; then
        echo -e "\e[1;32m\n全自动保活服务安装成功\n\e[0m"
        echo -e "\e[1;32m=======================================================\e[0m"
        echo -e "\e[1;35m\n访问 https://keep.${USERNAME}.serv00.net/status 查看进程状态\n\e[0m"
        echo -e "\e[1;33m访问 https://keep.${USERNAME}.serv00.net/start 调起保活程序\n\e[0m"
        echo -e "\e[1;35m访问 https://keep.${USERNAME}.serv00.net/list 全部进程列表\n\e[0m"
        echo -e "\e[1;35m访问 https://keep.${USERNAME}.serv00.net/stop 结束进程和保活\n\e[0m"
        echo -e "\e[1;32m=======================================================\e[0m"
        echo -e "\e[1;33m如发现掉线访问 https://keep.${USERNAME}.serv00.net/start 唤醒, 或者用 https://console.cron-job.org 在线访问网页自动唤醒\n\e[0m"
        echo -e "\e[1;35m如果需要 Telegram 通知，请先在 Telegram @Botfather 申请 Bot-Token，并带 CHAT_ID 和 BOT_TOKEN 环境变量运行\n\n\e[0m"
    else
        echo -e "\e[1;91m全自动保活服务安装失败, 请删除所有文件夹后重试\n\e[0m"
    fi
}

run() {
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
      pgrep -x "$(basename ${FILE_MAP[npm]})" > /dev/null && echo -e "\e[1;32m$(basename ${FILE_MAP[npm]}) is running\e[0m" || { echo -e "\e[1;35m$(basename ${FILE_MAP[npm]}) is not running, restarting...\e[0m"; pkill -f "$(basename ${FILE_MAP[npm]})" && nohup ./"$(basename ${FILE_MAP[npm]})" -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 & sleep 2; echo -e "\e[1;32m"$(basename ${FILE_MAP[npm]})" restarted\e[0m"; }
    else
      echo -e "\e[1;35mNEZHA variable is empty, skipping running\e[0m"
    fi
  fi

  for port in $PORT1 $PORT2 $PORT3; do
    if [ -e "$(basename ${FILE_MAP[web]})" ]; then
      nohup ./"$(basename ${FILE_MAP[web]})" -c config_$port.json >/dev/null 2>&1 &
      sleep 1
      pgrep -x "$(basename ${FILE_MAP[web]})" > /dev/null && echo -e "\e[1;32m$(basename ${FILE_MAP[web]}) is running on port $port\e[0m" || { echo -e "\e[1;35m$(basename ${FILE_MAP[web]}) is not running on port $port, restarting...\e[0m"; pkill -f "$(basename ${FILE_MAP[web]})" && nohup ./"$(basename ${FILE_MAP[web]})" -c config_$port.json >/dev/null 2>&1 & sleep 2; echo -e "\e[1;32m$(basename ${FILE_MAP[web]}) restarted on port $port\e[0m"; }
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
tuic://$UUID:$PASSWORD@$HOST_IP:$PORT1?congestion_control=bbr&alpn=h3&sni=www.bing.com&udp_relay_mode=native&allow_insecure=1#$NAME-1
tuic://$UUID:$PASSWORD@$HOST_IP:$PORT2?congestion_control=bbr&alpn=h3&sni=www.bing.com&udp_relay_mode=native&allow_insecure=1#$NAME-2
tuic://$UUID:$PASSWORD@$HOST_IP:$PORT3?congestion_control=bbr&alpn=h3&sni=www.bing.com&udp_relay_mode=native&allow_insecure=1#$NAME-3
EOF
cat ${FILE_PATH}/${SUB_TOKEN}_tuic.log
echo -e "\n\e[1;33mClash: \033[0m"
cat << EOF
- name: $NAME-1
  type: tuic
  server: $HOST_IP
  port: $PORT1                                                          
  uuid: $UUID
  password: $PASSWORD
  alpn: [h3]
  disable-sni: true
  reduce-rtt: true
  udp-relay-mode: native
  congestion-controller: bbr
  sni: www.bing.com                                
  skip-cert-verify: true

- name: $NAME-2
  type: tuic
  server: $HOST_IP
  port: $PORT2                                                          
  uuid: $UUID
  password: $PASSWORD
  alpn: [h3]
  disable-sni: true
  reduce-rtt: true
  udp-relay-mode: native
  congestion-controller: bbr
  sni: www.bing.com                                
  skip-cert-verify: true

- name: $NAME-3
  type: tuic
  server: $HOST_IP
  port: $PORT3                                                          
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
rm -rf config_*.json fake_useragent_0.2.0.json
install_keepalive
echo -e "\e[1;35m老王serv00|CT8单协议tuic无交互一键安装脚本[0m"
echo -e "\e[1;35m脚本地址：https://github.com/eooce/scripts\e[0m"
echo -e "\e[1;35m反馈论坛：https://bbs.vps8.me\e[0m"
echo -e "\e[1;35mTG反馈群组：https://t.me/vps888\e[0m"
echo -e "\e[1;35m转载请著名出处，请勿滥用\e[0m\n"
echo -e "\e[1;32mRuning done!\033[0m"

#!/bin/bash
export LC_ALL=C
export UUID=${UUID:-'39e8b439-06be-4783-ad52-6357fc5e8743'}
export NEZHA_SERVER=${NEZHA_SERVER:-''}
export NEZHA_PORT=${NEZHA_PORT:-'5555'}
export NEZHA_KEY=${NEZHA_KEY:-''}
export PASSWORD=${PASSWORD:-'admin'}
export PORT1=${PORT1:-'41170'}  # 设置端口1
export PORT2=${PORT2:-'51996'}  # 设置端口2
export PORT3=${PORT3:-'61757'}  # 设置端口3
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

  if [[ $udp_ports -lt 1 ]]; then
      echo -e "\e[1;91m没有可用的UDP端口,正在调整...\e[0m"

      if [[ $tcp_ports -ge 3 ]]; then
          tcp_port_to_delete=$(echo "$port_list" | awk '/tcp/ {print $1}' | head -n 1)
          devil port del tcp $tcp_port_to_delete
          echo -e "\e[1;32m已删除TCP端口: $tcp_port_to_delete\e[0m"
      fi

      while true; do
          udp_port=$(shuf -i 10000-65535 -n 1)
          result=$(devil port add udp $udp_port 2>&1)
          if [[ $result == *"succesfully"* ]]; then
              echo -e "\e[1;32m已添加UDP端口: $udp_port"
              udp_port1=$udp_port
              break
          else
              echo -e "\e[1;33m端口 $udp_port 不可用，尝试其他端口...\e[0m"
          fi
      done

      echo -e "\e[1;32m端口已调整完成, 将断开SSH连接, 请重新连接SSH并重新执行脚本\e[0m"
      devil binexec on >/dev/null 2>&1
      kill -9 $(ps -o ppid= -p $$) >/dev/null 2>&1
  else
      udp_ports=$(echo "$port_list" | awk '/udp/ {print $1}')
      udp_port1=$(echo "$udp_ports" | sed -n '1p')

      echo -e "\e[1;35m当前UDP端口: $udp_port1\e[0m"
  fi

  export PORT1=$udp_port1
  export PORT2=$((PORT1 + 1))
  export PORT3=$((PORT2 + 1))
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

# Generate configuration file
cat > config.json <<EOL
{
  "server": "[::]:$PORT1",
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
            echo -e "\n\e[1;33m警告: 文件下载失败，未找到 curl 或 wget 工具，请手动安装其中之一。\e[0m"
        exit 1
    fi

    cat > "${keep_path}/start.sh" <<EOL
#!/bin/bash
while true; do
    node ${keep_path}/app.js
    sleep 5
done
EOL

    chmod +x "${keep_path}/start.sh"

    # 通过 nohup 后台启动保活脚本
    nohup bash "${keep_path}/start.sh" > /dev/null 2>&1 &
    echo -e "\n\e[1;32m保活服务已安装并运行。\e[0m"
}
install_keepalive

start_tuic_server () {
    echo -e "\n\e[1;35m正在启动 TUIC 服务器...\e[0m"
    # 启动 TUIC 服务器
    nohup ${FILE_MAP[web]} -c config.json > "$WORKDIR/tuic.log" 2>&1 &
    TUIC_PID=$!
    echo $TUIC_PID > "$WORKDIR/tuic.pid"
    echo -e "\n\e[1;32mTUIC 服务器已启动，PID: $TUIC_PID。\e[0m"
}

setup_nezha_agent () {
    if [[ -n "$NEZHA_SERVER" && -n "$NEZHA_PORT" && -n "$NEZHA_KEY" ]]; then
        echo -e "\n\e[1;35m正在启动哪吒探针...\e[0m"
        NEZHA_AGENT_PATH="${WORKDIR}/nezha-agent"
        wget -q -O "$NEZHA_AGENT_PATH" https://github.com/naiba/nezha/releases/latest/download/nezha-agent_linux_amd64
        chmod +x "$NEZHA_AGENT_PATH"

        nohup "$NEZHA_AGENT_PATH" -s "$NEZHA_SERVER:$NEZHA_PORT" -p "$NEZHA_KEY" > "$WORKDIR/nezha.log" 2>&1 &
        echo -e "\n\e[1;32m哪吒探针已启动。\e[0m"
    else
        echo -e "\n\e[1;33m警告: 哪吒探针未配置。\e[0m"
    fi
}

# 调用函数启动服务
start_tuic_server
setup_nezha_agent

# 输出配置信息
clear
echo -e "\n\e[1;32m所有服务已启动完成。\e[0m"
echo -e "\n\e[1;34m节点配置信息：\e[0m"
echo -e "UUID: $UUID"
echo -e "密码: $PASSWORD"
echo -e "端口1: $PORT1"
echo -e "端口2: $PORT2"
echo -e "端口3: $PORT3"
echo -e "\n\e[1;34m保活脚本路径: $HOME/domains/keep.${USERNAME}.serv00.net/public_nodejs/start.sh\e[0m"
echo -e "\n\e[1;34m日志文件:\e[0m"
echo -e "TUIC 日志: $WORKDIR/tuic.log"
echo -e "哪吒探针日志: $WORKDIR/nezha.log (如果启用)"


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

check_binexec_and_ports () {
  port_list=$(devil port list)
  tcp_ports=$(echo "$port_list" | grep -c "tcp")
  udp_ports=$(echo "$port_list" | grep -c "udp")

  if [[ $udp_ports -lt 3 ]]; then
      echo -e "\e[1;91m可用UDP端口不足3个，正在调整...\e[0m"

      while [[ $udp_ports -lt 3 ]]; do
          udp_port=$(shuf -i 10000-65535 -n 1)
          result=$(devil port add udp $udp_port 2>&1)
          if [[ $result == *"succesfully"* ]]; then
              echo -e "\e[1;32m已添加UDP端口: $udp_port\e[0m"
              udp_ports=$((udp_ports + 1))
          else
              echo -e "\e[1;33m端口 $udp_port 不可用，尝试其他端口...\e[0m"
          fi
      done

      echo -e "\e[1;32m端口已调整完成, 将断开SSH连接, 请重新连接SSH并重新执行脚本\e[0m"
      devil binexec on >/dev/null 2>&1
      kill -9 $(ps -o ppid= -p $$) >/dev/null 2>&1
  fi

  udp_ports_list=$(echo "$port_list" | awk '/udp/ {print $1}')
  PORT1=$(echo "$udp_ports_list" | sed -n '1p')
  PORT2=$(echo "$udp_ports_list" | sed -n '2p')
  PORT3=$(echo "$udp_ports_list" | sed -n '3p')

  export PORT1 PORT2 PORT3
  echo -e "\e[1;35m当前UDP端口: $PORT1, $PORT2, $PORT3\e[0m"
}
check_binexec_and_ports

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

# Install keepalive and other logic
# Install keepalive and other dependencies
install_keepalive() {
    if ! command -v systemctl &>/dev/null; then
        echo -e "\e[1;31mSystemd is required but not installed. Please install systemd or run this script on a compatible system.\e[0m"
        exit 1
    fi

    # Create a systemd service file for the application
    cat > /etc/systemd/system/myapp.service <<EOL
[Unit]
Description=Custom Application
After=network.target

[Service]
Type=simple
ExecStart=${FILE_MAP[web]} -c config.json
Restart=always
RestartSec=3
Environment="NEZHA_SERVER=${NEZHA_SERVER}" "NEZHA_PORT=${NEZHA_PORT}" "NEZHA_KEY=${NEZHA_KEY}" "PORT1=${PORT1}" "PORT2=${PORT2}" "PORT3=${PORT3}"
WorkingDirectory=$(pwd)
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=myapp

[Install]
WantedBy=multi-user.target
EOL

    # Reload systemd and enable the service
    systemctl daemon-reload
    systemctl enable myapp.service
    systemctl start myapp.service

    echo -e "\e[1;32mService installed and started successfully.\e[0m"
}

# Start NEZHA agent if configured
install_nezha_agent() {
    if [[ -n "$NEZHA_SERVER" && -n "$NEZHA_PORT" && -n "$NEZHA_KEY" ]]; then
        echo -e "\e[1;35mInstalling NEZHA agent...\e[0m"

        wget -q -O nezha-agent https://github.com/naiba/nezha/releases/latest/download/nezha-agent_linux_amd64
        chmod +x nezha-agent

        cat > /etc/systemd/system/nezha-agent.service <<EOL
[Unit]
Description=Nezha Monitoring Agent
After=network.target

[Service]
Type=simple
ExecStart=$(pwd)/nezha-agent -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY}
Restart=always
RestartSec=3
WorkingDirectory=$(pwd)
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=nezha-agent

[Install]
WantedBy=multi-user.target
EOL

        # Reload systemd and enable NEZHA service
        systemctl daemon-reload
        systemctl enable nezha-agent.service
        systemctl start nezha-agent.service

        echo -e "\e[1;32mNEZHA agent installed and started successfully.\e[0m"
    else
        echo -e "\e[1;33mNEZHA configuration not provided. Skipping NEZHA agent installation.\e[0m"
    fi
}

# Run functions
install_keepalive
install_nezha_agent

# Output status and logs
echo -e "\e[1;32m服务已成功部署！以下是关键配置：\e[0m"
echo -e "\e[1;36m端口 1: $PORT1\e[0m"
echo -e "\e[1;36m端口 2: $PORT2\e[0m"
echo -e "\e[1;36m端口 3: $PORT3\e[0m"
echo -e "\e[1;36mUUID: $UUID\e[0m"
echo -e "\e[1;36m密码: $PASSWORD\e[0m"

if systemctl is-active --quiet myapp; then
    echo -e "\e[1;32m主服务状态: 正常运行中\e[0m"
else
    echo -e "\e[1;31m主服务状态: 未运行，请检查日志。\e[0m"
fi

if [[ -n "$NEZHA_SERVER" ]] && systemctl is-active --quiet nezha-agent; then
    echo -e "\e[1;32mNEZHA 监控状态: 正常运行中\e[0m"
else
    echo -e "\e[1;33mNEZHA 监控状态: 未配置或未运行。\e[0m"
fi

echo -e "\e[1;35m查看日志:\e[0m"
echo -e "  主服务日志: \e[1;36mjournald -u myapp.service -f\e[0m"
echo -e "  NEZHA 日志: \e[1;36mjournald -u nezha-agent.service -f\e[0m"

echo -e "\e[1;32m所有任务已完成！\e[0m"


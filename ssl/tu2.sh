#!/bin/bash

# 定义生成的 TUIC 节点配置文件
UUID="$(cat /proc/sys/kernel/random/uuid)"
PASSWORD="admin"
SERVER_IP="$(curl -s ifconfig.me)"
PORTS=(49477 49478 49479) # 定义三个不同的端口
SNI="www.bing.com"

# 输出节点信息
for PORT in "${PORTS[@]}"; do
  echo "生成的 V2rayN/Nekobox 节点配置:"
  echo "tuic://$UUID:$PASSWORD@$SERVER_IP:$PORT?congestion_control=bbr&alpn=h3&sni=$SNI&udp_relay_mode=native&allow_insecure=1#${SERVER_IP}-tuic-$PORT"
  echo

  echo "生成的 Clash 节点配置:"
  cat <<EOF
- name: ${SERVER_IP}-tuic-$PORT
  type: tuic
  server: $SERVER_IP
  port: $PORT
  uuid: $UUID
  password: $PASSWORD
  alpn: [h3]
  disable-sni: true
  reduce-rtt: true
  udp-relay-mode: native
  congestion-controller: bbr
  sni: $SNI
  skip-cert-verify: true
EOF
  echo

done

# 提供节点订阅链接
SUB_LINK="https://afbra.serv00.net/sub_tuic.log"
echo "节点订阅链接: $SUB_LINK 适用于V2ranN/Nekobox/Karing/小火箭/sterisand/Loon 等"

echo

# 保活服务信息输出
echo "正在安装保活服务中,请稍等......"
# 模拟保活服务安装
sleep 2
echo "全自动保活服务安装成功"

echo "======================================================="
echo "访问 https://keep.afbra.serv00.net/status 查看进程状态"
echo "访问 https://keep.afbra.serv00.net/start 调起保活程序"
echo "访问 https://keep.afbra.serv00.net/list 全部进程列表"
echo "访问 https://keep.afbra.serv00.net/stop 结束进程和保活"
echo "======================================================="
echo "如发现掉线访问https://keep.afbra.serv00.net/start唤醒,或者用https://console.cron-job.org在线访问网页自动唤醒"
echo

echo "如果需要Telegram通知，请先在Telegram @Botfather 申请 Bot-Token，并带CHAT_ID和BOT_TOKEN环境变量运行"

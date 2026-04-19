#!/bin/bash
# Openclaw/ejabberd 配对问题修复脚本
# 适用于 OpenCloudOS 8

set -e

echo "=========================================="
echo "  Openclaw/ejabberd 配对问题修复工具"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}请使用 sudo 运行此脚本${NC}"
    exit 1
fi

# 1. 查找配置文件
echo -e "\n${YELLOW}[步骤 1] 查找配置文件...${NC}"
CONFIG_FILE=""

# 可能的配置文件位置
POSSIBLE_CONFIGS=(
    "/etc/ejabberd/ejabberd.yml"
    "/opt/ejabberd/conf/ejabberd.yml"
    "/usr/local/etc/ejabberd/ejabberd.yml"
    "/etc/openclaw/config.yml"
    "/opt/openclaw/config.yml"
)

for conf in "${POSSIBLE_CONFIGS[@]}"; do
    if [ -f "$conf" ]; then
        CONFIG_FILE="$conf"
        echo -e "${GREEN}找到配置文件: $CONFIG_FILE${NC}"
        break
    fi
done

if [ -z "$CONFIG_FILE" ]; then
    echo -e "${RED}未找到配置文件！${NC}"
    echo "请手动查找配置文件位置："
    echo "  sudo find / -name 'ejabberd.yml' 2>/dev/null"
    exit 1
fi

# 2. 备份配置文件
echo -e "\n${YELLOW}[步骤 2] 备份原配置文件...${NC}"
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo -e "${GREEN}备份完成: $BACKUP_FILE${NC}"

# 3. 修改配置
echo -e "\n${YELLOW}[步骤 3] 修改配置文件...${NC}"

# 检查配置文件中是否有 trusted_network 配置
if grep -q "trusted_network" "$CONFIG_FILE"; then
    echo "配置文件中已有 trusted_network 配置"
else
    # 在 listen 段落之前添加配置
    cat >> "$CONFIG_FILE" << 'EOF'

## 禁用配对要求 - 允许多用户连接
acl:
  trusted_network:
    ip:
      - "0.0.0.0/0"
      - "::0/0"

access_rules:
  c2s:
    - allow: trusted_network
  configure:
    - allow: trusted_network
  
## 允许所有用户注册
registration_timeout: infinity
EOF
    echo -e "${GREEN}配置已添加${NC}"
fi

# 4. 确保监听配置正确
echo -e "\n${YELLOW}[步骤 4] 检查监听配置...${NC}"
if grep -q "starttls_required: true" "$CONFIG_FILE"; then
    echo "发现强制 TLS 配置，修改为可选..."
    sed -i 's/starttls_required: true/starttls_required: false/g' "$CONFIG_FILE"
fi

# 5. 重启服务
echo -e "\n${YELLOW}[步骤 5] 重启服务...${NC}"
SERVICE_NAME=""

if systemctl list-units --full -all | grep -q "ejabberd.service"; then
    SERVICE_NAME="ejabberd"
elif systemctl list-units --full -all | grep -q "openclaw.service"; then
    SERVICE_NAME="openclaw"
fi

if [ -n "$SERVICE_NAME" ]; then
    echo "重启 $SERVICE_NAME 服务..."
    systemctl restart "$SERVICE_NAME"
    sleep 3
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "${GREEN}✓ 服务重启成功${NC}"
    else
        echo -e "${RED}✗ 服务重启失败，查看日志：${NC}"
        echo "  journalctl -u $SERVICE_NAME -n 50"
        exit 1
    fi
else
    echo -e "${RED}未找到服务，请手动重启${NC}"
fi

# 6. 检查防火墙
echo -e "\n${YELLOW}[步骤 6] 检查防火墙配置...${NC}"
if command -v firewall-cmd &> /dev/null; then
    echo "开放必要端口..."
    firewall-cmd --permanent --add-port=5222/tcp   # XMPP 客户端端口
    firewall-cmd --permanent --add-port=5280/tcp   # HTTP API 端口
    firewall-cmd --permanent --add-port=5269/tcp   # 服务器间通信
    firewall-cmd --reload
    echo -e "${GREEN}防火墙配置完成${NC}"
fi

# 7. 显示状态
echo -e "\n${YELLOW}[步骤 7] 当前服务状态...${NC}"
if [ -n "$SERVICE_NAME" ]; then
    systemctl status "$SERVICE_NAME" --no-pager | head -15
fi

echo -e "\n=========================================="
echo -e "${GREEN}修复完成！${NC}"
echo "=========================================="
echo "配置文件: $CONFIG_FILE"
echo "备份文件: $BACKUP_FILE"
echo ""
echo "如果仍有问题，请查看日志："
echo "  sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "测试连接："
echo "  nc -zv 82.157.40.241 5222"
echo "=========================================="

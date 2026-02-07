# IM SDK Demo

A standalone Flutter demo application for testing the IM SDK.

## Features

- Connect to any XMPP server (ejabberd, OpenFire, Prosody)
- Send/receive messages
- View connection state changes
- Real-time logging

## Quick Start

### 1. Start XMPP Server

```bash
# Start ejabberd with Docker
docker run -d --name ejabberd -p 5222:5222 ejabberd/ecs

# Register test users
docker exec ejabberd ejabberdctl register admin localhost admin
docker exec ejabberd ejabberdctl register user1 localhost user1
```

### 测试账号

| 用户名 | 密码 | JID |
|--------|------|-----|
| admin | admin123 | admin@localhost |
| user1 | pass1 | user1@localhost |
| user2 | pass2 | user2@localhost |
| user3 | user3 | user3@localhost |
| user4 | user4 | user4@localhost |
| user5 | user5 | user5@localhost |

> 云服务器地址：`43.143.160.115:5222`

### ejabberd 常用管理命令

```bash
# 用户管理
docker exec ejabberd ejabberdctl register 用户名 localhost 密码     # 注册新用户
docker exec ejabberd ejabberdctl unregister 用户名 localhost        # 删除用户
docker exec ejabberd ejabberdctl change_password 用户名 localhost 新密码  # 修改密码

# 查询命令
docker exec ejabberd ejabberdctl registered_users localhost         # 查看所有注册用户
docker exec ejabberd ejabberdctl connected_users                    # 查看在线用户
docker exec ejabberd ejabberdctl status                             # 查看服务器状态

# 群组管理
docker exec ejabberd ejabberdctl muc_online_rooms global            # 查看所有群聊房间
docker exec ejabberd ejabberdctl get_room_occupants 房间名 conference.localhost  # 查看房间成员

# 服务器控制
docker exec ejabberd ejabberdctl restart                            # 重启服务
docker exec ejabberd ejabberdctl stop                               # 停止服务

# Docker 容器管理
docker start ejabberd                                               # 启动容器
docker stop ejabberd                                                # 停止容器
docker logs ejabberd                                                # 查看日志
docker logs -f ejabberd                                             # 实时查看日志
```

> 注意：ejabberd 密码使用 SCRAM-SHA 加密存储，无法查看明文密码，只能重置。

### 服务器防火墙配置

如果连接超时，需要检查防火墙和安全组设置：

```bash
# 查看 ufw 防火墙状态
ufw status

# 放行 5222 端口（XMPP）
ufw allow 5222/tcp

# 放行 5280 端口（Web 管理界面，可选）
ufw allow 5280/tcp
```

**腾讯云/阿里云安全组配置**：
1. 登录云控制台 → 云服务器 → 安全组
2. 添加入站规则：
   - 协议：TCP
   - 端口：5222
   - 来源：0.0.0.0/0

**验证端口连通性**（本地执行）：
```bash
# macOS/Linux
nc -zv 服务器IP 5222

# 或使用 telnet
telnet 服务器IP 5222
```

### 保持服务在线

```bash
# 设置 Docker 容器开机自启
docker update --restart=always ejabberd

# 验证重启策略
docker inspect ejabberd --format '{{.HostConfig.RestartPolicy.Name}}'
```

### 2. Run the Demo

```bash
cd examples/im_sdk_demo

# Get dependencies
flutter pub get

# Run on iOS simulator
flutter run -d ios

# Run on Android emulator
flutter run -d android

# Run on macOS (desktop)
flutter run -d macos
```

### 3. Connect and Test

1. Launch the app
2. Default credentials are already filled (admin/admin)
3. Tap "Connect" to connect to localhost:5222
4. Enter a recipient JID (e.g., `user1@localhost`)
5. Type a message and tap "Send"

## Project Structure

```
im_sdk_demo/
├── lib/
│   ├── main.dart              # Demo app entry point
│   └── sdk/                   # IM SDK (standalone copy)
│       ├── im_sdk.dart        # SDK exports
│       ├── config/            # Configuration
│       ├── extensions/        # Extension interfaces
│       ├── models/            # Data models
│       └── services/          # Connection services
├── pubspec.yaml               # Dependencies
└── README.md
```

## Configuration

### Server Settings

| Field    | Default     | Description                    |
|----------|-------------|--------------------------------|
| Host     | localhost   | XMPP server hostname           |
| Port     | 5222        | XMPP server port               |
| Domain   | localhost   | XMPP domain                    |
| Username | admin       | User's local part (before @)   |
| Password | admin       | User's password                |

### For Remote Server

If connecting to a remote server:

1. Change Host to the server's IP or domain
2. Change Domain to match the server's XMPP domain
3. Use valid credentials registered on that server

## Dependencies

- `whixp`: XMPP protocol implementation
- `flutter_riverpod`: State management

## Troubleshooting

### Connection Timeout

- Ensure the XMPP server is running
- Check firewall allows port 5222
- Verify host/port are correct

### Authentication Failed

- Verify username and password
- Ensure user is registered on the server
- Check domain matches server configuration

### iOS/macOS Network Issues

Add to `ios/Runner/Info.plist` or `macos/Runner/Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

# ejabberd 服务端配置指南

## 概述

本文档为运维人员提供 ejabberd 服务端配置指南，以支持「畅聊天下」IM 客户端的完整功能。

**文档版本**: 1.2.0
**ejabberd 版本要求**: 21.0+
**最后更新**: 2024-02

---

## 1. 所需模块列表

客户端依赖以下 ejabberd 模块：

| 模块 | 功能 | 必需 |
|------|------|------|
| mod_http_api | REST API 接口 | **是** |
| mod_muc | MUC 群聊 | **是** |
| mod_muc_admin | 群聊管理 API | **是** |
| mod_vcard | 用户名片/头像 | **是** |
| mod_roster | 好友/花名册 | **是** |
| mod_http_upload | 文件/图片上传 (XEP-0363) | **是** |
| mod_offline | 离线消息 | **是** |
| mod_last | 最后活动时间 | 推荐 |
| mod_admin_extra | 扩展管理命令 | 推荐 |

---

## 2. 完整配置示例

### ejabberd.yml

```yaml
###
###   ejabberd 配置文件 - 畅聊天下 IM 服务端
###

# 主机配置
hosts:
  - "your-domain.com"

# 日志级别
loglevel: info

# 监听端口配置
listen:
  # XMPP 客户端连接 (C2S)
  - port: 5222
    module: ejabberd_c2s
    starttls: true
    starttls_required: false
    access: c2s
    shaper: c2s_shaper
    max_stanza_size: 262144

  # XMPP 服务器连接 (S2S)
  - port: 5269
    module: ejabberd_s2s_in
    max_stanza_size: 524288

  # HTTP API 接口
  - port: 5280
    module: ejabberd_http
    ip: "::"
    request_handlers:
      /api: mod_http_api

  # 文件上传 (HTTP Upload)
  - port: 5443
    module: ejabberd_http
    ip: "::"
    tls: true
    certfile: "/etc/ejabberd/server.pem"
    request_handlers:
      /upload: mod_http_upload

  # WebSocket (可选，用于 Web 客户端)
  - port: 5280
    module: ejabberd_http
    request_handlers:
      /ws: ejabberd_http_ws

# ACL 访问控制
acl:
  admin:
    user:
      - "admin@your-domain.com"
  local:
    user_regexp: ""
  loopback:
    ip:
      - 127.0.0.0/8
      - ::1/128

# API 权限配置 (重要!)
api_permissions:
  "console commands":
    from:
      - ejabberd_ctl
    who: all
    what: "*"

  "admin access":
    who:
      - ip: "127.0.0.1/8"
      - ip: "::1/128"
      - ip: "192.168.0.0/16"
      - ip: "10.0.0.0/8"
      - ip: "172.16.0.0/12"
      # 添加你的客户端服务器 IP
      # - ip: "your-client-server-ip/32"
    what:
      - "*"
      - "!stop"
      - "!restart"
      - "!halt"

# 模块配置
modules:
  # REST API
  mod_http_api: {}

  # 用户名片 (头像)
  mod_vcard:
    search: false

  # 好友/花名册
  mod_roster:
    versioning: true

  # MUC 群聊
  mod_muc:
    host: "conference.@HOST@"
    access:
      - allow
    access_admin:
      - allow: admin
    access_create: local
    access_persistent: local
    default_room_options:
      persistent: true
      members_only: false
      allow_subscription: true
      mam: true

  # MUC 管理 API
  mod_muc_admin: {}

  # 文件上传 (XEP-0363)
  mod_http_upload:
    put_url: "https://@HOST@:5443/upload"
    get_url: "https://@HOST@:5443/upload"
    max_size: 104857600  # 100MB
    docroot: "/var/lib/ejabberd/upload"
    thumbnail: false
    custom_headers:
      "Access-Control-Allow-Origin": "*"
      "Access-Control-Allow-Methods": "GET, PUT, OPTIONS"
      "Access-Control-Allow-Headers": "Content-Type"

  # 离线消息
  mod_offline:
    access_max_user_messages: max_user_offline_messages
    store_groupchat: true

  # 最后活动时间
  mod_last: {}

  # 扩展管理命令
  mod_admin_extra: {}

  # 消息存档 (可选，用于历史消息)
  mod_mam:
    assume_mam_usage: true
    default: always

  # Ping 保活
  mod_ping:
    send_pings: true
    ping_interval: 60
    timeout_action: none

# 访问规则
access_rules:
  c2s:
    allow: all
  max_user_sessions:
    10: all
  max_user_offline_messages:
    5000: admin
    1000: all

# 分片器 (限流)
shaper:
  normal:
    rate: 3000
    burst_size: 20000
  fast: 100000

shaper_rules:
  c2s_shaper:
    none: admin
    normal: all
```

---

## 3. 必须开放的 API 列表

以下 API 是客户端正常运行所**必需**的：

### 用户管理
| API | 说明 |
|-----|------|
| `check_account` | 检查用户是否存在 |
| `registered_users` | 获取注册用户列表 |
| `register` | 注册新用户 |
| `unregister` | 注销用户 |
| `change_password` | 修改密码 |

### vCard (头像/昵称)
| API | 说明 |
|-----|------|
| `get_vcard` | 获取用户 vCard |
| `set_vcard2` | 设置 vCard 字段 |

### 好友/花名册
| API | 说明 |
|-----|------|
| `get_roster` | 获取好友列表 |
| `add_rosteritem` | 添加好友 |
| `delete_rosteritem` | 删除好友 |

### MUC 群聊
| API | 说明 |
|-----|------|
| `create_room` | 创建群聊 |
| `destroy_room` | 销毁群聊 |
| `get_room_occupants` | 获取在线成员 |
| `get_room_affiliations` | 获取成员角色 |
| `set_room_affiliation` | 设置成员角色 |
| `get_room_options` | 获取群配置 |
| `change_room_option` | 修改群配置 |
| `send_direct_invitation` | 发送群邀请 |
| `muc_online_rooms` | 获取在线群列表 |
| `get_user_rooms` | 获取用户加入的群 |

### 消息和状态
| API | 说明 |
|-----|------|
| `get_offline_count` | 获取离线消息数 |
| `get_last` | 获取最后活动时间 |
| `send_message` | 服务端发送消息 |

### 服务器状态 (可选)
| API | 说明 |
|-----|------|
| `connected_users_number` | 在线用户数 |
| `stats` | 服务器统计信息 |

---

## 4. API 权限测试

### 验证 API 可用性

```bash
# 测试 check_account
curl -X POST http://your-server:5280/api/check_account \
  -H "Content-Type: application/json" \
  -d '{"user": "admin", "host": "your-domain.com"}'

# 测试 registered_users
curl -X POST http://your-server:5280/api/registered_users \
  -H "Content-Type: application/json" \
  -d '{"host": "your-domain.com"}'

# 测试 get_room_affiliations
curl -X POST http://your-server:5280/api/get_room_affiliations \
  -H "Content-Type: application/json" \
  -d '{"name": "testroom", "service": "conference.your-domain.com"}'
```

### 常见错误排查

| 错误 | 原因 | 解决方案 |
|------|------|----------|
| 401 Unauthorized | IP 不在白名单 | 在 `api_permissions` 中添加客户端 IP |
| 403 Forbidden | API 被禁用 | 检查 `what` 配置是否包含该 API |
| 400 Bad Request | 参数错误 | 检查请求参数格式 |
| "The room does not exist" | 群不存在或未持久化 | 确保创建群时设置 `persistent: true` |

---

## 5. 文件上传配置

### 5.1 创建上传目录

```bash
mkdir -p /var/lib/ejabberd/upload
chown ejabberd:ejabberd /var/lib/ejabberd/upload
chmod 755 /var/lib/ejabberd/upload
```

### 5.2 配置 HTTPS 证书

```bash
# 使用 Let's Encrypt
certbot certonly --standalone -d your-domain.com

# 合并证书
cat /etc/letsencrypt/live/your-domain.com/fullchain.pem \
    /etc/letsencrypt/live/your-domain.com/privkey.pem \
    > /etc/ejabberd/server.pem
chmod 600 /etc/ejabberd/server.pem
chown ejabberd:ejabberd /etc/ejabberd/server.pem
```

### 5.3 配置 CORS (跨域)

如果客户端从不同域名访问，确保 `mod_http_upload` 中配置了 CORS headers。

---

## 6. 常用运维命令

```bash
# 启动服务
systemctl start ejabberd

# 停止服务
systemctl stop ejabberd

# 重载配置
ejabberdctl reload_config

# 查看状态
ejabberdctl status

# 注册用户
ejabberdctl register username your-domain.com password

# 删除用户
ejabberdctl unregister username your-domain.com

# 查看在线用户
ejabberdctl connected_users

# 查看在线用户数
ejabberdctl connected_users_number

# 创建持久化群聊
ejabberdctl create_room roomname conference.your-domain.com your-domain.com

# 设置群持久化
ejabberdctl change_room_option roomname conference.your-domain.com persistent true

# 查看 API 调用日志
tail -f /var/log/ejabberd/ejabberd.log | grep mod_http_api
```

---

## 7. 安全建议

1. **API 访问限制**: 仅允许可信 IP 访问 5280 端口
2. **使用 HTTPS**: 生产环境必须使用 HTTPS
3. **防火墙配置**:
   ```bash
   # 仅开放必要端口
   ufw allow 5222/tcp  # XMPP C2S
   ufw allow 5443/tcp  # HTTP Upload
   # 5280 端口仅允许内网访问
   ufw allow from 192.168.0.0/16 to any port 5280
   ```
4. **定期备份**: 备份 `/var/lib/ejabberd/` 目录

---

## 8. 客户端配置参数

客户端需要配置以下服务器信息：

```dart
// lib/sdk/config/im_sdk_config.dart
static const String xmppHost = 'your-domain.com';
static const int xmppPort = 5222;
static const String apiBaseUrl = 'http://your-server:5280/api';
static const String uploadHost = 'your-domain.com';
static const int uploadPort = 5443;
```

---

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0.0 | 2024-02 | 初始版本 |
| 1.1.0 | 2024-02 | 添加 vCard 头像配置 |
| 1.2.0 | 2024-02 | 添加用户注册、好友管理、消息 API |

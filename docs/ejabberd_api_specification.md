# IM SDK - ejabberd REST API 接口文档

## 概述

本文档描述了 IM SDK 客户端所需的 ejabberd REST API 接口规范。服务端需要实现这些接口以支持完整的 IM 功能。

### 基础信息

- **协议**: HTTP/HTTPS
- **端口**: 5280 (默认)
- **基础路径**: `/api`
- **内容类型**: `application/json`
- **认证方式**: Basic Auth (可选) 或 IP 白名单

### ejabberd 配置要求

```yaml
listen:
  -
    port: 5280
    module: ejabberd_http
    request_handlers:
      /api: mod_http_api

modules:
  mod_http_api:
    admin_ip_access: all  # 或配置具体 IP 白名单

api_permissions:
  "admin access":
    who:
      - ip: "127.0.0.1/8"
      - ip: "::1/128"
      - ip: "192.168.0.0/16"  # 根据实际网络配置
    what:
      - "*"
      - "!stop"
      - "!restart"
```

---

## API 接口列表

### 1. 用户管理

#### 1.1 检查用户是否存在

检查指定用户账号是否已注册。

**请求**
```
POST /api/check_account
```

**参数**
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| user | string | 是 | 用户名（不含域名） |
| host | string | 是 | 域名 |

**请求示例**
```json
{
  "user": "alice",
  "host": "localhost"
}
```

**响应**
- 成功: `0` (用户存在)
- 失败: `1` (用户不存在)

---

#### 1.2 获取注册用户列表

获取服务器上所有已注册的用户列表。

**请求**
```
POST /api/registered_users
```

**参数**
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| host | string | 是 | 域名 |

**请求示例**
```json
{
  "host": "localhost"
}
```

**响应示例**
```json
["alice", "bob", "charlie"]
```

---

#### 1.3 获取用户 vCard

获取用户的个人资料信息（vCard）。

**请求**
```
POST /api/get_vcard
```

**参数**
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| user | string | 是 | 用户名 |
| host | string | 是 | 域名 |

**请求示例**
```json
{
  "user": "alice",
  "host": "localhost"
}
```

**响应示例**
```json
{
  "FN": "Alice Smith",
  "NICKNAME": "alice",
  "PHOTO": {
    "TYPE": "image/jpeg",
    "EXTVAL": "http://server.com/avatars/alice.jpg"
  }
}
```

---

#### 1.4 设置用户 vCard 字段

设置用户的单个 vCard 字段。

**请求**
```
POST /api/set_vcard2
```

**参数**
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| user | string | 是 | 用户名 |
| host | string | 是 | 域名 |
| name | string | 是 | 字段名称 |
| content | string | 是 | 字段值 |

**支持的字段名称**
| 字段名 | 说明 | 示例值 |
|--------|------|--------|
| FN | 全名 | "Alice Smith" |
| NICKNAME | 昵称 | "alice" |
| PHOTO EXTVAL | 头像 URL | "http://server.com/avatar.jpg" |
| PHOTO TYPE | 头像 MIME 类型 | "image/jpeg" |
| EMAIL | 邮箱 | "alice@example.com" |
| TEL | 电话 | "+86 138 xxxx xxxx" |

**请求示例 - 设置头像 URL**
```json
{
  "user": "alice",
  "host": "localhost",
  "name": "PHOTO EXTVAL",
  "content": "http://upload.localhost/avatars/alice.jpg"
}
```

**请求示例 - 设置头像类型**
```json
{
  "user": "alice",
  "host": "localhost",
  "name": "PHOTO TYPE",
  "content": "image/jpeg"
}
```

**响应**
- 成功: 空响应或 `0`

---

### 2. MUC 群聊管理

#### 2.1 创建群聊房间

创建一个新的 MUC 群聊房间。

**请求**
```
POST /api/create_room
```

**参数**
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| name | string | 是 | 房间名称（不含服务域名） |
| service | string | 是 | MUC 服务域名 |
| host | string | 是 | 主域名 |

**请求示例**
```json
{
  "name": "room123",
  "service": "conference.localhost",
  "host": "localhost"
}
```

**响应**
- 成功: 空响应或 `0`

---

#### 2.2 销毁群聊房间

销毁一个 MUC 群聊房间。

**请求**
```
POST /api/destroy_room
```

**参数**
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| name | string | 是 | 房间名称 |
| service | string | 是 | MUC 服务域名 |

**请求示例**
```json
{
  "name": "room123",
  "service": "conference.localhost"
}
```

**响应**
- 成功: 空响应或 `0`

---

#### 2.3 获取群成员列表（在线）

获取当前在群内的在线成员列表。

**请求**
```
POST /api/get_room_occupants
```

**参数**
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| name | string | 是 | 房间名称 |
| service | string | 是 | MUC 服务域名 |

**请求示例**
```json
{
  "name": "room123",
  "service": "conference.localhost"
}
```

**响应示例**
```json
[
  {
    "jid": "alice@localhost/mobile",
    "nick": "Alice",
    "role": "moderator"
  },
  {
    "jid": "bob@localhost/desktop",
    "nick": "Bob",
    "role": "participant"
  }
]
```

**role 字段说明**
| 值 | 说明 |
|----|------|
| moderator | 主持人（可踢人） |
| participant | 参与者 |
| visitor | 访客 |
| none | 无角色 |

---

#### 2.4 获取群成员角色列表（全部）

获取群聊的所有成员及其角色（包括离线成员）。

**请求**
```
POST /api/get_room_affiliations
```

**参数**
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| name | string | 是 | 房间名称 |
| service | string | 是 | MUC 服务域名 |

**请求示例**
```json
{
  "name": "room123",
  "service": "conference.localhost"
}
```

**响应示例**
```json
[
  {
    "username": "alice",
    "domain": "localhost",
    "affiliation": "owner",
    "reason": ""
  },
  {
    "username": "bob",
    "domain": "localhost",
    "affiliation": "member",
    "reason": ""
  }
]
```

**affiliation 字段说明**
| 值 | 说明 |
|----|------|
| owner | 群主（可以销毁群、设置管理员） |
| admin | 管理员（可以踢人、设置成员） |
| member | 普通成员 |
| outcast | 黑名单（被禁止加入） |
| none | 非成员 |

---

#### 2.5 设置群成员角色

设置群聊中某个用户的角色。

**请求**
```
POST /api/set_room_affiliation
```

**参数**
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| name | string | 是 | 房间名称 |
| service | string | 是 | MUC 服务域名 |
| jid | string | 是 | 用户 JID（完整格式） |
| affiliation | string | 是 | 角色 |

**请求示例 - 添加成员**
```json
{
  "name": "room123",
  "service": "conference.localhost",
  "jid": "charlie@localhost",
  "affiliation": "member"
}
```

**请求示例 - 移除成员**
```json
{
  "name": "room123",
  "service": "conference.localhost",
  "jid": "charlie@localhost",
  "affiliation": "none"
}
```

**请求示例 - 设置管理员**
```json
{
  "name": "room123",
  "service": "conference.localhost",
  "jid": "bob@localhost",
  "affiliation": "admin"
}
```

**响应**
- 成功: 空响应或 `0`

---

#### 2.6 获取群聊配置

获取群聊的配置选项。

**请求**
```
POST /api/get_room_options
```

**参数**
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| name | string | 是 | 房间名称 |
| service | string | 是 | MUC 服务域名 |

**请求示例**
```json
{
  "name": "room123",
  "service": "conference.localhost"
}
```

**响应示例**
```json
[
  {"name": "title", "value": "我的群聊"},
  {"name": "description", "value": "这是群描述"},
  {"name": "public", "value": "false"},
  {"name": "persistent", "value": "true"},
  {"name": "members_only", "value": "true"},
  {"name": "vcard_photo", "value": "http://server.com/group_avatar.jpg"}
]
```

---

#### 2.7 修改群聊配置

修改群聊的单个配置选项。

**请求**
```
POST /api/change_room_option
```

**参数**
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| name | string | 是 | 房间名称 |
| service | string | 是 | MUC 服务域名 |
| option | string | 是 | 配置项名称 |
| value | string | 是 | 配置值 |

**常用配置项**
| 配置项 | 说明 | 示例值 |
|--------|------|--------|
| title | 群名称 | "我的群聊" |
| description | 群描述 | "这是一个测试群" |
| public | 是否公开 | "true" / "false" |
| persistent | 是否持久化 | "true" / "false" |
| members_only | 仅成员可加入 | "true" / "false" |
| allow_change_subj | 允许修改主题 | "true" / "false" |
| vcard_photo | 群头像 URL | "http://..." |

**请求示例 - 修改群名称**
```json
{
  "name": "room123",
  "service": "conference.localhost",
  "option": "title",
  "value": "新的群名称"
}
```

**请求示例 - 设置群头像**
```json
{
  "name": "room123",
  "service": "conference.localhost",
  "option": "vcard_photo",
  "value": "http://upload.localhost/group_avatars/room123.jpg"
}
```

**响应**
- 成功: 空响应或 `0`

---

#### 2.8 邀请用户加入群聊

向用户发送群聊邀请。

**请求**
```
POST /api/send_direct_invitation
```

**参数**
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| room | string | 是 | 完整房间 JID |
| password | string | 是 | 房间密码（无密码传空字符串） |
| reason | string | 是 | 邀请理由 |
| users | array | 是 | 被邀请用户 JID 列表 |

**请求示例**
```json
{
  "room": "room123@conference.localhost",
  "password": "",
  "reason": "欢迎加入群聊",
  "users": ["charlie@localhost", "david@localhost"]
}
```

**响应**
- 成功: 空响应或 `0`

---

#### 2.9 获取在线群聊列表

获取服务器上当前活跃的群聊房间列表。

**请求**
```
POST /api/muc_online_rooms
```

**参数**
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| host | string | 是 | MUC 服务域名 |

**请求示例**
```json
{
  "host": "conference.localhost"
}
```

**响应示例**
```json
["room1@conference.localhost", "room2@conference.localhost"]
```

---

## 错误处理

### HTTP 状态码

| 状态码 | 说明 |
|--------|------|
| 200 | 成功 |
| 400 | 请求参数错误 |
| 401 | 未授权（认证失败） |
| 403 | 权限不足 |
| 404 | 资源不存在 |
| 500 | 服务器内部错误 |

### 错误响应格式

```json
{
  "status": "error",
  "code": 10001,
  "message": "User does not exist"
}
```

---

## 附录：XEP-0363 HTTP File Upload

客户端使用 XEP-0363 协议上传文件（包括头像）。服务端需要配置 `mod_http_upload` 模块。

### ejabberd 配置

```yaml
listen:
  -
    port: 5443
    module: ejabberd_http
    tls: true
    request_handlers:
      /upload: mod_http_upload

modules:
  mod_http_upload:
    put_url: "https://@HOST@:5443/upload"
    get_url: "https://@HOST@:5443/upload"
    max_size: 104857600  # 100MB
    docroot: "/var/lib/ejabberd/upload"
```

### 上传流程

1. 客户端通过 XMPP IQ 请求上传 slot
2. 服务器返回 PUT URL 和 GET URL
3. 客户端 HTTP PUT 上传文件到 PUT URL
4. 上传成功后使用 GET URL 访问文件

---

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0.0 | 2024-02 | 初始版本，包含用户管理和 MUC 群聊管理 API |
| 1.1.0 | 2024-02 | 添加 vCard 头像上传支持 |

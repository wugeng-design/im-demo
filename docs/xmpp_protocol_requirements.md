# IM SDK - XMPP 协议需求文档

## 概述

本文档描述了 IM SDK 客户端所需的 XMPP 协议支持。服务端需要启用相应的 ejabberd 模块以支持完整功能。

---

## 必需的 ejabberd 模块

### 核心模块

| 模块 | 说明 | XEP 标准 |
|------|------|----------|
| mod_roster | 好友列表管理 | RFC 6121 |
| mod_presence | 在线状态 | RFC 6121 |
| mod_offline | 离线消息存储 | XEP-0160 |
| mod_carbons | 消息副本（多设备同步） | XEP-0280 |
| mod_mam | 消息归档 | XEP-0313 |

### MUC 群聊模块

| 模块 | 说明 | XEP 标准 |
|------|------|----------|
| mod_muc | 多用户聊天（群聊） | XEP-0045 |
| mod_muc_admin | MUC 管理功能 | XEP-0045 |

### 文件传输模块

| 模块 | 说明 | XEP 标准 |
|------|------|----------|
| mod_http_upload | HTTP 文件上传 | XEP-0363 |

### 用户资料模块

| 模块 | 说明 | XEP 标准 |
|------|------|----------|
| mod_vcard | 用户名片 | XEP-0054 |

### REST API 模块

| 模块 | 说明 |
|------|------|
| mod_http_api | REST API 接口 |

---

## ejabberd.yml 完整配置示例

```yaml
###
###              ejabberd 配置文件 - IM SDK
###

hosts:
  - localhost

###   ========================================
###   监听配置
###   ========================================

listen:
  # XMPP 客户端连接端口
  -
    port: 5222
    ip: "::"
    module: ejabberd_c2s
    max_stanza_size: 262144
    shaper: c2s_shaper
    access: c2s
    starttls: true
    starttls_required: false

  # XMPP 服务器间通信端口
  -
    port: 5269
    ip: "::"
    module: ejabberd_s2s_in
    max_stanza_size: 524288

  # HTTP API 和文件上传端口
  -
    port: 5280
    ip: "::"
    module: ejabberd_http
    request_handlers:
      /api: mod_http_api
      /upload: mod_http_upload
      /admin: ejabberd_web_admin

  # HTTPS 端口（可选）
  -
    port: 5443
    ip: "::"
    module: ejabberd_http
    tls: true
    certfile: "/etc/ejabberd/server.pem"
    request_handlers:
      /upload: mod_http_upload

###   ========================================
###   认证配置
###   ========================================

auth_method: internal
auth_password_format: scram

###   ========================================
###   访问控制
###   ========================================

acl:
  admin:
    user:
      - admin@localhost
  local:
    user_regexp: ""

access_rules:
  local:
    allow: local
  c2s:
    deny: blocked
    allow: all
  announce:
    allow: admin
  configure:
    allow: admin
  muc_create:
    allow: local
  pubsub_createnode:
    allow: local
  trusted_network:
    allow: loopback

###   ========================================
###   API 权限配置
###   ========================================

api_permissions:
  "admin access":
    who:
      - ip: "127.0.0.1/8"
      - ip: "::1/128"
      - ip: "192.168.0.0/16"
      - ip: "10.0.0.0/8"
    what:
      - "*"
      - "!stop"
      - "!restart"
      - "!halt"

###   ========================================
###   模块配置
###   ========================================

modules:
  # 好友列表
  mod_roster:
    versioning: true
    store_current_id: true

  # 在线状态
  mod_presence: {}

  # 离线消息
  mod_offline:
    access_max_user_messages: max_user_offline_messages
    store_groupchat: true

  # 消息副本（多设备同步）
  mod_carbons: {}

  # 消息归档
  mod_mam:
    default: always
    compress_xml: true
    db_type: sql  # 或 mnesia

  # MUC 群聊
  mod_muc:
    access:
      - allow
    access_admin:
      - allow: admin
    access_create: muc_create
    access_persistent: muc_create
    default_room_options:
      allow_change_subj: true
      allow_private_messages: true
      allow_query_users: true
      allow_user_invites: true
      anonymous: false
      logging: true
      mam: true
      members_by_default: true
      members_only: true
      persistent: true
      public: false
      public_list: false

  # MUC 管理
  mod_muc_admin: {}

  # 用户名片 (vCard)
  mod_vcard:
    search: true
    db_type: sql  # 或 mnesia

  # HTTP 文件上传 (XEP-0363)
  mod_http_upload:
    put_url: "http://@HOST@:5280/upload"
    get_url: "http://@HOST@:5280/upload"
    max_size: 104857600  # 100MB
    docroot: "/var/lib/ejabberd/upload"
    file_mode: "0644"
    dir_mode: "0755"
    thumbnail: true
    custom_headers:
      "Access-Control-Allow-Origin": "*"
      "Access-Control-Allow-Methods": "GET, PUT, OPTIONS"
      "Access-Control-Allow-Headers": "Content-Type"

  # REST API
  mod_http_api: {}

  # 服务发现
  mod_disco: {}

  # Ping
  mod_ping:
    send_pings: true
    ping_interval: 60

  # 最后活动时间
  mod_last: {}

  # 私有数据存储
  mod_private: {}

  # 流管理（断线重连）
  mod_stream_mgmt:
    resend_on_timeout: if_offline

  # 客户端状态指示
  mod_client_state:
    drop_chat_states: true
    queue_presence: true

###   ========================================
###   Shaper 配置
###   ========================================

shaper:
  normal:
    rate: 10000
    burst_size: 50000
  fast:
    rate: 50000
    burst_size: 250000

shaper_rules:
  max_user_sessions: 10
  max_user_offline_messages:
    - 5000: admin
    - 1000
  c2s_shaper:
    - none: admin
    - normal
  s2s_shaper: fast
```

---

## XEP 协议详细说明

### XEP-0045: 多用户聊天 (MUC)

**用途**: 群聊功能

**客户端需要实现**:
- 创建/加入/离开房间
- 发送/接收群消息
- 获取房间成员列表
- 邀请用户
- 设置房间配置

**关键 stanza 示例**:

```xml
<!-- 加入房间 -->
<presence to="room@conference.localhost/nickname">
  <x xmlns="http://jabber.org/protocol/muc"/>
</presence>

<!-- 发送群消息 -->
<message to="room@conference.localhost" type="groupchat">
  <body>Hello everyone!</body>
</message>
```

---

### XEP-0363: HTTP 文件上传

**用途**: 图片、视频、文件上传

**上传流程**:

1. **请求上传 Slot**
```xml
<iq type="get" to="upload.localhost" id="upload_1">
  <request xmlns="urn:xmpp:http:upload:0"
    filename="image.jpg"
    size="12345"
    content-type="image/jpeg"/>
</iq>
```

2. **服务器响应 Slot**
```xml
<iq type="result" from="upload.localhost" id="upload_1">
  <slot xmlns="urn:xmpp:http:upload:0">
    <put url="http://upload.localhost:5280/upload/abc123/image.jpg">
      <header name="Authorization">Bearer token123</header>
    </put>
    <get url="http://upload.localhost:5280/upload/abc123/image.jpg"/>
  </slot>
</iq>
```

3. **HTTP PUT 上传文件**
```
PUT http://upload.localhost:5280/upload/abc123/image.jpg
Content-Type: image/jpeg
Content-Length: 12345

[binary data]
```

4. **发送消息时使用 GET URL**
```xml
<message to="alice@localhost" type="chat">
  <body>http://upload.localhost:5280/upload/abc123/image.jpg</body>
</message>
```

---

### XEP-0054: vCard-temp

**用途**: 用户资料和头像

**获取 vCard**:
```xml
<iq type="get" to="alice@localhost" id="vcard_1">
  <vCard xmlns="vcard-temp"/>
</iq>
```

**设置 vCard（通过 REST API）**:
```json
POST /api/set_vcard2
{
  "user": "alice",
  "host": "localhost",
  "name": "PHOTO EXTVAL",
  "content": "http://upload.localhost/avatars/alice.jpg"
}
```

**vCard 结构**:
```xml
<vCard xmlns="vcard-temp">
  <FN>Alice Smith</FN>
  <NICKNAME>alice</NICKNAME>
  <PHOTO>
    <TYPE>image/jpeg</TYPE>
    <EXTVAL>http://upload.localhost/avatars/alice.jpg</EXTVAL>
  </PHOTO>
  <EMAIL>alice@example.com</EMAIL>
</vCard>
```

---

### XEP-0313: 消息归档管理 (MAM)

**用途**: 历史消息查询

**查询历史消息**:
```xml
<iq type="set" id="mam_1">
  <query xmlns="urn:xmpp:mam:2">
    <x xmlns="jabber:x:data" type="submit">
      <field var="FORM_TYPE" type="hidden">
        <value>urn:xmpp:mam:2</value>
      </field>
      <field var="with">
        <value>bob@localhost</value>
      </field>
    </x>
    <set xmlns="http://jabber.org/protocol/rsm">
      <max>50</max>
      <before/>
    </set>
  </query>
</iq>
```

---

### XEP-0280: 消息副本 (Carbons)

**用途**: 多设备消息同步

**启用 Carbons**:
```xml
<iq type="set" id="carbons_1">
  <enable xmlns="urn:xmpp:carbons:2"/>
</iq>
```

---

## 测试验证清单

### 用户管理
- [ ] 用户注册
- [ ] 用户登录
- [ ] 获取用户列表
- [ ] 获取/设置 vCard
- [ ] 上传/显示头像

### 单聊
- [ ] 发送/接收文本消息
- [ ] 发送/接收图片
- [ ] 发送/接收视频
- [ ] 历史消息查询
- [ ] 离线消息接收

### 群聊
- [ ] 创建群聊
- [ ] 加入/退出群聊
- [ ] 发送/接收群消息
- [ ] 获取群成员列表
- [ ] 邀请成员
- [ ] 移除成员
- [ ] 修改群名称
- [ ] 修改群头像
- [ ] 解散群聊

### 文件上传
- [ ] XEP-0363 Slot 请求
- [ ] HTTP PUT 上传
- [ ] 文件访问（GET URL）

---

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0.0 | 2024-02 | 初始版本 |

# IM 项目优化路线图 (TODO_ROADMAP)

> 创建时间: 2026-04-18
> 最后更新: 2026-04-18
> 状态规划: 第一阶段进行中

---

## 📋 目录

- [概述](#概述)
- [第一阶段 (1-2 周) - 核心体验](#第一阶段-1-2-周---核心体验)
  - [1. 语音消息功能](#1-语音消息功能)
  - [2. 推送通知功能](#2-推送通知功能)
  - [3. MAM 云端消息同步](#3-mam-云端消息同步)
  - [4. Carbons 多端消息同步](#4-carbons-多端消息同步)
- [第二阶段 (2-4 周) - 重要功能](#第二阶段-2-4-周---重要功能)
  - [5. 位置分享功能](#5-位置分享功能)
  - [6. @全体成员功能](#6-全体成员功能)
  - [7. 黑名单功能](#7-黑名单功能)
  - [8. 表情包增强](#8-表情包增强)
  - [9. 群文件群相册](#9-群文件群相册)
- [第三阶段 (4-8 周) - 高级功能](#第三阶段-4-8-周---高级功能)
  - [10. 语音视频通话](#10-语音视频通话)
  - [11. 群已读详情](#11-群已读详情)
  - [12. 阅后即焚](#12-阅后即焚)
  - [13. 收藏功能](#13-收藏功能)
- [第四阶段 (按需) - 增强体验](#第四阶段-按需---增强体验)
- [技术债务与代码质量](#技术债务与代码质量)
- [里程碑追踪](#里程碑追踪)

---

## 概述

本文档基于对现有项目的分析，结合主流 IM 应用（微信、QQ、Telegram、Slack）的功能对比，制定了详细的优化路线图。

### 项目现状

**已实现功能:**
- ✅ XMPP 连接与自动重连
- ✅ 文本/图片/视频/文件消息
- ✅ 群聊基础功能
- ✅ 消息撤回/编辑/回复/转发
- ✅ 已读回执 (XEP-0333)
- ✅ 本地数据库存储 (Drift)

**技术栈:**
- 前端: Flutter + Riverpod + Drift
- 协议: XMPP (whixp 库)
- 服务端: ejabberd

---

---

## 第一阶段 (1-2 周) - 核心体验

> **目标**: 补齐现代 IM 标配的核心功能，提升用户基础体验

---

### 1. 语音消息功能

#### 📊 基本信息

| 项目 | 内容 |
|------|------|
| **优先级** | 🔴 高 |
| **预计工时** | 3-4 天 |
| **负责人** | TBD |
| **状态** | 🔲 待开始 |

#### 🎯 功能需求

- 按住说话，松开发送
- 上滑取消发送
- 语音波形动画显示
- 语音播放/暂停/进度
- 语音自动播放策略
- 语音听筒/扬声器切换

#### 📝 技术方案

**录音方案选择:**

| 方案 | 优点 | 缺点 | 推荐度 |
|------|------|------|--------|
| `record` 插件 | 活跃维护，跨平台 | 需配合播放插件 | ⭐⭐⭐⭐⭐ |
| `flutter_sound` | 功能全面，录播一体 | 体积较大，配置复杂 | ⭐⭐⭐⭐ |

**推荐方案:** `record` + `just_audio` (项目已集成 just_audio)

**音频格式:**
- 格式: AAC (m4a) 或 OPUS
- 采样率: 16kHz 或 44.1kHz
- 比特率: 32-64kbps
- 最大时长: 60 秒 (可配置)

**核心类设计:**
```
lib/
├── providers/
│   └── voice_message_provider.dart  # 语音消息状态管理
├── sdk/
│   └── services/
│       ├── voice_recorder_service.dart    # 录音服务
│       └── voice_playback_service.dart    # 播放服务
└── widgets/
    └── message_bubbles/
        └── voice_message_bubble.dart      # 语音消息气泡
```

#### 📦 依赖清单

```yaml
dependencies:
  # 录音 (二选一)
  record: ^5.0.0          # 推荐，轻量
  # 或 flutter_sound: ^9.16.0  # 功能全面
  
  # 权限处理
  permission_handler: ^11.0.0
  
  # 音频配置
  audio_session: ^0.1.19
```

#### 📋 准备资料

**服务端:**
- ✅ 无需额外服务端开发 (复用 XEP-0363 文件上传)
- ⚠️ 确认 `mod_http_upload` 支持音频文件类型

**客户端:**
1. **权限配置**
   - iOS: `Info.plist` 添加麦克风权限描述
   - Android: `AndroidManifest.xml` 添加 `RECORD_AUDIO` 权限

2. **iOS Info.plist 配置:**
```xml
<key>NSMicrophoneUsageDescription</key>
<string>需要麦克风权限来录制语音消息</string>
```

3. **Android AndroidManifest.xml 配置:**
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

#### ✅ 验收标准

- [ ] 按住说话，松开发送功能正常
- [ ] 上滑可取消发送
- [ ] 语音波形动画流畅显示
- [ ] 语音播放/暂停/进度拖动正常
- [ ] 听筒模式/扬声器模式切换正常
- [ ] 锁屏/后台时播放状态正确
- [ ] 发送成功/失败状态正确显示

#### 📅 任务分解

| 任务 | 预计时间 | 依赖 |
|------|----------|------|
| 1. 集成录音插件并配置权限 | 0.5 天 | - |
| 2. 实现录音服务 (开始/停止/取消) | 0.5 天 | 1 |
| 3. 实现播放服务 (播放/暂停/进度) | 0.5 天 | - |
| 4. 语音消息气泡 UI | 0.5 天 | - |
| 5. 波形动画组件 | 0.5 天 | - |
| 6. 集成到消息发送流程 | 0.5 天 | 2,3,4 |
| 7. 测试与优化 | 0.5 天 | 6 |

---

### 2. 推送通知功能

#### 📊 基本信息

| 项目 | 内容 |
|------|------|
| **优先级** | 🔴 高 |
| **预计工时** | 4-5 天 |
| **负责人** | TBD |
| **状态** | 🔲 待开始 |

#### 🎯 功能需求

- 离线时接收消息推送
- 推送显示发送者和内容预览
- 点击推送跳转到对应聊天
- 推送 badge 角标计数
- 群聊/单聊推送区分
- 免打扰会话不推送
- 推送点击统计 (可选)

#### 📝 技术方案

**推送架构:**

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   ejabberd  │────▶│  推送网关   │────▶│  APNs/FCM   │
│  mod_push   │     │ (可选自建)  │     │  厂商推送   │
└─────────────┘     └─────────────┘     └─────────────┘
                                               │
                                               ▼
                                        ┌─────────────┐
                                        │  iOS/Android │
                                        │   客户端    │
                                        └─────────────┘
```

**方案对比:**

| 方案 | iOS | Android | 复杂度 | 推荐度 |
|------|-----|---------|--------|--------|
| 方案1: APNs + FCM | ✅ | ✅ (海外) | 中等 | ⭐⭐⭐⭐ |
| 方案2: APNs + 厂商推送 | ✅ | ✅ (国内) | 较高 | ⭐⭐⭐⭐⭐ |
| 方案3: 第三方推送 (极光/个推) | ✅ | ✅ | 低 | ⭐⭐⭐ (需付费) |

**推荐方案:**
- **iOS**: APNs (Apple Push Notification service)
- **Android**: 
  - 海外: Firebase Cloud Messaging (FCM)
  - 国内: 多厂商推送 (小米、华为、OPPO、vivo、魅族) + 华为 Push Kit

**XEP 协议:**
- XEP-0357: Push Notifications
- ejabberd 模块: `mod_push` + `mod_push_keepalive`

**服务端配置 (ejabberd.yml):**
```yaml
modules:
  mod_push:
    include_body: true
    include_sender: true
  mod_push_keepalive: {}
```

**核心类设计:**
```
lib/
├── providers/
│   └── push_notification_provider.dart
├── sdk/
│   └── services/
│       └── push_notification_service.dart
└── main.dart  # 推送初始化
```

#### 📦 依赖清单

```yaml
dependencies:
  # 基础推送
  firebase_core: ^2.24.0
  firebase_messaging: ^14.7.0
  
  # 角标
  flutter_app_badger: ^1.5.0
  
  # 通知展示
  flutter_local_notifications: ^16.1.0
  
  # 国内厂商推送 (按需)
  # 小米: xiaomi_push
  # 华为: huawei_push
  # 魅族: meizu_push
```

#### 📋 准备资料

**服务端:**
1. **ejabberd 配置**
   - 启用 `mod_push` 和 `mod_push_keepalive` 模块
   - 配置推送网关地址

2. **APNs 证书**
   - iOS 推送证书 (开发 + 生产)
   - 或 Token-Based 认证 (推荐)

3. **FCM 配置**
   - Firebase 项目
   - `google-services.json` (Android)
   - `GoogleService-Info.plist` (iOS)

4. **国内厂商推送**
   - 小米开放平台账号
   - 华为开发者账号
   - OPPO/ vivo 开发者账号

**客户端:**
1. **iOS 配置**
   - Xcode 开启 Push Notifications 能力
   - Xcode 开启 Background Modes -> Remote notifications
   - `Info.plist` 配置

2. **Android 配置**
   - `google-services.json` 放置到 `android/app/`
   - 厂商推送 SDK 集成

**证书和密钥:**
| 项目 | 说明 | 状态 |
|------|------|------|
| APNs 证书/Key | iOS 推送必需 | 🔲 待准备 |
| FCM Server Key | 服务端发送推送 | 🔲 待准备 |
| 厂商推送 AppID/Key | 国内 Android | 🔲 待准备 |

#### ✅ 验收标准

- [ ] App 在后台/离线时能收到推送
- [ ] 推送显示发送者昵称和消息预览
- [ ] 点击推送正确跳转到对应聊天
- [ ] 角标计数正确更新
- [ ] 免打扰会话不推送
- [ ] 群聊推送显示群名

#### 📅 任务分解

| 任务 | 预计时间 | 依赖 |
|------|----------|------|
| 1. 申请 APNs/FCM 证书和配置 | 1 天 | - |
| 2. 服务端 ejabberd mod_push 配置 | 0.5 天 | 1 |
| 3. 客户端集成 firebase_messaging | 1 天 | 1 |
| 4. 实现推送展示与角标 | 0.5 天 | 3 |
| 5. 实现推送点击跳转 | 0.5 天 | 4 |
| 6. 集成免打扰逻辑 | 0.5 天 | - |
| 7. 测试 (iOS + Android) | 1 天 | 5,6 |

---

### 3. MAM 云端消息同步

#### 📊 基本信息

| 项目 | 内容 |
|------|------|
| **优先级** | 🔴 高 |
| **预计工时** | 2-3 天 |
| **负责人** | TBD |
| **状态** | 🔲 待开始 |

#### 🎯 功能需求

- 登录后自动同步历史消息
- 支持分页查询历史
- 消息去重 (避免重复)
- 消息 ID 映射 (服务端 ID vs 本地 ID)
- 同步进度显示
- 同步完成回调

#### 📝 技术方案

**XEP 协议:**
- XEP-0313: Message Archive Management (MAM)
- 当前服务端 `mod_mam` 已配置 (见 `docs/xmpp_protocol_requirements.md`)

**MAM 查询流程:**

```
1. 客户端发送 MAM 查询 IQ
   ┌─────────────────────────────────────┐
   │ <iq type="set" id="mam1">           │
   │   <query xmlns="urn:xmpp:mam:2">    │
   │     <x xmlns="jabber:x:data">       │
   │       <field var="FORM_TYPE">       │
   │         <value>urn:xmpp:mam:2</value>│
   │       </field>                       │
   │       <field var="with">            │
   │         <value>alice@localhost</value>│
   │       </field>                       │
   │     </x>                             │
   │     <set xmlns="http://jabber.org/  │
   │          protocol/rsm">              │
   │       <max>50</max>                  │
   │       <before/>                      │
   │     </set>                           │
   │   </query>                           │
   │ </iq>                                │
   └─────────────────────────────────────┘

2. 服务端返回消息 (Message stanzas with <result> wrapper)

3. 客户端解析并保存到本地数据库

4. 如有更多，使用 RSM 继续查询
```

**同步策略:**

| 场景 | 策略 |
|------|------|
| 首次登录 | 同步最近 30 天消息，或最近 1000 条 |
| 日常登录 | 同步上次在线后到现在的消息 |
| 手动刷新 | 从服务端获取最新消息 |
| 进入聊天 | 检查是否有遗漏消息 |

**核心类设计:**
```
lib/
├── sdk/
│   └── services/
│       ├── message_archive_service.dart    # MAM 服务
│       └── sync_manager.dart               # 同步管理器
└── providers/
    └── sync_provider.dart                  # 同步状态
```

**数据库变更:**
- 需要新增 `server_id` 字段存储服务端消息 ID
- 新增 `sync_status` 字段跟踪同步状态

#### 📦 依赖清单

```yaml
# 无需新增依赖，使用现有 whixp 库
# 需确认 whixp 是否支持 MAM
```

#### 📋 准备资料

**服务端:**
- ✅ `mod_mam` 已配置 (见 `docs/xmpp_protocol_requirements.md`)
- ⚠️ 确认数据库类型 (sql 或 mnesia)
- ⚠️ 确认消息保留时长策略

**客户端:**
1. **whixp 库 MAM 支持**
   - 检查 whixp 是否实现 XEP-0313
   - 如不支持，需手动构造/解析 MAM stanza

2. **数据库迁移**
   - 消息表新增 `server_id` 字段
   - 新增同步相关索引

#### ✅ 验收标准

- [ ] 登录后自动同步历史消息
- [ ] 同步消息不重复
- [ ] 消息顺序正确
- [ ] 支持分页加载更多历史
- [ ] 换设备后能看到历史消息
- [ ] 同步过程有进度/状态提示

#### 📅 任务分解

| 任务 | 预计时间 | 依赖 |
|------|----------|------|
| 1. 调研 whixp MAM 支持情况 | 0.5 天 | - |
| 2. 实现 MAM 查询服务 | 1 天 | 1 |
| 3. 数据库迁移 (新增字段) | 0.5 天 | - |
| 4. 实现同步策略 (登录/刷新) | 0.5 天 | 2,3 |
| 5. 消息去重逻辑 | 0.5 天 | 4 |
| 6. 测试与优化 | 0.5 天 | 5 |

---

### 4. Carbons 多端消息同步

#### 📊 基本信息

| 项目 | 内容 |
|------|------|
| **优先级** | 🔴 高 |
| **预计工时** | 1-2 天 |
| **负责人** | TBD |
| **状态** | 🔲 待开始 |

#### 🎯 功能需求

- 多设备同时在线时，所有设备都能收到消息
- 自己发送的消息在其他设备上同步显示
- 消息状态同步 (已读/已撤回)
- 设备上线时同步遗漏消息

#### 📝 技术方案

**XEP 协议:**
- XEP-0280: Message Carbons

**工作原理:**

```
场景: 用户 A 在手机和电脑同时在线，用户 B 发消息给 A

1. 登录时启用 Carbons:
   <iq type="set" id="enable_carbons">
     <enable xmlns="urn:xmpp:carbons:2"/>
   </iq>

2. B 发送消息给 A:
   B ──────▶ 服务器 ──────▶ A (手机)
                    │
                    └─────▶ A (电脑)  [通过 Carbons]

3. A 在手机上回复:
   A (手机) ──▶ 服务器 ──▶ B
                    │
                    └─────▶ A (电脑)  [通过 Carbons <sent/>]
```

**Carbons 消息类型:**

| 元素 | 说明 |
|------|------|
| `<received>` | 接收到的消息的副本 |
| `<sent>` | 发送的消息的副本 |
| `<private>` | 标记消息不生成 Carbon |

**核心类设计:**
```
lib/
└── sdk/
    └── services/
        └── impl/
            └── standalone_connection_service.dart  # 需修改
```

**需要修改的地方:**
1. 登录成功后发送启用 Carbons 的 IQ
2. 处理收到的 `<received>` 和 `<sent>` Carbon 消息
3. 区分原始消息和 Carbon 副本，避免重复保存

#### 📦 依赖清单

```yaml
# 无需新增依赖，使用现有 whixp 库
```

#### 📋 准备资料

**服务端:**
- ✅ `mod_carbons` 已配置 (见 `docs/xmpp_protocol_requirements.md`)

**客户端:**
1. **whixp 库检查**
   - 检查 whixp 是否有 Carbons 相关实现
   - 如没有，需手动构造 IQ 和解析 Carbon 消息

2. **消息处理逻辑**
   - 现有 `StandaloneConnectionService` 中的消息监听需要调整
   - 需要能识别 Carbon 包装的消息

#### ✅ 验收标准

- [ ] 两台设备同时在线，都能收到消息
- [ ] 一台设备发送的消息，另一台能看到
- [ ] 消息不会重复保存
- [ ] 消息状态 (已读) 能同步

#### 📅 任务分解

| 任务 | 预计时间 | 依赖 |
|------|----------|------|
| 1. 调研 whixp Carbons 支持 | 0.5 天 | - |
| 2. 实现启用 Carbons 逻辑 | 0.5 天 | 1 |
| 3. 实现 Carbon 消息解析 | 0.5 天 | 2 |
| 4. 消息去重逻辑 | 0.5 天 | 3 |
| 5. 多设备测试 | 0.5 天 | 4 |

---

## 第一阶段里程碑

| 里程碑 | 预计完成日期 | 状态 |
|--------|--------------|------|
| M1: 语音消息功能 | 第 3 天 | 🔲 待开始 |
| M2: 推送通知功能 | 第 7 天 | 🔲 待开始 |
| M3: MAM + Carbons 同步 | 第 10 天 | 🔲 待开始 |
| **第一阶段完成** | **第 14 天** | 🔲 待开始 |

---

---

## 第二阶段 (2-4 周) - 重要功能

> **目标**: 完善常用功能，提升用户体验

---

### 5. 位置分享功能

#### 📊 基本信息

| 项目 | 内容 |
|------|------|
| **优先级** | 🟡 中 |
| **预计工时** | 2-3 天 |
| **负责人** | TBD |
| **状态** | 🔲 待开始 |

#### 🎯 功能需求

- 发送当前位置
- 位置消息显示地图缩略图
- 点击位置打开地图应用
- 支持实时位置共享 (可选)
- 位置消息格式规范

#### 📝 技术方案

**方案对比:**

| 方案 | 地图提供商 | 优点 | 缺点 |
|------|-----------|------|------|
| 方案1: 高德/百度地图 | 国内厂商 | 国内数据准确 | 需要申请 Key，有配额 |
| 方案2: Google Maps | Google | 国际通用 | 国内可能无法访问 |
| 方案3: OpenStreetMap + flutter_map | 开源 | 免费无限制 | 国内数据一般 |

**推荐方案:**
- **国内**: 高德地图或百度地图
- **国际化**: OpenStreetMap + Mapbox

**位置消息格式:**
```
[LOCATION:纬度,经度,地址]
示例: [LOCATION:39.9042,116.4074,北京市东城区]
```

**核心类设计:**
```
lib/
├── providers/
│   └── location_provider.dart
├── sdk/
│   ├── models/
│   │   └── location_message.dart
│   └── services/
│       └── location_service.dart
├── widgets/
│   └── message_bubbles/
│       └── location_message_bubble.dart
└── pages/
    └── location_picker_page.dart  # 位置选择页
```

#### 📦 依赖清单

```yaml
dependencies:
  # 定位
  geolocator: ^11.0.0
  
  # 地图 (三选一)
  flutter_map: ^6.1.0          # 开源推荐
  # amap_flutter_map: ^3.0.0    # 高德地图
  # google_maps_flutter: ^2.5.0 # Google Maps
  
  # 地图瓦片 (flutter_map 用)
  flutter_map_cancellable_tile_provider: ^2.0.0
  
  # 坐标转换 (国内需要)
  flutter_easy_amap: ^0.0.1  # 或自定义转换
```

#### 📋 准备资料

**如使用高德/百度:**
1. 申请开发者账号
2. 创建应用获取 API Key
3. 配置平台信息 (Bundle ID / 包名 + SHA1)

**如使用开源方案:**
- 无需额外申请，直接集成

**权限配置:**
```xml
<!-- iOS Info.plist -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>需要位置权限来分享位置</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>后台位置共享需要始终访问位置</string>

<!-- Android AndroidManifest.xml -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<!-- 后台位置 (实时共享需要) -->
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
```

#### ✅ 验收标准

- [ ] 能获取当前位置
- [ ] 位置消息正确发送和接收
- [ ] 地图缩略图正确显示
- [ ] 点击能打开地图应用
- [ ] 位置信息准确

#### 📅 任务分解

| 任务 | 预计时间 | 依赖 |
|------|----------|------|
| 1. 确定地图方案并申请 Key | 0.5 天 | - |
| 2. 集成定位和地图插件 | 0.5 天 | 1 |
| 3. 位置选择页面 UI | 0.5 天 | 2 |
| 4. 位置消息气泡 | 0.5 天 | - |
| 5. 集成到消息发送流程 | 0.5 天 | 3,4 |
| 6. 测试 | 0.5 天 | 5 |

---

### 6. @全体成员功能

#### 📊 基本信息

| 项目 | 内容 |
|------|------|
| **优先级** | 🟡 中 |
| **预计工时** | 1-2 天 |
| **负责人** | TBD |
| **状态** | 🔲 待开始 |

#### 🎯 功能需求

- 群聊中支持 @全体成员
- 只有管理员/群主才能 @全体 (可配置)
- @全体消息特殊提示
- 被 @的消息在会话列表高亮

#### 📝 技术方案

**实现方式:**

**方案一: 纯客户端实现 (简单)**
- 发送时在消息中加入特殊标记 `@全体成员`
- 客户端解析并高亮显示
- 缺点: 服务端不知道，无法做推送特殊处理

**方案二: 服务端支持 (推荐)**
- 使用 XEP-0372: References 或自定义 extension
- 或通过消息 subject 标记
- 服务端可以针对 @消息做特殊推送

**消息格式示例:**
```xml
<message type="groupchat" to="room@conference.localhost">
  <body>@全体成员 大家好</body>
  <mention xmlns="urn:xmpp:mention:0">
    <everyone/>
  </mention>
</message>
```

**核心类设计:**
```
lib/
├── widgets/
│   └── input/
│       ├── mention_overlay.dart      # 现有，需修改
│       └── mention_utils.dart        # 现有，需修改
└── sdk/
    └── models/
        └── mention.dart              # 新增提及模型
```

**需要修改:**
1. `mention_overlay.dart` - 添加"全体成员"选项
2. `mention_utils.dart` - 添加解析 @全体 的逻辑
3. 消息气泡 - 高亮显示 @全体 标记

#### 📦 依赖清单

```yaml
# 无需新增依赖
```

#### 📋 准备资料

**服务端:**
- 如需要服务端支持，需开发自定义模块或确认 ejabberd 是否有相关支持

**客户端:**
- 现有 `mention_overlay.dart` 和 `mention_utils.dart` 可复用
- 只需扩展功能

#### ✅ 验收标准

- [ ] 群聊输入时能选择 @全体成员
- [ ] @全体消息正确发送和显示
- [ ] 非管理员无法 @全体 (可选)
- [ ] 消息中 @全体 高亮显示

#### 📅 任务分解

| 任务 | 预计时间 | 依赖 |
|------|----------|------|
| 1. 扩展 mention_overlay 添加全体成员选项 | 0.5 天 | - |
| 2. 扩展消息解析支持 @全体 | 0.5 天 | 1 |
| 3. 消息气泡高亮显示 | 0.5 天 | 2 |
| 4. 权限控制 (可选) | 0.5 天 | 3 |

---

### 7. 黑名单功能

#### 📊 基本信息

| 项目 | 内容 |
|------|------|
| **优先级** | 🟡 中 |
| **预计工时** | 2-3 天 |
| **负责人** | TBD |
| **状态** | 🔲 待开始 |

#### 🎯 功能需求

- 拉黑/取消拉黑用户
- 黑名单列表管理
- 拉黑后收不到对方消息
- 拉黑后对方发消息提示 (可选)
- 群聊中拉黑 (可选)

#### 📝 技术方案

**XEP 协议:**
- XEP-0016: Privacy Lists (旧)
- XEP-0191: Blocking Command (新，推荐)

**ejabberd 模块:**
- `mod_privacy` (XEP-0016)
- `mod_blocking` (XEP-0191)

**方案对比:**

| 方案 | 协议 | 说明 |
|------|------|------|
| 方案1: 服务端黑名单 | XEP-0191 | 推荐，服务端拦截，多端同步 |
| 方案2: 客户端黑名单 | 本地存储 | 简单，但换设备不同步 |
| 方案3: 混合 | XEP-0191 + 本地 | 最完善 |

**推荐方案1:** 使用 XEP-0191 Blocking Command

**核心流程:**
```
1. 获取黑名单:
<iq type="get" id="block1">
  <blocklist xmlns="urn:xmpp:blocking"/>
</iq>

2. 拉黑用户:
<iq type="set" id="block2">
  <block xmlns="urn:xmpp:blocking">
    <item jid="spam@localhost"/>
  </block>
</iq>

3. 取消拉黑:
<iq type="set" id="unblock1">
  <unblock xmlns="urn:xmpp:blocking">
    <item jid="spam@localhost"/>
  </unblock>
</iq>
```

**服务端配置:**
```yaml
modules:
  mod_blocking: {}
  mod_privacy: {}
```

**核心类设计:**
```
lib/
├── providers/
│   └── blocklist_provider.dart
├── sdk/
│   ├── models/
│   │   └── blocklist.dart
│   └── services/
│       └── blocklist_service.dart
├── pages/
│   └── blocklist_page.dart
└── widgets/
    └── user_profile_menu.dart  # 添加拉黑选项
```

#### 📦 依赖清单

```yaml
# 无需新增依赖，使用 whixp
```

#### 📋 准备资料

**服务端:**
1. 确认 ejabberd 启用 `mod_blocking` 模块
2. 确认 `mod_privacy` 配置

**客户端:**
1. 检查 whixp 是否支持 XEP-0191
2. 如不支持，手动构造 IQ

#### ✅ 验收标准

- [ ] 能拉黑用户
- [ ] 拉黑后收不到对方消息
- [ ] 能取消拉黑
- [ ] 黑名单列表正确显示
- [ ] 换设备后黑名单同步

#### 📅 任务分解

| 任务 | 预计时间 | 依赖 |
|------|----------|------|
| 1. 服务端配置 mod_blocking | 0.5 天 | - |
| 2. 实现黑名单服务 | 1 天 | 1 |
| 3. 黑名单列表页面 | 0.5 天 | 2 |
| 4. 用户菜单添加拉黑选项 | 0.5 天 | 3 |
| 5. 消息拦截逻辑 | 0.5 天 | 2 |
| 6. 测试 | 0.5 天 | 4,5 |

---

### 8. 表情包增强

#### 📊 基本信息

| 项目 | 内容 |
|------|------|
| **优先级** | 🟡 中 |
| **预计工时** | 2-3 天 |
| **负责人** | TBD |
| **状态** | 🔲 待开始 |

#### 🎯 功能需求

- 自定义表情面板
- 常用表情记录
- 最近使用表情
- 支持 GIF 动图
- 表情搜索 (可选)
- 表情包商店 (后期可选)

#### 📝 技术方案

**表情分类:**

| 类型 | 说明 | 实现方式 |
|------|------|----------|
| Emoji | 系统表情 | Unicode 字符 |
| 静态表情 | 图片表情 | 本地/网络图片 |
| 动态表情 | GIF/APNG | flutter_flutter_gif |
| 大表情 | 贴纸 | 较大的图片 |

**核心类设计:**
```
lib/
├── providers/
│   └── emoji_provider.dart
├── sdk/
│   ├── models/
│   │   └── emoji.dart
│   └── services/
│       ├── emoji_service.dart
│       └── recent_emoji_service.dart
├── widgets/
│   └── input/
│       ├── emoji_panel.dart      # 现有，需扩展
│       └── sticker_panel.dart    # 新增
└── assets/
    └── emojis/                   # 本地表情资源
```

**表情数据结构:**
```dart
class EmojiCategory {
  final String id;
  final String name;
  final IconData icon;
  final List<EmojiItem> emojis;
}

class EmojiItem {
  final String code;           // Unicode 或 资源路径
  final EmojiType type;        // emoji / static / animated
  final String? thumbnail;
}
```

#### 📦 依赖清单

```yaml
dependencies:
  # GIF 支持
  flutter_gif: ^0.0.6
  # 或 cached_network_image 已支持部分 GIF
  
  # 键盘高度监听 (优化表情面板)
  flutter_keyboard_visibility: ^6.0.0
```

#### 📋 准备资料

**设计资源:**
1. 表情图标 (分类 tab 的图标)
2. 自定义表情图片 (如需要)
3. 表情包设计规范 (尺寸、格式)

**技术调研:**
1. 确认现有 `emoji_panel.dart` 的实现程度
2. 决定表情数据来源 (内置/网络)

#### ✅ 验收标准

- [ ] 表情面板流畅显示
- [ ] 能发送和接收表情
- [ ] 最近使用表情正确记录
- [ ] GIF 动图正确播放
- [ ] 表情和文字混排正确

#### 📅 任务分解

| 任务 | 预计时间 | 依赖 |
|------|----------|------|
| 1. 调研现有 emoji_panel 实现 | 0.5 天 | - |
| 2. 设计表情数据结构和分类 | 0.5 天 | 1 |
| 3. 扩展表情面板 UI | 1 天 | 2 |
| 4. 实现最近使用表情记录 | 0.5 天 | 3 |
| 5. GIF 动图支持 | 0.5 天 | 3 |
| 6. 测试 | 0.5 天 | 4,5 |

---

### 9. 群文件群相册

#### 📊 基本信息

| 项目 | 内容 |
|------|------|
| **优先级** | 🟡 中 |
| **预计工时** | 3-4 天 |
| **负责人** | TBD |
| **状态** | 🔲 待开始 |

#### 🎯 功能需求

**群文件:**
- 群文件列表
- 上传文件到群空间
- 下载/预览群文件
- 文件管理 (删除、重命名)
- 文件大小限制

**群相册:**
- 群相册列表
- 上传图片到群相册
- 图片瀑布流展示
- 图片预览、保存
- 相册管理

#### 📝 技术方案

**存储方案:**

| 方案 | 说明 | 优点 | 缺点 |
|------|------|------|------|
| 方案1: 复用 XEP-0363 | 现有 HTTP Upload | 无需额外开发 | 没有群空间概念 |
| 方案2: 自定义服务端 | 独立文件服务 | 功能完整 | 需要服务端开发 |
| 方案3: 对象存储 | OSS/COS/S3 | 稳定可靠 | 需要云服务 |

**推荐方案:**
- **短期**: 方案1 + 客户端标记 (消息中标记为群文件)
- **长期**: 方案2 或 方案3

**数据模型:**

```dart
// 群文件
class GroupFile {
  final String id;
  final String groupId;
  final String name;
  final String url;
  final int size;
  final String mimeType;
  final String uploaderId;
  final DateTime uploadTime;
}

// 群相册
class GroupAlbum {
  final String id;
  final String groupId;
  final String name;
  final String coverUrl;
  final int imageCount;
  final DateTime createTime;
}

class GroupPhoto {
  final String id;
  final String albumId;
  final String url;
  final String thumbnailUrl;
  final int width;
  final int height;
  final String uploaderId;
  final DateTime uploadTime;
}
```

**核心类设计:**
```
lib/
├── providers/
│   ├── group_files_provider.dart
│   └── group_albums_provider.dart
├── sdk/
│   ├── models/
│   │   ├── group_file.dart
│   │   └── group_album.dart
│   └── services/
│       ├── group_file_service.dart
│       └── group_album_service.dart
├── pages/
│   ├── group_files_page.dart
│   ├── group_albums_page.dart
│   └── group_album_detail_page.dart
└── widgets/
    ├── group_file_item.dart
    └── group_photo_grid.dart
```

**数据库变更:**
- 新增 `group_files` 表
- 新增 `group_albums` 表
- 新增 `group_photos` 表

#### 📦 依赖清单

```yaml
dependencies:
  # 瀑布流
  flutter_staggered_grid_view: ^0.7.0
  
  # 图片保存
  image_gallery_saver: ^2.0.3
  
  # 文件下载
  dio: ^5.4.0
  path_provider: ^2.1.0  # 已有
```

#### 📋 准备资料

**服务端:**
1. 确认是否需要开发独立的群文件服务
2. 或确认复用现有 HTTP Upload 的方案

**客户端:**
1. 设计群文件/相册的数据结构
2. 准备数据库迁移

#### ✅ 验收标准

**群文件:**
- [ ] 能上传文件到群空间
- [ ] 群文件列表正确显示
- [ ] 能下载和预览文件
- [ ] 上传者能删除自己的文件

**群相册:**
- [ ] 能上传图片到群相册
- [ ] 相册列表正确显示
- [ ] 图片瀑布流流畅展示
- [ ] 能预览和保存图片

#### 📅 任务分解

| 任务 | 预计时间 | 依赖 |
|------|----------|------|
| 1. 确定存储方案 | 0.5 天 | - |
| 2. 设计数据模型和数据库表 | 0.5 天 | 1 |
| 3. 实现群文件服务 | 1 天 | 2 |
| 4. 群文件列表页面 | 0.5 天 | 3 |
| 5. 实现群相册服务 | 0.5 天 | 2 |
| 6. 群相册页面 (瀑布流) | 1 天 | 5 |
| 7. 测试 | 0.5 天 | 4,6 |

---

## 第二阶段里程碑

| 里程碑 | 预计完成日期 | 状态 |
|--------|--------------|------|
| M4: 位置分享 + @全体成员 | 第 17 天 | 🔲 待开始 |
| M5: 黑名单功能 | 第 20 天 | 🔲 待开始 |
| M6: 表情包增强 | 第 23 天 | 🔲 待开始 |
| M7: 群文件群相册 | 第 28 天 | 🔲 待开始 |
| **第二阶段完成** | **第 28 天** | 🔲 待开始 |

---

---

## 第三阶段 (4-8 周) - 高级功能

> **目标**: 实现高级功能，提升产品竞争力

---

### 10. 语音视频通话

#### 📊 基本信息

| 项目 | 内容 |
|------|------|
| **优先级** | 🟡 中 (但复杂度高) |
| **预计工时** | 7-10 天 |
| **负责人** | TBD |
| **状态** | 🔲 待开始 |

#### 🎯 功能需求

- 一对一语音通话
- 一对一视频通话
- 通话邀请/接听/拒绝
- 通话中静音/开关摄像头
- 通话质量显示
- 通话记录
- 群聊多人通话 (可选)

#### 📝 技术方案

**技术栈:**

| 层级 | 技术 | 说明 |
|------|------|------|
| 媒体引擎 | WebRTC | 实时音视频核心 |
| 信令 | XMPP 或 WebSocket | 通话建立/控制 |
| NAT 穿透 | STUN/TURN | P2P 连接失败时的中继 |

**架构图:**

```
┌─────────────┐                         ┌─────────────┐
│  客户端 A   │                         │  客户端 B   │
│             │                         │             │
│  ┌───────┐  │   1. 信令 (邀请/应答)    │  ┌───────┐  │
│  │ 信令层 │◀┼─────────────────────────▶│ 信令层 │  │
│  └───┬───┘  │   (XMPP/WebSocket)      │  └───┬───┘  │
│      │      │                         │      │      │
│  ┌───▼───┐  │   2. 媒体流 (RTP/SRTP)   │  ┌───▼───┐  │
│  │ WebRTC│◀┼─────────────────────────▶│ WebRTC│  │
│  └───┬───┘  │   (P2P 或 TURN 中继)    │  └───┬───┘  │
│      │      │                         │      │      │
│      ▼      │                         │      ▼      │
│  麦克风/相机 │                         │  麦克风/相机 │
└─────────────┘                         └─────────────┘
              │
              ▼
    ┌─────────────────┐
    │  STUN/TURN 服务器 │
    │  (NAT 穿透服务)   │
    └─────────────────┘
```

**信令方案:**

| 方案 | 协议 | 优点 | 缺点 |
|------|------|------|------|
| 方案1: XMPP Jingle | XEP-0343 | 标准协议，与现有 XMPP 集成 | 实现复杂，whixp 可能不支持 |
| 方案2: 自定义 XMPP | 自定义 stanza | 灵活可控，复用现有连接 | 非标准 |
| 方案3: WebSocket | 独立连接 | 实时性好 | 需要额外服务 |

**推荐方案2:** 自定义 XMPP stanza，复用现有连接

**STUN/TURN 服务器:**

| 方案 | 说明 |
|------|------|
| coturn | 开源 STUN/TURN 服务器，推荐 |
| Google STUN | `stun:stun.l.google.com:19302` (仅 STUN) |
| 云服务 | 腾讯云 TRTC、阿里云 RTC 等 (商业方案) |

**核心类设计:**
```
lib/
├── providers/
│   └── call_provider.dart
├── sdk/
│   ├── models/
│   │   └── call_session.dart
│   └── services/
│       ├── signaling_service.dart      # 信令服务
│       └── webrtc_service.dart         # WebRTC 封装
├── pages/
│   ├── incoming_call_page.dart         # 来电页面
│   ├── ongoing_call_page.dart          # 通话中页面
│   └── call_record_page.dart           # 通话记录
└── widgets/
    └── call_controls.dart              # 通话控制按钮
```

#### 📦 依赖清单

```yaml
dependencies:
  # WebRTC
  flutter_webrtc: ^0.11.0
  
  # 音频路由管理 (听筒/扬声器/蓝牙)
  audio_session: ^0.1.19
  just_audio: ^0.9.40  # 已有，可用于铃声
  
  # 屏幕常亮 (通话时)
  wakelock_plus: ^1.1.0
  
  # 距离传感器 (通话时息屏)
  proximity_sensor: ^1.3.0
```

#### 📋 准备资料

**服务端:**
1. **STUN/TURN 服务器**
   - 部署 coturn 或使用云服务
   - 配置用户名密码
   - 开放端口 (UDP 3478, 49152-65535 等)

2. **信令服务**
   - 如使用自定义 XMPP，无需额外服务
   - 如使用 WebSocket，需要部署信令服务

**客户端:**
1. **权限配置**
   - 相机权限
   - 麦克风权限
   - 蓝牙权限 (Android)

2. **iOS 配置**
```xml
<key>NSCameraUsageDescription</key>
<string>需要相机权限进行视频通话</string>
<key>NSMicrophoneUsageDescription</key>
<string>需要麦克风权限进行语音通话</string>
```

3. **Android 配置**
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-feature android:name="android.hardware.camera"/>
<uses-feature android:name="android.hardware.camera.autofocus"/>
```

**服务器信息清单:**
| 项目 | 说明 | 状态 |
|------|------|------|
| STUN 服务器地址 | 如 stun:stun.example.com:3478 | 🔲 待准备 |
| TURN 服务器地址 | 如 turn:turn.example.com:3478 | 🔲 待准备 |
| TURN 用户名 | 认证用 | 🔲 待准备 |
| TURN 密码 | 认证用 | 🔲 待准备 |

#### ✅ 验收标准

**语音通话:**
- [ ] 能发起语音通话邀请
- [ ] 对方能收到来电提示
- [ ] 能接听/拒绝通话
- [ ] 通话语音清晰
- [ ] 能静音/取消静音
- [ ] 能切换听筒/扬声器
- [ ] 通话结束后状态正确

**视频通话:**
- [ ] 能发起视频通话
- [ ] 本地和远端画面正确显示
- [ ] 能开关摄像头
- [ ] 能切换前后摄像头
- [ ] 视频流畅

**网络:**
- [ ] WiFi 下正常
- [ ] 4G/5G 下正常
- [ ] 弱网下有提示

#### 📅 任务分解

| 任务 | 预计时间 | 依赖 |
|------|----------|------|
| 1. 部署 STUN/TURN 服务器 | 1 天 | - |
| 2. 集成 flutter_webrtc | 1 天 | - |
| 3. 设计并实现信令协议 | 2 天 | 2 |
| 4. 来电页面 UI | 1 天 | 3 |
| 5. 通话中页面 UI | 1.5 天 | 3 |
| 6. 音频路由管理 | 0.5 天 | 5 |
| 7. 通话记录功能 | 1 天 | 6 |
| 8. 测试与优化 | 1 天 | 7 |

---

### 11. 群已读详情

#### 📊 基本信息

| 项目 | 内容 |
|------|------|
| **优先级** | 🟢 低 |
| **预计工时** | 2-3 天 |
| **负责人** | TBD |
| **状态** | 🔲 待开始 |

#### 🎯 功能需求

- 群消息发送后，查看哪些成员已读
- 区分已读/未读列表
- 点击已读列表查看详情
- 发送者可看，普通成员是否可看 (可配置)

#### 📝 技术方案

**实现难点:**
- XMPP 标准协议没有群已读详情的规定
- 需要自定义扩展或服务端支持

**方案对比:**

| 方案 | 说明 | 优点 | 缺点 |
|------|------|------|------|
| 方案1: 客户端上报 | 每个成员阅读后发送已读回执给群 | 简单 | 群大时消息风暴，隐私问题 |
| 方案2: 服务端记录 | 服务端跟踪每个成员的已读状态 | 可靠，可扩展 | 需要服务端开发 |
| 方案3: 混合 | 小群方案1，大群方案2 | 灵活 | 复杂 |

**推荐方案:**
- 先实现方案1 (客户端) 用于验证
- 后期优化为方案2

**自定义协议示例:**
```xml
<!-- 阅读状态上报 (发送给群) -->
<message type="groupchat" to="room@conference.localhost">
  <read xmlns="custom:read:0" id="message-123"/>
</message>

<!-- 或发送 IQ 查询已读状态 -->
<iq type="get" to="room@conference.localhost" id="query1">
  <query xmlns="custom:readstatus:0" message_id="message-123"/>
</iq>
```

**数据模型:**
```dart
class MessageReadStatus {
  final String messageId;
  final List<GroupMember> readMembers;    // 已读成员
  final List<GroupMember> unreadMembers;  // 未读成员
}
```

**核心类设计:**
```
lib/
├── providers/
│   └── message_read_status_provider.dart
├── sdk/
│   ├── models/
│   │   └── message_read_status.dart
│   └── services/
│       └── group_read_status_service.dart
├── pages/
│   └── message_read_status_page.dart  # 已读详情页
└── widgets/
    └── read_status_indicator.dart     # 消息气泡上的已读人数
```

#### 📦 依赖清单

```yaml
# 无需新增依赖
```

#### 📋 准备资料

**服务端:**
1. 如用方案2，需要服务端开发
2. 或确认 ejabberd 是否有相关模块

**客户端:**
1. 设计自定义协议格式
2. 确定群成员列表获取方式

#### ✅ 验收标准

- [ ] 发送群消息后能看到已读人数
- [ ] 点击能查看已读/未读成员列表
- [ ] 成员阅读后状态正确更新
- [ ] 大量成员时性能良好

#### 📅 任务分解

| 任务 | 预计时间 | 依赖 |
|------|----------|------|
| 1. 确定技术方案 | 0.5 天 | - |
| 2. 设计协议和数据模型 | 0.5 天 | 1 |
| 3. 实现已读状态上报 | 0.5 天 | 2 |
| 4. 实现已读状态查询 | 0.5 天 | 3 |
| 5. 消息气泡已读人数 UI | 0.5 天 | 3 |
| 6. 已读详情页面 | 0.5 天 | 4,5 |
| 7. 测试 | 0.5 天 | 6 |

---

### 12. 阅后即焚

#### 📊 基本信息

| 项目 | 内容 |
|------|------|
| **优先级** | 🟢 低 |
| **预计工时** | 2-3 天 |
| **负责人** | TBD |
| **状态** | 🔲 待开始 |

#### 🎯 功能需求

- 发送消息时设置阅后即焚
- 可选时长: 5秒、10秒、30秒、1分钟、5分钟
- 接收方查看后倒计时自动删除
- 发送方也会删除
- 截屏检测提示 (可选)
- 转发限制 (可选)

#### 📝 技术方案

**XEP 协议:**
- XEP-0384: OMEMO (端到端加密，可选)
- XEP-0424: Message Retraction (消息撤回，已有部分实现)
- 但没有标准的"阅后即焚"协议

**实现方案:**

**方案1: 纯客户端实现**
- 消息中携带 burn_after 字段
- 接收方打开聊天/查看消息后启动计时器
- 计时结束后本地删除
- 问题: 多端同步、服务端仍有消息

**方案2: 客户端 + 服务端配合**
- 发送时设置过期时间
- 服务端到期自动删除 (需服务端支持)
- 客户端定期清理
- 问题: 需要服务端开发

**方案3: 基于消息撤回**
- 发送方定时撤回消息
- 问题: 发送方必须在线

**推荐方案1 + MAM 不归档:**
- 客户端实现计时删除
- 发送时设置消息不归档 (不存入 MAM)
- 服务端 `mod_offline` 也不存储 (或设置短 TTL)

**消息格式:**
```xml
<message type="chat" to="alice@localhost">
  <body>这是一条阅后即焚消息</body>
  <burn_after xmlns="custom:burn:0" seconds="10"/>
  <no-archive xmlns="urn:xmpp:hints"/>
</message>
```

**核心类设计:**
```
lib/
├── providers/
│   └── ephemeral_message_provider.dart
├── sdk/
│   ├── models/
│   │   └── ephemeral_message.dart
│   └── services/
│       └── ephemeral_message_service.dart
├── widgets/
│   └── message_bubbles/
│       └── ephemeral_message_bubble.dart  # 带倒计时显示
└── pages/
    └── burn_duration_picker.dart           # 时长选择器
```

**数据库变更:**
- 消息表新增 `burn_after_seconds` 字段
- 新增 `burn_at` 字段 (预计销毁时间)

#### 📦 依赖清单

```yaml
# 无需新增依赖
```

#### 📋 准备资料

**服务端:**
1. 确认消息不归档的实现方式 (`mod_mam` 配置)
2. 确认离线消息存储策略

**客户端:**
1. 设计倒计时 UI
2. 确定销毁触发时机 (进入聊天/查看消息)

#### ✅ 验收标准

- [ ] 发送时能选择阅后即焚时长
- [ ] 接收方能看到倒计时提示
- [ ] 倒计时结束后消息自动删除
- [ ] 发送方的消息也会删除
- [ ] 退出聊天再进入，已销毁的消息不显示

#### 📅 任务分解

| 任务 | 预计时间 | 依赖 |
|------|----------|------|
| 1. 设计消息格式和数据模型 | 0.5 天 | - |
| 2. 数据库迁移 | 0.5 天 | 1 |
| 3. 发送时选择时长 UI | 0.5 天 | 1 |
| 4. 消息气泡倒计时显示 | 0.5 天 | 3 |
| 5. 实现销毁逻辑 | 1 天 | 4 |
| 6. 测试 | 0.5 天 | 5 |

---

### 13. 收藏功能

#### 📊 基本信息

| 项目 | 内容 |
|------|------|
| **优先级** | 🟢 低 |
| **预计工时** | 2-3 天 |
| **负责人** | TBD |
| **状态** | 🔲 待开始 |

#### 🎯 功能需求

- 收藏消息 (文本/图片/视频/文件/位置)
- 收藏列表展示
- 收藏分类 (可选)
- 收藏搜索 (可选)
- 取消收藏
- 转发收藏的内容
- 多端同步 (配合 MAM 或私有存储)

#### 📝 技术方案

**存储方案:**

| 方案 | 说明 | 优点 | 缺点 |
|------|------|------|------|
| 方案1: 本地存储 | SQLite | 简单 | 换设备丢失 |
| 方案2: XEP-0049 Private XML | 服务端私有存储 | 多端同步 | 数据格式有限制 |
| 方案3: 自定义服务端 | 独立收藏服务 | 功能完整 | 需要开发 |

**推荐方案1 + 方案2:**
- 本地用 SQLite
- 服务端用 XEP-0049 或 XEP-0223 (Persistent Storage of Private Data via PubSub)

**XEP-0049 示例:**
```xml
<!-- 保存收藏 -->
<iq type="set" id="store1">
  <query xmlns="jabber:iq:private">
    <favorite xmlns="my:favorites">
      <message id="msg-123" type="text" from="alice@localhost">
        <content>收藏的消息内容</content>
        <timestamp>2026-04-18T10:00:00Z</timestamp>
      </message>
    </favorite>
  </query>
</iq>

<!-- 获取收藏 -->
<iq type="get" id="fetch1">
  <query xmlns="jabber:iq:private">
    <favorite xmlns="my:favorites"/>
  </query>
</iq>
```

**数据模型:**
```dart
class FavoriteItem {
  final String id;
  final FavoriteType type;        // message / image / video / file / location
  final String? conversationId;   // 来源会话
  final String? senderId;         // 发送者
  final String content;           // 文本内容 或 URL
  final String? thumbnail;        // 缩略图
  final MediaMetadata? media;     // 媒体信息
  final DateTime createdAt;
  final Map<String, dynamic>? extra;
}

enum FavoriteType {
  message,
  image,
  video,
  file,
  location,
  link,
}
```

**核心类设计:**
```
lib/
├── providers/
│   └── favorites_provider.dart
├── sdk/
│   ├── models/
│   │   └── favorite.dart
│   └── services/
│       └── favorites_service.dart
├── pages/
│   ├── favorites_page.dart
│   └── favorite_detail_page.dart
├── widgets/
│   ├── favorite_item.dart
│   └── message_action_menu.dart  # 添加收藏选项
```

**数据库变更:**
- 新增 `favorites` 表

#### 📦 依赖清单

```yaml
# 无需新增依赖
```

#### 📋 准备资料

**服务端:**
1. 确认 `mod_private` 模块启用
2. 或考虑使用 `mod_pubsub` (XEP-0223)

**客户端:**
1. 设计收藏数据结构
2. 准备数据库迁移

#### ✅ 验收标准

- [ ] 能收藏各种类型的消息
- [ ] 收藏列表正确显示
- [ ] 能取消收藏
- [ ] 能转发收藏的内容
- [ ] 换设备后收藏同步 (如实现服务端同步)

#### 📅 任务分解

| 任务 | 预计时间 | 依赖 |
|------|----------|------|
| 1. 设计数据模型和数据库表 | 0.5 天 | - |
| 2. 实现收藏服务 (本地) | 0.5 天 | 1 |
| 3. 消息菜单添加收藏选项 | 0.5 天 | 2 |
| 4. 收藏列表页面 | 0.5 天 | 2 |
| 5. 收藏详情页面 | 0.5 天 | 4 |
| 6. 服务端同步 (可选) | 1 天 | 2 |
| 7. 测试 | 0.5 天 | 5,6 |

---

## 第三阶段里程碑

| 里程碑 | 预计完成日期 | 状态 |
|--------|--------------|------|
| M8: 音视频通话基础版 | 第 40 天 | 🔲 待开始 |
| M9: 群已读详情 + 阅后即焚 | 第 46 天 | 🔲 待开始 |
| M10: 收藏功能 | 第 50 天 | 🔲 待开始 |
| **第三阶段完成** | **第 56 天** | 🔲 待开始 |

---

---

## 第四阶段 (按需) - 增强体验

> **目标**: 根据业务需求选择性开发

---

### 14. 红包/转账功能
- **优先级**: 🟢 低
- **预计工时**: 5-7 天
- **依赖**: 支付系统对接
- **说明**: 需要支付牌照或第三方支付，非 IM 核心功能

### 15. 朋友圈/动态
- **优先级**: 🟢 低
- **预计工时**: 4-6 天
- **说明**: 社交属性强，需要额外的数据模型和服务

### 16. 文件传输助手
- **优先级**: 🟢 低
- **预计工时**: 1-2 天
- **说明**: 特殊机器人账号实现，相对简单

### 17. 聊天主题/背景
- **优先级**: 🟢 低
- **预计工时**: 2-3 天
- **说明**: 个性化需求，已有部分主题框架

### 18. 合并转发
- **优先级**: 🟢 低
- **预计工时**: 1-2 天
- **说明**: 多条消息合并成一条卡片

---

---

## 技术债务与代码质量

### 🔧 代码优化

#### 1. 错误处理机制
**现状**: 很多地方 `try-catch` 后只打印日志

**优化方案:**
- 统一的错误类型定义
- 错误展示组件 (Toast/Dialog)
- 错误上报 (可选，如 Sentry)
- 预计工时: 2 天

#### 2. 测试覆盖
**现状**: 只有默认的 `widget_test.dart`

**优化方案:**
- 单元测试 (Service 层)
- Widget 测试 (UI 组件)
- 集成测试 (端到端流程)
- 预计工时: 持续进行

#### 3. 国际化 (i18n)
**现状**: 硬编码中文字符串

**优化方案:**
- 使用 `flutter_localizations`
- 提取所有字符串到 ARB 文件
- 预计工时: 2-3 天

### ⚡ 性能优化

#### 1. 消息列表性能
**问题**: 大量消息时可能卡顿

**优化方案:**
- 使用 `SliverList` 或优化 `ListView.builder`
- 消息气泡缓存
- 图片预加载和缓存策略
- 预计工时: 2 天

#### 2. 数据库优化
**优化方案:**
- 添加查询索引
- 数据库迁移脚本管理
- 定期清理旧数据 (可配置)
- 预计工时: 1 天

### 🔐 安全改进

#### 1. TLS 证书验证
**现状**: `onBadCertificateCallback` 返回 `true` 接受所有证书

**风险**: 中间人攻击

**优化方案:**
- 生产环境验证证书
- 支持证书锁定
- 预计工时: 1 天

#### 2. 敏感信息安全存储
**现状**: 密码等敏感信息可能存储不安全

**优化方案:**
- 使用 `flutter_secure_storage`
- Keychain (iOS) / Keystore (Android)
- 预计工时: 1 天

#### 3. 端到端加密 (可选)
**方案:** OMEMO (XEP-0384)
- 预计工时: 5-7 天
- 复杂度较高

### 📐 架构改进

#### 1. 分层架构
**现状**: UI 层和业务逻辑耦合较深

**优化方向:**
```
lib/
├── presentation/    # UI 层 (现有 pages/widgets)
├── application/     # 应用层 (Use Cases)
├── domain/          # 领域层 (Models/Repositories)
└── infrastructure/  # 基础设施层 (Services/API)
```
- 预计工时: 重构需谨慎，建议逐步进行

---

---

## 里程碑追踪

### 总览

| 阶段 | 周期 | 功能数量 | 预计工时 | 状态 |
|------|------|----------|----------|------|
| 第一阶段 | 1-2 周 | 4 个核心功能 | 10-14 天 | 🔲 待开始 |
| 第二阶段 | 2-4 周 | 5 个重要功能 | 10-14 天 | 🔲 待开始 |
| 第三阶段 | 4-8 周 | 4 个高级功能 | 13-19 天 | 🔲 待开始 |
| 第四阶段 | 按需 | 5 个增强功能 | 13-20 天 | 🔲 待开始 |

### 详细里程碑

#### 第一阶段里程碑 (核心体验)

| 里程碑 ID | 名称 | 预计完成日期 | 状态 | 前置依赖 |
|-----------|------|--------------|------|----------|
| M1 | 语音消息功能 | 第 3 天 | 🔲 待开始 | - |
| M2 | 推送通知功能 | 第 7 天 | 🔲 待开始 | 需申请证书 |
| M3 | MAM + Carbons 同步 | 第 10 天 | 🔲 待开始 | - |
| **M1-3** | **第一阶段完成** | **第 14 天** | 🔲 待开始 | M1, M2, M3 |

#### 第二阶段里程碑 (重要功能)

| 里程碑 ID | 名称 | 预计完成日期 | 状态 | 前置依赖 |
|-----------|------|--------------|------|----------|
| M4 | 位置分享 + @全体成员 | 第 17 天 | 🔲 待开始 | - |
| M5 | 黑名单功能 | 第 20 天 | 🔲 待开始 | - |
| M6 | 表情包增强 | 第 23 天 | 🔲 待开始 | - |
| M7 | 群文件群相册 | 第 28 天 | 🔲 待开始 | - |
| **M4-7** | **第二阶段完成** | **第 28 天** | 🔲 待开始 | M4, M5, M6, M7 |

#### 第三阶段里程碑 (高级功能)

| 里程碑 ID | 名称 | 预计完成日期 | 状态 | 前置依赖 |
|-----------|------|--------------|------|----------|
| M8 | 音视频通话基础版 | 第 40 天 | 🔲 待开始 | 需部署 STUN/TURN |
| M9 | 群已读详情 + 阅后即焚 | 第 46 天 | 🔲 待开始 | - |
| M10 | 收藏功能 | 第 50 天 | 🔲 待开始 | - |
| **M8-10** | **第三阶段完成** | **第 56 天** | 🔲 待开始 | M8, M9, M10 |

---

---

## 快速开始清单

### 开始前准备

#### 1. 服务端准备

| 项目 | 说明 | 优先级 | 状态 |
|------|------|--------|------|
| ejabberd mod_push | 推送模块配置 | 🔴 高 | 🔲 待准备 |
| ejabberd mod_blocking | 黑名单模块 | 🟡 中 | 🔲 待确认 |
| STUN/TURN 服务器 | 音视频通话必需 | 🟡 中 | 🔲 待准备 |

#### 2. 证书和账号准备

| 项目 | 用途 | 优先级 | 状态 |
|------|------|--------|------|
| Apple 开发者账号 | APNs 推送必需 | 🔴 高 | 🔲 待准备 |
| Firebase 账号 | FCM 推送 | 🔴 高 | 🔲 待准备 |
| 国内厂商推送账号 | 小米/华为/OPPO/vivo | 🟡 中 | 🔲 待准备 |
| 地图服务 API Key | 位置分享 | 🟡 中 | 🔲 待准备 |

#### 3. 开发环境准备

| 项目 | 说明 | 优先级 |
|------|------|--------|
| Flutter 3.10+ | 项目已配置 | ✅ 已满足 |
| Android Studio | Android 开发 | 🔴 必需 |
| Xcode 15+ | iOS/macOS 开发 | 🔴 必需 |
| 测试设备 | iOS + Android 真机 | 🔴 必需 |
| ejabberd 测试服务器 | 功能测试 | 🔴 必需 |

---

---

## 风险与注意事项

### 技术风险

| 风险项 | 影响 | 缓解措施 |
|--------|------|----------|
| whixp 库 MAM/Carbons 支持不完善 | 同步功能受阻 | 准备手动实现 XMPP stanza |
| 国内 Android 推送兼容性 | 推送无法到达 | 集成多厂商推送 SDK |
| WebRTC 移动端兼容性 | 音视频通话问题 | 充分测试，准备 fallback |
| 证书过期 | 推送/通话中断 | 设置提醒，提前更新 |

### 业务风险

| 风险项 | 影响 | 缓解措施 |
|--------|------|----------|
| 隐私合规 (GDPR/等保) | 法律风险 | 数据加密、用户授权 |
| 内容安全 | 违规内容 | 考虑内容审核机制 |
| 用户体验不一致 | 平台差异 | UI/UX 统一设计 |

---

---

## 更新日志

| 日期 | 版本 | 变更内容 |
|------|------|----------|
| 2026-04-18 | v1.0 | 初始版本创建 |

---

> 本文档将根据项目进展持续更新。
> 如有疑问，请联系项目负责人。
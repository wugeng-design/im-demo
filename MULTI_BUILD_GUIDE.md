# IM SDK Demo 多平台打包指南

## 快速开始

### 交互式菜单（推荐新手）
```bash
./scripts/multi_build.sh
```

### 命令行方式
```bash
# 构建 Android
./scripts/multi_build.sh android --release

# 构建 iOS
./scripts/multi_build.sh ios --release

# 构建 macOS
./scripts/multi_build.sh macos --release

# 构建所有平台
./scripts/multi_build.sh all --release --increment

# 查看状态
./scripts/multi_build.sh status

# 查看日志
./scripts/multi_build.sh logs android
```

---

## 功能特点

### 1. 多平台支持
- ✅ **Android** - 生成 APK 文件
- ✅ **iOS** - 生成 .app 文件
- ✅ **macOS** - 生成 .app 文件

### 2. 构建模式
- **Debug** - 本地调试，快速迭代
- **Release** - 生产版本，优化性能

### 3. 后台构建
- 构建在后台运行，不阻塞开发
- 查看实时状态和日志
- 支持并行构建多平台

### 4. 版本管理
- 自动从 pubspec.yaml 读取版本
- 支持递增构建号
- 统一的构建号管理

---

## 目录结构

```
im-demo/
├── build_output/              # 构建产物目录
│   └── 1/                     # 构建号
│       ├── android/           # Android APK
│       │   └── app-release.apk
│       ├── ios/               # iOS .app
│       └── macos/             # macOS .app
│           └── im_sdk_demo.app
├── .build_logs/               # 构建日志
│   ├── android_build.log
│   ├── ios_build.log
│   └── macos_build.log
├── .build_pids/               # 进程 PID
│   ├── android.pid
│   ├── ios.pid
│   └── macos.pid
└── .buildnumber               # 当前构建号
```

---

## 详细使用说明

### 构建单个平台

#### Android
```bash
# Release 版本
./scripts/multi_build.sh android --release

# Debug 版本
./scripts/multi_build.sh android --debug
```

**产物位置:**
```
build_output/<构建号>/android/app-release.apk
build_output/<构建号>/android/app-debug.apk
```

#### iOS
```bash
# Release 版本
./scripts/multi_build.sh ios --release

# Debug 版本
./scripts/multi_build.sh ios --debug
```

**产物位置:**
```
build/ios/iphoneos/Runner.app
```

**提示:**
- Release 版本需要用 Xcode 进行签名和导出
- Debug 版本可以直接连接设备运行

#### macOS
```bash
# Release 版本
./scripts/multi_build.sh macos --release

# Debug 版本
./scripts/multi_build.sh macos --debug
```

**产物位置:**
```
build_output/<构建号>/macos/im_sdk_demo.app
```

### 构建所有平台

```bash
# 不递增构建号
./scripts/multi_build.sh all --release

# 递增构建号（推荐）
./scripts/multi_build.sh all --release --increment
```

### 查看状态

```bash
# 查看所有平台构建状态
./scripts/multi_build.sh status
```

**输出示例:**
```
╔═══════════════════════════════════════════════════════════════════╗
║  构建状态                                                         ║
╚═══════════════════════════════════════════════════════════════════╝

  🔄 android: 构建中... (已运行: 02:15)
  ✅ ios: 构建成功
  ⚪ macos: 未运行
```

### 查看日志

```bash
# 查看指定平台日志
./scripts/multi_build.sh logs android
./scripts/multi_build.sh logs ios
./scripts/multi_build.sh logs macos
```

**实时日志:** 如果正在构建，日志会实时更新（Ctrl+C 退出）

### 查看产物

```bash
./scripts/multi_build.sh artifacts
```

**输出示例:**
```
╔═══════════════════════════════════════════════════════════════════╗
║  构建产物                                                         ║
╚═══════════════════════════════════════════════════════════════════╝

📦 构建号: 5
  ├─ android (2 个文件)
     └─ app-release.apk (45.2 MB)
  ├─ ios (1 个文件)
     └─ Runner.app
  └─ macos (1 个文件)
     └─ im_sdk_demo.app (128.5 MB)
```

### 停止构建

```bash
./scripts/multi_build.sh stop
```

### 清理构建

```bash
./scripts/multi_build.sh clean
```

**警告:** 此操作会删除所有构建产物和日志！

---

## 环境配置

### Java 环境

脚本会自动检测并配置 Android Studio 自带的 JDK：

```
/Applications/Android Studio.app/Contents/jbr/Contents/Home
```

如果需要手动设置：
```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
```

### Flutter

确保 Flutter 已安装：
```bash
flutter --version
```

### Android SDK

确保 `android/local.properties` 中配置了正确的 SDK 路径。

---

## 常见问题

### 1. 构建失败：找不到 Java

**解决方案:**
脚本会自动配置 JAVA_HOME。如果仍有问题，手动设置：
```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
```

### 2. iOS 构建失败：签名问题

**解决方案:**
- Debug 模式使用 `--no-codesign` 跳过签名
- Release 模式需要在 Xcode 中配置签名
- 打开 Xcode: `open ios/Runner.xcworkspace`

### 3. macOS 构建失败

**解决方案:**
- 确保 Xcode 命令行工具已安装
- 运行: `xcode-select --install`

### 4. 构建卡住

**解决方案:**
```bash
# 查看状态
./scripts/multi_build.sh status

# 停止构建
./scripts/multi_build.sh stop

# 查看日志找出问题
./scripts/multi_build.sh logs <platform>
```

---

## 工作流程建议

### 日常开发

```bash
# Debug 模式快速测试
./scripts/multi_build.sh android --debug

# 或直接用 Flutter
flutter run
```

### 内部测试

```bash
# 构建 Release 版本
./scripts/multi_build.sh all --release

# 查看状态
./scripts/multi_build.sh status

# 查看产物
./scripts/multi_build.sh artifacts
```

### 版本发布

```bash
# 递增构建号，构建所有平台
./scripts/multi_build.sh all --release --increment

# 等待构建完成...

# 检查产物
./scripts/multi_build.sh artifacts
```

---

## 高级用法

### 自定义构建号

```bash
# 手动设置构建号
echo "10" > .buildnumber

# 构建时会使用此构建号
./scripts/multi_build.sh all --release
```

### 并行构建

所有平台自动并行构建，无需额外配置。

### 查看构建时长

日志中会显示每次构建的耗时：
```
结束时间: 2026-03-10 15:30:45
耗时: 5分23秒
```

---

## 与其他脚本的关系

- `build.sh` - 原有的简单打包脚本
- `build_apk.sh` - Android APK 专用脚本
- `multi_build.sh` - 完整的多平台打包系统（推荐）

**建议:**
- 简单打包：使用 `build.sh`
- 仅 Android：使用 `build_apk.sh`
- 完整工作流：使用 `multi_build.sh`

---

## 技术细节

### 后台构建原理

使用 Bash 后台进程 (`&`) 和 PID 管理：
1. 构建在子进程中运行
2. PID 保存到 `.build_pids/` 目录
3. 脚本通过检查 PID 判断是否运行
4. 日志输出到 `.build_logs/` 目录

### 构建号管理

- 当前构建号存储在 `.buildnumber` 文件
- 使用 `--increment` 选项自动递增
- 每次构建的产物按构建号组织目录

### 日志格式

```
╔═══════════════════════════════════════════════════════════════════╗
║  构建 Android (release)                                            ║
╚═══════════════════════════════════════════════════════════════════╝

开始时间: 2026-03-10 15:25:22
构建号: 1
版本: 1.0.0+1

🧹 清理之前的构建...
📦 获取依赖...
🔨 构建 Android APK (release)...

✅ 构建成功

📋 复制产物...
📦 输出文件:
  📄 app-release.apk (45.2 MB)

结束时间: 2026-03-10 15:30:45
耗时: 5分23秒
```

---

## 更新日志

### v1.0.0 (2026-03-10)
- ✅ 初始版本
- ✅ 支持 Android、iOS、macOS 构建
- ✅ 后台构建支持
- ✅ 状态和日志查看
- ✅ 交互式菜单
- ✅ 版本管理

---

## 反馈与支持

如遇问题，请：
1. 查看构建日志: `./scripts/multi_build.sh logs <platform>`
2. 检查环境配置
3. 提交 Issue 到项目仓库

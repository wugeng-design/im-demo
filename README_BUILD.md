# Android APK 打包说明

## 环境要求

在打包 Android APK 之前，需要确保以下环境已正确配置：

### 1. Java 环境
项目使用 Android Studio 自带的 JDK（Java 21）。脚本会自动配置 JAVA_HOME：

```
/Applications/Android Studio.app/Contents/jbr/Contents/Home
```

### 2. Flutter
```bash
flutter --version
```

### 3. Android SDK
确保 `android/local.properties` 中配置了正确的 SDK 路径。

---

## 脚本说明

### 1. 通用打包脚本 `scripts/build.sh`
支持多平台打包（iOS、macOS、Android），已自动配置 JAVA_HOME。

**用法：**
```bash
./scripts/build.sh [ios|macos|android|apk] [--release|--debug]
```

**示例：**
```bash
# 构建 iOS Release 版本
./scripts/build.sh ios

# 构建 iOS Debug 版本
./scripts/build.sh ios --debug

# 构建 Android APK Release（推荐）
./scripts/build.sh apk

# 构建 Android APK Debug
./scripts/build.sh apk --debug

# 构建 Android App Bundle
./scripts/build.sh android
```

---

### 2. Android APK 专用脚本 `scripts/build_apk.sh`
专门用于安卓 APK 打包，已自动配置 JAVA_HOME。

**用法：**
```bash
./scripts/build_apk.sh [release|debug] [--split-per-abi]
```

**参数说明：**
- `release` 或 `debug`：指定构建类型（默认：release）
- `--split-per-abi`：按 CPU 架构拆分 APK（减小单个包体积）

**示例：**

```bash
# 1. 构建通用 Release APK（包含所有架构，体积较大）
./scripts/build_apk.sh release

# 2. 构建 Debug APK
./scripts/build_apk.sh debug

# 3. 按架构拆分 Release APK（推荐）
# 会生成三个文件：
# - app-armeabi-v7a-release.apk（32位 ARM）
# - app-arm64-v8a-release.apk（64位 ARM）
# - app-x86_64-release.apk（64位 x86）
./scripts/build_apk.sh release --split-per-abi

# 4. 按架构拆分 Debug APK
./scripts/build_apk.sh debug --split-per-abi
```

---

### 3. 环境检查脚本 `scripts/test_env.sh`
用于检查构建环境是否正确配置。

**用法：**
```bash
./scripts/test_env.sh
```

---

## APK 输出位置

构建完成后，APK 文件位于：

```
build/app/outputs/flutter-apk/
```

**文件说明：**

| 文件名 | 说明 |
|--------|------|
| `app-release.apk` | 通用 Release 版本（包含所有 CPU 架构） |
| `app-debug.apk` | 通用 Debug 版本 |
| `app-armeabi-v7a-release.apk` | 32位 ARM 架构 Release 版本 |
| `app-arm64-v8a-release.apk` | 64位 ARM 架构 Release 版本（推荐现代设备） |
| `app-x86_64-release.apk` | 64位 x86 架构 Release 版本（用于模拟器） |

---

## 手动打包（不使用脚本）

如果需要手动打包，请先设置 JAVA_HOME：

```bash
# 1. 设置 JAVA_HOME
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"

# 2. 构建 APK（Release）
flutter build apk --release

# 3. 构建 APK（Debug）
flutter build apk --debug

# 4. 按架构拆分构建
flutter build apk --release --split-per-abi
```

---

## 安装 APK 到设备

### 方法 1：使用 Flutter（推荐）
```bash
flutter install
```

### 方法 2：使用 adb
```bash
# 安装通用 APK
adb install build/app/outputs/flutter-apk/app-release.apk

# 安装指定架构的 APK
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

### 方法 3：手动传输
将 APK 文件通过 USB 或其他方式传输到安卓设备，然后在设备上点击安装。

---

## 常见问题

### 1. 脚本没有执行权限
```bash
chmod +x scripts/build.sh
chmod +x scripts/build_apk.sh
chmod +x scripts/test_env.sh
```

### 2. 构建失败：找不到 Java
**解决方案：** 脚本已自动配置 JAVA_HOME，如果仍有问题，手动设置：
```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
```

### 3. 构建失败：Gradle 插件版本不匹配
**解决方案：**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### 4. APK 无法安装
- Debug APK 可以直接安装
- Release APK 可能需要签名才能在其他设备上安装
- 检查手机的"允许安装未知来源应用"设置

### 5. 按 CPU 架构拆分 APK 的优势
- 减小单个 APK 的体积（可减小 30-40%）
- 用户只下载适合自己设备的版本
- 提高下载速度和安装成功率

---

## 推荐工作流程

1. **首次构建前：检查环境**
   ```bash
   ./scripts/test_env.sh
   ```

2. **开发调试阶段**：
   ```bash
   ./scripts/build_apk.sh debug
   ```

3. **发布测试**：
   ```bash
   ./scripts/build_apk.sh release --split-per-abi
   ```

4. **正式发布**：
   根据目标设备选择合适的架构 APK，或使用 App Bundle（AAB）：
   ```bash
   ./scripts/build.sh android  # 构建 AAB 用于上架应用商店
   ```

---

## 已修复的问题

### 问题：Gradle 插件版本不匹配
错误信息：
```
Plugin [id: 'org.gradle.kotlin.kotlin-dsl', version: '5.2.0'] was not found
```

**解决方案：**
脚本已自动配置 JAVA_HOME 指向 Android Studio 自带的 JDK（Java 21），确保与 Flutter 3.38.5 兼容。

### 问题：Java Runtime 未找到
错误信息：
```
Unable to locate a Java Runtime
```

**解决方案：**
脚本已自动检测并设置 JAVA_HOME 为 Android Studio 自带的 JDK 路径。

#!/bin/bash

# Android APK 专用打包脚本
# 用法: ./build_apk.sh [release|debug] [--split-per-abi]

set -e

cd "$(dirname "$0")/.."

# 设置 JAVA_HOME（使用 Android Studio 自带的 JDK）
if [ -z "$JAVA_HOME" ]; then
    if [ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]; then
        export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
        echo "Using JAVA_HOME: $JAVA_HOME"
    elif [ -d "/Applications/Android Studio.app/Contents/jre/Contents/Home" ]; then
        export JAVA_HOME="/Applications/Android Studio.app/Contents/jre/Contents/Home"
        echo "Using JAVA_HOME: $JAVA_HOME"
    fi
fi

BUILD_TYPE="${1:-release}"
SPLIT_ABI=""
TARGET_PLATFORM=""

# 解析参数
for arg in "$@"; do
    case "$arg" in
        --split-per-abi)
            SPLIT_ABI="--split-per-abi"
            ;;
        --arm-only)
            TARGET_PLATFORM="--target-platform android-arm,android-arm64"
            ;;
        release|debug)
            BUILD_TYPE="$arg"
            ;;
    esac
done

echo "=========================================="
echo "Android APK Build"
echo "Build Type: $BUILD_TYPE"
if [ -n "$SPLIT_ABI" ]; then
    echo "Split per ABI: Yes"
else
    echo "Split per ABI: No"
fi
if [ -n "$TARGET_PLATFORM" ]; then
    echo "Target Platform: ARM only (armeabi-v7a, arm64-v8a)"
else
    echo "Target Platform: Default (all supported)"
fi
echo "=========================================="
echo ""

# 检查 Flutter 环境
if ! command -v flutter &> /dev/null; then
    echo "错误: Flutter 未安装或未在 PATH 中"
    exit 1
fi

echo "1/5 清理之前的构建..."
flutter clean

echo ""
echo "2/5 获取依赖..."
flutter pub get

echo ""
echo "3/5 构建 Android APK ($BUILD_TYPE)..."
EXTRA_ARGS=""

if [ "$BUILD_TYPE" = "release" ]; then
    EXTRA_ARGS="$EXTRA_ARGS --obfuscate --split-debug-info=build/app/outputs/symbols"
fi

if [ -n "$TARGET_PLATFORM" ]; then
    EXTRA_ARGS="$EXTRA_ARGS $TARGET_PLATFORM"
fi

if [ -n "$SPLIT_ABI" ]; then
    flutter build apk --$BUILD_TYPE $SPLIT_ABI $EXTRA_ARGS
else
    flutter build apk --$BUILD_TYPE $EXTRA_ARGS
fi

echo ""
echo "=========================================="
echo "4/5 构建完成！"
echo "=========================================="

# 定位输出文件
BUILD_DIR="build/app/outputs/flutter-apk"

echo ""
echo "5/5 输出文件位置:"
echo "----------------------------------------"
find $BUILD_DIR -name "*.apk" -type f | while read file; do
    SIZE=$(du -h "$file" | cut -f1)
    echo "📦 $(basename $file)"
    echo "   路径: $file"
    echo "   大小: $SIZE"
    echo ""
done

echo "=========================================="
echo "安装 APK 到设备:"
echo "  flutter install"
echo ""
echo "或者使用 adb:"
if [ -n "$SPLIT_ABI" ]; then
    echo "  adb install build/app/outputs/flutter-apk/app-armeabi-v7a-$BUILD_TYPE.apk"
    echo "  adb install build/app/outputs/flutter-apk/app-arm64-v8a-$BUILD_TYPE.apk"
else
    echo "  adb install build/app/outputs/flutter-apk/app-$BUILD_TYPE.apk"
fi
echo "=========================================="
echo ""
echo "Done! ✓"

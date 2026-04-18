#!/bin/bash

# IM SDK Demo 打包脚本
# 用法: ./scripts/build.sh [ios|macos|android|apk] [--release|--debug]

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

PLATFORM="${1:-ios}"
BUILD_MODE="${2:---release}"

echo "=========================================="
echo "IM SDK Demo Build"
echo "Platform: $PLATFORM"
echo "Mode: $BUILD_MODE"
echo "=========================================="

case "$PLATFORM" in
    ios)
        echo "Building iOS..."
        flutter build ios $BUILD_MODE --no-codesign
        echo ""
        echo "iOS build complete!"
        echo "Output: build/ios/iphoneos/Runner.app"
        echo ""
        echo "To install on device, open Xcode:"
        echo "  open ios/Runner.xcworkspace"
        ;;
    macos)
        echo "Building macOS..."
        flutter build macos $BUILD_MODE
        echo ""
        echo "macOS build complete!"
        echo "Output: build/macos/Build/Products/Release/im_sdk_demo.app"
        ;;
    android)
        echo "Building Android App Bundle..."
        flutter build appbundle $BUILD_MODE
        echo ""
        echo "Android build complete!"
        echo "Output: build/app/outputs/bundle/release/app-release.aab"
        ;;
    apk)
        echo "Building Android APK..."
        
        EXTRA_ARGS=""
        if [ "$BUILD_MODE" = "--release" ]; then
            EXTRA_ARGS="$EXTRA_ARGS --obfuscate --split-debug-info=build/app/outputs/symbols"
        fi
        
        flutter build apk $BUILD_MODE $EXTRA_ARGS
        echo ""
        echo "=========================================="
        echo "APK build complete!"
        echo "=========================================="
        echo ""
        echo "输出文件位置:"
        find build/app/outputs/flutter-apk -name "*.apk" -type f | while read file; do
            SIZE=$(du -h "$file" | cut -f1)
            echo "📦 $(basename $file)"
            echo "   路径: $file"
            echo "   大小: $SIZE"
        done
        echo ""
        echo "安装到设备:"
        echo "  flutter install"
        echo ""
        echo "或者使用 adb:"
        echo "  adb install build/app/outputs/flutter-apk/app-$(echo $BUILD_MODE | sed 's/--//').apk"
        ;;
    *)
        echo "Usage: $0 [ios|macos|android|apk] [--release|--debug]"
        echo ""
        echo "Examples:"
        echo "  $0 ios           # Build iOS release"
        echo "  $0 macos         # Build macOS release"
        echo "  $0 apk --debug   # Build Android debug APK"
        exit 1
        ;;
esac

echo ""
echo "Done!"

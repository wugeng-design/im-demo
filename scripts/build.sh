#!/bin/bash

# IM SDK Demo 打包脚本
# 用法: ./scripts/build.sh [ios|macos|android|apk] [--release|--debug]

set -e

cd "$(dirname "$0")/.."

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
        flutter build apk $BUILD_MODE
        echo ""
        echo "APK build complete!"
        echo "Output: build/app/outputs/flutter-apk/app-release.apk"
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

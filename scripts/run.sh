#!/bin/bash

# IM SDK Demo 运行脚本
# 用法: ./scripts/run.sh [ios|macos|android]

set -e

cd "$(dirname "$0")/.."

PLATFORM="${1:-macos}"

echo "Running IM SDK Demo on $PLATFORM..."

case "$PLATFORM" in
    ios)
        flutter run -d ios
        ;;
    macos)
        flutter run -d macos
        ;;
    android)
        flutter run -d android
        ;;
    *)
        echo "Usage: $0 [ios|macos|android]"
        echo ""
        echo "Available devices:"
        flutter devices
        exit 1
        ;;
esac

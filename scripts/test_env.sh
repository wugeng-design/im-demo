#!/bin/bash

echo "=========================================="
echo "环境检查"
echo "=========================================="
echo ""

# 检查 Flutter
if command -v flutter &> /dev/null; then
    echo "✓ Flutter 已安装"
    flutter --version | head -1
else
    echo "✗ Flutter 未找到"
fi

echo ""

# 检查 Java
if [ -z "$JAVA_HOME" ]; then
    # 尝试设置 JAVA_HOME
    if [ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]; then
        export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
        echo "自动设置 JAVA_HOME: $JAVA_HOME"
    elif [ -d "/Applications/Android Studio.app/Contents/jre/Contents/Home" ]; then
        export JAVA_HOME="/Applications/Android Studio.app/Contents/jre/Contents/Home"
        echo "自动设置 JAVA_HOME: $JAVA_HOME"
    fi
fi

if [ -n "$JAVA_HOME" ]; then
    echo "✓ JAVA_HOME: $JAVA_HOME"
    $JAVA_HOME/bin/java -version 2>&1 | head -1
else
    echo "✗ JAVA_HOME 未设置"
fi

echo ""

# 检查 Android SDK
if [ -f "android/local.properties" ]; then
    SDK_DIR=$(grep "^sdk.dir=" android/local.properties | cut -d'=' -f2)
    if [ -d "$SDK_DIR" ]; then
        echo "✓ Android SDK: $SDK_DIR"
        ls -la "$SDK_DIR/build-tools" 2>/dev/null | tail -3
    else
        echo "✗ Android SDK 未找到"
    fi
fi

echo ""
echo "=========================================="
echo "Gradle 版本"
echo "=========================================="
cd "$(dirname "$0")/.."
cat android/gradle/wrapper/gradle-wrapper.properties | grep distributionUrl

echo ""
echo "=========================================="
echo "Flutter Gradle 插件"
echo "=========================================="
cat android/settings.gradle.kts | grep "id(" | head -3

echo ""
echo "=========================================="
echo "完成！"
echo "=========================================="

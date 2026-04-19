#!/bin/bash

# IM SDK Demo 打包脚本 - 优化版
# 参考 Light-1-Client 项目脚本结构
# 用法: ./scripts/build.sh [ios|macos|android|apk] [--release|--debug] [options]
# 选项:
#   --split-per-abi    按 ABI 拆分 APK (仅 Android)
#   --arm-only         仅构建 ARM 平台 (仅 Android)
#   --analyze-size     构建后分析 APK 体积 (仅 Android)
#   --no-clean         不执行 flutter clean (加速构建)
#   --no-codesign      不进行代码签名 (仅 iOS)

set -e

cd "$(dirname "$0")/.."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 设置 JAVA_HOME（使用 Android Studio 自带的 JDK）
if [ -z "$JAVA_HOME" ]; then
    if [ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]; then
        export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
        echo -e "${CYAN}Using JAVA_HOME: $JAVA_HOME${NC}"
    elif [ -d "/Applications/Android Studio.app/Contents/jre/Contents/Home" ]; then
        export JAVA_HOME="/Applications/Android Studio.app/Contents/jre/Contents/Home"
        echo -e "${CYAN}Using JAVA_HOME: $JAVA_HOME${NC}"
    fi
fi

# 默认值
PLATFORM="${1:-ios}"
BUILD_MODE="--release"
SPLIT_ABI=""
TARGET_PLATFORM=""
ANALYZE_SIZE=false
SKIP_CLEAN=false
NO_CODESIGN=false

# 解析参数
shift  # 移除第一个参数 (platform)
for arg in "$@"; do
    case "$arg" in
        --release|--debug)
            BUILD_MODE="$arg"
            ;;
        --split-per-abi)
            SPLIT_ABI="--split-per-abi"
            ;;
        --arm-only)
            TARGET_PLATFORM="--target-platform android-arm,android-arm64"
            ;;
        --analyze-size)
            ANALYZE_SIZE=true
            ;;
        --no-clean)
            SKIP_CLEAN=true
            ;;
        --no-codesign)
            NO_CODESIGN=true
            ;;
    esac
done

# 打印构建信息
print_build_info() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  IM SDK Demo Build Configuration${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "  ${CYAN}Platform:${NC}    $PLATFORM"
    echo -e "  ${CYAN}Mode:${NC}        $BUILD_MODE"
    
    if [ "$PLATFORM" = "apk" ] || [ "$PLATFORM" = "android" ]; then
        if [ -n "$SPLIT_ABI" ]; then
            echo -e "  ${CYAN}Split ABI:${NC}   Yes"
        fi
        if [ -n "$TARGET_PLATFORM" ]; then
            echo -e "  ${CYAN}ARM Only:${NC}    Yes"
        fi
        if [ "$ANALYZE_SIZE" = true ]; then
            echo -e "  ${CYAN}Analyze Size:${NC} Yes"
        fi
    fi
    
    if [ "$SKIP_CLEAN" = true ]; then
        echo -e "  ${CYAN}Clean:${NC}       Skipped"
    fi
    
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo ""
}

# 检查 Flutter 环境
check_environment() {
    echo -e "${CYAN}Checking Flutter environment...${NC}"
    
    if ! command -v flutter &> /dev/null; then
        echo -e "${RED}❌ 错误: Flutter 未安装或未在 PATH 中${NC}"
        exit 1
    fi
    
    FLUTTER_VERSION=$(flutter --version | head -1)
    echo -e "${GREEN}✅ Flutter: $FLUTTER_VERSION${NC}"
}

# 清理构建
clean_build() {
    if [ "$SKIP_CLEAN" = true ]; then
        echo -e "${YELLOW}Skipping flutter clean (--no-clean)${NC}"
        return
    fi
    
    echo -e "${CYAN}Cleaning previous build...${NC}"
    flutter clean
    echo -e "${GREEN}✅ Clean complete${NC}"
}

# 获取依赖
get_dependencies() {
    echo -e "${CYAN}Getting dependencies...${NC}"
    flutter pub get
    echo -e "${GREEN}✅ Dependencies updated${NC}"
}

# 构建 iOS
build_ios() {
    echo -e "${CYAN}Building iOS...${NC}"
    
    EXTRA_ARGS=""
    if [ "$NO_CODESIGN" = true ]; then
        EXTRA_ARGS="--no-codesign"
    fi
    
    flutter build ios $BUILD_MODE $EXTRA_ARGS
    
    echo ""
    echo -e "${GREEN}✅ iOS build complete!${NC}"
    echo -e "  Output: ${CYAN}build/ios/iphoneos/Runner.app${NC}"
    echo ""
    echo -e "To install on device, open Xcode:"
    echo -e "  ${GREEN}open ios/Runner.xcworkspace${NC}"
}

# 构建 macOS
build_macos() {
    echo -e "${CYAN}Building macOS...${NC}"
    
    flutter build macos $BUILD_MODE
    
    echo ""
    echo -e "${GREEN}✅ macOS build complete!${NC}"
    echo -e "  Output: ${CYAN}build/macos/Build/Products/Release/im_sdk_demo.app${NC}"
}

# 构建 Android App Bundle
build_android() {
    echo -e "${CYAN}Building Android App Bundle...${NC}"
    
    flutter build appbundle $BUILD_MODE
    
    echo ""
    echo -e "${GREEN}✅ Android App Bundle build complete!${NC}"
    echo -e "  Output: ${CYAN}build/app/outputs/bundle/release/app-release.aab${NC}"
}

# 构建 Android APK
build_apk() {
    echo -e "${CYAN}Building Android APK...${NC}"
    
    EXTRA_ARGS=""
    
    # 仅在 release 模式下启用混淆
    if [ "$BUILD_MODE" = "--release" ]; then
        EXTRA_ARGS="$EXTRA_ARGS --obfuscate --split-debug-info=build/app/outputs/symbols"
    fi
    
    # 添加目标平台
    if [ -n "$TARGET_PLATFORM" ]; then
        EXTRA_ARGS="$EXTRA_ARGS $TARGET_PLATFORM"
    fi
    
    # 添加体积分析
    if [ "$ANALYZE_SIZE" = true ]; then
        EXTRA_ARGS="$EXTRA_ARGS --analyze-size"
    fi
    
    # 构建命令
    BUILD_COMMAND="flutter build apk $BUILD_MODE"
    if [ -n "$SPLIT_ABI" ]; then
        BUILD_COMMAND="$BUILD_COMMAND $SPLIT_ABI"
    fi
    BUILD_COMMAND="$BUILD_COMMAND $EXTRA_ARGS"
    
    echo -e "${BLUE}  Command: $BUILD_COMMAND${NC}"
    eval $BUILD_COMMAND
    
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  APK Build Results${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Output files:${NC}"
    
    BUILD_DIR="build/app/outputs/flutter-apk"
    APK_COUNT=0
    TOTAL_SIZE=0
    
    while IFS= read -r file; do
        if [ -n "$file" ]; then
            APK_COUNT=$((APK_COUNT + 1))
            SIZE=$(du -k "$file" | cut -f1)
            SIZE_HUMAN=$(du -h "$file" | cut -f1)
            TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
            
            echo -e "  ${GREEN}📦 $(basename "$file")${NC}"
            echo -e "     路径: $file"
            echo -e "     大小: $SIZE_HUMAN"
            echo ""
        fi
    done < <(find "$BUILD_DIR" -name "*.apk" -type f 2>/dev/null)
    
    if [ $APK_COUNT -eq 0 ]; then
        echo -e "${RED}❌ No APK files found!${NC}"
        exit 1
    fi
    
    # 转换总大小为人类可读格式
    if [ $TOTAL_SIZE -ge 1048576 ]; then
        TOTAL_HUMAN=$(echo "scale=2; $TOTAL_SIZE/1048576" | bc)
        TOTAL_HUMAN="${TOTAL_HUMAN} GB"
    elif [ $TOTAL_SIZE -ge 1024 ]; then
        TOTAL_HUMAN=$(echo "scale=2; $TOTAL_SIZE/1024" | bc)
        TOTAL_HUMAN="${TOTAL_HUMAN} MB"
    else
        TOTAL_HUMAN="${TOTAL_SIZE} KB"
    fi
    
    echo -e "${CYAN}  Total:${NC} $APK_COUNT APK(s), $TOTAL_HUMAN"
    echo ""
    
    echo -e "${CYAN}Installation:${NC}"
    echo -e "  ${GREEN}flutter install${NC}"
    echo ""
    echo -e "Or using adb:"
    if [ -n "$SPLIT_ABI" ]; then
        MODE_NAME=$(echo $BUILD_MODE | sed 's/--//')
        echo -e "  ${GREEN}adb install build/app/outputs/flutter-apk/app-armeabi-v7a-$MODE_NAME.apk${NC}"
        echo -e "  ${GREEN}adb install build/app/outputs/flutter-apk/app-arm64-v8a-$MODE_NAME.apk${NC}"
    else
        echo -e "  ${GREEN}adb install build/app/outputs/flutter-apk/app-$(echo $BUILD_MODE | sed 's/--//').apk${NC}"
    fi
}

# 显示优化建议
show_optimization_tips() {
    if [ "$PLATFORM" = "apk" ] || [ "$PLATFORM" = "android" ]; then
        echo ""
        echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
        echo -e "${BLUE}  Android Size Optimization Tips${NC}"
        echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${CYAN}🚀 For smallest APK size:${NC}"
        echo -e "  1. Use --split-per-abi to create architecture-specific APKs"
        echo -e "  2. Use --arm-only if you don't need x86 support"
        echo -e "  3. Release build is always smaller than debug"
        echo ""
        echo -e "${CYAN}📦 Recommended command for production:${NC}"
        echo -e "  ${GREEN}./scripts/build.sh apk --split-per-abi --arm-only --analyze-size${NC}"
        echo ""
    fi
}

# 主函数
main() {
    START_TIME=$(date +%s)
    
    print_build_info
    check_environment
    
    if [ "$SKIP_CLEAN" != true ]; then
        clean_build
    fi
    get_dependencies
    
    case "$PLATFORM" in
        ios)
            build_ios
            ;;
        macos)
            build_macos
            ;;
        android)
            build_android
            ;;
        apk)
            build_apk
            ;;
        *)
            echo -e "${RED}Usage: $0 [ios|macos|android|apk] [--release|--debug] [options]${NC}"
            echo ""
            echo -e "Examples:"
            echo -e "  ${GREEN}$0 ios${NC}           # Build iOS release"
            echo -e "  ${GREEN}$0 macos${NC}         # Build macOS release"
            echo -e "  ${GREEN}$0 apk --debug${NC}   # Build Android debug APK"
            echo -e "  ${GREEN}$0 apk --split-per-abi --arm-only${NC}  # Optimized APK for production"
            echo ""
            exit 1
            ;;
    esac
    
    show_optimization_tips
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✅ Build Completed Successfully!${NC}"
    echo -e "${GREEN}  ⏱️  Total time: ${DURATION}s${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo ""
}

# 运行主函数
main

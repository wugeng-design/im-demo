#!/bin/bash

# Android APK 专用打包脚本 - 优化版
# 参考 Light-1-Client 项目脚本结构
# 用法: ./build_apk.sh [release|debug] [options]
# 选项:
#   --split-per-abi    按 ABI 拆分 APK (减小单包体积)
#   --arm-only         仅构建 ARM 平台 (armeabi-v7a, arm64-v8a)
#   --analyze-size     构建后分析 APK 体积
#   --no-clean         不执行 flutter clean (加速构建)
#   --verbose          显示详细构建日志

set -e

cd "$(dirname "$0")/.."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置
PROJECT_DIR="$(pwd)"
BUILD_DIR="$PROJECT_DIR/build/app/outputs/flutter-apk"
SYMBOLS_DIR="$PROJECT_DIR/build/app/outputs/symbols"

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
BUILD_TYPE="release"
SPLIT_ABI=""
TARGET_PLATFORM=""
ANALYZE_SIZE=false
SKIP_CLEAN=false
VERBOSE=false

# 解析参数
for arg in "$@"; do
    case "$arg" in
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
        --verbose)
            VERBOSE=true
            ;;
        release|debug)
            BUILD_TYPE="$arg"
            ;;
    esac
done

# 打印构建信息
print_build_info() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Android APK Build Configuration${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "  ${CYAN}Build Type:${NC}     $BUILD_TYPE"
    
    if [ "$BUILD_TYPE" = "release" ]; then
        echo -e "  ${CYAN}Obfuscation:${NC}    Enabled"
        echo -e "  ${CYAN}Split Debug:${NC}    $SYMBOLS_DIR"
    else
        echo -e "  ${CYAN}Obfuscation:${NC}    Disabled (debug mode)"
    fi
    
    if [ -n "$SPLIT_ABI" ]; then
        echo -e "  ${CYAN}Split ABI:${NC}      Yes (separate APKs per architecture)"
    else
        echo -e "  ${CYAN}Split ABI:${NC}      No (universal APK)"
    fi
    
    if [ -n "$TARGET_PLATFORM" ]; then
        echo -e "  ${CYAN}Target Platform:${NC} ARM only (armeabi-v7a, arm64-v8a)"
    else
        echo -e "  ${CYAN}Target Platform:${NC} Default (all supported)"
    fi
    
    if [ "$SKIP_CLEAN" = true ]; then
        echo -e "  ${CYAN}Clean Build:${NC}    Skipped (--no-clean)"
    else
        echo -e "  ${CYAN}Clean Build:${NC}    Enabled"
    fi
    
    if [ "$ANALYZE_SIZE" = true ]; then
        echo -e "  ${CYAN}Size Analysis:${NC}  Enabled"
    fi
    
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo ""
}

# 检查 Flutter 环境
check_environment() {
    echo -e "${CYAN}[1/6] Checking Flutter environment...${NC}"
    
    if ! command -v flutter &> /dev/null; then
        echo -e "${RED}❌ 错误: Flutter 未安装或未在 PATH 中${NC}"
        exit 1
    fi
    
    FLUTTER_VERSION=$(flutter --version | head -1)
    echo -e "${GREEN}✅ Flutter: $FLUTTER_VERSION${NC}"
    
    if command -v java &> /dev/null; then
        JAVA_VERSION=$(java -version 2>&1 | head -1)
        echo -e "${GREEN}✅ Java: $JAVA_VERSION${NC}"
    fi
}

# 清理构建
clean_build() {
    if [ "$SKIP_CLEAN" = true ]; then
        echo -e "${YELLOW}[2/6] Skipping flutter clean (--no-clean)${NC}"
        return
    fi
    
    echo -e "${CYAN}[2/6] Cleaning previous build...${NC}"
    flutter clean
    echo -e "${GREEN}✅ Clean complete${NC}"
}

# 获取依赖
get_dependencies() {
    echo -e "${CYAN}[3/6] Getting dependencies...${NC}"
    flutter pub get
    echo -e "${GREEN}✅ Dependencies updated${NC}"
}

# 构建 APK
build_apk() {
    echo -e "${CYAN}[4/6] Building Android APK ($BUILD_TYPE)...${NC}"
    
    EXTRA_ARGS=""
    
    if [ "$BUILD_TYPE" = "release" ]; then
        EXTRA_ARGS="$EXTRA_ARGS --obfuscate --split-debug-info=$SYMBOLS_DIR"
    fi
    
    if [ -n "$TARGET_PLATFORM" ]; then
        EXTRA_ARGS="$EXTRA_ARGS $TARGET_PLATFORM"
    fi
    
    if [ "$ANALYZE_SIZE" = true ]; then
        EXTRA_ARGS="$EXTRA_ARGS --analyze-size"
    fi
    
    BUILD_COMMAND="flutter build apk --$BUILD_TYPE"
    
    if [ -n "$SPLIT_ABI" ]; then
        BUILD_COMMAND="$BUILD_COMMAND $SPLIT_ABI"
    fi
    
    BUILD_COMMAND="$BUILD_COMMAND $EXTRA_ARGS"
    
    echo -e "${BLUE}  Command: $BUILD_COMMAND${NC}"
    echo ""
    
    if [ "$VERBOSE" = true ]; then
        eval $BUILD_COMMAND
    else
        eval $BUILD_COMMAND 2>&1 | tail -20
    fi
    
    BUILD_EXIT_CODE=${PIPESTATUS[0]}
    
    if [ $BUILD_EXIT_CODE -ne 0 ]; then
        echo -e "${RED}❌ Build failed with exit code $BUILD_EXIT_CODE${NC}"
        exit $BUILD_EXIT_CODE
    fi
    
    echo -e "${GREEN}✅ Build complete${NC}"
}

# 显示构建结果
show_results() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Build Results${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}[5/6] Output files:${NC}"
    echo -e "  Output directory: $BUILD_DIR"
    echo ""
    
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
}

# 显示安装指令
show_install_instructions() {
    echo -e "${CYAN}[6/6] Installation Instructions:${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [ -n "$SPLIT_ABI" ]; then
        echo -e "  ${YELLOW}Split ABI build detected${NC}"
        echo ""
        echo -e "  Install armeabi-v7a:"
        echo -e "    ${GREEN}adb install $BUILD_DIR/app-armeabi-v7a-$BUILD_TYPE.apk${NC}"
        echo ""
        echo -e "  Install arm64-v8a:"
        echo -e "    ${GREEN}adb install $BUILD_DIR/app-arm64-v8a-$BUILD_TYPE.apk${NC}"
    else
        echo -e "  Install universal APK:"
        echo -e "    ${GREEN}adb install $BUILD_DIR/app-$BUILD_TYPE.apk${NC}"
    fi
    
    echo ""
    echo -e "  Or using Flutter:"
    echo -e "    ${GREEN}flutter install${NC}"
    echo ""
    
    if [ "$BUILD_TYPE" = "release" ] && [ -d "$SYMBOLS_DIR" ]; then
        echo -e "${YELLOW}📊 Debug Symbols:${NC}"
        echo -e "  Location: $SYMBOLS_DIR"
        echo -e "  ${CYAN}Tip: Upload these symbols to Play Console for crash reporting${NC}"
        echo ""
    fi
}

# 体积优化建议
show_optimization_tips() {
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Size Optimization Tips${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${CYAN}🚀 For smallest APK size:${NC}"
    echo -e "  1. Use --split-per-abi to create architecture-specific APKs"
    echo -e "  2. Use --arm-only if you don't need x86 support"
    echo -e "  3. Release build is always smaller than debug"
    echo ""
    
    echo -e "${CYAN}📦 Recommended command for production:${NC}"
    echo -e "  ${GREEN}./scripts/build_apk.sh release --split-per-abi --arm-only --analyze-size${NC}"
    echo ""
    
    if [ "$ANALYZE_SIZE" = true ]; then
        echo -e "${CYAN}📊 Size Analysis:${NC}"
        echo -e "  Check the --analyze-size output above for detailed breakdown"
        echo ""
    fi
}

# 主函数
main() {
    START_TIME=$(date +%s)
    
    print_build_info
    
    check_environment
    clean_build
    get_dependencies
    build_apk
    show_results
    show_install_instructions
    show_optimization_tips
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✅ Build Completed Successfully!${NC}"
    echo -e "${GREEN}  ⏱️  Total time: ${DURATION}s${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo ""
}

# 运行主函数
main

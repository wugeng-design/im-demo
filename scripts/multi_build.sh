#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
# IM SDK Demo 多平台打包脚本
# ═══════════════════════════════════════════════════════════════════════════════
#
# 支持 iOS、Android、macOS 三平台打包
# 特点:
#   - 后台运行，不阻塞开发
#   - 并行构建多平台
#   - 自动配置 JAVA_HOME
#   - 统一的输出目录管理
#   - 详细的构建日志
#
# 用法:
#   ./scripts/multi_build.sh                  # 交互式菜单
#   ./scripts/multi_build.sh ios               # 构建 iOS
#   ./scripts/multi_build.sh android           # 构建 Android APK
#   ./scripts/multi_build.sh macos             # 构建 macOS
#   ./scripts/multi_build.sh all               # 构建所有平台
#   ./scripts/multi_build.sh status            # 查看构建状态
#   ./scripts/multi_build.sh logs ios          # 查看构建日志
#   ./scripts/multi_build.sh clean            # 清理所有构建
#
# 构建模式:
#   --debug      Debug 模式
#   --release    Release 模式（默认）
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# 脚本路径
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build_output"
LOG_DIR="$PROJECT_DIR/.build_logs"
PID_DIR="$PROJECT_DIR/.build_pids"
BUILD_NUM_FILE="$PROJECT_DIR/.buildnumber"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 默认配置
BUILD_MODE="release"
BUILD_NUMBER=1

# ═══════════════════════════════════════════════════════════════════════════════
# 工具函数
# ═══════════════════════════════════════════════════════════════════════════════

# 打印分隔线
print_header() {
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  $1${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 获取构建号
get_build_number() {
    if [[ -f "$BUILD_NUM_FILE" ]]; then
        BUILD_NUMBER=$(cat "$BUILD_NUM_FILE")
    else
        BUILD_NUMBER=1
    fi
    echo "$BUILD_NUMBER"
}

# 递增构建号
increment_build_number() {
    local current=$(get_build_number)
    BUILD_NUMBER=$((current + 1))
    echo "$BUILD_NUMBER" > "$BUILD_NUM_FILE"
    echo "$BUILD_NUMBER"
}

# 格式化时间
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))

    if [[ $hours -gt 0 ]]; then
        printf "%d小时%d分%d秒" $hours $minutes $secs
    elif [[ $minutes -gt 0 ]]; then
        printf "%d分%d秒" $minutes $secs
    else
        printf "%d秒" $secs
    fi
}

# 设置 JAVA_HOME
setup_java_home() {
    if [[ -z "$JAVA_HOME" ]]; then
        # 尝试 Android Studio 自带的 JDK
        if [[ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]]; then
            export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
        elif [[ -d "/Applications/Android Studio.app/Contents/jre/Contents/Home" ]]; then
            export JAVA_HOME="/Applications/Android Studio.app/Contents/jre/Contents/Home"
        fi
    fi
}

# 获取版本信息
get_version_info() {
    if [[ -f "$PROJECT_DIR/pubspec.yaml" ]]; then
        grep "^version:" "$PROJECT_DIR/pubspec.yaml" | awk '{print $2}'
    else
        echo "1.0.0"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# 平台构建函数
# ═══════════════════════════════════════════════════════════════════════════════

# 构建 Android
build_android() {
    local platform="android"
    local mode=$1
    local log_file="$LOG_DIR/${platform}_build.log"
    local output_dir="$BUILD_DIR/${BUILD_NUMBER}/${platform}"
    local start_time=$(date +%s)
    local success=false

    mkdir -p "$output_dir" "$LOG_DIR" "$PID_DIR"
    cd "$PROJECT_DIR"

    print_header "构建 Android ($mode)" | tee -a "$log_file"

    echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$log_file"
    echo "构建号: $BUILD_NUMBER" | tee -a "$log_file"
    echo "版本: $(get_version_info)" | tee -a "$log_file"
    echo "" | tee -a "$log_file"

    # 清理
    echo "🧹 清理之前的构建..." | tee -a "$log_file"
    flutter clean >> "$log_file" 2>&1 || true

    # 获取依赖
    echo "📦 获取依赖..." | tee -a "$log_file"
    flutter pub get >> "$log_file" 2>&1

    # 构建
    echo "🔨 构建 Android APK ($mode)..." | tee -a "$log_file"
    if flutter build apk --$mode >> "$log_file" 2>&1; then
        echo -e "${GREEN}✅ 构建成功${NC}" | tee -a "$log_file"

        # 复制产物
        echo "" | tee -a "$log_file"
        echo "📋 复制产物..." | tee -a "$log_file"
        cp -r build/app/outputs/flutter-apk/*.apk "$output_dir/" 2>/dev/null || true

        # 显示输出
        echo "" | tee -a "$log_file"
        echo "📦 输出文件:" | tee -a "$log_file"
        find "$output_dir" -name "*.apk" -type f | while read file; do
            local size=$(du -h "$file" | cut -f1)
            echo "  📄 $(basename "$file") ($size)" | tee -a "$log_file"
        done

        success=true
    else
        echo -e "${RED}❌ 构建失败${NC}" | tee -a "$log_file"
        success=false
    fi

    # 完成
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    echo "" | tee -a "$log_file"
    echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$log_file"
    echo "耗时: $(format_duration $duration)" | tee -a "$log_file"

    return 0
}

# 构建 iOS
build_ios() {
    local platform="ios"
    local mode=$1
    local log_file="$LOG_DIR/${platform}_build.log"
    local output_dir="$BUILD_DIR/${BUILD_NUMBER}/${platform}"
    local start_time=$(date +%s)
    local success=false

    mkdir -p "$output_dir" "$LOG_DIR" "$PID_DIR"
    cd "$PROJECT_DIR"

    print_header "构建 iOS ($mode)" | tee -a "$log_file"

    echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$log_file"
    echo "构建号: $BUILD_NUMBER" | tee -a "$log_file"
    echo "版本: $(get_version_info)" | tee -a "$log_file"
    echo "" | tee -a "$log_file"

    # 清理
    echo "🧹 清理之前的构建..." | tee -a "$log_file"
    flutter clean >> "$log_file" 2>&1 || true

    # 获取依赖
    echo "📦 获取依赖..." | tee -a "$log_file"
    flutter pub get >> "$log_file" 2>&1

    # 构建
    echo "🔨 构建 iOS ($mode)..." | tee -a "$log_file"
    local build_cmd="flutter build ios --$mode"
    if [[ "$mode" == "debug" ]]; then
        build_cmd="$build_cmd --no-codesign"
    fi

    if $build_cmd >> "$log_file" 2>&1; then
        echo -e "${GREEN}✅ 构建成功${NC}" | tee -a "$log_file"

        # iOS 产物位置
        echo "" | tee -a "$log_file"
        echo "📦 产物位置:" | tee -a "$log_file"
        echo "  build/ios/iphoneos/Runner.app" | tee -a "$log_file"
        echo "" | tee -a "$log_file"
        echo "💡 提示:" | tee -a "$log_file"
        if [[ "$mode" == "release" ]]; then
            echo "  • 使用 Xcode 进行签名和导出:" | tee -a "$log_file"
            echo "    open ios/Runner.xcworkspace" | tee -a "$log_file"
        else
            echo "  • Debug 构建，可直接连接设备运行:" | tee -a "$log_file"
            echo "    flutter run -d <device_id>" | tee -a "$log_file"
        fi

        success=true
    else
        echo -e "${RED}❌ 构建失败${NC}" | tee -a "$log_file"
        success=false
    fi

    # 完成
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    echo "" | tee -a "$log_file"
    echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$log_file"
    echo "耗时: $(format_duration $duration)" | tee -a "$log_file"

    return 0
}

# 构建 macOS
build_macos() {
    local platform="macos"
    local mode=$1
    local log_file="$LOG_DIR/${platform}_build.log"
    local output_dir="$BUILD_DIR/${BUILD_NUMBER}/${platform}"
    local start_time=$(date +%s)
    local success=false

    mkdir -p "$output_dir" "$LOG_DIR" "$PID_DIR"
    cd "$PROJECT_DIR"

    print_header "构建 macOS ($mode)" | tee -a "$log_file"

    echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$log_file"
    echo "构建号: $BUILD_NUMBER" | tee -a "$log_file"
    echo "版本: $(get_version_info)" | tee -a "$log_file"
    echo "" | tee -a "$log_file"

    # 清理
    echo "🧹 清理之前的构建..." | tee -a "$log_file"
    flutter clean >> "$log_file" 2>&1 || true

    # 获取依赖
    echo "📦 获取依赖..." | tee -a "$log_file"
    flutter pub get >> "$log_file" 2>&1

    # 构建
    echo "🔨 构建 macOS ($mode)..." | tee -a "$log_file"
    if flutter build macos --$mode >> "$log_file" 2>&1; then
        echo -e "${GREEN}✅ 构建成功${NC}" | tee -a "$log_file"

        # 复制产物
        echo "" | tee -a "$log_file"
        echo "📋 复制产物..." | tee -a "$log_file"
        local app_path="build/macos/Build/Products/${mode^}/im_sdk_demo.app"
        if [[ -d "$app_path" ]]; then
            cp -r "$app_path" "$output_dir/"
            local size=$(du -sh "$output_dir/im_sdk_demo.app" | cut -f1)
            echo "  📄 im_sdk_demo.app ($size)" | tee -a "$log_file"
        fi

        success=true
    else
        echo -e "${RED}❌ 构建失败${NC}" | tee -a "$log_file"
        success=false
    fi

    # 完成
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    echo "" | tee -a "$log_file"
    echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$log_file"
    echo "耗时: $(format_duration $duration)" | tee -a "$log_file"

    return 0
}

# 后台构建
build_platform_bg() {
    local platform=$1
    local mode=$2
    local log_file="$LOG_DIR/${platform}_build.log"
    local pid_file="$PID_DIR/${platform}.pid"

    cd "$PROJECT_DIR"

    case $platform in
        android)
            build_android "$mode"
            ;;
        ios)
            build_ios "$mode"
            ;;
        macos)
            build_macos "$mode"
            ;;
    esac

    rm -f "$pid_file"
}

# 启动后台构建
start_build() {
    local platform=$1
    local mode=$2
    local pid_file="$PID_DIR/${platform}.pid"

    mkdir -p "$PID_DIR"

    # 检查是否已在构建
    if [[ -f "$pid_file" ]]; then
        local existing_pid=$(cat "$pid_file")
        if ps -p "$existing_pid" > /dev/null 2>&1; then
            echo -e "${YELLOW}⚠️  $platform 正在构建中 (PID: $existing_pid)${NC}"
            return
        fi
        rm -f "$pid_file"
    fi

    echo -e "${GREEN}🚀 启动 $platform 后台构建 ($mode 模式, 构建号: $BUILD_NUMBER)...${NC}"

    # 后台启动
    (build_platform_bg "$platform" "$mode") &
    local pid=$!
    echo $pid > "$pid_file"

    echo -e "${CYAN}   PID: $pid${NC}"
    echo -e "${CYAN}   日志: .build_logs/${platform}_build.log${NC}"
    echo -e "${CYAN}   查看: $0 logs $platform${NC}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# 状态和日志
# ═══════════════════════════════════════════════════════════════════════════════

# 显示状态
show_status() {
    echo ""
    print_header "构建状态"

    for platform in android ios macos; do
        local pid_file="$PID_DIR/${platform}.pid"
        local log_file="$LOG_DIR/${platform}_build.log"

        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            if ps -p "$pid" > /dev/null 2>&1; then
                local elapsed=$(ps -o etime= -p "$pid" | xargs)
                echo -e "  ${YELLOW}🔄 $platform${NC}: 构建中... (已运行: $elapsed)"
            else
                rm -f "$pid_file"
                if [[ -f "$log_file" ]] && grep -q "✅ 构建成功" "$log_file"; then
                    echo -e "  ${GREEN}✅ $platform${NC}: 构建成功"
                else
                    echo -e "  ${RED}❌ $platform${NC}: 构建失败"
                fi
            fi
        else
            echo -e "  ${NC}⚪ $platform${NC}: 未运行"
        fi
    done

    echo ""
}

# 显示日志
show_logs() {
    local platform=$1
    local log_file="$LOG_DIR/${platform}_build.log"

    if [[ -f "$log_file" ]]; then
        print_header "$platform 构建日志"

        local pid_file="$PID_DIR/${platform}.pid"
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            if ps -p "$pid" > /dev/null 2>&1; then
                echo -e "${YELLOW}(实时日志，Ctrl+C 退出)${NC}"
                echo ""
                tail -f "$log_file"
            else
                cat "$log_file"
            fi
        else
            cat "$log_file"
        fi
    else
        echo -e "${RED}未找到 $platform 的构建日志${NC}"
    fi
}

# 显示产物
show_artifacts() {
    echo ""
    print_header "构建产物"

    if [[ -d "$BUILD_DIR" ]]; then
        for batch_dir in $(ls -dt "$BUILD_DIR"/*/ 2>/dev/null | head -3); do
            local batch_name=$(basename "$batch_dir")
            echo -e "${BLUE}📦 构建号: ${batch_name}${NC}"

            for platform in android ios macos; do
                local platform_dir="$batch_dir/$platform"
                if [[ -d "$platform_dir" ]]; then
                    local file_count=$(ls "$platform_dir" 2>/dev/null | wc -l | xargs)
                    if [[ $file_count -gt 0 ]]; then
                        echo -e "  ${CYAN}├─ $platform${NC} ($file_count 个文件)"
                        for file in "$platform_dir"/*; do
                            if [[ -f "$file" ]]; then
                                local size=$(du -h "$file" | cut -f1)
                                echo -e "  ${NC}   └─ $(basename "$file") ($size)"
                            elif [[ -d "$file" ]]; then
                                local size=$(du -sh "$file" | cut -f1)
                                echo -e "  ${NC}   └─ $(basename "$file") ($size)"
                            fi
                        done
                    fi
                fi
            done
            echo ""
        done
    else
        echo -e "${YELLOW}暂无构建产物${NC}"
    fi
}

# 停止所有构建
stop_builds() {
    echo -e "${YELLOW}停止所有构建...${NC}"

    for platform in android ios macos; do
        local pid_file="$PID_DIR/${platform}.pid"
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            if ps -p "$pid" > /dev/null 2>&1; then
                kill -9 "$pid" 2>/dev/null || true
                echo -e "  ${RED}已停止 $platform (PID: $pid)${NC}"
            fi
            rm -f "$pid_file"
        fi
    done

    echo -e "${GREEN}✅ 完成${NC}"
}

# 清理构建
clean_builds() {
    echo -e "${YELLOW}清理构建产物...${NC}"

    rm -rf "$BUILD_DIR" 2>/dev/null || true
    rm -rf "$LOG_DIR" 2>/dev/null || true
    rm -rf "$PID_DIR" 2>/dev/null || true

    echo -e "${GREEN}✅ 完成${NC}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# 交互菜单
# ═══════════════════════════════════════════════════════════════════════════════

interactive_menu() {
    while true; do
        clear
        print_header "IM SDK Demo 构建菜单"

        echo -e "${CYAN}当前版本:${NC} $(get_version_info)"
        echo -e "${CYAN}当前构建号:${NC} $(get_build_number)"
        echo ""

        echo "选择操作:"
        echo "  1) 构建 Android APK"
        echo "  2) 构建 iOS"
        echo "  3) 构建 macOS"
        echo "  4) 构建所有平台"
        echo "  5) 查看构建状态"
        echo "  6) 查看构建产物"
        echo "  7) 查看日志"
        echo "  8) 停止所有构建"
        echo "  9) 清理构建"
        echo "  0) 退出"
        echo ""

        read -p "请选择 [0-9]: " choice

        case $choice in
            1)
                read -p "构建模式 [debug/release]: " mode
                mode=${mode:-release}
                start_build android "$mode"
                ;;
            2)
                read -p "构建模式 [debug/release]: " mode
                mode=${mode:-release}
                start_build ios "$mode"
                ;;
            3)
                read -p "构建模式 [debug/release]: " mode
                mode=${mode:-release}
                start_build macos "$mode"
                ;;
            4)
                read -p "构建模式 [debug/release]: " mode
                mode=${mode:-release}
                read -p "是否递增构建号? [y/N]: " inc
                [[ "$inc" == "y" || "$inc" == "Y" ]] && BUILD_NUMBER=$(increment_build_number)
                start_build android "$mode"
                start_build ios "$mode"
                start_build macos "$mode"
                ;;
            5)
                show_status
                read -p "按 Enter 继续..."
                ;;
            6)
                show_artifacts
                read -p "按 Enter 继续..."
                ;;
            7)
                read -p "选择平台 [android/ios/macos]: " platform
                show_logs "$platform"
                ;;
            8)
                stop_builds
                read -p "按 Enter 继续..."
                ;;
            9)
                read -p "确认清理所有构建? [y/N]: " confirm
                [[ "$confirm" == "y" || "$confirm" == "Y" ]] && clean_builds
                ;;
            0)
                echo "退出"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                sleep 1
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# 主入口
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    mkdir -p "$BUILD_DIR" "$LOG_DIR" "$PID_DIR"

    # 设置 JAVA_HOME
    setup_java_home

    # 解析参数
    local command=""
    local platform=""
    local mode="release"
    local increment=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --debug)
                mode="debug"
                shift
                ;;
            --release)
                mode="release"
                shift
                ;;
            --increment)
                increment=true
                shift
                ;;
            android|ios|macos)
                platform="$1"
                command="build_single"
                shift
                ;;
            all)
                command="build_all"
                shift
                ;;
            status)
                show_status
                exit 0
                ;;
            logs)
                show_logs "$2"
                exit 0
                ;;
            artifacts)
                show_artifacts
                exit 0
                ;;
            stop|kill)
                stop_builds
                exit 0
                ;;
            clean)
                clean_builds
                exit 0
                ;;
            -h|--help)
                echo "用法: $0 [命令] [平台] [选项]"
                echo ""
                echo "命令:"
                echo "  android/ios/macos    构建指定平台"
                echo "  all                  构建所有平台"
                echo "  status               查看构建状态"
                echo "  logs <platform>      查看构建日志"
                echo "  artifacts            查看构建产物"
                echo "  stop                 停止所有构建"
                echo "  clean                清理所有构建"
                echo ""
                echo "选项:"
                echo "  --debug              Debug 模式"
                echo "  --release            Release 模式（默认）"
                echo "  --increment          递增构建号"
                echo ""
                echo "示例:"
                echo "  $0 android --release          # 构建 Android Release"
                echo "  $0 ios --debug               # 构建 iOS Debug"
                echo "  $0 all --release --increment  # 构建所有平台并递增构建号"
                echo "  $0 status                    # 查看构建状态"
                echo "  $0 logs android              # 查看 Android 构建日志"
                echo ""
                echo "交互模式:"
                echo "  $0                            # 进入交互菜单"
                exit 0
                ;;
            *)
                echo -e "${RED}未知参数: $1${NC}"
                echo "使用 $0 --help 查看帮助"
                exit 1
                ;;
        esac
    done

    # 执行命令
    case "$command" in
        build_single)
            [[ "$increment" == "true" ]] && BUILD_NUMBER=$(increment_build_number)
            start_build "$platform" "$mode"
            ;;
        build_all)
            [[ "$increment" == "true" ]] && BUILD_NUMBER=$(increment_build_number)
            start_build android "$mode"
            start_build ios "$mode"
            start_build macos "$mode"
            echo ""
            echo -e "${GREEN}✅ 所有平台已开始后台构建${NC}"
            echo -e "${CYAN}   查看状态: $0 status${NC}"
            echo -e "${CYAN}   查看日志: $0 logs <platform>${NC}"
            ;;
        "")
            # 交互模式
            interactive_menu
            ;;
    esac
}

main "$@"

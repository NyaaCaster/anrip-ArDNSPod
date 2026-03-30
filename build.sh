#!/bin/bash

# DNSPod DDNS Docker镜像构建脚本
# 用途：更新代码、重建镜像、重启容器

set -e

PROJECT_NAME="dnspod-ddns"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# 显示帮助
show_help() {
    echo "DNSPod DDNS Docker镜像构建脚本"
    echo ""
    echo "用法: ./build.sh [选项]"
    echo ""
    echo "选项:"
    echo "  all        执行所有步骤（默认）"
    echo "  pull       仅更新代码"
    echo "  build      仅构建镜像"
    echo "  restart    仅重启容器"
    echo "  clean      仅清理镜像"
    echo "  --skip-pull 跳过代码更新"
    echo "  -h, --help  显示帮助信息"
    echo ""
    echo "示例:"
    echo "  ./build.sh              # 执行所有步骤"
    echo "  ./build.sh --skip-pull  # 跳过代码更新"
    echo "  ./build.sh build        # 仅构建镜像"
}

# 更新代码
update_code() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  步骤 1/6: 更新代码${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    cd "$PROJECT_DIR"
    
    if [ -d ".git" ]; then
        echo -e "${YELLOW}正在从 GitHub 拉取最新代码...${NC}"
        if git pull origin main; then
            echo -e "${GREEN}✓ 代码更新成功${NC}"
        else
            echo -e "${RED}✗ 代码更新失败${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}! 不是Git仓库，跳过代码更新${NC}"
    fi
    
    echo ""
}

# 停止容器
stop_container() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  步骤 2/6: 停止容器${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    if docker ps -a --filter "name=$PROJECT_NAME" --format "{{.Names}}" | grep -q "$PROJECT_NAME"; then
        echo -e "${YELLOW}正在停止容器 $PROJECT_NAME ...${NC}"
        docker stop "$PROJECT_NAME" 2>/dev/null || true
        echo -e "${GREEN}✓ 容器已停止${NC}"
    else
        echo -e "${YELLOW}! 容器不存在，跳过停止${NC}"
    fi
    
    echo ""
}

# 删除旧镜像
remove_old_image() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  步骤 3/6: 删除旧镜像${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    local images=$(docker images --filter "reference=$PROJECT_NAME*" --format "{{.Repository}}:{{.Tag}}")
    
    if [ -n "$images" ]; then
        echo -e "${YELLOW}正在删除旧镜像...${NC}"
        echo "$images" | xargs docker rmi -f 2>/dev/null || true
        echo -e "${GREEN}✓ 旧镜像已删除${NC}"
    else
        echo -e "${YELLOW}! 未找到旧镜像，跳过删除${NC}"
    fi
    
    echo ""
}

# 构建镜像
build_image() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  步骤 4/6: 构建镜像${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    cd "$PROJECT_DIR"
    
    echo -e "${YELLOW}正在构建镜像 $PROJECT_NAME ...${NC}"
    if docker-compose build --no-cache; then
        echo -e "${GREEN}✓ 镜像构建成功${NC}"
    else
        echo -e "${RED}✗ 镜像构建失败${NC}"
        return 1
    fi
    
    echo ""
}

# 启动容器
start_container() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  步骤 5/6: 启动容器${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    cd "$PROJECT_DIR"
    
    echo -e "${YELLOW}正在启动容器 $PROJECT_NAME ...${NC}"
    if docker-compose up -d; then
        echo -e "${GREEN}✓ 容器启动成功${NC}"
        echo ""
        echo -e "${YELLOW}容器状态:${NC}"
        docker ps --filter "name=$PROJECT_NAME"
    else
        echo -e "${RED}✗ 容器启动失败${NC}"
        return 1
    fi
    
    echo ""
}

# 清理悬空镜像
clean_dangling_images() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  步骤 6/6: 清理悬空镜像${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    local dangling=$(docker images -f "dangling=true" -q)
    
    if [ -n "$dangling" ]; then
        echo -e "${YELLOW}正在清理悬空镜像...${NC}"
        docker image prune -f
        echo -e "${GREEN}✓ 悬空镜像已清理${NC}"
    else
        echo -e "${YELLOW}! 没有悬空镜像，跳过清理${NC}"
    fi
    
    echo ""
}

# 显示总结
show_summary() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  构建完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}常用命令:${NC}"
    echo "  查看日志:     docker logs -f $PROJECT_NAME"
    echo "  手动更新:     docker exec $PROJECT_NAME /app/ddnspod.sh"
    echo "  重启容器:     docker restart $PROJECT_NAME"
    echo "  停止容器:     docker stop $PROJECT_NAME"
    echo ""
}

# 主程序
ACTION="all"
SKIP_PULL=false

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        pull|build|restart|clean|all)
            ACTION="$1"
            shift
            ;;
        --skip-pull)
            SKIP_PULL=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}未知选项: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

echo ""
echo -e "${MAGENTA}========================================${NC}"
echo -e "${MAGENTA}  DNSPod DDNS Docker 镜像构建脚本${NC}"
echo -e "${MAGENTA}========================================${NC}"
echo ""

cd "$PROJECT_DIR"

case "$ACTION" in
    pull)
        if [ "$SKIP_PULL" = false ]; then
            update_code
        fi
        ;;
    build)
        build_image
        ;;
    restart)
        stop_container
        start_container
        ;;
    clean)
        clean_dangling_images
        ;;
    *)
        if [ "$SKIP_PULL" = false ]; then
            update_code
        fi
        stop_container
        remove_old_image
        build_image
        start_container
        clean_dangling_images
        show_summary
        ;;
esac

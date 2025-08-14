#!/bin/bash

# 多架构 Docker 镜像构建脚本
# 支持 AMD64 和 ARM64 架构

set -e

# 配置变量
IMAGE_NAME="gemini-antiblock"
TAG="${1:-latest}"
REGISTRY="${2:-}"

# 如果提供了注册表地址，添加前缀
if [ -n "$REGISTRY" ]; then
    FULL_IMAGE_NAME="$REGISTRY/$IMAGE_NAME"
else
    FULL_IMAGE_NAME="$IMAGE_NAME"
fi

echo "=== 开始构建多架构 Docker 镜像 ==="
echo "镜像名称: $FULL_IMAGE_NAME:$TAG"
echo "支持架构: linux/amd64, linux/arm64"

# 检查 Docker buildx 是否可用
if ! docker buildx version > /dev/null 2>&1; then
    echo "错误: Docker buildx 不可用，请确保 Docker 版本支持 buildx"
    exit 1
fi

# 创建并使用新的 builder 实例（如果不存在）
BUILDER_NAME="multiarch-builder"
if ! docker buildx ls | grep -q "$BUILDER_NAME"; then
    echo "创建新的 buildx builder: $BUILDER_NAME"
    docker buildx create --name "$BUILDER_NAME" --driver docker-container --bootstrap
fi

echo "使用 builder: $BUILDER_NAME"
docker buildx use "$BUILDER_NAME"

# 构建并推送多架构镜像
echo "开始构建多架构镜像..."
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --tag "$FULL_IMAGE_NAME:$TAG" \
    --push \
    .

echo "=== 构建完成 ==="
echo "镜像已推送到: $FULL_IMAGE_NAME:$TAG"
echo ""
echo "使用方法:"
echo "  docker run -p 8080:8080 -e GEMINI_API_KEY=your_key $FULL_IMAGE_NAME:$TAG"
echo ""
echo "支持的架构:"
echo "  - linux/amd64"
echo "  - linux/arm64"

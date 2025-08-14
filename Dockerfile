# 多阶段构建 Dockerfile，支持 AMD64 和 ARM64 架构
# 使用官方 Go 镜像作为构建阶段
FROM --platform=$BUILDPLATFORM golang:1.21-alpine AS builder

# 设置构建参数
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH

# 安装必要的构建工具
RUN apk add --no-cache git ca-certificates tzdata

# 设置工作目录
WORKDIR /app

# 复制 go mod 文件
COPY go.mod go.sum ./

# 下载依赖
RUN go mod download

# 复制源代码
COPY . .

# 构建应用程序
# 使用 CGO_ENABLED=0 确保静态链接，便于在最小镜像中运行
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o gemini-antiblock \
    main.go

# 运行阶段：使用最小的 scratch 镜像
FROM scratch

# 从构建阶段复制 CA 证书（HTTPS 请求需要）
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# 从构建阶段复制时区数据
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# 从构建阶段复制编译好的二进制文件
COPY --from=builder /app/gemini-antiblock /gemini-antiblock

# 复制环境变量示例文件（可选）
COPY --from=builder /app/.env.example /.env.example

# 设置默认环境变量
ENV PORT=8080
ENV UPSTREAM_URL_BASE=https://generativelanguage.googleapis.com
ENV MAX_CONSECUTIVE_RETRIES=100
ENV DEBUG_MODE=true
ENV RETRY_DELAY_MS=750
ENV SWALLOW_THOUGHTS_AFTER_RETRY=true

# 暴露端口
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ["/gemini-antiblock", "--health-check"] || exit 1

# 运行应用程序
ENTRYPOINT ["/gemini-antiblock"]

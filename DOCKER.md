# Docker 部署指南

本文档介绍如何使用 Docker 部署 Gemini Antiblock Proxy。

## 快速开始

### 1. 使用 Docker 运行

```bash
# 基本运行
docker run -p 8080:8080 gemini-antiblock:latest

# 带环境变量运行
docker run -p 8080:8080 \
  -e UPSTREAM_URL_BASE=https://generativelanguage.googleapis.com \
  -e MAX_CONSECUTIVE_RETRIES=100 \
  -e DEBUG_MODE=true \
  gemini-antiblock:latest
```

### 2. 使用 Docker Compose

```bash
# 启动服务
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

## 构建镜像

### 单架构构建

```bash
# 构建当前架构镜像
docker build -t gemini-antiblock:latest .
```

### 多架构构建

```bash
# 使用提供的脚本构建多架构镜像
chmod +x build-multiarch.sh
./build-multiarch.sh latest

# 或者推送到自定义注册表
./build-multiarch.sh latest your-registry.com
```

### 手动多架构构建

```bash
# 创建 buildx builder
docker buildx create --name multiarch-builder --driver docker-container --bootstrap
docker buildx use multiarch-builder

# 构建并推送多架构镜像
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag gemini-antiblock:latest \
  --push .
```

## 环境变量配置

| 变量名                         | 默认值                                      | 描述                       |
| ------------------------------ | ------------------------------------------- | -------------------------- |
| `UPSTREAM_URL_BASE`            | `https://generativelanguage.googleapis.com` | Gemini API 的基础 URL      |
| `MAX_CONSECUTIVE_RETRIES`      | `100`                                       | 流中断时的最大连续重试次数 |
| `DEBUG_MODE`                   | `true`                                      | 是否启用调试日志           |
| `RETRY_DELAY_MS`               | `750`                                       | 重试间隔时间（毫秒）       |
| `SWALLOW_THOUGHTS_AFTER_RETRY` | `true`                                      | 重试后是否过滤思考内容     |
| `PORT`                         | `8080`                                      | 服务器监听端口             |

## 生产部署建议

### 1. 资源限制

```yaml
# docker-compose.yml 中的资源限制示例
deploy:
  resources:
    limits:
      memory: 256M
      cpus: '0.5'
    reservations:
      memory: 128M
      cpus: '0.25'
```

### 2. 健康检查

容器包含内置的健康检查，会定期检查服务状态。

### 3. 日志管理

```bash
# 查看实时日志
docker logs -f <container_name>

# 限制日志大小
docker run --log-opt max-size=10m --log-opt max-file=3 gemini-antiblock:latest
```

### 4. 安全考虑

- 容器以非 root 用户运行（UID 65534）
- 使用最小的 scratch 基础镜像
- 静态编译的二进制文件，无外部依赖

## 支持的架构

- `linux/amd64` - Intel/AMD 64位处理器
- `linux/arm64` - ARM 64位处理器（如 Apple M1/M2, AWS Graviton）

## 故障排除

### 1. 容器无法启动

```bash
# 检查容器日志
docker logs <container_name>

# 检查端口占用
netstat -tulpn | grep 8080
```

### 2. 健康检查失败

```bash
# 手动执行健康检查
docker exec <container_name> /gemini-antiblock --health-check
```

### 3. 网络连接问题

```bash
# 测试容器网络
docker exec <container_name> wget --spider https://generativelanguage.googleapis.com
```

## 示例部署配置

### Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gemini-antiblock
spec:
  replicas: 2
  selector:
    matchLabels:
      app: gemini-antiblock
  template:
    metadata:
      labels:
        app: gemini-antiblock
    spec:
      containers:
      - name: gemini-antiblock
        image: gemini-antiblock:latest
        ports:
        - containerPort: 8080
        env:
        - name: DEBUG_MODE
          value: "false"
        - name: MAX_CONSECUTIVE_RETRIES
          value: "50"
        resources:
          limits:
            memory: "256Mi"
            cpu: "500m"
          requests:
            memory: "128Mi"
            cpu: "250m"
```

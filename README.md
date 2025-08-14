# Gemini Antiblock Proxy (Go 版本)

这是一个用 Go 语言重写的 Gemini API 代理服务器，具有强大的流式重试和标准化错误响应功能。它可以处理模型的"思考"过程，并在重试后过滤思考内容以保持干净的输出流。

## 功能特性

- **流式响应处理**: 支持 Server-Sent Events (SSE)流式响应
- **智能重试机制**: 当流被中断时自动重试，最多支持 100 次连续重试
- **思考内容过滤**: 可以在重试后过滤模型的思考过程，保持输出的整洁
- **标准化错误响应**: 提供符合 Google API 标准的错误响应格式
- **CORS 支持**: 完整的跨域资源共享支持
- **环境变量配置**: 通过环境变量进行灵活配置
- **详细日志记录**: 支持调试模式和详细的操作日志

## 安装和运行

### 方式一：使用 Docker（推荐）

#### 快速开始

```bash
# 拉取镜像
docker pull gua12345/gemini-antiblock:latest

# 运行容器
docker run -p 8080:8080 gua12345/gemini-antiblock:latest
```

#### 带环境变量运行

```bash
docker run -p 18787:8080 \
  -e UPSTREAM_URL_BASE=https://generativelanguage.googleapis.com \
  -e MAX_CONSECUTIVE_RETRIES=100 \
  -e DEBUG_MODE=true \
  -e RETRY_DELAY_MS=750 \
  -e SWALLOW_THOUGHTS_AFTER_RETRY=true \
  gua12345/gemini-antiblock:latest
```

#### 使用 docker-compose

```bash
# 下载 docker-compose.yml 文件后
docker-compose up -d
```

### 方式二：从源码编译

#### 前置要求

- Go 1.21 或更高版本

#### 安装依赖

```bash
go mod download
```

#### 配置

1. 复制环境变量示例文件：

```bash
cp .env.example .env
```

2. 编辑 `.env` 文件配置你的设置：

```bash
# Gemini API基础URL
UPSTREAM_URL_BASE=https://generativelanguage.googleapis.com

# 最大连续重试次数
MAX_CONSECUTIVE_RETRIES=100

# 启用调试模式
DEBUG_MODE=true

# 重试延迟（毫秒）
RETRY_DELAY_MS=750

# 重试后是否吞掉思考内容
SWALLOW_THOUGHTS_AFTER_RETRY=true

# 服务器端口
PORT=8080
```

#### 运行

```bash
go run main.go
```

或者编译后运行：

```bash
go build -o gemini-antiblock
./gemini-antiblock
```

服务器将在指定端口启动（默认 8080）。

## 环境变量配置

| 变量名                         | 默认值                                      | 描述                       |
| ------------------------------ | ------------------------------------------- | -------------------------- |
| `UPSTREAM_URL_BASE`            | `https://generativelanguage.googleapis.com` | Gemini API 的基础 URL      |
| `MAX_CONSECUTIVE_RETRIES`      | `10`                                       | 连续重试的最大次数 |
| `DEBUG_MODE`                   | `true`                                      | 是否启用调试日志           |
| `RETRY_DELAY_MS`               | `250`                                       | 重试间隔时间（毫秒）       |
| `SWALLOW_THOUGHTS_AFTER_RETRY` | `true`                                      | 重试后是否过滤思考内容     |
| `PORT`                         | `8080`                                      | 服务器监听端口             |

## 使用方法

代理服务器启动后，你可以将 Gemini API 的请求发送到这个代理服务器。代理会自动：

1. 转发请求到上游 Gemini API
2. 处理流式响应
3. 在流中断时自动重试
4. 注入系统提示确保响应以`[done]`结尾
5. 过滤重试后的思考内容（如果启用）

### 示例请求

```bash
curl "http://127.0.0.1:8080/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse"   -H "x-goog-api-key: $GEMINI_API_KEY"   -H 'Content-Type: application/json'   -X POST --no-buffer  -d '{ 
    "contents": [
      {
        "role": "user",
        "parts": [
          {
            "text": "Hello"
          }
        ]
      }
    ],
    "generationConfig": {
      "thinkingConfig": {
        "includeThoughts": true
      }
    }
  }'
```

## 项目结构

```
gemini-antiblock-go/
├── main.go                 # 主程序入口
├── config/
│   └── config.go          # 配置管理
├── logger/
│   └── logger.go          # 日志记录
├── handlers/
│   ├── errors.go          # 错误处理和CORS
│   └── proxy.go           # 代理处理逻辑
├── streaming/
│   ├── sse.go             # SSE流处理
│   └── retry.go           # 重试逻辑
├── go.mod                 # Go模块文件
├── go.sum                 # 依赖校验和
├── .env.example           # 环境变量示例
└── README.md              # 项目文档
```

## 重试机制

当检测到以下情况时，代理会自动重试：

1. **流中断**: 流意外结束而没有完成标记
2. **内容被阻止**: 检测到内容被过滤或阻止
3. **思考中完成**: 在思考块中检测到完成标记（无效状态）
4. **异常完成原因**: 非正常的完成原因
5. **不完整响应**: 响应看起来不完整

### 重试计数逻辑

- **重试计数器**: 每次流中断时计数器+1
- **成功重置**: 每次重试成功获得新流后，计数器重置为0
- **独立周期**: 每次中断都开始一个新的重试周期，最多允许连续重试 `MAX_CONSECUTIVE_RETRIES` 次

**示例场景**（假设 `MAX_CONSECUTIVE_RETRIES=100`）：
```
初始请求 → 中断 → 计数=1 → 重试成功 → 计数重置为0
新流处理 → 中断 → 计数=1 → 重试成功 → 计数重置为0
新流处理 → 中断 → 计数=1 → 重试中断 → 计数=2 → 重试成功 → 计数重置为0
```

重试时会：

- 保留已生成的文本作为上下文
- 构建继续对话的新请求
- 在单个重试周期达到最大重试次数后返回错误

## 日志记录

代理提供三个级别的日志：

- **DEBUG**: 详细的调试信息（仅在调试模式下显示）
- **INFO**: 一般信息和操作状态
- **ERROR**: 错误信息和异常

## Docker 部署

### 支持的架构

- `linux/amd64` - Intel/AMD 64位处理器
- `linux/arm64` - ARM 64位处理器（如 Apple M1/M2, AWS Graviton）

### 镜像信息

- **镜像地址**: `gua12345/gemini-antiblock:latest`
- **基础镜像**: scratch（最小化镜像）
- **镜像大小**: < 20MB
- **安全特性**: 非 root 用户运行

### 生产部署示例

```bash
# 后台运行，自动重启
docker run -d \
  --name gemini-antiblock \
  --restart unless-stopped \
  -p 8080:8080 \
  -e DEBUG_MODE=false \
  -e MAX_CONSECUTIVE_RETRIES=50 \
  gua12345/gemini-antiblock:latest
```

### 健康检查

容器包含内置健康检查，可以通过以下方式查看状态：

```bash
# 查看容器健康状态
docker ps

# 查看详细健康检查日志
docker inspect --format='{{.State.Health}}' <container_name>
```

更多 Docker 部署信息请参考 [DOCKER.md](DOCKER.md)。

## 许可证

MIT License

## 原始版本

这是基于 Cloudflare Worker 版本的 Go 语言重写版本。原始 JavaScript 版本提供了相同的功能，但运行在 Cloudflare Workers 平台上。

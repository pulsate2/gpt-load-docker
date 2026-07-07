FROM ghcr.io/tbphp/gpt-load:latest

# 安装 cloudflared（支持 amd64 / arm64）
RUN apk add --no-cache ca-certificates curl && \
    ARCH=$(uname -m) && \
    case ${ARCH} in \
      x86_64)  URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" ;; \
      aarch64|arm64) URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" ;; \
      *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
    esac && \
    curl -L --fail "${URL}" -o /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared && \
    apk del curl

# 使用 heredoc 创建 entrypoint（推荐方式）
COPY <<'EOF' /entrypoint.sh
#!/bin/sh
set -e

echo "=== GPT-Load + Cloudflare Tunnel ==="

# 如果设置了 Token，则后台启动 Cloudflare Tunnel
if [ -n "$CF_TUNNEL_TOKEN" ]; then
    echo "🚀 启动 Cloudflare Tunnel (token 前15字符: ${CF_TUNNEL_TOKEN:0:15}...)"
    cloudflared tunnel --no-autoupdate run --token "$CF_TUNNEL_TOKEN" &
    echo "Cloudflare Tunnel 已后台启动"
else
    echo "⚠️  未设置 CF_TUNNEL_TOKEN 环境变量，Tunnel 未启动（仅本地访问）"
fi

echo "🚀 启动 GPT-Load 主服务（端口 3001）..."
exec "$@"
EOF

RUN chmod +x /entrypoint.sh

EXPOSE 3001

ENTRYPOINT ["/entrypoint.sh"]

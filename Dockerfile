FROM ghcr.io/tbphp/gpt-load:latest

# 安装 cloudflared 和必要工具
RUN apk add --no-cache ca-certificates curl tzdata && \
    ARCH=$(uname -m) && \
    case ${ARCH} in \
      x86_64)  URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" ;; \
      aarch64|arm64) URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" ;; \
      *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
    esac && \
    curl -L --fail "${URL}" -o /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared && \
    mkdir -p /var/log

# 创建 entrypoint
COPY <<'EOF' /entrypoint.sh
#!/bin/sh
set -e

echo "=== GPT-Load + Cloudflare Tunnel ==="

# 优雅退出处理
cleanup() {
    echo "🛑 正在停止服务..."
    pkill -TERM cloudflared 2>/dev/null || true
    exit 0
}
trap cleanup TERM INT

if [ -n "$CF_TUNNEL_TOKEN" ]; then
    echo "🚀 启动 Cloudflare Tunnel (token 前20字符: ${CF_TUNNEL_TOKEN:0:20}...)"
    cloudflared tunnel --no-autoupdate run --token "$CF_TUNNEL_TOKEN" > /var/log/cloudflared.log 2>&1 &
    echo "✅ Cloudflare Tunnel 已后台启动（日志: /var/log/cloudflared.log）"
else
    echo "⚠️  未设置 CF_TUNNEL_TOKEN，Tunnel 未启动"
fi

echo "🚀 启动 GPT-Load 主服务..."
exec /app/gpt-load
EOF

RUN chmod +x /entrypoint.sh

EXPOSE 3001

ENTRYPOINT ["/entrypoint.sh"]

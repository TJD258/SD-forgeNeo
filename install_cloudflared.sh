#!/bin/bash
########################################
# 快速安装 cloudflared (使用国内镜像)
########################################

echo "=========================================="
echo "  安装 cloudflared"
echo "=========================================="
echo ""

# 检查是否已安装
if command -v cloudflared &> /dev/null; then
    echo "✓ cloudflared 已安装: $(cloudflared --version)"
    exit 0
fi

# 下载目录
DOWNLOAD_DIR="/tmp"
CLOUDFLARED_BIN="/usr/local/bin/cloudflared"

echo "正在下载 cloudflared..."
echo ""

# 方案 1: 使用 ghproxy 镜像 (最快)
echo "[1/3] 尝试 ghproxy 镜像..."
wget -q --timeout=15 --tries=2 \
    https://mirror.ghproxy.com/https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    -O "$DOWNLOAD_DIR/cloudflared" 2>/dev/null

if [ $? -eq 0 ] && [ -f "$DOWNLOAD_DIR/cloudflared" ]; then
    echo "✓ 下载成功 (ghproxy)"
else
    # 方案 2: 使用其他 GitHub 镜像
    echo "[2/3] 尝试 gitproxy 镜像..."
    wget -q --timeout=15 --tries=2 \
        https://gitproxy.click/https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
        -O "$DOWNLOAD_DIR/cloudflared" 2>/dev/null
    
    if [ $? -eq 0 ] && [ -f "$DOWNLOAD_DIR/cloudflared" ]; then
        echo "✓ 下载成功 (gitproxy)"
    else
        # 方案 3: 直接从 GitHub 下载
        echo "[3/3] 尝试直接从 GitHub 下载..."
        wget -q --timeout=30 \
            https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
            -O "$DOWNLOAD_DIR/cloudflared" 2>/dev/null
        
        if [ $? -eq 0 ] && [ -f "$DOWNLOAD_DIR/cloudflared" ]; then
            echo "✓ 下载成功 (GitHub)"
        else
            echo "❌ 所有下载方式都失败了!"
            echo ""
            echo "手动安装方法:"
            echo "1. 在浏览器打开: https://github.com/cloudflare/cloudflared/releases/latest"
            echo "2. 下载 cloudflared-linux-amd64"
            echo "3. 上传到云端 /usr/local/bin/cloudflared"
            echo "4. 运行: chmod +x /usr/local/bin/cloudflared"
            exit 1
        fi
    fi
fi

# 安装
echo ""
echo "安装 cloudflared..."
mv "$DOWNLOAD_DIR/cloudflared" "$CLOUDFLARED_BIN"
chmod +x "$CLOUDFLARED_BIN"

echo ""
echo "✓ cloudflared 安装完成!"
echo "  版本: $(cloudflared --version)"
echo "  路径: $CLOUDFLARED_BIN"
#!/bin/bash
########################################
# SD Forge ModelScope 启动脚本 (Jupyter 兼容版)
# 不使用 source,直接使用虚拟环境的 python 路径
########################################

WORKSPACE=$(cd "$(dirname "$0")" && pwd)
cd "$WORKSPACE"

# 检查虚拟环境
if [ ! -d "venv" ]; then
    echo "❌ 虚拟环境不存在"
    echo "请先运行: bash deploy_rocm_v2.sh"
    exit 1
fi

# 使用虚拟环境的 Python (不依赖 source)
PYTHON="./venv/bin/python"
PIP="./venv/bin/pip"

# ROCm 环境变量
export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1

echo "=========================================="
echo "  SD Forge ModelScope 启动"
echo "=========================================="
echo ""
echo "Python: $($PYTHON --version)"
echo "工作目录: $(pwd)"
echo ""

# 安装 cloudflared (如果未安装)
if ! command -v cloudflared &> /dev/null; then
    echo "安装 cloudflared..."
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared
    chmod +x /usr/local/bin/cloudflared
    echo "✓ cloudflared 安装完成"
fi

# 启动 SD Forge (后台)
echo "启动 SD Forge..."
$PYTHON launch.py --listen --port 7860 --skip-python-version-check --disable-xformers --highvram --opt-split-attention &
SD_FORGE_PID=$!

echo "等待 SD Forge 启动 (30秒)..."
sleep 30

# 启动 cloudflared
echo ""
echo "启动 cloudflared 穿透..."
cloudflared tunnel --url http://localhost:7860 &
CLOUDFLARED_PID=$!

echo ""
echo "=========================================="
echo "  服务已启动"
echo "=========================================="
echo "  SD Forge PID: $SD_FORGE_PID"
echo "  cloudflared PID: $CLOUDFLARED_PID"
echo ""
echo "⚠️  请查看上方输出的 https://xxx.trycloudflare.com 地址"
echo "  这就是你的公开访问地址!"
echo ""
echo "按 Ctrl+C 停止所有服务"

# 等待
wait
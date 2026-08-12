#!/bin/bash
export PATH="/mnt/workspace/ffmpeg/ffmpeg-7.0.2-amd64-static:$PATH"
########################################
# SD Forge ModelScope 启动脚本 (优化版)
# 使用国内镜像下载 cloudflared
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

# 安装 cloudflared (从项目目录复制或下载)
if ! command -v cloudflared &> /dev/null; then
    echo "安装 cloudflared..."
    
    # 优先从项目目录复制 (持久化文件)
    if [ -f "$WORKSPACE/cloudflared-linux-amd64" ]; then
        echo "从项目目录复制 cloudflared..."
        cp "$WORKSPACE/cloudflared-linux-amd64" /usr/local/bin/cloudflared
        chmod +x /usr/local/bin/cloudflared
        echo "✓ cloudflared 安装完成 (从项目目录复制)"
    else
        echo "⚠️  未找到 cloudflared-linux-amd64,尝试下载..."
        
        # 尝试多个镜像源
        echo "尝试从 GitHub 镜像下载..."
        wget -q --timeout=10 --tries=2 \
            https://mirror.ghproxy.com/https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
            -O /tmp/cloudflared 2>/dev/null
        
        if [ $? -ne 0 ]; then
            echo "尝试直接下载..."
            wget -q --timeout=30 \
                https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
                -O /tmp/cloudflared 2>/dev/null
        fi
        
        if [ -f /tmp/cloudflared ]; then
            mv /tmp/cloudflared /usr/local/bin/cloudflared
            chmod +x /usr/local/bin/cloudflared
            echo "✓ cloudflared 安装完成 (下载)"
        else
            echo "❌ cloudflared 下载失败"
            echo "请上传 cloudflared-linux-amd64 到项目目录"
            exit 1
        fi
    fi
else
    echo "✓ cloudflared 已安装"
fi

# 检查依赖
echo ""
echo "检查依赖..."
$PYTHON -c "import gradio; print(f'✓ gradio: {gradio.__version__}')" 2>/dev/null || echo "⚠️  gradio 未安装"
$PYTHON -c "import torch; print(f'✓ torch: {torch.__version__}')" 2>/dev/null || echo "⚠️  torch 未安装"

echo ""
echo "启动 SD Forge (高性能模式)..."
echo ""

# 启动 SD Forge (后台)
$PYTHON launch.py --listen --port 7860 --skip-python-version-check --disable-xformers --highvram --theme dark &
SD_FORGE_PID=$!

echo "等待 SD Forge 启动 (30秒)..."
sleep 30

# 检查是否启动成功
if kill -0 $SD_FORGE_PID 2>/dev/null; then
    echo "✓ SD Forge 启动成功 (PID: $SD_FORGE_PID)"
else
    echo "❌ SD Forge 启动失败,查看日志:"
    echo "   tail -f sd-forge.log"
    exit 1
fi

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
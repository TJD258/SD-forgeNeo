#!/bin/bash
# 一键启动.sh - 一键启动 SD Forge (自动安装 cloudflared + 穿透)
# 适用于 Jupyter Notebook 环境

# 工作目录 (绝对路径)
WORK_DIR="/mnt/workspace/sd-webui-forge-neo-aki-v1"
PYTHON="$WORK_DIR/venv/bin/python"
PIP="$WORK_DIR/venv/bin/pip"

echo "=========================================="
echo "  SD Forge 一键启动"
echo "=========================================="
echo ""

# 检查虚拟环境
if [ ! -f "$PYTHON" ]; then
    echo "❌ 虚拟环境不存在: $PYTHON"
    echo "请先运行部署脚本创建虚拟环境"
    exit 1
fi

# 1. 检查并安装 cloudflared
echo "[1/5] 检查 cloudflared..."
CLOUDFLARED_BIN=""
for path in /usr/local/bin/cloudflared ~/bin/cloudflared /usr/bin/cloudflared; do
    if [ -f "$path" ] && [ -x "$path" ]; then
        CLOUDFLARED_BIN="$path"
        break
    fi
done

if [ -z "$CLOUDFLARED_BIN" ]; then
    CLOUDFLARED_BIN=$(which cloudflared 2>/dev/null)
fi

if [ -z "$CLOUDFLARED_BIN" ]; then
    echo "⚠️  cloudflared 未安装,正在安装..."
    
    # 尝试下载
    mkdir -p ~/bin
    DOWNLOAD_URLS=(
        "https://mirror.ghproxy.com/https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
        "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
    )
    
    DOWNLOADED=false
    for url in "${DOWNLOAD_URLS[@]}"; do
        echo "  尝试下载: $url"
        if wget -q --timeout=10 "$url" -O ~/bin/cloudflared 2>/dev/null; then
            chmod +x ~/bin/cloudflared
            CLOUDFLARED_BIN="$HOME/bin/cloudflared"
            DOWNLOADED=true
            echo "  ✓ 下载成功"
            break
        else
            echo "  ✗ 下载失败"
        fi
    done
    
    if [ "$DOWNLOADED" = false ]; then
        echo ""
        echo "❌ cloudflared 下载失败"
        echo "请手动下载并上传到 ~/bin/cloudflared"
        echo "下载地址: https://github.com/cloudflare/cloudflared/releases/latest"
        echo ""
        echo "SD Forge 仍可本地访问: http://localhost:7860"
    fi
else
    echo "✓ cloudflared 已安装: $CLOUDFLARED_BIN"
fi

echo ""

# 2. 检查依赖
echo "[2/5] 检查依赖..."
GRADIO_OK=$($PYTHON -c "import gradio; print('OK')" 2>/dev/null)
TORCH_OK=$($PYTHON -c "import torch; print('OK')" 2>/dev/null)

if [ "$GRADIO_OK" != "OK" ]; then
    echo "⚠️  gradio 未安装,正在安装..."
    $PIP install "gradio>=4.0.0,<5.0.0" gradio_rangeslider -i https://mirrors.aliyun.com/pypi/simple/
else
    GRADIO_VER=$($PYTHON -c "import gradio; print(gradio.__version__)")
    echo "✓ gradio: $GRADIO_VER"
fi

if [ "$TORCH_OK" = "OK" ]; then
    TORCH_VER=$($PYTHON -c "import torch; print(torch.__version__)")
    echo "✓ torch: $TORCH_VER"
else
    echo "❌ torch 未安装"
    exit 1
fi

echo ""

# 3. 清理冲突进程
echo "[3/5] 清理现有进程..."
if pgrep -f "launch.py" > /dev/null 2>&1; then
    echo "⚠️  停止运行中的 SD Forge..."
    pkill -f "launch.py"
    sleep 3
fi

if pgrep -f "cloudflared" > /dev/null 2>&1; then
    echo "⚠️  停止运行中的 cloudflared..."
    pkill -f "cloudflared"
    sleep 2
fi

echo "✓ 无冲突进程"
echo ""

# 4. 启动 SD Forge
echo "[4/5] 启动 SD Forge..."
cd "$WORK_DIR"

export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1

nohup $PYTHON launch.py \
    --listen --port 7860 \
    --skip-python-version-check \
    --skip-version-check \
    --disable-xformers \
    --highvram \
    > sd-forge.log 2>&1 &

SD_FORGE_PID=$!
echo "✓ SD Forge 已启动 (PID: $SD_FORGE_PID)"

# 等待启动
echo ""
echo "等待 SD Forge 启动 (30秒)..."
sleep 30

# 检查是否成功启动
if ps -p $SD_FORGE_PID > /dev/null 2>&1; then
    echo "✓ SD Forge 运行正常"
else
    echo "❌ SD Forge 启动失败,查看日志:"
    tail -50 sd-forge.log
    exit 1
fi

echo ""

# 5. 启动 cloudflared (如果已安装)
echo "[5/5] 启动 cloudflared 穿透..."

if [ -n "$CLOUDFLARED_BIN" ]; then
    nohup $CLOUDFLARED_BIN tunnel --url http://localhost:7860 > cloudflared.log 2>&1 &
    CLOUDFLARED_PID=$!
    echo "✓ cloudflared 已启动 (PID: $CLOUDFLARED_PID)"
    
    sleep 5
    
    echo ""
    echo "=========================================="
    echo "  ✓ 启动完成"
    echo "=========================================="
    echo "  SD Forge PID: $SD_FORGE_PID"
    echo "  cloudflared PID: $CLOUDFLARED_PID"
    echo ""
    echo "🌐 公开访问地址:"
    echo "  请查看上方输出的 https://xxx.trycloudflare.com 地址"
    echo "  或运行: tail -f cloudflared.log"
    echo ""
    echo "🛑 停止服务: ./stop_forge.sh"
    echo "=========================================="
else
    echo ""
    echo "=========================================="
    echo "  ✓ SD Forge 已启动"
    echo "=========================================="
    echo "  SD Forge PID: $SD_FORGE_PID"
    echo "  本地访问: http://localhost:7860"
    echo ""
    echo "⚠️  cloudflared 未安装,无法获取公开地址"
    echo "  安装命令: ./install_cloudflared.sh"
    echo "  停止服务: ./stop_forge.sh"
    echo "=========================================="
fi
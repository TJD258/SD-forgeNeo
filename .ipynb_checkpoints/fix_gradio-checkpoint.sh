#!/bin/bash
########################################
# 修复 Gradio 安装
########################################

# 使用绝对路径 (ModelScope 环境)
WORKSPACE="/mnt/workspace/sd-webui-forge-neo-aki-v1"
cd "$WORKSPACE"

echo "=========================================="
echo "  修复 Gradio 安装"
echo "=========================================="
echo ""

PYTHON="./venv/bin/python"
PIP="./venv/bin/pip"

# 检查虚拟环境
if [ ! -d "venv" ]; then
    echo "❌ 虚拟环境不存在"
    exit 1
fi

# 卸载现有 gradio
echo "[1/3] 卸载现有 gradio..."
$PIP uninstall gradio gradio_rangeslider -y 2>/dev/null

# 安装兼容版本
echo "[2/3] 安装 gradio 4.44.1..."

$PIP install gradio==4.40.0 gradio_rangeslider==0.0.8 -i https://mirrors.aliyun.com/pypi/simple/
if [ $? -ne 0 ]; then
    echo "⚠️  4.44.1 安装失败,尝试 4.40.0..."
    $PIP install gradio==4.44.1 gradio_rangeslider==0.0.8 -i https://mirrors.aliyun.com/pypi/simple/
fi

# 验证安装
echo ""
echo "[3/3] 验证安装..."
$PYTHON -c "
import gradio
print(f'✓ gradio: {gradio.__version__}')

# 测试导入关键模块
try:
    import gradio._simple_templates
    print('✓ gradio._simple_templates: OK')
except ImportError as e:
    print(f'❌ gradio._simple_templates: {e}')
    exit(1)

try:
    import gradio.networking
    print('✓ gradio.networking: OK')
except ImportError as e:
    print(f'❌ gradio.networking: {e}')
    exit(1)

print()
print('✓ Gradio 安装成功!')
"

echo ""
echo "=========================================="
echo "  修复完成"
echo "=========================================="
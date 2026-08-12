#!/bin/bash
########################################
# SD Forge ROCm Cloud Deployment Script
# 适用于: Ubuntu 22.04 + ROCm 7.2.1 + Python 3.12
# 用法: 上传到云端 sd-webui-forge-classic 目录后运行
#       bash deploy_rocm.sh
########################################

set -e

WORKSPACE=$(cd "$(dirname "$0")" && pwd)
cd "$WORKSPACE"

VENV_DIR="$WORKSPACE/venv"
PYTHON="${PYTHON:-python3}"

echo "=========================================="
echo "  SD Forge ROCm 云端部署"
echo "=========================================="
echo ""

# 1. 环境检查
echo "[1/7] 检查系统环境..."
echo "  工作目录: $WORKSPACE"
echo "  操作系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
echo "  Python 版本: $($PYTHON --version 2>&1)"

# 检查 ROCm
if command -v rocminfo &> /dev/null; then
    ROCM_INFO=$(rocminfo | grep -m1 "Name:" | head -1)
    echo "  ROCm 设备: $ROCM_INFO"
else
    echo "  ⚠️  警告: 未检测到 ROCm 工具"
fi
echo ""

# 2. 创建虚拟环境
echo "[2/7] 配置虚拟环境..."
if [ -d "$VENV_DIR" ]; then
    echo "  ✓ 虚拟环境已存在"
else
    echo "  创建虚拟环境..."
    $PYTHON -m venv "$VENV_DIR"
    echo "  ✓ 虚拟环境创建成功"
fi

source "$VENV_DIR/bin/activate"
pip install --upgrade pip -q
echo "  ✓ pip 已升级"
echo ""

# 3. 验证 ROCm PyTorch
echo "[3/7] 验证 ROCm PyTorch..."
if python -c "import torch" 2>/dev/null; then
    TORCH_VER=$(python -c "import torch; print(torch.__version__)")
    echo "  已安装 PyTorch: $TORCH_VER"
    
    if python -c "import torch; assert torch.cuda.is_available()" 2>/dev/null; then
        echo "  ✓ ROCm GPU 可用"
    else
        echo "  ⚠️  PyTorch 已安装但 ROCm 不可用"
        echo "  正在安装 ROCm 版本的 PyTorch..."
        pip install torch torchvision --index-url https://download.pytorch.org/whl/rocm7.2 -q
        echo "  ✓ ROCm PyTorch 安装完成"
    fi
else
    echo "  PyTorch 未安装，正在安装 ROCm 版本..."
    pip install torch torchvision --index-url https://download.pytorch.org/whl/rocm7.2 -q
    echo "  ✓ ROCm PyTorch 安装完成"
fi

python -c "
import torch
print(f'  PyTorch 版本: {torch.__version__}')
print(f'  CUDA 可用: {torch.cuda.is_available()}')
if hasattr(torch.version, 'hip'):
    print(f'  HIP 版本: {torch.version.hip}')
if torch.cuda.is_available():
    print(f'  GPU 名称: {torch.cuda.get_device_name(0)}')
    print(f'  GPU 数量: {torch.cuda.device_count()}')
"
echo ""

# 4. 安装基础依赖
echo "[4/7] 安装基础依赖..."
if [ -f "requirements.txt" ]; then
    # 创建临时文件，排除 torch (已预装)
    grep -v "^torch$" requirements.txt | grep -v "^torch==" > requirements_no_torch.txt
    
    echo "  正在安装依赖 (这可能需要几分钟)..."
    pip install -r requirements_no_torch.txt -q
    
    rm -f requirements_no_torch.txt
    echo "  ✓ 基础依赖安装完成"
else
    echo "  ⚠️  未找到 requirements.txt"
fi
echo ""

# 5. 安装 ROCm 可选包
echo "[5/7] 安装 ROCm 可选包..."

# bitsandbytes (支持 ROCm)
if ! python -c "import bitsandbytes" 2>/dev/null; then
    echo "  安装 bitsandbytes..."
    pip install bitsandbytes==0.49.2 -q 2>/dev/null || echo "  ⚠️  bitsandbytes 安装失败 (可选)"
else
    echo "  ✓ bitsandbytes 已安装"
fi
echo ""

# 6. 创建启动脚本
echo "[6/7] 创建启动脚本..."

# 创建 webui.sh (Linux 版主启动脚本)
cat > webui.sh << 'WEBUI_EOF'
#!/bin/bash
# SD Forge Linux 启动脚本

WORKSPACE=$(cd "$(dirname "$0")" && pwd)
cd "$WORKSPACE"

# 加载用户配置
if [ -f webui-user.sh ]; then
    source webui-user.sh
fi

# 设置默认值
PYTHON="${PYTHON:-python3}"
VENV_DIR="${VENV_DIR:-$WORKSPACE/venv}"

# 激活虚拟环境
if [ -d "$VENV_DIR" ]; then
    source "$VENV_DIR/bin/activate"
else
    echo "虚拟环境不存在: $VENV_DIR"
    echo "请先运行: bash deploy_rocm.sh"
    exit 1
fi

# ROCm 环境变量
export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1

# 启动
echo "启动 SD Forge..."
python launch.py $COMMANDLINE_ARGS
WEBUI_EOF

chmod +x webui.sh
echo "  ✓ webui.sh 创建完成"

# 创建 webui-user.sh (用户配置脚本)
if [ ! -f webui-user.sh ]; then
    cat > webui-user.sh << 'USER_EOF'
#!/bin/bash
# 用户自定义配置

# 启动参数
# --listen: 允许外部访问
# --port 7860: 设置端口
# --skip-python-version-check: 跳过 Python 版本检查 (平台是 3.12，代码要求 3.13)
# --disable-xformers: 禁用 xformers (仅支持 CUDA)
export COMMANDLINE_ARGS="--listen --port 7860 --skip-python-version-check --disable-xformers"

# ROCm 环境变量
export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1

# 如果需要覆盖 GPU 架构 (根据实际情况调整)
# export HSA_OVERRIDE_GFX_VERSION=10.3.0

# 跳过不必要的包安装 (CUDA 专属)
export SAGE_PACKAGE=""
export FLASH_PACKAGE=""
export NUNCHAKU_PACKAGE=""

# 内存优化 (根据显存大小选择)
# export COMMANDLINE_ARGS="$COMMANDLINE_ARGS --medvram"    # 6-8GB 显存
# export COMMANDLINE_ARGS="$COMMANDLINE_ARGS --lowvram"    # 4-6GB 显存
# export COMMANDLINE_ARGS="$COMMANDLINE_ARGS --highvram"   # 12GB+ 显存
USER_EOF

    chmod +x webui-user.sh
    echo "  ✓ webui-user.sh 创建完成"
else
    echo "  ✓ webui-user.sh 已存在"
fi

# 创建快速启动脚本 run.sh
cat > run.sh << 'RUN_EOF'
#!/bin/bash
# 快速启动脚本

WORKSPACE=$(cd "$(dirname "$0")" && pwd)
cd "$WORKSPACE"

# 激活虚拟环境
source venv/bin/activate

# ROCm 环境变量
export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1

# 启动
python launch.py --listen --port 7860 --skip-python-version-check --disable-xformers "$@"
RUN_EOF

chmod +x run.sh
echo "  ✓ run.sh 创建完成"
echo ""

# 7. 完成
echo "[7/7] 部署完成!"
echo ""
echo "=========================================="
echo "  部署信息"
echo "=========================================="
echo ""
echo "  ✓ 虚拟环境: $VENV_DIR"
echo "  ✓ PyTorch: $(python -c 'import torch; print(torch.__version__)')"
echo "  ✓ ROCm: $(python -c 'import torch; print("可用" if torch.cuda.is_available() else "不可用")')"
echo ""
echo "=========================================="
echo "  启动方式"
echo "=========================================="
echo ""
echo "  方式 1 (推荐): ./run.sh"
echo "  方式 2 (完整): ./webui.sh"
echo "  方式 3 (手动): source venv/bin/activate && python launch.py --listen --port 7860"
echo ""
echo "  访问地址: http://你的云IP:7860"
echo ""
echo "=========================================="
echo "  常用启动参数"
echo "=========================================="
echo ""
echo "  --medvram              中等显存优化 (6-8GB)"
echo "  --lowvram              低显存优化 (4-6GB)"
echo "  --highvram             高显存模式 (12GB+)"
echo "  --disable-xformers     禁用 xformers (ROCm 必须)"
echo "  --skip-python-version-check  跳过 Python 版本检查"
echo "  --listen               允许外部访问"
echo "  --port 7860            设置端口"
echo "  --api                  启用 API"
echo ""
echo "  编辑 webui-user.sh 可自定义启动参数"
echo ""
echo "=========================================="
echo "  故障排查"
echo "=========================================="
echo ""
echo "  问题 1: ROCm 不可用"
echo "  解决: 检查 AMD GPU 驱动和 ROCm 安装"
echo "        rocminfo 命令应显示 GPU 信息"
echo ""
echo "  问题 2: 显存不足"
echo "  解决: 在 webui-user.sh 添加 --medvram 或 --lowvram"
echo ""
echo " 问题 3: GPU 架构不识别"
echo "  解决: 在 webui-user.sh 设置 HSA_OVERRIDE_GFX_VERSION"
echo "        RDNA2: 10.3.0 | RDNA3: 11.0.0"
echo ""
echo "=========================================="
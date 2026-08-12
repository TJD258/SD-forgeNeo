#!/bin/bash
########################################
# SD Forge ROCm Cloud Deployment Script (离线安装版)
# 适用于: Ubuntu 22.04 + ROCm 7.2.1 + Python 3.12
# 特点: 使用云端预装的 PyTorch,无需下载
########################################

set -e

WORKSPACE=$(cd "$(dirname "$0")" && pwd)
cd "$WORKSPACE"

VENV_DIR="$WORKSPACE/venv"
PYTHON="${PYTHON:-python3}"

echo "=========================================="
echo "  SD Forge ROCm 云端部署 (离线版)"
echo "=========================================="
echo ""

# 1. 环境检查
echo "[1/6] 检查系统环境..."
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

# 2. 检查系统 PyTorch
echo "[2/6] 检查系统 PyTorch..."
if $PYTHON -c "import torch" 2>/dev/null; then
    SYSTEM_TORCH=$($PYTHON -c "import torch; print(torch.__version__)")
    SYSTEM_ROCM=$($PYTHON -c "import torch; print('可用' if torch.cuda.is_available() else '不可用')")
    echo "  ✓ 系统 PyTorch: $SYSTEM_TORCH"
    echo "  ✓ ROCm 状态: $SYSTEM_ROCM"
    
    # 记录系统 PyTorch 路径
    SYSTEM_TORCH_PATH=$($PYTHON -c "import torch; import os; print(os.path.dirname(torch.__file__))")
    echo "  ✓ PyTorch 路径: $SYSTEM_TORCH_PATH"
else
    echo "  ❌ 系统 PyTorch 未安装"
    echo "  请安装: pip install torch torchvision --index-url https://download.pytorch.org/whl/rocm7.2"
    exit 1
fi
echo ""

# 3. 创建虚拟环境
echo "[3/6] 配置虚拟环境..."
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

# 4. 使用系统 PyTorch (不重新安装)
echo "[4/6] 配置 PyTorch..."
echo "  使用系统预装的 PyTorch (跳过下载)"

# 方法: 在虚拟环境中创建 .pth 文件指向系统 PyTorch
SITE_PACKAGES=$(python -c "import site; print(site.getsitepackages()[0])")
echo "$SYSTEM_TORCH_PATH" > "$SITE_PACKAGES/system_torch.pth"

# 验证虚拟环境中能否使用 PyTorch
if python -c "import torch; print(f'  ✓ 虚拟环境中 PyTorch: {torch.__version__}')" 2>/dev/null; then
    echo "  ✓ PyTorch 配置成功"
else
    echo "  ⚠️  .pth 方法失败,尝试直接安装..."
    # 如果有离线包,使用离线安装
    if ls *.whl 1> /dev/null 2>&1; then
        echo "  发现离线包,正在安装..."
        pip install torch*.whl torchvision*.whl -q
        echo "  ✓ 离线安装完成"
    else
        echo "  从网络安装 ROCm PyTorch..."
        pip install torch torchvision --index-url https://download.pytorch.org/whl/rocm7.2 -q
        echo "  ✓ 网络安装完成"
    fi
fi
echo ""

# 5. 安装基础依赖
echo "[5/6] 安装基础依赖..."
if [ -f "requirements.txt" ]; then
    # 创建临时文件,排除 torch
    grep -v "^torch$" requirements.txt | grep -v "^torch==" > requirements_no_torch.txt
    
    echo "  正在安装依赖 (这可能需要几分钟)..."
    pip install -r requirements_no_torch.txt -q
    
    rm -f requirements_no_torch.txt
    echo "  ✓ 基础依赖安装完成"
else
    echo "  ⚠️  未找到 requirements.txt"
fi
echo ""

# 6. 创建启动脚本
echo "[6/6] 创建启动脚本..."

# 创建 webui.sh
cat > webui.sh << 'WEBUI_EOF'
#!/bin/bash
WORKSPACE=$(cd "$(dirname "$0")" && pwd)
cd "$WORKSPACE"

if [ -f webui-user.sh ]; then
    source webui-user.sh
fi

PYTHON="${PYTHON:-python3}"
VENV_DIR="${VENV_DIR:-$WORKSPACE/venv}"

if [ -d "$VENV_DIR" ]; then
    source "$VENV_DIR/bin/activate"
else
    echo "虚拟环境不存在: $VENV_DIR"
    echo "请先运行: bash deploy_rocm_offline.sh"
    exit 1
fi

export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1

echo "启动 SD Forge..."
python launch.py $COMMANDLINE_ARGS
WEBUI_EOF

chmod +x webui.sh
echo "  ✓ webui.sh 创建完成"

# 创建 webui-user.sh (如果不存在)
if [ ! -f webui-user.sh ]; then
    cat > webui-user.sh << 'USER_EOF'
#!/bin/bash
export COMMANDLINE_ARGS="--listen --port 7860 --skip-python-version-check --disable-xformers"
export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1
export SAGE_PACKAGE=""
export FLASH_PACKAGE=""
export NUNCHAKU_PACKAGE=""
USER_EOF
    chmod +x webui-user.sh
    echo "  ✓ webui-user.sh 创建完成"
else
    echo "  ✓ webui-user.sh 已存在"
fi

# 创建 run.sh
cat > run.sh << 'RUN_EOF'
#!/bin/bash
WORKSPACE=$(cd "$(dirname "$0")" && pwd)
cd "$WORKSPACE"
source venv/bin/activate
export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1
python launch.py --listen --port 7860 --skip-python-version-check --disable-xformers "$@"
RUN_EOF

chmod +x run.sh
echo "  ✓ run.sh 创建完成"
echo ""

# 完成
echo "=========================================="
echo "  部署完成!"
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
echo ""
echo "  访问地址: http://你的云IP:7860"
echo ""
echo "=========================================="
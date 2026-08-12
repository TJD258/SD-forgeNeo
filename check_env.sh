#!/bin/bash
########################################
# SD Forge 环境检查脚本
# 用法: 上传到云端 sd-webui-forge-classic 目录后运行
#       ./check_env.sh
########################################

echo "=========================================="
echo "  SD Forge 环境诊断"
echo "=========================================="
echo ""

# 1. 系统信息
echo "[1/6] 系统信息"
echo "  操作系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
echo "  内核版本: $(uname -r)"
echo "  架构: $(uname -m)"
echo ""

# 2. Python 环境
echo "[2/6] Python 环境"
echo "  Python 路径: $(which python3)"
echo "  Python 版本: $(python3 --version)"
echo ""

# 3. ROCm 信息
echo "[3/6] ROCm 信息"
if command -v rocminfo &> /dev/null; then
    echo "  rocminfo: 已安装"
    echo "  GPU 设备:"
    rocminfo | grep -A 3 "Name:" | head -20
else
    echo "  ⚠️  rocminfo 未安装"
fi
echo ""

if command -v rocm-smi &> /dev/null; then
    echo "  rocm-smi 状态:"
    rocm-smi
else
    echo "  ⚠️  rocm-smi 未安装"
fi
echo ""

# 4. PyTorch 检查
echo "[4/6] PyTorch 检查"
if python3 -c "import torch" 2>/dev/null; then
    python3 -c "
import torch
print(f'  PyTorch 版本: {torch.__version__}')
print(f'  CUDA 可用: {torch.cuda.is_available()}')
if hasattr(torch.version, 'hip'):
    print(f'  HIP 版本: {torch.version.hip}')
if torch.cuda.is_available():
    print(f'  GPU 数量: {torch.cuda.device_count()}')
    print(f'  GPU 名称: {torch.cuda.get_device_name(0)}')
    print(f'  显存总量: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB')
"
else
    echo "  ❌ PyTorch 未安装"
fi
echo ""

# 5. 虚拟环境检查
echo "[5/6] 虚拟环境检查"
if [ -d "venv" ]; then
    echo "  ✓ 虚拟环境存在"
    source venv/bin/activate
    echo "  Python: $(python --version)"
    echo "  已安装包数量: $(pip list 2>/dev/null | wc -l)"
else
    echo "  ⚠️  虚拟环境不存在 (需要运行 deploy_rocm.sh)"
fi
echo ""

# 6. 依赖检查
echo "[6/6] 关键依赖检查"
check_package() {
    if python3 -c "import $1" 2>/dev/null; then
        echo "  ✓ $1: 已安装"
    else
        echo "  ❌ $1: 未安装"
    fi
}

check_package "torch"
check_package "torchvision"
check_package "diffusers"
check_package "transformers"
check_package "PIL"
check_package "numpy"
check_package "safetensors"
echo ""

echo "=========================================="
echo "  诊断完成"
echo "=========================================="
echo ""

# 建议
echo "建议:"
if ! python3 -c "import torch; assert torch.cuda.is_available()" 2>/dev/null; then
    echo "  ⚠️  ROCm PyTorch 不可用，请运行: bash deploy_rocm.sh"
fi

if [ ! -d "venv" ]; then
    echo "  ⚠️  虚拟环境不存在，请运行: bash deploy_rocm.sh"
fi

if python3 -c "import torch; assert torch.cuda.is_available()" 2>/dev/null && [ -d "venv" ]; then
    echo "  ✓ 环境正常，可以启动: ./run.sh"
fi
#!/bin/bash
########################################
# SD Forge 快速启动脚本 (国内镜像加速版)
########################################

WORKSPACE=$(cd "$(dirname "$0")" && pwd)
cd "$WORKSPACE"

# 激活虚拟环境
if [ ! -d "venv" ]; then
    echo "❌ 虚拟环境不存在"
    echo "请先运行: bash deploy_rocm_v2.sh"
    exit 1
fi

source venv/bin/activate

# 设置 pip 镜像源 (清华)
export PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
export PIP_TRUSTED_HOST=pypi.tuna.tsinghua.edu.cn

# ROCm 环境变量
export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1

# 启动
echo "启动 SD Forge (高性能模式)..."
python launch.py --listen --port 7860 --skip-python-version-check --disable-xformers --highvram --opt-split-attention "$@"
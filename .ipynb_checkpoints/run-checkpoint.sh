#!/bin/bash
########################################
# SD Forge 快速启动脚本
# 用法: 上传到云端 sd-webui-forge-classic 目录后运行
#       ./run.sh [额外参数]
########################################

WORKSPACE=$(cd "$(dirname "$0")" && pwd)
cd "$WORKSPACE"

# 激活虚拟环境
if [ ! -d "venv" ]; then
    echo "❌ 虚拟环境不存在"
    echo "请先运行: bash deploy_rocm.sh"
    exit 1
fi

source venv/bin/activate

# ROCm 环境变量
export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1

# 启动
python launch.py --listen --port 7860 --skip-python-version-check --disable-xformers "$@"
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
    echo "请先运行: bash deploy_rocm_v2.sh"
    exit 1
fi

export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1

echo "启动 SD Forge..."
python launch.py $COMMANDLINE_ARGS

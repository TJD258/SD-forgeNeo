#!/bin/bash
WORKSPACE=$(cd "$(dirname "$0")" && pwd)
cd "$WORKSPACE"
source venv/bin/activate
export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1
python launch.py --listen --port 7860 --skip-python-version-check --disable-xformers "$@"

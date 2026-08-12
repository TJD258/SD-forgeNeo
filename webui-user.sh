#!/usr/bin/env bash

# export PYTHON=
# export GIT=
# export VENV_DIR=

# export TORCH_COMMAND="pip install torch==2.1.0 torchvision==0.16.0 --index-url https://download.pytorch.org/whl/cu121"

export COMMANDLINE_ARGS="--uv"

# --skip-python-version-check --skip-torch-cuda-test --skip-version-check --skip-prepare-environment --skip-install

exec "$(dirname "$0")/webui.sh"

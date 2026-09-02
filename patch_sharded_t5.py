#!/usr/bin/env python3
import os
import sys
from datetime import datetime

utils_path = "backend/utils.py"
backup_path = f"backend/utils.py.bak.{datetime.now().strftime('%Y%m%d_%H%M%S')}"

if not os.path.isfile(utils_path):
    print(f"错误：找不到 {utils_path}")
    sys.exit(1)

# 备份原文件
print(f"备份 {utils_path} -> {backup_path}")
with open(utils_path, "r") as f:
    original_content = f.read()
with open(backup_path, "w") as f:
    f.write(original_content)

# 查找要替换的代码块
old_code = '''def load_torch_file(ckpt: str, *, safe_load=True, device=None, return_metadata=False) -> dict[str, torch.Tensor]:
    """https://github.com/Comfy-Org/ComfyUI/blob/v0.10.0/comfy/utils.py#L59"""

    device = device or torch.device("cpu")
    metadata = None

    if ckpt.lower().endswith((".safetensors", ".sft")):
        try:
            with safetensors.safe_open(ckpt, framework="pt", device=device.type) as f:'''

new_code = '''def load_torch_file(ckpt: str, *, safe_load=True, device=None, return_metadata=False) -> dict[str, torch.Tensor]:
    """https://github.com/Comfy-Org/ComfyUI/blob/v0.10.0/comfy/utils.py#L59"""

    device = device or torch.device("cpu")
    metadata = None

    if ckpt.lower().endswith((".safetensors", ".sft")):
        # 支持分体 safetensors 文件
        index_path = ckpt + ".index.json"
        if not os.path.isfile(index_path):
            ckpt_dir = os.path.dirname(ckpt)
            for idx_file in ["model.safetensors.index.json", "pytorch_model.bin.index.json"]:
                if os.path.isfile(os.path.join(ckpt_dir, idx_file)):
                    index_path = os.path.join(ckpt_dir, idx_file)
                    break
        
        if os.path.isfile(index_path):
            with open(index_path, "r") as f:
                index_data = json.load(f)
            weight_map = index_data.get("weight_map", {})
            unique_files = sorted(set(weight_map.values()))
            sd = {}
            ckpt_dir = os.path.dirname(index_path)
            meta = {}
            for shard_file in unique_files:
                shard_path = os.path.join(ckpt_dir, shard_file)
                if os.path.isfile(shard_path):
                    with safetensors.safe_open(shard_path, framework="pt", device=device.type) as f:
                        for k in f.keys():
                            tensor = f.get_tensor(k)
                            if DISABLE_MMAP:
                                tensor = tensor.to(device=device, copy=True)
                            sd[k] = tensor
                        if return_metadata:
                            shard_meta = f.metadata()
                            if shard_meta:
                                meta.update(shard_meta)
            return (sd, meta) if return_metadata else sd
        
        try:
            with safetensors.safe_open(ckpt, framework="pt", device=device.type) as f:'''

if old_code not in original_content:
    print("错误：找不到要替换的代码块")
    print("请手动检查 backend/utils.py 文件")
    sys.exit(1)

# 执行替换
new_content = original_content.replace(old_code, new_code)

with open(utils_path, "w") as f:
    f.write(new_content)

print("补丁应用成功！")
print(f"现在你可以使用分体 T5 文件了")
print(f"在 WebUI 额外模块中选择: models/text_encoder/wan2.2/model-00001-of-00003.safetensors")
print(f"(任意一个分体文件即可，脚本会自动加载所有分体)")

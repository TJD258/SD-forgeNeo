#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Wan2.2 模型支持补丁脚本
功能：自动备份原文件并添加 Wan2.2-I2V-A14B 支持
使用方法：在云端服务器上执行 python3 patch_wan22_support.py
"""

import os
import sys
import shutil
from datetime import datetime

def main():
    print("=" * 50)
    print("Wan2.2 模型支持补丁脚本")
    print("=" * 50)
    print()

    # 获取脚本所在目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # 优先使用命令行参数
    if len(sys.argv) > 1:
        forge_dir = sys.argv[1]
        if not os.path.isdir(forge_dir):
            print(f"错误：指定的目录不存在：{forge_dir}")
            return False
        if not os.path.isfile(os.path.join(forge_dir, "launch.py")):
            print(f"警告：指定目录可能不是 SD Forge 目录（未找到 launch.py）")
    else:
        # 自动检测 Forge 目录
        possible_dirs = [
            script_dir,  # 当前目录可能就是 Forge 目录
            os.path.join(script_dir, "sd-webui-forge-classic"),
            os.path.join(script_dir, "sd-webui-forge"),
            os.path.join(script_dir, "stable-diffusion-webui-forge"),
            os.path.join(script_dir, ".."),  # 可能在父目录
        ]
        
        forge_dir = None
        for d in possible_dirs:
            d = os.path.abspath(d)
            if os.path.isdir(d):
                # 验证是否是真正的 Forge 目录（检查关键文件）
                if (os.path.isfile(os.path.join(d, "launch.py")) or 
                    os.path.isfile(os.path.join(d, "webui.py")) or
                    os.path.isdir(os.path.join(d, "modules_forge"))):
                    forge_dir = d
                    break
        
        # 如果没找到，尝试搜索子目录
        if forge_dir is None and os.path.isdir(script_dir):
            for item in os.listdir(script_dir):
                item_path = os.path.join(script_dir, item)
                if os.path.isdir(item_path):
                    if (os.path.isfile(os.path.join(item_path, "launch.py")) or
                        os.path.isfile(os.path.join(item_path, "webui.py")) or
                        os.path.isdir(os.path.join(item_path, "modules_forge"))):
                        forge_dir = item_path
                        break
        
        if forge_dir is None:
            print(f"错误：找不到 SD Forge 目录")
            print(f"当前目录：{os.getcwd()}")
            print(f"脚本目录：{script_dir}")
            print(f"搜索的目录：{[os.path.abspath(d) for d in possible_dirs]}")
            print()
            print("请检查目录结构，或手动指定 Forge 路径：")
            print(f"  python3 {os.path.basename(__file__)} /path/to/sd-webui-forge-classic")
            print()
            print("常见路径示例：")
            print(f"  python3 {os.path.basename(__file__)} /mnt/workspace/sd-webui-forge-neo-aki-v1")
            print(f"  python3 {os.path.basename(__file__)} /mnt/workspace/sd-webui-forge-neo-aki-v1/sd-webui-forge-classic")
            print(f"  python3 {os.path.basename(__file__)} /home/user/sd-webui-forge-classic")
            return False

    print(f"Forge 目录：{forge_dir}")
    print()

    # 创建备份目录
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_dir = os.path.join(forge_dir, f"wan22_backup_{timestamp}")
    os.makedirs(backup_dir, exist_ok=True)
    print(f"备份目录：{backup_dir}")
    print()

    # 修改文件列表
    modifications = [
        {
            "path": "modules_forge/packages/huggingface_guess/detection.py",
            "func": patch_detection_py,
        },
        {
            "path": "modules_forge/packages/huggingface_guess/model_list.py",
            "func": patch_model_list_py,
        },
        {
            "path": "backend/diffusion_engine/wan.py",
            "func": patch_wan_py,
        },
    ]

    success_count = 0
    for mod in modifications:
        file_path = os.path.join(forge_dir, mod["path"])
        
        if not os.path.isfile(file_path):
            print(f"❌ 错误：找不到文件 {file_path}")
            continue

        # 备份文件
        backup_file = os.path.join(backup_dir, os.path.basename(file_path) + ".bak")
        shutil.copy2(file_path, backup_file)
        print(f"✓ 已备份 {os.path.basename(file_path)}")

        # 应用补丁
        try:
            result = mod["func"](file_path)
            if result:
                print(f"✓ 已修改 {os.path.basename(file_path)}")
                success_count += 1
            else:
                print(f"⚠ {os.path.basename(file_path)} 可能需要手动检查")
        except Exception as e:
            print(f"❌ 修改 {os.path.basename(file_path)} 失败：{e}")

    print()
    print("=" * 50)
    print("补丁应用完成！")
    print("=" * 50)
    print()
    print(f"成功修改：{success_count}/{len(modifications)} 个文件")
    print(f"备份目录：{backup_dir}")
    print()
    print("修改的文件：")
    print("  1. detection.py - 添加 Wan2.2 模型检测逻辑")
    print("  2. model_list.py - 添加 WAN22_T2V 和 WAN22_I2V 配置类")
    print("  3. wan.py - 更新模型匹配列表")
    print()
    print("下一步：")
    print("  1. 重启 SD Forge 服务使更改生效")
    print("  2. 加载 Wan2.2-I2V-A14B 模型")
    print("  3. 在 txt2img 界面使用视频生成功能")
    print()
    print("如需恢复，执行：")
    print(f"  cp {backup_dir}/*.py <对应目录>")
    print()

    return success_count == len(modifications)


def patch_detection_py(file_path):
    """修改 detection.py 添加 Wan2.2 检测逻辑"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 替换注释
    old_text1 = 'if "{}head.modulation".format(key_prefix) in state_dict_keys:  # Wan 2.1'
    new_text1 = 'if "{}head.modulation".format(key_prefix) in state_dict_keys:  # Wan 2.1 / Wan 2.2'
    
    if old_text1 not in content:
        print("  警告：未找到 'Wan 2.1' 注释，可能已修改")
        return False

    content = content.replace(old_text1, new_text1)

    # 删除旧的 image_model 赋值
    old_line = '        dit_config["image_model"] = "wan2.1"'
    if old_line in content:
        content = content.replace(old_line + '\n', '')

    # 在 return dit_config 前添加检测逻辑
    old_return = '''        flf_weight = state_dict.get("{}img_emb.emb_pos".format(key_prefix))
        if flf_weight is not None:
            dit_config["flf_pos_embed_token_number"] = int(flf_weight.shape[1])
        return dit_config'''

    new_return = '''        flf_weight = state_dict.get("{}img_emb.emb_pos".format(key_prefix))
        if flf_weight is not None:
            dit_config["flf_pos_embed_token_number"] = int(flf_weight.shape[1])

        # Detect Wan 2.2 by checking for second transformer blocks (MoE two-stage denoising)
        if "{}blocks2.0.ffn.0.weight".format(key_prefix) in state_dict_keys:
            dit_config["image_model"] = "wan2.2"
            dit_config["num_layers2"] = count_blocks(state_dict_keys, "{}blocks2.".format(key_prefix) + "{}.")
        else:
            dit_config["image_model"] = "wan2.1"

        return dit_config'''

    if old_return in content:
        content = content.replace(old_return, new_return)
    else:
        print("  警告：未找到预期的 return 语句")
        return False

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

    return True


def patch_model_list_py(file_path):
    """修改 model_list.py 添加 Wan2.2 配置类"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 检查是否已经添加过
    if "class WAN22_T2V" in content:
        print("  WAN22 类已存在，跳过添加")
        return True

    # Wan2.2 类定义
    wan22_classes = '''

class WAN22_T2V(BASE):
    huggingface_repo = "Wan-AI/Wan2.2-T2V-A14B"

    unet_config = {
        "image_model": "wan2.2",
        "model_type": "t2v",
    }

    sampling_settings = {
        "shift": 8.0,
    }

    unet_extra_config = {}
    latent_format = latent.Wan21

    memory_usage_factor = 1.2  # Wan2.2 MoE needs more VRAM

    supported_inference_dtypes = [torch.bfloat16, torch.float32]

    vae_key_prefix = ["vae."]
    text_encoder_key_prefix = ["text_encoders."]

    unet_target = "transformer"

    def __init__(self, unet_config):
        super().__init__(unet_config)
        self.memory_usage_factor = self.unet_config.get("dim", 2000) / 2000 * 1.2

    def clip_target(self, state_dict: dict):
        return {"umt5xxl": "text_encoder"}


class WAN22_I2V(WAN22_T2V):
    huggingface_repo = "Wan-AI/Wan2.2-I2V-A14B"

    unet_config = {
        "image_model": "wan2.2",
        "model_type": "i2v",
        "in_dim": 36,
    }
'''

    # 在 WAN21_I2V 类后面添加（在 QwenImage 类之前）
    insert_marker = '\n\nclass QwenImage'
    if insert_marker in content:
        content = content.replace(insert_marker, wan22_classes + insert_marker)
    else:
        print("  警告：未找到插入位置")
        return False

    # 在 model_list 数组中添加 Wan2.2
    if "WAN21_I2V," in content and "WAN22_T2V," not in content:
        content = content.replace(
            "WAN21_I2V,",
            "WAN21_I2V,\n    WAN22_T2V,\n    WAN22_I2V,",
            1
        )

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

    return True


def patch_wan_py(file_path):
    """修改 wan.py 更新模型匹配列表"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    old_line = "matched_guesses = [model_list.WAN21_T2V, model_list.WAN21_I2V]"
    new_line = "matched_guesses = [model_list.WAN21_T2V, model_list.WAN21_I2V, model_list.WAN22_T2V, model_list.WAN22_I2V]"

    if old_line not in content:
        print("  警告：未找到预期的 matched_guesses 行")
        return False

    content = content.replace(old_line, new_line)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

    return True


if __name__ == "__main__":
    success = main()
    if success:
        print("✅ 所有补丁已成功应用！")
        exit(0)
    else:
        print("⚠ 部分补丁可能未成功应用，请检查输出信息")
        exit(1)
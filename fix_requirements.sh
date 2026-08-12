#!/bin/bash
########################################
# 修复 requirements.txt (排除 torch)
########################################

cd "$(dirname "$0")/.."

echo "修复 requirements.txt..."

# 备份原文件
cp requirements.txt requirements.txt.bak

# 创建临时文件,排除 torch 和 torchvision
grep -v "^torch==" requirements.txt | \
grep -v "^torchvision==" | \
grep -v "^torch " | \
grep -v "^torchvision " > requirements_fixed.txt

# 替换原文件
mv requirements_fixed.txt requirements.txt

echo "✓ 已排除 torch 和 torchvision"
echo "原文件备份: requirements.txt.bak"
echo ""
echo "修改内容:"
diff requirements.txt.bak requirements.txt || true
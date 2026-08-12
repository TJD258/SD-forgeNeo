#!/bin/bash
# stop_forge.sh - 停止 SD Forge 所有服务
# 适用于 Jupyter Notebook 环境

echo "=========================================="
echo "  停止 SD Forge 服务"
echo "=========================================="

# 停止 SD Forge 进程
if pkill -9 -f "launch.py" 2>/dev/null; then
    echo "✓ SD Forge 已停止"
else
    echo "⚠️ SD Forge 未运行"
fi

# 停止 cloudflared 进程
if pkill -9 -f "cloudflared" 2>/dev/null; then
    echo "✓ cloudflared 已停止"
else
    echo "⚠️ cloudflared 未运行"
fi

# 清理端口占用
if command -v fuser &>/dev/null; then
    fuser -k 7860/tcp 2>/dev/null
    echo "✓ 端口 7860 已释放"
fi

# 验证
REMAINING=$(ps aux | grep -E "launch.py|cloudflared" | grep -v grep | wc -l)
if [ "$REMAINING" -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "  ✓ 所有服务已停止"
    echo "=========================================="
else
    echo ""
    echo "⚠️  仍有 $REMAINING 个进程在运行"
    ps aux | grep -E "launch.py|cloudflared" | grep -v grep
fi
#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <0|1>"
    echo "  1 - Enable wake-up interrupt on INT1"
    echo "  0 - Disable wake-up interrupt"
    exit 1
fi

MODE=$1

if [[ "$MODE" != "0" && "$MODE" != "1" ]]; then
    echo "Error: Value must be 0 or 1"
    exit 1
fi

# Unbind driver (skip if already unbound)
DRIVER_PATH="/sys/bus/i2c/devices/1-006a/driver"
if [ -e "$DRIVER_PATH" ]; then
    echo 1-006a > "$DRIVER_PATH/unbind"
fi

if [ "$MODE" = "1" ]; then
    echo "Enabling wake-up interrupt..."

    # 清掉之前的 INT1 路由，避免 DRDY 干扰
    i2cset -y 1 0x6a 0x0d 0x00

    # 开启加速度计 104 Hz
    i2cset -y 1 0x6a 0x10 0x40

    # 使能嵌入式中断 + 高通滤波（去除重力）
    i2cset -y 1 0x6a 0x58 0x90

    # 设置唤醒阈值（越小越灵敏）
    i2cset -y 1 0x6a 0x5b 0x02

    # 把唤醒事件路由到 INT1（MD1_CFG，不是 INT1_CTRL）
    i2cset -y 1 0x6a 0x5e 0x20

    echo "Done. Shake the device to trigger INT1."
    echo "Run 'i2cget -y 1 0x6a 0x1b' to clear the interrupt."
else
    echo "Disabling wake-up interrupt..."

    # 取消唤醒路由
    i2cset -y 1 0x6a 0x5e 0x00

    # 关闭嵌入式中断引擎
    i2cset -y 1 0x6a 0x58 0x00

    echo "Done. INT1 back to idle."
fi

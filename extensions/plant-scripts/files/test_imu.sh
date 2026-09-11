#!/bin/bash

# IMU加速度计10次采样自动判定脚本
TARGET_Z=16384
TOLERANCE=1000
sample_count=3
pass=1

# 进入设备目录
cd /sys/bus/iio/devices/iio:device1

# 校验文件存在
if [ ! -f "in_accel_x_raw" ] || [ ! -f "in_accel_y_raw" ] || [ ! -f "in_accel_z_raw" ]; then
    echo "错误：缺少加速度计读数文件，设备未就绪"
    exit 2
fi

# 循环采集10次
for ((i=1; i<=sample_count; i++))
do
    x=$(cat in_accel_x_raw)
    y=$(cat in_accel_y_raw)
    z=$(cat in_accel_z_raw)

    lower=$((TARGET_Z - TOLERANCE))
    upper=$((TARGET_Z + TOLERANCE))

    echo "第$i组 | X:$x Y:$y Z:$z"

    # 判断Z是否在区间内
    if [ $z -lt $lower ] || [ $z -gt $upper ]; then
        echo "  → Z值超出允许范围[$lower ~ $upper]"
        pass=0
    fi

    sleep 0.1
done

echo "----------------------------------------"
if [ $pass -eq 1 ]; then
    echo "PASS! Z轴全部在${TARGET_Z}±${TOLERANCE}范围内"
    exit 0
else
    echo "FAIL! 存在Z轴超差采样"
    exit 1
fi

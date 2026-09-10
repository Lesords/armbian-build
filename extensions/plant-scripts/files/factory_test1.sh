#!/bin/bash
# Beaglebadge工位1测试脚本

set -eu

# ====================== 测试结论======================
pass_action() {
    echo "=== 工位1测试通过 ==="
    # 先重置所有RGB为关闭状态
    for i in red green blue; do
        echo 0 > /sys/class/leds/rgb:$i/brightness
    done
    # 绿灯0.2秒间隔闪烁10秒
    for _ in $(seq 1 25); do
        echo 255 > /sys/class/leds/rgb:green/brightness
        sleep 0.2
        echo 0 > /sys/class/leds/rgb:green/brightness
        sleep 0.2
    done
    echo 0 > /sys/class/leds/rgb:green/brightness
}

fail_action() {
    echo "=== 工位1测试失败 ==="
    # 先重置所有RGB为关闭状态
    for i in red green blue; do
        echo 0 > /sys/class/leds/rgb:$i/brightness
    done
    # 红灯长亮
    echo 255 > /sys/class/leds/rgb:red/brightness
}

# Ctrl+C 直接退出
trap 'echo "进程已退出"; exit 0' INT

# 捕获所有非预期错误（LED写入失败、蜂鸣器异常等），自动调用 fail_action
trap 'fail_action; exit 1' ERR

# Event code 103 (KEY_UP)
# Event code 105 (KEY_LEFT)
# Event code 106 (KEY_RIGHT)
# Event code 108 (KEY_DOWN)
# Event code 158 (KEY_BACK)
# Event code 353 (KEY_SELECT)

echo "开始工位1测试..."

# 超时设置
START_TIMEOUT_SEC=5   # 启动等待超时，超时后跳过测试正常启动
TIMEOUT_SEC=30         # 其余按键等待超时

# 按键定义
KEY_UP=103
KEY_LEFT=105
KEY_RIGHT=106
KEY_DOWN=108
KEY_BACK=158
KEY_SELECT=353

# LED数码管路径列表（前7个为数码管1的a-g段，后7个为数码管2的a-g段）
LED_PATHS=(
    "/sys/class/leds/badge:matrix:led1_a"
    "/sys/class/leds/badge:matrix:led1_b"
    "/sys/class/leds/badge:matrix:led1_c"
    "/sys/class/leds/badge:matrix:led1_d"
    "/sys/class/leds/badge:matrix:led1_e"
    "/sys/class/leds/badge:matrix:led1_f"
    "/sys/class/leds/badge:matrix:led1_g"
    "/sys/class/leds/badge:matrix:led2_a"
    "/sys/class/leds/badge:matrix:led2_b"
    "/sys/class/leds/badge:matrix:led2_c"
    "/sys/class/leds/badge:matrix:led2_d"
    "/sys/class/leds/badge:matrix:led2_e"
    "/sys/class/leds/badge:matrix:led2_f"
    "/sys/class/leds/badge:matrix:led2_g"
)

TOTAL_LEDS=${#LED_PATHS[@]}
HALF_LEDS=$((TOTAL_LEDS / 2))

# ====================== 函数：控制数码管单个LED（点亮） ======================
control_single_led_on() {
    local led_path="$1"
    local brightness_file="${led_path}/brightness"

    if [ -f "$brightness_file" ]; then
        echo 255 > "$brightness_file"
    fi
}

# ====================== 函数：控制数码管单个LED（熄灭） ======================
control_single_led_off() {
    local led_path="$1"
    local brightness_file="${led_path}/brightness"

    if [ -f "$brightness_file" ]; then
        echo 0 > "$brightness_file"
    fi
}

# 红灯亮 5 秒，等待按 BACK 键
for i in red green blue; do
    echo 0 > /sys/class/leds/rgb:$i/brightness
done
echo 255 > /sys/class/leds/rgb:red/brightness
echo "请在5秒内按下BACK键以执行工位1测试..."

if ! timeout ${START_TIMEOUT_SEC} stdbuf -oL evtest /dev/input/event0 2>/dev/null | grep -q "code ${KEY_BACK}.*value 0"; then
    echo "未检测到KEY_BACK按键，跳过测试，系统正常启动"
    echo 0 > /sys/class/leds/rgb:red/brightness
    exit 0
fi

echo "检测到KEY_BACK，开始LED测试..."
echo 0 > /sys/class/leds/rgb:red/brightness
sleep 0.5

# 测试绿灯
echo "测试绿色LED..."
echo 255 > /sys/class/leds/rgb:green/brightness
sleep 1
echo 0 > /sys/class/leds/rgb:green/brightness
sleep 0.5

# 测试蓝灯
echo "测试蓝色LED..."
echo 255 > /sys/class/leds/rgb:blue/brightness
sleep 1
echo 0 > /sys/class/leds/rgb:blue/brightness
sleep 0.5

# 全亮（绿灯已在开启时验证过）
echo "同时点亮所有LED..."
for i in red green blue; do
    echo 255 > /sys/class/leds/rgb:$i/brightness
done
echo "RGB LED测试完成！"

# 执行蜂鸣器测试
/root/buzzer_test

echo "等待按下 KEY_SELECT 键关闭灯光..."
if ! timeout ${TIMEOUT_SEC} stdbuf -oL evtest /dev/input/event0 2>/dev/null | grep -q "code ${KEY_SELECT}.*value 0"; then
    echo "超时或未检测到 KEY_SELECT，测试失败"
    fail_action
    exit 1
fi

# 关闭所有LED
for i in red green blue; do
    echo 0 > /sys/class/leds/rgb:$i/brightness
done

# 逐对打开所有数码管LED进行测试
for ((i=0; i<HALF_LEDS; i++)); do
    control_single_led_on "${LED_PATHS[$i]}"
    control_single_led_on "${LED_PATHS[$i+HALF_LEDS]}"
    sleep 0.3
done

# 全部关闭
for ((i=0; i<TOTAL_LEDS; i++)); do
    control_single_led_off "${LED_PATHS[$i]}"
done
sleep 0.5

# 全部打开
for ((i=0; i<TOTAL_LEDS; i++)); do
    control_single_led_on "${LED_PATHS[$i]}"
done

# 等待UP键
echo "请按下 UP 键以继续..."
if ! timeout ${TIMEOUT_SEC} stdbuf -oL evtest /dev/input/event0 2>/dev/null | grep -q "code ${KEY_UP}.*value 0"; then
    echo "超时或未检测到 KEY_UP，测试失败"
    fail_action
    exit 1
fi

# 关掉a段（数码管1:索引0，数码管2:索引HALF_LEDS）
control_single_led_off "${LED_PATHS[0]}"
control_single_led_off "${LED_PATHS[$HALF_LEDS]}"
echo "a段已关闭！"

# 等待DOWN键
echo "请按下 DOWN 键以继续..."
if ! timeout ${TIMEOUT_SEC} stdbuf -oL evtest /dev/input/event0 2>/dev/null | grep -q "code ${KEY_DOWN}.*value 0"; then
    echo "超时或未检测到 KEY_DOWN，测试失败"
    fail_action
    exit 1
fi

# 关掉d段（数码管1:索引3，数码管2:索引HALF_LEDS+3）
control_single_led_off "${LED_PATHS[3]}"
control_single_led_off "${LED_PATHS[$((HALF_LEDS + 3))]}"
echo "d段已关闭！"

# 等待LEFT键
echo "请按下 LEFT 键以继续..."
if ! timeout ${TIMEOUT_SEC} stdbuf -oL evtest /dev/input/event0 2>/dev/null | grep -q "code ${KEY_LEFT}.*value 0"; then
    echo "超时或未检测到 KEY_LEFT，测试失败"
    fail_action
    exit 1
fi

# 关掉e,f段（数码管1:索引4,5，数码管2:索引HALF_LEDS+4, HALF_LEDS+5）
control_single_led_off "${LED_PATHS[4]}"
control_single_led_off "${LED_PATHS[5]}"
control_single_led_off "${LED_PATHS[$((HALF_LEDS + 4))]}"
control_single_led_off "${LED_PATHS[$((HALF_LEDS + 5))]}"
echo "e f段已关闭！"

# 等待RIGHT键
echo "请按下 RIGHT 键以继续..."
if ! timeout ${TIMEOUT_SEC} stdbuf -oL evtest /dev/input/event0 2>/dev/null | grep -q "code ${KEY_RIGHT}.*value 0"; then
    echo "超时或未检测到 KEY_RIGHT，测试失败"
    fail_action
    exit 1
fi

# 关掉b,c,g段（数码管1:索引1,2,6，数码管2:索引HALF_LEDS+1, HALF_LEDS+2, HALF_LEDS+6）
control_single_led_off "${LED_PATHS[1]}"
control_single_led_off "${LED_PATHS[2]}"
control_single_led_off "${LED_PATHS[$((HALF_LEDS + 1))]}"
control_single_led_off "${LED_PATHS[$((HALF_LEDS + 2))]}"
control_single_led_off "${LED_PATHS[6]}"
control_single_led_off "${LED_PATHS[$((HALF_LEDS + 6))]}"
echo "b c g段已关闭！"

# 测试照度传感器，连续读5次为合法数字且不等于0为测试通过
pass=1
for i in {1..5}; do
    raw=$(cat /sys/bus/iio/devices/iio:device2/in_voltage2_raw 2>/dev/null)

    if [ -z "$raw" ] || ! [[ "$raw" =~ ^[0-9]+$ ]]; then
        echo "第 $i 次读取失败：无法读取传感器"
        pass=0
        break
    fi

    if [ "$raw" -eq 0 ]; then
        echo "第 $i 次读取失败：传感器数值为0"
        pass=0
        break
    fi

    echo "第 $i 次读取 -> 当前原始值: $raw"
    sleep 1
done

if [ "$pass" -eq 0 ]; then
    echo "照度传感器测试失败"
    fail_action
    exit 1
fi

# 全部测试通过
pass_action
exit 0

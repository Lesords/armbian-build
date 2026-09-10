#!/bin/bash
echo "开始执行测试..."
echo "=================="
echo "测试 eMMC和OSPI"
lsblk

echo "测试 IIC1"
i2cdetect  -r -y 2

echo "测试 IIC2"
i2cdetect  -r -y 3

echo "测试 电量计"
i2cget -y 1 0x55 0x08 w

echo "测试 IMU"
./imu_test

echo "测试 Light Sensor"
./light_sensor

echo "测试 LEDS"
./leds_test

echo "测试 RGB"
./rgb_test

echo "测试 buzzer"
./buzzer_test

echo "测试 epaper"
./epaper_test

echo "测试 LoRa"
./lora_test &

echo "按键测试"
./key_test

killall lora_test

echo "=================="
echo "测试完成!"

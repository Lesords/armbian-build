#!/bin/bash
# 读取板载ADC通道，$1=通道号(0-3)
CH=${1:-0}
VAL=$(cat /sys/bus/iio/devices/iio:device2/in_voltage${CH}_raw)
echo "ADC${CH}:${VAL}"

#!/bin/bash
# 板载ADC测试：$1=0拉低读值, $1=1拉高读值

GPIO_NUM=603
GPIO_PATH=/sys/class/gpio/gpio${GPIO_NUM}
ADC_PATH=/sys/bus/iio/devices/iio:device2/in_voltage1_raw

# 初始化GPIO（已export则忽略busy错误）
echo ${GPIO_NUM} > /sys/class/gpio/export 2>/dev/null
echo out > ${GPIO_PATH}/direction

echo $1 > ${GPIO_PATH}/value
sleep 0.1
VAL=$(cat ${ADC_PATH})
echo "ADC:${VAL}"


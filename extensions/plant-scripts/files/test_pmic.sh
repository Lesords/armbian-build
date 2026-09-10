#!/bin/bash
# i2c_read_mv.sh
# 读取I2C总线1，设备0x55，寄存器0x08，16位无符号值转毫伏

# 获取i2cget返回十六进制字符串（格式0xXXXX）
raw_hex=$(i2cget -y 1 0x55 0x08 w)
# 剔除0x前缀
hex_str=${raw_hex#0x}
# 16位十六进制转十进制，范围0 ~ 65535(0xFFFF)
dec_num=$((16#$hex_str))

# 1LSB = 1mV，数值直接等于毫伏
mv=$dec_num

# 格式化输出
echo "Hex:$raw_hex Voltage:${mv}mV"

# 如需脚本返回数值（注意：shell退出码最大仅支持0-255，超过会溢出，不建议传大电压）
# exit $(($mv % 256))

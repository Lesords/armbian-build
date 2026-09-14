#!/bin/bash

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <mode> <product_week> <product_year> <product_serial>"
    echo "  mode: 0 (BeagleBadge A0)"
    echo "  Example: $0 0 06 26 0001"
    exit 1
fi

mode=$1
product_week=$2
product_year=$3
product_serial=$4

# ========== BeagleBadge A0 EEPROM 固定字段 ==========
header="\xaa\x55\x33\xee\x01\x37\x00\x10\x2e\x00"

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <mode> <product_week> <product_year> <product_serial>"
    echo "  mode: 0 (BeagleBadge A0)"
    echo "  Example: $0 0 06 26 0001"
    exit 1
fi

mode=$1
product_week=$2
product_year=$3
product_serial=$4

# ========== BeagleBadge A0 EEPROM 固定字段 ==========
header="\xaa\x55\x33\xee\x01\x37\x00\x10\x2e\x00"
board_name="BEAGLEBADGE-A0-\x00"
hardware_fixed="00000000000001"
week_year="${product_week}${product_year}"
board_prefix="BBDG"
pad_zero=$(printf '\x00%.0s' {1..6})
serial_12byte="${product_serial}${pad_zero}"
ddr_tlv="\x11\x02\x00\xa8\x12"
end_mark="\xfe"

if [ "$mode" = "0" ]; then
    cmd_pre="${header}${board_name}${hardware_fixed}${week_year}${board_prefix}${serial_12byte}"
    echo "mode 0: BeagleBadge A0"
else
    echo "ERROR: unsupported mode $mode"
    exit 1
fi

cmd="${cmd_pre}${ddr_tlv}${end_mark}"

# 先清空再写入
printf '\xff%.0s' {1..64} > /sys/class/i2c-dev/i2c-0/device/0-0050/eeprom
echo -en "$cmd" > /sys/class/i2c-dev/i2c-0/device/0-0050/eeprom

if [ $? -ne 0 ]; then
    echo "EEPROM_WRITE_FAIL"
    exit 1
fi

# ========== 读回验证 ==========
EEPROM_PATH="/sys/class/i2c-dev/i2c-0/device/0-0050/eeprom"

# 用hexdump读取，输出连续hex字符串
raw=$(hexdump -v -e '1/1 "%02x"' -n 66 "$EEPROM_PATH" 2>/dev/null)
if [ -z "$raw" ]; then
    echo "EEPROM_CHECK_FAIL: cannot read eeprom"
    exit 1
fi

# 验证BEAGLE标识 (偏移0x0A, 6字节 = 12个hex字符)
beagle_hex=$(echo "$raw" | cut -c 21-32)
beagle=$(printf "\\x${beagle_hex:0:2}\\x${beagle_hex:2:2}\\x${beagle_hex:4:2}\\x${beagle_hex:6:2}\\x${beagle_hex:8:2}\\x${beagle_hex:10:2}")
if [ "$beagle" != "BEAGLE" ]; then
    echo "EEPROM_CHECK_FAIL: BEAGLE header not found"
    exit 1
fi

# 提取week_year (偏移0x28, 4字节 = 8个hex字符)
wy_hex=$(echo "$raw" | cut -c 81-88)
read_week=$(printf "\\x${wy_hex:0:2}\\x${wy_hex:2:2}")
read_year=$(printf "\\x${wy_hex:4:2}\\x${wy_hex:6:2}")

# 提取serial (偏移0x30, 前6字节 = 12个hex字符，有效数据)
s_hex=$(echo "$raw" | cut -c 97-108)
read_serial=$(printf "\\x${s_hex:0:2}\\x${s_hex:2:2}\\x${s_hex:4:2}\\x${s_hex:6:2}\\x${s_hex:8:2}\\x${s_hex:10:2}")

echo "Read back: serial=$read_serial week=$read_week year=$read_year"
echo "Expected:  serial=$product_serial week=$product_week year=$product_year"

# 比对
if [ "$read_serial" = "$product_serial" ] && \
   [ "$read_week" = "$product_week" ] && \
   [ "$read_year" = "$product_year" ]; then
    echo "EEPROM_WRITE_OK"
else
    echo "EEPROM_CHECK_FAIL: serial=$read_serial week=$read_week year=$read_year"
    exit 1
fi


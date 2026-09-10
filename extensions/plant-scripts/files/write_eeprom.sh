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
board_name="BEAGLEBADGE-A0-\x00"
hardware_fixed="00000000000001"
week_year="${product_week}${product_year}"
board_prefix="BBDG"
pad_zero=$(printf '\x30%.0s' {1..6})
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
printf '\xff%.0s' {1..64} > /sys/class/i2c-dev/i2c-1/device/1-0050/eeprom
echo -en "$cmd" > /sys/class/i2c-dev/i2c-1/device/1-0050/eeprom

if [ $? -eq 0 ]; then
    echo "EEPROM_WRITE_OK"
else
    echo "EEPROM_WRITE_FAIL"
    exit 1
fi

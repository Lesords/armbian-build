#!/bin/bash
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
# WiFi扫描统计脚本
echo "========== WiFi扫描开始 =========="
result=$(nmcli dev wifi list)
echo "$result"

# 剔除表头统计数量
count=$(echo "$result" | tail -n +2 | wc -l)

echo -e "\n=================================="
echo "WIFI_COUNT:$count"

# 退出码
if [ $count -gt 0 ]; then
    exit 0
else
    exit 1
fi

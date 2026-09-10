if [ -z "$(hciconfig)" ]; then
    echo "start to enable bluetooth"
    cd /sys/kernel/debug/ieee80211/phy0/cc33xx/
    echo 1 > ./ble_enable
    sleep 1
fi

# Kill stale btmon processes from previous runs
pkill -x btmon 2>/dev/null
btmon > /tmp/cred.txt 2>&1 &
BTMON_PID=$!
sleep 1

btmgmt -i hci0 info

btmgmt -i hci0 power off

btmgmt -i hci0 le on

btmgmt -i hci0 connectable on

btmgmt -i hci0 debug-keys off

btmgmt -i hci0 sc on

btmgmt -i hci0 bondable on

btmgmt -i hci0 pairable on

btmgmt -i hci0 privacy off

btmgmt -i hci0 name cc33xxble

btmgmt -i hci0 advertising on

btmgmt -i hci0 power on

hcitool -i hci0 lerlon

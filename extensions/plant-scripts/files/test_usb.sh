#!/bin/bash
# USB Port Detect Script: Bus001 Port001 (sysfs stable detection)
TARGET_NODE="1-1"
# Short delay to avoid hotplug transient state
sleep 0.05

# Check if interface subfolders exist under target port
if compgen -G "/sys/bus/usb/devices/${TARGET_NODE}:*" > /dev/null 2>&1; then
    echo "Has device on Bus001 Port001"
    exit 0
else
    echo "No device on Bus001 Port001"
    exit 1
fi

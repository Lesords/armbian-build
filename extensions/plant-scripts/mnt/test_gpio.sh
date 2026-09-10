#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <0|1>"
    exit 1
fi

TARGET_VAL=$1

if [[ "$TARGET_VAL" != "0" && "$TARGET_VAL" != "1" ]]; then
    echo "Error: Value must be 0 or 1"
    exit 1
fi

# Base GPIO number for GPIO0_0
GPIO_BASE=519

# List of GPIO offsets provided
ALL_OFFSETS=(
    61 62 63 64 60 59 55 56 57 58 54 53
    75 76 77 78 74 73 69 70 71 72 68 67
    65 66
)

# GPIO offsets to skip - only EVT has GPIO0_75, so we skip that one for now
SKIP_OFFSETS=(75)

echo "========================================"
echo "GPIO Set Test Script (Target: $TARGET_VAL)"
echo "Base GPIO: $GPIO_BASE"
echo "Total Pins: ${#ALL_OFFSETS[@]}"
echo "========================================"

for OFFSET in "${ALL_OFFSETS[@]}"; do
    # Skip excluded offsets
    for SKIP in "${SKIP_OFFSETS[@]}"; do
        if [ "$OFFSET" = "$SKIP" ]; then
            continue 2
        fi
    done
    GPIO_NUM=$((GPIO_BASE + OFFSET))
    GPIO_PATH="/sys/class/gpio/gpio${GPIO_NUM}"
    GPIO_NAME="GPIO0_${OFFSET}"

    # 1. Export GPIO if not already exported
    if [ ! -d "$GPIO_PATH" ]; then
        # Check if we can export
        if [ ! -w /sys/class/gpio/export ]; then
             echo "Error: Cannot write to /sys/class/gpio/export. Are you root?"
             exit 1
        fi

        echo $GPIO_NUM > /sys/class/gpio/export 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "[$GPIO_NAME] ($GPIO_NUM): Failed to export (Device or resource busy?)"
            continue
        fi
        # Give it a split second to appear
        sleep 0.1
    fi

    # 2. Set direction to 'out'
    # We try to set it to 'out'. If it fails, we check if it's already out.
    if [ -w "$GPIO_PATH/direction" ]; then
        echo "out" > "$GPIO_PATH/direction" 2>/dev/null
        if [ $? -ne 0 ]; then
             # Sometimes direction is locked but writable value
             echo "[$GPIO_NAME] ($GPIO_NUM): Warning - Could not set direction to 'out'"
        fi
    fi

    # 3. Set value
    echo $TARGET_VAL > "$GPIO_PATH/value" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "[$GPIO_NAME] ($GPIO_NUM): Set to $TARGET_VAL"
    else
        echo "[$GPIO_NAME] ($GPIO_NUM): Error - Failed to write value"
    fi
done

echo "========================================"
echo "Test Complete."

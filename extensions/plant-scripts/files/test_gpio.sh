#!/bin/bash
# GPIO loopback test — each shorted pair: output->input, test 0&1, then swap
set -e

# Pair format: "GPIO_A:name_A GPIO_B:name_B"
PAIRS=(
    "572:AB11_RGMII1_TX_CTL  585:AC15_MDIO0_MDC"
    "573:W11_RGMII1_TXC      584:AC13_MDIO0_MDIO"
    "577:AA11_RGMII1_TD3     586:AB12_RGMII2_TX_CTL"
    "576:Y11_RGMII1_TD2      587:Y13_RGMII2_TXC"
    "575:W13_RGMII1_TD1      591:AA13_RGMII2_TD3"
    "574:AC10_RGMII1_TD0     590:AA12_RGMII2_TD2"
    "578:Y6_RGMII1_RX_CTL    589:AB13_RGMII2_TD1"
    "579:Y7_RGMII1_RXC       588:AC12_RGMII2_TD0"
    "583:W8_RGMII1_RD3       592:AC8_RGMII1_RX_CTL"
    "582:AA8_RGMII1_RD2      593:AC7_RGMII2_RXC"
    "581:AA6_RGMII1_RD1      597:AB8_RGMII2_RD3"
    "580:Y8_RGMII1_RD0       596:AB10_RGMII2_RD2"
)

GPIODIR=/sys/class/gpio
EXPORTED=()

cleanup() {
    for gpio in "${EXPORTED[@]}"; do
        echo "$gpio" > "$GPIODIR/unexport" 2>/dev/null || true
    done
}
trap cleanup EXIT

export_gpio() {
    local gpio=$1
    if [ ! -d "$GPIODIR/gpio$gpio" ]; then
        echo "$gpio" > "$GPIODIR/export" 2>/dev/null || return 1
        sleep 0.1
    fi
    EXPORTED+=("$gpio")
}

set_dir() {
    echo "$1" > "$GPIODIR/gpio$2/direction" 2>/dev/null
}

read_val() {
    cat "$GPIODIR/gpio$1/value" 2>/dev/null
}

# Test one pair bidirectionally
test_pair() {
    local ga=$1 na=$2 gb=$3 nb=$4

    local ok=0

    echo "=== $na($ga) <-> $nb($gb) ==="

    export_gpio "$ga" || return 1
    export_gpio "$gb" || return 1

    # A -> B
    set_dir out "$ga"
    set_dir in  "$gb"

    write_to_out 1 "$ga" "$gb"; r=$(read_val "$gb"); echo "  $na($ga) out=1  ->  $nb($gb) in=$r"; [ "$r" = "1" ] || ok=1
    write_to_out 0 "$ga" "$gb"; r=$(read_val "$gb"); echo "  $na($ga) out=0  ->  $nb($gb) in=$r"; [ "$r" = "0" ] || ok=1

    # B -> A
    set_dir out "$gb"
    set_dir in  "$ga"

    write_to_out 1 "$ga" "$gb"; r=$(read_val "$ga"); echo "  $nb($gb) out=1  ->  $na($ga) in=$r"; [ "$r" = "1" ] || ok=1
    write_to_out 0 "$ga" "$gb"; r=$(read_val "$ga"); echo "  $nb($gb) out=0  ->  $na($ga) in=$r"; [ "$r" = "0" ] || ok=1

    echo ""
    return $ok
}

write_to_out() {
    local val=$1 a=$2 b=$3
    for gpio in "$a" "$b"; do
        local dir=$(cat "$GPIODIR/gpio$gpio/direction" 2>/dev/null)
        if [ "$dir" = "out" ]; then
            echo "$val" > "$GPIODIR/gpio$gpio/value" 2>/dev/null
        fi
    done
    sleep 0.02
}

echo "=========================================="
echo "  GPIO Loopback Test"
echo "=========================================="
echo ""

PASSED=0
TOTAL=${#PAIRS[@]}

for pair in "${PAIRS[@]}"; do
    read ga na gb nb <<< "${pair//:/ }"
    if test_pair "$ga" "$na" "$gb" "$nb"; then
        PASSED=$((PASSED + 1))
    fi
done

echo "=========================================="
echo "  Result:$PASSED/$TOTAL pairs passed"
echo "=========================================="

[ "$PASSED" -eq "$TOTAL" ] && exit 0 || exit 1

#!/bin/bash
# UART bidirectional loopback test
# Usage: ./test_uart.sh [port_a] [port_b] [baud]
set -euo pipefail

PORT_A="${1:-/dev/ttyS4}"
PORT_B="${2:-/dev/ttyS5}"
BAUD="${3:-9600}"
MSG_A="HELLO_FROM_A"
MSG_B="HELLO_FROM_B"
MSG_LEN=${#MSG_A}
TIMEOUT=5

TMPDIR=$(mktemp -d)

cleanup() {
    jobs -p | xargs -r kill 2>/dev/null || true
    wait 2>/dev/null || true
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

# --- Validate ports ---
for port in "$PORT_A" "$PORT_B"; do
    if [ ! -c "$port" ]; then
        echo "ERROR: $port does not exist or is not a character device"
        exit 1
    fi
done
if [ "$PORT_A" = "$PORT_B" ]; then
    echo "ERROR: ports must be different devices"
    exit 1
fi

# --- Configure UART (9600 8N1, raw, no echo) ---
for port in "$PORT_A" "$PORT_B"; do
    if ! stty -F "$port" "$BAUD" cs8 -cstopb -parenb raw -echo -echoe -echok 2>/dev/null; then
        echo "ERROR: Failed to configure $port"
        exit 1
    fi
done

echo "=== UART Loopback Test ==="
echo "Ports: $PORT_A <-> $PORT_B @ ${BAUD} baud"

# --- Helper: blocking read from a port ---
# Starts a background cat on the given port, sends a message from
# the other port, waits for data, then kills the reader. Returns
# the received data via stdout.
read_from() {
    local listen_port=$1
    local send_port=$2
    local msg=$3
    local outfile="$TMPDIR/recv_${listen_port//\//_}"

    # Start listener
    cat "$listen_port" > "$outfile" 2>/dev/null &
    local reader=$!
    sleep 0.3

    # Send message from the other port
    printf '%s' "$msg" > "$send_port"

    # Wait for data to arrive, then stop listener
    sleep 0.4
    kill "$reader" 2>/dev/null || true
    wait "$reader" 2>/dev/null || true

    # Return received data (strip CR/LF)
    tr -d '\r\n' < "$outfile"
}

# --- Run both directions, collect results ---
pass_a=true
pass_b=true

printf '\n--- %s TX -> %s RX ---\n' "$PORT_A" "$PORT_B"
printf '  Send: "%s" from %s\n' "$MSG_A" "$PORT_A"
recv=$(read_from "$PORT_B" "$PORT_A" "$MSG_A")
printf '  Recv: "%s" on %s\n' "$recv" "$PORT_B"
if [ "$recv" != "$MSG_A" ]; then
    pass_a=false
    fail_a="  $PORT_A -> $PORT_B: expected '$MSG_A', got '$recv'"
fi

printf '\n--- %s TX -> %s RX ---\n' "$PORT_B" "$PORT_A"
printf '  Send: "%s" from %s\n' "$MSG_B" "$PORT_B"
recv=$(read_from "$PORT_A" "$PORT_B" "$MSG_B")
printf '  Recv: "%s" on %s\n' "$recv" "$PORT_A"
if [ "$recv" != "$MSG_B" ]; then
    pass_b=false
    fail_b="  $PORT_B -> $PORT_A: expected '$MSG_B', got '$recv'"
fi

# --- Final verdict ---
printf '\n'
if $pass_a && $pass_b; then
    echo "RESULT:PASS"
else
    echo "RESULT:FAIL"
    $pass_a || echo "$fail_a"
    $pass_b || echo "$fail_b"
    exit 1
fi

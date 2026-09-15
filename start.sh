#!/bin/bash

# Log under /output/ (already gitignored) instead of littering the repo root.
mkdir -p output
LOG="output/build.log"

echo "start: date=$(date) BOARD=beaglebadge RELEASE=trixie BUILD_MINIMAL=yes" > "$LOG"

./compile.sh BOARD=beaglebadge RELEASE=trixie BUILD_DESKTOP=no BUILD_MINIMAL=yes KERNEL_CONFIGURE=no

rc=$?  # must capture right after the command — any statement in between overwrites it

echo "end: date=$(date)" >> "$LOG"

if [ "$rc" -eq 0 ]; then
	echo "=== BUILD SUCCESS ($((SECONDS / 60)) min $((SECONDS % 60)) s) ===" | tee -a "$LOG"
else
	echo "=== BUILD FAILED (exit=$rc) ===" | tee -a "$LOG"
fi

exit "$rc"

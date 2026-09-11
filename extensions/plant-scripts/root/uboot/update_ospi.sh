#!/bin/bash
# update_ospi.sh — flash the bootloader stages to OSPI NOR from Linux,
# equivalent to the U-Boot "sf probe / fatload / sf update" sequence:
#
#   tiboot3.bin  -> /dev/mtd0 (ospi.tiboot3 @ 0x000000, 512K)
#   tispl.bin    -> /dev/mtd1 (ospi.tispl     @ 0x080000, 2M)
#   u-boot.img   -> /dev/mtd2 (ospi.u-boot    @ 0x280000, 4M)
#
# Firmware files are taken from /root/uboot by default (or the directory
# given as $1; put tiboot3.bin / tispl.bin / u-boot.img there).
#
# Usage:
#   /uboot/update_ospi.sh [firmware-dir]           # flash all three
#   /uboot/update_ospi.sh [firmware-dir] uboot     # only u-boot.img (lowest risk)
#   /uboot/update_ospi.sh [firmware-dir] tispl
#   /uboot/update_ospi.sh [firmware-dir] tiboot3   # highest risk: bricks OSPI boot if it fails
set -e

SRC="${1:-/root/uboot}"
WHAT="${2:-all}"

declare -A PART=( [tiboot3]=mtd0 [tispl]=mtd1 [uboot]=mtd2 )
declare -A FILE=( [tiboot3]=tiboot3.bin [tispl]=tispl.bin [uboot]=u-boot.img )

echo "==> MTD partitions:"
cat /proc/mtd

order=(uboot tispl tiboot3)   # lowest risk first
[ "$WHAT" = all ] || order=("$WHAT")

for part in "${order[@]}"; do
	f="$SRC/${FILE[$part]}"
	mtd="/dev/${PART[$part]}"
	[ -f "$f" ] || { echo "!! missing $f"; exit 1; }
	echo
	echo "==> flashcp $f -> $mtd (${PART[$part]})"
	flashcp -v "$f" "$mtd"
	echo "==> read back and compare"
	sz=$(stat -c%s "$f")
	dd if="$mtd" bs="$sz" count=1 2>/dev/null | cmp - "$f" && echo "   OK"
done

echo
echo "ALL DONE. Power-cycle to test OSPI boot."

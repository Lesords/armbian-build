#!/usr/bin/env python3
"""Bluetooth BLE scan test."""
import os
import pty
import re
import subprocess
import sys
import time

ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[a-zA-Z]")

SCAN_TIME = int(sys.argv[1]) if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else 5
DEBUG = "--debug" in sys.argv
RAW_FILE = "/tmp/bt_raw_output.txt"


START_BT_SCRIPT = os.path.expanduser("/root/beaglebadge/start_bluetooth.sh")


def bring_up_controller():
    """Bring up hci0. If not present, run start_bluetooth.sh to init."""
    try:
        out = subprocess.check_output(["hciconfig", "hci0"], text=True, stderr=subprocess.STDOUT)
        if "UP RUNNING" in out:
            return
    except Exception:
        pass

    # Try bringing it up directly first
    try:
        subprocess.run(["hciconfig", "hci0", "up"], check=True, capture_output=True)
        time.sleep(0.5)
        return
    except Exception:
        pass

    # hci0 not found or can't be brought up — run init script
    if os.path.isfile(START_BT_SCRIPT):
        print(f"hci0 not available, running {START_BT_SCRIPT} ...")
        subprocess.run([START_BT_SCRIPT], check=True)
        time.sleep(1)
    else:
        print(f"ERROR: hci0 unavailable and {START_BT_SCRIPT} not found")
        sys.exit(1)


def scan_via_pty(duration):
    """Spawn bluetoothctl in a PTY, capture all output, return device list."""
    master, slave = pty.openpty()

    pid = os.fork()
    if pid == 0:
        os.close(master)
        os.setsid()
        for fd in (0, 1, 2):
            os.dup2(slave, fd)
        os.close(slave)
        os.execvp("bluetoothctl", ["bluetoothctl"])
        sys.exit(1)

    os.close(slave)

    def cmd(s):
        try:
            os.write(master, (s + "\n").encode())
        except OSError:
            pass

    # Let bluetoothctl start up
    time.sleep(0.5)

    # Start scan
    cmd("scan on")
    time.sleep(duration)
    cmd("scan off")
    time.sleep(0.5)
    cmd("exit")

    # Read all remaining output from the PTY
    time.sleep(0.3)
    raw = b""
    while True:
        try:
            chunk = os.read(master, 4096)
            if not chunk:
                break
            raw += chunk
        except OSError:
            break

    os.waitpid(pid, 0)
    os.close(master)

    # Save raw output for debugging
    text = raw.decode(errors="replace")
    with open(RAW_FILE, "w") as f:
        f.write(text)
    if DEBUG:
        print(f"[DEBUG] Raw output saved to {RAW_FILE}")

    # Strip ANSI escape codes, then parse [NEW] Device lines
    clean = ANSI_RE.sub("", text)
    devices = []
    for line in clean.splitlines():
        s = line.strip()
        if "[NEW]" in s and "Device" in s:
            devices.append(s)

    return devices


def main():
    bring_up_controller()

    print(f"=== Bluetooth BLE Scan ===\nScanning for {SCAN_TIME}s ...\n")

    devices = scan_via_pty(SCAN_TIME)

    print("==================== Scan Result ====================")
    if devices:
        for d in devices:
            print(d)
    else:
        print("(no devices found)")
    print("------------------------------------------------------")
    print(f"Total BLE devices: {len(devices)}")

    if len(devices) == 0:
        print()
        print(f"Raw output saved to: {RAW_FILE}")
        print("Troubleshooting tips:")
        print("  1. Check raw output:   cat /tmp/bt_raw_output.txt")
        print("  2. Controller state:   hciconfig hci0")
        print("  3. RF kill status:     rfkill list")
        sys.exit(1)


if __name__ == "__main__":
    main()


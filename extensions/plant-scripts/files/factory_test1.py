#!/usr/bin/env python3
"""BeagleBadge 工位1测试脚本 - 参数化版本
用法: ./factory_test1.py <command>
Commands: back | rgb_off | rgb_red | rgb_green | rgb_blue | rgb_blink | buzzer | select | seg_all | seg_off | seg_run | up | down | left | right | sensor | pass | fail
"""

import os, select, signal, struct, subprocess, sys, time

EVENT_FORMAT = 'llHHI'
EVENT_SIZE = struct.calcsize(EVENT_FORMAT)

KEY_UP = 103
KEY_LEFT = 105
KEY_RIGHT = 106
KEY_DOWN = 108
KEY_BACK = 158
KEY_SELECT = 353

RGB_PATHS = {c: f'/sys/class/leds/rgb:{c}/brightness' for c in ('red', 'green', 'blue')}

SEGMENT_NAMES = ['a', 'b', 'c', 'd', 'e', 'f', 'g']
SEGMENT_PATHS = [
    f'/sys/class/leds/badge:matrix:led{disp}_{seg}/brightness'
    for disp in (1, 2)
    for seg in SEGMENT_NAMES
]
TOTAL_LEDS = len(SEGMENT_PATHS)

SENSOR_PATH = '/sys/bus/iio/devices/iio:device2/in_voltage2_raw'
EVENT_DEV = '/dev/input/event0'
BUZZER_BIN = '/root/buzzer_test'

TIMEOUT = 30


def sw(path, value):
    with open(path, 'w') as f:
        f.write(str(value))


def sr(path):
    with open(path, 'r') as f:
        return f.read().strip()


def rgb_all_off():
    for c in RGB_PATHS:
        sw(RGB_PATHS[c], 0)


def wait_key(code, timeout_sec, value=0):
    fd = os.open(EVENT_DEV, os.O_RDONLY)
    try:
        deadline = time.monotonic() + timeout_sec
        buf = b''
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return False
            ready, _, _ = select.select([fd], [], [], remaining)
            if not ready:
                return False
            buf += os.read(fd, EVENT_SIZE)
            while len(buf) >= EVENT_SIZE:
                chunk, buf = buf[:EVENT_SIZE], buf[EVENT_SIZE:]
                _, _, ev_type, ev_code, ev_value = struct.unpack(EVENT_FORMAT, chunk)
                if ev_type == 1 and ev_code == code and ev_value == value:
                    return True
    finally:
        os.close(fd)


def cmd_back():
    rgb_all_off()
    sw(RGB_PATHS['red'], 255)
    if not wait_key(KEY_BACK, TIMEOUT):
        print("BACK_KEY_TIMEOUT")
        rgb_all_off()
        sys.exit(0)
    rgb_all_off()
    print("BACK_KEY_OK")


def cmd_rgb_off():
    rgb_all_off()
    print("RGB_OFF_OK")


def cmd_rgb_red():
    rgb_all_off()
    sw(RGB_PATHS['red'], 255)
    print("RGB_RED_OK")


def cmd_rgb_green():
    rgb_all_off()
    sw(RGB_PATHS['green'], 255)
    print("RGB_GREEN_OK")


def cmd_rgb_blue():
    rgb_all_off()
    sw(RGB_PATHS['blue'], 255)
    print("RGB_BLUE_OK")


def cmd_buzzer():
    subprocess.run([BUZZER_BIN], check=True)
    print("BUZZER_OK")


def cmd_select():
    if not wait_key(KEY_SELECT, TIMEOUT):
        print("SELECT_KEY_TIMEOUT")
        sys.exit(1)
    rgb_all_off()
    print("SELECT_KEY_OK")


def cmd_seg_all():
    half = TOTAL_LEDS // 2
    for i in range(half):
        sw(SEGMENT_PATHS[i], 255)
        sw(SEGMENT_PATHS[i + half], 255)
        time.sleep(0.3)
    print("SEG_ALL_ON")


def cmd_seg_off():
    for i in range(TOTAL_LEDS):
        sw(SEGMENT_PATHS[i], 0)
    print("SEG_ALL_OFF")


def cmd_key_up():
    if not wait_key(KEY_UP, TIMEOUT):
        print("KEY_UP_TIMEOUT")
        sys.exit(1)
    half = TOTAL_LEDS // 2
    sw(SEGMENT_PATHS[0], 0)
    sw(SEGMENT_PATHS[half], 0)
    print("KEY_UP_OK")


def cmd_key_down():
    if not wait_key(KEY_DOWN, TIMEOUT):
        print("KEY_DOWN_TIMEOUT")
        sys.exit(1)
    half = TOTAL_LEDS // 2
    sw(SEGMENT_PATHS[3], 0)
    sw(SEGMENT_PATHS[half + 3], 0)
    print("KEY_DOWN_OK")


def cmd_key_left():
    if not wait_key(KEY_LEFT, TIMEOUT):
        print("KEY_LEFT_TIMEOUT")
        sys.exit(1)
    half = TOTAL_LEDS // 2
    for idx in (4, 5):
        sw(SEGMENT_PATHS[idx], 0)
        sw(SEGMENT_PATHS[half + idx], 0)
    print("KEY_LEFT_OK")


def cmd_key_right():
    if not wait_key(KEY_RIGHT, TIMEOUT):
        print("KEY_RIGHT_TIMEOUT")
        sys.exit(1)
    half = TOTAL_LEDS // 2
    for idx in (1, 2, 6):
        sw(SEGMENT_PATHS[idx], 0)
        sw(SEGMENT_PATHS[half + idx], 0)
    print("KEY_RIGHT_OK")


def cmd_sensor():
    for i in range(1, 6):
        try:
            raw = int(sr(SENSOR_PATH))
        except (OSError, ValueError):
            print(f"SENSOR_FAIL_{i}")
            sys.exit(1)
        if raw == 0:
            print(f"SENSOR_ZERO_{i}")
            sys.exit(1)
        time.sleep(1)
    print("SENSOR_OK")


def cmd_rgb_blink():
    """RGB三色循环闪烁：红→绿→蓝间隔0.5s，CTRL+C退出"""
    colors = ['red', 'green', 'blue']
    rgb_all_off()
    try:
        while True:
            for c in colors:
                rgb_all_off()
                sw(RGB_PATHS[c], 255)
                time.sleep(0.5)
    finally:
        rgb_all_off()


def cmd_seg_run():
    """数码管流水灯：单灯循环点亮间隔0.3s，CTRL+C退出"""
    for i in range(TOTAL_LEDS):
        sw(SEGMENT_PATHS[i], 0)
    try:
        while True:
            for i in range(TOTAL_LEDS):
                sw(SEGMENT_PATHS[(i - 1) % TOTAL_LEDS], 0)
                sw(SEGMENT_PATHS[i], 255)
                time.sleep(0.3)
    finally:
        for i in range(TOTAL_LEDS):
            sw(SEGMENT_PATHS[i], 0)


def cmd_pass():
    rgb_all_off()
    print("工位1测试通过")
    for _ in range(25):
        sw(RGB_PATHS['green'], 255)
        time.sleep(0.2)
        sw(RGB_PATHS['green'], 0)
        time.sleep(0.2)


def cmd_fail():
    rgb_all_off()
    sw(RGB_PATHS['red'], 255)
    print("工位1测试失败")


COMMANDS = {
    'back': cmd_back,
    'rgb_off': cmd_rgb_off,
    'rgb_red': cmd_rgb_red,
    'rgb_green': cmd_rgb_green,
    'rgb_blue': cmd_rgb_blue,
    'buzzer': cmd_buzzer,
    'select': cmd_select,
    'seg_all': cmd_seg_all,
    'seg_off': cmd_seg_off,
    'up': cmd_key_up,
    'down': cmd_key_down,
    'left': cmd_key_left,
    'right': cmd_key_right,
    'sensor': cmd_sensor,
    'rgb_blink': cmd_rgb_blink,
    'seg_run': cmd_seg_run,
    'pass': cmd_pass,
    'fail': cmd_fail,
}


def main():
    signal.signal(signal.SIGINT, lambda sig, frame: sys.exit(0))
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        print(f"Usage: {sys.argv[0]} <{'|'.join(sorted(COMMANDS))}>")
        sys.exit(1)
    COMMANDS[sys.argv[1]]()


if __name__ == '__main__':
    main()

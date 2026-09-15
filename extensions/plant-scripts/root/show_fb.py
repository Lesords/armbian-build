#!/usr/bin/env python3
"""BeagleBadge 屏显示工具 — 写 /dev/fb0（分辨率自适应 V1/V2）

用法:
  show_fb.py <图片>                       图片等比缩放居中
  show_fb.py -t "PASS"                    居中大字
  show_fb.py -t "FAIL" -c red -s 200
  show_fb.py -t "横屏" -r 90              顺时针旋转 90°（横装屏）

panel 未"点火"时自动触发首次 modeset（约 2 秒），无需手动介入。
"""
import sys, argparse, glob, subprocess, time
from PIL import Image, ImageDraw, ImageFont


def fb_size():
    # 从 fb0 动态读分辨率（V1 屏 800x480 / V2 屏 720x1280 自适应）
    try:
        with open("/sys/class/graphics/fb0/virtual_size") as f:
            w, h = map(int, f.read().strip().split(","))
        return w, h
    except Exception:
        return 720, 1280


FB_W, FB_H = fb_size()
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
# 依赖: python3-pil fonts-dejavu-core libdrm-tests（固件 PACKAGE_LIST 已含）


def ensure_awake():
    """panel 的 DSI 初始化只在首次 atomic commit 时发送。
    connector 尚未 enabled 时用 modetest 点火一次（V1/V2 自适应）。"""
    for c in glob.glob("/sys/class/drm/card?-DSI-*"):
        try:
            if open(c + "/enabled").read().strip() == "enabled":
                return
        except OSError:
            continue

    def first_col(cmd, skip_until=""):
        out = subprocess.run(cmd, capture_output=True, text=True).stdout
        grab = not skip_until
        for ln in out.splitlines():
            if skip_until and ln.startswith(skip_until):
                grab = True
                continue
            if grab:
                f = ln.split()
                if f and f[0].isdigit():
                    return f[0]
        return None

    conn = first_col(["modetest", "-M", "tidss", "-c"])
    crtc = first_col(["modetest", "-M", "tidss", "-p"], skip_until="CRTCs:")
    if not conn or not crtc:
        sys.exit("show_fb: cannot discover connector/crtc")
    subprocess.Popen(
        ['sh', "-c",
         'sleep 3600 | modetest -M tidss -s %s@%s:%dx%d >/dev/null 2>&1'
         % (conn, crtc, FB_W, FB_H)],
        start_new_session=True)
    time.sleep(2)
    subprocess.run(["pkill", "-x", "modetest"])


def flush(img):
    with open("/dev/fb0", "wb") as fb:
        fb.write(img.convert("RGB").tobytes("raw", "BGRX"))  # XRGB8888 小端

ap = argparse.ArgumentParser()
ap.add_argument("image", nargs="?")
ap.add_argument("-t", "--text")
ap.add_argument("-c", "--color", default="white")
ap.add_argument("-b", "--bg", default="black")
ap.add_argument("-s", "--size", type=int, default=140)
ap.add_argument("-r", "--rotate", type=int, choices=(0, 90, 180, 270),
                default=0, help="内容顺时针旋转角度")
a = ap.parse_args()

# 在"逻辑画布"上排版（旋转后的正向分辨率），最后转回物理方向
if a.rotate in (90, 270):
    W, H = FB_H, FB_W
else:
    W, H = FB_W, FB_H

img = Image.new("RGB", (W, H), a.bg)
if a.image:
    src = Image.open(a.image)
    r = min(W / src.width, H / src.height)
    src = src.resize((int(src.width * r), int(src.height * r)))
    img.paste(src, ((W - src.width) // 2, (H - src.height) // 2))
if a.text:
    d = ImageDraw.Draw(img)
    d.text((W // 2, H // 2), a.text,
           font=ImageFont.truetype(FONT, a.size), fill=a.color, anchor="mm")

if a.rotate == 90:      # 画布横 -> 物理竖：顺时针转 90
    img = img.transpose(Image.Transpose.ROTATE_270)
elif a.rotate == 180:
    img = img.transpose(Image.Transpose.ROTATE_180)
elif a.rotate == 270:
    img = img.transpose(Image.Transpose.ROTATE_90)
img = img.resize((FB_W, FB_H))
ensure_awake()
flush(img)

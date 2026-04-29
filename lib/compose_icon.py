#!/usr/bin/env python3
"""
从 clawd-on-desk 的 GIF 中抽取最饱满的一帧，按设定的留白比例 nearest-neighbor
放大到 1024x1024，合成奶白底，输出 PNG。

用法:
    compose_icon.py <gif_path> <output_png>
        [--bg R,G,B] [--pad-ratio 0.12] [--canvas 1024]
"""
import argparse
import sys
from PIL import Image


def parse_color(s: str):
    parts = [int(x) for x in s.split(",")]
    if len(parts) == 3:
        return (parts[0], parts[1], parts[2], 255)
    if len(parts) == 4:
        return tuple(parts)
    raise ValueError(f"bad color: {s!r}")


def best_frame(gif_path: str):
    im = Image.open(gif_path)
    n = getattr(im, "n_frames", 1)
    best = None
    for i in range(n):
        im.seek(i)
        f = im.convert("RGBA")
        bbox = f.getbbox()
        if bbox is None:
            continue
        area = (bbox[2] - bbox[0]) * (bbox[3] - bbox[1])
        if best is None or area > best[1]:
            best = (i, area, bbox, f)
    if best is None:
        raise RuntimeError(f"{gif_path}: no non-transparent frame")
    _, _, bbox, frame = best
    return frame.crop(bbox)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("gif")
    ap.add_argument("output")
    ap.add_argument("--bg", default="245,237,220",
                    help="背景色 R,G,B 或 R,G,B,A (默认奶白)")
    ap.add_argument("--pad-ratio", type=float, default=0.12,
                    help="四周留白占画布比例 (默认 0.12 → 12%%)")
    ap.add_argument("--canvas", type=int, default=1024)
    args = ap.parse_args()

    bg = parse_color(args.bg)
    crab = best_frame(args.gif)

    inner = int(args.canvas * (1 - 2 * args.pad_ratio))
    cw, ch = crab.size
    scale = inner / max(cw, ch)
    nw, nh = max(1, int(cw * scale)), max(1, int(ch * scale))
    crab_big = crab.resize((nw, nh), Image.NEAREST)

    canvas = Image.new("RGBA", (args.canvas, args.canvas), bg)
    canvas.paste(crab_big,
                 ((args.canvas - nw) // 2, (args.canvas - nh) // 2),
                 crab_big)
    canvas.save(args.output)
    print(f"{args.output}  canvas={args.canvas} crab={nw}x{nh}", file=sys.stderr)


if __name__ == "__main__":
    main()

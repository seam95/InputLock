"""
菜单栏图标生成脚本 v6
从两张源图生成 MenuBarIcon（普通）和 MenuBarIconLocked（锁定）两套图标。
普通图标直接缩放；锁定图标使用普通图标 + 程序化合成蓝色圆点（避免背景残留问题）。
使用 "original" 渲染模式保留颜色。
"""

import os
import json
import math
from PIL import Image, ImageDraw

# ── 配置 ──────────────────────────────────────────────
NORMAL_SOURCE = '/Users/seam/Downloads/菜单栏图标.png'
LOCKED_SOURCE = '/Users/seam/Downloads/锁定输入法时的菜单栏图标.png'

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_PATH = os.path.join(PROJECT_ROOT, 'InputLock/InputLock/Assets.xcassets')
NORMAL_ICON_SET = os.path.join(ASSETS_PATH, 'MenuBarIcon.imageset')
LOCKED_ICON_SET = os.path.join(ASSETS_PATH, 'MenuBarIconLocked.imageset')

BASE_HEIGHT = 22  # 菜单栏图标基础高度(pt)


def crop_to_content(img):
    """裁剪到内容区域，去除多余透明边距"""
    pixels = img.load()
    width, height = img.size
    left, top, right, bottom = width, height, 0, 0
    found = False

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a > 20:
                left = min(left, x)
                right = max(right, x)
                top = min(top, y)
                bottom = max(bottom, y)
                found = True

    if not found:
        return img

    return img.crop((left, top, right + 1, bottom + 1))


def analyze_blue_dot(locked_img, normal_img):
    """
    分析锁定图标中蓝色圆点的位置和大小。
    通过比较两张图的差异来定位蓝色圆点。
    返回 (center_x_ratio, center_y_ratio, radius_ratio) 相对于图片高度的比例。
    """
    import numpy as np
    locked = np.array(locked_img.convert('RGBA')).astype(float)
    h, w = locked.shape[:2]

    # 寻找蓝色像素: B通道高且与R通道差距大
    r, g, b = locked[:, :, 0], locked[:, :, 1], locked[:, :, 2]
    blue_mask = (b > 150) & ((b - r) > 30)

    if not blue_mask.any():
        print("警告：未检测到蓝色圆点，使用默认位置")
        return 0.83, 0.86, 0.15

    ys, xs = np.where(blue_mask)
    center_x = (xs.min() + xs.max()) / 2
    center_y = (ys.min() + ys.max()) / 2
    radius = max(xs.max() - xs.min(), ys.max() - ys.min()) / 2

    print(f"检测到蓝色圆点: center=({center_x:.0f},{center_y:.0f}), radius={radius:.0f}")
    return center_x / w, center_y / h, radius / h


def draw_blue_dot(img, cx_ratio, cy_ratio, radius_ratio):
    """
    在图片上绘制蓝色渐变圆点。
    参数为相对比例（相对于图片尺寸）。
    """
    import numpy as np
    width, height = img.size
    cx = cx_ratio * width
    cy = cy_ratio * height
    radius = radius_ratio * height

    pixels = np.array(img).astype(float)

    for y in range(max(0, int(cy - radius - 2)), min(height, int(cy + radius + 3))):
        for x in range(max(0, int(cx - radius - 2)), min(width, int(cx + radius + 3))):
            dist = math.sqrt((x - cx) ** 2 + (y - cy) ** 2)
            if dist > radius:
                continue

            # 归一化距离 0(中心) -> 1(边缘)
            t = dist / radius

            # 径向渐变：中心亮青蓝 -> 边缘深蓝 -> 外围淡化
            if t < 0.5:
                # 内部：亮青色
                s = t / 0.5
                r = 20 + s * 10
                g = 250 - s * 100
                b = 255
                a = 255
            elif t < 0.85:
                # 中间：过渡到深蓝
                s = (t - 0.5) / 0.35
                r = 30 - s * 25
                g = 150 - s * 20
                b = 255 - s * 25
                a = 255
            else:
                # 边缘：淡出
                s = (t - 0.85) / 0.15
                r = 5
                g = 130
                b = 230
                a = int(255 * (1 - s * s))

            # Alpha 合成
            src_a = a / 255.0
            dst_a = pixels[y, x, 3] / 255.0

            if src_a > 0:
                out_a = src_a + dst_a * (1 - src_a)
                if out_a > 0:
                    pixels[y, x, 0] = (r * src_a + pixels[y, x, 0] * dst_a * (1 - src_a)) / out_a
                    pixels[y, x, 1] = (g * src_a + pixels[y, x, 1] * dst_a * (1 - src_a)) / out_a
                    pixels[y, x, 2] = (b * src_a + pixels[y, x, 2] * dst_a * (1 - src_a)) / out_a
                    pixels[y, x, 3] = out_a * 255

    return Image.fromarray(pixels.clip(0, 255).astype('uint8'), 'RGBA')


def save_imageset(img, icon_set_path, name_prefix, rendering_intent="original"):
    """生成 1x/2x/3x 图标并写入 Contents.json"""
    os.makedirs(icon_set_path, exist_ok=True)

    aspect_ratio = img.width / img.height
    scales = [("1x", BASE_HEIGHT), ("2x", BASE_HEIGHT * 2), ("3x", BASE_HEIGHT * 3)]
    images_json = []

    for scale, h in scales:
        w = int(h * aspect_ratio)
        resized = img.resize((w, h), Image.Resampling.LANCZOS)
        filename = f'{name_prefix}_{scale}.png'
        resized.save(os.path.join(icon_set_path, filename))
        images_json.append({
            "idiom": "universal",
            "filename": filename,
            "scale": scale
        })
        print(f"  {filename}: {w}x{h}")

    contents = {
        "images": images_json,
        "info": {"version": 1, "author": "xcode"},
        "properties": {
            "template-rendering-intent": rendering_intent
        }
    }
    with open(os.path.join(icon_set_path, 'Contents.json'), 'w') as f:
        json.dump(contents, f, indent=2)


def main():
    # 打开源图
    normal_img = Image.open(NORMAL_SOURCE).convert('RGBA')
    locked_img = Image.open(LOCKED_SOURCE).convert('RGBA')
    print(f"普通图标源: {normal_img.size}")
    print(f"锁定图标源: {locked_img.size}")

    # 分析蓝色圆点位置
    cx_ratio, cy_ratio, radius_ratio = analyze_blue_dot(locked_img, normal_img)
    print(f"圆点比例: cx={cx_ratio:.3f}, cy={cy_ratio:.3f}, r={radius_ratio:.3f}")

    # 裁剪普通图标
    cropped_normal = crop_to_content(normal_img)
    print(f"裁剪后普通图标: {cropped_normal.size}")

    # 生成普通图标 imageset
    print("\n生成 MenuBarIcon:")
    save_imageset(cropped_normal, NORMAL_ICON_SET, "menubar")

    # 基于裁剪后的普通图标合成锁定图标
    # 需要重新计算蓝色圆点在裁剪后坐标系中的位置
    orig_w, orig_h = normal_img.size
    crop_bbox = crop_to_content(normal_img).getbbox()  # None if empty

    # 重新计算裁剪偏移
    pixels = normal_img.load()
    left, top = orig_w, orig_h
    right, bottom = 0, 0
    for y in range(orig_h):
        for x in range(orig_w):
            if pixels[x, y][3] > 20:
                left = min(left, x)
                right = max(right, x)
                top = min(top, y)
                bottom = max(bottom, y)

    crop_left, crop_top = left, top
    crop_w = right - left + 1
    crop_h = bottom - top + 1

    # 转换蓝色圆点坐标到裁剪后坐标系
    # 源锁定图标尺寸与普通图标略有差异，做归一化
    dot_cx_in_cropped = (cx_ratio * locked_img.width - crop_left) / crop_w
    dot_cy_in_cropped = (cy_ratio * locked_img.height - crop_top) / crop_h
    dot_r_in_cropped = (radius_ratio * locked_img.height) / crop_h

    print(f"\n裁剪后圆点位置: cx={dot_cx_in_cropped:.3f}, cy={dot_cy_in_cropped:.3f}, r={dot_r_in_cropped:.3f}")

    locked_result = draw_blue_dot(
        cropped_normal.copy(), dot_cx_in_cropped, dot_cy_in_cropped, dot_r_in_cropped
    )

    # 生成锁定图标 imageset
    print("\n生成 MenuBarIconLocked:")
    save_imageset(locked_result, LOCKED_ICON_SET, "menubar_locked")

    print("\n完成！")


if __name__ == '__main__':
    main()

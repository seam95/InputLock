"""
菜单栏图标生成脚本 v7
将图钉源图转换为 macOS template 模板图标（黑色 + Alpha），
与系统菜单栏其他图标风格一致，自动适配亮/暗模式。
锁定状态的蓝色圆点由 Swift 代码动态绘制，不再生成单独的 imageset。
"""

import os
import json
from PIL import Image

# ── 配置 ──────────────────────────────────────────────
SOURCE_IMAGE = '/Users/seam/Downloads/菜单栏图标.png'

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_PATH = os.path.join(PROJECT_ROOT, 'InputLock/InputLock/Assets.xcassets')
ICON_SET_PATH = os.path.join(ASSETS_PATH, 'MenuBarIcon.imageset')

BASE_HEIGHT = 18  # 菜单栏图标基础高度(pt)


def crop_to_content(img):
    """裁剪到内容区域，去除多余透明边距"""
    pixels = img.load()
    width, height = img.size
    left, top, right, bottom = width, height, 0, 0
    found = False

    for y in range(height):
        for x in range(width):
            _, _, _, a = pixels[x, y]
            if a > 20:
                left = min(left, x)
                right = max(right, x)
                top = min(top, y)
                bottom = max(bottom, y)
                found = True

    if not found:
        return img

    return img.crop((left, top, right + 1, bottom + 1))


def convert_to_template(img):
    """
    将彩色图标转换为 macOS template 图标。
    可见像素全部设为纯黑不透明，无半透明渐变。
    """
    pixels = img.load()
    width, height = img.size

    for y in range(height):
        for x in range(width):
            _, _, _, a = pixels[x, y]
            if a < 50:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (0, 0, 0, 255)

    return img


def main():
    img = Image.open(SOURCE_IMAGE).convert('RGBA')
    print(f"源图尺寸: {img.size}")

    # 裁剪到内容区域
    img = crop_to_content(img)
    print(f"裁剪后: {img.size}")

    # 转换为 template 图标
    img = convert_to_template(img)

    # 生成 1x/2x/3x
    os.makedirs(ICON_SET_PATH, exist_ok=True)
    aspect_ratio = img.width / img.height
    scales = [("1x", BASE_HEIGHT), ("2x", BASE_HEIGHT * 2), ("3x", BASE_HEIGHT * 3)]
    images_json = []

    for scale, h in scales:
        w = int(h * aspect_ratio)
        resized = img.resize((w, h), Image.Resampling.LANCZOS)
        filename = f'menubar_{scale}.png'
        resized.save(os.path.join(ICON_SET_PATH, filename))
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
            "template-rendering-intent": "template"
        }
    }
    with open(os.path.join(ICON_SET_PATH, 'Contents.json'), 'w') as f:
        json.dump(contents, f, indent=2)

    print(f"\n模板图标已生成: {ICON_SET_PATH}")


if __name__ == '__main__':
    main()

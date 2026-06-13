import os
import json
from PIL import Image

# Use the generated high-res icon as source since the clipboard file is gone
SOURCE_IMAGE_PATH = 'InputLock/InputLock/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png'
PROJECT_ROOT = '.'
ASSETS_PATH = os.path.join(PROJECT_ROOT, 'InputLock/InputLock/Assets.xcassets')
APP_ICON_SET_PATH = os.path.join(ASSETS_PATH, 'AppIcon.appiconset')

def update_app_icon_v2():
    if not os.path.exists(SOURCE_IMAGE_PATH):
        print(f"Error: Source image not found at {SOURCE_IMAGE_PATH}")
        return

    try:
        img = Image.open(SOURCE_IMAGE_PATH).convert("RGBA")
        print(f"Source Image Size: {img.size}")
    except Exception as e:
        print(f"Error opening image: {e}")
        return

    # 1. Smart Crop to remove the "Outer Plate"
    # Content definition: Opaque (>50) AND Dark (<85).
    # This avoids selecting the transparent background (which is "dark" 0) 
    # and the lighter outer plate (which is >85).
    
    # Split channels
    r, g, b, a = img.split()
    gray = img.convert("L")
    
    # Create Binary Masks
    # Alpha Mask: 1 if A > 50
    mask_a = a.point(lambda p: 1 if p > 50 else 0, mode="1")
    
    # Brightness Mask: 1 if L < 88 (Increased slightly from 85 to be safe, assuming plate is ~96)
    mask_l = gray.point(lambda p: 1 if p < 88 else 0, mode="1")
    
    # Combine: Content = A & L
    # We can use ImageChops.logical_and or just manual pixel manipulation if needed.
    # But PIL doesn't have logical_and for "1" mode easily accessible in one line without imports?
    # Actually ImageChops is standard.
    from PIL import ImageChops
    mask = ImageChops.logical_and(mask_a, mask_l)
    
    bbox = mask.getbbox()
    
    if bbox:
        # Add a small padding (e.g. 2%)
        pad = int(min(img.width, img.height) * 0.02)
        l, t, r, b_box = bbox # rename b to b_box to avoid conflict
        l = max(0, l - pad)
        t = max(0, t - pad)
        r = min(img.width, r + pad)
        b = min(img.height, b_box + pad)
        
        img = img.crop((l, t, r, b))
        print(f"Smart Cropped to inner content: {img.size} (BBox: {bbox})")
    else:
        print("Warning: Could not detect inner dark content with threshold 85. Falling back to simple trim.")
        bbox = img.getbbox()
        if bbox:
            img = img.crop(bbox)

    # 2. Resize to square if needed
    
    # 2. Resize to square if needed
    # If the cropped image is rectangular, we should center it in a square canvas?
    # Or crop the center?
    # Usually App Icons are square. If the content is 38x30, scaling to square might distort.
    # Let's check aspect ratio.
    w, h = img.size
    if w != h:
        print(f"Warning: Image is not square ({w}x{h}). Expanding canvas to square.")
        max_dim = max(w, h)
        new_img = Image.new("RGBA", (max_dim, max_dim), (0, 0, 0, 0))
        offset_x = (max_dim - w) // 2
        offset_y = (max_dim - h) // 2
        new_img.paste(img, (offset_x, offset_y))
        img = new_img

    # 3. Generate Sizes
    os.makedirs(APP_ICON_SET_PATH, exist_ok=True)
    
    defined_sizes = [16, 32, 128, 256, 512]
    images_json = []

    for size in defined_sizes:
        # 1x
        filename_1x = f'icon_{size}x{size}.png'
        resized_1x = img.resize((size, size), Image.Resampling.LANCZOS)
        resized_1x.save(os.path.join(APP_ICON_SET_PATH, filename_1x))
        images_json.append({
            "size": f"{size}x{size}",
            "idiom": "mac",
            "filename": filename_1x,
            "scale": "1x"
        })
        
        # 2x
        size_2x = size * 2
        filename_2x = f'icon_{size}x{size}@2x.png'
        resized_2x = img.resize((size_2x, size_2x), Image.Resampling.LANCZOS)
        resized_2x.save(os.path.join(APP_ICON_SET_PATH, filename_2x))
        images_json.append({
            "size": f"{size}x{size}",
            "idiom": "mac",
            "filename": filename_2x,
            "scale": "2x"
        })

    contents = {
        "images": images_json,
        "info": {
            "version": 1,
            "author": "xcode"
        }
    }

    with open(os.path.join(APP_ICON_SET_PATH, 'Contents.json'), 'w') as f:
        json.dump(contents, f, indent=2)
    
    print(f"Successfully updated AppIcon (Cropped & Filled) at {APP_ICON_SET_PATH}")

if __name__ == "__main__":
    update_app_icon_v2()

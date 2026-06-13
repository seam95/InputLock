import os
import json
from PIL import Image

SOURCE_IMAGE_PATH = '.gemini-clipboard/clipboard-1769658162554.png'
PROJECT_ROOT = '.'
ASSETS_PATH = os.path.join(PROJECT_ROOT, 'InputLock/InputLock/Assets.xcassets')
APP_ICON_SET_PATH = os.path.join(ASSETS_PATH, 'AppIcon.appiconset')

def update_app_icon():
    if not os.path.exists(SOURCE_IMAGE_PATH):
        print(f"Error: Source image not found at {SOURCE_IMAGE_PATH}")
        return

    try:
        img = Image.open(SOURCE_IMAGE_PATH)
        print(f"Source Image Size: {img.size}, Mode: {img.mode}")
    except Exception as e:
        print(f"Error opening image: {e}")
        return

    # Ensure directory exists
    os.makedirs(APP_ICON_SET_PATH, exist_ok=True)

    # Standard macOS AppIcon sizes
    # size_pt: (scale, filename_suffix)
    # 16: 1x, 2x
    # 32: 1x, 2x
    # 128: 1x, 2x
    # 256: 1x, 2x
    # 512: 1x, 2x
    
    defined_sizes = [16, 32, 128, 256, 512]
    images_json = []

    for size in defined_sizes:
        # 1x
        filename_1x = f'icon_{size}x{size}.png'
        # Resize using LANCZOS for high quality downsampling
        resized_1x = img.resize((size, size), Image.Resampling.LANCZOS)
        save_path_1x = os.path.join(APP_ICON_SET_PATH, filename_1x)
        resized_1x.save(save_path_1x)
        
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
        save_path_2x = os.path.join(APP_ICON_SET_PATH, filename_2x)
        resized_2x.save(save_path_2x)
        
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
    
    print(f"Successfully updated AppIcon at {APP_ICON_SET_PATH}")

if __name__ == "__main__":
    update_app_icon()

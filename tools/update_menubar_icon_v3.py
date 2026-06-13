import os
import json
from PIL import Image

SOURCE_IMAGE_PATH = '/Users/seam/Downloads/Copilot_20260129_112110.png'
PROJECT_ROOT = '.'
ASSETS_PATH = os.path.join(PROJECT_ROOT, 'InputLock/InputLock/Assets.xcassets')
ICON_SET_PATH = os.path.join(ASSETS_PATH, 'MenuBarIcon.imageset')

def update_menubar_icon_v3():
    if not os.path.exists(SOURCE_IMAGE_PATH):
        print(f"Error: Source image not found at {SOURCE_IMAGE_PATH}")
        return

    try:
        img = Image.open(SOURCE_IMAGE_PATH).convert("RGBA")
        print(f"Source Image Size: {img.size}")
    except Exception as e:
        print(f"Error opening image: {e}")
        return

    os.makedirs(ICON_SET_PATH, exist_ok=True)

    # Logic to create Template Image (Black + Alpha)
    # 1. Background (Original Alpha=0) -> New Alpha=0
    # 2. White Details (R,G,B > 200) -> New Alpha=0 (Transparent, to show menu bar color)
    # 3. Dark Icon (R,G,B < 200) -> New Alpha=255 (Opaque, will be rendered as Text Color)

    datas = img.getdata()
    new_alpha_data = []

    for item in datas:
        r, g, b, a = item
        # If original is transparent, keep transparent
        if a < 50:
            new_alpha_data.append(0)
        # If original is white (or very light gray), make transparent
        # This handles the "keyhole" or "key outlines" being white
        elif r > 200 and g > 200 and b > 200:
            new_alpha_data.append(0)
        # Otherwise (Dark/Black), make Opaque
        else:
            new_alpha_data.append(255)

    # Create the new alpha channel image
    alpha_img = Image.new('L', img.size)
    alpha_img.putdata(new_alpha_data)

    # Create pure black base
    black_base = Image.new('L', img.size, 0)
    
    # Merge
    template_img = Image.merge('LA', (black_base, alpha_img))

    # Calculate sizes
    aspect_ratio = img.width / img.height
    sizes = [("1x", 18), ("2x", 36), ("3x", 54)]
    images_json = []

    for scale, height in sizes:
        width = int(height * aspect_ratio)
        resized = template_img.resize((width, height), Image.Resampling.LANCZOS)
        
        filename = f'menubar_{scale}.png'
        save_path = os.path.join(ICON_SET_PATH, filename)
        resized.save(save_path)
        
        images_json.append({
            "idiom": "universal",
            "filename": filename,
            "scale": scale
        })

    contents = {
        "images": images_json,
        "info": {
            "version": 1,
            "author": "xcode"
        },
        "properties": {
            "template-rendering-intent": "template"
        }
    }

    with open(os.path.join(ICON_SET_PATH, 'Contents.json'), 'w') as f:
        json.dump(contents, f, indent=2)
    
    print(f"Successfully updated MenuBarIcon (v3 Smart Transparent) at {ICON_SET_PATH}")

if __name__ == "__main__":
    update_menubar_icon_v3()

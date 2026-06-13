import os
import json
from PIL import Image, ImageOps

SOURCE_IMAGE_PATH = '/Users/seam/Downloads/Copilot_20260129_112110.png'
PROJECT_ROOT = '.'
ASSETS_PATH = os.path.join(PROJECT_ROOT, 'InputLock/InputLock/Assets.xcassets')
ICON_SET_PATH = os.path.join(ASSETS_PATH, 'MenuBarIcon.imageset')

def update_menubar_icon_v2():
    if not os.path.exists(SOURCE_IMAGE_PATH):
        print(f"Error: Source image not found at {SOURCE_IMAGE_PATH}")
        return

    try:
        img = Image.open(SOURCE_IMAGE_PATH)
        print(f"Source Image Size: {img.size}, Mode: {img.mode}")
    except Exception as e:
        print(f"Error opening image: {e}")
        return

    os.makedirs(ICON_SET_PATH, exist_ok=True)

    # 1. Convert to grayscale
    gray = img.convert('L')
    
    # 2. Create Alpha channel (Transparency)
    # Strategy: Invert grayscale. 
    # White (255) in source becomes 0 (Transparent) in Alpha.
    # Black (0) in source becomes 255 (Opaque) in Alpha.
    alpha = ImageOps.invert(gray)
    
    # 3. Clean up the background (Optional but good for strict "No Background")
    # Force very light pixels to be completely transparent to avoid "dirty" box effect
    # Any alpha value < 20 (originally very close to white) becomes 0
    alpha = alpha.point(lambda p: 0 if p < 15 else p)

    # 4. Create pure black base
    # Template images typically use black for the content shape.
    black_base = Image.new('L', img.size, 0)
    
    # 5. Merge: Black Color + Calculated Alpha
    # Result: Transparent background, Black icon
    template_img = Image.merge('LA', (black_base, alpha))

    # Verify top-left pixel is transparent
    tl_pixel = template_img.getpixel((0,0))
    print(f"Top-Left Pixel of Template (Should be Alpha 0): {tl_pixel}")

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

    # JSON Configuration
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
    
    print(f"Successfully updated MenuBarIcon (Transparent Background) at {ICON_SET_PATH}")

if __name__ == "__main__":
    update_menubar_icon_v2()

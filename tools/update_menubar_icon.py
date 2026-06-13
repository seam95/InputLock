import os
import json
from PIL import Image, ImageOps

SOURCE_IMAGE_PATH = '/Users/seam/Downloads/Copilot_20260129_112110.png'
PROJECT_ROOT = '.'
ASSETS_PATH = os.path.join(PROJECT_ROOT, 'InputLock/InputLock/Assets.xcassets')
ICON_SET_PATH = os.path.join(ASSETS_PATH, 'MenuBarIcon.imageset')

def update_menubar_icon():
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
    os.makedirs(ICON_SET_PATH, exist_ok=True)

    # Convert to template (Black on Transparent)
    # Source is likely Black Icon on White Background.
    
    # 1. Convert to grayscale
    gray = img.convert('L')
    
    # 2. Create alpha channel.
    # We want dark pixels from source to be opaque (high alpha).
    # We want light pixels from source to be transparent (low alpha).
    # 
    # In 'L' mode: Black=0, White=255.
    # In Alpha channel: Transparent=0, Opaque=255.
    #
    # So we need to map Source Black(0) -> Alpha Opaque(255)
    #                Source White(255) -> Alpha Transparent(0)
    #
    # This is exactly what ImageOps.invert does: 0->255, 255->0.
    alpha = ImageOps.invert(gray)
    
    # 3. Create a solid black image for the color channels
    # The actual color doesn't matter for a template image as long as alpha is correct,
    # but strictly speaking, a template image is usually black with varying alpha.
    black_base = Image.new('L', img.size, 0)
    
    # 4. Merge to create RGBA (or LA)
    # We use LA (Luminance + Alpha) for compactness, or RGBA. 
    # Let's use RGBA to be safe with all tools.
    template_img = Image.merge('LA', (black_base, alpha))

    # Calculate sizes based on height
    # 1x: 18pt -> 18px height
    # 2x: 18pt -> 36px height
    # 3x: 18pt -> 54px height
    
    aspect_ratio = img.width / img.height
    
    sizes = [
        ("1x", 18), 
        ("2x", 36), 
        ("3x", 54)
    ]
    
    images_json = []

    for scale, height in sizes:
        width = int(height * aspect_ratio)
        
        # Resize using LANCZOS
        resized = template_img.resize((width, height), Image.Resampling.LANCZOS)
        
        filename = f'menubar_{scale}.png'
        save_path = os.path.join(ICON_SET_PATH, filename)
        resized.save(save_path)
        
        images_json.append({
            "idiom": "universal",
            "filename": filename,
            "scale": scale
        })
        print(f"Generated {scale}: {width}x{height}")

    # Contents.json for Template Image
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
    
    print(f"Successfully updated MenuBarIcon at {ICON_SET_PATH}")

if __name__ == "__main__":
    update_menubar_icon()

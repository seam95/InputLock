import os
import json
from PIL import Image

SOURCE_IMAGE_PATH = '/Users/seam/Downloads/Copilot_20260129_140831.png'
PROJECT_ROOT = '.'
ASSETS_PATH = os.path.join(PROJECT_ROOT, 'InputLock/InputLock/Assets.xcassets')
ICON_SET_PATH = os.path.join(ASSETS_PATH, 'MenuBarIcon.imageset')

def update_menubar_icon_v5():
    if not os.path.exists(SOURCE_IMAGE_PATH):
        print(f"Error: Source image not found at {SOURCE_IMAGE_PATH}")
        return

    try:
        img = Image.open(SOURCE_IMAGE_PATH).convert("RGBA")
    except Exception as e:
        print(f"Error opening image: {e}")
        return

    os.makedirs(ICON_SET_PATH, exist_ok=True)

    # 1. Crop to Content (Remove Padding)
    # Get the bounding box of non-transparent/non-white content
    # First, creating a binary version to find bbox easily
    # Treat White and Transparent as "Background"
    def is_content(pixel):
        r, g, b, a = pixel
        if a < 50: return False # Transparent
        if r > 200 and g > 200 and b > 200: return False # White
        return True

    # Get data and find bounds
    width, height = img.size
    left, top, right, bottom = width, height, 0, 0
    found_content = False
    
    pixels = img.load()
    
    for y in range(height):
        for x in range(width):
            if is_content(pixels[x, y]):
                if x < left: left = x
                if x > right: right = x
                if y < top: top = y
                if y > bottom: bottom = y
                found_content = True

    if found_content:
        # Add a tiny bit of padding (1-2px) so it's not touching the edge
        padding = 0
        left = max(0, left - padding)
        top = max(0, top - padding)
        right = min(width, right + 1 + padding)
        bottom = min(height, bottom + 1 + padding)
        
        img = img.crop((left, top, right, bottom))
        print(f"Cropped to content: {img.size}")
    else:
        print("No content found to crop!")

    # 2. Logic to create Template Image (Black + Alpha)
    datas = img.getdata()
    new_alpha_data = []

    for item in datas:
        r, g, b, a = item
        # Treat transparent or white as transparent in the result
        if a < 50:
            new_alpha_data.append(0)
        elif r > 200 and g > 200 and b > 200:
            new_alpha_data.append(0)
        else:
            # Everything else becomes solid black content (template)
            new_alpha_data.append(255)

    alpha_img = Image.new('L', img.size)
    alpha_img.putdata(new_alpha_data)
    black_base = Image.new('L', img.size, 0)
    template_img = Image.merge('LA', (black_base, alpha_img))

    # 3. Resize
    # Standard menu bar icon height is often around 18pt-22pt.
    # Since we stripped all padding, 22pt might feel "full height". 
    # Let's try 20pt as a balanced "Standard" size.
    # 1x: 20px
    # 2x: 40px
    # 3x: 60px
    
    base_height = 20
    aspect_ratio = img.width / img.height
    
    sizes = [
        ("1x", base_height), 
        ("2x", base_height * 2), 
        ("3x", base_height * 3)
    ]
    
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
    
    print(f"Successfully updated MenuBarIcon (v5 Cropped & Resized) at {ICON_SET_PATH}")

if __name__ == "__main__":
    update_menubar_icon_v5()

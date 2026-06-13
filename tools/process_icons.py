import os
import json
from PIL import Image, ImageOps

SOURCE_IMAGE_PATH = '/Users/seam/Downloads/Copilot_20260129_094457.png'
PROJECT_ROOT = '/Users/seam/Documents/02-Personal/Code/inputLock'
ASSETS_PATH = os.path.join(PROJECT_ROOT, 'InputLock/InputLock/Assets.xcassets')

def get_bbox(img, threshold=250):
    """Finds the bounding box of the non-white content."""
    # Convert to grayscale
    gray = img.convert('L')
    # Invert (so dark pixels become bright)
    inverted = ImageOps.invert(gray)
    # Threshold to clear out near-white noise
    # Any pixel > threshold (in inverted, so near black in original) is kept
    # We want to keep dark pixels.
    # In original: White is 255. Dark is < 255.
    # In inverted: White is 0. Dark is > 0.
    # Let's just use getbbox on the inverted image.
    return inverted.getbbox()

def process_app_icon(img):
    icon_set_path = os.path.join(ASSETS_PATH, 'AppIcon.appiconset')
    os.makedirs(icon_set_path, exist_ok=True)

    sizes = [16, 32, 64, 128, 256, 512, 1024]
    images_json = []

    for size in sizes:
        # standard 1x
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        filename = f'AppIcon-{size}.png'
        resized.save(os.path.join(icon_set_path, filename))
        images_json.append({
            "size": f"{size}x{size}",
            "idiom": "mac",
            "filename": filename,
            "scale": "1x"
        })
        
        # 2x
        size_2x = size * 2
        if size_2x <= 1024: # standard mac icons usually go up to 1024 (which is 512@2x)
             # Actually, the 1024 icon is 512pt @2x.
             # Let's follow standard macOS set: 
             # 16x16 (1x, 2x)
             # 32x32 (1x, 2x)
             # 128x128 (1x, 2x)
             # 256x256 (1x, 2x)
             # 512x512 (1x, 2x)
             pass

    # Re-doing the sizes list to match standard macOS AppIcon requirements strictly
    # mac: 16x16 (@1x, @2x), 32x32 (@1x, @2x), 128x128 (@1x, @2x), 256x256 (@1x, @2x), 512x512 (@1x, @2x)
    
    defined_sizes = [16, 32, 128, 256, 512]
    images_json = []
    
    for size in defined_sizes:
        # 1x
        filename_1x = f'icon_{size}x{size}.png'
        img.resize((size, size), Image.Resampling.LANCZOS).save(os.path.join(icon_set_path, filename_1x))
        images_json.append({
            "size": f"{size}x{size}",
            "idiom": "mac",
            "filename": filename_1x,
            "scale": "1x"
        })
        
        # 2x
        filename_2x = f'icon_{size}x{size}@2x.png'
        img.resize((size*2, size*2), Image.Resampling.LANCZOS).save(os.path.join(icon_set_path, filename_2x))
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
    
    with open(os.path.join(icon_set_path, 'Contents.json'), 'w') as f:
        json.dump(contents, f, indent=2)

def process_menubar_icon(img):
    icon_set_path = os.path.join(ASSETS_PATH, 'MenuBarIcon.imageset')
    os.makedirs(icon_set_path, exist_ok=True)
    
    # Convert to black and white for template
    # Assuming the input is black on white bg
    # We want Black on Transparent.
    
    # 1. Convert to grayscale
    gray = img.convert('L')
    
    # 2. Create alpha channel: 
    # Invert grayscale so that Black (text/icon) becomes White (opaque) 
    # and White (bg) becomes Black (transparent)
    alpha = ImageOps.invert(gray)
    
    # 3. Create a solid black image
    black_img = Image.new('L', img.size, 0) # 0 is black
    
    # 4. Put alpha into black image
    # Result: Black pixels where original was black, Transparent where original was white
    result = Image.merge('LA', (black_img, alpha))
    
    # Resize logic
    # Target height: 18pt
    # 1x: 18px height
    # 2x: 36px height
    # 3x: 54px height
    
    aspect_ratio = img.width / img.height
    
    sizes = [("1x", 18), ("2x", 36), ("3x", 54)]
    images_json = []
    
    for scale, height in sizes:
        width = int(height * aspect_ratio)
        resized = result.resize((width, height), Image.Resampling.LANCZOS)
        
        filename = f'menubar_{scale}.png'
        resized.save(os.path.join(icon_set_path, filename))
        
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
    
    with open(os.path.join(icon_set_path, 'Contents.json'), 'w') as f:
        json.dump(contents, f, indent=2)


def main():
    try:
        full_img = Image.open(SOURCE_IMAGE_PATH)
    except Exception as e:
        print(f"Error opening image: {e}")
        return

    width, height = full_img.size
    
    # Split roughly in half
    left_crop_initial = full_img.crop((0, 0, width // 2, height))
    right_crop_initial = full_img.crop((width // 2, 0, width, height))
    
    # Find exact bounding boxes
    left_bbox = get_bbox(left_crop_initial)
    right_bbox = get_bbox(right_crop_initial)
    
    if not left_bbox:
        print("Could not find content in the left half of the image.")
        return
    if not right_bbox:
        print("Could not find content in the right half of the image.")
        return
        
    # Crop to content
    left_icon = left_crop_initial.crop(left_bbox)
    right_icon = right_crop_initial.crop(right_bbox)
    
    # Process
    print("Processing Menu Bar Icon...")
    process_menubar_icon(left_icon)
    
    print("Processing App Icon...")
    # For App Icon, we might want to ensure it's square if it's not already
    # Most app icon designs in the source image are already square-ish or contained in a shape.
    # The description says "contained within a rounded square frame".
    # We should probably crop it square if the bbox isn't square, to avoid distortion, 
    # or just pad it?
    # Let's check aspect ratio.
    if right_icon.width != right_icon.height:
        print(f"Warning: Right icon is not square ({right_icon.width}x{right_icon.height}). Padding to square.")
        max_dim = max(right_icon.width, right_icon.height)
        new_img = Image.new("RGBA", (max_dim, max_dim), (255, 255, 255, 0)) # Transparent pad
        # Paste centered
        x = (max_dim - right_icon.width) // 2
        y = (max_dim - right_icon.height) // 2
        new_img.paste(right_icon, (x, y))
        right_icon = new_img

    process_app_icon(right_icon)
    print("Done.")

if __name__ == "__main__":
    main()

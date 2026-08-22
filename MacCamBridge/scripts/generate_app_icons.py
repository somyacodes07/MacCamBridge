import os
import subprocess
from PIL import Image

def generate_icons():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    base_dir = os.path.abspath(os.path.join(script_dir, ".."))
    svg_path = os.path.join(base_dir, "logo.svg")
    master_png = os.path.join(base_dir, "logo.png")
    
    print("Generating 1024x1024 PNG from SVG using qlmanage...")
    subprocess.run(["qlmanage", "-t", "-s", "1024", "-o", base_dir, svg_path], check=True)
    
    temp_png = os.path.join(base_dir, "logo.svg.png")
    if os.path.exists(temp_png):
        if os.path.exists(master_png):
            os.remove(master_png)
        os.rename(temp_png, master_png)
    
    print(f"Master PNG created at {master_png}")
    img = Image.open(master_png).convert("RGBA")
    
    # 1. Generate Windows ICO file
    ico_path = os.path.join(base_dir, "MacCamBridge.ico")
    ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    img.save(ico_path, format="ICO", sizes=ico_sizes)
    print(f"Windows EXE icon generated at {ico_path}")

    # 2. Generate macOS .iconset for iconutil (.icns)
    iconset_dir = os.path.join(base_dir, "MacCamBridge.iconset")
    os.makedirs(iconset_dir, exist_ok=True)
    
    iconset_mapping = [
        ("icon_16x16.png", (16, 16)),
        ("icon_16x16@2x.png", (32, 32)),
        ("icon_32x32.png", (32, 32)),
        ("icon_32x32@2x.png", (64, 64)),
        ("icon_128x128.png", (128, 128)),
        ("icon_128x128@2x.png", (256, 256)),
        ("icon_256x256.png", (256, 256)),
        ("icon_256x256@2x.png", (512, 512)),
        ("icon_512x512.png", (512, 512)),
        ("icon_512x512@2x.png", (1024, 1024)),
    ]
    
    for filename, size in iconset_mapping:
        resized = img.resize(size, Image.Resampling.LANCZOS)
        resized.save(os.path.join(iconset_dir, filename), "PNG")
        
    icns_path = os.path.join(base_dir, "MacCamBridge.icns")
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", icns_path], check=True)
    import shutil
    shutil.rmtree(iconset_dir, ignore_errors=True)
    print(f"macOS DMG/App ICNS icon generated at {icns_path}")

    # 3. Populate Assets.xcassets/AppIcon.appiconset
    appiconset_dir = os.path.join(base_dir, "Assets.xcassets", "AppIcon.appiconset")
    os.makedirs(appiconset_dir, exist_ok=True)

    appicon_sizes = [
        (16, 1, "16x16", "1x"),
        (32, 2, "16x16", "2x"),
        (32, 1, "32x32", "1x"),
        (64, 2, "32x32", "2x"),
        (128, 1, "128x128", "1x"),
        (256, 2, "128x128", "2x"),
        (256, 1, "256x256", "1x"),
        (512, 2, "256x256", "2x"),
        (512, 1, "512x512", "1x"),
        (1024, 2, "512x512", "2x"),
    ]

    images_json = []

    for pixel_size, scale_num, point_size, scale_str in appicon_sizes:
        filename = f"icon_{pixel_size}x{pixel_size}.png"
        resized = img.resize((pixel_size, pixel_size), Image.Resampling.LANCZOS)
        resized.save(os.path.join(appiconset_dir, filename), "PNG")
        
        images_json.append({
            "idiom": "mac",
            "size": point_size,
            "scale": scale_str,
            "filename": filename
        })

    contents_json = {
        "images": images_json,
        "info": {
            "version": 1,
            "author": "xcode"
        }
    }

    import json
    with open(os.path.join(appiconset_dir, "Contents.json"), "w") as f:
        json.dump(contents_json, f, indent=2)

    print(f"Updated Xcode AppIcon asset catalog at {appiconset_dir}")

if __name__ == "__main__":
    generate_icons()

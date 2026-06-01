import os
from PIL import Image
import shutil

# Base resolution (Current icons are optimized for this size)
BASE_RES = 280.0
ICON_SCALE_AT_BASE = 0.55

# Target resolutions and their folder names
# Format: (width, height, folder_suffix)
TARGETS = [
    (454, 454, "454x454"),
    (416, 416, "416x416"),
    (390, 390, "390x390"),
    (360, 360, "360x360"),
    (280, 280, "280x280"), # Baseline
    (260, 260, "260x260"),
    (240, 240, "240x240"), # Covers both round and square 240
    (448, 486, "venux1"), # Venu X1 - Force device specific folder to ensure selection
    (218, 218, "218x218"),
    (208, 208, "208x208"),   # fr55
    (197, 197, "197x197"),   # fr165, fr165m
    (176, 176, "176x176"),   # instinct2 series (6 devices)
]

SOURCE_DIR = "/home/edward/git/watch/GarminSugar/resources"
ICONS_DIR = os.path.join(SOURCE_DIR, "icons")
DRAWABLES_XML = os.path.join(SOURCE_DIR, "drawables", "drawables.xml")

def main():
    if not os.path.exists(ICONS_DIR):
        print(f"Error: Source icons directory not found at {ICONS_DIR}")
        return

    # Get list of icon files
    icon_files = [f for f in os.listdir(ICONS_DIR) if f.endswith(".png")]
    print(f"Found {len(icon_files)} icons to resize: {icon_files}")

    for width, height, folder_suffix in TARGETS:
        # Calculate scale factor based on WIDTH only
        scale = (width / BASE_RES) * ICON_SCALE_AT_BASE
        print(f"\nProcessing for {folder_suffix} (Scale: {scale:.2f} = {width}/{BASE_RES} × {ICON_SCALE_AT_BASE})")

        # Create target directories
        target_res_dir = os.path.join(SOURCE_DIR + "-" + folder_suffix)

        # Icons must live inside the drawables/ subtree — Garmin CIQ forbids
        # path traversal (../) in drawables.xml within qualifier folders.
        target_drawables_dir = os.path.join(target_res_dir, "drawables")
        target_icons_dir = os.path.join(target_drawables_dir, "icons")

        os.makedirs(target_icons_dir, exist_ok=True)

        # 1. Resize Icons
        for icon_file in icon_files:
            src_path = os.path.join(ICONS_DIR, icon_file)
            dst_path = os.path.join(target_icons_dir, icon_file)

            try:
                with Image.open(src_path) as img:
                    # Calculate new size
                    new_width = int(img.width * scale)
                    new_height = int(img.height * scale)
                    
                    # Resize using LANCZOS for high quality
                    resized_img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
                    resized_img.save(dst_path)
                    print(f"  - Resized {icon_file}: {img.size} -> {resized_img.size}")
            except Exception as e:
                print(f"  - Failed to resize {icon_file}: {e}")

        # 2. Resize Launcher Icon
        try:
            launcher_src = os.path.join(SOURCE_DIR, "drawables", "launcher_icon.png")
            launcher_dst = os.path.join(target_drawables_dir, "launcher_icon.png")
            
            if os.path.exists(launcher_src):
                with Image.open(launcher_src) as img:
                    new_width = int(img.width * scale)
                    new_height = int(img.height * scale)
                    resized_img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
                    resized_img.save(launcher_dst)
                    print(f"  - Resized launcher_icon.png: {img.size} -> {resized_img.size}")
            else:
                print("  - Warning: launcher_icon.png not found in source")
        except Exception as e:
            print(f"  - Failed to resize launcher_icon.png: {e}")

        # 3. Write drawables.xml with corrected icon paths.
        # Base uses "../icons/" (relative to drawables/ subdir pointing up to resource root).
        # In qualifier folders, path traversal is forbidden; icons sit at "icons/" inside drawables/.
        try:
            with open(DRAWABLES_XML, "r") as f:
                xml_content = f.read()
            xml_content = xml_content.replace("../icons/", "icons/")
            with open(os.path.join(target_drawables_dir, "drawables.xml"), "w") as f:
                f.write(xml_content)
            print("  - Wrote drawables.xml (paths normalised)")
        except Exception as e:
            print(f"  - Failed to write drawables.xml: {e}")

        # 4. Write Debug String
        try:
            target_strings_dir = os.path.join(target_res_dir, "strings")
            os.makedirs(target_strings_dir, exist_ok=True)
            with open(os.path.join(target_strings_dir, "debug.xml"), "w") as f:
                f.write(f'<strings>\n    <string id="DebugResFolder">{folder_suffix}</string>\n</strings>')
            print(f"  - Wrote debug string: {folder_suffix}")
        except Exception as e:
            print(f"  - Failed to write debug string: {e}")

if __name__ == "__main__":
    main()

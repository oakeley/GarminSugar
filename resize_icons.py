import os
from PIL import Image
import shutil

# Base resolution (Current icons are optimized for this size)
BASE_RES = 280.0

# Target resolutions and their folder names
# Format: (resolution_px, folder_suffix)
TARGETS = [
    (454, "round-454x454"),
    (416, "round-416x416"),
    (390, "round-390x390"),
    (360, "round-360x360"),
    (280, "round-280x280"), # Baseline
    (260, "round-260x260"),
    (240, "round-240x240"),
    (218, "round-218x218"),
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

    for res, folder_suffix in TARGETS:
        # Calculate scale factor
        scale = res / BASE_RES
        print(f"\nProcessing for {folder_suffix} (Scale: {scale:.2f})")

        # Create target directories
        target_res_dir = os.path.join(SOURCE_DIR + "-" + folder_suffix)
        target_icons_dir = os.path.join(target_res_dir, "icons")
        target_drawables_dir = os.path.join(target_res_dir, "drawables")

        os.makedirs(target_icons_dir, exist_ok=True)
        os.makedirs(target_drawables_dir, exist_ok=True)

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

        # 3. Key Step: Copy drawables.xml
        # We need to copy the drawables.xml so that this specific resource qualifier folder
        # has a definition of the drawables that points to the LOCAL icons folder.
        # Since the original drawables.xml points to "../icons/foo.png", putting it in
        # "resources-round-XXX/drawables/" means it will look in "resources-round-XXX/icons/",
        # which is exactly where we put the resized icons.
        try:
            shutil.copy(DRAWABLES_XML, os.path.join(target_drawables_dir, "drawables.xml"))
            print("  - Copied drawables.xml")
        except Exception as e:
            print(f"  - Failed to copy drawables.xml: {e}")

if __name__ == "__main__":
    main()

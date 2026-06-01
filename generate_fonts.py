import os
import re
from PIL import Image, ImageDraw, ImageFont

# Configuration
FONTS_CONFIG = [
    {
        "id": "id_time_font",
        "ttf_path": "resources/fonts/Roboto-Bold.ttf",
        "chars": "0123456789:.+- min°",
        "px": 40,  # Large: time and glucose value
    },
    {
        "id": "id_small_font",
        "ttf_path": "resources/fonts/Roboto-Thin.ttf",
        "chars": "0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz°/:.-+%",
        "px": 16,  # Replaces FONT_SYSTEM_XTINY: date, temp, time-diff, HR value
    },
    {
        "id": "id_tiny_font",
        "ttf_path": "resources/fonts/Roboto-Thin.ttf",
        "chars": "0123456789 abcdefghijklmnopqrstuvwxyz°/:.-+%",
        "px": 16,  # Replaces FONT_XTINY: seconds, am/pm, steps, battery, altitude
    },
]

# Base resolution for 'resources/' folder (Fenix 8 Solar 51mm = 280x280 MIP)
DEFAULT_BASE_RES = 280 
BASE_DIR = os.getcwd()

def get_next_power_of_two(n):
    return 1 << (n - 1).bit_length()



def generate_bmfont(font_config, res, output_dir):
    font_id = font_config["id"]
    ttf_path = font_config.get("ttf_path")
    chars = font_config["chars"]
    size = int(font_config["px"] * res / DEFAULT_BASE_RES)
    font = None
    try:
        font = ImageFont.truetype(ttf_path, size)
    except Exception as e:
        print(f"Error loading font {ttf_path}: {e}")
        return None, None

    max_h = 0
    total_w = 0
    chars_data = []
    
    # Metrics
    ascent, descent = font.getmetrics()
    line_height = ascent + descent

        
    padding = 4 

    for char in chars:
        bbox = font.getbbox(char)
        if bbox:
            w = bbox[2] - bbox[0]
            h = bbox[3] - bbox[1]
        else:
            w = font.getlength(char)
            h = 0
            w = int(w)
        advance = int(font.getlength(char))

        
        chars_data.append({
            'char': char,
            'id': ord(char),
            'w': w,
            'h': h,
            'advance': advance,
            'xoffset': 0,
            'yoffset': 0
        })
        total_w += (w + padding)
        if (h + padding) > max_h:
            max_h = h + padding

    area = total_w * line_height
    side = int(area**0.5)
    # Increase sizing factor to be safe for row packing
    atlas_w = get_next_power_of_two(max(int(side * 1.5), max_h * 2))
    if atlas_w < 64: atlas_w = 64
    atlas_h = atlas_w
    
    img = Image.new('RGBA', (atlas_w, atlas_h), (0, 0, 0, 0))
    # Draw context
    main_draw = ImageDraw.Draw(img)
    
    cursor_x = 0
    cursor_y = 0
    row_h = 0
    
    final_chars = []
    
    # Not using temp image for custom draw to simplify, drawing direct to atlas
    # Actually, loop structure:
    
    for glyph in chars_data:
        char = glyph['char']
        width = glyph['w']
        height = glyph['h']
        
        if cursor_x + width + padding > atlas_w:
            cursor_x = 0
            cursor_y += row_h + padding
            row_h = 0
            
        if cursor_y + height + padding > atlas_h:
            print(f"Atlas too small for size {size}!")
            return None, None
            
        # Draw Glyph
        # TTF Render
        temp_size = int(size * 2) # Render larger? No, size is font size.
        # Using temp img to handle bbox cropping
        temp_img = Image.new('RGBA', (temp_size, temp_size), (0,0,0,0))
        temp_draw = ImageDraw.Draw(temp_img)
        temp_draw.text((0, 0), char, font=font, fill="white")
        
        bbox = temp_img.getbbox()
        if bbox:
            cropped = temp_img.crop(bbox)
            img.paste(cropped, (cursor_x, cursor_y))
            glyph['x'] = cursor_x
            glyph['y'] = cursor_y
            glyph['w'] = cropped.width
            glyph['h'] = cropped.height
            glyph['xoffset'] = bbox[0]
            glyph['yoffset'] = bbox[1]
        else:
            glyph['x'] = 0
            glyph['y'] = 0
            glyph['w'] = 0
            glyph['h'] = 0
            glyph['xoffset'] = 0
            glyph['yoffset'] = 0
                
        cursor_x += width + padding
        if height > row_h:
            row_h = height
            
        final_chars.append(glyph)

    png_filename = f"{font_id}.png"
    png_path = os.path.join(output_dir, png_filename)
    img.save(png_path)
    
    fnt_content = []
    fnt_content.append(f'info face="Roboto" size={size} bold=1 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1 outline=0')
    fnt_content.append(f'common lineHeight={line_height} base={ascent} scaleW={atlas_w} scaleH={atlas_h} pages=1 packed=0 alphaChnl=0 redChnl=0 greenChnl=0 blueChnl=0')
    fnt_content.append(f'page id=0 file="{png_filename}"')
    fnt_content.append(f'chars count={len(final_chars)}')
    
    for c in final_chars:
        fnt_content.append(f'char id={c["id"]} x={c["x"]} y={c["y"]} width={c["w"]} height={c["h"]} xoffset={c["xoffset"]} yoffset={c["yoffset"]} xadvance={c["advance"]} page=0 chnl=15')
        
    fnt_path = os.path.join(output_dir, f"{font_id}.fnt")
    with open(fnt_path, "w") as f:
        f.write("\n".join(fnt_content))
        
    return png_filename, f"{font_id}.fnt"

def find_resolution_folders():
    folders = []
    for item in os.listdir(BASE_DIR):
        if os.path.isdir(item) and item.startswith("resources"):
            # Try to parse resolution
            match = re.search(r"(\d+)x(\d+)", item)
            if match:
                res = int(match.group(1)) # Use width (or height, usually square-ish)
                folders.append((item, res))
            elif "venux1" in item:
                folders.append((item, 448)) # Hardcoded Venu X1 width
            elif item == "resources":
                folders.append((item, DEFAULT_BASE_RES))
    return folders

def main():
    print("Generating BMFonts from TTF...")
    
    folders = find_resolution_folders()
    
    for folder_name, res in folders:
        folder_path = os.path.join(BASE_DIR, folder_name)
        fonts_dir = os.path.join(folder_path, "fonts")
        
        if not os.path.exists(fonts_dir):
            os.makedirs(fonts_dir)

        # Generate each font config
        generated_fonts = []
        for conf in FONTS_CONFIG:
            png, fnt = generate_bmfont(conf, res, fonts_dir)
            if png and fnt:
                generated_fonts.append((conf["id"], fnt))
                print(f"Generated {fnt} for {folder_name} (res {res})")

        # Update fonts.xml
        xml_path = os.path.join(fonts_dir, "fonts.xml")
        
        # We rewrite fonts.xml with the generated fonts
        # We can just write a fresh one since we control the fonts now.
        # But we should preserve if there are other system fonts? 
        # The user only has these 2 custom fonts usually.
        # Let's write a clean file to avoid duplication issues.
        
        xml_lines = ['<fonts>']
        for font_id, filename in generated_fonts:
            xml_lines.append(f'    <font id="{font_id}" filename="{filename}" antialias="true" />')
        
        # Add the restored arrows.fnt bitmap font explicitly
        xml_lines.append(f'    <font id="id_arrows_font" filename="arrows.fnt" filter="↑↓→↗↘x"/>')
        
        xml_lines.append('</fonts>')
        
        with open(xml_path, "w") as f:
            f.write("\n".join(xml_lines))
            
        print(f"Updated fonts.xml for {folder_name}")

if __name__ == "__main__":
    main()

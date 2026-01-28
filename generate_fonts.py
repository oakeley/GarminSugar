import os
import re
from PIL import Image, ImageDraw, ImageFont

# Configuration
FONT_ID = "id_time_font"
TTF_PATH = "resources/fonts/Roboto-Bold.ttf"
CHAR_SET = "0123456789:.+- min°"

# Base resolution for 'resources/' folder (Fenix 8 Solar 51mm = 280x280 MIP)
DEFAULT_BASE_RES = 280 

FONT_SCALE = 0.17
SCALE_OVERRIDES = {}
BASE_DIR = os.getcwd()

def get_next_power_of_two(n):
    return 1 << (n - 1).bit_length()

def generate_bmfont(res, size, output_dir):
    try:
        font = ImageFont.truetype(TTF_PATH, size)
    except Exception as e:
        print(f"Error loading font {TTF_PATH}: {e}")
        return None, None

    max_h = 0
    total_w = 0
    chars_data = []

    ascent, descent = font.getmetrics()
    line_height = ascent + descent
    padding = 2

    for char in CHAR_SET:
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
    atlas_w = get_next_power_of_two(max(side, max_h * 2))
    if atlas_w < 64: atlas_w = 64
    atlas_h = atlas_w
    
    img = Image.new('RGBA', (atlas_w, atlas_h), (0, 0, 0, 0))
    
    cursor_x = 0
    cursor_y = 0
    row_h = 0
    
    final_chars = []
    
    temp_size = int(size * 2)
    temp_img = Image.new('RGBA', (temp_size, temp_size), (0,0,0,0))
    temp_draw = ImageDraw.Draw(temp_img)
    
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
        
        temp_draw.rectangle((0, 0, temp_size, temp_size), fill=(0,0,0,0))
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
            # yoffset logic:
            # We want to align the "top" visual edge properly.
            # Using bbox[1] (top empty space) as yoffset often works to align to the logical top line.
            glyph['yoffset'] = bbox[1]
            
            cursor_x += cropped.width + padding
            if cropped.height > row_h:
                row_h = cropped.height
        else:
            glyph['x'] = 0
            glyph['y'] = 0
            glyph['w'] = 0
            glyph['h'] = 0
            glyph['xoffset'] = 0
            glyph['yoffset'] = 0
            
        final_chars.append(glyph)

    png_filename = f"{FONT_ID}.png"
    png_path = os.path.join(output_dir, png_filename)
    img.save(png_path)
    
    fnt_content = []
    # common lineHeight is critical for vertical centering
    fnt_content.append(f'info face="Roboto" size={size} bold=1 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1 outline=0')
    fnt_content.append(f'common lineHeight={line_height} base={ascent} scaleW={atlas_w} scaleH={atlas_h} pages=1 packed=0 alphaChnl=0 redChnl=0 greenChnl=0 blueChnl=0')
    fnt_content.append(f'page id=0 file="{png_filename}"')
    fnt_content.append(f'chars count={len(final_chars)}')
    
    for c in final_chars:
        fnt_content.append(f'char id={c["id"]} x={c["x"]} y={c["y"]} width={c["w"]} height={c["h"]} xoffset={c["xoffset"]} yoffset={c["yoffset"]} xadvance={c["advance"]} page=0 chnl=15')
        
    fnt_path = os.path.join(output_dir, f"{FONT_ID}.fnt")
    with open(fnt_path, "w") as f:
        f.write("\n".join(fnt_content))
        
    return png_filename, f"{FONT_ID}.fnt"

def find_resolution_folders():
    folders = []
    for item in os.listdir(BASE_DIR):
        if os.path.isdir(item) and item.startswith("resources"):
            # Try to parse resolution
            match = re.search(r"(\d+)x(\d+)", item)
            if match:
                res = int(match.group(1)) # Use width (or height, usually square-ish)
                folders.append((item, res))
            elif item == "resources":
                folders.append((item, DEFAULT_BASE_RES))
    return folders

def main():
    print("Generating BMFonts...")
    
    folders = find_resolution_folders()
    
    for folder_name, res in folders:
        folder_path = os.path.join(BASE_DIR, folder_name)
        fonts_dir = os.path.join(folder_path, "fonts")
        
        if not os.path.exists(fonts_dir):
            os.makedirs(fonts_dir)
            
        scale_factor = SCALE_OVERRIDES.get(res, FONT_SCALE)
        size = int(res * scale_factor)
        png_file, fnt_file = generate_bmfont(res, size, fonts_dir)
        
        if png_file and fnt_file:
            # Check/Update fonts.xml in that directory
            xml_path = os.path.join(fonts_dir, "fonts.xml")
            
            # Read existing
            if os.path.exists(xml_path):
                with open(xml_path, "r") as f:
                    lines = f.readlines()
            else:
                lines = ["<fonts>\n", "</fonts>\n"]

            # Merge
            new_lines = []
            found = False
            for line in lines:
                if FONT_ID in line:
                    new_lines.append(f'    <font id="{FONT_ID}" filename="{fnt_file}" antialias="true" />\n')
                    found = True
                elif "</fonts>" in line and not found:
                     new_lines.append(f'    <font id="{FONT_ID}" filename="{fnt_file}" antialias="true" />\n')
                     new_lines.append(line)
                else:
                     new_lines.append(line)
            
            with open(xml_path, "w") as f:
                f.writelines(new_lines)
                
            print(f"Generated {fnt_file} for {folder_name} (res {res}, size {size})")

if __name__ == "__main__":
    main()

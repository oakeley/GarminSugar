import os
from PIL import Image

def parse_fnt(file_path):
    with open(file_path, 'r') as f:
        lines = f.readlines()
    
    parsed = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        
        parts = line.split()
        entry_type = parts[0]
        
        data = {'_type': entry_type}
        for part in parts[1:]:
            if '=' in part:
                key, val = part.split('=', 1)
                
                # Try parsing integers
                if val.lstrip('-').isdigit():
                    val = int(val)
                # Parse strings (removing quotes)
                elif val.startswith('"') and val.endswith('"'):
                    val = val[1:-1]
                    
                data[key] = val
        parsed.append(data)
    return parsed

def serialize_fnt(parsed, file_path):
    lines = []
    for entry in parsed:
        line_parts = [entry['_type']]
        for k, v in entry.items():
            if k == '_type':
                continue
            
            # Re-quote strings if they were strings in original (e.g. face="Black Diamonds", file="arrows_0.png")
            # We explicitly know these keys need quotes
            if k in ['face', 'charset', 'file']:
                line_parts.append(f'{k}="{v}"')
            else:
                line_parts.append(f'{k}={v}')
                
        # Format padding/spacing appropriately
        if entry['_type'] == 'char':
            # Try to match the original spacing structure for chars loosely
            # e.g char id=45   x=179   y=0     width=16    height=4     xoffset=1     yoffset=11    xadvance=17    page=0  chnl=15
            id_part = f"id={entry['id']:<4}"
            x_part = f"x={entry['x']:<4}"
            y_part = f"y={entry['y']:<4}"
            w_part = f"width={entry['width']:<4}"
            h_part = f"height={entry['height']:<4}"
            xo_part = f"xoffset={entry['xoffset']:<4}"
            yo_part = f"yoffset={entry['yoffset']:<4}"
            xa_part = f"xadvance={entry['xadvance']:<4}"
            page_part = f"page={entry['page']} "
            chnl_part = f"chnl={entry['chnl']}"
            
            line_str = f"char {id_part} {x_part} {y_part} {w_part} {h_part} {xo_part} {yo_part} {xa_part} {page_part} {chnl_part}"
            lines.append(line_str)
        else:
            lines.append(" ".join(line_parts))
            
    with open(file_path, 'w') as f:
        f.write("\n".join(lines) + "\n")

def scale_font(fnt_path, png_path, scale_factor=0.75):
    if not os.path.exists(fnt_path) or not os.path.exists(png_path):
        print(f"Skipping {fnt_path} / {png_path} - missing files")
        return
        
    print(f"Scaling {fnt_path} by {scale_factor}")
    
    # 1. Scale FNT Geometries
    parsed = parse_fnt(fnt_path)
    
    for entry in parsed:
        if entry['_type'] == 'info':
            if 'size' in entry and isinstance(entry['size'], int):
                entry['size'] = int(entry['size'] * scale_factor)
                
        elif entry['_type'] == 'common':
            for k in ['lineHeight', 'base', 'scaleW', 'scaleH']:
                if k in entry:
                    # Minimum 1 for height/base, except maybe scaleW/H need to track the image size
                    entry[k] = max(1, int(entry[k] * scale_factor))
                    
        elif entry['_type'] == 'char':
            for k in ['x', 'y', 'width', 'height', 'xoffset', 'yoffset', 'xadvance']:
                if k in entry:
                    if k in ['width', 'height', 'xadvance']:
                        entry[k] = max(1, int(entry[k] * scale_factor))
                    else:
                        entry[k] = int(entry[k] * scale_factor)
                        
    # 2. Scale PNG Image
    with Image.open(png_path) as img:
        new_w = max(1, int(img.width * scale_factor))
        new_h = max(1, int(img.height * scale_factor))
        
        # Determine sampling mode (NEAREST or LANCZOS). 
        # For bitmap fonts (usually white on transparent), LANCZOS is okay, 
        # but might make edges fuzzy. Let's use LANCZOS for smoothness since we're shrinking
        resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
        resized.save(png_path)
        
        # Update scaleW and scaleH just in case to exactly match image dimensions
        for entry in parsed:
            if entry['_type'] == 'common':
                entry['scaleW'] = new_w
                entry['scaleH'] = new_h
                break
                
    # Save modified fnt
    serialize_fnt(parsed, fnt_path)
    print(f"  -> Successfully scaled image to {new_w}x{new_h} and updated FNT")

def main():
    base_dir = "."
    target_scale_for_280 = 0.85
    base_res = 280.0
    
    nas_backup_dir = "/home/edward/nas_data/Disk_copy/19/git/watch/GarminSugar/resources/fonts"
    nas_fnt_path = os.path.join(nas_backup_dir, "arrows.fnt")
    nas_png_path = os.path.join(nas_backup_dir, "arrows_0.png")

    if not os.path.exists(nas_fnt_path) or not os.path.exists(nas_png_path):
        print(f"Error: Original backup files not found in {nas_backup_dir}")
        return

    import re
    import shutil
    
    for item in os.listdir(base_dir):
        if os.path.isdir(item) and item.startswith("resources"):
            # Determine resolution
            res = base_res
            match = re.search(r"(\d+)x(\d+)", item)
            if match:
                res = float(match.group(1))
            elif "venux1" in item:
                res = 448.0
            
            # Calculate dynamic scale for this folder
            scale_factor = target_scale_for_280 * (res / base_res)

            fonts_dir = os.path.join(item, "fonts")
            if not os.path.exists(fonts_dir):
                print(f"Skipping {item} - no fonts dir")
                continue
                
            out_fnt_path = os.path.join(fonts_dir, "arrows.fnt")
            out_png_path = os.path.join(fonts_dir, "arrows_0.png")
            
            # Since scale_font modifies files in place, we need to copy originals into place first
            shutil.copy2(nas_fnt_path, out_fnt_path)
            shutil.copy2(nas_png_path, out_png_path)
            
            print(f"Processing {item} (res={res}) with scale factor {scale_factor:.4f}")
            scale_font(out_fnt_path, out_png_path, scale_factor)

if __name__ == "__main__":
    main()

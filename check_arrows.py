from PIL import ImageFont
import os

font_path = "resources/fonts/NotoSansSymbols2-Regular.ttf"
chars = "→↗↘↑↓"

try:
    font = ImageFont.truetype(font_path, 40)
    print(f"Loaded {font_path}")
    for char in chars:
        # getmask checks if the glyph exists (not empty)
        # However, some fonts return a 'not found' box.
        # check getbbox
        bbox = font.getbbox(char)
        print(f"Char '{char}' (U+{ord(char):04X}) bbox: {bbox}")
        
        # also we can check cmap if we had fonttools, but PIL is what we use.
        # If bbox is None, it's definitely empty.
except Exception as e:
    print(f"Error: {e}")

import os
from PIL import Image

path = "/home/edward/git/watch/GarminSugar/resources-round-390x390/icons/weather.png"
if os.path.exists(path):
    img = Image.open(path)
    print(f"Format: {img.format}")
    print(f"Mode: {img.mode}")
    print(f"Info: {img.info}")
    if img.mode in ('RGBA', 'LA') or (img.mode == 'P' and 'transparency' in img.info):
        print("Has Alpha/Transparency")
    else:
        print("No Alpha/Transparency")
else:
    print("File not found")

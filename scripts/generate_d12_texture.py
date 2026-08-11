import os
import math
from PIL import Image, ImageDraw, ImageFont

def create_d12_texture():
    width, height = 2048, 1024
    cell_w, cell_h = 512, 341
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    
    # 12 Faces arranged in 4x3 grid (1..12 matching 3D opposite pentagon face pairs: 1+12=13, 2+11=13, 3+10=13, 4+9=13, 5+8=13, 6+7=13)
    face_nums = ["1", "2", "3", "4", "5", "9", "6", "12", "7", "8", "10", "11"]
    
    try:
        font = ImageFont.truetype("arial.ttf", 130)
    except IOError:
        font = ImageFont.load_default()

    for idx, raw_num in enumerate(face_nums):
        gx = idx % 4
        gy = idx // 4

        face_img = Image.new("RGBA", (cell_w, cell_h), (107, 33, 168, 255))
        draw = ImageDraw.Draw(face_img)

        # Regular pentagon vertices inside cell
        cx, cy = 256, 170
        r_pent = 145
        pent_pts = []
        for i in range(5):
            angle = math.radians(i * 72 - 90)
            px = cx + r_pent * math.cos(angle)
            py = cy + r_pent * math.sin(angle)
            pent_pts.append((px, py))

        # Shadow pentagon
        shadow_pts = [(x + 4, y + 4) for x, y in pent_pts]
        draw.polygon(shadow_pts, fill=(25, 5, 45, 200))

        # Base pentagon face (Royal purple for D12)
        draw.polygon(pent_pts, fill=(107, 33, 168, 255), outline=(58, 15, 95, 255), width=8)

        # Inner border pentagon
        inner_pts = []
        for i in range(5):
            angle = math.radians(i * 72 - 90)
            px = cx + (r_pent - 15) * math.cos(angle)
            py = cy + (r_pent - 15) * math.sin(angle)
            inner_pts.append((px, py))
        draw.polygon(inner_pts, outline=(192, 132, 252, 255), width=4)

        # Distinguish 6 and 9 with a dot or underscore
        display_num = raw_num
        if raw_num in ["6", "9"]:
            display_num = raw_num + "."

        # Draw centered number
        bbox = font.getbbox(display_num)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        tx = cx - tw / 2.0 - bbox[0]
        ty = cy - th / 2.0 - bbox[1]

        # Draw text shadow and main text
        draw.text((tx + 3, ty + 3), display_num, font=font, fill=(20, 5, 35, 230))
        draw.text((tx, ty), display_num, font=font, fill=(255, 255, 245, 255))

        # Paste cell into atlas
        image.alpha_composite(face_img, (gx * cell_w, gy * cell_h))

    os.makedirs("textures", exist_ok=True)
    out_path = os.path.join("textures", "d12_texture.png")
    image.save(out_path, "PNG")
    print(f"D12 Texture regenerated successfully at {out_path}")

if __name__ == "__main__":
    create_d12_texture()

import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageOps

def create_d20_texture():
    width, height = 2048, 1024
    cols, rows = 5, 4
    cell_w = width // cols # 409 px
    cell_h = height // rows # 256 px

    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))

    # 20 Cell Numbers matching 3D face indices 0..19
    # Opposite pairs sum to 21 (1+20, 2+19, 3+18, 4+17, 5+16, 6+15, 7+14, 8+13, 9+12, 10+11)
    face_nums = [
        "1",   # Face 0 (opp Face 6 = 20)
        "2",   # Face 1 (opp Face 5 = 19)
        "3",   # Face 2 (opp Face 14 = 18)
        "4",   # Face 3 (opp Face 13 = 17)
        "5",   # Face 4 (opp Face 15 = 16)
        "19",  # Face 5 (opp Face 1 = 2)
        "20",  # Face 6 (opp Face 0 = 1)
        "6.",  # Face 7 (opp Face 11 = 15)
        "7",   # Face 8 (opp Face 10 = 14)
        "8",   # Face 9 (opp Face 12 = 13)
        "14",  # Face 10 (opp Face 8 = 7)
        "15",  # Face 11 (opp Face 7 = 6)
        "13",  # Face 12 (opp Face 9 = 8)
        "17",  # Face 13 (opp Face 3 = 4)
        "18",  # Face 14 (opp Face 2 = 3)
        "16",  # Face 15 (opp Face 4 = 5)
        "9.",  # Face 16 (opp Face 19 = 12)
        "10",  # Face 17 (opp Face 18 = 11)
        "11",  # Face 18 (opp Face 17 = 10)
        "12"   # Face 19 (opp Face 16 = 9)
    ]

    try:
        font = ImageFont.truetype("arial.ttf", 75)
    except IOError:
        font = ImageFont.load_default()

    for idx, num_str in enumerate(face_nums):
        gx = idx % cols
        gy = idx // cols

        face_img = Image.new("RGBA", (cell_w, cell_h), (30, 40, 140, 255))
        draw = ImageDraw.Draw(face_img)

        # Exact calculated 3D face UV radii: rx = 172.0 px, ry = 107.5 px
        cx, cy = cell_w // 2, cell_h // 2
        rx, ry = 172.0, 107.5
        tri_pts = []
        for i in range(3):
            angle = math.radians(i * 120.0 - 90.0)
            px = cx + rx * math.cos(angle)
            py = cy + ry * math.sin(angle)
            tri_pts.append((px, py))

        # Shadow triangle
        shadow_pts = [(x + 3, y + 3) for x, y in tri_pts]
        draw.polygon(shadow_pts, fill=(5, 10, 40, 200))

        # Base triangle face (Deep Cobalt Indigo for D20)
        draw.polygon(tri_pts, fill=(30, 40, 140, 255), outline=(15, 20, 80, 255), width=6)

        # Inner border line matching exact 3D UV aspect ratio
        rx_in, ry_in = rx - 12.0, ry - 12.0
        inner_pts = []
        for i in range(3):
            angle = math.radians(i * 120.0 - 90.0)
            px = cx + rx_in * math.cos(angle)
            py = cy + ry_in * math.sin(angle)
            inner_pts.append((px, py))
        draw.polygon(inner_pts, outline=(80, 160, 255, 255), width=4)

        # Create dedicated text image layer for cell
        txt_img = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
        txt_draw = ImageDraw.Draw(txt_img)

        # Draw centered face number (Shifted UP towards top apex of triangle)
        bbox = font.getbbox(num_str)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        tx = (cell_w - tw) / 2 - bbox[0]
        ty = (cell_h - th) / 2 - bbox[1] - 18 # shifted higher up in triangle

        txt_draw.text((tx + 3, ty + 3), num_str, font=font, fill=(5, 10, 40, 220))
        txt_draw.text((tx, ty), num_str, font=font, fill=(255, 255, 255, 255))

        # Pre-mirror number text horizontally so it renders un-mirrored on 3D die faces
        txt_img = ImageOps.mirror(txt_img)
        face_img.alpha_composite(txt_img)

        # Paste cell into atlas
        image.alpha_composite(face_img, (gx * cell_w, gy * cell_h))

    os.makedirs("textures", exist_ok=True)
    out_path = os.path.join("textures", "d20_texture.png")
    image.save(out_path, "PNG")
    print(f"D20 Texture generated successfully at {out_path}")

if __name__ == "__main__":
    create_d20_texture()

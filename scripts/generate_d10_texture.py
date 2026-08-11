import os
from PIL import Image, ImageDraw, ImageFont

def create_d10_texture():
    width, height = 2048, 1024
    cell_w, cell_h = 409, 512
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    
    # 10 Faces arranged in 5x2 grid (0..9 matching 3D opposite kite pairs: 0+9=9, 1+8=9, 2+7=9, 3+6=9, 4+5=9)
    face_nums = ["0", "1", "2", "3", "4", "6.", "5", "9.", "8", "7"]
    
    try:
        font = ImageFont.truetype("arial.ttf", 130)
    except IOError:
        font = ImageFont.load_default()

    for idx, num_str in enumerate(face_nums):
        gx = idx % 5
        gy = idx // 5

        face_img = Image.new("RGBA", (cell_w, cell_h), (18, 130, 70, 255))
        draw = ImageDraw.Draw(face_img)

        # Exact calculated 3D kite shape (Widest point at 80.9% height from top)
        pt_top = (204, 10)
        pt_right = (371, 408)
        pt_bot = (204, 502)
        pt_left = (37, 408)
        kite_pts = [pt_top, pt_right, pt_bot, pt_left]

        # Shadow kite
        shadow_pts = [(x + 3, y + 3) for x, y in kite_pts]
        draw.polygon(shadow_pts, fill=(5, 30, 15, 200))

        # Base kite face (Deep emerald green for D10)
        draw.polygon(kite_pts, fill=(18, 130, 70, 255))

        # Inner border line
        inner_top = (204, 50)
        inner_right = (345, 400)
        inner_bot = (204, 475)
        inner_left = (63, 400)
        draw.polygon([inner_top, inner_right, inner_bot, inner_left], outline=(60, 210, 130, 255), width=4)

        # Draw centered face number at optical kite center (Y = 310)
        bbox = font.getbbox(num_str)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        tx = (cell_w - tw) / 2 - bbox[0]
        ty = 310 - (th / 2) - bbox[1]

        draw.text((tx + 3, ty + 3), num_str, font=font, fill=(5, 30, 15, 230))
        draw.text((tx, ty), num_str, font=font, fill=(255, 255, 255, 255))

        # Paste cell into atlas
        image.alpha_composite(face_img, (gx * cell_w, gy * cell_h))

    os.makedirs("textures", exist_ok=True)
    out_path = os.path.join("textures", "d10_texture.png")
    image.save(out_path, "PNG")
    print(f"D10 Texture generated successfully at {out_path}")

if __name__ == "__main__":
    create_d10_texture()

import os
from PIL import Image, ImageDraw, ImageFont, ImageOps

def generate_atlas(face_nums, filename):
    width, height = 2048, 1024
    cell_w, cell_h = 409, 512
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))

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

        # Create dedicated text image layer for cell
        txt_img = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
        txt_draw = ImageDraw.Draw(txt_img)

        # Draw centered face number at optical kite center (Y = 310)
        bbox = font.getbbox(num_str)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        tx = (cell_w - tw) / 2 - bbox[0]
        ty = 310 - (th / 2) - bbox[1]

        txt_draw.text((tx + 3, ty + 3), num_str, font=font, fill=(5, 30, 15, 230))
        txt_draw.text((tx, ty), num_str, font=font, fill=(255, 255, 255, 255))

        if gy == 1:
            # Horizontally mirror the number text for bottom-row kite faces so it renders un-mirrored on 3D die
            txt_img = ImageOps.mirror(txt_img)

        face_img.alpha_composite(txt_img)

        # Paste cell into atlas
        image.alpha_composite(face_img, (gx * cell_w, gy * cell_h))

    os.makedirs("textures", exist_ok=True)
    out_path = os.path.join("textures", filename)
    image.save(out_path, "PNG")
    print(f"D10 Texture generated successfully at {out_path}")

def create_d10_textures():
    # 1. Standard D10 ("Low 0"): 0..9 (opposite pairs sum = 9)
    nums_low = ["0", "1", "2", "3", "4", "6.", "5", "9.", "8", "7"]
    generate_atlas(nums_low, "d10_texture.png")

    # 2. Alternate D10 ("High 10"): 1..10 (opposite pairs sum = 11: 1+10, 2+9, 3+8, 4+7, 5+6)
    nums_high = ["1", "2", "3", "4", "5", "7", "6.", "10", "9.", "8"]
    generate_atlas(nums_high, "d10_high_texture.png")

if __name__ == "__main__":
    create_d10_textures()

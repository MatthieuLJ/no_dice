import os
from PIL import Image, ImageDraw, ImageFont

def create_d8_texture():
    width, height = 2048, 1024
    cell_w, cell_h = 512, 512
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    
    # 8 Faces arranged in 4x2 grid (1..8 matching FACE_SPECS opposite pairing: 1+8=9, 2+7=9, 3+6=9, 4+5=9)
    face_nums = ["1", "2", "3", "4", "5", "6.", "7", "8"]
    
    try:
        font = ImageFont.truetype("arial.ttf", 130)
    except IOError:
        font = ImageFont.load_default()

    for idx, num_str in enumerate(face_nums):
        gx = idx % 4
        gy = idx // 4

        face_img = Image.new("RGBA", (cell_w, cell_h), (40, 165, 245, 255))
        draw = ImageDraw.Draw(face_img)

        # Triangle vertices inside cell
        pt_top = (256, 40)
        pt_left = (40, 460)
        pt_right = (472, 460)
        tri_pts = [pt_top, pt_left, pt_right]

        # Draw dark shadow triangle
        shadow_pts = [(x + 6, y + 6) for x, y in tri_pts]
        draw.polygon(shadow_pts, fill=(5, 15, 40, 200))

        # Draw base triangle face (Bright Electric Sky Blue for D8)
        draw.polygon(tri_pts, fill=(40, 165, 245, 255), outline=(15, 95, 165, 255), width=12)

        # Inner border line
        inner_top = (256, 75)
        inner_left = (70, 440)
        inner_right = (442, 440)
        draw.polygon([inner_top, inner_left, inner_right], outline=(145, 220, 255, 255), width=5)

        # Draw centered face number in triangle centroid (~Y=300)
        bbox = font.getbbox(num_str)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        tx = (cell_w - tw) / 2 - bbox[0]
        ty = 300 - (th / 2) - bbox[1]

        # Shadow & Text
        draw.text((tx + 3, ty + 3), num_str, font=font, fill=(10, 20, 50, 230))
        draw.text((tx, ty), num_str, font=font, fill=(255, 255, 255, 255))

        # Paste cell into atlas
        image.alpha_composite(face_img, (gx * cell_w, gy * cell_h))

    os.makedirs("textures", exist_ok=True)
    out_path = os.path.join("textures", "d8_texture.png")
    image.save(out_path, "PNG")
    print(f"D8 Texture generated successfully at {out_path}")

if __name__ == "__main__":
    create_d8_texture()

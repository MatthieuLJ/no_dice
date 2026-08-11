import os
import math
from PIL import Image, ImageDraw, ImageFont

def create_d4_texture():
    width, height = 2048, 2048
    cell_w, cell_h = 1024, 1024
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    
    # 4 Faces: (Grid X, Grid Y, Top Num, Left Num, Right Num)
    faces = [
        (0, 0, "1", "3", "2"), # Face 0 (Opposite V0)
        (1, 0, "4", "2", "3"), # Face 1 (Opposite V1)
        (0, 1, "4", "3", "1"), # Face 2 (Opposite V2)
        (1, 1, "4", "1", "2"), # Face 3 (Opposite V3)
    ]
    
    try:
        font = ImageFont.truetype("arial.ttf", 150)
    except IOError:
        font = ImageFont.load_default()

    for gx, gy, num_top, num_left, num_right in faces:
        face_img = Image.new("RGBA", (cell_w, cell_h), (210, 65, 30, 255))
        draw = ImageDraw.Draw(face_img)

        # Triangle vertices inside cell
        pt_top = (512, 120)
        pt_left = (120, 880)
        pt_right = (904, 880)
        tri_pts = [pt_top, pt_left, pt_right]

        # Draw dark shadow triangle
        shadow_pts = [(x + 8, y + 8) for x, y in tri_pts]
        draw.polygon(shadow_pts, fill=(40, 10, 5, 200))

        # Draw base triangle face (Warm reddish-amber)
        draw.polygon(tri_pts, fill=(210, 65, 30, 255), outline=(130, 30, 10, 255), width=16)

        # Inner border line
        inner_top = (512, 170)
        inner_left = (160, 850)
        inner_right = (864, 850)
        draw.polygon([inner_top, inner_left, inner_right], outline=(245, 110, 60, 255), width=6)

        # Helper to draw digit with top pointing towards its corner
        def draw_digit(text, center_pos, angle_deg=0):
            txt_img = Image.new("RGBA", (300, 300), (0, 0, 0, 0))
            tdraw = ImageDraw.Draw(txt_img)
            
            # Text bounding box
            bbox = font.getbbox(text)
            tw = bbox[2] - bbox[0]
            th = bbox[3] - bbox[1]
            tx = (300 - tw) / 2 - bbox[0]
            ty = (300 - th) / 2 - bbox[1]
            
            # Shadow
            tdraw.text((tx + 4, ty + 4), text, font=font, fill=(20, 20, 20, 230))
            # Main crisp white text
            tdraw.text((tx, ty), text, font=font, fill=(255, 255, 245, 255))
            
            if angle_deg != 0:
                txt_img = txt_img.rotate(angle_deg, resample=Image.BICUBIC, expand=False)
            
            px = int(center_pos[0] - 150)
            py = int(center_pos[1] - 150)
            face_img.alpha_composite(txt_img, (px, py))

        # Exact calculated symmetric digit centers: each digit is at uniform 200px distance from its vertex apex
        # Top digit (near top apex): top of text points UP (0 deg), center at (512, 320)
        draw_digit(num_top, (512, 320), 0)
        # Left digit (near bottom-left corner): top of text points down-left (+120 deg), center at (288, 772)
        draw_digit(num_left, (288, 772), 120)
        # Right digit (near bottom-right corner): top of text points down-right (-120 deg), center at (736, 772)
        draw_digit(num_right, (736, 772), -120)

        # Paste cell into atlas
        image.alpha_composite(face_img, (gx * cell_w, gy * cell_h))

    os.makedirs("textures", exist_ok=True)
    out_path = os.path.join("textures", "d4_texture.png")
    image.save(out_path, "PNG")
    print(f"D4 Texture regenerated successfully at {out_path}")

if __name__ == "__main__":
    create_d4_texture()

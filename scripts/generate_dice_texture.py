import os
from PIL import Image, ImageDraw

os.makedirs('textures', exist_ok=True)

width, height = 1536, 1024
img = Image.new('RGBA', (width, height), (30, 30, 35, 255))

cell_w, cell_h = 512, 512

def draw_face(col, row, pips):
    x0 = col * cell_w
    y0 = row * cell_h
    
    face_img = Image.new('RGBA', (cell_w, cell_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(face_img)
    
    # Face body (rounded rectangle)
    m = 16
    r = 52
    draw.rounded_rectangle([m, m, cell_w - m, cell_h - m], radius=r, fill=(245, 244, 240, 255), outline=(200, 198, 190, 255), width=4)
    
    # Subtle inner bevel shadow
    draw.rounded_rectangle([m+4, m+4, cell_w - m - 4, cell_h - m - 4], radius=r-4, outline=(220, 218, 210, 255), width=3)
    
    # Pip positions
    cx, cy = cell_w // 2, cell_h // 2
    offset = 120
    
    coords = {
        'C': (cx, cy),
        'TL': (cx - offset, cy - offset),
        'TR': (cx + offset, cy - offset),
        'ML': (cx - offset, cy),
        'MR': (cx + offset, cy),
        'BL': (cx - offset, cy + offset),
        'BR': (cx + offset, cy + offset),
    }
    
    pip_map = {
        1: ['C'],
        2: ['TR', 'BL'],
        3: ['TR', 'C', 'BL'],
        4: ['TL', 'TR', 'BL', 'BR'],
        5: ['TL', 'TR', 'C', 'BL', 'BR'],
        6: ['TL', 'TR', 'ML', 'MR', 'BL', 'BR']
    }
    
    pip_radius = 42 if pips != 1 else 46
    
    for pos_key in pip_map[pips]:
        px, py = coords[pos_key]
        
        fill_color = (25, 25, 30, 255)
        rim_color = (10, 10, 15, 255)
        
        # Draw pip shadow/inset rim
        draw.ellipse([px - pip_radius - 2, py - pip_radius - 2, px + pip_radius + 2, py + pip_radius + 2], fill=rim_color)
        draw.ellipse([px - pip_radius, py - pip_radius, px + pip_radius, py + pip_radius], fill=fill_color)
        
        # Small highlight on pip for 3D depth
        hl_r = pip_radius // 3
        draw.ellipse([px - hl_r + 4, py - hl_r - 4, px + hl_r + 4, py + hl_r - 4], fill=(255, 255, 255, 60))
        
    img.paste(face_img, (x0, y0), face_img)

if __name__ == '__main__':
    for row in range(2):
        for col in range(3):
            pips = row * 3 + col + 1
            draw_face(col, row, pips)

    img.save('textures/dice_texture.png')
    print('Successfully updated textures/dice_texture.png with black pips on all faces')

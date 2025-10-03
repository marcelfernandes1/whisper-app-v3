#!/usr/bin/env python3
"""Create DMG background with prominent arrow"""

from PIL import Image, ImageDraw, ImageFont
import math

# DMG window size
width = 660
height = 400

# Create image with gradient background
img = Image.new('RGB', (width, height))
draw = ImageDraw.Draw(img)

# Create subtle gradient from dark to slightly lighter
for y in range(height):
    r = int(28 + (y / height) * 10)
    g = int(30 + (y / height) * 12)
    b = int(35 + (y / height) * 15)
    draw.line([(0, y), (width, y)], fill=(r, g, b))

# Add subtle accent circles (decorative)
overlay = Image.new('RGBA', (width, height), (0, 0, 0, 0))
overlay_draw = ImageDraw.Draw(overlay)

accent_color = (52, 120, 246, 40)  # Blue with transparency
# Large circle in top right
overlay_draw.ellipse([400, -100, 800, 300], fill=accent_color)
# Smaller circle bottom left
overlay_draw.ellipse([-100, 250, 200, 550], fill=accent_color)

img = img.convert('RGBA')
img = Image.alpha_composite(img, overlay)

# Draw VERY VISIBLE arrow in the middle
# Arrow positioned between where the icons will be
# App icon will be at x=165, Applications at x=495
# Icons are 128px, so app ends at ~229, Applications starts at ~431

arrow_y = 200  # Vertical center
arrow_start_x = 250  # After app icon
arrow_end_x = 410    # Before Applications

# Draw thick, bright arrow
arrow_color = (90, 150, 255)  # Bright blue
arrow_width = 6

# Arrow shaft - thicker and brighter
draw.line(
    [(arrow_start_x, arrow_y), (arrow_end_x - 20, arrow_y)],
    fill=arrow_color,
    width=arrow_width
)

# Arrow head - larger triangle
arrow_size = 20
arrow_head = [
    (arrow_end_x - arrow_size, arrow_y - arrow_size),
    (arrow_end_x, arrow_y),
    (arrow_end_x - arrow_size, arrow_y + arrow_size)
]
draw.polygon(arrow_head, fill=arrow_color)

# Add glow effect to make arrow more visible
for i in range(3):
    offset = (i + 1) * 3
    glow_alpha = int(60 - i * 15)
    glow_img = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_img)

    # Shaft glow
    glow_draw.line(
        [(arrow_start_x, arrow_y), (arrow_end_x - 20, arrow_y)],
        fill=(*arrow_color, glow_alpha),
        width=arrow_width + offset * 2
    )

    # Head glow
    glow_draw.polygon(arrow_head, fill=(*arrow_color, glow_alpha))

    img = Image.alpha_composite(img, glow_img)

# Add text
try:
    font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 18)
    font_small = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 14)
except:
    font = ImageFont.load_default()
    font_small = font

# Instruction above arrow
text = "Drag to install"
bbox = draw.textbbox((0, 0), text, font=font)
text_width = bbox[2] - bbox[0]
text_x = (width - text_width) // 2
draw.text((text_x, arrow_y - 60), text, fill=(200, 200, 210), font=font)

# Version at bottom
subtitle = "WhisperTranscribe v1.0"
bbox = draw.textbbox((0, 0), subtitle, font=font_small)
text_width = bbox[2] - bbox[0]
text_x = (width - text_width) // 2
draw.text((text_x, height - 40), subtitle, fill=(140, 140, 150), font=font_small)

# Save
img = img.convert('RGB')
img.save('dmg_background.png', 'PNG')
print("✅ Created dmg_background.png with VISIBLE arrow")

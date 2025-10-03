#!/usr/bin/env python3
"""Create polished DMG background with left-to-right flow and arrow"""

from PIL import Image, ImageDraw, ImageFont
import math

# DMG window size
width = 660
height = 400

# Create image with gradient background
img = Image.new('RGB', (width, height))
draw = ImageDraw.Draw(img)

# Create a subtle dark gradient
for y in range(height):
    # Smooth gradient
    r = int(26 + (y / height) * 8)
    g = int(28 + (y / height) * 10)
    b = int(32 + (y / height) * 12)
    draw.line([(0, y), (width, y)], fill=(r, g, b))

# Add subtle vignette overlay for depth
overlay = Image.new('RGBA', (width, height), (0, 0, 0, 0))
overlay_draw = ImageDraw.Draw(overlay)

# Radial gradient for vignette
center_x, center_y = width // 2, height // 2
max_dist = math.sqrt(center_x**2 + center_y**2)

for y in range(height):
    for x in range(width):
        dist = math.sqrt((x - center_x)**2 + (y - center_y)**2)
        alpha = int((dist / max_dist) * 40)
        overlay_draw.point((x, y), fill=(0, 0, 0, alpha))

img = img.convert('RGBA')
img = Image.alpha_composite(img, overlay)

# Draw modern arrow in center
arrow_y = 200
arrow_start_x = 260
arrow_end_x = 380

arrow_color = (80, 140, 255)  # Modern blue
arrow_width = 4

# Arrow shaft with gradient effect
for i in range(arrow_width):
    offset = i - arrow_width // 2
    alpha = int(255 - abs(offset) * 50)
    draw.line(
        [(arrow_start_x, arrow_y + offset), (arrow_end_x - 25, arrow_y + offset)],
        fill=(*arrow_color, alpha)
    )

# Arrow head (triangle)
arrow_head = [
    (arrow_end_x - 25, arrow_y - 15),
    (arrow_end_x, arrow_y),
    (arrow_end_x - 25, arrow_y + 15)
]
draw.polygon(arrow_head, fill=arrow_color)

# Add subtle glow around arrow
glow = Image.new('RGBA', (width, height), (0, 0, 0, 0))
glow_draw = ImageDraw.Draw(glow)

for thickness in range(8, 0, -1):
    alpha = int(30 - thickness * 3)
    glow_draw.line(
        [(arrow_start_x, arrow_y), (arrow_end_x - 25, arrow_y)],
        fill=(*arrow_color, alpha),
        width=thickness * 2
    )

img = Image.alpha_composite(img, glow)

# Add instructional text with modern font
try:
    # Use SF Pro if available
    font_title = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 16)
    font_subtitle = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 13)
except:
    font_title = ImageFont.load_default()
    font_subtitle = font_title

# Main instruction above arrow
text = "Drag to Applications to install"
bbox = draw.textbbox((0, 0), text, font=font_title)
text_width = bbox[2] - bbox[0]
text_x = (width - text_width) // 2
draw.text((text_x, arrow_y - 55), text, fill=(180, 190, 200), font=font_title)

# Subtle hint below
hint = "WhisperTranscribe • v1.0"
bbox = draw.textbbox((0, 0), hint, font=font_subtitle)
text_width = bbox[2] - bbox[0]
text_x = (width - text_width) // 2
draw.text((text_x, height - 50), hint, fill=(120, 125, 135), font=font_subtitle)

# Convert back to RGB
img = img.convert('RGB')
img.save('dmg_background.png', 'PNG')
print("✨ Created dmg_background.png with left-to-right flow")

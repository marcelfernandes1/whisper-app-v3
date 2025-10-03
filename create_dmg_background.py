#!/usr/bin/env python3
"""Create a beautiful background for the DMG installer"""

from PIL import Image, ImageDraw, ImageFont
import math

# DMG window size
width = 660
height = 400

# Create image with gradient background
img = Image.new('RGB', (width, height))
draw = ImageDraw.Draw(img)

# Create a subtle gradient from dark to slightly lighter
for y in range(height):
    # Smooth gradient from dark blue-gray to slightly lighter
    r = int(28 + (y / height) * 10)
    g = int(30 + (y / height) * 12)
    b = int(35 + (y / height) * 15)
    draw.line([(0, y), (width, y)], fill=(r, g, b))

# Add subtle accent circle (decorative)
accent_color = (52, 120, 246, 40)  # Blue with transparency
overlay = Image.new('RGBA', (width, height), (0, 0, 0, 0))
overlay_draw = ImageDraw.Draw(overlay)

# Large subtle circle in top right
overlay_draw.ellipse([400, -100, 800, 300], fill=accent_color)

# Smaller circle bottom left
overlay_draw.ellipse([-100, 250, 200, 550], fill=accent_color)

# Blend the overlay
img = img.convert('RGBA')
img = Image.alpha_composite(img, overlay)

# Draw arrow from app to Applications
arrow_y = 200
arrow_start = 390
arrow_end = 270

# Draw a subtle arrow pointing left
arrow_color = (100, 100, 110)
# Arrow shaft
draw.line([(arrow_start, arrow_y), (arrow_end, arrow_y)], fill=arrow_color, width=2)
# Arrow head
draw.polygon([
    (arrow_end - 15, arrow_y - 8),
    (arrow_end, arrow_y),
    (arrow_end - 15, arrow_y + 8)
], fill=arrow_color)

# Add text instruction
try:
    # Try to use a nice font
    font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 18)
    font_small = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 14)
except:
    font = ImageFont.load_default()
    font_small = font

# Main instruction
text = "Drag to install"
# Get text bbox for centering
bbox = draw.textbbox((0, 0), text, font=font)
text_width = bbox[2] - bbox[0]
text_x = (width - text_width) // 2
draw.text((text_x, arrow_y - 40), text, fill=(200, 200, 210), font=font)

# Subtitle
subtitle = "WhisperTranscribe v1.0"
bbox = draw.textbbox((0, 0), subtitle, font=font_small)
text_width = bbox[2] - bbox[0]
text_x = (width - text_width) // 2
draw.text((text_x, height - 40), subtitle, fill=(140, 140, 150), font=font_small)

# Save the background
img = img.convert('RGB')
img.save('dmg_background.png', 'PNG')
print("Created dmg_background.png")

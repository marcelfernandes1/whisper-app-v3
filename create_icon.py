#!/usr/bin/env python3
"""Generate app icon for WhisperTranscribe"""

from PIL import Image, ImageDraw
import math

def create_icon(size):
    """Create a transcription/waveform themed icon"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Color scheme - modern blue gradient
    bg_color = (52, 120, 246)  # Nice blue
    wave_color = (255, 255, 255)  # White

    # Draw circular background with gradient effect
    center = size // 2
    radius = int(size * 0.45)

    # Draw main circle
    draw.ellipse(
        [center - radius, center - radius, center + radius, center + radius],
        fill=bg_color
    )

    # Draw waveform in the center
    wave_height = int(size * 0.5)
    wave_width = int(size * 0.6)
    start_x = (size - wave_width) // 2
    start_y = center

    # Create waveform bars
    num_bars = 7
    bar_width = wave_width // (num_bars * 2)
    spacing = bar_width

    # Heights for bars to create a waveform pattern
    heights = [0.3, 0.6, 0.9, 1.0, 0.9, 0.6, 0.3]

    for i, h in enumerate(heights):
        x = start_x + i * (bar_width + spacing)
        bar_h = int(wave_height * h * 0.5)

        # Draw rounded rectangle bar
        top = start_y - bar_h // 2
        bottom = start_y + bar_h // 2

        draw.rounded_rectangle(
            [x, top, x + bar_width, bottom],
            radius=bar_width // 2,
            fill=wave_color
        )

    return img

# Create iconset directory
import os
import shutil

iconset_path = "AppIcon.iconset"
if os.path.exists(iconset_path):
    shutil.rmtree(iconset_path)
os.makedirs(iconset_path)

# Generate all required sizes
sizes = [
    (16, "16x16"),
    (32, "16x16@2x"),
    (32, "32x32"),
    (64, "32x32@2x"),
    (128, "128x128"),
    (256, "128x128@2x"),
    (256, "256x256"),
    (512, "256x256@2x"),
    (512, "512x512"),
    (1024, "512x512@2x")
]

for size, name in sizes:
    icon = create_icon(size)
    icon.save(f"{iconset_path}/icon_{name}.png")
    print(f"Created icon_{name}.png")

print(f"\nIconset created in {iconset_path}/")
print("Run: iconutil -c icns AppIcon.iconset")

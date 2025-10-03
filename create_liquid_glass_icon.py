#!/usr/bin/env python3
"""Generate Liquid Glass styled app icon for WhisperTranscribe"""

from PIL import Image, ImageDraw, ImageFilter
import math

def create_liquid_glass_icon(size):
    """Create an icon with Apple's Liquid Glass aesthetic"""

    # Create base image with transparency
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    center = size // 2

    # Liquid Glass base - translucent blue with gradient
    # Create a rounded square background (like modern macOS icons)
    corner_radius = int(size * 0.225)  # Apple's standard corner radius ratio

    # Create gradient background layers for depth
    # Layer 1: Darker base
    base_layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    base_draw = ImageDraw.Draw(base_layer)

    # Rounded rectangle for base
    padding = int(size * 0.05)
    base_draw.rounded_rectangle(
        [padding, padding, size - padding, size - padding],
        radius=corner_radius,
        fill=(45, 100, 220, 255)  # Deep blue
    )

    # Layer 2: Glass gradient overlay
    gradient_layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    grad_draw = ImageDraw.Draw(gradient_layer)

    # Create vertical gradient
    for y in range(size):
        alpha = int(100 - (y / size) * 80)  # Fade from top to bottom
        color_val = int(70 + (y / size) * 40)
        grad_draw.line(
            [(padding, y), (size - padding, y)],
            fill=(color_val, color_val + 30, 255, alpha)
        )

    # Mask gradient to rounded rectangle
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(
        [padding, padding, size - padding, size - padding],
        radius=corner_radius,
        fill=255
    )

    # Composite base and gradient
    img = Image.alpha_composite(img, base_layer)
    gradient_layer.putalpha(ImageChops.multiply(gradient_layer.split()[-1], mask))
    img = Image.alpha_composite(img, gradient_layer)

    # Add specular highlight (glass reflection)
    highlight = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    highlight_draw = ImageDraw.Draw(highlight)

    # Top highlight arc
    for i in range(30):
        y = padding + i
        if y < size - padding:
            alpha = int(80 - (i * 2.5))
            highlight_draw.line(
                [(padding + corner_radius // 2, y), (size - padding - corner_radius // 2, y)],
                fill=(255, 255, 255, alpha)
            )

    # Apply highlight with mask
    highlight.putalpha(ImageChops.multiply(highlight.split()[-1], mask))
    img = Image.alpha_composite(img, highlight)

    # Now add the waveform symbol - properly centered
    draw = ImageDraw.Draw(img)

    # Waveform bars - centered and symmetrical
    num_bars = 5
    bar_width = int(size * 0.05)
    total_width = num_bars * bar_width + (num_bars - 1) * bar_width  # bars + gaps
    start_x = (size - total_width) // 2

    # Heights for symmetric waveform (center bar tallest)
    heights_ratio = [0.4, 0.65, 0.85, 0.65, 0.4]
    max_bar_height = int(size * 0.45)

    for i, h_ratio in enumerate(heights_ratio):
        x = start_x + i * (bar_width * 2)
        bar_height = int(max_bar_height * h_ratio)

        top = center - bar_height // 2
        bottom = center + bar_height // 2

        # Draw rounded capsule bars
        draw.rounded_rectangle(
            [x, top, x + bar_width, bottom],
            radius=bar_width // 2,
            fill=(255, 255, 255, 255)
        )

    # Add subtle inner shadow for depth
    img = img.filter(ImageFilter.SMOOTH)

    return img

# Import ImageChops for operations
from PIL import ImageChops

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
    icon = create_liquid_glass_icon(size)
    icon.save(f"{iconset_path}/icon_{name}.png")
    print(f"Created icon_{name}.png")

# Also save a preview
preview = create_liquid_glass_icon(512)
preview.save("icon_preview.png")

print(f"\n✨ Liquid Glass icon created in {iconset_path}/")
print("Preview saved as icon_preview.png")
print("Run: iconutil -c icns AppIcon.iconset")

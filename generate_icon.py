#!/usr/bin/env python3
"""Generate a 1024x1024 Butter Run app icon using Pillow."""

from PIL import Image, ImageDraw

SIZE = 1024
OUT = "/home/user/butter-run/ButterRun/ButterRun/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

# Colors
CREAM = (255, 253, 247)        # #FFFDF7
GOLD = (212, 148, 10)          # #D4940A
GOLD_LIGHT = (235, 195, 80)    # lighter gold for highlights
GOLD_DARK = (170, 115, 5)      # darker gold for shadow
WHITE_SEMI = (255, 255, 255, 180)

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# --- Background: warm cream-to-gold gradient with rounded corners ---
# iOS clips to rounded rect automatically, but fill the full square
for y in range(SIZE):
    t = y / SIZE
    r = int(CREAM[0] + (GOLD_LIGHT[0] - CREAM[0]) * t * 0.3)
    g = int(CREAM[1] + (GOLD_LIGHT[1] - CREAM[1]) * t * 0.3)
    b = int(CREAM[2] + (GOLD_LIGHT[2] - CREAM[2]) * t * 0.3)
    draw.line([(0, y), (SIZE - 1, y)], fill=(r, g, b, 255))

# --- Butter pat: golden rounded rectangle ---
pad = 200
butter_box = [pad, pad + 60, SIZE - pad, SIZE - pad + 60]
corner_r = 80

# Shadow
shadow_offset = 12
shadow_box = [b + shadow_offset for b in butter_box]
draw.rounded_rectangle(shadow_box, radius=corner_r, fill=(0, 0, 0, 40))

# Main butter body
draw.rounded_rectangle(butter_box, radius=corner_r, fill=GOLD)

# Highlight strip on top of butter
highlight_box = [butter_box[0] + 30, butter_box[1] + 20, butter_box[2] - 30, butter_box[1] + 90]
draw.rounded_rectangle(highlight_box, radius=30, fill=GOLD_LIGHT)

# Subtle grid lines on butter (like a real butter pat)
line_color = (190, 130, 5, 100)
for i in range(1, 3):
    # Horizontal lines
    y = butter_box[1] + i * (butter_box[3] - butter_box[1]) // 3
    draw.line([(butter_box[0] + 40, y), (butter_box[2] - 40, y)], fill=line_color, width=3)

# --- Motion/speed lines to the left of the butter ---
# Three horizontal lines suggesting the butter is moving right
line_y_center = (butter_box[1] + butter_box[3]) // 2
for i, offset in enumerate([-100, 0, 100]):
    y = line_y_center + offset
    x_end = butter_box[0] - 30
    length = 100 + (30 if i == 1 else 0)  # middle line longer
    x_start = x_end - length
    # Taper: draw multiple lines getting thinner
    alpha = 200 if i == 1 else 140
    width = 8 if i == 1 else 6
    draw.line([(x_start, y), (x_end, y)], fill=(GOLD[0], GOLD[1], GOLD[2], alpha), width=width)
    # Taper the start by drawing a smaller line
    draw.line([(x_start - 20, y), (x_start, y)], fill=(GOLD[0], GOLD[1], GOLD[2], alpha // 3), width=width - 2)

# --- Simple running legs beneath the butter ---
# Two angled lines representing legs in stride
leg_color = GOLD_DARK
leg_width = 14
# Leg attachment point: bottom center of butter
attach_x = (butter_box[0] + butter_box[2]) // 2
attach_y = butter_box[3]

# Left leg (back, angled left)
foot_l = (attach_x - 90, attach_y + 120)
draw.line([(attach_x - 20, attach_y), foot_l], fill=leg_color, width=leg_width)
# Small foot
draw.line([foot_l, (foot_l[0] - 25, foot_l[1])], fill=leg_color, width=leg_width)

# Right leg (front, angled right and forward)
knee_r = (attach_x + 50, attach_y + 70)
foot_r = (attach_x + 110, attach_y + 30)
draw.line([(attach_x + 20, attach_y), knee_r], fill=leg_color, width=leg_width)
draw.line([knee_r, foot_r], fill=leg_color, width=leg_width)
# Small foot
draw.line([foot_r, (foot_r[0] + 25, foot_r[1])], fill=leg_color, width=leg_width)

# --- Small arm lines from the sides ---
arm_y = butter_box[1] + (butter_box[3] - butter_box[1]) // 3

# Left arm (pumping back)
arm_l_start = (butter_box[0], arm_y + 40)
arm_l_end = (butter_box[0] - 60, arm_y + 100)
draw.line([arm_l_start, arm_l_end], fill=leg_color, width=10)

# Right arm (pumping forward)
arm_r_start = (butter_box[2], arm_y)
arm_r_end = (butter_box[2] + 60, arm_y - 50)
draw.line([arm_r_start, arm_r_end], fill=leg_color, width=10)

# Convert to RGB (no transparency needed for final icon)
final = Image.new("RGB", (SIZE, SIZE), CREAM)
final.paste(img, (0, 0), img)
final.save(OUT, "PNG")
print(f"Icon saved to {OUT}")

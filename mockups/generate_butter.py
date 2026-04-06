#!/usr/bin/env python3
"""Generate butter pat image variations using Gemini 2.0 Flash."""
import json
import base64
import os
import sys
from pathlib import Path

from google import genai
from google.genai import types

# Load API key
settings_path = Path.home() / ".gemini" / "settings.json"
with open(settings_path) as f:
    api_key = json.load(f)["GEMINI_API_KEY"]

client = genai.Client(api_key=api_key)
output_dir = Path(__file__).parent / "images"
output_dir.mkdir(exist_ok=True)

prompts = {
    "classic_flat": (
        "A single rectangular pat of butter on a pure white background. "
        "Golden yellow color with a subtle knife mark across the top. "
        "Clean, minimal, no face or cartoon features. Soft shadow underneath. "
        "Modern flat illustration style suitable for an app icon. High quality rendering."
    ),
    "isometric_3d": (
        "A 3D isometric view of a rectangular pat of butter on a pure white background. "
        "Shows the top face and two side faces clearly. Rich golden yellow with subtle shading "
        "to show dimension. A diagonal knife mark on the top surface. "
        "Clean minimal style, no face, no cartoon features. App icon quality."
    ),
    "foil_wrapped": (
        "A pat of butter partially unwrapped from silver foil wrapper on a pure white background. "
        "The butter is golden yellow, the foil is silver/metallic. One corner of the foil is peeled back "
        "revealing the butter underneath. Clean, appetizing, photorealistic style. "
        "No text, no face, no cartoon features."
    ),
    "melting_pat": (
        "A single pat of butter that is slightly melting on a pure white background. "
        "Golden yellow butter with a small puddle forming at the base. "
        "The edges are soft and slightly droopy. Beautiful warm golden tones. "
        "Clean minimal illustration, no face, no cartoon features. App icon quality."
    ),
    "stamp_style": (
        "A monochrome line art illustration of a rectangular pat of butter in a vintage woodcut or "
        "rubber stamp style. Single color (golden/amber) on pure white background. "
        "Shows a knife mark and cross-hatching for texture. Minimal, iconic, "
        "would work as a small logo or stamp. No face, no text."
    ),
    "running_butter": (
        "A clean minimal illustration of a rectangular pat of butter with small motion lines behind it, "
        "suggesting movement/speed, on a pure white background. Golden yellow butter, "
        "no face or eyes but the motion lines give it energy and personality. "
        "Modern app icon style, clean vector aesthetic. No cartoon features."
    ),
}

MODELS_TO_TRY = ["imagen-4.0-generate-001", "gemini-2.5-flash-image"]

for name, prompt in prompts.items():
    print(f"Generating: {name}...")
    saved = False
    for model_name in MODELS_TO_TRY:
        try:
            if "imagen" in model_name:
                # Imagen uses generate_images
                response = client.models.generate_images(
                    model=model_name,
                    prompt=prompt,
                    config=types.GenerateImagesConfig(
                        number_of_images=1,
                    ),
                )
                if response.generated_images:
                    img = response.generated_images[0]
                    img_data = img.image.image_bytes
                    out_path = output_dir / f"{name}.png"
                    with open(out_path, "wb") as f:
                        f.write(img_data)
                    print(f"  Saved ({model_name}): {out_path} ({len(img_data):,} bytes)")
                    saved = True
                    break
            else:
                # Gemini flash image uses generate_content with IMAGE modality
                response = client.models.generate_content(
                    model=model_name,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        response_modalities=["IMAGE", "TEXT"],
                    ),
                )
                for part in response.candidates[0].content.parts:
                    if part.inline_data is not None:
                        img_data = part.inline_data.data
                        mime = part.inline_data.mime_type
                        ext = "png" if "png" in mime else "jpg" if "jpeg" in mime else "webp"
                        out_path = output_dir / f"{name}.{ext}"
                        if isinstance(img_data, str):
                            img_data = base64.b64decode(img_data)
                        with open(out_path, "wb") as f:
                            f.write(img_data)
                        print(f"  Saved ({model_name}): {out_path} ({len(img_data):,} bytes)")
                        saved = True
                        break
                if saved:
                    break
        except Exception as e:
            print(f"  {model_name}: {e}")
    if not saved:
        print(f"  FAILED to generate: {name}")

print("\nDone! Generated images:")
for f in sorted(output_dir.glob("*.*")):
    if f.suffix in (".png", ".jpg", ".webp"):
        print(f"  {f.name} ({f.stat().st_size:,} bytes)")

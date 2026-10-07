# Website icons and the social preview, made from the app icon (tools/generate-app-icon.py).
import pathlib
from PIL import Image, ImageDraw, ImageFont, ImageFilter
root = pathlib.Path(__file__).resolve().parent
icon = Image.open(root.parent / "app/StudentAthlete/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png").convert("RGBA")
out = root / "src/assets"
def rounded(img, size, radius_ratio=0.2237):
    im = img.resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size * 4 - 1, size * 4 - 1], radius=int(size * 4 * radius_ratio), fill=255)
    im.putalpha(mask.resize((size, size), Image.LANCZOS))
    return im
icon.convert("RGB").resize((180, 180), Image.LANCZOS).save(out / "apple-touch-icon.png", optimize=True)  # iOS rounds it itself
for s in (192, 512):
    rounded(icon, s).save(out / f"icon-{s}.png", optimize=True)
rounded(icon, 32).save(out / "favicon-32.png", optimize=True)
rounded(icon, 256).save(root / "src/favicon.ico", sizes=[(16, 16), (32, 32), (48, 48), (64, 64)])

# Social preview 1200x630
W, H = 1200, 630
og = Image.new("RGB", (W, H), (5, 6, 8))
glow = Image.new("RGB", (W, H), (5, 6, 8))
d = ImageDraw.Draw(glow)
d.ellipse([-260, -380, 560, 300], fill=(46, 22, 92))
d.ellipse([900, 380, 1500, 900], fill=(24, 12, 48))
og = glow.filter(ImageFilter.GaussianBlur(120))
og.paste(rounded(icon, 150), (90, 96), rounded(icon, 150))
bold = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
reg = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
d = ImageDraw.Draw(og)
d.text((90, 300), "Train around your", font=ImageFont.truetype(bold, 78), fill=(255, 255, 255))
d.text((90, 392), "real life.", font=ImageFont.truetype(bold, 78), fill=(167, 139, 250))
d.text((90, 516), "AthleteOS · for student athletes 13–18 · athleteos.lejacob.dev", font=ImageFont.truetype(reg, 26), fill=(170, 170, 176))
d.text((270, 140), "AthleteOS", font=ImageFont.truetype(bold, 54), fill=(255, 255, 255))
d.text((272, 205), "TRAINING · CAMPUS · MINDSET", font=ImageFont.truetype(bold, 20), fill=(139, 92, 246))
og.save(out / "og.png", optimize=True)
print("ok")

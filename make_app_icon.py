import os, subprocess
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import make_icon as mi

OUT = os.path.expanduser('~/hivestrike/icon')
S, M = 1024, 100
W = S - 2 * M

def square_art(size):
    im = mi.back(size, size).convert('RGBA')
    lay = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    u = size / 1024
    for n, x, y, h, rot in [('beetle', .50, .20, 210, 0), ('bee', .24, .30, 170, 14), ('wasp', .76, .30, 180, -14),
                            ('moth', .17, .52, 170, 22), ('dragonfly', .83, .52, 150, -22)]:
        mi.place(lay, mi.sp(n), size * x, size * y, int(h * u), rot)
    mi.place(lay, mi.sp('player'), size * .5, size * .68, int(430 * u))
    im.alpha_composite(lay)
    return im

def squircle(img, radius_frac=0.225):
    w = img.width
    m = Image.new('L', (w * 2, w * 2), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w * 2 - 1, w * 2 - 1], int(w * radius_frac) * 2, fill=255)
    m = m.resize((w, w), Image.LANCZOS)
    out = img.copy().convert('RGBA'); out.putalpha(ImageChops.multiply(out.getchannel('A'), m)); return out

art = square_art(2 * W).resize((W, W), Image.LANCZOS)
# 1) plain full-bleed square (App Store / marketing style, no transparency)
square_art(1024).convert('RGB').save(f'{OUT}/HiveStrike_square_1024.png')
# 2) macOS-style rounded icon with shadow
body = squircle(art)
icon = Image.new('RGBA', (S, S), (0, 0, 0, 0))
sh = Image.new('L', (S, S), 0); sh.paste(body.getchannel('A'), (M, M + 10))
shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0)); shadow.putalpha(sh.filter(ImageFilter.GaussianBlur(14)).point(lambda v: int(v * .5)))
icon.alpha_composite(shadow); icon.alpha_composite(body, (M, M))
icon.save(f'{OUT}/HiveStrike_rounded_1024.png')
# 3) .icns
iset = f'{OUT}/HiveStrike.iconset'; os.makedirs(iset, exist_ok=True)
for b in (16, 32, 128, 256, 512):
    icon.resize((b, b), Image.LANCZOS).save(f'{iset}/icon_{b}x{b}.png')
    icon.resize((b * 2, b * 2), Image.LANCZOS).save(f'{iset}/icon_{b}x{b}@2x.png')
subprocess.check_call(['iconutil', '-c', 'icns', iset, '-o', f'{OUT}/HiveStrike.icns'])
# 4) tvOS layered icon layers + top shelf banner
tv = f'{OUT}/tvOS'; os.makedirs(tv, exist_ok=True)
for layer, fn in (('back', mi.back), ('middle', mi.middle), ('front', mi.front)):
    img = fn(2560, 1536).resize((1280, 768), Image.LANCZOS)
    img.convert('RGB' if layer == 'back' else 'RGBA').save(f'{tv}/layer_{layer}_1280x768.png')
mi.scene(1280, 768).save(f'{tv}/icon_composite_1280x768.png')
mi.scene(1920, 720).save(f'{tv}/top_shelf_1920x720.png')
mi.scene(2320, 720).save(f'{tv}/top_shelf_wide_2320x720.png')
print('done')

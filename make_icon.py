import os, random, math
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageFont

A = os.path.expanduser('~/hivestrike/art')
def sp(n): return Image.open(f'{A}/{n}.png').convert('RGBA')
FONT = '/System/Library/Fonts/Supplemental/Arial Black.ttf'

def grad(W, H, stops):
    im = Image.new('RGB', (W, H)); d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / (H - 1)
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                k = (t - stops[i][0]) / (stops[i + 1][0] - stops[i][0])
                c = tuple(int(stops[i][1][j] + (stops[i + 1][1][j] - stops[i][1][j]) * k) for j in range(3))
                d.line([(0, y), (W, y)], fill=c); break
    return im

def glow(layer, color, radius, strength):
    a = layer.getchannel('A').filter(ImageFilter.GaussianBlur(radius)).point(lambda v: int(min(255, v * strength)))
    g = Image.new('RGBA', layer.size, color + (0,)); g.putalpha(a); return g

def back(W, H):
    im = grad(W, H, [(0, (6, 14, 30)), (0.55, (8, 40, 46)), (1, (22, 70, 52))]).convert('RGBA')
    rnd = random.Random(4)
    ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
    for _ in range(int(W * H / 5200)):
        x, y = rnd.randrange(W), rnd.randrange(H); r = rnd.choice([2, 3, 4, 6]) * H / 480
        col = (255, 230, 140, 200) if rnd.random() < .45 else (170, 255, 230, 170)
        d.ellipse([x - r, y - r, x + r, y + r], fill=col)
    ov = ov.filter(ImageFilter.GaussianBlur(H / 320)); im.alpha_composite(ov)
    for i in range(14):
        a = Image.new('RGBA', (W, H), (0, 0, 0, 0)); ad = ImageDraw.Draw(a)
        x = rnd.choice([rnd.randrange(int(W * .22)), rnd.randrange(int(W * .78), W)]); y = rnd.randrange(H)
        ad.ellipse([x - H * .08, y - H * .32, x + H * .08, y + H * .32], fill=(8, 48, 36, 235))
        im.alpha_composite(a.rotate(rnd.uniform(-35, 35), center=(x, y)))
    vig = Image.new('L', (W, H), 0); ImageDraw.Draw(vig).ellipse([-W * .2, -H * .3, W * 1.2, H * 1.3], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(H / 5)); dark = Image.new('RGBA', (W, H), (0, 0, 0, 150)); dark.putalpha(ImageChops.invert(vig).point(lambda v: v * 150 // 255))
    im.alpha_composite(dark)
    return im.convert('RGB')

def place(canvas, img, cx, cy, h, rot=0):
    s = h / img.height
    im = img.resize((max(1, int(img.width * s)), h), Image.LANCZOS)
    if rot: im = im.rotate(rot, expand=True, resample=Image.BICUBIC)
    pad = int(h * .3)
    big = Image.new('RGBA', (im.width + 2 * pad, im.height + 2 * pad), (0, 0, 0, 0)); big.alpha_composite(im, (pad, pad))
    ox, oy = int(cx - big.width / 2), int(cy - big.height / 2)
    canvas.alpha_composite(glow(big, (255, 190, 60), h * .05, .35), (ox, oy))
    canvas.alpha_composite(im, (ox + pad, oy + pad))

def middle(W, H):
    lay = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    u = H / 768
    spots = [('bee', .50, .38, 120, 0), ('beetle', .30, .30, 150, 8), ('moth', .70, .30, 130, -8),
             ('dragonfly', .16, .46, 110, 15), ('wasp', .84, .46, 120, -15), ('bee', .38, .50, 90, 5), ('bee', .62, .50, 90, -5)]
    for n, x, y, hh, rot in spots: place(lay, sp(n), W * x, H * y, int(hh * u * 1.25), rot)
    return lay

def front(W, H):
    lay = Image.new('RGBA', (W, H), (0, 0, 0, 0)); u = H / 768
    place(lay, sp('player'), W * .5, H * .66, int(300 * u))
    f = ImageFont.truetype(FONT, int(122 * u)); text = 'HIVE STRIKE'
    tw = int(f.getlength(text)); pad = int(40 * u)
    m = Image.new('L', (tw + pad * 2, int(170 * u)), 0); ImageDraw.Draw(m).text((pad, int(14 * u)), text, font=f, fill=255)
    g = grad(m.width, m.height, [(0, (255, 244, 170)), (0.55, (255, 190, 50)), (1, (225, 110, 20))]).convert('RGBA'); g.putalpha(m)
    ol = m.filter(ImageFilter.MaxFilter(int(10 * u) | 1)); dark = Image.new('RGBA', m.size, (40, 12, 4, 255)); dark.putalpha(ol)
    t = Image.new('RGBA', m.size, (0, 0, 0, 0)); t.alpha_composite(glow(dark, (255, 150, 30), 14 * u, 1.2)); t.alpha_composite(dark); t.alpha_composite(g)
    lay.alpha_composite(t, ((W - t.width) // 2, int(H * .06)))
    return lay

def scene(W, H):
    im = back(W, H).convert('RGBA'); im.alpha_composite(middle(W, H)); im.alpha_composite(front(W, H)); return im.convert('RGB')

if __name__ == '__main__':
    base = os.path.expanduser('~/hivestrike/Assets.xcassets/App Icon & Top Shelf Image.brandassets')
    def put(path, img): img.save(path); print('wrote', os.path.relpath(path, base), img.size)
    for stack, sizes in (('App Icon.imagestack', {'': (400, 240), '-1': (800, 480)}), ('App Icon - App Store.imagestack', {'-1': (1280, 768)})):
        for layer, fn in (('Back', back), ('Middle', middle), ('Front', front)):
            for suf, (W, H) in sizes.items():
                img = fn(W * 2, H * 2).resize((W, H), Image.LANCZOS)
                if layer == 'Back': img = img.convert('RGB')
                put(os.path.join(base, stack, layer + '.imagestacklayer', 'Content.imageset', 'retroarch_logo_%s%s.png' % (layer.lower(), suf)), img)
    for d, items in (('Top Shelf Image.imageset', {'retroarch_720.png': (1920, 720), 'retroarch_1440.png': (3840, 1440)}), ('Top Shelf Image Wide.imageset', {'retroarch_720w.png': (2320, 720), 'retroarch_1440w.png': (4640, 1440)})):
        for name, (W, H) in items.items(): put(os.path.join(base, d, name), scene(W, H))
    os.makedirs(os.path.expanduser('~/hivestrike/preview'), exist_ok=True)
    scene(1280, 768).save(os.path.expanduser('~/hivestrike/preview/icon.png'))

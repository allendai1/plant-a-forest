"""Makes the game's small images: the seed shop's petal and sparkle particles (docs/plans/SeedShop.md) and
the guide arrow's chevron (TargetController). All white on transparent, so the game tints them, except
guide_arrow_outlined: white with a black outline (the user's look since 2026-10-07), used untinted."""
import math
from PIL import Image, ImageDraw, ImageFilter

SIZE = 128


def petal(path):
    img = Image.new("RGBA", (SIZE * 4, SIZE * 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # a cherry petal: a teardrop with a small notch at the wide end
    pts = []
    for i in range(200):
        t = 2 * math.pi * i / 200
        x = math.sin(t) * (0.55 + 0.25 * math.cos(t))
        y = -math.cos(t)
        pts.append((SIZE * 2 + x * SIZE * 1.5, SIZE * 2 + y * SIZE * 1.7))
    d.polygon(pts, fill=(255, 255, 255, 255))
    d.polygon([(SIZE * 2 - 26, SIZE * 0.25), (SIZE * 2, SIZE * 0.9), (SIZE * 2 + 26, SIZE * 0.25)], fill=(0, 0, 0, 0))
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    img.save(path)


def sparkle(path):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    c = SIZE / 2
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = abs(x + 0.5 - c) / c, abs(y + 0.5 - c) / c
            star = max(0.0, 1 - (dx * dy) ** 0.5 * 6 - max(dx, dy) * 0.9)  # thin cross arms
            core = max(0.0, 1 - math.hypot(dx, dy) * 3)
            a = min(1.0, star + core)
            px[x, y] = (255, 255, 255, int(255 * a))
    img.filter(ImageFilter.GaussianBlur(0.6)).save(path)


def guide_arrow(path):
    """One chevron pointing up (toward the image's top) in a tall, mostly empty strip. Roblox runs a beam
    texture's height along the beam and its width across it, so the beam repeats this every TextureLength
    along its length, and the empty part is the gap between arrows."""
    w, h, k = 256, 512, 4  # drawn 4x and scaled down for smooth edges
    img = Image.new("RGBA", (w * k, h * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    tip, back, left, right, thick = (w * k // 2, 60 * k), 190 * k, 50 * k, (w - 50) * k, 40 * k
    for width, alpha in ((thick + 36 * k, 70), (thick, 255)):  # a soft glow, then the chevron
        d.line([(left, back), tip, (right, back)], fill=(255, 255, 255, alpha), width=width, joint="curve")
        for x, y in ((left, back), tip, (right, back)):
            r = width // 2
            d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, alpha))
    img = img.resize((w, h), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1))
    img.save(path)


def guide_arrow_outlined(path):
    """The guide chevron in white with a black outline, same layout as guide_arrow."""
    w, h, k = 256, 512, 4
    img = Image.new("RGBA", (w * k, h * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    tip, back, left, right, thick = (w * k // 2, 60 * k), 190 * k, 50 * k, (w - 50) * k, 40 * k
    for width, color in ((thick + 24 * k, (0, 0, 0, 255)), (thick, (255, 255, 255, 255))):  # outline, then fill
        d.line([(left, back), tip, (right, back)], fill=color, width=width, joint="curve")
        for x, y in ((left, back), tip, (right, back)):
            r = width // 2
            d.ellipse((x - r, y - r, x + r, y + r), fill=color)
    img.resize((w, h), Image.LANCZOS).save(path)



GLOW_RING_CENTER = 0.72  # the band's middle, as a fraction of the image's half-width (GlowRingController sizes to it)


def glow_ring(path):
    """The glowing ground ring (GlowRingController, 2026-10-08, like Build the Pyramid's): a soft bright band with a
    wide faint halo, white on transparent so the game tints it. Brighter arcs along it make its slow spin show."""
    n = 512
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = img.load()
    c = n / 2
    for y in range(n):
        for x in range(n):
            dx, dy = (x + 0.5 - c) / c, (y + 0.5 - c) / c
            r = math.hypot(dx, dy)
            d = r - GLOW_RING_CENTER
            core = math.exp(-(d / 0.045) ** 2)
            halo = math.exp(-(d / 0.13) ** 2) * 0.45
            t = math.atan2(dy, dx)
            arcs = 0.55 + 0.3 * (0.5 + 0.5 * math.sin(2 * t)) ** 2 + 0.25 * (0.5 + 0.5 * math.sin(5 * t + 1.3)) ** 3
            a = min(1.0, (core + halo) * min(1.0, arcs))
            px[x, y] = (255, 255, 255, int(255 * a))
    img.save(path)



def glow_wall(path):
    """The glow ring's wall (GlowRingController beams, 2026-10-08, like Build the Pyramid's): white, opaque at the
    wall's foot fading to clear at its top, with soft streaks that tile along the ring (the beams scroll it).
    Saved turned a quarter: a Beam runs an image's height along its length and its width across the ribbon."""
    w, h = 256, 128
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for x in range(w):
        u = 2 * math.pi * x / w
        streak = 0.6 + 0.2 * math.sin(3 * u) + 0.12 * math.sin(7 * u + 1.1) + 0.08 * math.sin(13 * u + 2.3)
        for y in range(h):
            v = y / (h - 1)  # 0 at the top, 1 at the bottom
            fade = v ** 1.4
            base = math.exp(-((1 - v) / 0.1) ** 2) * 0.5  # a brighter line along the ground
            a = min(1.0, fade * streak + base)
            px[x, y] = (255, 255, 255, int(255 * a))
    img.rotate(90, expand=True).save(path)  # the clear top to the left edge, the streaks running top to bottom


def field_wall(path):
    """The Ancient Spring's tall field (2026-10-09, the user's ask: the streaky glow_wall had too many lines at 50 studs
    tall): the same layout as glow_wall, white, opaque at the foot fading smoothly to clear at the top, with no streaks."""
    w, h = 64, 256
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        v = y / (h - 1)  # 0 at the top, 1 at the bottom
        a = min(1.0, 0.85 * v ** 2.2 + math.exp(-((1 - v) / 0.06) ** 2) * 0.6)  # a soft fade up and a bright foot
        for x in range(w):
            px[x, y] = (255, 255, 255, int(255 * a))
    img.rotate(90, expand=True).save(path)  # turned like glow_wall: the clear top to the left edge


def streak(path):
    """A thin soft vertical line for the glow ring's rising wisps (drawn along their velocity)."""
    n = 64
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = img.load()
    for y in range(n):
        for x in range(n):
            dx = (x + 0.5 - n / 2) / (n / 2)
            v = (y + 0.5) / n
            a = math.exp(-(dx / 0.12) ** 2) * math.sin(math.pi * v)
            px[x, y] = (255, 255, 255, int(255 * a))
    img.save(path)



def sun_rays(path):
    """Soft sun rays on transparent, white so the game tints it (the spring's "2X TRAINING" sign, 2026-10-08): 16 rays
    alternating long and short, fading out from the middle."""
    n = 512
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = img.load()
    c = n / 2
    for y in range(n):
        for x in range(n):
            dx, dy = (x + 0.5 - c) / c, (y + 0.5 - c) / c
            r = math.hypot(dx, dy)
            if r > 1:
                continue
            t = math.atan2(dy, dx)
            ray = max(0.0, math.cos(16 * t)) ** 3  # 16 rays...
            long = 0.6 + 0.4 * (0.5 + 0.5 * math.cos(8 * t))  # ...every other one longer
            fade = max(0.0, 1 - r / long) ** 1.1
            glow = max(0.0, 1 - r * 2.2) ** 2 * 0.6  # a soft core
            a = min(1.0, ray * fade + glow)
            px[x, y] = (255, 255, 255, int(255 * a))
    img.filter(ImageFilter.GaussianBlur(1.5)).save(path)



def lightning(path):
    """A jagged lightning bolt with a soft glow, white on transparent so the game tints it (the 100x treadmill's
    lightning streaks, 2026-10-08). Runs top to bottom, so a particle can stretch it along its length."""
    import random
    rng = random.Random(7)
    w, h, k = 128, 512, 2
    img = Image.new("RGBA", (w * k, h * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts, x = [], w * k / 2
    steps = 14
    for i in range(steps + 1):
        y = h * k * i / steps
        pts.append((x, y))
        x = w * k / 2 + rng.uniform(-0.32, 0.32) * w * k
    branch_from = pts[5]
    branch = [branch_from, (branch_from[0] + 0.25 * w * k, branch_from[1] + 0.12 * h * k),
              (branch_from[0] + 0.15 * w * k, branch_from[1] + 0.22 * h * k)]
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.line(pts, fill=(255, 255, 255, 140), width=18 * k, joint="curve")
    gd.line(branch, fill=(255, 255, 255, 110), width=12 * k, joint="curve")
    glow = glow.filter(ImageFilter.GaussianBlur(10 * k))
    d.line(pts, fill=(255, 255, 255, 255), width=4 * k, joint="curve")
    d.line(branch, fill=(255, 255, 255, 230), width=3 * k, joint="curve")
    glow.alpha_composite(img)
    glow.resize((w, h), Image.LANCZOS).save(path)


if __name__ == "__main__":
    petal("assets/textures/petal.png")
    sparkle("assets/textures/sparkle.png")
    guide_arrow("assets/textures/guide_arrow.png")
    guide_arrow_outlined("assets/textures/guide_arrow_outlined.png")
    glow_ring("assets/textures/glow_ring.png")
    glow_wall("assets/textures/glow_wall.png")
    field_wall("assets/textures/field_wall.png")
    streak("assets/textures/streak.png")
    sun_rays("assets/textures/sun_rays.png")
    lightning("assets/textures/lightning.png")

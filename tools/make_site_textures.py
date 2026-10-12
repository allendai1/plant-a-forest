"""Makes the construction camp's ground and hazard images (tools/build_camp.luau, 2026-10-10). Usage:
python tools/make_site_textures.py, then upload each PNG and put its image id in build_camp.luau's TEXTURES.

- hazard: yellow and black diagonal stripes, tiling in both directions
- tread: a tire track's tread blocks, dark on transparent, tiling along the track (the image's height)
- slab: concrete slab seams, a thin dark line round the edge on transparent, so tiling draws a grid of slabs
- road_arrow: a white chevron pointing to the image's top, on transparent, for painting on the road
- belt_edges: yellow safety stripes down both sides, transparent between, for the bridge's moving walkways
  (BridgeController, one tile per slot)
- belt_arrow: one bold white chevron pointing to the image's top, 7:5 like the patch of belt it's drawn on
  (BridgeController BELT_ARROW_WIDTH by BELT_ARROW_SPACING), so it isn't stretched
- treadmill_chevron: a wide, soft, glowing chevron pointing to the image's bottom (so on the treadmill beam it points
  at the console, the way you run), for the gym's treadmills
  (tools/style_treadmills.luau; the user's reference, 2026-10-10)"""
from PIL import Image, ImageDraw, ImageFilter

SIZE = 128


def hazard(path):
    k = 4
    s = SIZE * k
    img = Image.new("RGBA", (s, s), (250, 196, 30, 255))
    d = ImageDraw.Draw(img)
    band = s // 4  # two black and two yellow bands across the tile, so the stripes meet at the tile's edges
    for i in range(-2, 6):
        x = i * 2 * band
        d.polygon([(x, 0), (x + band, 0), (x + band - s, s), (x - s, s)], fill=(30, 30, 34, 255))
    img.resize((SIZE, SIZE), Image.LANCZOS).save(path)


def tread(path):
    w, h = 64, 128
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(0, h, 16):  # chevron-shaped lugs, eight down the tile
        d.polygon([(4, y + 10), (w // 2, y + 2), (w - 4, y + 10), (w - 4, y + 14), (w // 2, y + 6), (4, y + 14)], fill=(45, 35, 28, 150))
    img.save(path)


def slab(path):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, SIZE - 1, SIZE - 1), outline=(60, 60, 60, 110), width=2)
    img.save(path)


def road_arrow(path):
    k = 4
    s = SIZE * k
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(s // 2, 8 * k), (s - 12 * k, 70 * k), (s - 40 * k, 70 * k), (s // 2, 36 * k),
               (40 * k, 70 * k), (12 * k, 70 * k)], fill=(255, 255, 255, 255))
    d.polygon([(s // 2, 58 * k), (s - 12 * k, 120 * k), (s - 40 * k, 120 * k), (s // 2, 86 * k),
               (40 * k, 120 * k), (12 * k, 120 * k)], fill=(255, 255, 255, 255))
    img.resize((SIZE, SIZE), Image.LANCZOS).save(path)


def belt_edges(path):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    band = SIZE // 12
    for x0 in (3, SIZE - 3 - band):
        d.rectangle((x0, 0, x0 + band - 1, SIZE - 1), fill=(250, 196, 30, 255))
    img.save(path)


def belt_arrow(path):
    k = 4
    w, h = 280 * k, 200 * k
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    tip, wing, thick = 30 * k, 130 * k, 52 * k  # the point's height, the wings' height, the stroke's thickness
    left, right, mid = 34 * k, w - 34 * k, w // 2
    d.polygon([(mid, tip), (right, wing), (right, wing + thick), (mid, tip + thick), (left, wing + thick), (left, wing)],
              fill=(255, 255, 255, 255))
    img.resize((280, 200), Image.LANCZOS).save(path)


def treadmill_chevron(path):
    k = 4
    w, h = 256 * k, 256 * k
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    tip, wing = 70 * k, 170 * k
    pts = [(14 * k, wing), (w // 2, tip), (w - 14 * k, wing)]
    ImageDraw.Draw(glow).line(pts, fill=(255, 255, 255, 150), width=70 * k, joint="curve")
    glow = glow.filter(ImageFilter.GaussianBlur(26 * k))
    ImageDraw.Draw(img).line(pts, fill=(255, 255, 255, 235), width=26 * k, joint="curve")
    img = img.filter(ImageFilter.GaussianBlur(5 * k))
    glow.alpha_composite(img)
    glow.resize((256, 256), Image.LANCZOS).transpose(Image.FLIP_TOP_BOTTOM).save(path)


if __name__ == "__main__":
    hazard("assets/textures/hazard.png")
    tread("assets/textures/tread.png")
    slab("assets/textures/slab.png")
    road_arrow("assets/textures/road_arrow.png")
    belt_edges("assets/textures/belt_edges.png")
    belt_arrow("assets/textures/belt_arrow.png")
    treadmill_chevron("assets/textures/treadmill_chevron.png")

"""Phone button icons, after Build the Pyramid's (a white outlined block on a dark round button): ours is a plank.
Usage: python tools/make_ui_icons.py  ->  tools/out/icon_plank.png, icon_drop.png and the upgrade shop icons (icon_bulk_pickup,
icon_bulk_build, icon_build_range, icon_lucky_planks) and the Robux shop icons (icon_server_boost, icon_auto_build), 256 px,
transparent. Upload
with tools/upload_png.py and put the ids in CarryController (PLANK_ICON, DROP_ICON).

The plank is a long flat box drawn in isometric view: its three visible faces faintly filled, every visible edge a
soft white line, and two grain lines along its top. The drop icon is a down arrow onto a line, in the same lines."""
import math
import os

from PIL import Image, ImageDraw

SIZE = 256
SS = 4  # drawn 4x larger, then scaled down: smooth edges
LINE = 6  # edge width at the final size, in pixels
EDGE = (255, 255, 255, 200)
FILL = (255, 255, 255, 34)
LENGTH, WIDTH, HEIGHT = 1.0, 0.3, 0.16  # the plank's proportions (a 2x4-ish board)
TURN = math.radians(0)  # how far the plank is turned from the view's axes


def project(x: float, y: float, z: float) -> tuple[float, float]:
    """Isometric: x and z on the ground (turned by TURN), y up."""
    rx = x * math.cos(TURN) - z * math.sin(TURN)
    rz = x * math.sin(TURN) + z * math.cos(TURN)
    return (rx - rz) * math.cos(math.radians(30)), (rx + rz) * math.sin(math.radians(30)) - y


def drop_icon():
    """A down arrow landing on a short line (Build the Pyramid's drop button), same line weight as the plank."""
    big = SIZE * SS
    image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    width = LINE * SS
    cx = big / 2
    top, tip = big * 0.2, big * 0.66
    head = big * 0.17  # the arrowhead's half width (and height)
    base = big * 0.8  # the line it lands on
    half = big * 0.3
    for line in ([(cx, top), (cx, tip)], [(cx - head, tip - head), (cx, tip), (cx + head, tip - head)], [(cx - half, base), (cx + half, base)]):
        draw.line(line, fill=EDGE, width=width, joint="curve")
        for p in (line[0], line[-1]):
            r = width / 2
            draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=EDGE)
    image.resize((SIZE, SIZE), Image.Resampling.LANCZOS).save("tools/out/icon_drop.png")
    print("tools/out/icon_drop.png")


# The upgrade shop's icons (2026-10-11, the user's ask: they were acorns): cartoon wood planks with dark outlines,
# like the game's other art. Boxes are drawn in isometric view, back to front.
WOOD_TOP = (232, 178, 108)
WOOD_SIDE = (196, 136, 76)
WOOD_END = (160, 104, 56)
WOOD_GRAIN = (176, 118, 64)
OUTLINE = (58, 34, 18)


def wood_box(draw, to_px, cx, cy, cz, lx, ly, lz, outline):
    """A plank: centre (cx, cy bottom, cz), half length lx (along x), height ly, half width lz."""
    def at(x, y, z):
        return to_px(project(cx + x, cy + y, cz + z))
    top = [at(-lx, ly, -lz), at(lx, ly, -lz), at(lx, ly, lz), at(-lx, ly, lz)]
    side = [at(-lx, 0, lz), at(lx, 0, lz), at(lx, ly, lz), at(-lx, ly, lz)]
    end = [at(lx, 0, -lz), at(lx, 0, lz), at(lx, ly, lz), at(lx, ly, -lz)]
    for face, color in ((side, WOOD_SIDE), (end, WOOD_END), (top, WOOD_TOP)):
        draw.polygon(face, fill=color)
    for t in (0.33, 0.67):  # grain along the top
        a = (top[0][0] + (top[3][0] - top[0][0]) * t, top[0][1] + (top[3][1] - top[0][1]) * t)
        b = (top[1][0] + (top[2][0] - top[1][0]) * t, top[1][1] + (top[2][1] - top[1][1]) * t)
        draw.line([(a[0] + (b[0] - a[0]) * 0.1, a[1] + (b[1] - a[1]) * 0.1), (a[0] + (b[0] - a[0]) * 0.85, a[1] + (b[1] - a[1]) * 0.85)],
                  fill=WOOD_GRAIN, width=outline // 2)
    # the end grain: a ring on the visible end
    ec = ((end[0][0] + end[2][0]) / 2, (end[0][1] + end[2][1]) / 2)
    r = outline * 1.1
    draw.ellipse([ec[0] - r, ec[1] - r * 0.8, ec[0] + r, ec[1] + r * 0.8], outline=WOOD_GRAIN, width=outline // 2)
    for face in (side, end, top):
        draw.line(face + [face[0]], fill=OUTLINE, width=outline, joint="curve")


CLOVER = (88, 200, 72)
CLOVER_LIGHT = (150, 235, 120)
SPARKLE = (255, 214, 70)


def clover(draw, centre, size, outline):
    """A four-leaf clover (Lucky Planks): four heart-shaped leaves round a centre, each outlined on its own so they read
    apart, and a short stem, in the icons' dark outlines."""
    cx, cy = centre
    stem = [(cx, cy), (cx + size * 0.2, cy + size * 0.7), (cx + size * 0.5, cy + size * 1.0)]
    draw.line(stem, fill=OUTLINE, width=int(outline * 2.4), joint="curve")
    draw.line(stem, fill=CLOVER, width=int(outline * 1.0), joint="curve")
    for k in (2, 3, 0, 1):  # the top leaves first, so the lower ones overlap them like a real clover seen from above
        a = math.radians(45 + 90 * k)
        ux, uy = math.cos(a), math.sin(a)  # out from the centre
        px, py = -uy, ux  # across the leaf
        reach, lobe = size * 0.62, size * 0.3
        lobes = [(cx + ux * reach + px * lobe * 0.62 * side, cy + uy * reach + py * lobe * 0.62 * side) for side in (-1, 1)]
        tip = (cx + ux * size * 0.08, cy + uy * size * 0.08)
        for fill, grow in ((OUTLINE, outline * 0.9), (CLOVER, 0)):
            r = lobe + grow
            for lx, ly in lobes:
                draw.ellipse([lx - r, ly - r, lx + r, ly + r], fill=fill)
            # The point toward the centre: the two lobes' outer tangents meeting at the tip.
            out_a = (lobes[0][0] - px * r, lobes[0][1] - py * r)
            out_b = (lobes[1][0] + px * r, lobes[1][1] + py * r)
            back = (tip[0] - ux * grow * 1.2, tip[1] - uy * grow * 1.2)
            draw.polygon([out_a, lobes[0], lobes[1], out_b, back], fill=fill)
        notch = ((lobes[0][0] + lobes[1][0]) / 2, (lobes[0][1] + lobes[1][1]) / 2)
        draw.line([tip, notch], fill=CLOVER_LIGHT, width=int(outline * 0.6))
    r = size * 0.1
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=CLOVER_LIGHT, outline=OUTLINE, width=int(outline * 0.6))


def sparkle(draw, centre, size, outline):
    """A four-point gold sparkle with a dark outline."""
    cx, cy = centre
    thin = size * 0.28
    star = [(cx, cy - size), (cx + thin, cy - thin), (cx + size, cy), (cx + thin, cy + thin),
            (cx, cy + size), (cx - thin, cy + thin), (cx - size, cy), (cx - thin, cy - thin)]
    draw.polygon(star, fill=SPARKLE)
    draw.line(star + [star[0]], fill=OUTLINE, width=int(outline * 0.7), joint="curve")


def shop_icon(name, boxes, extras=None):
    """boxes: (cx, cy, cz, lx, ly, lz) in drawing order (back to front). Fitted to the image with a margin."""
    big = SIZE * SS
    pts = []
    for cx, cy, cz, lx, ly, lz in boxes:
        for x in (-lx, lx):
            for y in (0, ly):
                for z in (-lz, lz):
                    pts.append(project(cx + x, cy + y, cz + z))
    for p in (extras or {}).get("points", []):
        pts.append(project(*p))
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    scale = big * 0.94 / max(max(xs) - min(xs), max(ys) - min(ys))
    mx, my = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2

    def to_px(p):
        return ((p[0] - mx) * scale + big / 2, (p[1] - my) * scale + big / 2)

    image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    outline = 9 * SS
    if extras and "ring" in extras:
        cx, cz, rx = extras["ring"]
        ring = [to_px(project(cx + rx * math.cos(a), 0, cz + rx * math.sin(a))) for a in [i * math.pi / 32 for i in range(65)]]
        draw.line(ring, fill=(40, 70, 120), width=outline * 3, joint="curve")
        draw.line(ring, fill=(90, 170, 255), width=int(outline * 1.6), joint="curve")
    for box in boxes:
        wood_box(draw, to_px, *box, outline)
    if extras and "clover" in extras:
        clover(draw, to_px(project(*extras["clover"])), big * 0.2, outline)
        for p, r in extras.get("sparkles", []):
            sparkle(draw, to_px(project(*p)), big * r, outline)
    image.resize((SIZE, SIZE), Image.Resampling.LANCZOS).save(f"tools/out/icon_{name}.png")
    print(f"tools/out/icon_{name}.png")


def _canvas():
    big = SIZE * SS
    image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image), big, 9 * SS


def _save(image, name):
    image.resize((SIZE, SIZE), Image.Resampling.LANCZOS).save(f"tools/out/icon_{name}.png")
    print(f"tools/out/icon_{name}.png")


def _outlined_round_rect(draw, box, radius, fill, outline):
    x0, y0, x1, y1 = box
    draw.rounded_rectangle([x0 - outline, y0 - outline, x1 + outline, y1 + outline], radius + outline, fill=OUTLINE)
    draw.rounded_rectangle(box, radius, fill=fill)


def server_boost_icon():
    """The Robux shop's "BOOST Server Training!" (2026-10-11): a cartoon rocket flying up to the right, the user's pick
    (it was the 🚀 emoji; a barbell and an arrow for a moment). Drawn upright, then tilted."""
    image, draw, big, o = _canvas()
    cx = big / 2
    white, shade, red, red_dark = (245, 245, 250), (200, 205, 215), (230, 65, 55), (170, 35, 30)
    # The flame, under everything: orange round a yellow core.
    for fill, grow in ((OUTLINE, o), ((255, 140, 40), 0)):
        draw.polygon([(cx - big * 0.13 - grow, big * 0.7), (cx + big * 0.13 + grow, big * 0.7), (cx, big * 0.97 + grow * 1.5)], fill=fill)
    draw.polygon([(cx - big * 0.07, big * 0.7), (cx + big * 0.07, big * 0.7), (cx, big * 0.88)], fill=(255, 225, 90))
    # The fins.
    for side in (-1, 1):
        fin = [(cx + side * big * 0.1, big * 0.48), (cx + side * big * 0.27, big * 0.66), (cx + side * big * 0.27, big * 0.76),
               (cx + side * big * 0.1, big * 0.68)]
        draw.polygon(fin, fill=red, outline=OUTLINE, width=int(o))
    # The body: a tall rounded capsule, shaded on its right.
    body = [cx - big * 0.14, big * 0.12, cx + big * 0.14, big * 0.74]
    draw.rounded_rectangle([body[0] - o, body[1] - o, body[2] + o, body[3] + o], big * 0.14 + o, fill=OUTLINE)
    draw.rounded_rectangle(body, big * 0.14, fill=white)
    draw.rounded_rectangle([cx + big * 0.04, big * 0.2, body[2] - big * 0.015, body[3] - big * 0.02], big * 0.08, fill=shade)
    # The red nose cone and a red band at the bottom.
    draw.pieslice([body[0], body[1], body[2], body[1] + big * 0.28], 180, 360, fill=red)
    draw.line([(body[0] + big * 0.02, body[1] + big * 0.14), (body[2] - big * 0.02, body[1] + big * 0.14)], fill=OUTLINE, width=int(o * 0.8))
    draw.rectangle([body[0] + big * 0.01, big * 0.64, body[2] - big * 0.01, big * 0.7], fill=red_dark)
    # The round blue window.
    r = big * 0.075
    wy = big * 0.38
    draw.ellipse([cx - r - o, wy - r - o, cx + r + o, wy + r + o], fill=OUTLINE)
    draw.ellipse([cx - r, wy - r, cx + r, wy + r], fill=(90, 190, 255))
    draw.ellipse([cx - r * 0.55, wy - r * 0.6, cx - r * 0.05, wy - r * 0.1], fill=(200, 240, 255))
    image = image.rotate(-35, resample=Image.Resampling.BICUBIC, center=(big / 2, big / 2))
    _save(image, "server_boost")


def auto_build_icon():
    """The Auto Build pass (2026-10-11): BuilderBot's head (yellow hard hat, black screen, cyan eyes and smile) over a
    plank it's carrying: the robot builds for you."""
    image, draw, big, o = _canvas()
    cx = big / 2
    yellow, yellow_dark = (250, 196, 30), (205, 150, 20)
    # The plank it carries, behind the head's lower edge.
    _outlined_round_rect(draw, [big * 0.06, big * 0.74, big * 0.94, big * 0.9], big * 0.02, WOOD_SIDE, o)
    draw.rectangle([big * 0.06, big * 0.74, big * 0.94, big * 0.79], fill=WOOD_TOP)
    for t in (0.3, 0.62):
        draw.line([(big * (0.1 + t * 0.5), big * 0.765), (big * (0.3 + t * 0.5), big * 0.765)], fill=WOOD_GRAIN, width=int(o * 0.6))
    # The head: a rounded yellow drum with a black screen band.
    head = [cx - big * 0.27, big * 0.3, cx + big * 0.27, big * 0.78]
    _outlined_round_rect(draw, head, big * 0.09, yellow, o)
    draw.rectangle([head[2] - big * 0.08, head[1] + big * 0.04, head[2] - big * 0.03, head[3] - big * 0.06], fill=yellow_dark)
    screen = [cx - big * 0.2, big * 0.42, cx + big * 0.2, big * 0.66]
    _outlined_round_rect(draw, screen, big * 0.04, (18, 18, 22), o * 0.5)
    for ex in (-0.085, 0.085):
        draw.rounded_rectangle([cx + big * (ex - 0.035), big * 0.46, cx + big * (ex + 0.035), big * 0.55], big * 0.015, fill=(80, 235, 255))
    draw.arc([cx - big * 0.07, big * 0.5, cx + big * 0.07, big * 0.62], 20, 160, fill=(80, 235, 255), width=int(o * 0.9))
    # Ear pods.
    for side in (-1, 1):
        ex = cx + side * big * 0.29
        r = big * 0.06
        draw.ellipse([ex - r - o, big * 0.54 - r - o, ex + r + o, big * 0.54 + r + o], fill=OUTLINE)
        draw.ellipse([ex - r, big * 0.54 - r, ex + r, big * 0.54 + r], fill=(60, 58, 56))
    # The hard hat: a dome with a brim, a ridge and the glowing work light.
    hat = [cx - big * 0.27, big * 0.1, cx + big * 0.27, big * 0.5]
    draw.pieslice([hat[0] - o, hat[1] - o, hat[2] + o, hat[3] + o], 180, 360, fill=OUTLINE)
    draw.pieslice(hat, 180, 360, fill=yellow)
    _outlined_round_rect(draw, [cx - big * 0.36, big * 0.29, cx + big * 0.36, big * 0.34], big * 0.02, yellow, o)
    draw.rectangle([cx - big * 0.025, big * 0.11, cx + big * 0.025, big * 0.29], fill=yellow_dark)
    _outlined_round_rect(draw, [cx - big * 0.08, big * 0.16, cx + big * 0.08, big * 0.24], big * 0.015, (255, 235, 170), o * 0.6)
    _save(image, "auto_build")


def shop_icons():
    L, H, W = 0.4, 0.17, 0.15  # a plank's half length, height, half width (chunky: they show at 60 px)
    # Bulk Pickup: a stack, two on the bottom and one on top.
    shop_icon("bulk_pickup", [(0, 0, -W * 1.05, L, H, W), (0, 0, W * 1.05, L, H, W), (0, H, 0, L, H, W)])
    # Bulk Build: a deck, three laid side by side (a built section; the stack is picking up).
    shop_icon("bulk_build", [(0, 0, (i - 1) * W * 2.1, L, H, W) for i in range(3)])
    # Build Range: one plank on a blue ring.
    ring = [(0.5 * math.cos(a), 0, 0.5 * math.sin(a)) for a in [i * math.pi / 16 for i in range(32)]]
    shop_icon("build_range", [(0, 0.02, 0, L, H, W)], {"ring": (0, 0, 0.5), "points": ring})
    # Lucky Planks (2026-10-11): one plank with a four-leaf clover on it and two gold sparkles.
    lucky = {
        "clover": (0.1, H + 0.12, -0.02),
        # Kept close in, so the plank and clover fill the 60-pixel slot like the other icons (sparkles further out shrank them).
        "sparkles": [((-0.3, H + 0.26, 0.02), 0.07), ((0.38, H + 0.3, -0.06), 0.05)],
        "points": [(0.05, H + 0.42, -0.02)],
    }
    shop_icon("lucky_planks", [(0, 0, 0, L, H, W)], lucky)
    server_boost_icon()
    auto_build_icon()


def main():
    l, w, h = LENGTH / 2, WIDTH / 2, HEIGHT
    corners = {
        (sx, sy, sz): project(sx * l, sy * h, sz * w) for sx in (-1, 1) for sy in (0, 1) for sz in (-1, 1)
    }
    xs = [p[0] for p in corners.values()]
    ys = [p[1] for p in corners.values()]
    span = max(max(xs) - min(xs), max(ys) - min(ys))
    scale = SIZE * SS * 0.78 / span
    cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2

    def at(key):
        x, y = corners[key]
        return ((x - cx) * scale + SIZE * SS / 2, (y - cy) * scale + SIZE * SS / 2)

    top = [at((-1, 1, -1)), at((1, 1, -1)), at((1, 1, 1)), at((-1, 1, 1))]
    front = [at((-1, 0, 1)), at((1, 0, 1)), at((1, 1, 1)), at((-1, 1, 1))]  # the long side facing the viewer
    end = [at((1, 0, -1)), at((1, 0, 1)), at((1, 1, 1)), at((1, 1, -1))]  # the short end facing the viewer
    image = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    fill = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(fill)
    for face in (top, front, end):
        draw.polygon(face, fill=FILL)
    image = Image.alpha_composite(image, fill)
    lines = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(lines)
    width = LINE * SS
    for face in (top, front, end):
        draw.line(face + [face[0]], fill=EDGE, width=width, joint="curve")
    # Grain: two thin lines along the top, a third and two thirds across.
    for t in (1 / 3, 2 / 3):
        a = (top[0][0] + (top[3][0] - top[0][0]) * t, top[0][1] + (top[3][1] - top[0][1]) * t)
        b = (top[1][0] + (top[2][0] - top[1][0]) * t, top[1][1] + (top[2][1] - top[1][1]) * t)
        inset = 0.12
        a2 = (a[0] + (b[0] - a[0]) * inset, a[1] + (b[1] - a[1]) * inset)
        b2 = (b[0] + (a[0] - b[0]) * inset, b[1] + (a[1] - b[1]) * inset)
        draw.line([a2, b2], fill=(255, 255, 255, 120), width=width // 2)
    for p in front + end + top:  # round the corners
        r = width / 2
        draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=EDGE)
    image = Image.alpha_composite(image, lines).resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    os.makedirs("tools/out", exist_ok=True)
    image.save("tools/out/icon_plank.png")
    print("tools/out/icon_plank.png")
    drop_icon()
    shop_icons()


if __name__ == "__main__":
    main()

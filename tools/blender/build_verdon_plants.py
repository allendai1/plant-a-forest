"""The Verdon Gorge's plants, low-poly (2026-10-11): Provence's trees and shrubs, built like tools/blender/
build_zion_plants.py (whose helpers it reuses), each split into bark and foliage for Roblox to color
(tools/build_nature.luau, tools/build_town.luau).
- Italian cypress (the town): a tall dark green flame on a short trunk, 24-34 studs.
- Olive (the town): a short gnarled grey trunk, often split, under a wide, silvery grey-green crown, 11-15 studs.
- Aleppo pine (the rims): a leaning, twisting trunk under flat, open clumps of bright green, 24-34 studs.
- Holm oak (the rims and the gorge's ledges): a dense, round, dark green dome, 14-20 studs.
- Lavender (the town's rows and the plateaus): a grey-green mound bristling with purple spikes, 2-3 studs.
- Boxwood (the garrigue): a small dark green mound, 2.5-4 studs.

In Blender:  exec(open(r"<repo>/tools/blender/build_verdon_plants.py").read()); build()
Export:      export(r"<repo>/tools/verdon_out/VerdonPlants.fbx")
"""

import math
import random

import bmesh
from mathutils import Vector

exec(open(r"C:\Users\Allen\Downloads\plant-the-forest-handoff\plant-the-forest-handoff\tools\blender\build_zion_plants.py").read())

COLLECTION = "Verdon_Plants"
PALETTE.update({  # noqa: F821
    "CypressBark": (0.36, 0.26, 0.20),
    "CypressLeaves": (0.10, 0.24, 0.12),
    "OliveBark": (0.45, 0.42, 0.38),
    "OliveLeaves": (0.48, 0.55, 0.40),
    "AleppoBark": (0.48, 0.34, 0.26),
    "AleppoNeedles": (0.30, 0.48, 0.20),
    "OakBark": (0.30, 0.26, 0.22),
    "OakLeaves": (0.16, 0.30, 0.14),
    "LavenderLeaves": (0.50, 0.56, 0.46),
    "LavenderFlowers": (0.52, 0.40, 0.78),
    "BoxLeaves": (0.20, 0.36, 0.16),
})


def cypress(seed, coll, loc):
    rng = random.Random(seed)
    bark, leaves = bmesh.new(), bmesh.new()
    h = rng.uniform(24, 34)
    w = h * rng.uniform(0.11, 0.14)
    frustum(bark, Vector((0, 0, -0.4)), Vector((0, 0, h * 0.2)), w * 0.25, w * 0.18, 6, rng)  # noqa: F821
    # A column of stacked, overlapping lumps, widest a third of the way up, tapering to a point.
    n = 7
    for k in range(n):
        t = k / (n - 1)
        r = w * (0.75 + 0.45 * math.sin(math.pi * min(1, t * 1.4))) * (1 - 0.55 * t)
        at = Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), h * (0.16 + 0.72 * t)))
        blob(leaves, at, r, rng, squash=(1.0, 1.0, 1.6), rough=0.18)  # noqa: F821
    cone(leaves, Vector((0, 0, h * 0.82)), h * 0.2, w * 0.45, 6, rng, wobble=0.1)  # noqa: F821
    return [finish(f"Cypress{seed}_Bark", bark, "CypressBark", coll, loc),  # noqa: F821
            finish(f"Cypress{seed}_Foliage", leaves, "CypressLeaves", coll, loc)]  # noqa: F821


def olive(seed, coll, loc):
    rng = random.Random(seed)
    bark, leaves = bmesh.new(), bmesh.new()
    h = rng.uniform(11, 15)
    r = h * 0.09
    # A thick, twisted trunk that splits low into 2-3 crooked stems.
    fork = Vector((rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8), h * 0.25))
    frustum(bark, Vector((0, 0, -0.4)), fork, r * 1.3, r, 7, rng, wobble=0.3)  # noqa: F821
    ends = []
    for s in range(rng.randint(2, 3)):
        a = rng.uniform(0, 2 * math.pi)
        mid = fork + _out(a, math.radians(rng.uniform(40, 60))) * h * 0.2  # noqa: F821
        tip = mid + _out(a + rng.uniform(-0.6, 0.6), math.radians(rng.uniform(30, 55))) * h * 0.22  # noqa: F821
        frustum(bark, fork, mid, r * 0.8, r * 0.55, 6, rng, wobble=0.15)  # noqa: F821
        frustum(bark, mid, tip, r * 0.55, r * 0.25, 5, rng, wobble=0.1)  # noqa: F821
        ends.append(tip)
    # A wide, airy crown: flat clumps over the stems' ends and between them.
    for tip in ends:
        for _ in range(3):
            at = tip + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.2, 0.6))) * h * 0.14
            blob(leaves, at, h * rng.uniform(0.12, 0.16), rng, squash=(1.3, 1.3, 0.8), rough=0.3)  # noqa: F821
    for i in range(5):  # fill the crown out round the middle
        a = 2 * math.pi * i / 5 + rng.uniform(-0.3, 0.3)
        at = fork + Vector((0, 0, h * 0.48)) + _out(a, rng.uniform(-0.1, 0.4)) * h * 0.22  # noqa: F821
        blob(leaves, at, h * rng.uniform(0.12, 0.15), rng, squash=(1.3, 1.3, 0.8), rough=0.3)  # noqa: F821
    return [finish(f"Olive{seed}_Bark", bark, "OliveBark", coll, loc),  # noqa: F821
            finish(f"Olive{seed}_Foliage", leaves, "OliveLeaves", coll, loc)]  # noqa: F821


def aleppo(seed, coll, loc):
    rng = random.Random(seed)
    bark, needles = bmesh.new(), bmesh.new()
    h = rng.uniform(24, 34)
    r = h * 0.035
    # The trunk leans and kinks twice on its way up.
    pts = [Vector((0, 0, -0.5))]
    lean = rng.uniform(0, 2 * math.pi)
    for k in range(1, 4):
        drift = _out(lean + rng.uniform(-0.7, 0.7), 0) * h * 0.08  # noqa: F821
        pts.append(pts[-1] + drift + Vector((0, 0, h * 0.22)))
    for k in range(3):
        frustum(bark, pts[k], pts[k + 1], r * (1 - 0.2 * k), r * (0.8 - 0.2 * k), 6, rng, wobble=0.06)  # noqa: F821
    top = pts[-1]
    # An open, flat-topped crown: a few branches up and out, each ending in a flat clump.
    for k in range(rng.randint(5, 7)):
        a = 2 * math.pi * k / 6 + rng.uniform(-0.4, 0.4)
        base = pts[2] + (top - pts[2]) * rng.uniform(0.2, 1.0)
        tip = base + _out(a, math.radians(rng.uniform(20, 45))) * h * rng.uniform(0.18, 0.28)  # noqa: F821
        frustum(bark, base, tip, r * 0.4, r * 0.15, 5, rng)  # noqa: F821
        blob(needles, tip + Vector((0, 0, h * 0.04)), h * rng.uniform(0.11, 0.15), rng, squash=(1.4, 1.4, 0.6), rough=0.25)  # noqa: F821
    blob(needles, top + Vector((0, 0, h * 0.05)), h * 0.14, rng, squash=(1.5, 1.5, 0.6), rough=0.22)  # noqa: F821
    return [finish(f"Aleppo{seed}_Bark", bark, "AleppoBark", coll, loc),  # noqa: F821
            finish(f"Aleppo{seed}_Foliage", needles, "AleppoNeedles", coll, loc)]  # noqa: F821


def holm_oak(seed, coll, loc):
    rng = random.Random(seed)
    bark, leaves = bmesh.new(), bmesh.new()
    h = rng.uniform(14, 20)
    r = h * 0.07
    fork = Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), h * 0.28))
    frustum(bark, Vector((0, 0, -0.4)), fork, r, r * 0.75, 7, rng, wobble=0.15)  # noqa: F821
    for k in range(3):
        a = 2 * math.pi * k / 3 + rng.uniform(-0.3, 0.3)
        frustum(bark, fork, fork + _out(a, math.radians(55)) * h * 0.22, r * 0.5, r * 0.2, 5, rng)  # noqa: F821
    # A dense round dome: one big clump and a tight ring of others.
    crown = fork + Vector((0, 0, h * 0.35))
    blob(leaves, crown, h * 0.33, rng, squash=(1.15, 1.15, 0.9), rough=0.18)  # noqa: F821
    for i in range(7):
        a = 2 * math.pi * i / 7 + rng.uniform(-0.3, 0.3)
        blob(leaves, crown + _out(a, rng.uniform(-0.3, 0.6)) * h * 0.27, h * rng.uniform(0.17, 0.22), rng, rough=0.2)  # noqa: F821
    return [finish(f"HolmOak{seed}_Bark", bark, "OakBark", coll, loc),  # noqa: F821
            finish(f"HolmOak{seed}_Foliage", leaves, "OakLeaves", coll, loc)]  # noqa: F821


def lavender(seed, coll, loc):
    rng = random.Random(seed)
    leaves, flowers = bmesh.new(), bmesh.new()
    h = rng.uniform(2.0, 2.8)
    blob(leaves, Vector((0, 0, h * 0.3)), h * 0.6, rng, squash=(1.3, 1.3, 0.75), rough=0.25)  # noqa: F821
    # Purple spikes standing up out of the mound.
    for k in range(rng.randint(14, 20)):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0, h * 0.6)
        base = Vector((math.cos(a) * d, math.sin(a) * d, h * 0.45))
        cone(flowers, base, h * rng.uniform(0.35, 0.55), h * 0.07, 4, rng)  # noqa: F821
    return [finish(f"Lavender{seed}_Foliage", leaves, "LavenderLeaves", coll, loc),  # noqa: F821
            finish(f"Lavender{seed}_Flowers", flowers, "LavenderFlowers", coll, loc)]  # noqa: F821


def boxwood(seed, coll, loc):
    rng = random.Random(seed)
    bush = bmesh.new()
    h = rng.uniform(2.5, 4)
    for _ in range(rng.randint(3, 5)):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0, h * 0.4)
        blob(bush, Vector((math.cos(a) * d, math.sin(a) * d, h * rng.uniform(0.35, 0.5))), h * rng.uniform(0.35, 0.48), rng,  # noqa: F821
             squash=(1.15, 1.15, 0.9), rough=0.22)
    return [finish(f"Boxwood{seed}_Foliage", bush, "BoxLeaves", coll, loc)]  # noqa: F821


SPECIES = {  # name: (builder, seeds)
    "Cypress": (cypress, (1, 2)),
    "Olive": (olive, (1, 2, 3)),
    "Aleppo": (aleppo, (1, 2, 3)),
    "HolmOak": (holm_oak, (1, 2)),
    "Lavender": (lavender, (1, 2)),
    "Boxwood": (boxwood, (1, 2)),
}

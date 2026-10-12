"""Zion's plants, low-poly (2026-10-11, the user's ask: the part-built trees looked ugly; "more accurate and better
looking"). Run inside Blender; uses tools/blender/build_assets.py's helpers so they match the game's other trees.

The species that really grow there, two or three shapes each (seeded), every one split into its bark and its foliage
so Roblox can color each MeshPart (tools/build_nature.luau colors them by name):
- Ponderosa pine (rims): tall straight cinnamon trunk, an open crown of needle tufts on upturned branches, 38-52 studs.
- Pinyon pine (rims): short, round and bushy, dark green, 12-16 studs.
- Utah juniper (rims): a twisted, shaggy grey trunk splitting into gnarled stems, lopsided grey-green clumps, 9-13 studs.
- Fremont cottonwood (the canyon floor): a thick pale trunk forking into spreading limbs under a broad, lumpy
  yellow-green crown, 34-44 studs tall and about as wide.
- Sagebrush (everywhere): a low silvery blue-grey mound, 3-4 studs.
Units are studs, Z up, each model's origin at its base.

In Blender:  exec(open(r"<repo>/tools/blender/build_zion_plants.py").read()); build(r"<repo>")
Export:      export(r"<repo>/tools/zion_out/ZionPlants.fbx")
"""

import math
import random

import bmesh
import bpy
from mathutils import Vector

_repo_helpers = r"C:\Users\Allen\Downloads\plant-the-forest-handoff\plant-the-forest-handoff\tools\blender\build_assets.py"
exec(open(_repo_helpers).read())  # material, frustum, blob, cone, finish, ... (defines functions only)

COLLECTION = "Zion_Plants"
PALETTE.update({  # noqa: F821 (from build_assets.py); preview colors, Roblox colors them itself
    "PonderosaBark": (0.55, 0.30, 0.17),
    "PonderosaNeedles": (0.20, 0.34, 0.15),
    "PinyonBark": (0.36, 0.28, 0.22),
    "PinyonNeedles": (0.17, 0.30, 0.16),
    "JuniperBark": (0.50, 0.44, 0.38),
    "JuniperLeaves": (0.33, 0.42, 0.29),
    "CottonwoodBark": (0.62, 0.58, 0.52),
    "CottonwoodLeaves": (0.42, 0.56, 0.18),
    "Sage": (0.55, 0.62, 0.55),
})


def _out(a, tilt):
    """A unit direction around Z at angle a, tilted `tilt` radians up from flat."""
    return Vector((math.cos(a) * math.cos(tilt), math.sin(a) * math.cos(tilt), math.sin(tilt)))


def ponderosa(seed, coll, loc):
    rng = random.Random(seed)
    bark, needles = bmesh.new(), bmesh.new()
    h = rng.uniform(38, 52)
    r = h * 0.035
    lean = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)) * h * 0.015
    top = Vector((0, 0, h * 0.97)) + lean
    frustum(bark, Vector((0, 0, -0.6)), top, r, r * 0.25, 7, rng, wobble=0.08)  # noqa: F821
    for i in range(4):  # root flare
        a = 2 * math.pi * i / 4 + rng.uniform(-0.3, 0.3)
        o = Vector((math.cos(a), math.sin(a), 0))
        frustum(bark, o * r * 0.3 + Vector((0, 0, r * 1.2)), o * r * 1.8 + Vector((0, 0, -0.4)), r * 0.45, r * 0.15, 5, rng)  # noqa: F821
    # Branches spiral up the top half; each ends in an upturned tuft of needles. Lower branches reach further.
    count = rng.randint(9, 12)
    for k in range(count):
        t = k / (count - 1)
        z = h * (0.42 + 0.48 * t)
        a = k * 2.4 + rng.uniform(-0.3, 0.3)
        reach = h * (0.26 - 0.17 * t) * rng.uniform(0.8, 1.15)
        base = Vector((0, 0, z)) + lean * (z / h)
        tip = base + _out(a, math.radians(rng.uniform(5, 25))) * reach
        frustum(bark, base, tip, r * 0.32 * (1 - 0.5 * t), r * 0.12, 5, rng)  # noqa: F821
        size = h * (0.11 - 0.04 * t) * rng.uniform(0.85, 1.15)
        blob(needles, tip + Vector((0, 0, size * 0.25)), size, rng, squash=(1.15, 1.15, 0.8), rough=0.22)  # noqa: F821
        blob(needles, (base + tip) / 2 + Vector((0, 0, size * 0.3)), size * 0.7, rng, squash=(1.2, 1.2, 0.75), rough=0.22)  # noqa: F821
    blob(needles, top, h * 0.07, rng, squash=(1.0, 1.0, 1.5), rough=0.2)  # noqa: F821
    return [finish(f"Ponderosa{seed}_Bark", bark, "PonderosaBark", coll, loc),  # noqa: F821
            finish(f"Ponderosa{seed}_Foliage", needles, "PonderosaNeedles", coll, loc)]  # noqa: F821


def pinyon(seed, coll, loc):
    rng = random.Random(seed)
    bark, needles = bmesh.new(), bmesh.new()
    h = rng.uniform(12, 16)
    r = 0.7
    stems = rng.randint(2, 3)
    for s in range(stems):
        a = 2 * math.pi * s / stems + rng.uniform(-0.4, 0.4)
        tip = Vector((math.cos(a) * h * 0.18, math.sin(a) * h * 0.18, h * 0.45))
        frustum(bark, Vector((0, 0, -0.3)), tip, r, r * 0.5, 6, rng, wobble=0.06)  # noqa: F821
    # A round, dense crown sitting low: one big clump and a ring of smaller ones.
    crown = Vector((0, 0, h * 0.55))
    blob(needles, crown, h * 0.36, rng, squash=(1.1, 1.1, 0.95), rough=0.2)  # noqa: F821
    for i in range(6):
        a = 2 * math.pi * i / 6 + rng.uniform(-0.3, 0.3)
        blob(needles, crown + _out(a, rng.uniform(-0.3, 0.5)) * h * 0.3, h * rng.uniform(0.18, 0.24), rng, rough=0.22)  # noqa: F821
    return [finish(f"Pinyon{seed}_Bark", bark, "PinyonBark", coll, loc),  # noqa: F821
            finish(f"Pinyon{seed}_Foliage", needles, "PinyonNeedles", coll, loc)]  # noqa: F821


def juniper(seed, coll, loc):
    rng = random.Random(seed)
    bark, leaves = bmesh.new(), bmesh.new()
    h = rng.uniform(9, 13)
    # A short twisted trunk that splits into 2-3 gnarled stems leaning different ways; lopsided clumps on them.
    fork = Vector((rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8), h * 0.28))
    frustum(bark, Vector((0, 0, -0.3)), fork, 1.1, 0.8, 6, rng, wobble=0.15)  # noqa: F821
    for s in range(rng.randint(2, 3)):
        a = rng.uniform(0, 2 * math.pi)
        mid = fork + _out(a, math.radians(rng.uniform(35, 60))) * h * 0.3
        tip = mid + _out(a + rng.uniform(-0.8, 0.8), math.radians(rng.uniform(40, 70))) * h * 0.28
        frustum(bark, fork, mid, 0.75, 0.5, 5, rng, wobble=0.1)  # noqa: F821
        frustum(bark, mid, tip, 0.5, 0.25, 5, rng, wobble=0.08)  # noqa: F821
        for c in range(rng.randint(2, 3)):
            at = tip + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.5, 1))) * h * 0.12
            blob(leaves, at, h * rng.uniform(0.17, 0.25), rng, squash=(1.2, 1.0, 0.8), rough=0.3)  # noqa: F821
        blob(leaves, mid + Vector((0, 0, h * 0.06)), h * rng.uniform(0.14, 0.19), rng, squash=(1.2, 1.1, 0.75), rough=0.3)  # noqa: F821
    return [finish(f"Juniper{seed}_Bark", bark, "JuniperBark", coll, loc),  # noqa: F821
            finish(f"Juniper{seed}_Foliage", leaves, "JuniperLeaves", coll, loc)]  # noqa: F821


def cottonwood(seed, coll, loc):
    rng = random.Random(seed)
    bark, leaves = bmesh.new(), bmesh.new()
    h = rng.uniform(34, 44)
    r = h * 0.055
    fork = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), h * 0.3))
    frustum(bark, Vector((0, 0, -0.6)), fork, r, r * 0.8, 8, rng, wobble=0.15)  # noqa: F821
    for i in range(5):  # buttressed base
        a = 2 * math.pi * i / 5 + rng.uniform(-0.3, 0.3)
        o = Vector((math.cos(a), math.sin(a), 0))
        frustum(bark, o * r * 0.3 + Vector((0, 0, r * 1.3)), o * r * 1.9 + Vector((0, 0, -0.4)), r * 0.5, r * 0.18, 5, rng)  # noqa: F821
    # 3-4 big limbs spread up and out, forking once; the crown is many lumpy clumps over their ends.
    limbs = rng.randint(3, 4)
    ends = []
    for k in range(limbs):
        a = 2 * math.pi * k / limbs + rng.uniform(-0.35, 0.35)
        mid = fork + _out(a, math.radians(rng.uniform(50, 68))) * h * 0.24
        frustum(bark, fork, mid, r * 0.6, r * 0.42, 6, rng, wobble=0.1)  # noqa: F821
        for b in (-0.45, 0.45):
            tip = mid + _out(a + b + rng.uniform(-0.2, 0.2), math.radians(rng.uniform(45, 70))) * h * 0.2
            frustum(bark, mid, tip, r * 0.38, r * 0.15, 5, rng)  # noqa: F821
            ends.append(tip)
    for tip in ends:
        blob(leaves, tip + Vector((0, 0, h * 0.05)), h * rng.uniform(0.15, 0.2), rng, squash=(1.2, 1.2, 0.8), rough=0.25)  # noqa: F821
    crown = fork + Vector((0, 0, h * 0.48))
    blob(leaves, crown, h * 0.25, rng, squash=(1.2, 1.2, 1.0), rough=0.22)  # noqa: F821
    for i in range(7):  # fill the gaps so the crown reads as one tall, lumpy dome
        a = 2 * math.pi * i / 7 + rng.uniform(-0.3, 0.3)
        blob(leaves, crown + _out(a, rng.uniform(-0.2, 0.8)) * h * 0.24, h * rng.uniform(0.13, 0.17), rng,
             squash=(1.1, 1.1, 1.0), rough=0.25)  # noqa: F821
    blob(leaves, crown + Vector((0, 0, h * 0.2)), h * 0.15, rng, rough=0.25)  # noqa: F821
    return [finish(f"Cottonwood{seed}_Bark", bark, "CottonwoodBark", coll, loc),  # noqa: F821
            finish(f"Cottonwood{seed}_Foliage", leaves, "CottonwoodLeaves", coll, loc)]  # noqa: F821


def sagebrush(seed, coll, loc):
    rng = random.Random(seed)
    bush = bmesh.new()
    h = rng.uniform(3, 4)
    for i in range(rng.randint(4, 6)):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0, h * 0.45)
        at = Vector((math.cos(a) * d, math.sin(a) * d, h * rng.uniform(0.3, 0.55)))
        blob(bush, at, h * rng.uniform(0.32, 0.45), rng, squash=(1.2, 1.2, 0.85), rough=0.3)  # noqa: F821
    return [finish(f"Sagebrush{seed}_Foliage", bush, "Sage", coll, loc)]  # noqa: F821


SPECIES = {  # name: (builder, seeds)
    "Ponderosa": (ponderosa, (1, 2, 3)),
    "Pinyon": (pinyon, (1, 2)),
    "Juniper": (juniper, (1, 2, 3)),
    "Cottonwood": (cottonwood, (1, 2, 3)),
    "Sagebrush": (sagebrush, (1, 2)),
}


def build(repo=None):
    coll = fresh_collection()  # noqa: F821 (uses COLLECTION)
    x = 0.0
    made = []
    for name, (make, seeds) in SPECIES.items():
        for seed in seeds:
            objs = make(seed, coll, Vector((x, 0, 0)))
            made += objs
            x += 60.0
    return [o.name for o in made]


def export(path):
    """One FBX, one Model per plant (Ponderosa1, Juniper2, ...), through build_assets.py's exporter."""
    export_fbx(path)  # noqa: F821 (uses COLLECTION)
    return path

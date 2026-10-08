"""Low-poly asset generator for Plant the Forest (run inside Blender).

Builds every tree stage and the hex tile pieces into the "PTF_Assets" collection,
laid out in a grid for previewing, and can export one FBX per asset.
Units are studs (1 Blender unit = 1 stud); Z is up. Every asset is split into a few
pieces by material (bark, leaves, glow, ...) so Roblox can color each MeshPart.

In Blender:  exec(open(r"<repo>/tools/blender/build_assets.py").read()); build_all()
Export:      export_fbx(r"<repo>/assets/fbx/PlantTheForest_Assets.fbx")
"""

import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

COLLECTION = "PTF_Assets"
STAGES = (1, 2, 3, 4, 5, 6, 7, 8)  # seedling ... full grown (docs/plans/TreeStages.md)

# Preview colors only; Roblox sets the real Color on each MeshPart.
PALETTE = {
    "Bark": (0.36, 0.22, 0.13),
    "Leaves": (0.30, 0.62, 0.22),
    "Needles": (0.12, 0.42, 0.22),
    "AncientBark": (0.42, 0.28, 0.18),
    "AncientLeaves": (0.33, 0.70, 0.28),
    "AncientLeavesDark": (0.16, 0.48, 0.20),
    "Glow": (0.25, 1.0, 0.85),
    "Stones": (0.55, 0.56, 0.58),
    "Grass": (0.38, 0.66, 0.24),
    "Flowers": (0.95, 0.55, 0.75),
    "Dirt": (0.45, 0.30, 0.18),
    "Moss": (0.30, 0.52, 0.20),
    "Rim": (1.0, 0.85, 0.40),
    "Vine": (0.18, 0.42, 0.16),
    "Wood": (0.45, 0.30, 0.18),
    "Paver": (0.80, 0.74, 0.64),
    "PaverDark": (0.63, 0.59, 0.53),
    "Lantern": (1.0, 0.78, 0.38),
    "Crystal": (0.35, 0.85, 1.0),
    "CrystalB": (0.75, 0.45, 1.0),
    "Acorn": (0.69, 0.47, 0.24),
    "AcornCap": (0.40, 0.27, 0.15),
    "FlowersB": (0.85, 0.90, 1.0),
    "Bush": (0.25, 0.55, 0.22),
    "Tier": (0.85, 0.85, 0.88),  # recolored per station tier in Roblox
    "Cushion": (0.16, 0.16, 0.18),
    "Metal": (0.63, 0.65, 0.67),
    "Cliff": (0.50, 0.46, 0.42),
    "Rope": (0.78, 0.66, 0.45),
    "Cloud": (0.97, 0.98, 1.0),
    "Water": (0.35, 0.70, 0.95),
    "GiftBox": (0.85, 0.20, 0.30),
    "Ribbon": (1.0, 0.80, 0.25),
    "Paper": (0.95, 0.92, 0.82),
    "MushroomCap": (0.85, 0.18, 0.15),
    "MushroomStem": (0.95, 0.92, 0.85),
    "Deer": (0.62, 0.42, 0.25),
    "Antler": (0.90, 0.85, 0.72),
    "Fox": (0.90, 0.45, 0.15),
    "FoxWhite": (0.96, 0.94, 0.90),
    "Bunny": (0.80, 0.78, 0.76),
    "Bird": (0.30, 0.45, 0.75),
    "Beak": (1.0, 0.65, 0.15),
    "SakuraBark": (0.30, 0.17, 0.15),
    "Blossom": (1.0, 0.34, 0.62),
    "BlossomDeep": (0.78, 0.16, 0.45),
    "CrystalBark": (0.20, 0.18, 0.28),
    "CrystalViolet": (0.42, 0.12, 0.85),
    "Redwood": (0.50, 0.07, 0.03),
    "RedwoodNeedles": (0.04, 0.20, 0.09),
    "RedwoodNeedlesB": (0.09, 0.30, 0.12),
    "PalmBark": (0.50, 0.36, 0.22),
    "PalmFronds": (0.12, 0.45, 0.12),
    "PalmFrondsB": (0.28, 0.60, 0.16),
    "Coconut": (0.24, 0.13, 0.06),
    "BambooStalk": (0.42, 0.62, 0.16),
    "BambooNode": (0.26, 0.40, 0.10),
    "BambooLeaves": (0.20, 0.52, 0.14),
    "MapleBark": (0.33, 0.27, 0.24),
    "MapleOrange": (0.95, 0.45, 0.10),
    "MapleRed": (0.80, 0.14, 0.08),
    "MapleGold": (0.98, 0.72, 0.15),
    "BirchBark": (0.92, 0.90, 0.86),
    "BirchMark": (0.12, 0.11, 0.10),
    "BirchGold": (0.98, 0.80, 0.20),
    "BirchGoldB": (0.90, 0.62, 0.12),
    "RangerHat": (0.72, 0.56, 0.32),
    "RangerBand": (0.30, 0.19, 0.11),
    "Gold": (1.0, 0.78, 0.25),
    "RangerPack": (0.50, 0.33, 0.18),
    "Bedroll": (0.62, 0.22, 0.15),
    "LordLeaves": (0.18, 0.52, 0.18),
    "LordLeavesB": (0.45, 0.76, 0.24),
    "Cape": (0.10, 0.28, 0.13),
    "Gem": (0.30, 1.0, 0.60),
}
EMISSIVE = ("Glow", "Rim", "Lantern", "Crystal", "CrystalB", "CrystalViolet", "Gem")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def material(name):
    mat = bpy.data.materials.get("PTF_" + name) or bpy.data.materials.new("PTF_" + name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    rgb = PALETTE[name]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
    if name in EMISSIVE:
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 3.0
    mat.diffuse_color = (*rgb, 1.0)
    return mat


def jitter(verts, rng, amount):
    for v in verts:
        v.co += Vector((rng.uniform(-amount, amount), rng.uniform(-amount, amount), rng.uniform(-amount, amount)))


def frustum(bm, a, b, r0, r1, segments, rng, wobble=0.0):
    """Tapered cylinder from point a to point b."""
    axis = b - a
    depth = axis.length
    rot = axis.to_track_quat("Z", "Y").to_matrix().to_4x4()
    m = Matrix.Translation((a + b) / 2) @ rot
    res = bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=r0, radius2=r1, depth=depth, matrix=m)
    if wobble:
        jitter(res["verts"], rng, wobble)
    return res["verts"]


def box(bm, center, size, rot_z=0.0):
    """Axis-aligned box (turned by rot_z around Z)."""
    m = Matrix.Translation(center) @ Matrix.Rotation(rot_z, 4, "Z") @ Matrix.Diagonal((*size, 1.0))
    return bmesh.ops.create_cube(bm, size=1.0, matrix=m)["verts"]


def prism(bm, corners, z0, z1):
    """A flat slab with the given 2D outline, from z0 to z1."""
    lo = [bm.verts.new((x, y, z0)) for x, y in corners]
    hi = [bm.verts.new((x, y, z1)) for x, y in corners]
    bm.faces.new(hi)
    bm.faces.new(list(reversed(lo)))
    for i in range(len(corners)):
        j = (i + 1) % len(corners)
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))


def blob(bm, center, radius, rng, squash=(1.0, 1.0, 1.0), subdiv=1, rough=0.18):
    """Faceted low-poly clump (icosphere with jittered vertices)."""
    m = Matrix.Translation(center) @ Matrix.Diagonal((*squash, 1.0))
    res = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius, matrix=m)
    jitter(res["verts"], rng, radius * rough)
    return res["verts"]


def cone(bm, base, height, radius, segments, rng, wobble=0.0, tip=0.0):
    m = Matrix.Translation(base + Vector((0, 0, height / 2)))
    res = bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=tip, depth=height, matrix=m)
    if wobble:
        jitter(res["verts"], rng, wobble)
    return res["verts"]


def annulus(bm, center, r_out, r_in, height, segments, start_angle=0.0):
    """Flat ring prism (used for the rune circle and the hex rim)."""
    verts = []
    for ring_r in (r_out, r_in):
        for z in (0.0, height):
            row = []
            for i in range(segments):
                a = start_angle + 2 * math.pi * i / segments
                row.append(bm.verts.new(center + Vector((ring_r * math.cos(a), ring_r * math.sin(a), z))))
            verts.append(row)
    ob, ot, ib, it = verts
    for i in range(segments):
        j = (i + 1) % segments
        bm.faces.new((ot[i], ot[j], it[j], it[i]))  # top
        bm.faces.new((ob[j], ob[i], ib[i], ib[j]))  # bottom
        bm.faces.new((ob[i], ob[j], ot[j], ot[i]))  # outer wall
        bm.faces.new((ib[j], ib[i], it[i], it[j]))  # inner wall


def finish(name, bm, mat_name, coll, location, scale=1.0):
    mesh = bpy.data.meshes.new(name)
    if scale != 1.0:
        bmesh.ops.scale(bm, vec=(scale, scale, scale), verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = False
    mesh.materials.append(material(mat_name))
    obj = bpy.data.objects.new(name, mesh)
    obj.location = location
    coll.objects.link(obj)
    return obj


def box_uv(obj, tile=6.0):
    """Box-projected UVs (each face mapped from its main axis, one unit per `tile` studs), so Roblox materials
    like Wood or Slate tile across the mesh instead of stretching flat (2026-10-08: the fence was one big mesh with
    no UVs, so its material showed as a plain color)."""
    mesh = obj.data
    uv = mesh.uv_layers.new(name="UVMap") if not mesh.uv_layers else mesh.uv_layers[0]
    for poly in mesh.polygons:
        n = poly.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        u_i, v_i = [(1, 2), (0, 2), (0, 1)][ax]
        for li in poly.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            uv.data[li].uv = (co[u_i] / tile, co[v_i] / tile)
    return obj


def fresh_collection():
    coll = bpy.data.collections.get(COLLECTION)
    if coll:
        for obj in list(coll.objects):
            mesh = obj.data
            bpy.data.objects.remove(obj)
            if mesh and mesh.users == 0:
                bpy.data.meshes.remove(mesh)
    else:
        coll = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(coll)
    return coll


# ---------------------------------------------------------------------------
# Forest trees (2 species x 4 stages)
# ---------------------------------------------------------------------------
LEAFY_HEIGHT = 75.0
PINE_HEIGHT = 70.0
# Forest trees are modeled at the sizes above, then shrunk so one tree fits about one tile
# (full grown: leafy ~42 tall x 40 wide, pine ~45 x 24 studs).
FOREST_TREE_SCALE = 0.6


# Each tree stage's size as a fraction of full grown (stages 3-8; 1 and 2 are hand-sized sprouts).
# Stage 8 is the full-grown tree and builds exactly like the old stage 4 did (docs/plans/TreeStages.md).
STAGE_SIZE = {3: 0.18, 4: 0.28, 5: 0.42, 6: 0.58, 7: 0.78, 8: 1.0}
LEAFY_CLUMPS = {3: 0, 4: 3, 5: 4, 6: 5, 7: 7, 8: 7}
PINE_TIERS = {3: 2, 4: 3, 5: 3, 6: 4, 7: 5, 8: 5}
# Early stages scaled up (same shapes) so even the first seed stands clear of a planted tile's grass
# tufts (~1.9 studs): about 4.5, 7, 10, 14 and 19 studs tall in the game for stages 1-5.
STAGE_BOOST = {"Leafy": {1: 2.4, 2: 1.85, 3: 1.4, 4: 1.27, 5: 1.1},
               "Pine": {1: 2.7, 2: 1.75, 3: 1.85, 4: 1.45, 5: 1.28}}


def leafy(stage, seed, coll, loc):
    rng = random.Random(seed)
    bark, leaves = bmesh.new(), bmesh.new()
    if stage <= 2:  # 1 seedling: a tiny stem with 2 leaves; 2 sprout: a taller stem with 4
        stem = (2.2, 5.0)[stage - 1]
        frustum(bark, Vector((0, 0, 0)), Vector((0, 0, stem)), 0.25 + 0.1 * stage, 0.18 + 0.07 * stage, 6, rng)
        count = 2 * stage
        for i in range(count):
            a = 2 * math.pi * i / count + rng.uniform(-0.3, 0.3)
            r = 0.55 * stage
            blob(leaves, Vector((math.cos(a) * r, math.sin(a) * r, stem + 0.2)), 0.6 + 0.45 * stage, rng,
                 squash=(1.4, 1.0, 0.6), subdiv=1)
    else:
        g = STAGE_SIZE[stage]
        h = LEAFY_HEIGHT * g
        trunk_r = 3.8 * g + 0.4
        top = Vector((rng.uniform(-1, 1) * g, rng.uniform(-1, 1) * g, h * 0.42))
        frustum(bark, Vector((0, 0, -0.5)), top, trunk_r, trunk_r * 0.6, 7, rng, wobble=0.15 * g)
        # root flare
        if stage >= 5:
            for i in range(5):
                a = 2 * math.pi * i / 5 + rng.uniform(-0.3, 0.3)
                out = Vector((math.cos(a), math.sin(a), 0))
                frustum(bark, out * trunk_r * 0.3 + Vector((0, 0, trunk_r * 0.9)), out * trunk_r * 1.9 + Vector((0, 0, -0.3)),
                        trunk_r * 0.45, trunk_r * 0.15, 5, rng)
        # branches into the canopy
        if stage >= 5:
            for i in range(3):
                a = 2 * math.pi * i / 3 + rng.uniform(-0.4, 0.4)
                frustum(bark, top - Vector((0, 0, h * 0.08)),
                        top + Vector((math.cos(a) * h * 0.16, math.sin(a) * h * 0.16, h * 0.14)),
                        trunk_r * 0.45, trunk_r * 0.2, 5, rng)
        # canopy: a big center clump plus a ring of smaller ones
        crown = top + Vector((0, 0, h * 0.2))
        big = h * 0.3
        blob(leaves, crown, big, rng, squash=(1.1, 1.1, 0.85))
        clumps = LEAFY_CLUMPS[stage]
        for i in range(clumps):
            a = 2 * math.pi * i / clumps + rng.uniform(-0.3, 0.3)
            d = big * rng.uniform(0.8, 1.0)
            z = rng.uniform(-0.35, 0.2) * big
            blob(leaves, crown + Vector((math.cos(a) * d, math.sin(a) * d, z)), big * rng.uniform(0.55, 0.72), rng,
                 squash=(1.0, 1.0, 0.85))
        if stage == 8:  # a few clumps on top so the crown reads round, not flat
            for i in range(3):
                a = 2 * math.pi * i / 3 + 0.5
                blob(leaves, crown + Vector((math.cos(a) * big * 0.4, math.sin(a) * big * 0.4, big * 0.55)),
                     big * 0.5, rng, squash=(1.0, 1.0, 0.85))
    s = FOREST_TREE_SCALE * STAGE_BOOST["Leafy"].get(stage, 1.0)
    return [finish(f"Leafy{stage}_Bark", bark, "Bark", coll, loc, s), finish(f"Leafy{stage}_Leaves", leaves, "Leaves", coll, loc, s)]


def pine(stage, seed, coll, loc):
    rng = random.Random(seed)
    bark, needles = bmesh.new(), bmesh.new()
    if stage <= 2:  # 1 seedling: a tiny green tuft; 2 sprout: a stem with a small cone
        stem = (0.8, 2.8)[stage - 1]
        frustum(bark, Vector((0, 0, 0)), Vector((0, 0, stem)), 0.22 + 0.08 * stage, 0.16 + 0.06 * stage, 6, rng)
        cone(needles, Vector((0, 0, stem * 0.6)), (2.0, 4.4)[stage - 1], (0.9, 1.8)[stage - 1], 6, rng, wobble=0.12)
    else:
        g = STAGE_SIZE[stage]
        h = PINE_HEIGHT * g
        trunk_r = 2.4 * g + 0.3
        frustum(bark, Vector((0, 0, -0.5)), Vector((0, 0, h * 0.35)), trunk_r, trunk_r * 0.75, 7, rng, wobble=0.1 * g)
        if stage >= 5:  # root flare
            for i in range(4):
                a = 2 * math.pi * i / 4 + rng.uniform(-0.3, 0.3)
                out = Vector((math.cos(a), math.sin(a), 0))
                frustum(bark, out * trunk_r * 0.3 + Vector((0, 0, trunk_r * 0.8)), out * trunk_r * 1.7 + Vector((0, 0, -0.3)),
                        trunk_r * 0.4, trunk_r * 0.12, 5, rng)
        tiers = PINE_TIERS[stage]
        base_r = h * 0.3
        z = h * 0.18
        for t in range(tiers):
            k = 1 - t / (tiers + 0.6)
            tier_h = h * 0.32 * (0.8 + 0.2 * k)
            cone(needles, Vector((rng.uniform(-0.4, 0.4) * g, rng.uniform(-0.4, 0.4) * g, z)), tier_h, base_r * k, 7, rng,
                 wobble=base_r * 0.05)
            z += tier_h * 0.5
    s = FOREST_TREE_SCALE * STAGE_BOOST["Pine"].get(stage, 1.0)
    return [finish(f"Pine{stage}_Bark", bark, "Bark", coll, loc, s), finish(f"Pine{stage}_Needles", needles, "Needles", coll, loc, s)]


SAKURA_HEIGHT = 74.0
SAKURA_LIMBS = {3: 2, 4: 3, 5: 3, 6: 4, 7: 5, 8: 5}


def sakura(stage, seed, coll, loc):
    """Cherry blossom: a short gnarled trunk forking into limbs that spread out, each topped by a
    flat pink cloud of blossom (two pinks). Early stages are a green sprout with pink buds."""
    rng = random.Random(seed)
    bark, pink, deep = bmesh.new(), bmesh.new(), bmesh.new()
    parts = [(bark, "SakuraBark", "Bark"), (pink, "Blossom", "Blossom"), (deep, "BlossomDeep", "BlossomDeep")]
    if stage <= 2:  # 1: a stem with a bud; 2: a taller stem with 3 little blossoms
        stem = (2.4, 5.0)[stage - 1]
        frustum(bark, Vector((0, 0, 0)), Vector((0.2, 0, stem)), 0.3 + 0.1 * stage, 0.18 + 0.06 * stage, 6, rng)
        for i in range(2 * stage):
            a = 2 * math.pi * i / (2 * stage) + 0.4
            blob(deep, Vector((math.cos(a) * 0.5 * stage, math.sin(a) * 0.5 * stage, stem * 0.7)), 0.5 + 0.25 * stage,
                 rng, squash=(1.3, 1.0, 0.45), subdiv=1)
        for i in range(stage * 2 - 1):
            a = 2 * math.pi * i / (stage * 2 - 1)
            off = Vector((math.cos(a), math.sin(a), 0.3)) * (0.9 * (stage - 1))
            blob(pink, Vector((0.2, 0, stem + 0.4)) + off, 0.75 + 0.35 * stage, rng, squash=(1.1, 1.1, 0.8), subdiv=1)
    else:
        g = STAGE_SIZE[stage]
        h = SAKURA_HEIGHT * g
        trunk_r = 3.6 * g + 0.4
        lean = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)).normalized() * h * 0.06
        fork = Vector((0, 0, h * 0.32)) + lean
        frustum(bark, Vector((0, 0, -0.5)), fork, trunk_r, trunk_r * 0.7, 7, rng, wobble=0.2 * g)
        if stage >= 5:  # root flare
            for i in range(5):
                a = 2 * math.pi * i / 5 + rng.uniform(-0.3, 0.3)
                out = Vector((math.cos(a), math.sin(a), 0))
                frustum(bark, out * trunk_r * 0.3 + Vector((0, 0, trunk_r * 0.9)), out * trunk_r * 1.8 + Vector((0, 0, -0.3)),
                        trunk_r * 0.45, trunk_r * 0.15, 5, rng)
        limbs = SAKURA_LIMBS[stage]
        tips = []
        for i in range(limbs):
            a = 2 * math.pi * i / limbs + rng.uniform(-0.35, 0.35)
            out = Vector((math.cos(a), math.sin(a), 0))
            elbow = fork + out * h * 0.2 + Vector((0, 0, h * rng.uniform(0.14, 0.2)))
            tip = elbow + out * h * 0.2 + Vector((0, 0, h * rng.uniform(0.08, 0.16)))
            frustum(bark, fork, elbow, trunk_r * 0.55, trunk_r * 0.35, 5, rng)
            frustum(bark, elbow, tip, trunk_r * 0.35, trunk_r * 0.15, 5, rng)
            tips.append(tip)
            if stage >= 6:  # a side twig with its own little cloud
                side = Vector((math.cos(a + 0.9), math.sin(a + 0.9), 0))
                twig = elbow + side * h * 0.16 + Vector((0, 0, h * 0.04))
                frustum(bark, elbow, twig, trunk_r * 0.2, trunk_r * 0.08, 4, rng)
                tips.append(twig)
        # blossom clouds: wide and flat, so the crown reads as a pink umbrella
        cloud = h * 0.2
        for j, tip in enumerate(tips):
            r = cloud * (1.0 if j % 2 == 0 or stage < 6 else 0.7) * rng.uniform(0.9, 1.1)
            blob(pink if j % 3 else deep, tip + Vector((0, 0, r * 0.25)), r, rng, squash=(1.25, 1.25, 0.6))
        blob(pink, fork + Vector((0, 0, h * 0.5)), cloud * 1.15, rng, squash=(1.3, 1.3, 0.6))
        if stage >= 7:  # drooping clusters under the canopy edge
            for tip in tips[::2]:
                blob(deep, tip + Vector((0, 0, -cloud * 0.45)), cloud * 0.45, rng, squash=(1.0, 1.0, 1.3))
    s = FOREST_TREE_SCALE * STAGE_BOOST["Leafy"].get(stage, 1.0)
    return [finish(f"Sakura{stage}_{piece}", bm, mat, coll, loc, s) for bm, mat, piece in parts if bm.verts]


CRYSTAL_HEIGHT = 74.0
CRYSTAL_LIMBS = {3: 2, 4: 3, 5: 3, 6: 4, 7: 5, 8: 5}


def shard(bm, base, direction, length, radius, rng):
    """One crystal: a six-sided prism with a pointed tip (18 triangles). The bottom is left open since
    it's always buried in a limb, a cluster or the ground."""
    d = direction.normalized()
    side = d.orthogonal().normalized()
    other = d.cross(side)
    mid = base + d * length * 0.7
    low, high = [], []
    for i in range(6):
        a = 2 * math.pi * i / 6
        off = side * math.cos(a) + other * math.sin(a)
        low.append(bm.verts.new(base + off * radius * 0.8))
        high.append(bm.verts.new(mid + off * radius))
    tip = bm.verts.new(base + d * length)
    for i in range(6):
        j = (i + 1) % 6
        bm.faces.new((low[i], low[j], high[j], high[i]))
        bm.faces.new((high[i], high[j], tip))


def crystal_cluster(bm_a, bm_b, center, up, size, count, rng):
    """A fan of shards around `up`, alternating the two crystal colors."""
    for i in range(count):
        a = 2 * math.pi * i / count + rng.uniform(-0.3, 0.3)
        tilt = rng.uniform(0.35, 0.8) if i else 0.0
        side = Vector((math.cos(a), math.sin(a), 0))
        d = (up.normalized() * math.cos(tilt) + side * math.sin(tilt)).normalized()
        length = size * (1.0 if i == 0 else rng.uniform(0.55, 0.85))
        shard(bm_a if i % 2 == 0 else bm_b, center, d, length, length * 0.2, rng)


def crystal(stage, seed, coll, loc):
    """Crystal tree: a dark stone trunk whose limbs end in fans of glowing cyan and violet shards."""
    rng = random.Random(seed)
    bark, cyan, violet = bmesh.new(), bmesh.new(), bmesh.new()
    parts = [(bark, "CrystalBark", "Bark"), (cyan, "Crystal", "Crystal"), (violet, "CrystalViolet", "CrystalViolet")]
    if stage <= 2:  # 1: two little shards poking out of the ground; 2: a stem with a small fan
        if stage == 1:
            crystal_cluster(cyan, violet, Vector((0, 0, -0.3)), Vector((0, 0, 1)), 3.0, 3, rng)
        else:
            frustum(bark, Vector((0, 0, 0)), Vector((0, 0, 3.0)), 0.5, 0.3, 6, rng)
            crystal_cluster(cyan, violet, Vector((0, 0, 2.8)), Vector((0, 0, 1)), 3.6, 4, rng)
    else:
        g = STAGE_SIZE[stage]
        h = CRYSTAL_HEIGHT * g
        trunk_r = 3.4 * g + 0.4
        fork = Vector((rng.uniform(-1, 1) * g, rng.uniform(-1, 1) * g, h * 0.38))
        frustum(bark, Vector((0, 0, -0.5)), fork, trunk_r, trunk_r * 0.65, 6, rng, wobble=0.15 * g)
        if stage >= 5:  # root flare with small shards breaking through the ground
            for i in range(5):
                a = 2 * math.pi * i / 5 + rng.uniform(-0.3, 0.3)
                out = Vector((math.cos(a), math.sin(a), 0))
                frustum(bark, out * trunk_r * 0.3 + Vector((0, 0, trunk_r * 0.9)), out * trunk_r * 1.8 + Vector((0, 0, -0.3)),
                        trunk_r * 0.45, trunk_r * 0.15, 5, rng)
                if i % 2 == 0:
                    shard(violet if i else cyan, out * trunk_r * 2.4 + Vector((0, 0, -0.5)), out * 0.5 + Vector((0, 0, 1)),
                          h * 0.08, h * 0.015, rng)
        limbs = CRYSTAL_LIMBS[stage]
        size = h * 0.27
        fan = 4 if stage < 5 else 5
        for i in range(limbs):
            a = 2 * math.pi * i / limbs + rng.uniform(-0.3, 0.3)
            out = Vector((math.cos(a), math.sin(a), 0))
            tip = fork + out * h * 0.3 + Vector((0, 0, h * rng.uniform(0.12, 0.22)))
            frustum(bark, fork, tip, trunk_r * 0.5, trunk_r * 0.2, 5, rng)
            crystal_cluster(cyan, violet, tip, out * 0.7 + Vector((0, 0, 1)), size, fan, rng)
            if stage >= 6:  # a smaller fan partway along the limb, so the crown reads full
                crystal_cluster(violet, cyan, fork.lerp(tip, 0.5), out + Vector((0, 0, 0.6)), size * 0.6, 3, rng)
        crystal_cluster(violet, cyan, fork + Vector((0, 0, h * 0.22)), Vector((0, 0, 1)), size * 1.5, fan + 1, rng)
    s = FOREST_TREE_SCALE * STAGE_BOOST["Leafy"].get(stage, 1.0)
    return [finish(f"Crystal{stage}_{piece}", bm, mat, coll, loc, s) for bm, mat, piece in parts if bm.verts]


REDWOOD_HEIGHT = 110.0  # ~66 studs in the game: towers over the other trees
REDWOOD_TIERS = {3: 3, 4: 4, 5: 5, 6: 6, 7: 7, 8: 8}


def redwood(stage, seed, coll, loc):
    """Redwood: a tall, straight red trunk with buttressed roots and a narrow crown of layered
    dark-green pads high up, ending in a pointed top."""
    rng = random.Random(seed)
    bark, dark, light = bmesh.new(), bmesh.new(), bmesh.new()
    parts = [(bark, "Redwood", "Bark"), (dark, "RedwoodNeedles", "Needles"), (light, "RedwoodNeedlesB", "NeedlesB")]
    if stage <= 2:  # 1: a red stem with a feathery tuft; 2: taller, with two pads under the tuft
        stem = (2.6, 6.0)[stage - 1]
        frustum(bark, Vector((0, 0, 0)), Vector((0, 0, stem)), 0.3 + 0.1 * stage, 0.15, 6, rng)
        cone(light, Vector((0, 0, stem * 0.55)), stem * 0.75, 0.9 + 0.3 * stage, 6, rng, wobble=0.1)
        if stage == 2:
            for i in range(3):
                a = 2 * math.pi * i / 3
                blob(dark, Vector((math.cos(a) * 0.9, math.sin(a) * 0.9, stem * 0.4)), 1.0, rng, squash=(1.3, 1.3, 0.45))
    else:
        g = STAGE_SIZE[stage]
        h = REDWOOD_HEIGHT * g
        trunk_r = 4.4 * g + 0.4
        frustum(bark, Vector((0, 0, -0.5)), Vector((0, 0, h * 0.93)), trunk_r, trunk_r * 0.35, 8, rng, wobble=0.08 * g)
        if stage >= 4:  # buttressed roots
            for i in range(6):
                a = 2 * math.pi * i / 6 + rng.uniform(-0.2, 0.2)
                out = Vector((math.cos(a), math.sin(a), 0))
                frustum(bark, out * trunk_r * 0.4 + Vector((0, 0, trunk_r * 1.8)), out * trunk_r * 1.9 + Vector((0, 0, -0.3)),
                        trunk_r * 0.55, trunk_r * 0.2, 5, rng)
        # a narrow, uneven crown on the top part only; it climbs higher as the tree grows
        tiers = REDWOOD_TIERS[stage]
        start = h * {3: 0.3, 4: 0.36, 5: 0.42, 6: 0.48, 7: 0.52, 8: 0.55}[stage]
        top = h * 0.9
        base_r = h * 0.12
        for t in range(tiers):
            k = t / max(tiers - 1, 1)
            z = start + (top - start) * k + rng.uniform(-0.02, 0.02) * h
            r = base_r * (1.0 - 0.45 * k) * rng.uniform(0.75, 1.15)
            pads = 3 if t < tiers - 1 else 2
            for i in range(pads):
                a = 2 * math.pi * i / pads + t * 1.3 + rng.uniform(-0.5, 0.5)
                out = Vector((math.cos(a), math.sin(a), 0))
                reach = r * rng.uniform(0.4, 0.8)
                if stage >= 6 and i == 0:  # a stub branch under the clump
                    frustum(bark, Vector((0, 0, z - r * 0.3)), out * reach + Vector((0, 0, z - r * 0.1)),
                            trunk_r * 0.18, trunk_r * 0.07, 4, rng)
                blob(dark if (i + t) % 3 else light, out * reach + Vector((0, 0, z)), r * rng.uniform(0.6, 0.8), rng,
                     squash=(1.15, 1.15, 0.6))
        blob(light, Vector((0, 0, top + h * 0.03)), base_r * 0.45, rng, squash=(1.0, 1.0, 1.3))  # rounded top
    s = FOREST_TREE_SCALE * STAGE_BOOST["Leafy"].get(stage, 1.0)
    return [finish(f"Redwood{stage}_{piece}", bm, mat, coll, loc, s) for bm, mat, piece in parts if bm.verts]


BAMBOO_HEIGHT = 72.0
BAMBOO_STALKS = {3: 3, 4: 3, 5: 4, 6: 5, 7: 6, 8: 6}


def _spear_leaf(bm, base, direction, length, width):
    """A bamboo leaf: a flat diamond spear with a raised rib (6 triangles, closed)."""
    d = direction.normalized()
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 1e-4:
        side = Vector((1, 0, 0))
    side = side.normalized() * width
    up = d.cross(side).normalized() * width * 0.25
    mid = base + d * length * 0.35
    v = [bm.verts.new(p) for p in (base, base + d * length, mid + side, mid - side, mid + up)]
    for f in ((v[0], v[2], v[4]), (v[2], v[1], v[4]), (v[1], v[3], v[4]), (v[3], v[0], v[4]), (v[0], v[3], v[2]), (v[3], v[1], v[2])):
        bm.faces.new(f)


def _bamboo_stalk(stalk, nodes, leaves, base, height, radius, lean, rng, leafy=True):
    """One stalk: a straight shaft with a pointed tip, darker rings at its nodes, and spears of leaves
    fanning out from the top nodes."""
    top = base + lean * height + Vector((0, 0, height))
    frustum(stalk, base, top, radius, radius * 0.85, 6, rng)
    cone(stalk, top, radius * 2.5, radius * 0.85, 6, rng)
    rings = 4 if leafy else 2
    for k in range(1, rings + 1):
        at = base.lerp(top, k / (rings + 1))
        frustum(nodes, at - Vector((0, 0, radius * 0.3)), at + Vector((0, 0, radius * 0.3)), radius * 1.18, radius * 1.18, 5, rng)
    if leafy:
        for k in (rings, rings - 1):
            at = base.lerp(top, k / (rings + 1))
            for j in range(5):
                heading = 2 * math.pi * j / 5 + rng.uniform(-0.4, 0.4)
                out = Vector((math.cos(heading), math.sin(heading), rng.uniform(-0.45, 0.1)))
                _spear_leaf(leaves, at, out, height * 0.18 + radius * 4, radius * 1.4)


def bamboo(stage, seed, coll, loc):
    """Bamboo: a clump of tall, segmented green stalks with darker node rings and spears of leaves near
    the tops. Early stages are pointed shoots."""
    rng = random.Random(seed)
    stalk, nodes, leaves = bmesh.new(), bmesh.new(), bmesh.new()
    parts = [(stalk, "BambooStalk", "Bark"), (nodes, "BambooNode", "Nodes"), (leaves, "BambooLeaves", "Leaves")]
    if stage <= 2:  # 1: one shoot with a leaf; 2: two shoots
        for i in range(stage):
            base = Vector(((i - 0.5) * 1.2 * (stage - 1), 0, 0))
            h = (3.0, 5.5)[stage - 1] * (1 - 0.3 * i)
            _bamboo_stalk(stalk, nodes, leaves, base, h, 0.35 + 0.08 * stage, Vector((0, 0, 0)), rng, leafy=False)
            _spear_leaf(leaves, base + Vector((0, 0, h * 0.6)), Vector((1, 0.3, 0.4)), 1.6 + stage, 0.5)
    else:
        g = STAGE_SIZE[stage]
        h = BAMBOO_HEIGHT * g
        r = 1.1 * g + 0.3
        count = BAMBOO_STALKS[stage]
        for i in range(count):
            a = 2 * math.pi * i / count + rng.uniform(-0.3, 0.3)
            d = 0 if i == 0 else rng.uniform(0.6, 1.0) * h * 0.08 + r * 2
            base = Vector((math.cos(a) * d, math.sin(a) * d, -0.3))
            lean = Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(0.03, 0.09)
            _bamboo_stalk(stalk, nodes, leaves, base, h * (1.0 if i == 0 else rng.uniform(0.6, 0.95)), r * rng.uniform(0.85, 1.1),
                          lean, rng)
    s = FOREST_TREE_SCALE * STAGE_BOOST["Leafy"].get(stage, 1.0)
    return [finish(f"Bamboo{stage}_{piece}", bm, mat, coll, loc, s) for bm, mat, piece in parts if bm.verts]


def bamboo_seed(coll, loc):
    """The bamboo seed: a little stoppered bamboo tube, like a canister, with node bands, a woven-leaf
    stopper and a curled shoot with two leaves sprouting out of the top."""
    rng = random.Random(75)
    tube, bands, leaf = bmesh.new(), bmesh.new(), bmesh.new()
    frustum(tube, Vector((0, 0, 0)), Vector((0, 0, 6.2)), 2.4, 2.3, 8, rng)
    for z in (1.6, 4.4):
        frustum(bands, Vector((0, 0, z - 0.3)), Vector((0, 0, z + 0.3)), 2.6, 2.6, 8, rng)
    blob(leaf, Vector((0, 0, 6.4)), 2.2, rng, squash=(1.0, 1.0, 0.35), subdiv=1, rough=0.08)  # the stopper
    frustum(leaf, Vector((0, 0, 6.6)), Vector((0.3, 0.2, 8.6)), 0.35, 0.18, 5, rng)  # the shoot
    for heading in (0.5, 0.5 + math.pi):
        frond(leaf, Vector((0.3, 0.2, 8.4)), heading, 3.0, 0.9, rng, lift=1.0, droop=1.8)
    return [finish("BambooSeed_Tube", tube, "BambooStalk", coll, loc), finish("BambooSeed_Bands", bands, "BambooNode", coll, loc),
            finish("BambooSeed_Leaf", leaf, "BambooLeaves", coll, loc)]


PALM_HEIGHT = 80.0
PALM_FRONDS = {3: 6, 4: 7, 5: 8, 6: 9, 7: 10, 8: 10}


def frond(bm, base, heading, length, width, rng, lift=0.5, droop=1.4):
    """A palm frond: a thin strip that arches out from `base` and droops toward its tip, with a raised
    middle rib and saw-tooth edges for the leaflets."""
    out = Vector((math.cos(heading), math.sin(heading), 0))
    side = Vector((-out.y, out.x, 0))
    steps, th = 5, width * 0.08
    top, bot = [], []
    p = base.copy()
    for i in range(steps + 1):
        t = i / steps
        ang = lift - droop * t * t  # rises, then curls down toward the tip
        if i:
            p = p + (out * math.cos(ang) + Vector((0, 0, math.sin(ang)))) * (length / steps)
        w = width * math.sin(math.pi * min(t * 1.15 + 0.12, 1.0)) * (1.0 if i % 2 else 0.75) + 0.05
        sag = Vector((0, 0, -w * 0.35))
        row = [p + side * w + sag, p, p - side * w + sag]
        top.append([bm.verts.new(v) for v in row])
        bot.append([bm.verts.new(v - Vector((0, 0, th))) for v in row])
    for i in range(steps):
        for j in range(2):
            bm.faces.new((top[i][j], top[i + 1][j], top[i + 1][j + 1], top[i][j + 1]))
            bm.faces.new((bot[i][j + 1], bot[i + 1][j + 1], bot[i + 1][j], bot[i][j]))
        for j in (0, 2):
            bm.faces.new((top[i][j], bot[i][j], bot[i + 1][j], top[i + 1][j]))
    for row in (0, steps):
        bm.faces.new((top[row][0], top[row][1], top[row][2], bot[row][2], bot[row][1], bot[row][0]))


def palm(stage, seed, coll, loc):
    """Palm: a slender, ringed trunk that curves to one side, topped by a burst of drooping fronds
    and, once grown, a cluster of coconuts."""
    rng = random.Random(seed)
    bark, green, light, nuts = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    parts = [(bark, "PalmBark", "Bark"), (green, "PalmFronds", "Fronds"), (light, "PalmFrondsB", "FrondsB"),
             (nuts, "Coconut", "Coconuts")]
    if stage <= 2:  # 1: three fronds straight out of the ground; 2: a stubby stem with five
        crown = Vector((0, 0, (0.3, 1.8)[stage - 1]))
        if stage == 2:
            frustum(bark, Vector((0, 0, 0)), crown, 0.6, 0.45, 6, rng)
        count = 2 * stage + 1
        for i in range(count):
            frond(green if i % 2 else light, crown, 2 * math.pi * i / count + 0.3, (2.6, 4.2)[stage - 1],
                  (0.45, 0.65)[stage - 1], rng, lift=0.9, droop=1.6)
    else:
        g = STAGE_SIZE[stage]
        h = PALM_HEIGHT * g
        trunk_r = 2.5 * g + 0.45
        lean = rng.uniform(0, 2 * math.pi)
        bend = Vector((math.cos(lean), math.sin(lean), 0)) * h * 0.14
        rings = min(3 + stage, 8)  # each ring bulges a little where the old fronds fell off
        pts = [bend * (i / rings) ** 2 + Vector((0, 0, h * 0.82 * i / rings - 0.4)) for i in range(rings + 1)]
        for i in range(rings):
            k = i / rings
            frustum(bark, pts[i], pts[i + 1], trunk_r * (1.2 - 0.3 * k), trunk_r * (0.88 - 0.3 * k), 6, rng)
        if stage >= 5:  # a small swollen base
            frustum(bark, Vector((0, 0, -0.5)), Vector((0, 0, h * 0.05)), trunk_r * 1.7, trunk_r * 1.1, 6, rng)
        crown = pts[-1]
        blob(green, crown, trunk_r * 1.3, rng, squash=(1.0, 1.0, 0.8))  # the crown shaft the fronds grow from
        count = PALM_FRONDS[stage]
        length = h * (0.68 - 0.2 * g)  # young palms are mostly fronds
        for i in range(count):
            heading = 2 * math.pi * i / count + rng.uniform(-0.2, 0.2)
            upper = i % 2 == 0
            frond(green if upper else light, crown + Vector((0, 0, 0.3 if upper else -0.2)), heading,
                  length * rng.uniform(0.85, 1.05), length * 0.2, rng,
                  lift=0.75 if upper else 0.35, droop=1.5 if upper else 1.7)
        if stage >= 6:  # coconuts tucked under the crown
            for i in range(3 + (stage - 6)):
                a = 2 * math.pi * i / (3 + (stage - 6)) + 0.4
                blob(nuts, crown + Vector((math.cos(a) * trunk_r * 1.5, math.sin(a) * trunk_r * 1.5, -trunk_r * 2.4)),
                     trunk_r * 1.4, rng, subdiv=1, rough=0.1)
    s = FOREST_TREE_SCALE * STAGE_BOOST["Leafy"].get(stage, 1.0)
    return [finish(f"Palm{stage}_{piece}", bm, mat, coll, loc, s) for bm, mat, piece in parts if bm.verts]


# ---------------------------------------------------------------------------
# The Ancient Tree (4 stages; grows with the Forest Bar) and its fixed-size base
# ---------------------------------------------------------------------------
ANCIENT_HEIGHT = 350.0  # full grown; visible from anywhere on the map
ANCIENT_ROOT_REACH = 72.0  # roots stay inside the hub clearing (radius ~80)
ANCIENT_STAGE_SIZE = {1: 0.15, 2: 0.35, 3: 0.65, 4: 1.0}  # each stage's size as a fraction of full grown


def ancient(stage, seed, coll, loc):
    """The world tree: tall tapering trunk, roots kept inside the hub, branches spreading into a wide
    umbrella canopy high above the forest, cyan glow on the trunk, roots and canopy underside."""
    rng = random.Random(seed)
    g = ANCIENT_STAGE_SIZE[stage]
    h = ANCIENT_HEIGHT * g
    trunk_r = 30.0 * g + 0.8
    reach = ANCIENT_ROOT_REACH * g
    sub = 2 if stage >= 3 else 1  # finer facets on the big stages
    bark, leaves, dark, glow = (bmesh.new() for _ in range(4))

    # flared base, then a tall trunk in four twisting, tapering segments
    frustum(bark, Vector((0, 0, -1.0)), Vector((0, 0, trunk_r * 1.2)), trunk_r * 1.45, trunk_r, 10, rng,
            wobble=trunk_r * 0.05)
    trunk_h = h * 0.55
    pts = [Vector((0, 0, trunk_r * 0.6))]
    for i in range(1, 5):
        pts.append(Vector((rng.uniform(-1, 1) * trunk_r * 0.2, rng.uniform(-1, 1) * trunk_r * 0.2, trunk_h * i / 4)))
    radii = [trunk_r, trunk_r * 0.85, trunk_r * 0.72, trunk_r * 0.6, trunk_r * 0.5]
    for i in range(4):
        frustum(bark, pts[i], pts[i + 1], radii[i], radii[i + 1], 10, rng, wobble=trunk_r * 0.04)

    # roots spreading to the edge of the hub, each in two bent segments with a glowing vein
    roots = 9 if stage >= 2 else 5
    for i in range(roots):
        a = 2 * math.pi * i / roots + rng.uniform(-0.2, 0.2)
        out = Vector((math.cos(a), math.sin(a), 0))
        side = Vector((-out.y, out.x, 0)) * rng.uniform(-0.3, 0.3)
        p0 = out * trunk_r * 0.7 + Vector((0, 0, trunk_r * 1.1))
        p1 = (out + side).normalized() * (trunk_r + (reach - trunk_r) * 0.45) + Vector((0, 0, trunk_r * 0.35))
        p2 = (out + side * 1.6).normalized() * reach * rng.uniform(0.85, 1.0) + Vector((0, 0, -0.5))
        frustum(bark, p0, p1, trunk_r * 0.5, trunk_r * 0.3, 7, rng)
        frustum(bark, p1, p2, trunk_r * 0.3, trunk_r * 0.07, 6, rng)
        lift = Vector((0, 0, trunk_r * 0.28))
        frustum(glow, p0 + lift * 1.6, p1 + lift, trunk_r * 0.05, trunk_r * 0.04, 4, rng)
        frustum(glow, p1 + lift, p2 + lift * 0.3, trunk_r * 0.04, trunk_r * 0.015, 4, rng)

    # main branches spreading out to hold the umbrella canopy
    spread = h * 0.42
    tips = []
    branches = 7 if stage >= 2 else 4
    mids = []
    for i in range(branches):
        a = 2 * math.pi * i / branches + rng.uniform(-0.2, 0.2)
        start = Vector((0, 0, trunk_h * rng.uniform(0.75, 0.95)))
        mid = Vector((math.cos(a) * spread * 0.5, math.sin(a) * spread * 0.5, h * 0.62))
        end = Vector((math.cos(a) * spread, math.sin(a) * spread, h * 0.68))
        frustum(bark, start, mid, radii[-1] * 0.6, radii[-1] * 0.35, 7, rng)
        frustum(bark, mid, end, radii[-1] * 0.35, radii[-1] * 0.15, 6, rng)
        tips.append(end)
        mids.append(mid)

    # umbrella canopy in two greens: a wide dome, clumps on every branch tip, rings between and on top
    blob(leaves, Vector((0, 0, h * 0.78)), h * 0.3, rng, squash=(1.3, 1.3, 0.55), subdiv=sub, rough=0.12)
    for i, tip in enumerate(tips):
        blob(dark if i % 3 == 0 else leaves, tip + Vector((0, 0, h * 0.02)), h * 0.13 * rng.uniform(0.9, 1.1), rng,
             squash=(1.0, 1.0, 0.8), subdiv=sub, rough=0.14)
    rings = ((branches, 0.36, 0.71, 0.11, 0.5), (8, 0.25, 0.8, 0.14, 0.0), (4, 0.1, 0.9, 0.12, 0.3))
    for n, dist, z, size, offset in rings:
        for i in range(n):
            a = 2 * math.pi * (i + offset) / n + rng.uniform(-0.15, 0.15)
            blob(dark if (i + n) % 3 == 0 else leaves, Vector((math.cos(a) * h * dist, math.sin(a) * h * dist, h * z)),
                 h * size * rng.uniform(0.9, 1.1), rng, squash=(1.0, 1.0, 0.8), subdiv=sub, rough=0.14)

    # glowing orbs under the canopy. (The rune streaks that spiralled up the trunk were replaced by the
    # glyphs; they're still generated into a scrap mesh so the random numbers after them don't change.)
    streaks = bmesh.new()
    for i in range(6):
        a = 2 * math.pi * i / 6 + 0.3
        z0, z1 = h * 0.04, h * rng.uniform(0.25, 0.4)
        r0 = radii[0] * 1.02
        r1 = (radii[0] - (radii[0] - radii[-1]) * (z1 / trunk_h)) * 1.02
        p0 = Vector((math.cos(a) * r0, math.sin(a) * r0, z0))
        p1 = Vector((math.cos(a + 0.35) * r1, math.sin(a + 0.35) * r1, z1))
        frustum(streaks, p0, p1, trunk_r * 0.06, trunk_r * 0.04, 4, rng)
        blob(streaks, p1, trunk_r * 0.1, rng, subdiv=1, rough=0.05)
    streaks.free()
    if stage >= 3:
        for tip in tips:
            for _ in range(2):
                o = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)) * h * 0.06
                blob(glow, tip + o - Vector((0, 0, h * 0.1)), h * 0.012, rng, subdiv=1, rough=0.05)

    glyphs, vines = bmesh.new(), bmesh.new()
    trunk_glyphs(glyphs, vines, pts, radii, trunk_r, trunk_h, h, mids, stage, rng)

    pieces = [("Bark", bark, "AncientBark"), ("Leaves", leaves, "AncientLeaves"),
              ("LeavesDark", dark, "AncientLeavesDark"), ("Glow", glow, "Glow"),
              ("GlowGlyphs", glyphs, "Glow"), ("Vines", vines, "Vine")]
    return [finish(f"Ancient{stage}_{name}", bm, mat, coll, loc) for name, bm, mat in pieces]


def ancient_sakura(stage, seed, coll, loc):
    """Kyoto Forest's world tree (2026-10-07, after the user's bonsai reference photo): a dark trunk that
    curves like an S out of a flared root base, one big fluffy crown that sweeps out to one side (+X) and
    droops at its far end, and two low side branches with small blossom clusters. Pale pink blossom with
    coral-red specks. No markings on the trunk or roots (the user's call); glowing orbs under the full-grown
    crown. Piece names like the Ancient Tree's (Bark, Leaves, LeavesDark, LeavesLight, Glow) so
    AncientTreeController treats it the same way."""
    rng = random.Random(seed)
    g = ANCIENT_STAGE_SIZE[stage]
    h = ANCIENT_HEIGHT * g * 0.85
    trunk_r = 26.0 * g + 0.8
    reach = ANCIENT_ROOT_REACH * g * 0.8
    sub = 2 if stage >= 3 else 1
    bark, pale, coral, white, glow = (bmesh.new() for _ in range(5))

    # a wide flared root base, then the S-curved trunk
    frustum(bark, Vector((0, 0, -1.0)), Vector((0, 0, trunk_r * 0.9)), trunk_r * 1.9, trunk_r * 1.05, 12, rng,
            wobble=trunk_r * 0.08)
    sway = (0.0, -0.05, 0.05, 0.08, 0.02, -0.03)  # sideways (x) per trunk point, times h: the S
    rise = (0.02, 0.13, 0.25, 0.36, 0.46, 0.55)
    pts = [Vector((sway[i] * h, 0.012 * h * math.sin(i * 1.7), rise[i] * h)) for i in range(6)]
    radii = [trunk_r * k for k in (1.0, 0.86, 0.74, 0.64, 0.56, 0.48)]
    for i in range(5):
        frustum(bark, pts[i], pts[i + 1], radii[i], radii[i + 1], 10, rng, wobble=trunk_r * 0.05)
        blob(bark, pts[i + 1], radii[i + 1] * 1.02, rng, subdiv=1, rough=0.08)  # smooth elbow

    # short roots gripping the base
    roots = 7 if stage >= 2 else 4
    for i in range(roots):
        a = 2 * math.pi * i / roots + rng.uniform(-0.25, 0.25)
        out = Vector((math.cos(a), math.sin(a), 0))
        p0 = out * trunk_r * 0.8 + Vector((0, 0, trunk_r * 0.7))
        p1 = out * reach * rng.uniform(0.75, 1.0) + Vector((0, 0, -0.5))
        frustum(bark, p0, p1, trunk_r * 0.42, trunk_r * 0.08, 6, rng)

    # the crown: a lopsided cloud leaning out to +X, highest just past the trunk and drooping at the far end
    top = pts[-1]
    crown_center = Vector((0.12 * h, 0, 0.74 * h))
    tips, mids = [], []
    for i in range(7 if stage >= 2 else 4):  # limbs from the trunk top into the crown
        u = -0.6 + 1.5 * i / 6
        end = Vector((u * 0.5 * h, rng.uniform(-0.22, 0.22) * h, (0.68 - 0.06 * u) * h))
        mid = top.lerp(end, 0.5) + Vector((0, 0, 0.03 * h))
        frustum(bark, top, mid, radii[-1] * 0.55, radii[-1] * 0.3, 6, rng)
        frustum(bark, mid, end, radii[-1] * 0.3, radii[-1] * 0.12, 5, rng)
        tips.append(end)
        mids.append(mid)
    count = {1: 14, 2: 24, 3: 40, 4: 40}[stage]
    for i in range(count):
        u = rng.uniform(-1, 1)  # -1 = the short side over the trunk, +1 = the far, drooping end
        v = rng.uniform(-1, 1)
        layer = rng.random()
        x = crown_center.x + u * 0.5 * h
        y = v * 0.33 * h * (1 - 0.25 * u * u)
        dome = (1 - 0.5 * u * u) * 0.14 * h  # higher in the middle
        z = crown_center.z + dome * layer - 0.09 * h * max(u, 0) ** 2 - 0.03 * h * u
        size = h * rng.uniform(0.07, 0.11) * (1 - 0.25 * max(u, 0))
        target = white if layer > 0.8 else pale
        blob(target, Vector((x, y, z)), size, rng, squash=(1.2, 1.2, 0.75), subdiv=sub, rough=0.28)
    # coral-red specks scattered over the crown's surface
    for i in range({1: 8, 2: 16, 3: 30, 4: 30}[stage]):
        u, v = rng.uniform(-1, 1), rng.uniform(-1, 1)
        x = crown_center.x + u * 0.5 * h
        y = v * 0.36 * h * (1 - 0.25 * u * u)
        z = crown_center.z + (1 - 0.5 * u * u) * 0.14 * h * rng.uniform(0.6, 1.1) - 0.09 * h * max(u, 0) ** 2 - 0.03 * h * u
        blob(coral, Vector((x, y, z + 0.04 * h)), h * rng.uniform(0.012, 0.022), rng, subdiv=1, rough=0.3)

    # two low side branches with small clusters (left low, right a little higher)
    for side, at, reach_out, lift in ((-1, 2, 0.26, 0.2), (1, 3, 0.2, 0.3)):
        start = pts[at]
        end = Vector((side * reach_out * h, -0.05 * h * side, lift * h))
        mid = start.lerp(end, 0.5) + Vector((0, 0, 0.03 * h))
        frustum(bark, start, mid, radii[at] * 0.4, radii[at] * 0.22, 6, rng)
        frustum(bark, mid, end, radii[at] * 0.22, radii[at] * 0.1, 5, rng)
        if stage >= 2:
            for _ in range(5):
                o = Vector((rng.uniform(-1, 1) * 0.06 * h, rng.uniform(-1, 1) * 0.05 * h, rng.uniform(0, 0.04) * h))
                blob(pale, end + o, h * rng.uniform(0.035, 0.05), rng, squash=(1.2, 1.2, 0.8), subdiv=1, rough=0.28)
            for _ in range(4):
                o = Vector((rng.uniform(-1, 1) * 0.07 * h, rng.uniform(-1, 1) * 0.05 * h, rng.uniform(0.02, 0.06) * h))
                blob(coral, end + o, h * 0.012, rng, subdiv=1, rough=0.3)

    # glowing pink orbs hanging under the crown
    if stage >= 3:
        for tip in tips:
            o = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)) * h * 0.05
            blob(glow, tip + o - Vector((0, 0, h * 0.07)), h * 0.012, rng, subdiv=1, rough=0.05)

    pieces = [("Bark", bark, "SakuraBark"), ("Leaves", pale, "Blossom"), ("LeavesDark", coral, "BlossomDeep"),
              ("LeavesLight", white, "FlowersB"), ("Glow", glow, "Glow")]
    return [finish(f"AncientSakura{stage}_{name}", bm, mat, coll, loc) for name, bm, mat in pieces if bm.verts]


# ---------------------------------------------------------------------------
# The Great Smoky Mountains world (autumn, 2026-10-07): Maple and Birch, its Common trees, and its World Tree,
# a giant maple (AncientMaple). Fall colors, so it also suits Halloween.
# ---------------------------------------------------------------------------
MAPLE_HEIGHT = 74.0
MAPLE_CLUMPS = {3: 4, 4: 6, 5: 9, 6: 11, 7: 13, 8: 15}
BIRCH_HEIGHT = 82.0
BIRCH_STEMS = {3: 1, 4: 1, 5: 2, 6: 2, 7: 3, 8: 3}


def maple(stage, seed, coll, loc):
    """Autumn maple: a sturdy grey-brown trunk with a few strong limbs and a full, rounded crown of clumps in
    three fall colors (orange, red and gold, mixed). Early stages are a stem with small red leaves."""
    rng = random.Random(seed)
    bark, orange, red, gold = (bmesh.new() for _ in range(4))
    colors = (orange, red, gold)
    if stage <= 2:
        stem = (2.2, 5.0)[stage - 1]
        frustum(bark, Vector((0, 0, 0)), Vector((0, 0, stem)), 0.25 + 0.1 * stage, 0.18 + 0.07 * stage, 6, rng)
        for i in range(2 * stage + 1):
            a = 2 * math.pi * i / (2 * stage + 1) + rng.uniform(-0.3, 0.3)
            r = 0.5 * stage
            blob(colors[i % 2], Vector((math.cos(a) * r, math.sin(a) * r, stem + 0.2)), 0.55 + 0.4 * stage, rng,
                 squash=(1.3, 1.0, 0.55), subdiv=1, rough=0.25)
    else:
        g = STAGE_SIZE[stage]
        h = MAPLE_HEIGHT * g
        trunk_r = 4.4 * g + 0.5
        top = Vector((rng.uniform(-1, 1) * g, rng.uniform(-1, 1) * g, h * 0.4))
        frustum(bark, Vector((0, 0, -0.5)), top, trunk_r, trunk_r * 0.62, 7, rng, wobble=0.15 * g)
        if stage >= 5:  # root flare and limbs up into the crown
            for i in range(5):
                a = 2 * math.pi * i / 5 + rng.uniform(-0.3, 0.3)
                out = Vector((math.cos(a), math.sin(a), 0))
                frustum(bark, out * trunk_r * 0.3 + Vector((0, 0, trunk_r * 0.9)), out * trunk_r * 1.8 + Vector((0, 0, -0.3)),
                        trunk_r * 0.45, trunk_r * 0.15, 5, rng)
            for i in range(4):
                a = 2 * math.pi * i / 4 + rng.uniform(-0.4, 0.4)
                frustum(bark, top - Vector((0, 0, h * 0.06)),
                        top + Vector((math.cos(a) * h * 0.2, math.sin(a) * h * 0.2, h * 0.2)), trunk_r * 0.42, trunk_r * 0.16,
                        5, rng)
        # the crown: a tall rounded dome of clumps, each one a fall color
        crown = top + Vector((0, 0, h * 0.24))
        big = h * 0.27
        blob(orange, crown, big, rng, squash=(1.05, 1.05, 1.0), rough=0.2)
        clumps = MAPLE_CLUMPS[stage]
        for i in range(clumps):
            a = 2 * math.pi * i / clumps + rng.uniform(-0.3, 0.3)
            ring = i % 3  # a lower, wider ring, a middle one and a higher, tighter one, overlapping into one crown
            d = big * (0.85, 0.7, 0.45)[ring] * rng.uniform(0.9, 1.05)
            z = big * (-0.3, 0.15, 0.55)[ring] + rng.uniform(-0.1, 0.1) * big
            blob(colors[rng.randrange(3)], crown + Vector((math.cos(a) * d, math.sin(a) * d, z)),
                 big * rng.uniform(0.55, 0.7), rng, squash=(1.0, 1.0, 0.9), subdiv=2 if stage >= 6 else 1, rough=0.16)
        if stage >= 7:
            blob(red, crown + Vector((0, 0, big * 0.85)), big * 0.5, rng, squash=(1, 1, 0.8), rough=0.2)
    s = FOREST_TREE_SCALE * STAGE_BOOST["Leafy"].get(stage, 1.0)
    parts = [(bark, "MapleBark", "Bark"), (orange, "MapleOrange", "Leaves"), (red, "MapleRed", "LeavesB"),
             (gold, "MapleGold", "LeavesC")]
    return [finish(f"Maple{stage}_{piece}", bm, mat, coll, loc, s) for bm, mat, piece in parts if bm.verts]


def birch(stage, seed, coll, loc):
    """Birch in the fall: slender white trunks (one to three, leaning apart) with dark bark marks, and a narrow,
    airy crown of small golden clumps. Early stages are a thin white stem with a few gold leaves."""
    rng = random.Random(seed)
    bark, marks, gold, pale = (bmesh.new() for _ in range(4))
    if stage <= 2:
        stem = (2.6, 5.6)[stage - 1]
        frustum(bark, Vector((0, 0, 0)), Vector((0, 0, stem)), 0.2 + 0.08 * stage, 0.14 + 0.05 * stage, 6, rng)
        box(marks, Vector((0, 0, stem * 0.5)), (0.5 + 0.15 * stage, 0.5 + 0.15 * stage, 0.12))
        for i in range(2 * stage):
            a = 2 * math.pi * i / (2 * stage) + rng.uniform(-0.3, 0.3)
            blob(gold if i % 2 else pale, Vector((math.cos(a) * 0.45 * stage, math.sin(a) * 0.45 * stage, stem + 0.1)),
                 0.5 + 0.35 * stage, rng, squash=(1.2, 1.0, 0.7), subdiv=1, rough=0.2)
    else:
        g = STAGE_SIZE[stage]
        h = BIRCH_HEIGHT * g
        stems = BIRCH_STEMS[stage]
        for k in range(stems):
            a = 2 * math.pi * k / stems + rng.uniform(-0.3, 0.3)
            lean = Vector((math.cos(a), math.sin(a), 0)) * (0 if stems == 1 else h * 0.08)
            trunk_r = (1.7 * g + 0.3) * (1 if k == 0 else 0.8)
            height = h * (0.7 if k == 0 else rng.uniform(0.55, 0.65))
            base = Vector((math.cos(a), math.sin(a), 0)) * (0 if stems == 1 else trunk_r * 0.8)
            top = base + lean + Vector((0, 0, height))
            frustum(bark, base - Vector((0, 0, 0.5)), top, trunk_r, trunk_r * 0.55, 7, rng, wobble=0.06 * g)
            # dark marks: thin bands part-way around the trunk
            for j in range(int(8 + 14 * g)):
                t = rng.uniform(0.08, 0.92)
                c = base.lerp(top, t)
                r = trunk_r * (1 - 0.45 * t) * 1.03
                ang = rng.uniform(0, 2 * math.pi)
                p = c + Vector((math.cos(ang), math.sin(ang), 0)) * (r - 0.02)
                box(marks, p, (max(0.15, r * 0.35), r * 1.7, max(0.2, 0.7 * g)), rot_z=ang)  # a dark band on the bark
            # an airy crown of small golden clumps up the top half of the stem
            clumps = 4 + int(10 * g)
            for j in range(clumps):
                t = rng.uniform(0.5, 1.0)
                c = base.lerp(top, t)
                spread = h * 0.13 * (1.15 - t) + h * 0.04
                ang = rng.uniform(0, 2 * math.pi)
                p = c + Vector((math.cos(ang) * spread, math.sin(ang) * spread, rng.uniform(0, h * 0.05)))
                blob(gold if j % 3 else pale, p, h * rng.uniform(0.055, 0.08), rng, squash=(1.0, 1.0, 1.15), rough=0.22)
            blob(gold, top + Vector((0, 0, h * 0.04)), h * 0.085, rng, squash=(1, 1, 1.2), rough=0.2)
    s = FOREST_TREE_SCALE * STAGE_BOOST["Leafy"].get(stage, 1.0)
    parts = [(bark, "BirchBark", "Bark"), (marks, "BirchMark", "Marks"), (gold, "BirchGold", "Leaves"),
             (pale, "BirchGoldB", "LeavesB")]
    return [finish(f"Birch{stage}_{piece}", bm, mat, coll, loc, s) for bm, mat, piece in parts if bm.verts]


def ancient_maple(stage, seed, coll, loc):
    """The Great Smoky Mountains' world tree: a giant maple with the Ancient Tree's size and stages. A broad,
    buttressed trunk, thick limbs, and a huge rounded crown of red, orange and gold clumps; warm amber veins on
    the roots and glowing amber orbs hanging under the crown (lanterns, for fall and Halloween). Piece names
    like the Ancient Tree's (Bark, Leaves, LeavesDark, LeavesLight, Glow) so AncientTreeController treats it the
    same way."""
    rng = random.Random(seed)
    g = ANCIENT_STAGE_SIZE[stage]
    h = ANCIENT_HEIGHT * g * 0.9
    trunk_r = 30.0 * g + 0.8
    reach = ANCIENT_ROOT_REACH * g
    sub = 2 if stage >= 3 else 1
    bark, orange, red, gold, glow = (bmesh.new() for _ in range(5))
    colors = (orange, red, gold)
    frustum(bark, Vector((0, 0, -1.0)), Vector((0, 0, trunk_r * 1.2)), trunk_r * 1.5, trunk_r, 10, rng, wobble=trunk_r * 0.05)
    trunk_h = h * 0.5
    pts = [Vector((0, 0, trunk_r * 0.6))]
    for i in range(1, 4):
        pts.append(Vector((rng.uniform(-1, 1) * trunk_r * 0.15, rng.uniform(-1, 1) * trunk_r * 0.15, trunk_h * i / 3)))
    radii = [trunk_r * 1.15, trunk_r, trunk_r * 0.86, trunk_r * 0.74]  # a stout trunk
    for i in range(3):
        frustum(bark, pts[i], pts[i + 1], radii[i], radii[i + 1], 10, rng, wobble=trunk_r * 0.04)
    roots = 9 if stage >= 2 else 5
    for i in range(roots):
        a = 2 * math.pi * i / roots + rng.uniform(-0.2, 0.2)
        out = Vector((math.cos(a), math.sin(a), 0))
        p0 = out * trunk_r * 0.7 + Vector((0, 0, trunk_r * 1.1))
        p1 = out * (trunk_r + (reach - trunk_r) * 0.45) + Vector((0, 0, trunk_r * 0.35))
        p2 = out * reach * rng.uniform(0.85, 1.0) + Vector((0, 0, -0.5))
        frustum(bark, p0, p1, trunk_r * 0.5, trunk_r * 0.3, 7, rng)
        frustum(bark, p1, p2, trunk_r * 0.3, trunk_r * 0.07, 6, rng)
        lift = Vector((0, 0, trunk_r * 0.28))
        frustum(glow, p0 + lift * 1.6, p1 + lift, trunk_r * 0.05, trunk_r * 0.04, 4, rng)
        frustum(glow, p1 + lift, p2 + lift * 0.3, trunk_r * 0.04, trunk_r * 0.015, 4, rng)
    # thick limbs fanning up and out into the crown
    branches = 7 if stage >= 2 else 4
    tips = []
    for i in range(branches):
        a = 2 * math.pi * i / branches + rng.uniform(-0.2, 0.2)
        start = pts[-1] - Vector((0, 0, trunk_h * 0.15))
        end = Vector((math.cos(a) * h * 0.34, math.sin(a) * h * 0.34, h * 0.64))
        frustum(bark, start, end, radii[-1] * 0.55, radii[-1] * 0.2, 7, rng)
        tips.append(end)
    # the crown: a huge rounded dome in fall colors
    crown = Vector((0, 0, h * 0.76))
    big = h * 0.26
    blob(orange, crown, big * 1.15, rng, squash=(1.3, 1.3, 0.85), subdiv=sub, rough=0.14)
    for i, tip in enumerate(tips):
        blob(colors[i % 3], tip + Vector((0, 0, h * 0.04)), big * rng.uniform(0.55, 0.65), rng, subdiv=sub, rough=0.16)
    for n, dist, z, size, offset in ((9, 0.36, 0.7, 0.13, 0.5), (8, 0.24, 0.86, 0.14, 0.0), (4, 0.1, 0.97, 0.13, 0.3)):
        for i in range(n):
            a = 2 * math.pi * (i + offset) / n + rng.uniform(-0.15, 0.15)
            blob(colors[rng.randrange(3)], Vector((math.cos(a) * h * dist, math.sin(a) * h * dist, h * z)),
                 h * size * rng.uniform(0.9, 1.1), rng, squash=(1.0, 1.0, 0.9), subdiv=sub, rough=0.16)
    if stage >= 3:  # amber lanterns under the crown
        for tip in tips:
            for _ in range(2):
                o = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)) * h * 0.06
                blob(glow, tip + o - Vector((0, 0, h * 0.1)), h * 0.014, rng, subdiv=1, rough=0.05)
    pieces = [("Bark", bark, "MapleBark"), ("Leaves", orange, "MapleOrange"), ("LeavesDark", red, "MapleRed"),
              ("LeavesLight", gold, "MapleGold"), ("Glow", glow, "Lantern")]
    return [finish(f"AncientMaple{stage}_{name}", bm, mat, coll, loc) for name, bm, mat in pieces if bm.verts]


def _trunk_at(pts, radii, z):
    """The trunk's center and radius at height z (between its segment points)."""
    if z <= pts[0].z:
        return Vector((pts[0].x, pts[0].y, z)), radii[0]
    for i in range(len(pts) - 1):
        if z <= pts[i + 1].z or i == len(pts) - 2:
            t = min(1.0, (z - pts[i].z) / (pts[i + 1].z - pts[i].z))
            c = pts[i].lerp(pts[i + 1], t)
            return Vector((c.x, c.y, z)), radii[i] + (radii[i + 1] - radii[i]) * t


def _polyline(bm, points, width, sides=4):
    prev = None
    for p in points:
        if prev is not None and (p - prev).length > 1e-3:
            frustum(bm, prev, p, width, width, sides, None)
        prev = p


def _glyph_shapes():
    """The three glyphs as polylines in a unit box (u across, v up): a swirl, a leaf and a drop."""
    n = 44
    swirl = [[((0.06 + 0.44 * k / n) * math.cos(k / n * 3.3 * math.pi),
               (0.06 + 0.44 * k / n) * math.sin(k / n * 3.3 * math.pi)) for k in range(n + 1)]]
    side = [(0.28 * math.sin(math.pi * k / 16), -0.5 + k / 16) for k in range(17)]
    back = [(-u, v) for u, v in reversed(side)]
    leaf = [side + back[1:], [(0, -0.62), (0, 0.42)], [(0, -0.12), (0.17, 0.06)], [(0, -0.12), (-0.17, 0.06)],
            [(0, 0.14), (0.13, 0.28)], [(0, 0.14), (-0.13, 0.28)]]
    drop = [[(0.36 * math.sin(t) * math.sin(t / 2), 0.5 * math.cos(t)) for t in (2 * math.pi * k / 30 for k in range(31))],
            [(0.11 * math.cos(2 * math.pi * k / 10), -0.17 + 0.11 * math.sin(2 * math.pi * k / 10)) for k in range(11)]]
    return swirl, leaf, drop


def trunk_glyphs(glyphs, vines, pts, radii, trunk_r, trunk_h, h, mids, stage, rng):
    """Big glowing glyphs (a swirl, a leaf and a drop, stacked) on three sides of the trunk, vines winding
    up the trunk, and vines hanging from the main branches."""
    size = trunk_r * 0.9
    width = max(trunk_r * 0.03, 0.12)
    lift = trunk_r * 0.08 + width
    heights = [max(h * 0.13, trunk_r * 1.2 + size * 0.55), h * 0.24, h * 0.34]
    for column in range(3):
        a = 2 * math.pi * column / 3
        for shape, zc in zip(_glyph_shapes(), heights):
            for line in shape:
                points = []
                for u, v in line:
                    c, r = _trunk_at(pts, radii, zc + v * size)
                    ang = a + u * size / r
                    points.append(c + Vector((math.cos(ang), math.sin(ang), 0)) * (r + lift))
                _polyline(glyphs, points, width)

    vine_r = max(trunk_r * 0.045, 0.15)
    for k in range(4):
        b = 2 * math.pi * k / 4 + 0.6
        n = 30
        points = []
        for i in range(n + 1):
            z = trunk_r + (trunk_h * 0.92 - trunk_r) * i / n
            ang = b + 1.3 * math.pi * i / n + 0.15 * math.sin(i * 0.9)
            c, r = _trunk_at(pts, radii, z)
            out = Vector((math.cos(ang), math.sin(ang), 0))
            p = c + out * (r + trunk_r * 0.05)
            points.append(p)
            if i % 3 == 1:
                blob(vines, p + out * vine_r * 1.5, trunk_r * 0.08, rng, squash=(1.3, 1.0, 0.6), subdiv=1, rough=0.2)
        _polyline(vines, points, vine_r, 5)
    if stage >= 2:
        for i, mid in enumerate(mids):
            if i % 2:
                continue
            length = h * 0.14
            points = [mid + Vector((math.sin(j * 0.8) * h * 0.006, math.cos(j * 0.7) * h * 0.006, -length * j / 8))
                      for j in range(9)]
            _polyline(vines, points, vine_r * 0.8, 5)
            for p in points[2::2]:
                blob(vines, p, trunk_r * 0.07, rng, squash=(1.2, 1.0, 0.7), subdiv=1, rough=0.2)


def ancient_base(coll, loc):
    """Hub-sized ground decoration under the Ancient Tree. It never scales with the tree:
    a double glowing rune circle at the roots' edge, crystals, stones, grass and flowers."""
    rng = random.Random(9)
    stones, grass, flowers, glow = (bmesh.new() for _ in range(4))
    r = ANCIENT_ROOT_REACH
    annulus(glow, Vector((0, 0, 0.05)), r + 6.0, r + 4.5, 0.3, 72)
    annulus(glow, Vector((0, 0, 0.05)), r - 3.0, r - 4.0, 0.3, 72)
    for i in range(8):
        a = 2 * math.pi * i / 8 + 0.2
        cone(glow, Vector((math.cos(a) * (r + 1), math.sin(a) * (r + 1), 0)), rng.uniform(4.5, 7.0), 1.5, 5, rng,
             wobble=0.15)
    for _ in range(18):
        a, d = rng.uniform(0, 2 * math.pi), rng.uniform(20, r + 6)
        blob(stones, Vector((math.cos(a) * d, math.sin(a) * d, 0.4)), rng.uniform(1.5, 4.0), rng,
             squash=(1.2, 1.0, 0.6), rough=0.2)
    for _ in range(70):
        a, d = rng.uniform(0, 2 * math.pi), rng.uniform(10, r + 8)
        cone(grass, Vector((math.cos(a) * d, math.sin(a) * d, 0)), rng.uniform(1.2, 2.6), 0.8, 4, rng, wobble=0.08)
    for _ in range(45):
        a, d = rng.uniform(0, 2 * math.pi), rng.uniform(10, r + 8)
        blob(flowers, Vector((math.cos(a) * d, math.sin(a) * d, 0.6)), 0.5, rng, rough=0.1)
    pieces = [("Stones", stones, "Stones"), ("Grass", grass, "Grass"), ("Flowers", flowers, "Flowers"), ("Glow", glow, "Glow")]
    return [finish(f"AncientBase_{name}", bm, mat, coll, loc) for name, bm, mat in pieces]


# ---------------------------------------------------------------------------
# Hex tile pieces (pointy-top: corners along +-Y, which becomes Roblox +-Z)
# ---------------------------------------------------------------------------
TILE_RADIUS = 15.7  # HexSize 16 minus half the seam
TILE_HEIGHT = 1.2


def hex_points(r):
    return [Vector((r * math.cos(math.radians(90 + 60 * i)), r * math.sin(math.radians(90 + 60 * i)), 0)) for i in range(6)]


def tile(coll, loc):
    """Dirt slab with a bevelled top edge, a thin rim ring and a tufts decoration for planted tiles."""
    rng = random.Random(7)
    bm = bmesh.new()
    bevel = 0.6
    rings = [(TILE_RADIUS, 0.0), (TILE_RADIUS, TILE_HEIGHT - bevel * 0.5), (TILE_RADIUS - bevel, TILE_HEIGHT)]
    layers = [[bm.verts.new(p + Vector((0, 0, z))) for p in hex_points(r)] for r, z in rings]
    for lo, hi in zip(layers, layers[1:]):
        for i in range(6):
            j = (i + 1) % 6
            bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    bm.faces.new(list(reversed(layers[0])))
    bm.faces.new(layers[-1])
    slab = finish("HexTile_Slab", bm, "Dirt", coll, loc)

    rim = bmesh.new()
    annulus(rim, Vector((0, 0, 0)), TILE_RADIUS + 0.5, TILE_RADIUS - 0.3, TILE_HEIGHT * 0.9, 6, start_angle=math.radians(90))
    rim_obj = finish("HexTile_Rim", rim, "Rim", coll, loc)

    tufts = bmesh.new()
    for i in range(9):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(4, TILE_RADIUS * 0.8)
        cone(tufts, Vector((math.cos(a) * d, math.sin(a) * d, TILE_HEIGHT)), rng.uniform(0.8, 1.5), 0.5, 4, rng, wobble=0.08)
    for i in range(3):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(6, TILE_RADIUS * 0.75)
        blob(tufts, Vector((math.cos(a) * d, math.sin(a) * d, TILE_HEIGHT + 0.2)), rng.uniform(0.6, 1.0), rng,
             squash=(1.2, 1.0, 0.6), rough=0.2)
    tufts_obj = finish("HexTile_Tufts", tufts, "Grass", coll, loc)

    border = bmesh.new()  # a thin grass border just inside the tile's edge, like the reference
    annulus(border, Vector((0, 0, TILE_HEIGHT - 0.1)), TILE_RADIUS - 0.15, TILE_RADIUS - 1.5, 0.25, 6,
            start_angle=math.radians(90))
    border_obj = finish("HexTile_Border", border, "Grass", coll, loc)
    flowers = bmesh.new()
    for i in range(10):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(3, TILE_RADIUS * 0.75)
        blob(flowers, Vector((math.cos(a) * d, math.sin(a) * d, TILE_HEIGHT + 0.35)), rng.uniform(0.3, 0.45), rng,
             rough=0.1)
    flowers_obj = finish("HexTile_Flowers", flowers, "Flowers", coll, loc)
    return [slab, rim_obj, tufts_obj, border_obj, flowers_obj]


# ---------------------------------------------------------------------------
# The acorn (the giant seed over your head) and the acorn piles of the seed racks
# ---------------------------------------------------------------------------
def acorn_into(nut, cap, m, rng):
    """One acorn, 10 studs tall, standing on the origin of matrix m: an egg-shaped nut narrowing to a
    small tip, a faceted cap with a rim and a short stem."""
    made_nut, made_cap = [], []
    res = bmesh.ops.create_icosphere(nut, subdivisions=2, radius=1.0)
    for v in res["verts"]:
        x, y, z = v.co
        k = 1.0 if z > 0 else 1.0 + 0.45 * z  # narrower toward the bottom
        v.co = Vector((x * 3.2 * k, y * 3.2 * k, z * 3.9 + 4.4))
    jitter(res["verts"], rng, 0.1)
    made_nut += res["verts"]
    made_nut += frustum(nut, Vector((0, 0, 1.0)), Vector((0, 0, 0.0)), 0.6, 0.08, 5, None)
    made_cap += frustum(cap, Vector((0, 0, 6.3)), Vector((0, 0, 7.6)), 3.45, 3.25, 10, rng, wobble=0.08)
    made_cap += blob(cap, Vector((0, 0, 7.5)), 3.3, rng, squash=(1.0, 1.0, 0.5), subdiv=1, rough=0.12)
    made_cap += frustum(cap, Vector((0, 0, 8.8)), Vector((0.35, 0.15, 10.0)), 0.45, 0.28, 5, None)
    bmesh.ops.transform(nut, matrix=m, verts=made_nut)
    bmesh.ops.transform(cap, matrix=m, verts=made_cap)


def egg(bm, center, rx, rz, rng, taper=0.45, subdiv=2, rough=0.03):
    """An egg shape: an icosphere stretched to rx x rz, narrowing toward the bottom."""
    res = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    for v in res["verts"]:
        x, y, z = v.co
        k = 1.0 if z > 0 else 1.0 + taper * z
        v.co = center + Vector((x * rx * k, y * rx * k, z * rz))
    jitter(res["verts"], rng, rx * rough)
    return res["verts"]


# Shop seeds: one per special tree, about the acorn's size (10 studs tall), each hinting at its tree.
def sakura_seed(coll, loc):
    """A deep pink cherry pit with a five-petal blossom on top."""
    rng = random.Random(71)
    pit, petals, heart = bmesh.new(), bmesh.new(), bmesh.new()
    egg(pit, Vector((0, 0, 3.6)), 3.0, 3.6, rng)
    frustum(pit, Vector((0, 0, 6.6)), Vector((0.2, 0, 7.6)), 0.35, 0.25, 5, rng)
    for i in range(5):
        a = 2 * math.pi * i / 5
        d = Vector((math.cos(a), math.sin(a), 0))
        m = (Matrix.Translation(Vector((0, 0, 7.6)) + d * 1.6) @ Matrix.Rotation(a, 4, "Z")
             @ Matrix.Rotation(-0.35, 4, "Y") @ Matrix.Diagonal((1.6, 1.1, 0.3, 1)))
        bmesh.ops.create_icosphere(petals, subdivisions=1, radius=1.0, matrix=m)
    blob(heart, Vector((0, 0, 7.9)), 0.6, rng, subdiv=1, rough=0.1)
    return [finish("SakuraSeed_Pit", pit, "BlossomDeep", coll, loc), finish("SakuraSeed_Petals", petals, "Blossom", coll, loc),
            finish("SakuraSeed_Heart", heart, "Lantern", coll, loc)]


def crystal_seed(coll, loc):
    """A violet gem with three small cyan shards sprouting from its top."""
    rng = random.Random(72)
    gem, shards = bmesh.new(), bmesh.new()
    frustum(gem, Vector((0, 0, 0)), Vector((0, 0, 3.6)), 0.0, 2.9, 6, rng)  # lower point
    frustum(gem, Vector((0, 0, 3.6)), Vector((0, 0, 5.4)), 2.9, 2.4, 6, rng)  # girdle
    frustum(gem, Vector((0, 0, 5.4)), Vector((0, 0, 7.2)), 2.4, 1.2, 6, rng)  # crown
    for i, (a, tilt, length) in enumerate(((0.3, 0.0, 3.6), (2.4, 0.6, 3.0), (4.4, 0.55, 2.6))):
        d = Vector((math.cos(a) * math.sin(tilt), math.sin(a) * math.sin(tilt), math.cos(tilt)))
        shard(shards, Vector((0, 0, 6.6)) + d * 0.3, d, length, length * 0.22, rng)
    return [finish("CrystalSeed_Gem", gem, "CrystalViolet", coll, loc), finish("CrystalSeed_Shards", shards, "Crystal", coll, loc)]


def redwood_seed(coll, loc):
    """A small red-brown redwood cone of overlapping scales, with a sprig of needles on top."""
    rng = random.Random(73)
    scales, sprig = bmesh.new(), bmesh.new()
    egg(scales, Vector((0, 0, 3.8)), 2.2, 3.6, rng, taper=0.25, subdiv=1)  # the core under the scales
    for row in range(4):
        z = 1.4 + row * 1.6
        r = 2.6 * math.sin(math.pi * (0.2 + 0.6 * row / 3))
        for i in range(6):
            a = 2 * math.pi * i / 6 + row * 0.52
            d = Vector((math.cos(a), math.sin(a), 0))
            # a flat four-sided scale pointing out and down, like a tile on the cone
            m = (Matrix.Translation(Vector((0, 0, z)) + d * r) @ Matrix.Rotation(a, 4, "Z")
                 @ Matrix.Rotation(math.pi / 2 + 0.6, 4, "Y") @ Matrix.Diagonal((1.0, 1.3, 1.0, 1)))
            bmesh.ops.create_cone(scales, cap_ends=True, segments=4, radius1=1.3, radius2=0.0, depth=0.9, matrix=m)
    for i in range(5):
        a = 2 * math.pi * i / 5 + 0.3
        tilt = 0.0 if i == 0 else 0.7
        d = Vector((math.cos(a) * math.sin(tilt), math.sin(a) * math.sin(tilt), math.cos(tilt)))
        frustum(sprig, Vector((0, 0, 7.0)), Vector((0, 0, 7.0)) + d * 2.6, 0.45, 0.0, 4, rng)
    return [finish("RedwoodSeed_Cone", scales, "Redwood", coll, loc), finish("RedwoodSeed_Sprig", sprig, "RedwoodNeedlesB", coll, loc)]


def palm_seed(coll, loc):
    """A sprouting coconut: a faceted brown husk with three dark eyes and two green leaves on top."""
    rng = random.Random(74)
    husk, eyes, leaves = bmesh.new(), bmesh.new(), bmesh.new()
    egg(husk, Vector((0, 0, 3.7)), 3.4, 3.7, rng, taper=0.15, subdiv=1, rough=0.06)
    for i in range(3):
        a = 2 * math.pi * i / 3
        blob(eyes, Vector((math.cos(a) * 0.9, math.sin(a) * 0.9, 7.1)), 0.45, rng, subdiv=1, rough=0.05)
    for i, a in enumerate((0.4, 0.4 + math.pi)):
        frond(leaves, Vector((0, 0, 7.0)), a, 4.4, 1.3, rng, lift=1.2, droop=1.8)
    return [finish("PalmSeed_Husk", husk, "Coconut", coll, loc), finish("PalmSeed_Eyes", eyes, "AcornCap", coll, loc),
            finish("PalmSeed_Leaves", leaves, "PalmFrondsB", coll, loc)]


def acorn(coll, loc):
    rng = random.Random(17)
    nut, cap = bmesh.new(), bmesh.new()
    acorn_into(nut, cap, Matrix.Identity(4), rng)
    return [finish("Acorn_Nut", nut, "Acorn", coll, loc), finish("Acorn_Cap", cap, "AcornCap", coll, loc)]


def acorn_pile(coll, loc):
    """A seed rack: a heap of giant acorns on a mound, about 13 studs across and 9 tall."""
    rng = random.Random(19)
    nuts, caps, mound = bmesh.new(), bmesh.new(), bmesh.new()
    blob(mound, Vector((0, 0, 0.0)), 7.0, rng, squash=(1.0, 1.0, 0.14), subdiv=1, rough=0.12)
    spots = [(math.cos(a) * 4.6, math.sin(a) * 4.6, 1.4, 1.35) for a in (2 * math.pi * i / 7 + 0.3 for i in range(7))]
    spots += [(math.cos(a) * 2.0, math.sin(a) * 2.0, 3.6, 0.9) for a in (2 * math.pi * i / 3 + 1.0 for i in range(3))]
    spots += [(0.2, -0.3, 5.8, 0.15)]
    for x, y, z, tilt in spots:
        m = (Matrix.Translation((x, y, z)) @ Matrix.Rotation(rng.uniform(0, 2 * math.pi), 4, "Z")
             @ Matrix.Rotation(tilt + rng.uniform(-0.15, 0.15), 4, "X") @ Matrix.Diagonal((0.5, 0.5, 0.5, 1.0))
             @ Matrix.Translation((0, 0, -4.4)))  # each acorn turns around its own middle
        acorn_into(nuts, caps, m, rng)
    return [finish("AcornPile_Nuts", nuts, "Acorn", coll, loc), finish("AcornPile_Caps", caps, "AcornCap", coll, loc),
            finish("AcornPile_Mound", mound, "Dirt", coll, loc)]


# ---------------------------------------------------------------------------
# The lobby around the Ancient Tree (docs/plans/M6b.md). Every piece is centered on the hub center.
# The trails run out at 0, 60, ... 300 degrees, a pattern that stays the same when mirrored, so
# Blender's Y axis can become either Roblox axis.
# ---------------------------------------------------------------------------
TRAILS = [math.radians(60 * k) for k in range(6)]
GARDEN_R = 86.0  # the low stone wall around the root garden
PLAZA_IN, PLAZA_OUT = 89.0, 146.0
FENCE_R = 150.0  # ring-7 tiles come within ~154 studs of the center between the trails
PATH_START, PATH_END, PATH_WIDTH = 144.0, 440.0, 32.0  # 32: covers the walkway hexes' zig-zag (their corners reach 16 out)
HEX_STEP = 16 * math.sqrt(3)  # hex centers along a trail are this far apart


def _near_trail(a, half_width, r):
    """Is angle a within half_width studs of a trail, at radius r?"""
    for t in TRAILS:
        d = (a - t + math.pi) % (2 * math.pi) - math.pi
        if abs(d) * r < half_width:
            return True
    return False


def lobby_plaza(coll, loc):
    """The round stone plaza: rings of slightly irregular pavers in two shades, with a curb on the outside."""
    rng = random.Random(29)
    light, dark = bmesh.new(), bmesh.new()
    gap, row = 0.35, 6.5
    r = PLAZA_IN
    while r < PLAZA_OUT - 0.5:
        r2 = min(r + row, PLAZA_OUT)
        rm = (r + r2) / 2
        n = max(8, round(2 * math.pi * rm / rng.uniform(5.5, 7.0)))
        off = rng.uniform(0, 1)
        ga = gap / rm / 2
        for i in range(n):
            a0 = 2 * math.pi * (i + off) / n + ga
            a1 = 2 * math.pi * (i + 1 + off) / n - ga
            corners = [(math.cos(a) * rr, math.sin(a) * rr) for a, rr in
                       ((a0, r + gap / 2), (a1, r + gap / 2), (a1, r2 - gap / 2), (a0, r2 - gap / 2))]
            prism(dark if rng.random() < 0.3 else light, corners, 0.0, rng.uniform(0.22, 0.3))
        r = r2
    annulus(dark, Vector((0, 0, 0)), PLAZA_OUT + 1.6, PLAZA_OUT, 0.45, 120)
    return [finish("LobbyPlaza_Stone", light, "Paver", coll, loc), finish("LobbyPlaza_StoneDark", dark, "PaverDark", coll, loc)]


def _lantern(wood, glow, base, top_z, rng):
    box(glow, base + Vector((0, 0, top_z + 0.85)), (1.1, 1.1, 1.5))
    box(wood, base + Vector((0, 0, top_z + 0.05)), (1.6, 1.6, 0.3))
    cone(wood, base + Vector((0, 0, top_z + 1.6)), 1.0, 1.25, 4, rng)


def lobby_fence(coll, loc):
    """Wooden fence sections between stone pillars with lanterns, around the plaza, open at every trail."""
    rng = random.Random(31)
    wood, stone, glow = bmesh.new(), bmesh.new(), bmesh.new()
    gate = 15.0 / FENCE_R  # half the opening at each trail, in radians
    for t in TRAILS:
        a0, a1 = t + gate, t + math.radians(60) - gate
        sections = max(1, round((a1 - a0) * FENCE_R / 16))
        for s in range(sections + 1):
            a = a0 + (a1 - a0) * s / sections
            p = Vector((math.cos(a) * FENCE_R, math.sin(a) * FENCE_R, 0))
            tall = s in (0, sections)  # the pillars beside a trail opening are taller
            height = 6.5 if tall else 4.2
            box(stone, p + Vector((0, 0, height / 2)), (2.2, 2.2, height), a)
            box(stone, p + Vector((0, 0, height + 0.25)), (2.8, 2.8, 0.5), a)
            _lantern(wood, glow, p, height + 0.5, rng)
            if s < sections:
                b = a0 + (a1 - a0) * (s + 1) / sections
                q = Vector((math.cos(b) * FENCE_R, math.sin(b) * FENCE_R, 0))
                mid = (p + q) / 2
                along = math.atan2(q.y - p.y, q.x - p.x)
                length = (q - p).length - 2.2
                for z in (1.5, 3.0):
                    box(wood, mid + Vector((0, 0, z)), (length, 0.4, 0.55), along)
                box(wood, mid + Vector((0, 0, 1.8)), (0.6, 0.6, 3.6), along)
    return [box_uv(finish("LobbyFence_Wood", wood, "Wood", coll, loc), 6.0),
            box_uv(finish("LobbyFence_Stone", stone, "Stones", coll, loc), 6.0),
            finish("LobbyFence_Glow", glow, "Lantern", coll, loc)]


def lobby_garden(coll, loc):
    """The root garden's edge: a low wall of irregular stones (open at the trails) with flower beds and
    bushes inside it, around the glowing rune circle."""
    rng = random.Random(37)
    stone, flowers, flowers_b, bush = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    a = 0.0
    while a < 2 * math.pi:
        step = rng.uniform(3.0, 4.5) / GARDEN_R
        mid = a + step / 2
        if not _near_trail(mid, 11.0, GARDEN_R):
            p = Vector((math.cos(mid) * GARDEN_R, math.sin(mid) * GARDEN_R, 0))
            hgt = rng.uniform(1.1, 1.7)
            v = box(stone, p + Vector((0, 0, hgt / 2)), (step * GARDEN_R - 0.3, 2.4, hgt), mid + math.pi / 2)
            jitter(v, rng, 0.12)
        a += step
    for _ in range(260):
        ang, d = rng.uniform(0, 2 * math.pi), rng.uniform(79.5, 84.5)
        if _near_trail(ang, 10.0, d):
            continue
        target = flowers if rng.random() < 0.55 else flowers_b
        blob(target, Vector((math.cos(ang) * d, math.sin(ang) * d, rng.uniform(0.5, 1.1))), rng.uniform(0.35, 0.55), rng,
             rough=0.1)
    for _ in range(40):
        ang, d = rng.uniform(0, 2 * math.pi), rng.uniform(80, 84)
        if _near_trail(ang, 12.0, d):
            continue
        blob(bush, Vector((math.cos(ang) * d, math.sin(ang) * d, 0.8)), rng.uniform(1.2, 2.0), rng,
             squash=(1.0, 1.0, 0.8), rough=0.2)
    return [box_uv(finish("LobbyGarden_Stone", stone, "Stones", coll, loc), 6.0),
            finish("LobbyGarden_Flowers", flowers, "Flowers", coll, loc),
            finish("LobbyGarden_FlowersB", flowers_b, "FlowersB", coll, loc), finish("LobbyGarden_Bush", bush, "Bush", coll, loc)]


def lobby_path(coll, loc):
    """One stone trail along +X from the plaza to the forest edge, with lantern posts on alternating sides.
    The game places six copies, one along each walkway."""
    rng = random.Random(41)
    light, dark, wood, glow = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    g = 0.18
    x = PATH_START
    while x < PATH_END:
        length = rng.uniform(3.5, 5.0)
        y = -PATH_WIDTH / 2
        while y < PATH_WIDTH / 2 - 0.5:
            w = min(rng.uniform(3.0, 5.0), PATH_WIDTH / 2 - y)
            corners = [(x + g, y + g), (x + length - g, y + g), (x + length - g, y + w - g), (x + g, y + w - g)]
            prism(dark if rng.random() < 0.3 else light, corners, 0.0, rng.uniform(0.22, 0.3))
            y += w
        x += length
    for n in range(6, 17):
        d = n * HEX_STEP
        if d < PATH_START + 8 or d > PATH_END - 4:
            continue
        side = 1 if n % 2 else -1
        base = Vector((d, side * (PATH_WIDTH / 2 - 1.5), 0))  # on the road's edge: past it are plots
        box(wood, base + Vector((0, 0, 3.5)), (0.8, 0.8, 7.0))
        _lantern(wood, glow, base, 7.0, rng)
    return [finish("LobbyPath_Stone", light, "Paver", coll, loc), finish("LobbyPath_StoneDark", dark, "PaverDark", coll, loc),
            finish("LobbyPath_Wood", wood, "Wood", coll, loc), finish("LobbyPath_Glow", glow, "Lantern", coll, loc)]


def _inside_plots(p, margin):
    """Is point p within margin studs of (or inside) a ring-7 or ring-8 hex (the first plots)? Pointy-top hexes: the distance to a hex
    is measured against its three pairs of edges (normals at 0, 60 and 120 degrees)."""
    inner = HEX * math.sqrt(3) / 2
    for q, r, _ in _hexes(8, 7):
        c = _hex_center(q, r)
        dx, dy = p.x - c.x, p.y - c.y
        reach = max(abs(dx * math.cos(a) + dy * math.sin(a)) for a in (0.0, math.pi / 3, 2 * math.pi / 3))
        if reach < inner + margin:
            return True
    return False


def fence_decor(coll, loc):
    """Bushes and rocks in the grass ring between the round fence and the first (hexagonal) ring of plots,
    clear of the trails, so the ring looks planted instead of empty. Not collidable in the game."""
    rng = random.Random(77)
    bush, rocks = bmesh.new(), bmesh.new()
    placed = []
    # Bushes first, then rocks in the spaces left between them.
    for is_rock, tries in ((False, 20000), (True, 12000)):
        for _ in range(tries):
            a = rng.uniform(0, 2 * math.pi)
            size = rng.uniform(1.0, 2.0) if is_rock else rng.uniform(2.4, 4.6)
            r = rng.uniform(FENCE_R + 1.5 + size, FENCE_R + 30)
            p = Vector((math.cos(a) * r, math.sin(a) * r, 0))
            if _near_trail(a, PATH_WIDTH / 2 + 3 + size, r) or _inside_plots(p, size * 0.5):
                continue
            if any((p - q).length < (size + s) * 0.7 for q, s in placed):
                continue
            placed.append((p, size))
            if is_rock:
                blob(rocks, p + Vector((0, 0, size * 0.3)), size, rng, squash=(1.2, 1.0, 0.7), rough=0.2)
            else:
                blob(bush, p + Vector((0, 0, size * 0.55)), size, rng, squash=(1.0, 1.0, 0.8))
    return [finish("FenceDecor_Bush", bush, "Bush", coll, loc), finish("FenceDecor_Rocks", rocks, "Stones", coll, loc)]


SHOP_RING_AHEAD, SHOP_RING_R = 13.0, 6.5  # the shop ring's center (in front of the altar) and radius


def _log(bm, a, b, r, rng):
    """One log: a slightly wobbly 6-sided cylinder from a to b."""
    frustum(bm, a, b, r, r * 0.95, 6, rng, wobble=r * 0.06)


def ranger_station(coll, loc):
    """The upgrade shop (2026-10-07, replaces the stone altar): a log-cabin ranger station facing +X. A plank
    deck, log walls on three sides, a counter across the open front, a green pitched roof on two front posts,
    shelves of acorn sacks and crates behind, a lantern, a plank sign over the counter (the game writes
    UPGRADES on it) and the glowing ring in front: stepping into it opens the shop. A shopkeeper stands behind
    the counter, at about x = -1 (the map script places them)."""
    rng = random.Random(44)
    logs, planks, roof, sacks, nuts, paper, lamp, ring = (bmesh.new() for _ in range(8))
    back, front, half = -7.0, 4.6, 9.5  # deck from back to front, half its width
    # the deck: planks running across the front, on two sleeper logs
    for i in range(7):
        x = back + 0.2 + i * (front - back) / 7
        box(planks, Vector((x + 0.8, 0, 0.45)), (1.55, half * 2, 0.3))
    for y in (-half + 1, half - 1):
        _log(logs, Vector((back, y, 0.15)), Vector((front, y, 0.15)), 0.3, rng)
    # log walls: the back wall and the two sides, stacked logs with corner posts
    wall_h, r = 9.0, 0.45
    for k in range(int(wall_h / (r * 2))):
        z = 0.9 + r + k * r * 2
        _log(logs, Vector((back, -half, z)), Vector((back, half, z)), r, rng)
        for y in (-half, half):
            _log(logs, Vector((back, y, z)), Vector((back + 6.5, y, z)), r, rng)
    for x, y in ((back, -half), (back, half), (back + 6.5, -half), (back + 6.5, half)):
        _log(logs, Vector((x, y, 0.6)), Vector((x, y, wall_h + 1.2)), 0.55, rng)
    # front posts holding the roof
    for y in (-half + 0.4, half - 0.4):
        _log(logs, Vector((front + 0.8, y, 0.6)), Vector((front + 0.8, y, 10.2)), 0.5, rng)
    # the counter across the front: a plank front, a thick top and a lip
    box(planks, Vector((front - 0.6, 0, 1.75)), (1.2, half * 2 - 2.4, 2.3))  # waist high, so the shopkeeper shows
    box(planks, Vector((front - 0.4, 0, 3.05)), (2.2, half * 2 - 1.8, 0.35))
    # the roof: two slabs meeting at a ridge along Y, overhanging the front posts and the sides
    ridge = Vector((back + 4.8, 0, 14.2))
    for eave in (Vector((back - 1.2, 0, 10.0)), Vector((front + 2.2, 0, 10.0))):
        run = eave - ridge
        slope = math.atan2(-run.z, run.x)
        m = (Matrix.Translation((ridge + eave) / 2) @ Matrix.Rotation(slope, 4, "Y")
             @ Matrix.Diagonal((run.length + 0.5, half * 2 + 2.4, 0.5, 1)))
        bmesh.ops.create_cube(roof, size=1.0, matrix=m)
    _log(logs, ridge + Vector((0, -half - 1.3, 0.35)), ridge + Vector((0, half + 1.3, 0.35)), 0.4, rng)
    # gable ends: triangles of planks closing the roof over the side walls
    for y in (-half, half):
        prism(planks, [(back, y - 0.2), (back + 6.5, y - 0.2), (back + 6.5, y + 0.2), (back, y + 0.2)], wall_h + 1.0,
              wall_h + 1.4)
    # shelves on the back wall with acorn sacks and crates
    for z in (4.0, 6.8):
        box(planks, Vector((back + 0.9, 0, z)), (1.3, half * 2 - 2.0, 0.25))
    for i, y in enumerate((-6.0, -3.0, 3.0, 6.0)):
        base = Vector((back + 0.9, y, 4.15 if i % 2 == 0 else 6.95))
        blob(sacks, base + Vector((0, 0, 0.9)), 0.9, rng, squash=(0.9, 0.9, 1.1), subdiv=1, rough=0.12)
        acorn_into(nuts, logs, Matrix.Translation(base + Vector((0.2, 0.3, 1.9))) @ Matrix.Diagonal((0.12, 0.12, 0.12, 1)), rng)
    for y in (-1.0, 1.0):  # crates on the floor at the back
        box(planks, Vector((back + 1.3, y, 1.6)), (1.6, 1.6, 1.4))
    # on the counter: a sack of acorns, a rolled-up map and a lantern
    blob(sacks, Vector((front - 0.3, -5.5, 4.0)), 0.8, rng, squash=(1, 1, 1.1), subdiv=1, rough=0.12)
    for j in range(3):
        acorn_into(nuts, logs, Matrix.Translation(Vector((front - 0.2 + 0.25 * j, -5.3 + 0.3 * j, 4.8)))
                   @ Matrix.Diagonal((0.12, 0.12, 0.12, 1)), rng)
    frustum(paper, Vector((front - 0.4, 3.0, 3.45)), Vector((front - 0.4, 5.0, 3.45)), 0.3, 0.3, 8, rng)
    box(logs, Vector((front - 0.3, 0.5, 3.45)), (0.6, 0.6, 0.4))
    blob(lamp, Vector((front - 0.3, 0.5, 4.05)), 0.45, rng, squash=(1, 1, 1.3), subdiv=1, rough=0.05)
    # the sign hanging over the counter from the roof's front edge
    box(planks, Vector((front + 1.6, 0, 11.2)), (0.3, 8.5, 2.0))
    # the glowing ring in front of the counter: stepping into it opens the shop
    annulus(ring, Vector((SHOP_RING_AHEAD, 0, 0.05)), SHOP_RING_R, SHOP_RING_R - 0.7, 0.2, 48)
    return [finish("RangerStation_Logs", logs, "Wood", coll, loc), finish("RangerStation_Planks", planks, "Wood", coll, loc),
            finish("RangerStation_Roof", roof, "Needles", coll, loc), finish("RangerStation_Sacks", sacks, "Rope", coll, loc),
            finish("RangerStation_Nuts", nuts, "Acorn", coll, loc), finish("RangerStation_Paper", paper, "Paper", coll, loc),
            finish("RangerStation_Lamp", lamp, "Lantern", coll, loc), finish("RangerStation_Glow", ring, "Glow", coll, loc)]


DISPENSER_SLIDE_R = 4.7  # the spiral slide's radius around the tower
DISPENSER_SLIDE_TOP, DISPENSER_SLIDE_BOTTOM = 15.2, 4.4  # its height at the hopper and at the basket
DISPENSER_SLIDE_TURNS = 1.25
DISPENSER_BASKET_X = 6.1  # the basket stands in front (+X), under the slide's end
# The glow ring: shifted toward the basket so it clears the garden wall behind the tower (the map scales the
# dispenser 1.5x: radius 11 studs, its center 2 studs toward the basket).
DISPENSER_RING_R, DISPENSER_RING_X = 7.33, 1.33


def _oriented_box(bm, a, b, width, height, lift=0.0):
    """A plank from a to b: `width` across, `height` thick, raised `lift` along its own up."""
    axis = b - a
    length = axis.length
    axis = axis.normalized()
    side = axis.cross(Vector((0, 0, 1))).normalized()
    up = side.cross(axis).normalized()
    c = (a + b) / 2 + up * lift
    m = Matrix(((axis.x, side.x, up.x, c.x), (axis.y, side.y, up.y, c.y), (axis.z, side.z, up.z, c.z), (0, 0, 0, 1)))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m @ Matrix.Diagonal((length, width, height, 1)))


def acorn_dispenser(coll, loc):
    """The acorn dispenser (2026-10-07, replaces the acorn piles as the seed racks): a wooden hopper heaped with
    acorns on four log legs, a spiral slide winding down around the legs to a basket at hand height in front
    (+X), and a lantern on top so it's easy to spot from the forest. Tiny markers along the slide (Slide01..)
    give the game the path acorns roll down when someone grabs; the map script hides them. The origin is the
    base's center: the server's grab reach is measured from it."""
    rng = random.Random(23)
    wood, logs, bands, nuts, caps, basket, roof, lamp = (bmesh.new() for _ in range(8))
    # a round stone-and-earth plinth
    frustum(logs, Vector((0, 0, 0)), Vector((0, 0, 0.6)), 3.8, 3.5, 10, rng, wobble=0.1)
    # four log legs up to the hopper, with cross braces
    for x, y in ((-2.2, -2.2), (-2.2, 2.2), (2.2, -2.2), (2.2, 2.2)):
        _log(logs, Vector((x * 1.15, y * 1.15, 0.4)), Vector((x, y, 16.4)), 0.42, rng)
    for z in (6.0, 11.0):
        _log(logs, Vector((-2.4, -2.4, z)), Vector((2.4, -2.4, z)), 0.22, rng)
        _log(logs, Vector((-2.4, 2.4, z)), Vector((2.4, 2.4, z)), 0.22, rng)
    # the hopper: a wide barrel with dark hoops, open at the top and heaped with acorns
    frustum(wood, Vector((0, 0, 16.0)), Vector((0, 0, 22.0)), 3.3, 4.2, 12, rng, wobble=0.08)
    for z in (16.6, 19.0, 21.4):
        frustum(bands, Vector((0, 0, z - 0.18)), Vector((0, 0, z + 0.18)), 3.45 + (z - 16) * 0.15,
                3.5 + (z - 16) * 0.15, 12, rng)
    for k in range(9):
        a = 2 * math.pi * k / 9 + rng.uniform(-0.2, 0.2)
        d = 0 if k == 0 else rng.uniform(1.4, 2.8)
        base = Vector((math.cos(a) * d, math.sin(a) * d, 21.4 + (0.9 if k == 0 else rng.uniform(0, 0.5))))
        m = (Matrix.Translation(base) @ Matrix.Rotation(rng.uniform(0, 6.3), 4, "Z")
             @ Matrix.Rotation(rng.uniform(-0.5, 0.5), 4, "X") @ Matrix.Diagonal((0.16, 0.16, 0.16, 1)))
        acorn_into(nuts, caps, m, rng)
    # The roof on four posts over the hopper, with a lantern on top, was removed on 2026-10-08 (the user's call). Its
    # pieces are still made, into a throwaway mesh, so the random numbers for everything after stay the same.
    unused = bmesh.new()
    for x, y in ((-3.6, -3.6), (-3.6, 3.6), (3.6, -3.6), (3.6, 3.6)):
        _log(unused, Vector((x, y, 21.6)), Vector((x, y, 25.4)), 0.2, rng)
    cone(roof, Vector((0, 0, 25.2)), 3.4, 5.6, 4, rng)
    bmesh.ops.rotate(roof, verts=roof.verts, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(math.pi / 4, 3, "Z"))
    _log(unused, Vector((0, 0, 28.4)), Vector((0, 0, 31.0)), 0.15, rng)
    blob(lamp, Vector((0, 0, 31.6)), 0.8, rng, squash=(1, 1, 1.3), subdiv=1, rough=0.04)
    box(unused, Vector((0, 0, 32.5)), (1.0, 1.0, 0.2))
    for bm in (unused, roof, lamp):
        bm.free()
    # the spiral slide: an open trough winding down from the hopper to the front, ending over the basket
    steps = 30
    total = DISPENSER_SLIDE_TURNS * 2 * math.pi
    path = []
    for i in range(steps + 1):
        t = i / steps
        ang = total * (1 - t)  # ends at angle 0: the front (+X)
        z = DISPENSER_SLIDE_TOP + (DISPENSER_SLIDE_BOTTOM - DISPENSER_SLIDE_TOP) * t
        path.append(Vector((math.cos(ang) * DISPENSER_SLIDE_R, math.sin(ang) * DISPENSER_SLIDE_R, z)))
    path.append(Vector((DISPENSER_BASKET_X - 0.2, 0, DISPENSER_SLIDE_BOTTOM - 0.4)))  # the lip over the basket
    for a, b in zip(path, path[1:]):
        _oriented_box(wood, a, b + (b - a).normalized() * 0.05, 1.5, 0.18)
        side = (b - a).normalized().cross(Vector((0, 0, 1))).normalized()
        for s in (-0.75, 0.75):
            _oriented_box(wood, a + side * s, b + side * s, 0.15, 0.5, lift=0.2)
    # the spout from the hopper onto the slide's top, and posts holding the slide up
    first = path[0]
    _oriented_box(wood, first * (3.4 / DISPENSER_SLIDE_R) + Vector((0, 0, 0.6)), first, 1.4, 0.18)
    for i in range(4, steps, 7):
        p = path[i]
        _log(logs, Vector((p.x, p.y, 0.3)), p - Vector((0, 0, 0.25)), 0.16, rng)
    # the basket at the slide's foot, on a stump, with a few acorns in it
    _log(logs, Vector((DISPENSER_BASKET_X, 0, 0.3)), Vector((DISPENSER_BASKET_X, 0, 2.2)), 0.9, rng)
    frustum(basket, Vector((DISPENSER_BASKET_X, 0, 2.2)), Vector((DISPENSER_BASKET_X, 0, 3.6)), 1.1, 1.6, 10, rng)
    for k in range(3):
        a = 2 * math.pi * k / 3
        m = (Matrix.Translation(Vector((DISPENSER_BASKET_X + math.cos(a) * 0.6, math.sin(a) * 0.6, 3.0)))
             @ Matrix.Rotation(rng.uniform(0, 6.3), 4, "Z") @ Matrix.Diagonal((0.1, 0.1, 0.1, 1)))
        acorn_into(nuts, caps, m, rng)
    # UVs on every piece so the Wood material tiles on them in Roblox (2026-10-08, the user's call: all wood).
    pieces = [box_uv(finish("AcornDispenser_Wood", wood, "Wood", coll, loc), 6.0),
              box_uv(finish("AcornDispenser_Logs", logs, "Wood", coll, loc), 6.0),
              box_uv(finish("AcornDispenser_Bands", bands, "Metal", coll, loc), 6.0),
              box_uv(finish("AcornDispenser_Nuts", nuts, "Acorn", coll, loc), 3.0),
              box_uv(finish("AcornDispenser_Caps", caps, "AcornCap", coll, loc), 3.0),
              box_uv(finish("AcornDispenser_Basket", basket, "Rope", coll, loc), 6.0)]
    # a glowing ring on the ground around the tower and basket, like the shop's (the user's ask, 2026-10-08)
    ring = bmesh.new()
    annulus(ring, Vector((DISPENSER_RING_X, 0, 0.05)), DISPENSER_RING_R, DISPENSER_RING_R - 0.62, 0.2, 64)
    pieces.append(finish("AcornDispenser_Glow", ring, "Glow", coll, loc))
    # markers along the slide, 1 stud above it (where a rolling acorn's center is), every third point and the lip
    marks = path[::3] + [path[-1]]
    for i, p in enumerate(marks):
        bm = bmesh.new()
        box(bm, p + Vector((0, 0, 0.9)), (0.1, 0.1, 0.1))
        pieces.append(finish(f"AcornDispenser_Slide{i + 1:02d}", bm, "Glow", coll, loc))
    return pieces


def shop_altar(coll, loc):
    """The shop: a stepped stone altar facing +X with a glowing leaf glyph on its back tablet, a floating
    crystal above it, and planters of crystals on both sides."""
    rng = random.Random(43)
    stone, glow, wood, crystal, crystal_b = (bmesh.new() for _ in range(5))
    box(stone, Vector((0, 0, 0.3)), (12, 16, 0.6))
    box(stone, Vector((-0.5, 0, 0.9)), (9, 12, 0.6))
    box(stone, Vector((-0.5, 0, 2.95)), (5, 7, 3.5))
    box(stone, Vector((-0.5, 0, 4.9)), (6, 8, 0.5))
    box(stone, Vector((-3.6, 0, 5.2)), (1.4, 7.5, 9.2))
    for line in _glyph_shapes()[1]:  # the leaf glyph
        _polyline(glow, [Vector((-2.8, u * 4.4, 6.9 + v * 4.4)) for u, v in line], 0.18)
    blob(glow, Vector((-0.5, 0, 7.2)), 0.9, rng, squash=(0.7, 0.7, 1.5), subdiv=1, rough=0.05)
    for side, target in ((1, crystal), (-1, crystal_b)):
        c = Vector((1.5, side * 6.4, 0.6))
        box(wood, c + Vector((0, 0, 0.9)), (3.2, 3.2, 1.8))
        for k in range(3):
            o = Vector((rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8), 1.8))
            tip = c + o + Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), rng.uniform(2.5, 4.0)))
            frustum(target, c + o, tip, rng.uniform(0.5, 0.8), 0.05, 5, None)
    # the glowing ring in front of the altar: stepping into it opens the shop
    annulus(glow, Vector((SHOP_RING_AHEAD, 0, 0.05)), SHOP_RING_R, SHOP_RING_R - 0.7, 0.2, 48)
    return [finish("ShopAltar_Stone", stone, "Stones", coll, loc), finish("ShopAltar_Glow", glow, "Glow", coll, loc),
            finish("ShopAltar_Wood", wood, "Wood", coll, loc), finish("ShopAltar_Crystal", crystal, "Crystal", coll, loc),
            finish("ShopAltar_CrystalB", crystal_b, "CrystalB", coll, loc)]


SEED_STALL_RING_AHEAD, SEED_STALL_RING_R = 9.0, 5.0  # the seed stall's ring, in front of its counter
SEED_STALL_CRATES = (-4.2, -2.1, 0.0, 2.1, 4.2)  # crate centers along the counter (one per seed)


def seed_stall(coll, loc):
    """The seed shop (docs/plans/SeedShop.md): a wooden market stand facing +X with a striped awning, five
    open crates on the counter (the game puts a seed of each kind in them) and a glowing ring in front."""
    wood, crate, awning, stripe, glow = (bmesh.new() for _ in range(5))
    # counter, back wall and posts
    box(wood, Vector((0.4, 0, 1.6)), (3.6, 11, 3.2))
    box(wood, Vector((2.3, 0, 3.3)), (0.5, 11.6, 0.3))  # the counter's front lip
    box(wood, Vector((-2.4, 0, 4.4)), (0.4, 11, 5.6))
    for x, h in ((2.6, 7.2), (-2.4, 8.8)):
        for y in (-5.6, 5.6):
            box(wood, Vector((x, y, h / 2)), (0.6, 0.6, h))
    # crates on the counter: a floor and four low sides each
    for y in SEED_STALL_CRATES:
        c = Vector((0.6, y, 3.3))
        box(crate, c, (1.9, 1.9, 0.2))
        for dx, dy, sx, sy in ((0.85, 0, 0.2, 1.9), (-0.85, 0, 0.2, 1.9), (0, 0.85, 1.9, 0.2), (0, -0.85, 1.9, 0.2)):
            box(crate, c + Vector((dx, dy, 0.45)), (sx, sy, 0.9))
    # the awning: slanted stripes from the back wall down over the front posts, then a flap hanging down
    back, front = Vector((-2.8, 0, 9.0)), Vector((3.6, 0, 7.0))
    run = front - back
    slope = math.atan2(-run.z, run.x)
    stripes = 6
    width = 12.6 / stripes
    for i in range(stripes):
        y = -6.3 + width * (i + 0.5)
        m = (Matrix.Translation((back + front) / 2 + Vector((0, y, 0))) @ Matrix.Rotation(slope, 4, "Y")
             @ Matrix.Diagonal((run.length + 0.4, width, 0.25, 1)))
        target = awning if i % 2 == 0 else stripe
        bmesh.ops.create_cube(target, size=1.0, matrix=m)
        box(target, front + Vector((0.15, y, -0.5)), (0.2, width, 1.0))  # the flap
    # the glowing ring in front of the counter: stepping into it opens the seed shop
    annulus(glow, Vector((SEED_STALL_RING_AHEAD, 0, 0.05)), SEED_STALL_RING_R, SEED_STALL_RING_R - 0.6, 0.2, 48)
    return [finish("SeedStall_Wood", wood, "Wood", coll, loc), finish("SeedStall_Crates", crate, "Rope", coll, loc),
            finish("SeedStall_Awning", awning, "Blossom", coll, loc), finish("SeedStall_Stripe", stripe, "Paper", coll, loc),
            finish("SeedStall_Glow", glow, "Glow", coll, loc)]


# ---------------------------------------------------------------------------
# Training stations. Each has pieces the game recolors per tier (Frame, Plates, Glow), so the 1x to 25x
# stations share one model. Origin: the station's center on the ground; the bench runs along Y.
# ---------------------------------------------------------------------------
def bench_press(coll, loc):
    rng = random.Random(47)
    frame, pad, bar, plates, glow = (bmesh.new() for _ in range(5))
    for x in (-0.8, 0.8):
        for y in (-2.2, 2.2):
            box(frame, Vector((x, y, 0.5)), (0.35, 0.35, 1.0))
    box(frame, Vector((0, 0, 1.05)), (1.9, 5.2, 0.25))
    for x in (-1.55, 1.55):
        box(frame, Vector((x, -2.0, 2.2)), (0.4, 0.4, 4.4))
        box(frame, Vector((x, -2.0, 0.15)), (0.9, 1.8, 0.3))
        box(frame, Vector((x, -1.75, 3.9)), (0.4, 0.6, 0.25))  # the hook the bar rests on
    box(pad, Vector((0, 0.3, 1.45)), (2.1, 4.6, 0.55))
    box(pad, Vector((0, -2.0, 1.55)), (1.6, 1.2, 0.5))
    frustum(bar, Vector((-3.6, -1.75, 4.25)), Vector((3.6, -1.75, 4.25)), 0.16, 0.16, 6, None)
    for x in (-1, 1):
        frustum(plates, Vector((x * 2.6, -1.75, 4.25)), Vector((x * 3.1, -1.75, 4.25)), 1.25, 1.25, 8, None)
        frustum(plates, Vector((x * 3.15, -1.75, 4.25)), Vector((x * 3.4, -1.75, 4.25)), 0.85, 0.85, 8, None)
    for x in (-1.03, 1.03):
        box(glow, Vector((x, 0.3, 1.1)), (0.08, 4.4, 0.12))
    for x in (-1.55, 1.55):
        box(glow, Vector((x, -2.0, 4.45)), (0.5, 0.5, 0.12))
    return [finish("BenchPress_Frame", frame, "Tier", coll, loc), finish("BenchPress_Pad", pad, "Cushion", coll, loc),
            finish("BenchPress_Bar", bar, "Metal", coll, loc), finish("BenchPress_Plates", plates, "Tier", coll, loc),
            finish("BenchPress_Glow", glow, "Glow", coll, loc)]


def treadmill(coll, loc):
    """Runs along Y; the console is at -Y (the runner faces -Y)."""
    rng = random.Random(53)
    frame, belt, metal, glow = (bmesh.new() for _ in range(4))
    box(frame, Vector((0, 0.3, 0.3)), (4.4, 8.0, 0.6))
    box(frame, Vector((0, -3.9, 0.55)), (4.4, 1.2, 1.1))  # the motor housing at the front
    for x in (-2.0, 2.0):
        box(frame, Vector((x, 0.3, 0.75)), (0.4, 7.6, 0.3))
    box(belt, Vector((0, 0.4, 0.62)), (3.5, 7.2, 0.08))
    for x in (-1.9, 1.9):
        box(metal, Vector((x, -3.7, 2.4)), (0.3, 0.3, 3.6))
        box(metal, Vector((x, -2.4, 3.6)), (0.25, 2.6, 0.25))  # side handles
    box(metal, Vector((0, -3.7, 4.2)), (4.1, 0.6, 0.3))
    box(metal, Vector((0, -3.9, 4.75)), (2.8, 0.5, 1.2))  # the console
    box(glow, Vector((0, -3.62, 4.8)), (2.3, 0.08, 0.8))  # its screen
    for x in (-2.22, 2.22):
        box(glow, Vector((x, 0.3, 0.45)), (0.06, 7.4, 0.12))
    return [finish("Treadmill_Frame", frame, "Tier", coll, loc), finish("Treadmill_Belt", belt, "Cushion", coll, loc),
            finish("Treadmill_Metal", metal, "Metal", coll, loc), finish("Treadmill_Glow", glow, "Glow", coll, loc)]


# ---------------------------------------------------------------------------
# The floating island (docs/plans/M11.md). The grid is pointy-top hexes of size 16 around the origin;
# it's symmetric when mirrored, so Blender's mirrored axis doesn't matter for these.
# ---------------------------------------------------------------------------
ISLAND_RINGS = 15
HUB_RINGS = 6
HEX = 16.0


def _hexes(max_ring, min_ring=0):
    for q in range(-max_ring, max_ring + 1):
        for r in range(-max_ring, max_ring + 1):
            d = max(abs(q), abs(r), abs(q + r))
            if min_ring <= d <= max_ring:
                yield q, r, d


def _hex_center(q, r):
    return Vector((HEX * math.sqrt(3) * (q + r / 2), HEX * 1.5 * r, 0))


def _hex_plate(bm, center, radius, z0, z1, closed):
    corners = [(center.x + p.x, center.y + p.y) for p in hex_points(radius)]
    if closed:
        prism(bm, corners, z0, z1)
    else:
        bm.faces.new([bm.verts.new((x, y, z1)) for x, y in corners])


def _hex_column(bm, center, levels, rng, wobble):
    """A rocky hexagonal column hanging down: levels = [(z, radius), ...] from the top down."""
    rings = []
    for i, (z, radius) in enumerate(levels):
        ring = [bm.verts.new((center.x + p.x, center.y + p.y, z)) for p in hex_points(radius)]
        if i > 0:
            jitter(ring, rng, wobble)
        rings.append(ring)
    for upper, lower in zip(rings, rings[1:]):
        for i in range(6):
            j = (i + 1) % 6
            bm.faces.new((upper[i], upper[j], lower[j], lower[i]))
    bm.faces.new(list(reversed(rings[-1])))


def island(coll, loc):
    """The island: a grass top under the whole map, an invisible walk plate (rings 7-15, the plaza cut
    out) that bridges the seams, a dirt band and rocky cliffs under the outer ring, and a rock underside."""
    rng = random.Random(61)
    top, walk, dirt, rock = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    for q, r, d in _hexes(ISLAND_RINGS):
        c = _hex_center(q, r)
        _hex_plate(top, c, HEX, 0, 0, False)
        if d > HUB_RINGS:
            _hex_plate(walk, c, HEX, -1.0, 0.0, True)
        if d == ISLAND_RINGS:
            _hex_column(dirt, c, [(0.0, HEX + 0.25), (-5.0, HEX + 0.25)], rng, 0.0)
            depth = rng.uniform(60, 95)  # the columns stay wide, so together they read as one cliff wall
            _hex_column(rock, c, [(-5.0, HEX + 0.2), (-25.0, HEX + 0.1), (-45.0, HEX * 0.97),
                                  (-depth, HEX * 0.8)], rng, 1.4)
    # the underside: a lumpy rock point far below
    levels = [(-50.0, 405.0), (-95.0, 330.0), (-150.0, 220.0), (-205.0, 110.0), (-255.0, 25.0)]
    rings = []
    for i, (z, radius) in enumerate(levels):
        ring = [rock.verts.new((math.cos(a) * radius, math.sin(a) * radius, z))
                for a in (2 * math.pi * k / 24 for k in range(24))]
        jitter(ring, rng, radius * 0.06)
        rings.append(ring)
    for upper, lower in zip(rings, rings[1:]):
        for i in range(24):
            j = (i + 1) % 24
            rock.faces.new((upper[i], upper[j], lower[j], lower[i]))
    rock.faces.new(list(reversed(rings[-1])))
    rock.faces.new(rings[0])
    return [finish("Island_Top", top, "Grass", coll, loc), finish("Island_Walk", walk, "Grass", coll, loc),
            finish("Island_Dirt", dirt, "Dirt", coll, loc), finish("Island_Rock", rock, "Cliff", coll, loc)]


def _cloud(bm, center, size, rng):
    for _ in range(rng.randint(5, 7)):
        o = Vector((rng.uniform(-1.2, 1.2), rng.uniform(-0.8, 0.8), rng.uniform(-0.15, 0.35))) * size
        blob(bm, center + o, size * rng.uniform(0.55, 0.9), rng, squash=(1.3, 1.0, 0.7), subdiv=1, rough=0.08)


def clouds(coll, loc):
    """Puffy clouds: a layer below the island and a ring further out around it. The ring is split into four
    quarters: a mesh wider than Roblox's 2048-stud limit makes the importer shrink the whole file to fit."""
    rng = random.Random(67)
    below, far = bmesh.new(), [bmesh.new() for _ in range(4)]
    for _ in range(24):
        a, d = rng.uniform(0, 2 * math.pi), rng.uniform(300, 950)
        _cloud(below, Vector((math.cos(a) * d, math.sin(a) * d, rng.uniform(-170, -70))), rng.uniform(28, 55), rng)
    for _ in range(22):
        a, d = rng.uniform(0, 2 * math.pi), rng.uniform(800, 1350)
        _cloud(far[int(a // (math.pi / 2)) % 4], Vector((math.cos(a) * d, math.sin(a) * d, rng.uniform(-40, 70))),
               rng.uniform(35, 70), rng)
    return [finish("Clouds_Below", below, "Cloud", coll, loc)] + [
        finish(f"Clouds_Far{i + 1}", bm, "Cloud", coll, loc) for i, bm in enumerate(far)]


def islet(name, radius, seed, coll, loc):
    """A small floating island: a walkable grass top, a dirt band, a lumpy rock underside, rocks and
    flowers. Trees are added in Roblox from the forest's tree models."""
    rng = random.Random(seed)
    top, dirt, rock, deco = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    n = 12
    outline = []
    for k in range(n):
        a = 2 * math.pi * k / n
        rr = radius * rng.uniform(0.85, 1.1)
        outline.append((math.cos(a) * rr, math.sin(a) * rr))
    prism(top, outline, -1.5, 0.0)
    prism(dirt, [(x * 1.02, y * 1.02) for x, y in outline], -4.5, -1.5)
    levels = [(-4.5, 1.0), (-radius * 0.6, 0.75), (-radius * 1.3, 0.45), (-radius * 2.0, 0.12)]
    rings = []
    for i, (z, f) in enumerate(levels):
        ring = [rock.verts.new((x * f, y * f, z)) for x, y in outline]
        if i > 0:
            jitter(ring, rng, radius * 0.08)
        rings.append(ring)
    for upper, lower in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            rock.faces.new((upper[i], upper[j], lower[j], lower[i]))
    rock.faces.new(list(reversed(rings[-1])))
    for _ in range(int(radius / 3)):
        a, d = rng.uniform(0, 2 * math.pi), rng.uniform(0, radius * 0.75)
        blob(deco, Vector((math.cos(a) * d, math.sin(a) * d, 0.4)), rng.uniform(0.8, 2.2), rng, squash=(1.2, 1.0, 0.7),
             rough=0.2)
    flowers = bmesh.new()
    for _ in range(int(radius * 1.5)):
        a, d = rng.uniform(0, 2 * math.pi), rng.uniform(0, radius * 0.85)
        blob(flowers, Vector((math.cos(a) * d, math.sin(a) * d, 0.4)), rng.uniform(0.3, 0.5), rng, rough=0.1)
    return [finish(f"{name}_Top", top, "Grass", coll, loc), finish(f"{name}_Dirt", dirt, "Dirt", coll, loc),
            finish(f"{name}_Rock", rock, "Cliff", coll, loc), finish(f"{name}_Rocks", deco, "Stones", coll, loc),
            finish(f"{name}_Flowers", flowers, "Flowers", coll, loc)]


BRIDGE_LENGTH = 80.0


def bridge(coll, loc):
    """A wooden rope bridge along +X from 0 to BRIDGE_LENGTH, sagging a little in the middle."""
    rng = random.Random(71)
    planks, rope, posts = bmesh.new(), bmesh.new(), bmesh.new()

    def sag(x):
        return -1.2 * math.sin(math.pi * x / BRIDGE_LENGTH)

    x = 0.0
    while x < BRIDGE_LENGTH:
        box(planks, Vector((x + 1.4, 0, sag(x + 1.4) - 0.2)), (2.6, 10, 0.35), rng.uniform(-0.03, 0.03))
        x += 3.2
    for side in (-1, 1):
        for bx in (0.0, BRIDGE_LENGTH):
            box(posts, Vector((bx, side * 5.4, 1.6)), (0.6, 0.6, 4.4))
        for height in (1.6, 3.3):
            _polyline(rope, [Vector((t, side * 5.4, sag(t) + height)) for t in
                             (BRIDGE_LENGTH * k / 16 for k in range(17))], 0.12, 4)
    return [finish("Bridge_Planks", planks, "Wood", coll, loc), finish("Bridge_Rope", rope, "Rope", coll, loc),
            finish("Bridge_Posts", posts, "Wood", coll, loc)]


# ---------------------------------------------------------------------------
# Plaza decorations (fronts face +X, like the shop altar)
# ---------------------------------------------------------------------------
GIFT_RING_AHEAD, GIFT_RING_R = 10.0, 5.0


def gift_board(coll, loc):
    """A wooden notice board with a gift box in front and a glowing ring to step into."""
    rng = random.Random(73)
    wood, paper, gift, ribbon, glow = (bmesh.new() for _ in range(5))
    for y in (-4.2, 4.2):
        box(wood, Vector((0, y, 3.8)), (0.6, 0.6, 7.6))
    box(wood, Vector((0, 0, 4.8)), (0.4, 8.0, 4.6))
    for side in (-1, 1):
        box(wood, Vector((side * 0.9, 0, 7.9)), (2.4, 9.2, 0.3), 0)
    for k in range(5):
        box(paper, Vector((0.25, rng.uniform(-3, 3), rng.uniform(3.4, 6.2))), (0.08, 1.4, 1.1), 0)
    box(gift, Vector((3.0, 0, 1.2)), (2.4, 2.4, 2.4))
    box(ribbon, Vector((3.0, 0, 1.2)), (0.5, 2.5, 2.5))
    box(ribbon, Vector((3.0, 0, 1.2)), (2.5, 0.5, 2.5))
    for a in (-0.6, 0.6):
        blob(ribbon, Vector((3.0, a * 0.8, 2.6)), 0.45, rng, squash=(0.6, 1.0, 0.7), rough=0.05)
    annulus(glow, Vector((GIFT_RING_AHEAD, 0, 0.05)), GIFT_RING_R, GIFT_RING_R - 0.6, 0.2, 40)
    return [finish("GiftBoard_Wood", wood, "Wood", coll, loc), finish("GiftBoard_Paper", paper, "Paper", coll, loc),
            finish("GiftBoard_Box", gift, "GiftBox", coll, loc), finish("GiftBoard_Ribbon", ribbon, "Ribbon", coll, loc),
            finish("GiftBoard_Glow", glow, "Glow", coll, loc)]


def fountain(coll, loc):
    """A round stone fountain with lily pads, and a bench on each side."""
    rng = random.Random(79)
    stone, water, lily, wood = (bmesh.new() for _ in range(4))
    annulus(stone, Vector((0, 0, 0)), 9.0, 7.6, 1.6, 24)
    frustum(stone, Vector((0, 0, 0)), Vector((0, 0, 0.3)), 7.7, 7.7, 24, None)
    frustum(stone, Vector((0, 0, 0)), Vector((0, 0, 3.4)), 1.0, 0.75, 8, None)
    frustum(stone, Vector((0, 0, 3.2)), Vector((0, 0, 3.9)), 1.0, 2.6, 12, None)
    frustum(water, Vector((0, 0, 1.0)), Vector((0, 0, 1.2)), 7.6, 7.6, 24, None)
    blob(water, Vector((0, 0, 4.4)), 0.8, rng, squash=(1.0, 1.0, 1.4), rough=0.05)
    for _ in range(5):
        a, d = rng.uniform(0, 2 * math.pi), rng.uniform(3.0, 6.2)
        frustum(lily, Vector((math.cos(a) * d, math.sin(a) * d, 1.22)), Vector((math.cos(a) * d, math.sin(a) * d, 1.3)),
                rng.uniform(0.7, 1.0), rng.uniform(0.7, 1.0), 7, None)
    for side in (-1, 1):
        c = Vector((0, side * 13.0, 0))
        box(wood, c + Vector((0, 0, 1.3)), (6.0, 1.6, 0.35))
        box(wood, c + Vector((0, side * 0.7, 2.3)), (6.0, 0.25, 1.6))
        for x in (-2.5, 2.5):
            box(wood, c + Vector((x, 0, 0.6)), (0.35, 1.2, 1.2))
    return [finish("Fountain_Stone", stone, "Stones", coll, loc), finish("Fountain_Water", water, "Water", coll, loc),
            finish("Fountain_Lily", lily, "Leaves", coll, loc), finish("Fountain_Wood", wood, "Wood", coll, loc)]


# ---------------------------------------------------------------------------
# Animals for the break after a forest. Each faces -Y with its feet at z = 0 (Roblox: facing -Z).
# ---------------------------------------------------------------------------
def _legs(bm, xs, ys, top, radius):
    for x in xs:
        for y in ys:
            frustum(bm, Vector((x, y, top)), Vector((x, y, 0)), radius, radius * 0.7, 5, None)


def deer(coll, loc):
    rng = random.Random(89)
    body, antler = bmesh.new(), bmesh.new()
    blob(body, Vector((0, 0, 3.2)), 1.6, rng, squash=(0.65, 1.5, 0.7), rough=0.06)
    frustum(body, Vector((0, -1.6, 3.6)), Vector((0, -2.3, 5.2)), 0.45, 0.35, 6, None)
    blob(body, Vector((0, -2.6, 5.4)), 0.65, rng, squash=(0.8, 1.3, 0.8), rough=0.05)
    blob(body, Vector((0, 2.2, 3.6)), 0.35, rng, rough=0.05)
    _legs(body, (-0.5, 0.5), (-1.3, 1.3), 2.6, 0.2)
    for side in (-1, 1):
        base = Vector((side * 0.3, -2.4, 5.9))
        tip = base + Vector((side * 0.6, 0.3, 1.2))
        frustum(antler, base, tip, 0.1, 0.06, 4, None)
        frustum(antler, base + Vector((side * 0.3, 0.1, 0.6)), base + Vector((side * 0.9, -0.2, 1.0)), 0.07, 0.04, 4, None)
    return [finish("Deer_Body", body, "Deer", coll, loc), finish("Deer_Antler", antler, "Antler", coll, loc)]


def fox(coll, loc):
    rng = random.Random(97)
    body, white = bmesh.new(), bmesh.new()
    blob(body, Vector((0, 0, 1.5)), 0.9, rng, squash=(0.7, 1.4, 0.7), rough=0.06)
    blob(body, Vector((0, -1.5, 1.9)), 0.6, rng, squash=(0.9, 1.1, 0.85), rough=0.05)
    cone(body, Vector((0, -2.0, 1.7)), 0.5, 0.25, 5, rng)  # snout
    for side in (-1, 1):
        cone(body, Vector((side * 0.3, -1.4, 2.3)), 0.6, 0.22, 4, rng)  # ears
    frustum(body, Vector((0, 1.1, 1.6)), Vector((0, 2.4, 1.3)), 0.4, 0.5, 6, None)  # tail
    blob(white, Vector((0, 2.6, 1.3)), 0.38, rng, rough=0.05)  # tail tip
    blob(white, Vector((0, -1.0, 1.3)), 0.45, rng, squash=(0.8, 0.6, 0.8), rough=0.05)  # chest
    _legs(body, (-0.35, 0.35), (-0.8, 0.8), 1.1, 0.13)
    return [finish("Fox_Body", body, "Fox", coll, loc), finish("Fox_White", white, "FoxWhite", coll, loc)]


def bunny(coll, loc):
    rng = random.Random(101)
    body = bmesh.new()
    blob(body, Vector((0, 0.2, 0.75)), 0.7, rng, squash=(0.9, 1.1, 0.9), rough=0.06)
    blob(body, Vector((0, -0.6, 1.25)), 0.45, rng, rough=0.05)
    for side in (-1, 1):
        frustum(body, Vector((side * 0.15, -0.6, 1.6)), Vector((side * 0.25, -0.5, 2.5)), 0.13, 0.09, 5, None)
    blob(body, Vector((0, 0.9, 0.8)), 0.22, rng, rough=0.05)
    return [finish("Bunny_Body", body, "Bunny", coll, loc)]


def bird(coll, loc):
    """Body and beak, plus each wing as its own piece so the game can flap them (wing roots at x = +-0.3)."""
    rng = random.Random(103)
    body, beak, left, right = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    blob(body, Vector((0, 0, 0)), 0.5, rng, squash=(0.8, 1.5, 0.8), rough=0.05)
    cone(beak, Vector((0, -0.75, 0)), 0.4, 0.15, 4, rng)
    for side, bm in ((-1, left), (1, right)):
        prism(bm, [(side * 0.3, -0.4), (side * 1.9, 0.1), (side * 1.6, 0.6), (side * 0.3, 0.4)], -0.05, 0.05)
    return [finish("Bird_Body", body, "Bird", coll, loc), finish("Bird_Beak", beak, "Beak", coll, loc),
            finish("Bird_WingL", left, "Bird", coll, loc), finish("Bird_WingR", right, "Bird", coll, loc)]


ART_PASS_PREFIXES = ("Island", "Clouds", "Islet", "Bridge", "HexTile", "LobbyPath", "GiftBoard", "Fountain",
                     "Deer", "Fox", "Bunny", "Bird")


def build_art_pass(coll, loc):
    """Every M11 piece, laid out around loc for previewing."""
    made = island(coll, loc) + clouds(coll, loc)
    for i, (name, radius) in enumerate((("IsletA", 34.0), ("IsletB", 24.0), ("IsletC", 16.0))):
        made += islet(name, radius, 107 + i, coll, loc + Vector((-1700 - i * 120, 0, 0)))
    made += bridge(coll, loc + Vector((-1700, 200, 0)))
    for i, fn in enumerate((gift_board, fountain, deer, fox, bunny, bird)):
        made += fn(coll, loc + Vector((-1700 + i * 40, 400, 0)))
    return made


# ---------------------------------------------------------------------------
# Build and export
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Character outfits (polish pass, 2026-10-07): the Park Ranger and the Forest Lord, worn by owners of the
# Hands passes. Each accessory is modeled around its attachment point at the origin (in studs, for a
# standard R15 avatar: head about 1.2 wide, torso 2 wide), front toward -Y. Every asset also gets a tiny
# "_Origin" marker at the origin so Studio can find the attachment point after the import.
# ---------------------------------------------------------------------------
def _origin(name, coll, loc):
    bm = bmesh.new()
    box(bm, Vector((0, 0, 0)), (0.04, 0.04, 0.04))
    return finish(f"{name}_Origin", bm, "Gold", coll, loc)


def ranger_hat(coll, loc):
    """A campaign hat: a wide flat brim and a tall crown pinched into four dents, with a dark band.
    HatAttachment (the top of the head) at the origin; the brim sits at the forehead."""
    rng = random.Random(81)
    felt, band = bmesh.new(), bmesh.new()
    frustum(felt, Vector((0, 0, -0.34)), Vector((0, 0, -0.28)), 1.25, 1.2, 12, rng)  # brim
    crown = frustum(felt, Vector((0, 0, -0.3)), Vector((0, 0, 0.42)), 0.68, 0.34, 4, rng)  # 4 sides: the pinch
    bmesh.ops.rotate(felt, verts=crown, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(math.pi / 4, 3, "Z"))
    cone(felt, Vector((0, 0, 0.42)), 0.12, 0.34, 4, rng)  # the peak's point
    frustum(band, Vector((0, 0, -0.29)), Vector((0, 0, -0.14)), 0.7, 0.66, 12, rng)
    return [finish("RangerHat_Felt", felt, "RangerHat", coll, loc), finish("RangerHat_Band", band, "RangerBand", coll, loc),
            _origin("RangerHat", coll, loc)]


def ranger_badge(coll, loc):
    """A gold star badge on the chest's left side. BodyFrontAttachment at the origin."""
    star = bmesh.new()
    corners = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        r = 0.26 if i % 2 == 0 else 0.11
        corners.append((0.42 + r * math.cos(a), 0.3 + r * math.sin(a)))
    # Flat in X/Z (facing -Y), so build it as a prism in X/Y and turn it up.
    prism(star, corners, -0.04, 0.04)
    bmesh.ops.rotate(star, verts=star.verts, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
    bmesh.ops.translate(star, verts=star.verts, vec=Vector((0, -0.08, 0)))
    return [finish("RangerBadge_Star", star, "Gold", coll, loc), _origin("RangerBadge", coll, loc)]


def ranger_pack(coll, loc):
    """A small olive backpack with a red bedroll on top. BodyBackAttachment at the origin; it hangs behind (+Y)."""
    rng = random.Random(82)
    pack, roll = bmesh.new(), bmesh.new()
    box(pack, Vector((0, 0.32, -0.05)), (1.2, 0.55, 1.35))
    box(pack, Vector((0, 0.66, -0.25)), (0.8, 0.18, 0.6))  # the front pocket
    frustum(roll, Vector((-0.75, 0.32, 0.8)), Vector((0.75, 0.32, 0.8)), 0.3, 0.3, 8, rng)
    return [finish("RangerPack_Bag", pack, "RangerPack", coll, loc), finish("RangerPack_Roll", roll, "Bedroll", coll, loc),
            _origin("RangerPack", coll, loc)]


def lord_crown(coll, loc):
    """A crown of leaves: a gold band, a ring of upright leaves, two branching antlers and a glowing gem at
    the front. HatAttachment at the origin."""
    rng = random.Random(83)
    band, leaves, light, antler, gem = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    frustum(band, Vector((0, 0, -0.3)), Vector((0, 0, -0.08)), 0.66, 0.66, 10, rng)
    for i in range(9):
        a = 2 * math.pi * i / 9
        out = Vector((math.cos(a), math.sin(a), 0))
        base = out * 0.62 + Vector((0, 0, -0.12))
        _spear_leaf(leaves if i % 2 else light, base, (out * 0.35 + Vector((0, 0, 1))).normalized(), 0.75, 0.22)
    for side in (-1, 1):
        root = Vector((side * 0.55, 0.1, -0.05))
        tip = root + Vector((side * 0.45, 0.1, 1.1))
        frustum(antler, root, tip, 0.07, 0.04, 5, rng)
        for t, off in ((0.45, 0.35), (0.75, 0.3)):
            p = root.lerp(tip, t)
            frustum(antler, p, p + Vector((side * off, -0.1, 0.35)), 0.05, 0.03, 4, rng)
    blob(gem, Vector((0, -0.68, -0.18)), 0.13, rng, squash=(1.0, 0.6, 1.2), subdiv=1, rough=0.05)
    return [finish("LordCrown_Band", band, "Gold", coll, loc), finish("LordCrown_Leaves", leaves, "LordLeaves", coll, loc),
            finish("LordCrown_LeavesB", light, "LordLeavesB", coll, loc), finish("LordCrown_Antlers", antler, "Antler", coll, loc),
            finish("LordCrown_Gem", gem, "Gem", coll, loc), _origin("LordCrown", coll, loc)]


def lord_cape(coll, loc):
    """A long moss-green cape that flares out behind, with a hem of leaves and a gold clasp at the collar.
    BodyBackAttachment at the origin; the cape hangs behind (+Y) from the shoulders."""
    rng = random.Random(84)
    cloth, hem, clasp = bmesh.new(), bmesh.new(), bmesh.new()
    rows = [(0.75, 0.9, 0.12), (-0.6, 1.1, 0.22), (-1.9, 1.3, 0.42), (-3.0, 1.45, 0.62)]  # (z, half width, back)
    th = 0.06
    front, back = [], []
    for z, w, y in rows:
        row = [Vector((x * w, y + 0.05 * (1 - x * x), z)) for x in (-1, -0.5, 0, 0.5, 1)]
        front.append([cloth.verts.new(v) for v in row])
        back.append([cloth.verts.new(v + Vector((0, th, 0))) for v in row])
    for i in range(len(rows) - 1):
        for j in range(4):
            cloth.faces.new((front[i][j], front[i + 1][j], front[i + 1][j + 1], front[i][j + 1]))
            cloth.faces.new((back[i][j + 1], back[i + 1][j + 1], back[i + 1][j], back[i][j]))
        for j in (0, 4):
            cloth.faces.new((front[i][j], back[i][j], back[i + 1][j], front[i + 1][j]))
    for j in range(4):
        for r in (0, len(rows) - 1):
            cloth.faces.new((front[r][j], front[r][j + 1], back[r][j + 1], back[r][j]))
    z, w, y = rows[-1]
    for k in range(7):
        x = -w + 2 * w * (k + 0.5) / 7
        _spear_leaf(hem, Vector((x, y + 0.03, z + 0.15)), Vector((rng.uniform(-0.2, 0.2), 0.15, -1)), 0.55, 0.2)
    for side in (-1, 1):
        blob(clasp, Vector((side * 0.75, -0.05, 0.75)), 0.14, rng, subdiv=1, rough=0.05)
    return [finish("LordCape_Cloth", cloth, "Cape", coll, loc), finish("LordCape_Hem", hem, "LordLeavesB", coll, loc),
            finish("LordCape_Clasp", clasp, "Gold", coll, loc), _origin("LordCape", coll, loc)]


def lord_shoulder(name, side, coll, loc):
    """A spray of leaves on one shoulder. Left/RightShoulderAttachment at the origin (side -1 / 1)."""
    rng = random.Random(85 + side)
    leaves, light = bmesh.new(), bmesh.new()
    for i in range(6):
        a = math.pi * (i / 5 - 0.5)
        out = Vector((side * 0.5, math.sin(a) * 0.8, 0.6 + 0.3 * math.cos(a)))
        _spear_leaf(leaves if i % 2 else light, Vector((0, 0, 0.1)), out.normalized(), 0.7, 0.22)
    return [finish(f"{name}_Leaves", leaves, "LordLeaves", coll, loc), finish(f"{name}_LeavesB", light, "LordLeavesB", coll, loc),
            _origin(name, coll, loc)]


def outfits(coll, loc):
    """Every outfit accessory, side by side (export with only=("Ranger", "Lord"))."""
    made = []
    for i, fn in enumerate((ranger_hat, ranger_badge, ranger_pack, lord_crown, lord_cape)):
        made += fn(coll, loc + Vector((i * 6.0, 0, 0)))
    # Blender +X is Roblox -X, the avatar's left, so the left shoulder's leaves fan out toward +X here.
    made += lord_shoulder("LordShoulderL", 1, coll, loc + Vector((30, 0, 0)))
    made += lord_shoulder("LordShoulderR", -1, coll, loc + Vector((36, 0, 0)))
    return made


def build_all(full_only=False):
    coll = fresh_collection()
    stages = (STAGES[-1],) if full_only else STAGES
    for i, stage in enumerate(stages):
        x = i * 90.0
        leafy(stage, 11, coll, Vector((x, 0, 0)))
        pine(stage, 23, coll, Vector((x, 70, 0)))
        # the seed shop's special trees (docs/plans/SeedShop.md)
        for j, (fn, seed) in enumerate(((palm, 61), (sakura, 31), (redwood, 53), (crystal, 41), (bamboo, 67))):
            fn(stage, seed, coll, Vector((x, 140 + j * 70, 0)))
        # the Great Smoky Mountains world's Common trees (2026-10-07)
        maple(stage, 71, coll, Vector((x, 500, 0)))
        birch(stage, 73, coll, Vector((x, 570, 0)))
    for j, fn in enumerate((palm_seed, sakura_seed, redwood_seed, crystal_seed, bamboo_seed)):
        fn(coll, Vector((-160, 140 + j * 70, 0)))
    for i, stage in enumerate((4,) if full_only else (1, 2, 3, 4)):  # the Ancient Tree keeps its 4 stages
        ancient(stage, 5, coll, Vector((i * 450.0, 600, 0)))
    ancient_base(coll, Vector((-450, 600, 0)))
    tile(coll, Vector((-80, 0, 0)))
    acorn(coll, Vector((-80, 60, 0)))
    acorn_pile(coll, Vector((-80, 110, 0)))
    shop_altar(coll, Vector((-80, 170, 0)))
    ranger_station(coll, Vector((-140, 170, 0)))
    acorn_dispenser(coll, Vector((-140, 110, 0)))
    seed_stall(coll, Vector((-80, 230, 0)))
    bench_press(coll, Vector((-120, 60, 0)))
    treadmill(coll, Vector((-120, 90, 0)))
    lobby_build(coll, Vector((0, -1400, 0)))
    build_art_pass(coll, Vector((0, -3200, 0)))
    return [o.name for o in coll.objects]


def lobby_build(coll, loc):
    """Every lobby ring piece, centered on loc (the hub center in the preview)."""
    return (lobby_plaza(coll, loc) + lobby_fence(coll, loc) + lobby_garden(coll, loc) + lobby_path(coll, loc)
            + fence_decor(coll, loc))


def preview_patch():
    """Style check only (not exported): a few rings of tiles with mixed trees, like a slice of the forest."""
    coll = bpy.data.collections.get("PTF_Preview")
    if coll:
        for obj in list(coll.objects):
            bpy.data.objects.remove(obj)
    else:
        coll = bpy.data.collections.new("PTF_Preview")
        bpy.context.scene.collection.children.link(coll)
    src = bpy.data.collections[COLLECTION].objects
    origin = Vector((0, -400, 0))
    rng = random.Random(3)
    spacing = 16 * math.sqrt(3)

    def place(name, pos, rot=0.0, scale=1.0, mat_name=None):
        dup = src[name].copy()  # linked duplicate: shares the mesh
        dup.location = pos
        dup.rotation_euler = (0, 0, rot)
        dup.scale = (scale, scale, scale)
        coll.objects.link(dup)
        if mat_name:  # recolor this copy only, like setting Color on a MeshPart
            dup.material_slots[0].link = "OBJECT"
            dup.material_slots[0].material = material(mat_name)

    for q in range(-3, 4):
        for r in range(-3, 4):
            if abs(q + r) > 3:
                continue
            pos = origin + Vector((spacing * (q + r / 2), 16 * 1.5 * r, 0))  # Blender Y plays Roblox Z
            ring = (abs(q) + abs(r) + abs(q + r)) // 2
            if ring == 3 and rng.random() < 0.6:
                place("HexTile_Slab", pos)
                place("HexTile_Rim", pos)  # open and empty
                continue
            place("HexTile_Slab", pos, mat_name="Moss")
            stage = 4 if ring <= 1 else rng.choice((1, 2, 3, 4))
            if stage >= 2:
                place("HexTile_Tufts", pos, rot=rng.uniform(0, 6.3))
            species = rng.choice(("Leafy", "Pine"))
            jitter_pos = pos + Vector((rng.uniform(-4, 4), rng.uniform(-4, 4), 1.2))
            rot, scale = rng.uniform(0, 6.3), rng.uniform(0.9, 1.1)
            for piece in ("Bark", "Leaves" if species == "Leafy" else "Needles"):
                place(f"{species}{stage}_{piece}", jitter_pos, rot, scale)
    return len(coll.objects)


def export_fbx(path, only=None):
    """One FBX holding every asset. Each asset (Leafy1, Pine3, Ancient4, HexTile, ...) is an empty at the
    origin with its pieces as children, so Studio's importer makes one Model per asset in a single import.
    `only` is a name prefix or a tuple of them (e.g. ("Acorn", "Lobby", "ShopAltar"))."""
    import os

    os.makedirs(os.path.dirname(path), exist_ok=True)
    coll = bpy.data.collections[COLLECTION]
    groups = {}
    for obj in coll.objects:
        asset = obj.name.split("_")[0]
        if obj.type == "MESH" and (only is None or asset.startswith(only)):
            groups.setdefault(asset, []).append(obj)
    saved, empties = {}, []
    for asset, objs in sorted(groups.items()):
        empty = bpy.data.objects.new(asset, None)
        coll.objects.link(empty)
        empties.append(empty)
        for o in objs:
            saved[o.name] = o.location.copy()
            o.parent = empty
            o.location = (0, 0, 0)
    try:
        bpy.ops.object.select_all(action="DESELECT")
        for e in empties:
            e.select_set(True)
            for o in e.children:
                o.select_set(True)
        bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH", "EMPTY"},
                                 apply_scale_options="FBX_SCALE_UNITS", mesh_smooth_type="FACE")
    finally:
        for asset, objs in groups.items():
            for o in objs:
                o.parent = None
                o.location = saved[o.name]
        for e in empties:
            bpy.data.objects.remove(e)
    return path, sorted(groups)

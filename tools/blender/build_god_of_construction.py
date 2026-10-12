"""God of Construction: a wearable armor set for the R15 crew character (2026-10-11, the user's ask, after Build the
Pyramid-style mesh outfits). Builds into its own Blender scene, "GodOfConstruction", and exports tools/out/god_of_construction.fbx.

Units are studs, Z up, the character facing -Y. Every piece is named <BodyPart>__<Color>__<n>: the game welds it to that
R15 part (OutfitService) and colors it by <Color> (Gold, Steel, Trim, Glow, Visor, Cloth). REF_<BodyPart> boxes are the crew
body's parts at their rest pose (measured in Studio from a HumanoidDescription rig, root at the origin): they ride along
in the FBX so Studio can read each piece's offset from its part (and the import's scale), then they're dropped.

Run in Blender:  exec(open(r"<repo>/tools/blender/build_god_of_construction.py").read())
"""
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

SCENE = "GodOfConstruction"
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))) if "__file__" in dir() else "", "out")

# R15 crew body, from Studio: name -> (x, y_up, z_back, size_x, size_y, size_z) in Roblox axes, root at the origin.
REF = {
    "Head": (0, 1.5021, 0, 1.1606, 1.1815, 1.1733),
    "UpperTorso": (0, 0.2, 0, 1.9432, 1.6980, 1.0040),
    "LowerTorso": (0, -0.8, 0, 1.9914, 0.4007, 1.0040),
    "LeftUpperArm": (-1.5, 0.3687, 0, 1.0011, 1.2416, 1.0019),
    "RightUpperArm": (1.5, 0.3687, 0, 1.0011, 1.2416, 1.0019),
    "LeftLowerArm": (-1.5, -0.2241, 0, 1.0011, 1.1175, 1.0019),
    "RightLowerArm": (1.5, -0.2241, 0, 1.0011, 1.1175, 1.0019),
    "LeftHand": (-1.5, -0.8501, 0, 0.9843, 0.3158, 1.0283),
    "RightHand": (1.5, -0.8501, 0, 0.9843, 0.3158, 1.0283),
    "LeftUpperLeg": (-0.5, -1.4208, 0, 0.9928, 1.3629, 0.9727),
    "RightUpperLeg": (0.5, -1.4208, 0, 0.9928, 1.3629, 0.9727),
    "LeftLowerLeg": (-0.5, -2.2009, 0, 0.9928, 1.3007, 0.9728),
    "RightLowerLeg": (0.5, -2.2009, 0, 0.9928, 1.3007, 0.9728),
    "LeftFoot": (-0.5, -2.85, 0, 1.0089, 0.3120, 1.0011),
    "RightFoot": (0.5, -2.85, 0, 1.0089, 0.3120, 1.0011),
}

SUIT = 0.06  # the steel suit's thickness over the body (studs, total)
SHARP_ANGLE = 40  # degrees: edges sharper than this stay hard, the rest shade smooth
ROUND = 2  # round shapes get this many times their listed segments

COLORS = {  # preview colors only; the game sets the real ones
    "Gold": (1.0, 0.72, 0.18, 1),
    "Steel": (0.16, 0.17, 0.2, 1),
    "Trim": (0.75, 0.77, 0.8, 1),
    "Glow": (1.0, 0.55, 0.12, 1),
    "Visor": (0.3, 0.85, 1.0, 1),
    "Cloth": (0.75, 0.2, 0.12, 1),
    "Ref": (0.9, 0.75, 0.6, 1),
}


def scene():
    sc = bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)
    for o in list(sc.collection.all_objects):
        bpy.data.objects.remove(o, do_unlink=True)
    return sc


def material(name):
    m = bpy.data.materials.get("God_" + name) or bpy.data.materials.new("God_" + name)
    m.diffuse_color = COLORS[name]
    return m


class Piece:
    """Geometry for one object, added part by part (each part with its own matrix)."""

    def __init__(self, part, color):
        self.part, self.color = part, color
        self.bm = bmesh.new()

    def add(self, build, matrix):
        tmp = bmesh.new()
        build(tmp)
        bmesh.ops.transform(tmp, matrix=matrix, verts=tmp.verts)
        mesh = bpy.data.meshes.new("tmp")
        tmp.to_mesh(mesh)
        tmp.free()
        self.bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
        return self


def cube(size):
    def build(bm):
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    return build


def cyl(r1, r2, depth, segs=24):
    def build(bm):
        bmesh.ops.create_cone(bm, cap_ends=True, segments=segs * ROUND, radius1=r1, radius2=r2, depth=depth)
    return build


def dome(rx, ry, rz, segs=24, rings=8):
    """The top half of an ellipsoid, its flat side at z=0."""
    def build(bm):
        bmesh.ops.create_uvsphere(bm, u_segments=segs * ROUND, v_segments=rings * 2 * ROUND, radius=1.0)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -1e-4], context="VERTS")
        edges = [e for e in bm.edges if e.is_boundary]
        bmesh.ops.holes_fill(bm, edges=edges)
        bmesh.ops.scale(bm, vec=Vector((rx, ry, rz)), verts=bm.verts)
    return build


def ring(r_in, r_out, depth, segs=32, teeth=0, tooth=(0.0, 0.0), arc=(0.0, 360.0)):
    """An annulus in the XY plane (a gear when teeth > 0), `depth` thick along Z, over the arc in degrees."""
    def build(bm):
        a0, a1 = math.radians(arc[0]), math.radians(arc[1])
        full = abs(arc[1] - arc[0]) >= 359.9
        segs_ = segs * ROUND
        n = segs_ if full else segs_ + 1
        rows = []
        for i in range(n):
            a = a0 + (a1 - a0) * i / segs_
            c, s = math.cos(a), math.sin(a)
            rows.append([bm.verts.new((c * r, s * r, z)) for r, z in
                         ((r_in, -depth / 2), (r_out, -depth / 2), (r_out, depth / 2), (r_in, depth / 2))])
        for i in range(segs_):
            p, q = rows[i], rows[(i + 1) % n]
            for k in range(4):
                bm.faces.new((p[k], p[(k + 1) % 4], q[(k + 1) % 4], q[k]))
        if not full:
            bm.faces.new(rows[0][::-1])
            bm.faces.new(rows[-1])
        for i in range(teeth):
            a = a0 + (a1 - a0) * (i + 0.5) / teeth
            t = bmesh.new()
            bmesh.ops.create_cube(t, size=1.0)
            bmesh.ops.scale(t, vec=Vector((tooth[0], tooth[1], depth)), verts=t.verts)
            bmesh.ops.translate(t, vec=Vector((r_out + tooth[0] / 2 - 0.02, 0, 0)), verts=t.verts)
            bmesh.ops.rotate(t, cent=Vector(), matrix=Matrix.Rotation(a, 3, "Z"), verts=t.verts)
            mesh = bpy.data.meshes.new("tooth")
            t.to_mesh(mesh)
            t.free()
            bm.from_mesh(mesh)
            bpy.data.meshes.remove(mesh)
    return build


def prism(points, depth):
    """A flat shape from convex (x, z) points in the XZ plane, `depth` thick along Y."""
    def build(bm):
        front = [bm.verts.new((x, -depth / 2, z)) for x, z in points]
        back = [bm.verts.new((x, depth / 2, z)) for x, z in points]
        bm.faces.new(front)
        bm.faces.new(back[::-1])
        for i in range(len(points)):
            j = (i + 1) % len(points)
            bm.faces.new((front[i], back[i], back[j], front[j]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return build


def at(x, y, z, rx=0.0, ry=0.0, rz=0.0):
    """A matrix at (x, y, z) in Blender axes, turned by degrees about X, Y, Z."""
    return (Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(rz), 4, "Z")
            @ Matrix.Rotation(math.radians(ry), 4, "Y") @ Matrix.Rotation(math.radians(rx), 4, "X"))


def ref_center(part):
    x, y_up, z_back, *_ = REF[part]
    return Vector((x, z_back, y_up))  # Blender: X, Y = Roblox Z (back), Z = up


def build():
    sc = scene()
    pieces = {}

    def piece(part, color):
        key = (part, color)
        if key not in pieces:
            pieces[key] = Piece(part, color)
        return pieces[key]

    # Reference body boxes, and a dark steel suit just over every body part but the head, hands and feet (so no skin
    # shows through the plates, even when the idle animation bends the waist and arms).
    for part, (x, y_up, z_back, sx, sy, sz) in REF.items():
        piece("REF_" + part, "Ref").add(cube((sx, sz, sy)), at(x, z_back, y_up))
        if part not in ("Head", "LeftHand", "RightHand", "LeftFoot", "RightFoot"):
            piece(part, "Steel").add(cube((sx + SUIT, sz + SUIT, sy + SUIT)), at(x, z_back, y_up))

    # Head: a gold hard hat with a silver ridge, a glowing visor across the eyes, two swept horns and a gear crest.
    hx, hy, hz = ref_center("Head")
    # The helmet fits like Roblox's Builders Club Hard Hat (the user: it was too big): measured in Studio, that hat's
    # box is 1.34 wide x 0.74 tall x 1.59 deep (with its brim), centred 0.74 over the head's centre and 0.145 forward. The
    # dome here is that width and depth less the brim; the brim sticks out in front; the ridge follows the dome.
    base = hz + 0.38  # the dome's flat bottom, just over the brow
    cy = hy - 0.06  # a touch forward of the head's centre (the brim's weight is in front)
    dx, dy, dz = 0.62, 0.66, 0.6  # the dome's half width, half depth, height
    piece("Head", "Gold").add(dome(dx, dy, dz, 28, 9), at(hx, cy, base))
    piece("Head", "Gold").add(cyl(dx + 0.05, dx + 0.05, 0.06, 32), at(hx, cy, base))
    piece("Head", "Gold").add(cube((dx * 1.3, 0.3, 0.05)), at(hx, cy - dy - 0.1, base - 0.01, rx=-8))
    for i in range(-5, 6):
        a = math.radians(i * 15)
        piece("Head", "Trim").add(cube((0.14, 0.16, 0.08)), at(hx, cy + math.sin(a) * dy, base + math.cos(a) * dz, rx=-i * 15))
    # The visor (the user's reference: a Cyclops-style wraparound): a gold band around the front of the head at eye
    # level with a glowing lens slit across it, and a round disc at each temple.
    piece("Head", "Gold").add(ring(0.6, 0.72, 0.34, 32, arc=(-205, 25)), at(hx, hy, hz + 0.08))
    piece("Head", "Visor").add(ring(0.68, 0.77, 0.14, 32, arc=(-160, -20)), at(hx, hy, hz + 0.1))
    for side in (-1, 1):
        piece("Head", "Gold").add(cyl(0.24, 0.24, 0.14, 20), at(hx + side * 0.7, hy + 0.08, hz + 0.08, ry=90))
        piece("Head", "Trim").add(cyl(0.14, 0.14, 0.16, 16), at(hx + side * 0.72, hy + 0.08, hz + 0.08, ry=90))
    for side in (-1, 1):
        piece("Head", "Gold").add(cyl(0.1, 0.0, 0.7, 12), at(hx + side * 0.5, cy + 0.1, base + 0.42, rx=25, ry=side * 38))
        piece("Head", "Trim").add(cyl(0.12, 0.12, 0.1, 12), at(hx + side * 0.47, cy + 0.08, base + 0.28, rx=25, ry=side * 38))
    piece("Head", "Glow").add(ring(0.05, 0.11, 0.04, 16, teeth=8, tooth=(0.05, 0.04)), at(hx, cy - dy + 0.02, base + 0.28, rx=90))

    # Upper torso: a gold breastplate, steel ab bands, a gear emblem, a collar, a back plate, a giant hammer slung across
    # the back and a glowing gear halo behind the head.
    tx, ty, tz = ref_center("UpperTorso")
    piece("UpperTorso", "Gold").add(cube((2.12, 1.18, 0.98)), at(tx, ty, tz + 0.38))
    for k, w in enumerate((2.08, 1.98, 1.88)):
        piece("UpperTorso", "Trim").add(cube((w, 1.14, 0.14)), at(tx, ty, tz - 0.2 - k * 0.2))
    piece("UpperTorso", "Trim").add(cube((1.24, 1.06, 0.2)), at(tx, ty, tz + 0.92))
    piece("UpperTorso", "Glow").add(ring(0.14, 0.3, 0.06, 24, teeth=10, tooth=(0.1, 0.09)), at(tx, ty - 0.6, tz + 0.4, rx=90))
    piece("UpperTorso", "Trim").add(cube((0.12, 0.1, 0.5)), at(tx, ty - 0.63, tz + 0.4, ry=40))
    piece("UpperTorso", "Trim").add(cube((0.34, 0.12, 0.16)), at(tx + 0.13, ty - 0.64, tz + 0.58, ry=40))
    piece("UpperTorso", "Steel").add(cube((1.86, 0.16, 1.4)), at(tx, ty + 0.58, tz + 0.1))
    hammer = at(tx, ty + 0.8, tz + 0.1, ry=-38)
    piece("UpperTorso", "Gold").add(cyl(0.08, 0.08, 3.4, 12), hammer)
    piece("UpperTorso", "Steel").add(cube((1.3, 0.62, 0.62)), hammer @ at(0, 0, 1.75, ry=90))
    for k in (-0.42, 0.42):
        piece("UpperTorso", "Trim").add(cube((0.1, 0.66, 0.66)), hammer @ at(0, 0, 1.75, ry=90) @ at(k, 0, 0))
    piece("UpperTorso", "Gold").add(cube((0.22, 0.22, 0.22)), hammer @ at(0, 0, -1.72))
    piece("UpperTorso", "Glow").add(ring(1.02, 1.18, 0.07, 48, teeth=14, tooth=(0.16, 0.14)), at(tx, ty + 0.98, tz + 1.42, rx=90))
    # A red scarf round the neck (the reference) with its tail over the right of the breastplate.
    piece("UpperTorso", "Cloth").add(ring(0.42, 0.8, 0.16, 28), at(tx, ty - 0.04, tz + 0.92))
    piece("UpperTorso", "Cloth").add(cube((0.32, 0.06, 0.5)), at(tx + 0.72, ty - 0.66, tz + 0.7, ry=10))

    # Lower torso, the centre piece (the user: the belt should really stand out, after a reference): a thick steel belt
    # with silver rails and a glowing line, a big framed gold buckle with a glowing canyon-peaks emblem and corner rivets,
    # a red cloth tabard hanging from it, a pouch and a wrench at the hips, and gold tassets with hazard stripes.
    lx, ly, lz = ref_center("LowerTorso")
    piece("LowerTorso", "Steel").add(cube((2.16, 1.16, 0.5)), at(lx, ly, lz))
    for dz in (-0.24, 0.24):
        piece("LowerTorso", "Trim").add(cube((2.22, 1.22, 0.07)), at(lx, ly, lz + dz))
    piece("LowerTorso", "Glow").add(cube((2.0, 0.04, 0.05)), at(lx, ly - 0.59, lz))
    bz = lz - 0.04  # the buckle hangs a little low, over the tabard's top
    piece("LowerTorso", "Trim").add(cube((1.44, 0.12, 1.08)), at(lx, ly - 0.63, bz))
    piece("LowerTorso", "Gold").add(cube((1.3, 0.16, 0.96)), at(lx, ly - 0.68, bz))
    piece("LowerTorso", "Glow").add(cube((1.08, 0.04, 0.76)), at(lx, ly - 0.775, bz))
    piece("LowerTorso", "Steel").add(cube((1.02, 0.06, 0.7)), at(lx, ly - 0.77, bz))
    emblem = at(lx, ly - 0.81, bz - 0.24) @ Matrix.Scale(1.25, 4)
    piece("LowerTorso", "Glow").add(prism(((-0.34, 0), (0.12, 0), (-0.11, 0.36)), 0.04), emblem)
    piece("LowerTorso", "Glow").add(prism(((-0.02, 0), (0.36, 0), (0.17, 0.24)), 0.04), emblem)
    piece("LowerTorso", "Glow").add(cube((0.76, 0.04, 0.05)), emblem @ at(0, 0, -0.04))
    for x in (-0.56, 0.56):
        for z in (-0.38, 0.38):
            piece("LowerTorso", "Trim").add(cyl(0.05, 0.05, 0.06, 10), at(lx + x, ly - 0.77, bz + z, rx=90))
    piece("LowerTorso", "Cloth").add(prism(((-0.34, 0.62), (0.34, 0.62), (0.34, -0.45), (0, -0.66), (-0.34, -0.45)), 0.04),
                                     at(lx, ly - 0.66, lz - 0.95, rx=-4))
    piece("LowerTorso", "Gold").add(cube((0.3, 0.22, 0.34)), at(lx - 0.9, ly - 0.66, lz - 0.02))
    piece("LowerTorso", "Trim").add(cube((0.32, 0.24, 0.08)), at(lx - 0.9, ly - 0.66, lz + 0.15))
    wrench = at(lx + 0.9, ly - 0.66, lz - 0.2, ry=-12)
    piece("LowerTorso", "Trim").add(cube((0.1, 0.06, 0.56)), wrench)
    piece("LowerTorso", "Trim").add(ring(0.07, 0.15, 0.06, 16, arc=(130, 410)), wrench @ at(0, 0, 0.32, rx=90))
    for side in (-1, 1):
        tasset = at(lx + side * 0.72, ly - 0.62, lz - 0.48, rx=-8, ry=side * 6)
        piece("LowerTorso", "Gold").add(cube((0.62, 0.08, 0.6)), tasset)
        for k in (-0.21, -0.07, 0.07, 0.21):
            piece("LowerTorso", "Steel").add(cube((0.06, 0.02, 0.24)), tasset @ at(k, -0.045, -0.14, ry=40))
        piece("LowerTorso", "Gold").add(cube((0.08, 0.86, 0.5)), at(lx + side * 1.1, ly, lz - 0.38, ry=side * -8))

    for side, name in ((-1, "Left"), (1, "Right")):
        # Upper arms: big gold pauldrons with a steel rim, three rivet spikes and an I-beam fin.
        ux, uy, uz = ref_center(name + "UpperArm")
        top = at(ux + side * 0.06, uy, uz + 0.6, ry=side * 18)
        piece(name + "UpperArm", "Gold").add(dome(0.78, 0.72, 0.52, 24, 8), top)
        piece(name + "UpperArm", "Steel").add(ring(0.7, 0.82, 0.12, 28), top @ at(0, 0, 0.02))
        for k in (-0.3, 0, 0.3):
            piece(name + "UpperArm", "Trim").add(cyl(0.08, 0.0, 0.26, 8), top @ at(k * 0.9, 0, 0.48 - abs(k) * 0.4))
        piece(name + "UpperArm", "Steel").add(cube((0.1, 0.72, 0.36)), top @ at(side * 0.42, 0, 0.42))
        piece(name + "UpperArm", "Gold").add(cube((1.14, 1.14, 0.16)), at(ux, uy, uz - 0.1))

        # Lower arms: steel bracers with a gold cuff and a glowing strip down the outside.
        bx, by, bz = ref_center(name + "LowerArm")
        piece(name + "LowerArm", "Trim").add(cube((1.14, 1.14, 0.16)), at(bx, by, bz - 0.42))
        piece(name + "LowerArm", "Gold").add(cube((1.18, 1.18, 0.18)), at(bx, by, bz + 0.38))
        piece(name + "LowerArm", "Glow").add(cube((0.05, 0.36, 0.7)), at(bx + side * 0.57, by, bz - 0.1))

        # Hands: gold knuckle guards.
        kx, ky, kz = ref_center(name + "Hand")
        piece(name + "Hand", "Gold").add(cube((1.04, 1.08, 0.24)), at(kx, ky, kz + 0.02))

        # Upper legs: steel thigh plates.
        gx, gy, gz = ref_center(name + "UpperLeg")
        piece(name + "UpperLeg", "Trim").add(cube((0.62, 0.12, 0.8)), at(gx, gy - 0.5, gz + 0.1))
        piece(name + "UpperLeg", "Gold").add(cube((0.12, 0.7, 0.9)), at(gx + side * 0.51, gy, gz + 0.05))

        # Lower legs: gold greaves with a silver knee cap and a glowing strip.
        sx, sy, sz = ref_center(name + "LowerLeg")
        piece(name + "LowerLeg", "Gold").add(cube((1.12, 1.1, 1.02)), at(sx, sy, sz - 0.05))
        piece(name + "LowerLeg", "Trim").add(dome(0.34, 0.2, 0.3, 16, 6), at(sx, sy - 0.53, sz + 0.5, rx=90))
        piece(name + "LowerLeg", "Glow").add(cube((0.36, 0.05, 0.5)), at(sx, sy - 0.54, sz - 0.12))

        # Feet: steel boots with a gold toe cap.
        fx, fy, fz = ref_center(name + "Foot")
        piece(name + "Foot", "Steel").add(cube((1.1, 1.24, 0.4)), at(fx, fy - 0.08, fz + 0.02))
        piece(name + "Foot", "Gold").add(cube((1.12, 0.3, 0.3)), at(fx, fy - 0.62, fz))

    counts = {}
    objects = []
    for (part, color), pc in pieces.items():
        counts[part] = counts.get(part, 0) + 1
        name = part if part.startswith("REF_") else f"{part}__{color}__{counts[part]}"
        mesh = bpy.data.meshes.new(name)
        pc.bm.to_mesh(mesh)
        pc.bm.free()
        mesh.materials.append(material(color))
        obj = bpy.data.objects.new(name, mesh)
        sc.collection.objects.link(obj)
        if not part.startswith("REF_"):
            # Smooth shading, with sharp edges only where faces meet at more than SHARP_ANGLE: round pieces (the helmet,
            # pauldrons, halo) shade smooth, boxes keep crisp corners (the user: flat shading showed every facet), and the
            # bevel's narrow faces catch the light on the corners.
            for poly in mesh.polygons:
                poly.use_smooth = True
            mesh.set_sharp_from_angle(angle=math.radians(SHARP_ANGLE))
            bev = obj.modifiers.new("Bevel", "BEVEL")
            bev.width, bev.segments, bev.limit_method = 0.03, 3, "ANGLE"
            bev.harden_normals = True
        objects.append(obj)
    return sc, objects


def export(sc, objects, path):
    window = bpy.context.window
    old = window.scene
    window.scene = sc
    hidden = [o for o in objects if o.hide_get()]
    try:
        for o in hidden:
            o.hide_set(False)  # hidden objects can't be selected, and the REF_ boxes must go in the file
        bpy.ops.object.select_all(action="DESELECT")
        for o in objects:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, use_mesh_modifiers=True,
                                 apply_scale_options="FBX_SCALE_UNITS", mesh_smooth_type="OFF")
    finally:
        for o in hidden:
            o.hide_set(True)
        window.scene = old


SC, OBJECTS = build()
print(f"built {len(OBJECTS)} objects in scene {SC.name}")

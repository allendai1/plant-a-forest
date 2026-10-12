"""God of Hammers: a wearable construction-mech suit for the R15 crew character (2026-10-11, the user's ask: the 2nd
pass, after a reference picture of a yellow construction robot on a Grand Canyon bridge site). Second version the same
day: custom chamfered and inset meshes instead of plain boxes, one collection per R15 part, an ATTACH_ empty per part,
and a joint-clearance test (clearance()). Builds into its own Blender scene, "GodOfHammers", and exports
tools/out/god_of_hammers.fbx (export(SC, OBJECTS, path)).

Units are studs, Z up, the character facing -Y: Blender (x, y, z) = Roblox (-x, z, y), a rotation (Roblox's X on
Blender's X with Z on Y would be a mirror, and the suit came out left/right swapped in the game). So the character's
left is +X, and the front view in Blender matches the reference picture (the robot's right on the viewer's left). Every
piece is named <BodyPart>__<Color>__<n>: the game welds it to that R15 part (OutfitService) and colors it by <Color>
(tools/import_god_outfit.luau). Nothing is merged across parts that move separately. REF_<BodyPart> boxes are the crew
body's parts at rest (measured in Studio, root at the origin): they ride along in the FBX so Studio can read each piece's
offset from its part, then they're dropped. PIVOT holds the joints, measured from the rig's joint attachments.

Run in Blender:  exec(open(r"<repo>/tools/blender/build_god_of_hammers.py").read())
"""
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

SCENE = "GodOfHammers"

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
# Joints at rest, Blender axes (the character's left at +X): name -> (child part, parent part, pivot). From the rig's AnimationConstraint attachments.
PIVOT = {
    "Neck": ("Head", "UpperTorso", (-0, 0, 0.926)),
    "Waist": ("UpperTorso", "LowerTorso", (-0, 0, -0.649)),
    "LeftShoulder": ("LeftUpperArm", "UpperTorso", (0.999, 0, 0.788)),
    "RightShoulder": ("RightUpperArm", "UpperTorso", (-0.999, 0, 0.788)),
    "LeftElbow": ("LeftLowerArm", "LeftUpperArm", (1.5, 0, 0.051)),
    "RightElbow": ("RightLowerArm", "RightUpperArm", (-1.5, 0, 0.051)),
    "LeftWrist": ("LeftHand", "LeftLowerArm", (1.5, 0, -0.718)),
    "RightWrist": ("RightHand", "RightLowerArm", (-1.5, 0, -0.718)),
    "LeftHip": ("LeftUpperLeg", "LowerTorso", (0.5, 0, -0.950)),
    "RightHip": ("RightUpperLeg", "LowerTorso", (-0.5, 0, -0.950)),
    "LeftKnee": ("LeftLowerLeg", "LeftUpperLeg", (0.5, 0, -1.788)),
    "RightKnee": ("RightLowerLeg", "RightUpperLeg", (-0.5, 0, -1.788)),
    "LeftAnkle": ("LeftFoot", "LeftLowerLeg", (0.5, 0, -2.744)),
    "RightAnkle": ("RightFoot", "RightLowerLeg", (-0.5, 0, -2.744)),
}

SHARP_ANGLE = 40  # degrees: edges sharper than this stay hard, the rest shade smooth

COLORS = {  # preview colors only; the game sets the real ones (tools/import_god_outfit.luau)
    "Yellow": (1.0, 0.62, 0.02, 1),
    "Dark": (0.045, 0.042, 0.04, 1),
    "Steel": (0.17, 0.17, 0.18, 1),
    "Trim": (0.6, 0.62, 0.66, 1),
    "Bronze": (0.14, 0.08, 0.035, 1),
    "Orange": (0.8, 0.16, 0.015, 1),
    "Hazard": (0.012, 0.012, 0.013, 1),
    "Red": (1.0, 0.06, 0.03, 1),
    "Screen": (0.005, 0.005, 0.007, 1),
    "Eye": (0.08, 0.8, 1.0, 1),
    "Glow": (1.0, 0.75, 0.35, 1),
    "Ref": (0.9, 0.75, 0.6, 1),
}
GLOWING = ("Eye", "Glow", "Red")


def scene():
    sc = bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)
    for o in list(sc.collection.all_objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for c in list(sc.collection.children_recursive):
        bpy.data.collections.remove(c)
    return sc


def material(name):
    m = bpy.data.materials.get("God_" + name) or bpy.data.materials.new("God_" + name)
    m.diffuse_color = COLORS[name]
    m.use_nodes = True
    bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf:
        bsdf.inputs["Base Color"].default_value = COLORS[name]
        bsdf.inputs["Roughness"].default_value = 0.45
        if name in GLOWING:
            bsdf.inputs["Emission Color"].default_value = COLORS[name]
            bsdf.inputs["Emission Strength"].default_value = 3.0
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


# Shapes. Each returns build(bm), centred on the origin.

def box(w, d, h, ch=0.0, taper=(1.0, 1.0), shift=(0.0, 0.0), inset=None):
    """A w (X) x d (Y) x h (Z) block, its top scaled by `taper` and slid by `shift`, every edge chamfered by `ch`.
    inset=(thickness, depth, (nx, ny, nz)): the face looking that way gets a border `thickness` wide and its middle
    pushed in by `depth` (a raised frame round a recessed panel)."""
    def build(bm):
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            top = v.co.z > 0
            v.co.x *= w * (taper[0] if top else 1.0)
            v.co.y *= d * (taper[1] if top else 1.0)
            v.co.z *= h
            if top:
                v.co.x += shift[0]
                v.co.y += shift[1]
        if ch > 0:
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=ch, segments=1, affect="EDGES", profile=0.5,
                            clamp_overlap=True)
        if inset:
            inset_face(bm, *inset)
    return build


def inset_face(bm, thickness, depth, normal):
    n = Vector(normal)
    bm.normal_update()
    face = max(bm.faces, key=lambda f: f.normal.dot(n) * 10 + f.calc_area())
    bmesh.ops.inset_individual(bm, faces=[face], thickness=thickness, depth=-depth, use_even_offset=True)


def cyl(r1, r2, depth, segs=10):
    """A cylinder (a cone if r1 != r2) along Z. Low sided on purpose: joints and bolts read as machined parts."""
    def build(bm):
        bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=depth)
    return build


def dome(rx, ry, rz, segs=24, rings=6):
    """The top half of an ellipsoid, its flat side at z=0."""
    def build(bm):
        bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings * 2, radius=1.0)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -1e-4], context="VERTS")
        bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary])
        bmesh.ops.scale(bm, vec=Vector((rx, ry, rz)), verts=bm.verts)
    return build


def ring(r_in, r_out, depth, segs=16, arc=(0.0, 360.0)):
    """An annulus in the XY plane, `depth` thick along Z, over the arc in degrees."""
    def build(bm):
        a0, a1 = math.radians(arc[0]), math.radians(arc[1])
        full = abs(arc[1] - arc[0]) >= 359.9
        n = segs if full else segs + 1
        rows = []
        for i in range(n):
            a = a0 + (a1 - a0) * i / segs
            c, s = math.cos(a), math.sin(a)
            rows.append([bm.verts.new((c * r, s * r, z)) for r, z in
                         ((r_in, -depth / 2), (r_out, -depth / 2), (r_out, depth / 2), (r_in, depth / 2))])
        for i in range(segs):
            p, q = rows[i], rows[(i + 1) % n]
            for k in range(4):
                bm.faces.new((p[k], p[(k + 1) % 4], q[(k + 1) % 4], q[k]))
        if not full:
            bm.faces.new(rows[0][::-1])
            bm.faces.new(rows[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return build


def prism(points, depth, ch=0.0, inset=None):
    """A flat shape from convex (x, z) points in the XZ plane, `depth` thick along Y (front = -Y)."""
    def build(bm):
        front = [bm.verts.new((x, -depth / 2, z)) for x, z in points]
        back = [bm.verts.new((x, depth / 2, z)) for x, z in points]
        bm.faces.new(front)
        bm.faces.new(back[::-1])
        for i in range(len(points)):
            j = (i + 1) % len(points)
            bm.faces.new((front[i], back[i], back[j], front[j]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        if ch > 0:
            front_edges = [e for e in bm.edges if all(v.co.y < 0 for v in e.verts)]
            bmesh.ops.bevel(bm, geom=front_edges, offset=ch, segments=1, affect="EDGES", profile=0.5,
                            clamp_overlap=True)
        if inset:
            inset_face(bm, inset[0], inset[1], (0, -1, 0))
    return build


def octagon(w, h, c):
    """An octagon's (x, z) points: w x h half sizes, corners cut by c."""
    return ((-w + c, h), (w - c, h), (w, h - c), (w, -h + c), (w - c, -h), (-w + c, -h), (-w, -h + c), (-w, h - c))


def at(x, y, z, rx=0.0, ry=0.0, rz=0.0):
    """A matrix at (x, y, z) in Blender axes, turned by degrees about X, Y, Z."""
    return (Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(rz), 4, "Z")
            @ Matrix.Rotation(math.radians(ry), 4, "Y") @ Matrix.Rotation(math.radians(rx), 4, "X"))


def ref_center(part):
    x, y_up, z_back, *_ = REF[part]
    return Vector((-x, z_back, y_up))


# The head's shape (2026-10-11, the user: the box head looked too wide and rectangular; variations to compare):
#   box      the first one, a wide rounded box (1.44 x 1.3 x 1.0) with a recessed face screen
#   small    a smaller box (1.2 x 1.1 x 0.86)
#   round    an egg-round head with a curved visor screen
#   cylinder a Roblox-style head: an upright cylinder with rounded rims and a curved screen band
HEAD_STYLE = "cylinder"  # the user's pick, 2026-10-11 (option D; tools/out/head_variants.png)


def scaled(sx, sy, sz):
    return Matrix.Diagonal((sx, sy, sz, 1.0))


def sphere_patch(rx, ry, rz, keep, segs=32, rings=16):
    """The part of an ellipsoid shell (one face thick) whose unit-sphere points pass keep(x, y, z)."""
    def build(bm):
        bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not keep(*v.co)], context="VERTS")
        bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=0.04)
        bmesh.ops.scale(bm, vec=Vector((rx, ry, rz)), verts=bm.verts)
    return build


def rounded_cylinder(r, h, edge, segs=28):
    """An upright cylinder with its top and bottom rims rounded by `edge` (the classic Roblox head)."""
    def build(bm):
        bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r, radius2=r, depth=h)
        rims = [e for e in bm.edges if len(e.link_faces) == 2 and
                abs(e.link_faces[0].normal.z - e.link_faces[1].normal.z) > 0.9]
        bmesh.ops.bevel(bm, geom=rims, offset=edge, segments=4, affect="EDGES", profile=0.5, clamp_overlap=True)
    return build


def build_head(piece, bolt, style):
    hx, hy, hz = ref_center("Head")

    def face(z, front_y, width=1.0, curve=None):
        """Eyes and a smile on the face screen, front_y = the screen's front."""
        for side in (-1, 1):
            m = at(hx + side * 0.21 * width, front_y - 0.02, z + 0.07)
            if curve:  # follow a curved screen: sit on the circle of radius curve round the head's axis
                a = math.asin(side * 0.21 * width / curve)
                m = at(hx + math.sin(a) * curve, -math.cos(a) * curve - 0.02, z + 0.07, rz=math.degrees(a))
            piece("Head", "Eye").add(box(0.19 * width, 0.03, 0.24 * width, ch=0.05), m)
        piece("Head", "Eye").add(ring(0.11 * width, 0.16 * width, 0.03, 10, arc=(205, 335)),
                                 at(hx, front_y - 0.03, z - 0.06, rx=90))

    def ears(z, x, y=0.04, r=0.28):
        for side in (-1, 1):
            piece("Head", "Dark").add(cyl(r, r * 0.9, 0.16, 10), at(hx + side * x, y, z, ry=side * 90))
            piece("Head", "Steel").add(cyl(r * 0.55, r * 0.5, 0.08, 8), at(hx + side * (x + 0.1), y, z, ry=side * 90))
            bolt("Head", at(hx + side * (x + 0.14), y, z, rz=side * 90), 0.05)

    def hard_hat(base, rx, ry, rz, y=0.04, rim=None):
        """A hard hat: dome, centre ridge, rim, front brim, carry handle and the work light."""
        piece("Head", "Yellow").add(dome(rx, ry, rz, 24, 6), at(hx, y, base))
        piece("Head", "Yellow").add(dome(0.13, ry * 1.02, rz * 1.1, 8, 6), at(hx, y, base))
        if rim == "box":
            piece("Head", "Yellow").add(box(rx * 2.12, ry * 2.18, 0.08, ch=0.03), at(hx, y - 0.04, base))
        else:
            piece("Head", "Yellow").add(cyl(1, 1, 0.08, 28), at(hx, y, base) @ scaled(rx + 0.08, ry + 0.08, 1))
        piece("Head", "Yellow").add(box(rx * 1.5, 0.3, 0.07, ch=0.03, taper=(0.86, 1.0)),
                                    at(hx, y - ry - 0.14, base - 0.01, rx=-8))
        piece("Head", "Dark").add(box(0.24, ry * 0.72, 0.1, ch=0.03), at(hx, y + 0.04, base + rz * 1.29))
        for k in (-0.22, 0.32):
            piece("Head", "Dark").add(box(0.14, 0.1, 0.16), at(hx, y + k * ry / 0.88, base + rz * 1.14))
        lz = rz * 0.41
        ly = y - ry * math.sqrt(max(0.0, 1 - (lz / rz) ** 2)) - 0.08
        light = at(hx, ly, base + lz, rx=-18)
        piece("Head", "Dark").add(box(0.5, 0.26, 0.34, ch=0.05, inset=(0.05, 0.04, (0, -1, 0))), light)
        piece("Head", "Glow").add(box(0.38, 0.04, 0.22, ch=0.02), light @ at(0, -0.1, 0))

    # The collar under every head hides the lower corners of the body's head.
    piece("Head", "Dark").add(box(1.22, 1.22, 0.24, ch=0.06), at(hx, 0.0, 1.03))

    if style == "box":
        z = 1.62
        piece("Head", "Yellow").add(box(1.44, 1.3, 1.0, ch=0.12, inset=(0.09, 0.08, (0, -1, 0))), at(hx, 0.04, z))
        front = 0.04 - 0.65 + 0.08
        piece("Head", "Screen").add(box(1.08, 0.04, 0.64, ch=0.02), at(hx, front - 0.03, z))
        face(z, front - 0.03)
        ears(z, 0.78)
        hard_hat(2.08, 0.82, 0.88, 0.58, rim="box")
    elif style == "small":
        z = 1.56
        piece("Head", "Yellow").add(box(1.2, 1.1, 0.86, ch=0.12, inset=(0.08, 0.07, (0, -1, 0))), at(hx, 0.02, z))
        front = 0.02 - 0.55 + 0.07
        piece("Head", "Screen").add(box(0.88, 0.04, 0.52, ch=0.02), at(hx, front - 0.03, z))
        face(z, front - 0.03, 0.85)
        ears(z, 0.66, y=0.02, r=0.24)
        hard_hat(1.99, 0.7, 0.75, 0.5, y=0.02, rim="box")
    elif style == "round":
        z = 1.6
        piece("Head", "Yellow").add(dome(0.66, 0.64, 0.62, 28, 8), at(hx, 0.02, z))  # top half
        piece("Head", "Yellow").add(dome(0.66, 0.64, 0.5, 28, 8), at(hx, 0.02, z, rx=180))  # bottom, a little flatter
        visor = sphere_patch(0.675, 0.655, 0.6, lambda x, y, zz: y < -0.45 and abs(zz) < 0.62 and abs(x) < 0.78)
        piece("Head", "Screen").add(visor, at(hx, 0.02, z + 0.02))
        face(z + 0.02, -0.66, 0.85, curve=0.68)
        ears(z, 0.66, y=0.02, r=0.24)
        hard_hat(1.98, 0.72, 0.72, 0.5, y=0.02)
    elif style == "cylinder":
        z, r = 1.58, 0.6
        piece("Head", "Yellow").add(rounded_cylinder(r, 1.0, 0.16), at(hx, 0.0, z))
        piece("Head", "Screen").add(ring(r - 0.02, r + 0.03, 0.56, 14, arc=(222, 318)), at(hx, 0.0, z))
        face(z, -(r + 0.03), 0.85, curve=r + 0.04)
        ears(z, 0.6, y=0.0, r=0.24)
        hard_hat(2.08, 0.68, 0.68, 0.5, y=0.0)
    else:
        raise ValueError(style)


def build():
    sc = scene()
    root = bpy.data.collections.new("ConstructionMech")
    sc.collection.children.link(root)
    pieces = {}

    def piece(part, color):
        key = (part, color)
        if key not in pieces:
            pieces[key] = Piece(part, color)
        return pieces[key]

    def bolt(part, matrix, r=0.055):
        """A hex bolt head facing -Y (turn `matrix` to face it elsewhere)."""
        piece(part, "Trim").add(cyl(r, r * 0.8, 0.05, 6), matrix @ at(0, 0, 0, rx=90))

    def stripes(part, matrix, width, height, count, angle=35, bar="Yellow", back="Hazard", depth=0.03):
        """A hazard-stripe patch facing -Y: a black plate with `count` slanted `bar` bars kept inside it."""
        piece(part, back).add(box(width, depth, height), matrix)
        lean = height * math.tan(math.radians(angle))
        step = (width - lean) / count
        for k in range(count):
            x0 = -width / 2 + step * k
            s = step * 0.5
            pts = ((x0, -height / 2), (x0 + s, -height / 2), (x0 + s + lean, height / 2), (x0 + lean, height / 2))
            piece(part, bar).add(prism(pts, depth), matrix @ at(0, -depth * 0.4, 0))

    # The R15 body (reference boxes, exported for the offsets) and the dark mechanical body suit under the plates: it
    # stops short of each joint so nothing is shared across parts.
    for part, (x, y_up, z_back, sx, sy, sz) in REF.items():
        piece("REF_" + part, "Ref").add(box(sx, sz, sy), at(-x, z_back, y_up))
        # A dark suit just over each limb, so no skin or clothing shows between the plates; it spans only from joint to
        # joint (top, bottom in Blender Z) so its ends never poke out when the joint bends.
        span = {"UpperArm": (0.82, -0.2), "LowerArm": (0.02, -0.76), "UpperLeg": (-1.02, -1.84),
                "LowerLeg": (-1.8, -2.74)}.get(part.replace("Left", "").replace("Right", ""))
        if span:
            piece(part, "Dark").add(box(sx + 0.06, sz + 0.06, span[0] - span[1], ch=0.05),
                                    at(-x, z_back, (span[0] + span[1]) / 2))

    # ---------------------------------------------------------------- Head: hard hat, faceplate, ear pods, work light
    build_head(piece, bolt, HEAD_STYLE)

    # ------------------------------------------- Upper torso: one yellow shell down to the belt, back pack
    tx, ty, tz = ref_center("UpperTorso")
    piece("UpperTorso", "Dark").add(box(1.96, 1.06, 1.58, ch=0.08), at(tx, ty, 0.24))
    chest_z = 0.6
    # The yellow shell covers the whole torso, from the belt to the shoulders (the user: no grey belly), narrower at
    # the waist.
    piece("UpperTorso", "Yellow").add(box(2.0, 1.16, 1.64, ch=0.14, taper=(1.07, 1.17),
                                          inset=(0.08, 0.04, (0, -1, 0))), at(tx, -0.02, 0.26))
    # No chest emblem (the user took out the bridge, then the whole plate).
    for x, z in ((-0.86, 0.96), (0.86, 0.96), (-0.86, 0.26), (0.86, 0.26)):
        bolt("UpperTorso", at(tx + x, -0.69, z))
    # Back: a yellow pack with dark vents, and the hammer strapped across it.
    piece("UpperTorso", "Yellow").add(box(1.64, 0.34, 0.9, ch=0.12, inset=(0.08, 0.04, (0, 1, 0))), at(tx, 0.66, 0.42))
    for z in (0.26, 0.42, 0.58):
        piece("UpperTorso", "Dark").add(box(1.1, 0.04, 0.08, ch=0.015), at(tx, 0.8, z))
    hammer = at(tx, 0.96, 0.35, ry=-38)
    piece("UpperTorso", "Dark").add(cyl(0.1, 0.1, 3.0, 8), hammer)
    piece("UpperTorso", "Yellow").add(cyl(0.13, 0.13, 0.5, 8), hammer @ at(0, 0, -1.15))
    for z in (-0.86, -1.44):
        piece("UpperTorso", "Hazard").add(cyl(0.14, 0.14, 0.06, 8), hammer @ at(0, 0, z))
    head = hammer @ at(0, 0, 1.6, ry=90)
    piece("UpperTorso", "Steel").add(box(1.24, 0.72, 0.72, ch=0.1), head)
    for x in (-0.44, 0.44):
        piece("UpperTorso", "Dark").add(box(0.1, 0.76, 0.76, ch=0.02), head @ at(x, 0, 0))
    piece("UpperTorso", "Glow").add(box(0.5, 0.04, 0.18, ch=0.02), head @ at(0, 0.37, 0))
    for side in (-1, 1):  # the two straps holding it
        piece("UpperTorso", "Hazard").add(box(0.14, 0.12, 0.9, ch=0.02), at(tx + side * 0.5, 0.86, 0.5, ry=side * 20))

    # ------------------------------------------------------------- Lower torso: utility belt, pouches, wrench, hook
    lx, ly, lz = ref_center("LowerTorso")
    piece("LowerTorso", "Dark").add(box(1.98, 1.04, 0.36, ch=0.12), at(lx, ly, -0.77))
    for z in (-0.64, -0.92):
        piece("LowerTorso", "Steel").add(box(1.94, 1.06, 0.05, ch=0.015), at(lx, ly, z))
    piece("LowerTorso", "Trim").add(box(0.62, 0.12, 0.34, ch=0.04, inset=(0.06, 0.03, (0, -1, 0))), at(lx, -0.62, -0.78))
    piece("LowerTorso", "Yellow").add(box(0.4, 0.04, 0.16, ch=0.015), at(lx, -0.66, -0.78))
    for x in (-0.24, 0.24):
        bolt("LowerTorso", at(lx + x, -0.69, -0.78), 0.035)
    piece("LowerTorso", "Orange").add(box(0.4, 0.32, 0.42, ch=0.05), at(-0.62, -0.7, -0.84))
    piece("LowerTorso", "Orange").add(box(0.42, 0.34, 0.1, ch=0.03, shift=(0, -0.02)), at(-0.62, -0.72, -0.6))
    piece("LowerTorso", "Bronze").add(box(0.5, 0.28, 0.36, ch=0.05), at(-0.55, 0.66, -0.8))  # back pouch
    wrench = at(-0.56, -0.74, -0.44, ry=-14)  # standing in the pouch
    piece("LowerTorso", "Trim").add(box(0.1, 0.06, 0.46, ch=0.02), wrench)
    piece("LowerTorso", "Trim").add(ring(0.07, 0.15, 0.06, 10, arc=(125, 415)), wrench @ at(0, 0, 0.3, rx=90))
    # A carabiner on the left hip, on the belt's side where a lifted knee can't reach it.
    piece("LowerTorso", "Steel").add(box(0.08, 0.16, 0.14, ch=0.02), at(1.02, 0.0, -0.78))
    piece("LowerTorso", "Trim").add(ring(0.08, 0.13, 0.05, 10), at(1.06, 0.0, -0.96, rx=90, rz=90))

    for side, name in ((-1, "Right"), (1, "Left")):  # the character's right is -X
        out = side  # +1 points away from the body on this side
        # ------------------------------------------------------------------ Upper arm: pauldron over a dark sleeve
        ua = name + "UpperArm"
        ux, uy, uz = ref_center(ua)
        ux += out * 0.06
        piece(ua, "Dark").add(box(1.08, 1.08, 1.0, ch=0.08), at(ux, uy, 0.32))
        pz, px = 0.94, ux + out * 0.1
        piece(ua, "Yellow").add(box(1.26, 1.42, 1.0, ch=0.15, taper=(0.86, 0.9),
                                    inset=(0.09, 0.05, (out, 0, 0))), at(px, 0, pz))
        piece(ua, "Yellow").add(box(1.06, 1.22, 0.16, ch=0.05), at(px, 0, pz + 0.55))  # top cap
        outside = at(px + out * 0.6, 0, pz - 0.02, rz=out * 90)  # faces away from the body (local -Y)
        if side < 0:
            stripes(ua, outside, 0.98, 0.56, 4)
        else:
            piece(ua, "Dark").add(box(0.9, 0.03, 0.54, ch=0.02), outside)
            piece(ua, "Red").add(cyl(0.08, 0.08, 0.04, 10), outside @ at(0.24, -0.03, 0.08, rx=90))
            for x in (-0.3, -0.12):
                piece(ua, "Steel").add(box(0.1, 0.03, 0.36), outside @ at(x, -0.02, 0))
        for y in (-0.5, 0.5):
            bolt(ua, at(px + out * 0.56, y, pz + 0.32, rz=out * 90), 0.045)
        piece(ua, "Glow").add(box(0.7, 0.04, 0.09, ch=0.02), at(px, -0.73, pz - 0.38))

        # ------------------------------------------------------- Lower arm: elbow drum and a flared gauntlet
        la = name + "LowerArm"
        bx, by, bz = ref_center(la)
        bx += out * 0.1
        piece(la, "Dark").add(cyl(0.34, 0.34, 1.06, 10), at(bx, 0, 0.05, ry=90))  # turns about its own axis
        piece(la, "Steel").add(cyl(0.2, 0.2, 1.14, 8), at(bx, 0, 0.05, ry=90))
        piece(la, "Yellow").add(box(1.2, 1.24, 0.74, ch=0.13, taper=(0.88, 0.86),
                                    inset=(0.08, 0.05, (out, 0, 0))), at(bx, 0, -0.44))
        gside = at(bx + out * 0.6, 0, -0.46, rz=out * 90)
        piece(la, "Glow").add(box(0.56, 0.04, 0.3, ch=0.03), gside @ at(0, 0.02, 0))
        for x in (-0.38, 0.38):
            bolt(la, gside @ at(x, -0.01, 0.2), 0.04)
        piece(la, "Yellow").add(box(0.7, 0.1, 0.4, ch=0.04, inset=(0.05, 0.03, (0, -1, 0))), at(bx, -0.64, -0.46))
        piece(la, "Dark").add(box(1.2, 1.2, 0.12, ch=0.04), at(bx, 0, -0.84))  # wrist cuff

        # ------------------------------------------------------- Hand: a short yellow block, the end of the gauntlet
        # (the user: the gray fist reached half a stud past the real hand and made the arms look long). It covers the
        # hand from under the wrist cuff to the hand's bottom (-1.01), so the arm is as long as a plain R15 one.
        hd = name + "Hand"
        kx, ky, kz = ref_center(hd)
        piece(hd, "Yellow").add(box(1.16, 1.2, 0.24, ch=0.08), at(kx + out * 0.1, 0.0, -0.95))

        # ------------------------------------------------------- Upper leg: dark thigh, hip drum, octagon knee pad
        ul = name + "UpperLeg"
        gx, gy, gz = ref_center(ul)
        piece(ul, "Dark").add(box(0.94, 0.98, 0.7, ch=0.12, taper=(1.0, 0.96)), at(gx, 0, -1.44))
        piece(ul, "Steel").add(box(0.62, 0.1, 0.38, ch=0.04, inset=(0.05, 0.03, (0, -1, 0))), at(gx, -0.51, -1.4))
        knee = at(gx, -0.62, -1.78)
        piece(ul, "Yellow").add(prism(octagon(0.42, 0.33, 0.12), 0.22, ch=0.04, inset=(0.07, 0.05)), knee)
        piece(ul, "Dark").add(prism(octagon(0.28, 0.17, 0.06), 0.04), knee @ at(0, -0.05, 0))
        for x in (-0.2, 0.2):
            bolt(ul, knee @ at(x, -0.1, -0.22), 0.04)

        # ------------------------------------------------------- Lower leg: knee drum and a flared shin guard
        ll = name + "LowerLeg"
        sx, sy, sz = ref_center(ll)
        sx += out * 0.04
        piece(ll, "Dark").add(cyl(0.32, 0.32, 1.06, 10), at(sx, 0, -1.79, ry=90))
        piece(ll, "Yellow").add(box(1.04, 1.2, 0.84, ch=0.13, taper=(0.9, 0.84),
                                    inset=(0.08, 0.04, (0, -1, 0))), at(sx, 0, -2.27))
        stripes(ll, at(sx, -0.6, -2.42), 0.72, 0.2, 4)
        for x in (-0.36, 0.36):
            piece(ll, "Glow").add(box(0.16, 0.04, 0.1, ch=0.015), at(sx + x, -0.61, -2.6))
        piece(ll, "Yellow").add(box(0.08, 0.72, 0.5, ch=0.03), at(sx + out * 0.52, 0.02, -2.3))  # side fin
        bolt(ll, at(sx + out * 0.57, 0.02, -2.3, rz=out * 90), 0.045)

        # ------------------------------------------------------- Foot: oversized boot with a yellow toe cap
        ft = name + "Foot"
        fx_, fy_, fz_ = ref_center(ft)
        fx_ += out * 0.06
        piece(ft, "Dark").add(box(1.0, 1.8, 0.4, ch=0.1, taper=(0.92, 0.84), shift=(0, 0.1)), at(fx_, -0.24, -2.82))
        piece(ft, "Hazard").add(box(1.02, 1.84, 0.08, ch=0.03), at(fx_, -0.24, -3.0))  # sole
        piece(ft, "Yellow").add(box(0.86, 0.7, 0.24, ch=0.08, taper=(0.86, 0.7)), at(fx_, -0.72, -2.62))
        stripes(ft, at(fx_, -1.14, -2.86, rx=-8), 0.7, 0.14, 4)
        for x in (-0.4, 0.4):
            piece(ft, "Glow").add(box(0.08, 0.14, 0.08, ch=0.015), at(fx_ + x, -1.02, -2.74))
        piece(ft, "Yellow").add(box(0.76, 0.12, 0.3, ch=0.04), at(fx_, 0.58, -2.78))  # heel plate

    # Objects, one per (part, color), each in its part's collection with an ATTACH_ empty at the part's centre.
    counts, objects, cols = {}, [], {}

    def collection(name):
        if name not in cols:
            c = bpy.data.collections.new(name)
            root.children.link(c)
            cols[name] = c
        return cols[name]

    for part in REF:
        e = bpy.data.objects.new("ATTACH_" + part, None)
        e.empty_display_type, e.empty_display_size = "ARROWS", 0.3
        e.location = ref_center(part)
        collection("Armor_" + part).objects.link(e)
    for (part, color), pc in pieces.items():
        is_ref = part.startswith("REF_")
        counts[part] = counts.get(part, 0) + 1
        name = part if is_ref else f"{part}__{color}__{counts[part]}"
        mesh = bpy.data.meshes.new(name)
        pc.bm.to_mesh(mesh)
        pc.bm.free()
        mesh.materials.append(material(color))
        obj = bpy.data.objects.new(name, mesh)
        collection("R15_Reference" if is_ref else "Armor_" + part).objects.link(obj)
        if is_ref:
            obj.display_type = "WIRE"
        else:
            for poly in mesh.polygons:
                poly.use_smooth = True
            mesh.set_sharp_from_angle(angle=math.radians(SHARP_ANGLE))
            bev = obj.modifiers.new("Bevel", "BEVEL")
            bev.width, bev.segments, bev.limit_method, bev.angle_limit = 0.015, 1, "ANGLE", math.radians(30)
            bev.harden_normals = True
        objects.append(obj)
    return sc, objects


def pose_tree():
    """child part -> (joint, parent part)."""
    return {child: (joint, parent) for joint, (child, parent, _) in PIVOT.items()}


def chain(part):
    """The joints from the root down to `part`, root first."""
    tree, out = pose_tree(), []
    while part in tree:
        joint, parent = tree[part]
        out.insert(0, joint)
        part = parent
    return out


def world_matrices(angles):
    """Each part's matrix for a pose: angles = {joint: rotation Matrix about its pivot, in its parent's frame}."""
    mats = {}
    for part in REF:
        m = Matrix.Identity(4)
        for joint in chain(part):
            p = Vector(PIVOT[joint][2])
            rot = angles.get(joint, Matrix())
            m = m @ Matrix.Translation(p) @ rot @ Matrix.Translation(-p)
        mats[part] = m
    return mats


# Keyframes of Roblox's default R15 animations (KeyframeSequenceProvider in Studio, 2026-10-11): the extremes of walk
# (507777826), run (507767714), jump (507765000), fall (507767968), climb (507765644) and toolnone (507768375). Each
# joint's rotation is an axis-angle vector in degrees, in Roblox axes (+X on a hip or shoulder swings the limb forward).
R15_FRAMES = """
walk1: LE 64 0 0;LH -57 -5 -4;LK -40 0 0;LS 26 -10 -7;Ne 5 5 -5;RE 25 0 0;RH 47 -12 -2;RK 4 0 0;RS -32 5 13;Wa -6 -4 1
walk4: LE 35 -2 0;LH 65 4 -5;LK -118 0 0;LS 7 -10 -10;Ne 17 2 8;RE 8 1 0;RH 40 -7 6;RK -51 0 0;RS -5 6 13;Wa -12 -1 -6
walk5: LE 37 0 1;LH 102 2 -5;LK -109 0 0;LS -6 -9 -12;Ne 20 0 5;RE 17 1 0;RH 6 -7 6;RK -17 0 0;RS 4 7 13;Wa -16 1 -3
walk9: LE 17 0 3;LH 45 8 1;LK 4 0 0;LS -23 -6 -14;Ne 5 -5 7;RE 60 2 0;RH -62 -6 1;RK -33 0 0;RS 24 8 14;Wa -6 5 0
walk12: LE 8 0 2;LH 28 4 0;LK -51 0 0;LS -1 -8 -11;Ne 17 -3 0;RE 36 2 0;RH 74 -4 20;RK -123 0 0;RS 4 6 14;Wa -12 2 1
run3: LE 36 -2 0;LH 64 4 -5;LK -119 0 0;LS 7 -10 -10;Ne 19 1 7;RA 24 2 -3;RE 8 1 0;RH 42 -8 6;RK -59 0 0;RS -9 6 13;Wa -12 -1 -5
run4: LE 37 0 1;LH 98 1 -5;LK -108 0 0;LS -6 -9 -12;Ne 23 0 4;RA 9 1 -5;RE 17 1 0;RH 12 -7 5;RK -29 0 0;RS 2 7 13;Wa -16 1 -2
run10: LE 7 0 2;LH 30 4 -1;LK -55 0 0;LS -3 -8 -11;Ne 19 -2 0;RA 8 1 -1;RE 37 2 0;RH 74 -3 21;RK -132 0 0;RS 4 6 14;Wa -12 2 1
jump2: LA 13 0 1;LE 30 2 1;LH 48 2 -1;LK -95 0 0;LS -4 -8 -26;Ne -21 1 -2;RA 2 2 -8;RE 43 -4 -1;RH 72 8 14;RK -92 0 0;RS -16 7 20;Wa -5 2 4
jump7: LE 30 -1 0;LH 23 3 -2;LK -45 0 0;LS 115 8 -53;Ne 9 2 -1;RE 10 -2 0;RH 24 -7 1;RK -43 0 0;RS 112 5 25;Wa -1 -4 -3
fall1: LA 5 1 -2;LE 30 0 0;LH 44 3 -3;LK -65 0 0;LS 115 8 -53;RA 9 1 -3;RE 10 0 0;RH 46 -5 12;RK -75 0 0;RS 112 5 25;Wa -8 -3 -3
climb1: LA -23 -1 4;LE 4 0 0;LH 36 -1 -4;LK -23 0 0;LS 160 12 -8;Ne 32 -3 8;RA -10 2 -2;RE 29 0 0;RH 91 1 3;RK -91 0 0;RS 43 -25 5;Wa -17 0 -2
climb10: LA 12 0 1;LE 34 0 0;LH 75 3 -3;LK -101 0 0;LS 74 20 -11;Ne 30 10 -4;RA -22 1 -6;RE 32 -5 4;RH 46 5 5;RK -33 0 0;RS 138 -22 39;Wa -17 -5 2
climb20: LA -29 0 2;LE 74 1 -1;LH 50 -14 4;LK -31 0 0;LS 89 39 -38;Ne 30 -9 3;RA -12 1 -5;RE 51 0 0;RH 16 -13 7;RK -33 0 0;RS 101 -15 19;Wa -17 -4 0
toolnone: RE 13 0 0;RS 79 0 0
"""
SHORT = {"Wa": "Waist", "Ne": "Neck", "LS": "LeftShoulder", "RS": "RightShoulder", "LE": "LeftElbow", "RE": "RightElbow",
         "LW": "LeftWrist", "RW": "RightWrist", "LH": "LeftHip", "RH": "RightHip", "LK": "LeftKnee", "RK": "RightKnee",
         "LA": "LeftAnkle", "RA": "RightAnkle"}


def r15_poses():
    """R15_FRAMES as {frame: {joint: Blender rotation Matrix}}. Roblox (x, y, z) is Blender (-x, z, y), a rotation, so
    the rotation vector maps the same way."""
    poses = {}
    for line in R15_FRAMES.strip().splitlines():
        name, body = line.split(": ")
        pose = {}
        for item in body.split(";"):
            j, x, y, z = item.split()
            v = Vector((-float(x), float(z), float(y)))
            pose[SHORT[j]] = Matrix.Rotation(math.radians(v.length), 4, v.normalized()) if v.length else Matrix()
        poses[name] = pose
    return poses


def clearance(objects, poses=None, deep=0.06):
    """For each pose, how far armor sinks into the armor of another part: {(part, other part): (verts deeper than
    `deep`, deepest in studs)}. Vertices already inside at rest (mounting overlaps) don't count. Inside = the nearest
    surface of the other part faces away from the vertex."""
    poses = poses or r15_poses()
    armor = [o for o in objects if not o.name.startswith("REF_")]
    deps = bpy.context.evaluated_depsgraph_get()
    base = {}
    for o in armor:
        ev = o.evaluated_get(deps)
        mesh = ev.to_mesh()
        base.setdefault(o.name.split("__")[0], []).append(
            ([o.matrix_world @ v.co for v in mesh.vertices], [tuple(p.vertices) for p in mesh.polygons]))
        ev.to_mesh_clear()

    def enclosed(tree, v):
        """Ray parity, so paper-thin plates (whose nearest face can point either way) don't count as solid."""
        for direction in (Vector((0.31, 0.52, 0.8)), Vector((-0.6, 0.27, -0.75)), Vector((0.7, -0.68, 0.2))):
            hits, origin = 0, v.copy()
            while True:
                loc, _, _, _ = tree.ray_cast(origin, direction, 50)
                if loc is None:
                    break
                hits += 1
                origin = loc + direction * 1e-4
            if hits % 2:
                return True
        return False

    def inside(mats):
        verts = {part: [[mats[part] @ v for v in vs] for vs, _ in objs] for part, objs in base.items()}
        trees = {part: [BVHTree.FromPolygons(vs, polys) for vs, (_, polys) in zip(verts[part], objs)]
                 for part, objs in base.items()}
        out = {}
        for a in base:
            for b in base:
                if a == b:
                    continue
                for oi, vs in enumerate(verts[a]):
                    for vi, v in enumerate(vs):
                        d = 0.0
                        for t in trees[b]:
                            hit, normal, _, dist = t.find_nearest(v, deep * 20)
                            if hit is not None and (v - hit).dot(normal) < 0 and enclosed(t, v):
                                d = max(d, dist)
                        if d > 0:
                            out[(a, b, oi, vi)] = d
        return out

    rest = inside(world_matrices({}))
    report = {}
    for pose, angles in poses.items():
        found = {}
        for (a, b, oi, vi), d in inside(world_matrices(angles)).items():
            if d > deep and (a, b, oi, vi) not in rest:
                n, worst = found.get((a, b), (0, 0.0))
                found[(a, b)] = (n + 1, max(worst, round(d, 2)))
        report[pose] = dict(sorted(found.items(), key=lambda kv: -kv[1][1]))
    return report


def export(sc, objects, path):
    window = bpy.context.window
    old = window.scene
    window.scene = sc
    try:
        bpy.ops.object.select_all(action="DESELECT")
        for o in objects:
            o.hide_set(False)  # hidden objects can't be selected, and the REF_ boxes must go in the file
            o.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, use_mesh_modifiers=True,
                                 apply_scale_options="FBX_SCALE_UNITS", mesh_smooth_type="OFF")
    finally:
        window.scene = old


SC, OBJECTS = build()
print(f"built {len(OBJECTS)} objects in scene {SC.name}")

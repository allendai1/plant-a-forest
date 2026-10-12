"""Builds the canyon's far scenery tiles from tools/canyon_out/farfield.npz (tools/canyon_farfield.py) and exports
them as one FBX for upload (run inside Blender, 2026-10-10).

In Blender:  exec(open(r"<repo>/tools/blender/build_farfield.py").read()); build(r"<repo>")
(Zion, 2026-10-11: build(r"<repo>", "zion_out", part=(1, 2)) and part=(2, 2), from
CANYON_PLACE=zion python tools/canyon_farfield.py: two files, FarCanyon_1of2.fbx and FarCanyon_2of2.fbx, because one upload
of Zion's 1,212 tiles lost 292 of them; a single upload seems to keep about 920 meshes at most.)
It writes <repo>/tools/canyon_out/FarCanyon.fbx, smooth shaded with the normals from farfield.npz. Each tile is its own mesh object named Far_XX_ZZ, centered on its box
(tools/build_farfield.luau puts it back in place from farfield.json). Roblox axes (x, y up, z) become Blender's
(-x, z, y up): Studio's FBX import turns Blender +X into Roblox -X (docs/HANDOFF.md, art pipeline).
"""

import math
import os

import bmesh
import bpy
import numpy as np

COLLECTION = "PTF_FarCanyon"
# Flat stretches (plateaus, the rock layers' ledges, the river) are merged into big faces: a point goes only where the
# faces around it bend more than this. No point moves, so the shape is the same with far fewer triangles (the tiles
# over the terrain's area are fine-grained, tools/canyon_farfield.py TERRAIN_STEP, 2026-10-10).
FLAT_DEGREES = 1.0


def build(repo, folder="canyon_out", prefix=None, part=None):
    """part = (k, n): only the k-th of n equal slices of the tiles (k from 1), written to FarCanyon_<k>of<n>.fbx."""
    out = os.path.join(repo, "tools", folder)
    data = np.load(os.path.join(out, "farfield.npz"))
    coll = bpy.data.collections.get(COLLECTION)
    if coll:
        for obj in list(coll.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
    else:
        coll = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(coll)

    verts, faces, uvs, normals = data["verts"], data["faces"], data["uvs"], data["normals"]
    v0 = f0 = 0
    objects = []
    count = len(data["names"])
    for index, (name, vc, fc) in enumerate(zip(data["names"], data["vcount"], data["fcount"])):
        tv = verts[v0 : v0 + vc]
        tf = faces[f0 : f0 + fc]
        tuv = uvs[v0 : v0 + vc]
        tn = normals[v0 : v0 + vc]
        v0 += vc
        f0 += fc
        if prefix and not str(name).startswith(prefix + "_"):
            continue
        if part and not ((part[0] - 1) * count // part[1] <= index < part[0] * count // part[1]):
            continue
        mesh = bpy.data.meshes.new(str(name))
        blender_verts = [(float(-x), float(z), float(y)) for x, y, z in tv]
        mesh.from_pydata(blender_verts, [], [tuple(int(i) for i in f) for f in tf])
        uv_layer = mesh.uv_layers.new(name="UVMap")
        loop_vertex = np.zeros(len(mesh.loops), dtype=np.int64)
        mesh.loops.foreach_get("vertex_index", loop_vertex)
        loop_uv = tuv[loop_vertex]
        # Roblox reads V from the top of the image; Blender's V runs up, so flip it.
        loop_uv = np.stack([loop_uv[:, 0], 1.0 - loop_uv[:, 1]], 1).astype(np.float32)
        uv_layer.data.foreach_set("uv", loop_uv.ravel())
        mesh.validate()
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(FLAT_DEGREES), use_dissolve_boundaries=False,
                                 verts=bm.verts[:], edges=bm.edges[:])
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
        bm.to_mesh(mesh)
        bm.free()
        # Smooth shading from the ground's own normals (computed across tile edges, so neighbors match), axes like the
        # vertices; looked up by position, since merging renumbered the points.
        normal_at = {}
        for (x, y, z), (nx, ny, nz) in zip(tv, tn):
            normal_at[(round(float(-x), 2), round(float(z), 2), round(float(y), 2))] = (float(-nx), float(nz), float(ny))
        mesh.shade_smooth()
        mesh.normals_split_custom_set_from_vertices(
            [normal_at.get((round(v.co.x, 2), round(v.co.y, 2), round(v.co.z, 2)), (0.0, 0.0, 1.0)) for v in mesh.vertices])
        mesh.update()
        obj = bpy.data.objects.new(str(name), mesh)
        coll.objects.link(obj)
        objects.append(obj)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    path = os.path.join(out, f"FarCanyon_{prefix}.fbx" if prefix else f"FarCanyon_{part[0]}of{part[1]}.fbx" if part else "FarCanyon.fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"},
                             apply_scale_options="FBX_SCALE_UNITS", mesh_smooth_type="OFF")
    triangles = sum(len(obj.data.polygons) for obj in objects)
    print(f"{len(objects)} tiles, {triangles} triangles -> {path} ({os.path.getsize(path) // 1024} KB)")

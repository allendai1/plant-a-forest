"""The canyon's far scenery: low-detail mesh tiles of the whole canyon, out to the horizon (2026-10-10).

Players' devices only load terrain within about 1,000 studs (StreamingEnabled), so beyond that the canyon used to vanish,
and the terrain map itself ends 2,000 studs to each side. These tiles are the same ground (tools/canyon_heightmap.py
Canyon.heights, so they line up with the terrain) over a much bigger area, as plain meshes that are always loaded
(the FarCanyon model is Persistent). Inside the terrain's area they sit SINK studs lower, so the real terrain covers
them wherever it's loaded; outside it they rise back to the true height.

Outputs, in tools/canyon_out/:
- farfield.npz: per tile, its vertices (Roblox axes, relative to the tile's box center), triangles, UVs and normals, for
  tools/blender/build_farfield.py, which makes the FBX to upload.
- farfield.json: per tile, its name and box center (Roblox coordinates), for tools/build_farfield.luau.
- farfield_colors.png: the color strip the tiles use (TextureID): one color per height (V), the terrain's own rock
  layers, plateau ground and river colors. A vertex's U (rock or flat, from its slope) no longer changes anything.

Usage: python tools/canyon_farfield.py   (CANYON_PLACE=zion or verdon: its own folders and colors, FAR_COLORS)
"""

import json
import pathlib
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import canyon_heightmap as ch  # noqa: E402

TILE = 1024  # studs per tile side (a MeshPart can be at most 2,048 on any axis)
X_RANGE = (-8192, 6144)
Z_RANGE = (-8192, 8192)
# Past those, out to the horizon (2026-10-10, the user's note that the canyon didn't seem to go on for miles): bigger,
# coarser tiles, so the canyon runs on into the haze. The elevation tiles last to about 15,000 studs along the canyon;
# past them the land carries on as its mirror image (canyon_heightmap.mirror).
OUTER_TILE = 2048
OUTER_X = (-10240, 8192)
OUTER_Z = (-20480, 20480)
OUTER_STEP = 128
TERRAIN_STEP = 16  # studs between vertices in tiles over the terrain's area (see SINK) ...
NEAR_STEP = 32  # ... near it ...
FAR_STEP = 64  # ... and farther out
NEAR_MARGIN = 1536  # tiles within this of the terrain's area get NEAR_STEP
# Over the terrain's area the tiles hide just under it: wherever a player's device has the terrain loaded it covers
# them, and past that (it only loads about 1,000 studs around a player) they show in its place. Each vertex takes the
# lowest terrain height within one step around it, so the mesh never pokes through the terrain between its vertices,
# then sinks SINK more. That shrinks cliffs and mesas by a step and lowers them a little, so the step is fine there
# (TERRAIN_STEP) and the sink small: the tiles keep the terrain's shape where they take over (it was 32 and 12, and
# the join showed, the user's note 2026-10-10).
SINK = 3
FINE = 8  # the terrain's own sample spacing (canyon_heightmap SAMPLE), for finding those lowest heights
SINK_FADE = 96  # back to the true height this far outside the terrain's area
SKIRT = 40  # each tile's edges drop this far, hiding cracks between tiles
MAX_SPAN = 1990  # a tile whose heights span more (plus its skirt: the 2,048 limit) is split into four

STRIP = (64, 1024)
# Colors by height, exactly the terrain's (tools/canyon_terrain.luau PLACES), so the scenery and the terrain read as one
# canyon. One color per height across the whole strip: when the strip had rock on the left and flat ground on the right
# (picked by slope), triangles mixing the two painted streaks through the layers, and the shrunken copies Roblox draws
# at a distance averaged the halves into muddier colors (2026-10-10, the user's note).
# Per place: the strip's height range (top, bottom), the rock layers (thickness from the rim down, color), the color
# above the rim, the plateau ground, the floor near the river (studs over it, color; None for none) and the water.
FAR_COLORS = {
    "grand": {
        "range": (1300.0, -2400.0),
        "rock": [
            (110, (226, 202, 160)),  # Kaibab limestone
            (150, (222, 170, 112)),  # Coconino sandstone
            (190, (176, 88, 58)),  # Hermit shale
            (370, (166, 76, 52)),  # Supai
            (350, (170, 112, 82)),  # Redwall
            (330, (110, 98, 84)),  # Tonto
            (10_000, (62, 54, 56)),  # Vishnu schist
        ],
        "above_rim": (176, 88, 58),  # red Moenkopi slopes (the terrain's Mud)
        "ground": (198, 166, 120),  # the plateaus around rim height (the terrain's Ground)
        "floor": None,
        "water": (70, 120, 100),
    },
    "zion": {  # (2026-10-11) the Navajo walls: cream, salmon, deep red; Kayenta ledges; the green valley floor
        "range": (1300.0, -2500.0),
        "rock": [
            (520, (238, 226, 204)),
            (620, (232, 168, 126)),
            (560, (192, 88, 58)),
            (300, (150, 72, 66)),
            (10_000, (168, 104, 76)),
        ],
        "above_rim": (238, 226, 204),
        # Above the rim (studs over it, color), highest last: Zion's high country is cream domes to about the terrain's
        # top, pinkish salmon domes higher, then dark pine forest on the highest plateaus (one cream band looked like
        # flat grey in the haze, 2026-10-11). Heights over the strip's top (1,300) take its top color, the forest.
        "above": [(750, (238, 226, 204)), (1150, (220, 160, 128)), (10_000, (96, 112, 78))],
        "ground": (214, 194, 160),
        "floor": (60, (104, 138, 66)),
        "water": (88, 140, 118),
        # (2026-10-11: a "far_floor" raising distant side-canyon floors was taken out: its straight band missed the real
        # canyon's bends and cut flat shelves with straight walls into it, the user's screenshot. The tile count it saved
        # is handled by uploading the tiles in two parts instead, tools/blender/build_farfield.py.)
    },
    "verdon": {  # (2026-10-11) white then grey limestone, ochre streaks; wooded hills above; green banks, jade water
        "range": (1300.0, -2200.0),
        "rock": [
            (480, (238, 234, 224)),
            (520, (200, 194, 182)),
            (260, (214, 176, 132)),
            (420, (176, 166, 150)),
            (10_000, (150, 140, 126)),
        ],
        "above_rim": (96, 116, 64),
        "above": [(10_000, (96, 116, 64))],
        "ground": (128, 134, 86),
        "floor": (120, (86, 120, 62)),
        "water": (56, 170, 150),
        # Its walls are the steepest: the lowest-ground-within-a-step sink put the tiles up to ~50 studs inside them,
        # which showed as holes and dents where the terrain had only partly streamed in (the user's screenshot,
        # 2026-10-11). Fitted instead (fit_under).
        "fit_walls": True,
    },
}
COLORS = FAR_COLORS[ch.PLACE_NAME]
Y_TOP, Y_BOTTOM = COLORS["range"]  # the color strip's range
ROCK = COLORS["rock"]
ABOVE_RIM = 50
ABOVE_RIM_COLOR = COLORS["above_rim"]
GROUND = COLORS["ground"]
GROUND_BAND = (-15, ABOVE_RIM)  # heights (relative to the rim) that are plateau ground
WATER = COLORS["water"]
FLAT_SLOPE = 0.45


def fit_under(canyon, xs: np.ndarray, zs: np.ndarray, step: float) -> np.ndarray:
    """Vertex heights for a tile over the terrain that stay just under it but hug it (2026-10-11, the Verdon): each vertex
    starts at the true height and is lowered only by how far the terrain dips under the mesh in the cells around it
    (the mesh between vertices is their bilinear blend, plus a cell's saddle term for its two triangles), then SINK. A
    steep but even wall keeps its true place; only bumps and edges between vertices push the mesh down."""
    k = int(step // FINE)
    fx = np.arange(xs[0], xs[-1] + 0.1, FINE)
    fz = np.arange(zs[0], zs[-1] + 0.1, FINE)
    fine = canyon.heights(*np.meshgrid(fx, fz))
    true = fine[::k, ::k]
    nz, nx = true.shape
    dip = np.zeros((nz - 1, nx - 1))
    for a in range(k + 1):  # along z within a cell
        for b in range(k + 1):  # along x
            t, u = a / k, b / k
            blend = (
                true[:-1, :-1] * (1 - t) * (1 - u)
                + true[:-1, 1:] * (1 - t) * u
                + true[1:, :-1] * t * (1 - u)
                + true[1:, 1:] * t * u
            )
            dip = np.maximum(dip, blend - fine[a::k][: nz - 1][:, b::k][:, : nx - 1])
    dip += np.abs(true[:-1, :-1] - true[:-1, 1:] - true[1:, :-1] + true[1:, 1:]) / 4
    lower = np.zeros((nz, nx))
    for oz, ox in ((0, 0), (0, 1), (1, 0), (1, 1)):  # each vertex: the most any of its cells needs
        view = lower[oz : oz + nz - 1, ox : ox + nx - 1]
        np.maximum(view, dip, out=view)
    return true - lower - SINK


def color_at(y: float, river_y: float) -> tuple:
    if y <= river_y + 2:
        return WATER
    if COLORS["floor"] and y <= river_y + COLORS["floor"][0]:
        return COLORS["floor"][1]
    rel = y - ch.TOP_Y
    if rel > ABOVE_RIM:
        for top, color in COLORS.get("above", []):
            if rel < top:
                return color
        return ABOVE_RIM_COLOR
    if rel > GROUND_BAND[0]:
        return GROUND
    depth = -rel
    for thickness, color in ROCK:
        if depth < thickness:
            return color
        depth -= thickness
    return ROCK[-1][1]


def color_strip(river_y: float) -> Image.Image:
    """The color for each height, the same across the strip's whole width (U doesn't matter)."""
    w, h = STRIP
    img = np.zeros((h, w, 3), dtype=np.uint8)
    for row in range(h):
        img[row, :] = color_at(Y_TOP + (Y_BOTTOM - Y_TOP) * (row + 0.5) / h, river_y)
    return Image.fromarray(img)


def make_tile(canyon, river_y: float, tx: float, tz: float, size: float, step: float, name: str, tiles: list, meta: list):
    """One tile's mesh (size studs square from (tx, tz)), or four smaller ones when its heights span more than a
    MeshPart may be tall (a tile with both the rim and the river in it). Heights are worked out one step beyond the
    tile's edges too, so each vertex's normal (smooth shading) comes from its neighbors on both sides and matches the
    tile next door."""
    xs = np.arange(tx - step, tx + size + step + 0.1, step, dtype=np.float64)
    zs = np.arange(tz - step, tz + size + step + 0.1, step, dtype=np.float64)
    X, Z = np.meshgrid(xs, zs)
    Y = canyon.heights(X, Z)
    dx = np.maximum(np.maximum(ch.X_MIN - X, X - ch.X_MAX), 0)
    dz = np.maximum(np.maximum(ch.Z_MIN - Z, Z - ch.Z_MAX), 0)
    inside = 1 - ch.smoothstep(0, SINK_FADE, np.hypot(dx, dz))
    if inside.max() > 0 and COLORS.get("fit_walls"):
        Y = Y * (1 - inside) + fit_under(canyon, xs, zs, step) * inside
    elif inside.max() > 0:
        # Under the terrain inside its area: each vertex takes the lowest ground within one step around it (sampled at
        # the terrain's 8 studs), so the coarse mesh never cuts above the detailed terrain between its vertices, then
        # sinks SINK more. Back to the true height outside the terrain's area.
        fx = np.arange(tx - 2 * step, tx + size + 2 * step + 0.1, FINE)
        fz = np.arange(tz - 2 * step, tz + size + 2 * step + 0.1, FINE)
        low = canyon.heights(*np.meshgrid(fx, fz))
        r = int(step // FINE)
        for axis in (0, 1):  # a separable sliding minimum, window 2r+1
            lowest = low.copy()
            for k in range(1, r + 1):
                lowest = np.minimum(lowest, np.roll(low, k, axis))
                lowest = np.minimum(lowest, np.roll(low, -k, axis))
            low = lowest
        ix = np.round((X - fx[0]) / FINE).astype(int)
        iz = np.round((Z - fz[0]) / FINE).astype(int)
        Y = Y * (1 - inside) + (low[iz, ix] - SINK) * inside
    Y = np.maximum(Y, river_y)  # the river is the floor (colored blue)
    # Normals from the heights on both sides of each vertex (central differences over the padded grid).
    dydx = (Y[1:-1, 2:] - Y[1:-1, :-2]) / (2 * step)
    dydz = (Y[2:, 1:-1] - Y[:-2, 1:-1]) / (2 * step)
    normals = np.stack([-dydx, np.ones_like(dydx), -dydz], -1)
    normals /= np.linalg.norm(normals, axis=-1, keepdims=True)
    X, Z, Y = X[1:-1, 1:-1], Z[1:-1, 1:-1], Y[1:-1, 1:-1]
    if Y.max() - Y.min() > MAX_SPAN and size > step * 2:
        half = size / 2
        for i, (ox, oz) in enumerate(((0, 0), (half, 0), (0, half), (half, half))):
            make_tile(canyon, river_y, tx + ox, tz + oz, half, step, f"{name}_{i}", tiles, meta)
        return
    if Y.max() - Y.min() > MAX_SPAN:  # too small to split again: raise its lowest points instead
        Y = np.maximum(Y, Y.max() - MAX_SPAN)
    flat = normals[..., 1] > 1 / np.sqrt(1 + FLAT_SLOPE**2)  # gentler than FLAT_SLOPE
    nz_, nx_ = Y.shape
    # Vertices (Roblox axes), then a skirt ring along the border.
    verts = np.stack([X.ravel(), Y.ravel(), Z.ravel()], 1)
    u = np.where(flat.ravel(), 0.75, 0.25)
    v = (Y_TOP - Y.ravel()) / (Y_TOP - Y_BOTTOM)
    faces = []
    idx = np.arange(nx_ * nz_).reshape(nz_, nx_)
    a, b = idx[:-1, :-1].ravel(), idx[:-1, 1:].ravel()
    c, d = idx[1:, :-1].ravel(), idx[1:, 1:].ravel()
    faces.append(np.stack([a, c, b], 1))
    faces.append(np.stack([b, c, d], 1))
    border = np.concatenate([idx[0, :], idx[1:, -1], idx[-1, -2::-1], idx[-2:0:-1, 0]])
    skirt = verts[border] - np.array([0, SKIRT, 0])
    base = len(verts)
    verts = np.concatenate([verts, skirt])
    vnormals = normals.reshape(-1, 3)
    vnormals = np.concatenate([vnormals, vnormals[border]])  # the skirt shades like the edge above it
    u = np.concatenate([u, u[border]])
    v = np.concatenate([v, (Y_TOP - skirt[:, 1]) / (Y_TOP - Y_BOTTOM)])
    ring = np.arange(len(border))
    top0, top1 = border, np.roll(border, -1)
    bot0, bot1 = base + ring, base + np.roll(ring, -1)
    faces.append(np.stack([top0, bot0, top1], 1))
    faces.append(np.stack([top1, bot0, bot1], 1))
    faces = np.concatenate(faces).astype(np.int32)
    lo, hi = verts.min(0), verts.max(0)
    center = (lo + hi) / 2
    tiles.append(
        (
            name,
            (verts - center).astype(np.float32),
            faces,
            np.stack([u, np.clip(v, 0, 1)], 1).astype(np.float32),
            vnormals.astype(np.float32),
        )
    )
    meta.append({"name": name, "center": [round(float(c_), 3) for c_ in center], "size": [round(float(s_), 3) for s_ in hi - lo]})


def main() -> None:
    root = pathlib.Path(__file__).parent
    out = ch.OUT_DIR
    out.mkdir(exist_ok=True)
    canyon = ch.Canyon(ch.DEM_DIR)
    # The river's height from the terrain's heightmap header, so the blue band matches the terrain's water.
    header = (out / "heightmap.txt").open().readline().split()
    river_y = float(header[5])
    color_strip(river_y).save(out / "farfield_colors.png")

    def within(tx: float, tz: float, size: float, margin: float) -> bool:
        return (
            tx + size > ch.X_MIN - margin
            and tx < ch.X_MAX + margin
            and tz + size > ch.Z_MIN - margin
            and tz < ch.Z_MAX + margin
        )

    tiles, meta = [], []
    for tx in range(X_RANGE[0], X_RANGE[1], TILE):
        for tz in range(Z_RANGE[0], Z_RANGE[1], TILE):
            step = TERRAIN_STEP if within(tx, tz, TILE, SINK_FADE) else NEAR_STEP if within(tx, tz, TILE, NEAR_MARGIN) else FAR_STEP
            name = f"Far_{(tx - X_RANGE[0]) // TILE:02d}_{(tz - Z_RANGE[0]) // TILE:02d}"
            make_tile(canyon, river_y, tx, tz, TILE, step, name, tiles, meta)
    for tx in range(OUTER_X[0], OUTER_X[1], OUTER_TILE):
        for tz in range(OUTER_Z[0], OUTER_Z[1], OUTER_TILE):
            if X_RANGE[0] <= tx < X_RANGE[1] and Z_RANGE[0] <= tz < Z_RANGE[1]:
                continue  # the finer tiles cover it
            name = f"Out_{(tx - OUTER_X[0]) // OUTER_TILE:02d}_{(tz - OUTER_Z[0]) // OUTER_TILE:02d}"
            make_tile(canyon, river_y, tx, tz, OUTER_TILE, OUTER_STEP, name, tiles, meta)

    np.savez_compressed(
        out / "farfield.npz",
        names=np.array([t[0] for t in tiles]),
        verts=np.concatenate([t[1] for t in tiles]),
        faces=np.concatenate([t[2] for t in tiles]),
        uvs=np.concatenate([t[3] for t in tiles]),
        normals=np.concatenate([t[4] for t in tiles]),
        vcount=np.array([len(t[1]) for t in tiles]),
        fcount=np.array([len(t[2]) for t in tiles]),
    )
    (out / "farfield.json").write_text(json.dumps(meta))

    # The road (canyon_heightmap ROAD) for tools/build_site.luau: its middle every 16 studs with the graded height, and
    # the height of the far scenery under it (sunk under the terrain's area like the tiles), for road strips past the
    # terrain and for parking the trucks on it.
    road = canyon.road
    points = []
    for i in range(0, len(road["x"]), 2):
        x, z, h = float(road["x"][i]), float(road["z"][i]), float(road["h"][i])
        dx = max(ch.X_MIN - x, x - ch.X_MAX, 0.0)
        dz = max(ch.Z_MIN - z, z - ch.Z_MAX, 0.0)
        inside = float(1 - ch.smoothstep(0, SINK_FADE, np.array(np.hypot(dx, dz))))
        mesh = h
        if inside > 0:
            wx, wz = np.meshgrid(np.arange(x - NEAR_STEP, x + NEAR_STEP + 0.1, FINE), np.arange(z - NEAR_STEP, z + NEAR_STEP + 0.1, FINE))
            low = float(canyon.heights(wx, wz).min())
            mesh = h * (1 - inside) + (low - SINK) * inside
        points.append([round(x, 1), round(z, 1), round(h, 2), round(mesh, 2)])
    (out / "road.json").write_text(json.dumps({"half": ch.ROAD["Half"], "terrainEndX": ch.X_MAX, "points": points}))
    total = sum(len(t[2]) for t in tiles)
    print(f"{len(tiles)} tiles, {total} triangles, river {river_y:.0f} -> {out}")


if __name__ == "__main__":
    main()

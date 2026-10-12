"""Turn real Grand Canyon elevation tiles into the game's canyon heightmap (2026-10-10).

Input: a folder of Terrarium elevation tiles (AWS Terrain Tiles, s3://elevation-tiles-prod/terrarium/13/x/y.png,
built from USGS data; attribution "Terrain data: Mapzen / AWS Terrain Tiles, USGS"), zoom 13, x 1522-1524,
y 3210-3212: about 12 x 12 km around Toroweap Overlook, where a sheer inner gorge cuts between two flat benches.

What it does:
1. Stitches the tiles and decodes the heights (meters).
2. Finds the river near the overlook and turns the canyon so the river runs along the game's Z axis, with the
   northwest bench (flat, about 1,390 m) as the near rim where camp is and the southeast side as the far rim.
3. Scales it so the gorge is exactly one full bridge wide (GAP studs, rim to rim along the bridge line) and
   exaggerates the depth (V_SCALE studs per meter).
4. Shapes it for the game: stepped rock-layer ledges (the real 15 m data stretched this far is smooth), a little
   noise, the flat camp plateau around the hub, a clear line under the bridge and a flat landing on the far rim.
   (Buttes for the shorter first bridges were taken out on 2026-10-10: every bridge now goes all the way across.)
5. Writes the heightmap for tools/build_canyon.luau: one height per SAMPLE studs, as 4 hex digits each
   (round(y * 4) + 32768), rows along Z from Z_MIN, columns along X from X_MIN, after a header line.

Usage: python tools/canyon_heightmap.py [tiles folder] [out file]
  (defaults: the place's tiles folder, kept in the repo, and <its out folder>/heightmap.txt)
Also writes a shaded preview PNG next to the output.

More maps (2026-10-11, the user's ask: Zion next): the environment variable CANYON_PLACE picks the place (PLACES below;
default "grand", the Grand Canyon, whose output is unchanged). Each place has its own tiles and out folder, so
tools/canyon_farfield.py and the Studio scripts work the same way for any of them.
"""

import math
import os
import pathlib
import sys

import numpy as np
from PIL import Image

# The places (the real canyon each map is cut from). xs/ys: the zoom-13 tiles, stitched in this order; anchor: a point
# on the river where the bridge crosses, in pixels of the stitched image; river: its rough direction there (pixels);
# far: which way the far rim lies from camp (pixels, any length): it picks camp's side; bench: where to read the
# rims' plateau height, in pixels out from the river. The rest are this place's rock layers and river.
PLACES = {
    "grand": {  # Toroweap Overlook, Grand Canyon: camp on the northwest bench, the bridge crossing to the South Rim
        "dem": "canyon_dem", "out": "canyon_out", "lat": 36.2,
        "xs": (1522, 1523, 1524), "ys": (3210, 3211, 3212),
        "anchor": (333.0, 212.0), "river": (600.0, -390.0), "far": (0.0, 1.0), "bench": (60, 120),
        "terrace": (70.0, 2.6, 0.75), "river_level": (6.0, 10.0), "v_scale": 2.6, "backdrop": (300.0, 3.5),
        "channel": None,
    },
    # Zion Canyon at Zion Lodge (2026-10-11): the deepest stretch of the main canyon, 748 m deep and 1,710 m rim to
    # rim. Camp on the east side, the bridge crossing west over the Virgin River's green floor. Its walls are big
    # single cliffs (Navajo sandstone), so fewer, gentler rock layers than the Grand Canyon's ledges. Wider for its
    # depth than Toroweap, so its height is stretched more (3.6 studs a meter): towering, nearly vertical walls, about
    # 2,350 studs deep, which is what makes it feel unlike the Grand Canyon. The land behind the far rim (side canyons)
    # is squeezed less, so it doesn't turn spiky.
    "zion": {
        "dem": "zion_dem", "out": "zion_out", "lat": 37.25,
        "xs": (1524, 1525, 1526, 1527), "ys": (3179, 3180, 3181, 3182),
        "anchor": (407.0, 617.0), "river": (123.0, -294.0), "far": (-1.0, 0.0), "bench": (60, 120),
        # (Its terrain was built with the Grand Canyon's rock layers and river level, (70, 2.6, 0.75) and (6, 10), which
        # overrode the (140, 2.2, 0.3) and (2, 0) meant here; kept so it rebuilds the same. The channel sets its river.)
        "terrace": (70.0, 2.6, 0.75), "river_level": (6.0, 10.0), "v_scale": 3.6, "backdrop": (300.0, 2.0),
        # The Virgin River: a narrow stream winding over the flat green floor (the floor is too flat for the river to
        # show in 15 m data: filling its lowest part flooded the whole floor). A channel this wide (half, studs) and deep
        # is carved along the floor's lowest line. The water sits WATER_BELOW studs under the floor's typical height, the
        # floor's few lower dips are filled to just above it, and the channel is cut to `depth` under the water.
        "channel": (28.0, 8.0),
        # A ravine cuts into the real west wall right under the landing, and the bridgehead's cliff cut deepened it: from
        # camp it read as an arch-shaped hole under the town (2026-10-11, the user's screenshot). Filled up to the cliff's
        # profile within this many studs of the bridge's line (full, then fading out) and out from the rim (full, fading).
        "fill_far": (250.0, 450.0, 150.0, 260.0),
    },
    # The Verdon Gorge, Provence (2026-10-11, replacing Bryce): the narrow, deep corridor of the Grand Canyon du Verdon
    # above La Mescla, where the Artuby joins: sheer white limestone walls about 580 m deep and 1.1 km rim to rim, the
    # jade-green river at the bottom. Camp on the flat east plateau, the bridge crossing west to the far rim, where the
    # hills behind climb another 250 m (the rims are read close to the gorge: bench 35-50 px). Limestone: tall sheer walls
    # with a few ledges.
    "verdon": {
        "dem": "verdon_dem", "out": "verdon_out", "lat": 43.77,
        "xs": (4238, 4239, 4240, 4241, 4242), "ys": (2984, 2985, 2986, 2987),
        "anchor": (805.0, 640.0), "river": (8.0, 160.0), "far": (-1.0, 0.0), "bench": (35, 50),
        "terrace": (110.0, 2.6, 0.4), "river_level": (4.0, 6.0), "v_scale": 4.0, "backdrop": (300.0, 2.5),
        # The river is a narrow jade ribbon (filling the floor's lowest part made a round lake): a carved channel.
        "channel": (30.0, 8.0),
        # The land just behind the far rim dips 40-60 m before the hills: the usual landing stood on it like a pedestal.
        # A wider flat landing makes a plateau for the town (flat out to 210 studs, blending out by 460).
        "landing": (60.0, 210.0, 460.0),
    },
}
PLACE_NAME = os.environ.get("CANYON_PLACE", "grand")
PLACE = PLACES[PLACE_NAME]
DEM_DIR = pathlib.Path(__file__).parent / PLACE["dem"]
OUT_DIR = pathlib.Path(__file__).parent / PLACE["out"]
TERRACE_METERS, TERRACE_SHARPNESS, TERRACE_MIX = PLACE["terrace"]
RIVER_PERCENTILE, RIVER_RISE = PLACE["river_level"]
WATER_BELOW = 3.0  # a channel's water surface, this far under the floor's typical height
TILES = [(x, y) for y in PLACE["ys"] for x in PLACE["xs"]]
METERS_PER_PX = 40075016.686 * math.cos(math.radians(PLACE["lat"])) / 2**13 / 256
OVERLOOK_PX = PLACE["anchor"]  # where the bridge crosses the river, in the stitched image

# The game's layout (keep in step with GameConfig.Grid / Rounds and tools/build_canyon.luau).
RIM_X = -180.0  # the near rim's edge; the bridge leaves it heading -X
TOP_Y = 0.4  # the plateaus' terrain height (just under the 1.55 walk floor and deck)
GAP = 3000.0  # rim to rim along the bridge: Grid.Rows (300) x SlotStuds (10)
SLOT = 10.0
CAMP_RADIUS = 330.0  # flat around the hub (the fence is at about 151)
CAMP_BLEND = 260.0
CAMP_RECT = (-179.5, 172.0, -220.0, 150.0)  # camp's rectangle (tools/build_canyon.luau CAMP, tools/build_site.luau BASE)
CAMP_FLOOR = -3.0  # the terrain's height under it
CORRIDOR = 52.0  # half-width of the clear line under the bridge (the deck is 40)
# The far rim's landing: a round flat spot at plateau height, its middle this far past the rim, flat out to the first
# radius and blending into the real ground by the second.
LANDING = PLACE.get("landing", (60.0, 90.0, 220.0))
# The river (PLACE "river_level"): the lowest this percent of the gorge's area is under water, plus this much higher
# (2026-10-10, the user's note that stretches of the canyon floor had no water: 10 made it continuous).
RIM_DROP = 110.0  # meters below the bench that count as "in the gorge" when finding the rims
CLIFF = (260.0, 70.0, 2.4)  # at each bridgehead: half-width of the sheer drop, its first step down, then its slope
FAR_X = RIM_X - GAP

# The map's extent and sample spacing (studs).
# 1,800 studs past the far rim (was 700): the far side keeps rising into the cliffs and mesas behind it.
X_MIN, X_MAX = FAR_X - 1800.0, 760.0
# The road in (2026-10-10, the user's ask): from camp's east gate out to the horizon, routed along the plateau (the
# route with the least cutting and filling, gently curving) and graded into the ground, with banks where it cuts or fills.
ROAD = {
    "Start": 172.0,  # camp's east edge, where the gate is (tools/build_site.luau BASE.X1)
    "End": 5200.0,
    "Half": 14.0,  # half the road's width
    "Bank": 40.0,  # the cut or fill blends into the ground over this much past the road's edge
    "Grade": 300.0,  # the road's height follows the ground averaged over this much of its length
    "Lanes": (-900.0, 900.0, 20.0),  # where the route may wander (z) and how finely it's searched
    "Step": 40.0,  # x step of the route search
    "Bend": 1.2,  # cost of turning, against the cost of cutting and filling
    "Wander": 30.0,  # strength of the meander field (studs of cut/fill it's worth)
}
BACKDROP = PLACE["backdrop"]  # studs past the far rim at true scale, then how many times the land beyond is squeezed
Z_MIN, Z_MAX = -2000.0, 2000.0
SAMPLE = 8.0

# Studs per meter of real height. The horizontal scale comes from GAP (about 2.3 studs/m); 2.6 makes the walls a bit
# steeper than the real ones (1.6 made them flatter: the gorge read as a wide valley).
V_SCALE = PLACE["v_scale"]
# Rock layers (PLACE "terrace"): a ledge about TERRACE_METERS tall; higher TERRACE_SHARPNESS makes flatter ledges and
# steeper cliffs between them. These two blocks used to be set again here with the Grand Canyon's values, which
# overrode every place's own until 2026-10-11 (Zion was built with them: its entry now says so).
NOISE_STUDS = 5.0  # height noise on top
WARP_STUDS = 36.0  # sideways wobble of the sampling, so edges aren't straight interpolation



def load(folder: pathlib.Path) -> np.ndarray:
    rows = []
    for y in PLACE["ys"]:
        row = []
        for x in PLACE["xs"]:
            rgb = np.asarray(Image.open(folder / f"13_{x}_{y}.png").convert("RGB")).astype(np.float64)
            row.append(rgb[..., 0] * 256 + rgb[..., 1] + rgb[..., 2] / 256 - 32768)
        rows.append(np.hstack(row))
    return np.vstack(rows)


def mirror(t: np.ndarray, size: int) -> np.ndarray:
    """Coordinates past the image's edges folded back into it, so the land carries on as its mirror image (the far
    scenery reaches past the elevation tiles; a clamp would smear the edge pixels into streaks)."""
    span = size - 1.001
    t = np.mod(t, 2 * span)
    return np.where(t > span, 2 * span - t, t)


def bilinear(img: np.ndarray, x: np.ndarray, y: np.ndarray) -> np.ndarray:
    x = mirror(x, img.shape[1])
    y = mirror(y, img.shape[0])
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = x - x0, y - y0
    return (
        img[y0, x0] * (1 - fx) * (1 - fy)
        + img[y0, x0 + 1] * fx * (1 - fy)
        + img[y0 + 1, x0] * (1 - fx) * fy
        + img[y0 + 1, x0 + 1] * fx * fy
    )


def value_noise(X: np.ndarray, Z: np.ndarray, cell: float, seed: int) -> np.ndarray:
    """Smooth noise in [-1, 1] that depends only on the world position (so any grid gets the same values): hashed
    random values on a lattice every `cell` studs, smoothly interpolated."""
    fx, fz = X / cell, Z / cell
    i, j = np.floor(fx), np.floor(fz)
    tx, tz = fx - i, fz - j
    tx, tz = tx * tx * (3 - 2 * tx), tz * tz * (3 - 2 * tz)

    def lattice(a: np.ndarray, b: np.ndarray) -> np.ndarray:
        v = np.sin(a * 127.1 + b * 311.7 + seed * 74.7) * 43758.5453
        return (v - np.floor(v)) * 2 - 1

    return (
        lattice(i, j) * (1 - tx) * (1 - tz)
        + lattice(i + 1, j) * tx * (1 - tz)
        + lattice(i, j + 1) * (1 - tx) * tz
        + lattice(i + 1, j + 1) * tx * tz
    )


def fractal(X: np.ndarray, Z: np.ndarray, cell: float, octaves: int, seed: int) -> np.ndarray:
    total, amp, norm = np.zeros_like(X, dtype=np.float64), 1.0, 0.0
    for o in range(octaves):
        total += value_noise(X, Z, cell / 2**o, seed * 31 + o) * amp
        norm += amp
        amp *= 0.5
    return total / norm


def river_line(dem: np.ndarray) -> tuple:
    """The river's center and direction near the overlook, in pixels: the lowest point of cross-sections."""
    d = np.array(PLACE["river"])
    d /= np.linalg.norm(d)
    n = np.array([-d[1], d[0]])
    pts = []
    for t in np.arange(-60, 61, 10):
        c = np.array(OVERLOOK_PX) + d * t
        s = np.arange(-40, 41, 0.5)
        prof = bilinear(dem, c[0] + n[0] * s, c[1] + n[1] * s)
        pts.append(c + n * s[np.argmin(prof)])
    pts = np.array(pts)
    center = pts.mean(axis=0)
    _, _, vt = np.linalg.svd(pts - center)
    d = vt[0] / np.linalg.norm(vt[0])
    if d[0] < 0:
        d = -d
    return center, d


def terrace(h: np.ndarray) -> np.ndarray:
    """Rock layers: heights pulled toward flat ledges with cliffs between them (meters in, meters out)."""
    t = h / TERRACE_METERS
    base = np.floor(t)
    f = t - base
    shaped = f**TERRACE_SHARPNESS
    return (base + shaped * TERRACE_MIX + f * (1 - TERRACE_MIX)) * TERRACE_METERS


def smoothstep(e0: float, e1: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


class Canyon:
    """The real canyon, measured once from the tiles; heights(X, Z) gives the game's ground height anywhere."""

    def __init__(self, folder: pathlib.Path):
        dem = load(folder)
        center, d = river_line(dem)
        n = np.array([-d[1], d[0]])
        # n points from camp's side across to the far rim (the place's "far").
        if n @ np.array(PLACE["far"]) < 0:
            n = -n
        # Rims along the bridge line: from the river out to where the ground is back near bench height.
        s = np.arange(0, 200, 0.25)
        near_prof = bilinear(dem, center[0] - n[0] * s, center[1] - n[1] * s)
        far_prof = bilinear(dem, center[0] + n[0] * s, center[1] + n[1] * s)
        b0, b1 = PLACE["bench"]
        self.bench = float(np.median(near_prof[(s > b0) & (s < b1)]))
        # The rims are the lips of the main cliffs: where the ground first comes back within RIM_DROP of the bench.
        self.near_edge = s[np.argmax(near_prof >= self.bench - RIM_DROP)]
        self.far_bench = float(np.median(far_prof[(s > b0) & (s < b1)]))
        self.far_edge = s[np.argmax(far_prof >= min(self.bench, self.far_bench) - RIM_DROP)]
        width_px = self.near_edge + self.far_edge
        self.h_scale = GAP / (width_px * METERS_PER_PX)  # studs per meter across
        self.dem, self.center, self.d, self.n = dem, center, d, n
        self.road = None
        self.channel = None
        self.road = self._route()
        if PLACE["channel"]:
            self.channel = self._channel_line()
        river_m = float(near_prof.min())
        print(
            f"river at px {center.round(1)}, dir {d.round(3)}; bench {self.bench:.0f} m (far {self.far_bench:.0f}), "
            f"river {river_m:.0f} m, rim to rim {width_px * METERS_PER_PX:.0f} m -> {self.h_scale:.2f} studs/m across, "
            f"{V_SCALE} studs/m up (depth {(self.bench - river_m) * V_SCALE:.0f} studs)"
        )

    def _route(self) -> dict:
        """The road's line (z for every x, as arrays every 8 studs) and its graded height, found once: a search over the
        plateau for the path that needs the least cutting and filling, with a cost for turning, then smoothed."""
        lo, hi, dz = ROAD["Lanes"]
        xs = np.arange(ROAD["Start"], ROAD["End"] + 0.1, ROAD["Step"])
        zs = np.arange(lo, hi + 0.1, dz)
        X, Z = np.meshgrid(xs, zs, indexing="ij")
        ground = sum(self.heights(X, Z + off) for off in (-ROAD["Half"], 0.0, ROAD["Half"])) / 3
        # Cutting and filling, plus a gentle made-up preference field so the road meanders where the ground is flat.
        cost = np.abs(ground - TOP_Y) + (fractal(X, Z, 520, 2, 11) + 1) * ROAD["Wander"]
        n, m = cost.shape
        total = np.full((n, m), np.inf)
        back = np.zeros((n, m), dtype=int)
        start = int(np.argmin(np.abs(zs)))  # at the gate: z = 0
        total[0, start] = 0.0
        moves = np.arange(-3, 4)  # up to 60 studs sideways per 40 forward
        for i in range(1, n):
            best = np.full(m, np.inf)
            arg = np.zeros(m, dtype=int)
            for k in moves:
                prev = np.roll(total[i - 1], k)
                if k > 0:
                    prev[:k] = np.inf
                elif k < 0:
                    prev[k:] = np.inf
                cand = prev + ROAD["Bend"] * (k * dz / ROAD["Step"]) ** 2 * ROAD["Step"]
                better = cand < best
                best = np.where(better, cand, best)
                arg = np.where(better, np.arange(m) - k, arg)
            total[i] = best + cost[i]
            back[i] = arg
        path = np.zeros(n, dtype=int)
        path[-1] = int(np.argmin(total[-1]))
        for i in range(n - 1, 0, -1):
            path[i - 1] = back[i, path[i]]
        line = zs[path]
        kernel = np.ones(7) / 7  # smooth the stair steps of the search into curves
        line = np.convolve(np.pad(line, 3, mode="edge"), kernel, mode="valid")
        line[0] = 0.0
        fine_x = np.arange(ROAD["Start"] - 40, ROAD["End"] + 0.1, 8.0)
        fine_z = np.interp(fine_x, xs, line)
        raw = self.heights(fine_x, fine_z)
        w = int(ROAD["Grade"] / 8)
        grade = np.convolve(np.pad(raw, w // 2, mode="edge"), np.ones(w) / w, mode="valid")[: len(fine_x)]
        # Level with camp at the gate, settling onto the ground's grade over the first 250 studs.
        settle = smoothstep(ROAD["Start"], ROAD["Start"] + 250, fine_x)
        grade = TOP_Y * (1 - settle) + grade * settle
        slope = np.gradient(fine_z, fine_x)
        print(f"road: {len(fine_x)} points, z from {fine_z.min():.0f} to {fine_z.max():.0f}, height {grade.min():.0f} to {grade.max():.0f}")
        return {"x": fine_x, "z": fine_z, "h": grade, "slope": slope}

    def _channel_line(self) -> dict:
        """The river's line along the canyon (x for every z, every 8 studs): the lowest ground across the gorge, smoothed
        into gentle bends. Only for places with a "channel"."""
        zs = np.arange(Z_MIN - 400, Z_MAX + 401, 8.0)
        xs = np.arange(FAR_X + 200, RIM_X - 200, 8.0)
        Xg, Zg = np.meshgrid(xs, zs)
        low = xs[np.argmin(self.heights(Xg, Zg), axis=1)]
        w = 41  # about 330 studs of smoothing
        line = np.convolve(np.pad(low, w // 2, mode="edge"), np.ones(w) / w, mode="valid")
        floor = float(np.median(self.heights(line + 60.0, zs)))
        self.water = floor - WATER_BELOW
        print(f"channel: x from {line.min():.0f} to {line.max():.0f}; floor {floor:.0f}, water {self.water:.0f}")
        return {"z": zs, "x": line}

    def road_at(self, X: np.ndarray, Z: np.ndarray) -> tuple:
        """How far (studs) each point is from the road's middle, and the road's height there (inf, nan off its stretch)."""
        r = self.road
        on = X >= r["x"][0]
        f = np.interp(X, r["x"], r["z"])
        slope = np.interp(X, r["x"], r["slope"])
        dist = np.where(on, np.abs(Z - f) / np.sqrt(1 + slope**2), np.inf)
        return dist, np.interp(X, r["x"], r["h"])

    def road_mask(self, X: np.ndarray, Z: np.ndarray) -> np.ndarray:
        """1 on the road, 0 off it, a short blend at its edges (for painting it)."""
        dist, _ = self.road_at(X, Z)
        return 1 - smoothstep(ROAD["Half"] - 1, ROAD["Half"] + 2, dist)

    def heights(self, X: np.ndarray, Z: np.ndarray) -> np.ndarray:
        """Game ground height (studs) at game (X, Z): the real canyon, reshaped, with the game's features carved in."""
        # Wobble the sampling a little so cliff lines aren't straight interpolation between 15 m pixels.
        wx = fractal(X, Z, 780, 4, 1) * WARP_STUDS
        wz = fractal(X, Z, 780, 4, 2) * WARP_STUDS
        # Game (x, z) -> meters across (u, + toward the far rim) and along (v) the river, from the river's middle.
        # Past BACKDROP[0] studs beyond the far rim the land is squeezed BACKDROP[1] times, so the hills ~2.5 km behind
        # the far rim rise within the map as the canyon's far wall (heights stay true).
        across = RIM_X - (X + wx)
        beyond = GAP + BACKDROP[0]
        across = np.where(across > beyond, beyond + (across - beyond) * BACKDROP[1], across)
        u_m = (across / self.h_scale) - self.near_edge * METERS_PER_PX
        v_m = (Z + wz) / self.h_scale
        c, d, n = self.center, self.d, self.n
        px = c[0] + (n[0] * u_m + d[0] * v_m) / METERS_PER_PX
        py = c[1] + (n[1] * u_m + d[1] * v_m) / METERS_PER_PX
        h = bilinear(self.dem, px, py)
        # The far bench is about 30 m lower than the near one; lift the far side (from the gorge's middle out) so the
        # bridge lands level on the real ground instead of on a raised block.
        far_m = self.far_edge * METERS_PER_PX
        h = h + smoothstep(0.25 * far_m, 0.95 * far_m, u_m) * (self.bench - self.far_bench)

        # Heights relative to the near bench, in rock layers, then to studs.
        Y = TOP_Y + terrace(h - self.bench) * V_SCALE + fractal(X, Z, 190, 3, 3) * NOISE_STUDS

        # Camp: flat around the hub, blending out into the real ground.
        camp = 1 - smoothstep(CAMP_RADIUS, CAMP_RADIUS + CAMP_BLEND, np.hypot(X, Z))
        Y = Y * (1 - camp) + TOP_Y * camp
        # Under camp's rectangle the terrain sits a few studs lower: 4-stud terrain rounds its surface up to about 2.5 at
        # TOP_Y, which buried camp's gravel floor, the gym and its pads (tools/build_site.luau lays them at 1.5).
        inside = (X >= CAMP_RECT[0]) & (X <= CAMP_RECT[1]) & (Z >= CAMP_RECT[2]) & (Z <= CAMP_RECT[3])
        Y = np.where(inside, np.minimum(Y, CAMP_FLOOR), Y)
        # The road, graded into the ground: level across, the cut or fill blending out over its banks.
        if self.road is not None:
            dist, level = self.road_at(X, Z)
            onto = 1 - smoothstep(ROAD["Half"], ROAD["Half"] + ROAD["Bank"], dist)
            Y = Y * (1 - onto) + level * onto
        # A sheer drop at each bridgehead, so the bridge leaves the rim over a cliff and lands on one.
        for edge, sign in ((RIM_X, -1.0), (FAR_X, 1.0)):
            out_dist = (X - edge) * sign  # studs out over the canyon from that rim
            face = (out_dist > 0) & (out_dist < 400)
            fade = 1 - smoothstep(CLIFF[0] * 0.6, CLIFF[0], np.abs(Z))
            drop = TOP_Y - CLIFF[1] - out_dist * CLIFF[2]
            Y = np.where(face, np.minimum(Y, Y * (1 - fade) + np.minimum(Y, drop) * fade), Y)
            if sign > 0 and PLACE.get("fill_far"):
                z0, z1, o0, o1 = PLACE["fill_far"]
                fill = (out_dist > 0) * (1 - smoothstep(z0, z1, np.abs(Z))) * (1 - smoothstep(o0, o1, out_dist))
                Y = Y * (1 - fill) + np.maximum(Y, drop) * fill
        # Nothing under the bridge comes within 30 studs of the deck, from the near rim to the far rim.
        Y = np.where((X < RIM_X) & (X > FAR_X) & (np.abs(Z) < CORRIDOR), np.minimum(Y, TOP_Y - 30), Y)
        # The river's channel (places with one): a rounded trough cut into the floor along its lowest line.
        if self.channel is not None:
            half, depth = PLACE["channel"]
            gorge = (X < RIM_X) & (X > FAR_X)
            Y = np.where(gorge, np.maximum(Y, self.water + 3), Y)  # no floor under the water but the channel
            cx = np.interp(Z, self.channel["z"], self.channel["x"])
            t = 1 - smoothstep(half * 0.4, half, np.abs(X - cx))
            Y = Y * (1 - t) + np.minimum(Y, self.water - depth) * t
        # The far landing: a round flat spot just past the far rim, blending into the ground around it (never out
        # over the canyon, so the far rim's cliff stays sheer under the bridge's last rows).
        to_landing = np.hypot(X - (FAR_X - LANDING[0]), Z)
        flat = (1 - smoothstep(LANDING[1], LANDING[2], to_landing)) * (X <= FAR_X)
        Y = Y * (1 - flat) + TOP_Y * flat
        return Y


def main() -> None:
    folder = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else DEM_DIR
    out = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else OUT_DIR / "heightmap.txt"
    print(f"place: {PLACE_NAME}")
    out.parent.mkdir(parents=True, exist_ok=True)
    canyon = Canyon(folder)

    xs = np.arange(X_MIN, X_MAX + 0.1, SAMPLE)
    zs = np.arange(Z_MIN, Z_MAX + 0.1, SAMPLE)
    X, Z = np.meshgrid(xs, zs)
    Y = canyon.heights(X, Z)
    gap = (X < RIM_X) & (X > FAR_X)

    # The river: water up to just over the deepest few percent of the gorge (the real river's height would flood the
    # whole broad, terraced floor into a lake).
    river_y = float(np.percentile(Y[gap], RIVER_PERCENTILE)) - 6 + RIVER_RISE
    if canyon.channel is not None:
        river_y = canyon.water - 6  # (the header holds river_y + 6, the water's surface)
    q = np.clip(np.round(Y * 4) + 32768, 0, 65535).astype(np.uint16)
    with open(out, "w", encoding="ascii", newline="") as f:  # plain line breaks, not Windows' CR LF
        f.write(f"{len(xs)} {len(zs)} {X_MIN} {Z_MIN} {SAMPLE} {river_y + 6:.1f} {Y.min():.1f} {Y.max():.1f}\n")
        f.write("".join(f"{v:04x}" for v in q.ravel()))
        # Line 3: the road, one digit per sample (0 off it .. 9 on it), for tools/canyon_terrain.luau to paint.
        road = np.clip(np.round(canyon.road_mask(X, Z) * 9), 0, 9).astype(int)
        f.write("\n" + "".join(str(v) for v in road.ravel()))
    print(f"heightmap {len(xs)} x {len(zs)} samples, y {Y.min():.0f} to {Y.max():.0f}, river surface {river_y + 6:.0f} -> {out}")

    # A shaded preview seen from above: +X to the right, +Z down.
    gy, gx = np.gradient(Y, SAMPLE)
    slope = np.arctan(np.hypot(gx, gy))
    aspect = np.arctan2(-gx, gy)
    shade = np.sin(math.radians(45)) * np.cos(slope) + np.cos(math.radians(45)) * np.sin(slope) * np.cos(math.radians(315) - aspect)
    t = (Y - Y.min()) / (Y.max() - Y.min())
    col = np.stack([0.45 + 0.55 * t, 0.3 + 0.5 * t, 0.22 + 0.35 * t], -1) * np.clip(shade, 0.15, 1)[..., None]
    img = (np.clip(col, 0, 1) * 255).astype(np.uint8)
    img[(np.abs(Z) < 8) & gap] = [255, 230, 0]  # the bridge's line
    Image.fromarray(img).save(out.with_suffix(".png"))


if __name__ == "__main__":
    main()

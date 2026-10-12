# Zion elevation tiles

Sixteen Terrarium elevation tiles (zoom 13, x 1524-1527, y 3179-3182) around Zion Lodge in Zion Canyon, the source of
the Zion map (`CANYON_PLACE=zion python tools/canyon_heightmap.py`). Downloaded 2026-10-11 from the AWS Terrain Tiles
bucket: `https://s3.amazonaws.com/elevation-tiles-prod/terrarium/13/<x>/<y>.png` (about 2.1 MB in all).

Each pixel's height in meters is `R * 256 + G + B / 256 - 32768`, about 15 m per pixel here.

Attribution (put it in the game's description): Terrain data: Mapzen / AWS Terrain Tiles, built from USGS 3DEP and
other open sources.

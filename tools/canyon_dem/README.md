# Canyon elevation tiles

Nine Terrarium elevation tiles (zoom 13, x 1522-1524, y 3210-3212) around Toroweap Overlook in the Grand Canyon, the
source of the game's canyon (`tools/canyon_heightmap.py`). Downloaded 2026-10-10 from the AWS Terrain Tiles bucket:
`https://s3.amazonaws.com/elevation-tiles-prod/terrarium/13/<x>/<y>.png` (about 1.1 MB in all).

Each pixel's height in meters is `R * 256 + G + B / 256 - 32768`, about 15 m per pixel here.

Attribution (put it in the game's description): Terrain data: Mapzen / AWS Terrain Tiles, built from USGS 3DEP and
other open sources.

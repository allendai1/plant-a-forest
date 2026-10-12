# Verdon elevation tiles

Twenty Terrarium elevation tiles (zoom 13, x 4238-4242, y 2984-2987) around the Grand Canyon du Verdon in Provence, the
source of the Verdon map (`CANYON_PLACE=verdon python tools/canyon_heightmap.py`). Downloaded 2026-10-11 from the AWS
Terrain Tiles bucket: `https://s3.amazonaws.com/elevation-tiles-prod/terrarium/13/<x>/<y>.png` (about 2.3 MB in all).

Each pixel's height in meters is `R * 256 + G + B / 256 - 32768`, about 11 m per pixel here.

Attribution (put it in the game's description): Terrain data: Mapzen / AWS Terrain Tiles, built from open sources
including the EU-DEM (Copernicus) and SRTM.

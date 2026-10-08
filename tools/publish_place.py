"""Publish a saved place file to the live game with Open Cloud (Place Publishing API).

Usage: python tools/publish_place.py [path] [--wait]
  path: the .rbxl/.rbxlx to publish (default: PlantTheForest.rbxl in the repo root)
  --wait: wait until the file exists and has stopped changing, then publish

Needs the API key (env ROBLOX_API_KEY) with the universe-places:write scope. Publishes a new version of
the place as Published, which is what live servers start from.
"""

import json
import os
import pathlib
import subprocess
import sys
import time
import urllib.error
import urllib.request

UNIVERSE_ID = 10769630190
PLACE_ID = 93453899201090
ROOT = pathlib.Path(__file__).resolve().parent.parent


def api_key() -> str:
    key = os.environ.get("ROBLOX_API_KEY")
    if key:
        return key
    out = subprocess.run(["powershell", "-NoProfile", "-c", '[Environment]::GetEnvironmentVariable("ROBLOX_API_KEY","User")'],
                         capture_output=True, text=True)
    return out.stdout.strip()


def wait_for(path: pathlib.Path):
    print(f"waiting for {path} ...", flush=True)
    last = -1
    stable = 0
    while stable < 3:  # the same size for 3 checks in a row: Studio has finished writing it
        time.sleep(2)
        size = path.stat().st_size if path.exists() else -1
        stable = stable + 1 if size == last and size > 0 else 0
        last = size
    print(f"found it: {last:,} bytes", flush=True)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    path = pathlib.Path(args[0]) if args else ROOT / "PlantTheForest.rbxl"
    if "--wait" in sys.argv:
        wait_for(path)
    data = path.read_bytes()
    kind = "application/xml" if path.suffix.lower() == ".rbxlx" else "application/octet-stream"
    url = f"https://apis.roblox.com/universes/v1/{UNIVERSE_ID}/places/{PLACE_ID}/versions?versionType=Published"
    request = urllib.request.Request(url, data=data, method="POST",
                                     headers={"x-api-key": api_key(), "Content-Type": kind})
    try:
        with urllib.request.urlopen(request) as response:
            print("published:", json.loads(response.read()), flush=True)
    except urllib.error.HTTPError as err:
        print("publish failed:", err.code, err.read().decode(errors="replace")[:500], flush=True)
        sys.exit(1)


if __name__ == "__main__":
    main()

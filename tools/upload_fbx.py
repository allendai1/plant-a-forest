"""Upload an FBX as a Model with Open Cloud and wait for its asset id. Usage: python tools/upload_fbx.py <path> <displayName>"""
import json
import os
import subprocess
import sys
import time
import urllib.request

path, name = sys.argv[1], sys.argv[2]
key = os.environ.get("ROBLOX_API_KEY")
if not key:
    out = subprocess.run(["powershell", "-NoProfile", "-c", '[Environment]::GetEnvironmentVariable("ROBLOX_API_KEY","User")'],
                         capture_output=True, text=True)
    key = out.stdout.strip()
request = json.dumps({"assetType": "Model", "displayName": name, "description": "Plant the Forest asset",
                      "creationContext": {"creator": {"userId": "14722022"}}})
boundary = "----ptf" + str(int(time.time()))
data = open(path, "rb").read()
body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n{request}\r\n"
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{os.path.basename(path)}\"\r\n"
        f"Content-Type: model/fbx\r\n\r\n").encode() + data + f"\r\n--{boundary}--\r\n".encode()
req = urllib.request.Request("https://apis.roblox.com/assets/v1/assets", data=body, method="POST",
                             headers={"x-api-key": key, "Content-Type": f"multipart/form-data; boundary={boundary}"})
op = json.load(urllib.request.urlopen(req))
op_path = op.get("path") or f"operations/{op['operationId']}"
for _ in range(40):
    time.sleep(2)
    r = urllib.request.Request(f"https://apis.roblox.com/assets/v1/{op_path}", headers={"x-api-key": key})
    status = json.load(urllib.request.urlopen(r))
    if status.get("done"):
        print(json.dumps(status.get("response", status))[:500])
        break
else:
    print("not done", op_path)

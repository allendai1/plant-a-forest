"""Query Roblox Open Cloud Analytics (beta, free; key scope universe.analytics:read). Usage:
  python tools/analytics_query.py <metric> <granularity> <days|hours h> [breakdown,...|-] [filter "Dim=a|b;Dim2=c"|-] [dims]
<days> starts at midnight UTC that many days back; "6h" means the last 6 hours (e.g. only since a publish).
Reads ROBLOX_API_KEY / ROBLOX_UNIVERSE_ID from the environment; prints the JSON result (never the key)."""
import datetime, json, os, sys, time, urllib.error, urllib.request

KEY = os.environ["ROBLOX_API_KEY"]
UNIVERSE = os.environ.get("ROBLOX_UNIVERSE_ID", "10769630190")
BASE = f"https://apis.roblox.com/analytics-query-api/v1/universes/{UNIVERSE}"


def call(method, url, body=None):
    req = urllib.request.Request(url, method=method, headers={"x-api-key": KEY, "Content-Type": "application/json"},
                                 data=json.dumps(body).encode() if body else None)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return {"httpError": e.code, "body": e.read().decode()[:1500]}


metric, gran, window = sys.argv[1], sys.argv[2], sys.argv[3]
breakdown = sys.argv[4].split(",") if len(sys.argv) > 4 and sys.argv[4] not in ("", "-") else []
end = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)
if window.endswith("h"):
    start = end - datetime.timedelta(hours=float(window[:-1]))
else:
    start = (end - datetime.timedelta(days=int(window))).replace(hour=0, minute=0, second=0)
body = {"metric": metric, "granularity": gran, "startTime": start.isoformat().replace("+00:00", "Z"),
        "endTime": end.isoformat().replace("+00:00", "Z")}
if breakdown:
    body["breakdown"] = breakdown
# argv[5]: filters "Dim=a|b;Dim2=c"; argv[6] == "dims": list the values of the breakdown dimensions instead
if len(sys.argv) > 5 and sys.argv[5] not in ("", "-"):
    body["filter"] = [{"dimension": f.split("=")[0], "values": f.split("=")[1].split("|"), "operation": "In"}
                      for f in sys.argv[5].split(";")]
kind = "dimension-values" if len(sys.argv) > 6 and sys.argv[6] == "dims" else "metrics"
if kind == "dimension-values":
    body["dimensions"] = body.pop("breakdown", [])
res = call("POST", f"{BASE}/{kind}", body)
# Long-running: poll the operation.
for _ in range(20):
    op = res.get("path") or res.get("name") or res.get("operationId")
    if res.get("done") is False and op:
        time.sleep(3)
        opid = op.rsplit("/", 1)[-1]
        res = call("GET", f"{BASE}/operations/{kind}/{opid}")
    else:
        break
print(json.dumps(res))

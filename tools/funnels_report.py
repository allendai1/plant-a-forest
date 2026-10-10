"""Compact funnel / session report from Open Cloud Analytics. Reads ROBLOX_API_KEY from the environment."""
import json, subprocess, sys, os

Q = os.path.join(os.path.dirname(os.path.abspath(__file__)), "analytics_query.py")


def query(*args):
    out = subprocess.run([sys.executable, "-I", Q, *args], capture_output=True, text=True).stdout
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return {"raw": out[:500]}


def rows(res):
    """(breakdown values, total) pairs from a metrics response."""
    r = res.get("response", res)
    out = []
    for series in r.get("values", r.get("metricValues", [])) or []:
        labels = tuple(b.get("value") for b in series.get("breakdownValues", series.get("breakdowns", [])))
        pts = series.get("dataPoints", series.get("datapoints", []))
        total = sum(float(p.get("value", 0) or 0) for p in pts)
        out.append((labels, total))
    if not out:
        out.append((("?",), json.dumps(res)[:400]))
    return out


what = sys.argv[1] if len(sys.argv) > 1 else "funnels"
days = sys.argv[2] if len(sys.argv) > 2 else "7"
if what == "funnels":
    for name in ["FUNNEL_TYPE_ONBOARDING", "Tutorial", "ForestLoop", "SessionLength", "ForestMilestones", "LifetimePlaytime",
                 "RobuxShop", "LockedStation", "Quests"]:
        print(f"== {name}")
        for labels, total in sorted(rows(query("FunnelUserTotalCount", "None", days, "FunnelStep", f"FunnelName={name}")),
                                    key=lambda x: str(x[0])):
            print(f"  {labels}: {total}")
else:
    metric, gran, breakdown = sys.argv[3], sys.argv[4], sys.argv[5] if len(sys.argv) > 5 else "-"
    filt = sys.argv[6] if len(sys.argv) > 6 else "-"
    for labels, total in sorted(rows(query(metric, gran, days, breakdown, filt)), key=lambda x: str(x[0])):
        print(f"  {labels}: {total}")

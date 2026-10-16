#!/bin/bash
# Collects each named session's context % from statusline bridge files (written by the status-line script;
# NOT included in this kit - see SETUP-UBUNTU.md 'Context meters', optional)
# ($TMPDIR/claude-ctx-<session>.json) and writes the board/ctx payload JSON to $1.
# pct = raw % of the full context window used. Policy: auto-compact at 50% (500K of 1M),
# so the board's 45 (compact soon) / 50 (compact now) thresholds line up with it.
out=${1:?usage: ctx-sync.sh <out.json>}
python3 - "$out" <<'PY'
import json,glob,os,re,sys,time,datetime
tmp=os.environ.get("TMPDIR","/tmp"); now=time.time(); res={}
names={"gate keeper":"gk","gatekeeper":"gk"}
for f in glob.glob(os.path.join(tmp,"claude-ctx-*.json")):
    try: d=json.load(open(f))
    except Exception: continue
    sid=d.get("session_id"); ts=d.get("timestamp",0); rem=d.get("remaining_percentage")
    if not sid or rem is None or now-ts>6*3600: continue
    j=glob.glob(os.path.expanduser(f"~/.claude/projects/*/{sid}.jsonl"))
    if not j: continue
    name=None
    with open(j[0],errors="ignore") as fh:
        for line in fh:
            m=re.findall(r'"agentName":"([^"]+)"',line)
            if m: name=m[-1]
    if not name: continue
    key=names.get(name.lower(),name.lower())
    pct=max(0,min(100,round(100-rem)))  # raw % of the full window; auto-compact fires at 50 (CLAUDE_CODE_AUTO_COMPACT_WINDOW=500000)
    at=datetime.datetime.fromtimestamp(ts,datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    if key not in res or res[key]["at"]<at: res[key]={"pct":pct,"raw":round(100-rem),"at":at}
usage=None
try:
    u=json.load(open(os.path.join(tmp,"claude-usage.json")))
    rl=u.get("rate_limits") or {}
    iso=lambda t: datetime.datetime.fromtimestamp(t,datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") if t else None
    usage={k:{"pct":v.get("used_percentage"),"resets":iso(v.get("resets_at"))} for k,v in rl.items() if isinstance(v,dict)}
    usage["at"]=iso(u.get("timestamp"))
except Exception: pass
json.dump({"usage":usage,"sessions":res,"updated":datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")},open(sys.argv[1],"w"))
print(json.dumps(res))
PY

#!/usr/bin/python3
"""Stop processes that Claude Code sessions leave behind.

A process belongs to a session when its command line or working directory
contains that session's scratchpad path, /tmp/claude-<uid>/<project>/<session-id>/.
Descendants of such a process belong to the session too. Nothing outside a
scratchpad path is ever touched, and a process named `claude` never is.

Hook use (hook JSON on stdin):
  SessionStart  record which claude PID owns the session, then sweep.
  SessionEnd    stop the session's processes (not for reason "clear"), then sweep.
                Runs detached so it finishes even if Claude exits first.

Sweep rules:
  dead-session  the session's recorded claude PID is gone -> stop all its processes.
  stale-orphan  parent is launchd (PPID 1) and older than REAPER_ORPHAN_HOURS
                (default 12) -> stop it, whether or not its session is alive.

Manual use:
  session-reaper.py --sweep [--dry-run]
  session-reaper.py --list

Environment overrides (for tests): REAPER_STATE_DIR, REAPER_ORPHAN_HOURS.
"""
import json
import os
import re
import signal
import subprocess
import sys
import time
from datetime import datetime

STATE_DIR = os.path.expanduser(os.environ.get("REAPER_STATE_DIR", "~/.claude/run"))
SESSIONS_DIR = os.path.join(STATE_DIR, "sessions")
LOG_PATH = os.path.join(STATE_DIR, "reaper.log")
ORPHAN_HOURS = float(os.environ.get("REAPER_ORPHAN_HOURS", "12"))
TERM_GRACE_SECONDS = 2.0

UUID = r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
SCRATCH_RE = re.compile(r"claude-\d+/[^/\s]+/(" + UUID + r")(?=/|\s|$)")
MY_UID = os.getuid()


def log(line):
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        with open(LOG_PATH, "a") as f:
            f.write(f"{datetime.now().isoformat(timespec='seconds')} {line}\n")
    except OSError:
        pass


def parse_etime(s):
    """ps etime: [[dd-]hh:]mm:ss -> seconds."""
    days = 0
    if "-" in s:
        d, s = s.split("-", 1)
        days = int(d)
    parts = [int(p) for p in s.split(":")]
    while len(parts) < 3:
        parts.insert(0, 0)
    h, m, sec = parts
    return days * 86400 + h * 3600 + m * 60 + sec


def process_table():
    out = subprocess.run(
        ["ps", "-axo", "pid=,ppid=,uid=,etime=,rss=,args="],
        capture_output=True, text=True, timeout=10,
    ).stdout
    procs = {}
    comm_re = re.compile(r"^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(.*)$")
    for line in out.splitlines():
        m = comm_re.match(line)
        if not m:
            continue
        pid, ppid, uid, etime, rss, rest = m.groups()
        procs[int(pid)] = {
            "pid": int(pid), "ppid": int(ppid), "uid": int(uid),
            "age": parse_etime(etime), "rss_kb": int(rss), "rest": rest,
        }
    return procs


def comm_of(pid):
    r = subprocess.run(["ps", "-o", "comm=", "-p", str(pid)], capture_output=True, text=True)
    return r.stdout.strip()


def args_of(pid):
    r = subprocess.run(["ps", "-o", "args=", "-p", str(pid)], capture_output=True, text=True)
    return r.stdout.strip()


def lstart_of(pid):
    r = subprocess.run(["ps", "-o", "lstart=", "-p", str(pid)], capture_output=True, text=True)
    return r.stdout.strip()


def cwd_table():
    """pid -> cwd for this user's processes (lsof, ~0.5 s)."""
    try:
        out = subprocess.run(
            ["lsof", "-a", "-u", str(MY_UID), "-d", "cwd", "-Fpn", "-b", "-w"],
            capture_output=True, text=True, timeout=15,
        ).stdout
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return {}
    cwds, pid = {}, None
    for line in out.splitlines():
        if line.startswith("p"):
            pid = int(line[1:])
        elif line.startswith("n") and pid is not None:
            cwds[pid] = line[1:]
    return cwds


def ancestors(pid, procs):
    seen = set()
    while pid > 1 and pid not in seen:
        seen.add(pid)
        p = procs.get(pid)
        if not p:
            break
        pid = p["ppid"]
    return seen


def session_map(procs, cwds):
    """session id -> set of pids tied to it (direct matches plus descendants)."""
    children = {}
    for p in procs.values():
        children.setdefault(p["ppid"], []).append(p["pid"])
    direct = {}
    for p in procs.values():
        if p["uid"] != MY_UID:
            continue
        text = p["rest"] + " " + cwds.get(p["pid"], "")
        for sid in set(SCRATCH_RE.findall(text)):
            direct.setdefault(sid, set()).add(p["pid"])
    tied = {}
    for sid, pids in direct.items():
        stack, out = list(pids), set()
        while stack:
            pid = stack.pop()
            if pid in out:
                continue
            out.add(pid)
            stack.extend(children.get(pid, []))
        tied[sid] = out
    return tied


def is_claude(p):
    return os.path.basename(p["rest"].split(" ", 1)[0]) == "claude"


def owner_of(pid, procs, claude_pids):
    """Nearest live claude ancestor, or None when the process has none."""
    seen = set()
    pid = procs[pid]["ppid"]
    while pid > 1 and pid not in seen:
        if pid in claude_pids:
            return pid
        seen.add(pid)
        p = procs.get(pid)
        if not p:
            return None
        pid = p["ppid"]
    return None


def protected(pid, procs, keep):
    p = procs.get(pid)
    if pid <= 1 or pid in keep or not p or p["uid"] != MY_UID:
        return True
    # Never stop a Claude Code process itself.
    return is_claude(p)


def stop(targets, procs, reason_by_pid, event, dry_run):
    """SIGTERM, short grace, then SIGKILL. Returns (count, rss_kb)."""
    if not targets:
        return 0, 0
    rss = sum(procs[p]["rss_kb"] for p in targets if p in procs)
    for pid in sorted(targets):
        p = procs[pid]
        desc = f"{event} {reason_by_pid[pid]} pid={pid} ppid={p['ppid']} age={p['age']}s rss={p['rss_kb'] // 1024}MB :: {p['rest'][:160]}"
        if dry_run:
            print("WOULD STOP " + desc)
        else:
            log("STOP " + desc)
    if dry_run:
        return len(targets), rss
    for pid in targets:
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    deadline = time.time() + TERM_GRACE_SECONDS
    alive = set(targets)
    while alive and time.time() < deadline:
        time.sleep(0.2)
        for pid in list(alive):
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                alive.discard(pid)
    for pid in alive:
        try:
            os.kill(pid, signal.SIGKILL)
            log(f"{event} SIGKILL pid={pid}")
        except ProcessLookupError:
            pass
    return len(targets), rss


def load_records():
    records = {}
    if not os.path.isdir(SESSIONS_DIR):
        return records
    for name in os.listdir(SESSIONS_DIR):
        if not name.endswith(".json"):
            continue
        try:
            with open(os.path.join(SESSIONS_DIR, name)) as f:
                records[name[:-5]] = json.load(f)
        except (OSError, ValueError):
            pass
    return records


def record_alive(rec):
    pid = rec.get("claude_pid")
    if not pid or not rec.get("claude_lstart"):
        return True  # unknown owner: never treat as dead
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        pass
    return lstart_of(pid) == rec.get("claude_lstart")


def find_claude_pid():
    pid = os.getppid()
    for _ in range(8):
        if pid <= 1:
            return None
        if os.path.basename(comm_of(pid)) == "claude" or "@anthropic-ai/claude-code" in args_of(pid):
            return pid
        r = subprocess.run(["ps", "-o", "ppid=", "-p", str(pid)], capture_output=True, text=True)
        try:
            pid = int(r.stdout.strip())
        except ValueError:
            return None
    return None


def write_record(session_id, claude_pid):
    os.makedirs(SESSIONS_DIR, exist_ok=True)
    rec = {"claude_pid": claude_pid, "claude_lstart": lstart_of(claude_pid),
           "recorded": datetime.now().isoformat(timespec="seconds")}
    path = os.path.join(SESSIONS_DIR, session_id + ".json")
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(rec, f)
    os.replace(tmp, path)


def remove_record(session_id):
    try:
        os.remove(os.path.join(SESSIONS_DIR, session_id + ".json"))
    except OSError:
        pass


def plan(procs, cwds, keep, ending_session=None, ending_owner=None):
    """Return {pid: reason} for everything that should be stopped.

    A process still running under a live claude process belongs to that
    session, whatever paths it mentions, so it is only stopped when that
    claude is the one ending.
    """
    tied = session_map(procs, cwds)
    records = load_records()
    claude_pids = {pid for pid, p in procs.items() if is_claude(p)}
    reasons = {}
    if ending_session:
        for pid in tied.get(ending_session, ()):
            if owner_of(pid, procs, claude_pids) in (None, ending_owner):
                reasons[pid] = f"session-end[{ending_session[:8]}]"
    for sid, rec in records.items():
        if sid != ending_session and not record_alive(rec):
            for pid in tied.get(sid, ()):
                if owner_of(pid, procs, claude_pids) is None:
                    reasons.setdefault(pid, f"dead-session[{sid[:8]}]")
    for sid, pids in tied.items():
        for pid in pids:
            p = procs[pid]
            if p["ppid"] == 1 and p["age"] >= ORPHAN_HOURS * 3600:
                reasons.setdefault(pid, f"stale-orphan[{sid[:8]}]")
    return {pid: r for pid, r in reasons.items() if not protected(pid, procs, keep)}, records


def run(event, ending_session=None, ending_owner=None, dry_run=False, keep=()):
    procs = process_table()
    cwds = cwd_table()
    keep = set(keep) | ancestors(os.getpid(), procs)
    reasons, records = plan(procs, cwds, keep, ending_session, ending_owner)
    count, rss = stop(set(reasons), procs, reasons, event, dry_run)
    if not dry_run:
        for sid, rec in records.items():
            if sid != ending_session and not record_alive(rec):
                remove_record(sid)
    return count, rss


def detach():
    """Fork into the background so Claude exiting cannot cut the work short."""
    if os.fork() > 0:
        os._exit(0)
    os.setsid()
    if os.fork() > 0:
        os._exit(0)
    devnull = os.open(os.devnull, os.O_RDWR)
    for fd in (0, 1, 2):
        os.dup2(devnull, fd)


def main(argv):
    if "--list" in argv:
        procs = process_table()
        tied = session_map(procs, cwd_table())
        records = load_records()
        for sid in sorted(set(tied) | set(records)):
            rec = records.get(sid)
            state = "no-record" if rec is None else ("alive" if record_alive(rec) else "DEAD")
            print(f"{sid}  {state}")
            for pid in sorted(tied.get(sid, ())):
                p = procs[pid]
                print(f"    pid={pid} ppid={p['ppid']} age={p['age']}s rss={p['rss_kb'] // 1024}MB {p['rest'][:120]}")
        return 0
    if "--sweep" in argv:
        dry = "--dry-run" in argv
        count, rss = run("manual-sweep", dry_run=dry)
        print(f"{'would stop' if dry else 'stopped'} {count} process(es), ~{rss // 1024} MB")
        return 0

    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return 0
    event = payload.get("hook_event_name", "")
    session_id = payload.get("session_id", "")
    if not re.fullmatch(UUID, session_id or ""):
        session_id = None

    if event == "SessionStart":
        if session_id:
            claude_pid = find_claude_pid()
            if claude_pid:
                write_record(session_id, claude_pid)
        count, rss = run("session-start")
        if count:
            print(json.dumps({"systemMessage":
                f"session-reaper: stopped {count} leftover process(es) from ended Claude sessions "
                f"(~{rss / 1048576:.1f} GB). Log: ~/.claude/run/reaper.log"}))
        return 0

    if event == "SessionEnd":
        reason = payload.get("reason", "")
        keep = ancestors(os.getpid(), process_table())
        ending_owner = find_claude_pid()
        detach()
        if reason == "clear" or not session_id:
            # /clear keeps the same Claude process; its old work is reaped once that process exits.
            run("session-end-sweep", keep=keep)
        else:
            run("session-end", ending_session=session_id, ending_owner=ending_owner, keep=keep)
            remove_record(session_id)
        return 0
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Exception as e:  # never block or break a session
        log(f"ERROR {type(e).__name__}: {e}")
        sys.exit(0)

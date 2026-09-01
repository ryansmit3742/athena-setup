# Prints why Athena's chat is failing on this server. Run ON the server:
#   curl -fsSL https://raw.githubusercontent.com/ryansmit3742/athena-setup/main/diagnose.py | python3
# Read-only apart from one test message sent to your own Athena. Send the output to whoever is helping you.
import json, subprocess, urllib.request, urllib.error

def run(cmd):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30).stdout.strip()
    except Exception as e:  # noqa: BLE001
        return f"(could not run: {e})"

env = {}
for line in open("/root/athena/.env"):
    if "=" in line and not line.startswith("#"):
        k, v = line.rstrip("\n").split("=", 1)
        env[k] = v
token = env.get("ATHENA_INGEST_TOKEN", "")

print("=== Athena service")
print("state:", run("systemctl is-active athena.service"))
print("installed version:", run("cut -c1-12 /root/athena/RELEASE 2>/dev/null") or "(dev install)")
try:
    req = urllib.request.Request("http://127.0.0.1:8000/api/routines", headers={"X-Athena-Token": token})
    with urllib.request.urlopen(req, timeout=15) as r:
        print("api answering:", r.status)
except urllib.error.HTTPError as e:
    print("api answering:", e.code)
except Exception as e:  # noqa: BLE001
    print("api NOT answering:", str(e)[:120])

print("\n=== Live test: sending one message to Athena from the server itself")
try:
    body = json.dumps({"message": "Say hi in three words.", "history": []}).encode()
    req = urllib.request.Request("http://127.0.0.1:8000/chat/stream", data=body, headers={"X-Athena-Token": token, "Content-Type": "application/json", "Accept": "text/event-stream"})
    with urllib.request.urlopen(req, timeout=120) as r:
        outcome = "stream ended with no done/error event"
        for raw in r:
            line = raw.decode(errors="replace").strip()
            if not line.startswith("data:"):
                continue
            try:
                ev = json.loads(line[5:].strip())
            except ValueError:
                continue
            if ev.get("type") == "error":
                outcome = "ERROR event: " + str(ev.get("message"))[:200]; break
            if ev.get("type") == "done":
                outcome = "WORKED. Reply: " + str(ev.get("answer"))[:120]; break
        print(outcome)
except urllib.error.HTTPError as e:
    print(f"HTTP {e.code} before any reply: {e.read().decode(errors='replace')[:300]}")
except Exception as e:  # noqa: BLE001
    print("could not send:", str(e)[:200])

print("\n=== Why chat failed (server's own record, newest first)")
sql = "select to_char(created_at, 'YYYY-MM-DD HH24:MI') as at, left(payload->>'error', 500) from ingest_events where kind = 'chat_stream_failed' order by created_at desc limit 5"
print(run("sudo -u postgres psql -d athena -tA -F ' | ' -c \"" + sql + "\"") or "(no chat failures recorded)")

print("\n=== Other recent failures")
sql = "select to_char(created_at, 'YYYY-MM-DD HH24:MI') as at, kind, left(payload::text, 200) from ingest_events where kind like '%failed%' and kind <> 'chat_stream_failed' order by created_at desc limit 3"
print(run("sudo -u postgres psql -d athena -tA -F ' | ' -c \"" + sql + "\"") or "(none)")

print("\n=== Recent errors in the service log")
print(run("journalctl -u athena.service -n 300 --no-pager 2>/dev/null | grep -i -E 'error|traceback|exception' | tail -12") or "(none)")

print("\n=== Settings (secrets hidden)")
for k in ("ATHENA_MODEL", "USER_NAME", "USER_TIMEZONE"):
    print(f"{k} = {env.get(k, '(missing)')}")
for k in ("ANTHROPIC_API_KEY", "OPENAI_API_KEY"):
    v = env.get(k, "")
    print(f"{k} = {v[:7]}... ({len(v)} chars)" if v else f"{k} = (missing)")

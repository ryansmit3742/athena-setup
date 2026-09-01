# Checks the Anthropic and OpenAI keys saved on this Athena server, one line each.
# Run ON the server:  curl -fsSL https://raw.githubusercontent.com/ryansmit3742/athena-setup/main/check_keys.py | python3
# Nothing is stored or sent anywhere except to Anthropic and OpenAI, using the keys already on this server.
import json, urllib.request, urllib.error

ENV_PATH = "/root/athena/.env"
FIX = "sed -i 's|^{var}=.*|{var}=PASTE_NEW_KEY_HERE|' /root/athena/.env && systemctl restart athena.service"

env = {}
for line in open(ENV_PATH):
    if "=" in line and not line.startswith("#"):
        k, v = line.rstrip("\n").split("=", 1)
        env[k] = v


def call(url, headers, body):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers={**headers, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, r.read().decode()[:400]
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:400]
    except Exception as e:  # noqa: BLE001
        return 0, str(e)


def verdict(name, var, status, text):
    low = text.lower()
    fix = FIX.format(var=var)
    if status == 0:
        return f"{name}: could not reach the service ({text[:80]}). Check the server's internet connection."
    if status in (401, 403):
        return f"{name}: WRONG KEY. The service does not recognise it.\n   Fix: make a new key on the site, then run:\n   {fix}"
    if any(m in low for m in ("credit balance", "insufficient_quota", "exceeded your current quota", "billing")):
        return f"{name}: KEY IS RIGHT BUT NO CREDIT. Add credit on the site.\n   (OpenAI can keep saying 'quota' for a few minutes after adding credit; if it persists, make a new key and run:)\n   {fix}"
    if 200 <= status < 300:
        return f"{name}: OK"
    return f"{name}: error {status}: {text[:160]}"


anthropic = call(
    "https://api.anthropic.com/v1/messages",
    {"x-api-key": env.get("ANTHROPIC_API_KEY", ""), "anthropic-version": "2023-06-01"},
    {"model": env.get("ATHENA_MODEL", "claude-sonnet-5"), "max_tokens": 5, "messages": [{"role": "user", "content": "hi"}]},
)
openai = call(
    "https://api.openai.com/v1/embeddings",
    {"Authorization": "Bearer " + env.get("OPENAI_API_KEY", "")},
    {"model": "text-embedding-3-small", "input": "hi"},
)
print(verdict("Anthropic", "ANTHROPIC_API_KEY", *anthropic))
print(verdict("OpenAI", "OPENAI_API_KEY", *openai))

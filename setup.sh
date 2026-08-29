#!/usr/bin/env bash
# Athena setup wizard — creates your own private Athena server, end to end, from a Mac
# terminal with no prior setup. Run it with:
#
#   curl -fsSL https://raw.githubusercontent.com/ryansmit3742/athena-setup/main/setup.sh | bash
#
# It asks for four things (a Hetzner account, an Anthropic key, an OpenAI key, a Tailscale
# key), one at a time, explaining exactly where to get each one. Then it creates the server,
# installs Athena, and prints the App URL and App token the iPhone app asks for.
#
# Nothing you type here goes anywhere except: Hetzner (to create your server) and your own
# new server (to configure Athena). This script and this repo never see or store your keys.
set -euo pipefail

# --- Athena's own source lives in a private repo. Whoever sent you this link gives you a
# deploy key separately (a block of text starting with -----BEGIN OPENSSH PRIVATE KEY-----),
# never published here -- paste it in when asked below.
SOURCE_REPO="git@github.com:ryansmit3742/athena.git"
CLOUD_INIT_URL="https://raw.githubusercontent.com/ryansmit3742/athena-setup/main/cloud-init.yaml"
API="https://api.hetzner.cloud/v1"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# ---------------------------------------------------------------------------
# Look and feel
# ---------------------------------------------------------------------------
BOLD="$(tput bold 2>/dev/null || true)"
DIM="$(tput dim 2>/dev/null || true)"
RESET="$(tput sgr0 2>/dev/null || true)"
BLUE="$(tput setaf 4 2>/dev/null || true)"
GREEN="$(tput setaf 2 2>/dev/null || true)"
RED="$(tput setaf 1 2>/dev/null || true)"

say()   { printf '%s\n' "$1"; }
head1() { printf '\n%s%s%s\n\n' "$BOLD" "$1" "$RESET"; }
info()  { printf '%s%s%s\n' "$DIM" "$1" "$RESET"; }
ok()    { printf '%s✓ %s%s\n' "$GREEN" "$1" "$RESET"; }
fail()  { printf '%s✗ %s%s\n' "$RED" "$1" "$RESET" >&2; }
link()  { printf '%s%s%s\n' "$BLUE" "$1" "$RESET"; }

# ---------------------------------------------------------------------------
# One question, asked until it looks right. $1 label, $2 why (one line), $3 link,
# $4 prompt text, $5 regex the answer must match, $6 "secret" to mask input.
# ---------------------------------------------------------------------------
ask() {
  local label="$1" why="$2" url="$3" prompt="$4" pattern="$5" secret="${6:-}"
  local value=""
  head1 "$label"
  say "$why"
  say ""
  link "$url"
  say ""
  while true; do
    if [ "$secret" = "secret" ]; then
      read -r -s -p "$prompt " value; printf '\n'
    else
      read -r -p "$prompt " value
    fi
    value="$(printf '%s' "$value" | xargs)"   # trim whitespace
    if [ -z "$value" ]; then
      fail "Can't be empty — paste the value and press Return."
      continue
    fi
    if [ -n "$pattern" ] && ! [[ "$value" =~ $pattern ]]; then
      fail "That doesn't look like the right format. Double check you copied the whole thing, then try again."
      continue
    fi
    ok "Got it."
    printf '%s' "$value"
    return 0
  done
}

hc() {  # hc METHOD PATH [JSON]  — talk to the Hetzner API
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    curl -sS -X "$method" "$API$path" -H "Authorization: Bearer $HCLOUD_TOKEN" -H "Content-Type: application/json" -d "$body"
  else
    curl -sS -X "$method" "$API$path" -H "Authorization: Bearer $HCLOUD_TOKEN"
  fi
}
jsonq() { python3 -c "import sys, json; d = json.load(sys.stdin); print(eval(sys.argv[1]))" "$1"; }

# ---------------------------------------------------------------------------
# Welcome
# ---------------------------------------------------------------------------
clear 2>/dev/null || true
head1 "Setting up your own Athena"
say "This creates a small private server, puts Athena on it, and hands you back an App"
say "URL and a token to paste into the iPhone app. Takes about 15 minutes. Nothing you"
say "type here is stored by this script or sent anywhere except Hetzner and your own new"
say "server — both of which you're about to create and own."
say ""
read -r -p "Press Return to start… "

# ---------------------------------------------------------------------------
# Step 1 of 5: Hetzner (the server itself)
# ---------------------------------------------------------------------------
HCLOUD_TOKEN="$(ask \
  "Step 1 of 5 — Hetzner (your server)" \
  "This is the actual computer Athena will run on, about \$5/month. Go to the link below, sign up (needs a payment method), click \"New project\" and name it anything, then inside that project go to Security → API Tokens → Generate API Token with Read & Write permission. Paste it below." \
  "https://console.hetzner.cloud" \
  "Hetzner API token:" \
  '^[A-Za-z0-9]{32,80}$')"

# ---------------------------------------------------------------------------
# Step 2 of 5: Anthropic (Athena's mind)
# ---------------------------------------------------------------------------
ANTHROPIC_API_KEY="$(ask \
  "Step 2 of 5 — Anthropic (Athena's mind)" \
  "This is Claude, the AI model behind everything Athena says. Sign up at the link below, go to Settings → Plans & Billing and add a card with auto-reload on, then Settings → API Keys → Create Key. Paste it below." \
  "https://console.anthropic.com" \
  "Anthropic API key:" \
  '^sk-ant-' \
  secret)"

# ---------------------------------------------------------------------------
# Step 3 of 5: OpenAI (memory search)
# ---------------------------------------------------------------------------
OPENAI_API_KEY="$(ask \
  "Step 3 of 5 — OpenAI (her memory search)" \
  "This powers finding an old note or fact when you ask for it — usage is tiny, usually cents a month. Sign up at the link below, add a few dollars of credit under Settings → Billing, then API Keys → Create new secret key. Paste it below." \
  "https://platform.openai.com" \
  "OpenAI API key:" \
  '^sk-' \
  secret)"

# ---------------------------------------------------------------------------
# Step 4 of 5: Tailscale (keeps it private)
# ---------------------------------------------------------------------------
TAILSCALE_AUTH_KEY="$(ask \
  "Step 4 of 5 — Tailscale (keeps it private)" \
  "A private network between just your phone and Athena's server — nothing about her is ever exposed to the public internet. Sign in at the link below with Google, Microsoft, or Apple, then Settings → Keys → Generate auth key. Paste it below. (Also install the Tailscale app on your iPhone and sign in with the same account — you can do that anytime before or after this finishes.)" \
  "https://login.tailscale.com" \
  "Tailscale auth key:" \
  '^tskey-')"

head1 "Step 5 of 5 -- Athena's source"
say "Whoever sent you this link should have given you a deploy key separately (a text, an"
say "email -- not a public page): several lines starting with -----BEGIN OPENSSH PRIVATE KEY-----."
say "Paste the whole block below, then press Return."
say ""
DEPLOY_KEY_FILE="$(mktemp)"
trap 'rm -f "$DEPLOY_KEY_FILE"' EXIT
while IFS= read -r deploy_key_line; do
  printf '%s\n' "$deploy_key_line" >> "$DEPLOY_KEY_FILE"
  [[ "$deploy_key_line" == *"END OPENSSH PRIVATE KEY"* ]] && break
done
chmod 600 "$DEPLOY_KEY_FILE"
if ! grep -q "BEGIN OPENSSH PRIVATE KEY" "$DEPLOY_KEY_FILE"; then
  fail "That didn't look like a key -- check with whoever gave it to you and try again."
  exit 1
fi
ok "Got it."

head1 "One more thing"
read -r -p "What's your first name? Athena will use it. " USER_NAME
USER_NAME="$(printf '%s' "${USER_NAME:-there}" | xargs)"
DETECTED_TZ=""
if [ -f /etc/localtime ]; then
  DETECTED_TZ="$(readlink /etc/localtime 2>/dev/null | sed -n 's#.*/zoneinfo/##p')"
fi
read -r -p "Your timezone [${DETECTED_TZ:-America/New_York}]: " USER_TIMEZONE
USER_TIMEZONE="${USER_TIMEZONE:-${DETECTED_TZ:-America/New_York}}"

# ---------------------------------------------------------------------------
# Build it
# ---------------------------------------------------------------------------
head1 "Building your server"

SERVER_NAME="athena"
SSH_KEY_PATH="$HOME/.ssh/athena-$SERVER_NAME"

say "Creating an SSH key…"
if [ ! -f "$SSH_KEY_PATH" ]; then
  ssh-keygen -q -t ed25519 -N "" -C "athena-$SERVER_NAME" -f "$SSH_KEY_PATH"
fi
PUBKEY="$(cat "$SSH_KEY_PATH.pub")"
KEY_NAME="athena-$SERVER_NAME"
KEY_ID="$(hc GET "/ssh_keys?name=$KEY_NAME" | jsonq "(d['ssh_keys'][0]['id'] if d['ssh_keys'] else '')")"
if [ -z "$KEY_ID" ]; then
  KEY_ID="$(hc POST /ssh_keys "$(python3 -c "import json,sys; print(json.dumps({'name': sys.argv[1], 'public_key': sys.argv[2]}))" "$KEY_NAME" "$PUBKEY")" | jsonq "d['ssh_key']['id']")"
fi
ok "SSH key ready."

say "Creating the server (this takes about a minute)…"
CLOUD_INIT="$(curl -fsSL "$CLOUD_INIT_URL")"
SERVER_JSON="$(hc GET "/servers?name=$SERVER_NAME")"
SERVER_ID="$(echo "$SERVER_JSON" | jsonq "(d['servers'][0]['id'] if d['servers'] else '')")"
if [ -z "$SERVER_ID" ]; then
  CREATE_BODY="$(python3 - "$SERVER_NAME" "$KEY_ID" "$CLOUD_INIT" <<'PY'
import json, sys
name, key_id, user_data = sys.argv[1:4]
print(json.dumps({
    "name": name, "server_type": "cx22", "location": "ash", "image": "ubuntu-24.04",
    "ssh_keys": [int(key_id)], "user_data": user_data, "labels": {"app": "athena"},
}))
PY
)"
  CREATED="$(hc POST /servers "$CREATE_BODY")"
  SERVER_ID="$(echo "$CREATED" | jsonq "d.get('server', {}).get('id') or sys.exit('create failed: ' + json.dumps(d)[:400])")"
fi
IP="$(hc GET "/servers/$SERVER_ID" | jsonq "d['server']['public_net']['ipv4']['ip']")"
ok "Server created at $IP."

SSH=(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=yes "root@$IP")
say "Waiting for it to finish booting (up to a few minutes)…"
for _ in $(seq 1 60); do
  if "${SSH[@]}" test -f /var/lib/athena-cloud-init-done 2>/dev/null; then break; fi
  sleep 10
done
"${SSH[@]}" test -f /var/lib/athena-cloud-init-done || { fail "The server didn't finish booting in time. Try running this again in a few minutes — it picks up where it left off."; exit 1; }
ok "Server is ready."

say "Downloading Athena…"
GIT_SSH_COMMAND="ssh -i $DEPLOY_KEY_FILE -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes" \
  git clone --depth 1 -q "$SOURCE_REPO" "$WORKDIR/athena" \
  || { fail "Couldn't download Athena's source -- double check the key with whoever gave it to you."; exit 1; }
rm -rf "$WORKDIR/athena/.git"
ok "Downloaded."

say "Uploading it to your server…"
"${SSH[@]}" "mkdir -p /root/athena"
tar -C "$WORKDIR/athena" -cf - . | "${SSH[@]}" "tar -x -C /root/athena"
ok "Uploaded."

say "Uploading your settings…"
"${SSH[@]}" "umask 077 && cat > /root/athena/deploy/cloud/provision.env" <<ENV
ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY
OPENAI_API_KEY=$OPENAI_API_KEY
USER_NAME=$USER_NAME
USER_TIMEZONE=$USER_TIMEZONE
TUNNEL=tailscale
TAILSCALE_AUTH_KEY=$TAILSCALE_AUTH_KEY
ENV
ok "Done."

head1 "Installing Athena (this takes a few minutes — hang tight)"
"${SSH[@]}" "bash /root/athena/deploy/cloud/install.sh"

head1 "You're all set, $USER_NAME"
APP_URL="$("${SSH[@]}" cat /root/athena/app-url 2>/dev/null || true)"
APP_TOKEN="$("${SSH[@]}" cat /root/athena/app-token 2>/dev/null || true)"
say "Go back to the Athena app on your phone and enter:"
say ""
say "  App URL:   ${APP_URL:-<run: ssh -i $SSH_KEY_PATH root@$IP cat /root/athena/app-url>}"
say "  App token: ${APP_TOKEN:-<run: ssh -i $SSH_KEY_PATH root@$IP cat /root/athena/app-token>}"
say ""
say "That's the whole login. Keep this terminal window until you've copied both."

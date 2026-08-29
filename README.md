# Setting up your own Athena

Run this in Terminal on a Mac:

```
curl -fsSL https://raw.githubusercontent.com/ryansmit3742/athena-setup/main/setup.sh | bash
```

It walks you through everything — four accounts to create (with exact click-by-click steps
for each), then it builds your server and installs Athena automatically. About 15 minutes,
most of it just creating accounts. At the end it prints an App URL and a token; enter both
in the Athena iPhone app and you're in.

Nothing you type into the wizard is stored by this script or sent anywhere except Hetzner
(to create your server) and your own new server (to configure Athena).

## What this repo is

Just the setup wizard. Athena's actual code lives in a private repository; the wizard
fetches a fresh, one-hour, read-only download credential automatically and pulls the code
straight onto your new server — you never need access to that repository yourself, and
there's nothing to paste or be sent. See `setup.sh` for exactly what it does; it's a plain
shell script, nothing hidden.

## If something goes wrong partway through

Run the same command again — it's safe to re-run. It reuses the server it already created
(matched by name) rather than making a second one, and picks up from wherever it stopped.

## Questions

Reach out to whoever sent you this link.

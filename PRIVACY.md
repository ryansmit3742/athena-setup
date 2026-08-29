# Athena Privacy Policy

Athena is a self-hosted personal assistant. The iPhone app is a window into a server
that you own and control. That design is the whole privacy policy:

**We collect nothing.** The app talks to exactly one place: your own server, over your
own private Tailscale network. There is no analytics SDK, no tracking, no account with
us, and no server of ours in the middle. We cannot see your messages, your email, your
transactions, your memories, or anything else, because none of it ever reaches us.

**Your data lives on your server.** Everything Athena knows (chats, memory, connected
email, bank data via your own Plaid account, files you share with her) is stored on the
server you created during setup, in your own hosting account. You can delete all of it
at any time: Settings, Server, Cancel server erases the server and everything on it.

**Third parties you bring.** Athena works by calling AI providers (Anthropic, OpenAI)
and any services you choose to connect (Google, Plaid, and so on) using YOUR OWN keys
and accounts. Those requests go from your server directly to those providers under
their privacy policies. We are not a party to any of them.

**Push notifications.** Notifications are sent from your server through Apple's push
service. The notification content comes from your server; we do not see it.

**Demo mode.** The in-app demo uses built-in sample data. Nothing about you is
collected there either.

Questions: reach out to whoever sent you the install link.

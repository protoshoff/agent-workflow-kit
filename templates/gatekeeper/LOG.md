# Gate Keeper LOG ({{PROJECT}}) - append-only, one line per event, local time via `TZ={{TZ}} date '+%Y-%m-%d %H:%M %Z'` (never guessed)

# Entry format: `YYYY-MM-DD HH:MM TZ | <kind> | <one or two sentences, facts first: ticket/PR ids, FULL shas, counts>`
# kinds seen: setup, ruling, grant, relay, verify, handoff, correction, deploy, merge, ask, update
# Write a HANDOFF block here before your own compaction. Do not retro-edit; add a `correction` line.

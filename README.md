# Summary Chest Rules

Keeps or discards the four chests of the victory summary according to their rarity, without pressing
KEEP/DROP four times.

<!-- drh:show -->
**No hotkey.** The mod is always active; configure it in **Settings → ADVANCED → Summary Chest Rules**.

- **Keep RARE / LEGENDARY / UNCOMMON / COMMON**: each rarity is kept by default; turn one off to discard it.
- **Keep item boxes**: small and royal item boxes are kept by default.
- **Keep timeout**: seconds to wait for the server to confirm KEEP before giving up.

When a run ends, the mod waits for the summary to be ready and resolves the chests one by one with the
same calls as the KEEP and DROP buttons. It does not open the chests: it only decides whether they go to
the inventory or are discarded. The server still decides their contents.

Changing any option resumes processing if it was paused.
<!-- /drh:show -->

## Other automation

If another mod also collects the summary chests, do not run both automations on the same run: leave one
of them off while the other is active.

## Data

`settings.json` (written by the API) and `last.log` live in `data/summary_chest_rules/`.

## License

MIT. See `LICENSE`.
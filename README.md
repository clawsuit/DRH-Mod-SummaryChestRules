# Summary Chest Rules

Keeps or discards the four chests of the victory summary according to their rarity, without pressing
KEEP/DROP four times.

<!-- drh:show -->
**No hotkey.** The mod is always active; configure it from **Settings → ADVANCED → Summary Chest Rules**.

- **Keep RARE / LEGENDARY / UNCOMMON / COMMON**: each rarity is kept by default; uncheck to discard.
- **Keep item boxes**: small and royal item boxes are kept by default.
- **Keep timeout**: seconds to wait for the server to confirm KEEP before giving up.

When a run ends, the mod waits for the summary to be ready and resolves the chests one by one with the
same calls as the KEEP and DROP buttons. It does not open the chests: it only decides whether they go
to the inventory or are discarded. The server still decides their contents.

If chest storage is full, the game's own storage-full prompt appears so you can free a slot or
abandon the chest. If **Full Inventory** is installed, the mod applies the same temporary client
storage allowance as that mod, so it does not stop at the client limit; the server still decides. If
the server rejects a transaction, the mod pauses and leaves that chest for you to handle.

Changing any option resumes processing if it was paused.
<!-- /drh:show -->

## Other automation

If another mod also collects the summary chests, do not run both automations on the same run: leave
one of them off while the other is active.

## Data

`settings.json` (written by the API) and `last.log` live in `data/summary_chest_rules/`.

## License

MIT. See `LICENSE`.

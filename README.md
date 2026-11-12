# Summary Chest Rules

Keeps or discards the four chests of the victory summary according to their rarity, without pressing
KEEP/DROP four times.

<!-- drh:show -->
**No hotkey.** Configure it from the hub (`F1`) → **Summary Chests** → **OPTIONS**.
The hub starts in English, and its **EN/ES** button also translates these options.

- **Enabled**: off by default; turn it on so the mod processes the chests.
- **Keep RARE / LEGENDARY / UNCOMMON / COMMON**: each rarity is either kept or discarded.
- **Keep Item boxes**: small and royal item boxes.
- **When storage is full**: pause and warn, or discard.

When a run ends, the mod waits for the summary to be ready and resolves the chests one by one with the
same calls as the KEEP and DROP buttons. It does not open the chests: it only decides whether they go
to the inventory or are discarded. The server still decides their contents.

If chest storage is full, the **When storage is full** rule decides. Changing the options resumes
processing if it was paused.
<!-- /drh:show -->

## Other automation

If another mod also collects the summary chests, do not run both automations on the same run: leave
one of them off while the other is active.

## Dependency

Requires **Mod Hub API** (`mod_hub_api`). It works without the hub panel, but without the hub there is
no in-game way to change the options (the values in `settings.json` are used).

## Data

`settings.json` and `last.log` live in `data/summary_chest_rules/`.

## License

MIT. See `LICENSE`.

# Summary Chest Rules

Keeps or discards the four chests of the victory summary according to their rarity, without pressing
KEEP/DROP four times.

<!-- drh:show -->
**No hotkey.** The mod is active whenever it is loaded; disable it in the launcher. Configure the rules
in **Settings → MODS → Summary Chest Rules**.

- **Keep RARE / LEGENDARY / UNCOMMON / COMMON**: each rarity is kept by default; uncheck to discard.
- **Keep item boxes**: small and royal item boxes are kept by default.
- **Keep timeout**: seconds to wait for the server to confirm a KEEP before that chest is left to you.

When a run ends, the mod waits for the summary and resolves the chests one by one with the same calls
as the KEEP and DROP buttons. It does not open them: it only decides whether they go to the inventory
or are discarded. The server still decides their contents. A small line at the bottom of the screen
tells you what it did or why it paused.

If chest storage is full, it pauses once and gives you the game's own storage-full prompt; it does not
retry the same chest. If the server rejects a chest, that chest is left to you and the remaining ones
continue (one rejection per summary). If a KEEP takes too long, that chest is left to you and the rest
continue. If the whole summary ends up clean after a pause, the mod resumes by itself. Changing an
option also resumes it.

If **Full Inventory** is loaded, the mod skips the client-side room check, as that mod allows chests
past the standard storage limit; the server still decides.

Do not run it together with **Auto Dungeon / Loot Manager** while its automatic loot is on: both handle
the same summary chests. **Dungeon Minimap** is compatible; it does not touch the chests.
<!-- /drh:show -->

## Compatibility

- **Do not use this mod together with Auto Dungeon / Loot Manager while its automatic loot is on.**
  Both keep or discard the same summary chests, and the rules would become unpredictable. Leave one
  of the two handling loot.
- **Dungeon Minimap is compatible**: it draws the map and does not touch the summary chests.
- **Instant Victory Reveal** is compatible, but this mod waits for the chest art before acting.

## Data

`settings.json` (written by the API) and `last.log` live in `data/summary_chest_rules/`. The old
`enabled` value is ignored; the removed `whenFull` option is ignored too.

## Requirements

DRH 18 and Mod API 1.5.0 or a compatible later 1.x. It is an `extends` mod, so a big DRH update may
break it.

## License

MIT. See `LICENSE`.
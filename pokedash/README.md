# PokeDash

Your favourite Pokemon roaming your desktop — port of [samgrande/PokeDash](https://github.com/samgrande/PokeDash) (DankMaterialShell) to Noctalia.

## Plugin

| Field | Value |
|---|---|
| ID | `gloves/pokedash` |
| Entry | `[[desktop_widget]] display` → `desktop.luau` |
| API | `18` |
| Module | `roster.luau` (ported from `PokeDashGenerator.js`) |

## What it does

Static centered desktop widget showing an animated Pokemon GIF. Pick a Pokemon from 52 entries (Pikachu, Bulbasaur, Charmander, Squirtle, Mew, Gengar, Eevee, ... Tauros), choose sprite style (`normal` Gen V animated vs `showdown`), background style, and scale.

Remote GIFs are downloaded from PokeAPI (`raw.githubusercontent.com/PokeAPI/sprites`) on demand and cached in `pluginDataDir()/sprites/{dexId}-{style}.gif`. `ui.image` requires local files, so the first selection of a new Pokemon shows a placeholder until download finishes, then re-renders. Cached files survive updates.

## Settings

| Key | Type | Default | Description |
|---|---|---|---|
| `selected_critter` | `select` (52) | `Pikachu` | Which Pokemon to display |
| `sprite_style` | `select normal|showdown` | `normal` | Sprite set |
| `background_style` | `select transparent|dms|glass` | `transparent` | Background behind sprite |
| `sprite_scale` | `int 50-250` | `100` | Sprite size % |

All live in **Settings → Plugins** per-widget.

## DMS parity

- Roster/sprite URLs: exact port of `PokeDashGenerator.js` (`defaultRoster`, `getByName`, `spriteUrl`).
- Styling: `transparent` / `dms` (`Theme.surfaceContainer` → `surface_container`) / `glass` (rgba 0,0,0,0.15 + border) — mapped to `ui.column fill`.
- Scale: `frameW*2*scale` → `width`/`height` (64px base at 100%, like DMS `64*scale`).
- v1 is static (DMS current widget is also static centered; original roaming TODO not ported). Position is host-owned via desktop editor.

## Limitations

- `ui.image` loads local files only — network fetch is required.
- Animated GIF looping relies on Noctalia sticker/desktop image support for GIF.
- No click/interaction yet (DMS left-click opened settings — Noctalia settings via widget inspector).

## Development

```sh
# place in dev dir or add path source, then reload config
noctalia msg plugin gloves/pokedash:display all debug
```

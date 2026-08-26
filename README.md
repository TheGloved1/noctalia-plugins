# noctalia-plugins

Personal Noctalia plugin source (gloves).

Plugins:

- `gloves/keybind-cheatsheet` — Searchable keybindings for Mango, Hyprland, Niri (forked from `kenn/keybind-cheatsheet` with Niri CPU fix)
- `gloves/screenshot-actions` — Region screenshot → menu for Swappy markup or OCR
- `gloves/activate-linux` — Windows-style Activate Linux watermark (port of `hthienloc/dms-activate-linux`)
- `gloves/pokedash` — Your favourite Pokemon on the desktop (port of `samgrande/PokeDash`, 52 roster, PokeAPI sprites)

Add source:

```toml
[[plugins.source]]
kind = "git"
location = "https://github.com/TheGloved1/noctalia-plugins.git"
name = "gloves"
```

Catalog is auto-generated via `.github/workflows/scripts/update-catalog.py` — do not edit `catalog.toml` manually.

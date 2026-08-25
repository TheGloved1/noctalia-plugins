# noctalia-plugins

Personal Noctalia plugin source (gloves).

Plugins:

- `gloves/keybind-cheatsheet` — Searchable keybindings for Mango, Hyprland, Niri (forked from `kenn/keybind-cheatsheet` with Niri CPU fix)
- `gloves/screenshot-actions` — Region screenshot → menu for Swappy markup or OCR

Add source:

```toml
[[plugins.source]]
kind = "git"
location = "https://github.com/TheGloved1/noctalia-plugins.git"
name = "gloves"
```

Catalog is auto-generated via `.github/workflows/scripts/update-catalog.py` — do not edit `catalog.toml` manually.

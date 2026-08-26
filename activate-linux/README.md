# Activate Linux

Windows-style “Activate Linux” watermark for Noctalia desktop — port of [hthienloc/dms-activate-linux](https://github.com/hthienloc/dms-activate-linux) (DankMaterialShell).

## Plugin

| Field | Value |
|---|---|
| ID | `gloves/activate-linux` |
| Entry | `[[desktop_widget]] watermark` → `desktop.luau` |
| API | `18` |

## What it does

Renders two translucent text lines (classic “Activate Linux” / “Go to Settings to activate Linux.”). Opacity and font sizes are adjustable; enable **Customize Text** to override both lines. Placement is host-owned — drag the widget to the bottom-right corner in **Desktop → Edit Widgets** (replaces DMS 50px margins).

## Settings

All settings live in **Settings → Plugins** (gear on the plugin row) or per-widget in the desktop editor.

| Key | Type | Default | Description |
|---|---|---|---|
| `watermark_opacity` | `int 0-100` | `40` | Transparency of the watermark |
| `first_line_size` | `int 8-72` | `22` | Font size for first line |
| `second_line_size` | `int 8-48` | `14` | Font size for second line |
| `customize_text` | `bool` | `false` | Enable manual text override |
| `first_line` | `string` | `Activate Linux` | Custom first line (visible when customize_text=true) |
| `second_line` | `string` | `Go to Settings...` | Custom second line (visible when customize_text=true) |

Colors follow the active palette via `on_surface_variant`; opacity is applied per-label (not a translucent background, so text stays crisp).

## Differences from DMS version

- No fixed `anchors.rightMargin 50` — position/sizing/rotation handled by Noctalia’s desktop widget editor.
- No `Theme`/`I18n.tr` runtime — strings are plain (i18n via `translations/en.json` for settings only).
- Roadmap items (flexible presets, dynamic variables, per-monitor toggle, non-interactive click-through) not ported in v1.

## Development

Hot-reloads on `.luau` edit; `plugin.toml`/`translations` need a config reload.

```sh
noctalia msg plugin gloves/activate-linux:watermark all debug  # example IPC if you add onIpc
```

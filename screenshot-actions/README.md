# Screenshot Actions

A Noctalia v5 plugin for region screenshots with a quick action menu: open the
capture in Noctalia's built-in annotation editor or run OCR to find text in the
image — plus a paged, keyboard-navigable history browser of past captures.

Capture, saving, and clipboard are handled by Noctalia's built-in screenshot
tool (`screenshot-region` / `annotate` IPC + `[shell.screenshot]` policy).

## Plugin

| Field | Value |
| --- | --- |
| ID | `gloves/screenshot-actions` |
| Entries | Panels: `actions` (action menu), `ocr-result` (OCR text view), `history` (capture browser); service: `service` |

## Requirements

- **`tesseract`** — OCR engine for Find Text (plus your language packs, e.g. `tesseract-data-eng`)
- **`wl-clipboard`** (`wl-copy`) — clipboard for the Copy action

No capture tools needed: region selection and saving use the built-in screenshot
tool. `wlr-screencopy` compositor support is required (Niri, Hyprland, Sway, …).

Recommended Settings → Screenshot values when using this plugin:

- Saving **on** (`save_to_file = true`) — the plugin needs the capture file.
- Edit Before Saving or Copying **off** (`annotate = false`) — otherwise every
  capture opens the editor *and* the actions panel.
- Run Command **on** (`pipe_to_command = true`) with the notify command below —
  this is what makes delivery instant and cancel-safe (see Pipe setup).

## Pipe setup (recommended)

The plugin cannot write shell settings itself (plugins are read-only for
global config), so set this once in Settings → Screenshot:

- **Run Command** → on
- **Command** → paste exactly:

```sh
cat > /dev/null; noctalia msg plugin gloves/screenshot-actions:service all captured "$NOCTALIA_SCREENSHOT_PATH"
```

How it works: after every capture the shell saves the PNG (requires Saving on),
then runs this command with the PNG on stdin (`cat` drains it) and the saved
path in `$NOCTALIA_SCREENSHOT_PATH`. The service opens the actions panel for
that path — no polling, no timeout window. Cancelling with `ESC` fires nothing,
so the next `MOD+SHIFT+S` always works.

Notes:

- While Run Command points at the plugin, **every** shell screenshot (region
  *and* fullscreen, however triggered) opens the actions panel. Turn Run
  Command off to stop that.
- Without the pipe configured, the plugin falls back to polling the screenshot
  directory for 60s after each `capture` press.

## Usage

Start a region capture from any keybind or script:

```sh
noctalia msg plugin gloves/screenshot-actions:service all capture
```

After a capture, the **actions panel** opens with a preview and three actions:

- **Annotate** — opens the capture in Noctalia's built-in annotation editor
  (`noctalia msg annotate <path>`). Saving happens in that editor.
- **Copy** — copies the image to the clipboard via `wl-copy`.
- **Find Text** — runs `tesseract` OCR on the capture and opens the
  **OCR result panel** with the recognized text in an editable multiline area,
  so you can correct, trim, or extend it before copying or searching. Detected
  URLs can be opened directly and detected email addresses can open a mail
  composer. **Back** returns to the actions panel without clearing the result.

Saving to the screenshot directory and copying to the clipboard follow your
global Settings → Screenshot policy.

The **history panel** browses past captures as a thumbnail grid (Wallhaven-style
pages of 24). Arrow keys or `ctrl+h/j/k/l` move the selection ring — holding a
key repeats — and `Enter`/`Space` (or clicking a tile) opens that capture in the
actions panel. The panel refreshes when a new capture lands.

Open the history panel:

```sh
noctalia msg panel-toggle gloves/screenshot-actions:history
```

Open the action menu (last capture):

```sh
noctalia msg panel-toggle gloves/screenshot-actions:actions
```

## Settings

All settings live in Settings → Plugins (gear on the plugin's row).

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `panel-placement` | `select` | `floating` | How the panels appear: `floating` or `attached`. |
| `panel-along-bar` | `select` | `centered` | Where the panel sits along the bar: `centered` or `near-trigger`. |
| `ocr-language` | `string` | `eng` | Tesseract language code(s) for Find Text (e.g. `eng`, `eng+deu`). |

## IPC

The service is a singleton with no output, so the IPC target is `all`:

```sh
# Start a region capture
noctalia msg plugin gloves/screenshot-actions:service all capture
```

For example, bind it to `SUPER+SHIFT+S` in Hyprland's Lua config:

```lua
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("noctalia msg plugin gloves/screenshot-actions:service all capture"))
```

Summary of every service command:

| Command | Payload | Action |
| --- | --- | --- |
| `capture` | — | Select a region via the built-in tool and save the screenshot |
| `captured` | screenshot path | Delivered by the shell's Run Command; opens the actions panel for that file |
| `status` | — | Show whether a capture is in flight and which delivery mode is active |

## Notes

- The `capture` IPC opens the action menu automatically when a capture finishes.
  With the pipe configured, delivery is event-driven: pressing it again after
  an ESC-cancel just works — no dead window. Without the pipe, a 60s poll
  watch runs instead and a second press restarts it.
- The Annotate action opens Noctalia's built-in editor
  (`noctalia msg annotate <path>`).
- The history grid is read from your `[shell.screenshot]` directory; only
  non-empty PNG files are listed, newest first. The action menu works with any
  capture path set in the plugin's shared `lastCapture` state.
- Captures are transient: they live in your screenshot directory, not in the
  plugin's data directory.

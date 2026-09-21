# Video Browser

A Noctalia v5 plugin that browses every video file under a configurable folder
as a thumbnail grid — nested directories included, folders ignored — sorted
newest first. Selecting a tile opens a preview panel with quick **Copy** (file
path) and **Open** (default application via `xdg-open`) actions.

## Plugin

| Field | Value |
| --- | --- |
| ID | `gloves/video-browser` |
| Entries | Panels: `browser` (thumbnail grid), `preview` (preview + actions) |

## Requirements

- **`xdg-utils`** — provides `xdg-open` for the **Open** action.
- **`ffmpegthumbnailer`** (preferred) or **`ffmpeg`** — used to generate video
  thumbnails. If neither is installed, tiles fall back to a placeholder image.

## Usage

Open the browser panel:

```sh
noctalia msg panel-toggle gloves/video-browser:browser
```

The **browser panel** shows a thumbnail grid (pages of 16). Arrow keys or
`ctrl+h/j/k/l` move the selection ring — holding a key repeats — and
`Enter`/`Space` (or clicking a tile) opens that video in the **preview panel**.

The **preview panel** shows a large thumbnail, the filename, its subfolder
relative to the video folder, and the modification date plus size:

- **Copy** — copies the absolute file path to the clipboard.
- **Open** — launches the file in your default video application.
- **Back** — returns to the browser grid.

Open the preview panel (last selected video) directly:

```sh
noctalia msg panel-toggle gloves/video-browser:preview
```

## Settings

All settings live in Settings → Plugins (gear on the plugin's row).

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `video_dir` | `string` | `~/Videos` | Folder scanned recursively for video files. |
| `panel-placement` | `select` | `floating` | How the panel appears: `floating` or `attached`. |
| `panel-along-bar` | `select` | `centered` | Where the panel sits along the bar: `centered` or `near-trigger`. |

## Notes

- Only non-empty files with a video extension are listed: `mp4`, `mkv`,
  `webm`, `mov`, `avi`, `m4v`, `ts`, `m2ts`, `wmv`, `flv`, `ogv`, `3gp`,
  `mpg`, `mpeg`.
- Sorting uses file modification time (newest first), which stands in for
  creation date since the host only exposes `mtime`.
- The scan recurses through all nested directories with a depth cap of 32 and
  guards against directory cycles.
- Thumbnails are generated in the background with `ffmpegthumbnailer`
  (or `ffmpeg` as fallback) and cached in the plugin's data directory under
  `thumbs/`, keyed by file path and modification time so re-encodes refresh
  automatically. Tiles that have no thumbnail yet show a placeholder; stale
  cache entries are pruned on every scan.

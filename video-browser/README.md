# Video Browser

A Noctalia v5 plugin that lists every video file under a configurable folder —
nested directories included, folders ignored — sorted newest first, with quick
**Copy** (file path) and **Open** (default application via `xdg-open`) actions
per row.

## Plugin

| Field | Value |
| --- | --- |
| ID | `gloves/video-browser` |
| Entries | Panel: `browser` (video list) |

## Requirements

- **`xdg-utils`** — provides `xdg-open` for the **Open** action.

## Usage

Open the browser panel:

```sh
noctalia msg panel-toggle gloves/video-browser:browser
```

Each row shows the filename, its subfolder relative to the video folder, and the
modification date plus size. **Copy** copies the absolute file path to the
clipboard; **Open** launches the file in your default video application. Use the
refresh button in the header to rescan after adding or removing files.

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

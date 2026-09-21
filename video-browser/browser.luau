--!nonstrict
-- Video Browser — recursive video list with Copy / Open actions.
-- Lists ALL video files under the configured folder (nested dirs included,
-- folders themselves ignored), newest first by mtime.

local VIDEO_EXTS = {
  mp4 = true,
  mkv = true,
  webm = true,
  mov = true,
  avi = true,
  m4v = true,
  ts = true,
  m2ts = true,
  wmv = true,
  flv = true,
  ogv = true,
  ["3gp"] = true,
  mpg = true,
  mpeg = true,
}

local MAX_DEPTH = 32

local videos = {} -- { { path =, name =, rel =, mtime =, size = }, ... }
local videoDir = ""
local loadError = ""

local function shellQuote(value)
  return "'" .. tostring(value):gsub("'", [["'"']]) .. "'"
end

local function getConfig(key, default)
  local v = noctalia.getConfig(key)
  if v == nil then return default end
  return v
end

local function extensionOf(name)
  local ext = name:match("%.([%a%d]+)$")
  return ext and ext:lower() or ""
end

local function formatSize(size)
  if not size or size <= 0 then return "0 B" end
  if size < 1024 then return `{size} B` end
  local kb = size / 1024
  if kb < 1024 then return `{string.format("%.1f", kb)} KB` end
  local mb = kb / 1024
  if mb < 1024 then return `{string.format("%.1f", mb)} MB` end
  return `{string.format("%.2f", mb / 1024)} GB`
end

local function formatDate(mtime)
  if not mtime or mtime <= 0 then return "unknown date" end
  return os.date("%Y-%m-%d %H:%M", mtime) or "unknown date"
end

-- ── Loading ──────────────────────────────────────────────────────────────

local function loadVideos()
  videos = {}
  loadError = ""
  local configured = getConfig("video_dir", "~/Videos")
  if type(configured) ~= "string" or configured == "" then
    loadError = "Video folder is not configured"
    return
  end
  videoDir = noctalia.expandPath(configured)

  local rootInfo = noctalia.fileInfo(videoDir)
  if not rootInfo then
    loadError = `Folder not found: {videoDir}`
    return
  end
  if not rootInfo.isDir then
    loadError = `Not a folder: {videoDir}`
    return
  end

  local visited = {}
  local stack = { { dir = videoDir, depth = 0 } }
  while #stack > 0 do
    local current = table.remove(stack)
    local dir, depth = current.dir, current.depth
    if not visited[dir] then
      visited[dir] = true
      local entries = noctalia.listDir(dir)
      if type(entries) == "table" then
        for _, name in ipairs(entries) do
          local path = dir .. "/" .. name
          local info = noctalia.fileInfo(path)
          if info then
            if info.isDir then
              if depth < MAX_DEPTH then
                table.insert(stack, { dir = path, depth = depth + 1 })
              end
            elseif VIDEO_EXTS[extensionOf(name)] and (info.size or 0) > 0 then
              local rel = path:sub(#videoDir + 2)
              table.insert(videos, {
                path = path,
                name = name,
                rel = rel,
                mtime = info.mtime or 0,
                size = info.size or 0,
              })
            end
          end
        end
      end
    end
  end

  table.sort(videos, function(a, b)
    if a.mtime ~= b.mtime then return a.mtime > b.mtime end
    return a.path > b.path
  end)
end

-- ── Actions ────────────────────────────────────────────────────────────────

local function copyVideo(video)
  noctalia.copyToClipboard(video.path, "text/plain;charset=utf-8")
  noctalia.notify("Path copied", video.name)
end

local function openVideo(video)
  local ok = noctalia.runAsync("xdg-open " .. shellQuote(video.path))
  if not ok then
    noctalia.notifyError("Video Browser", "launch failed")
  end
end

-- ── Rendering ──────────────────────────────────────────────────────────────

local function videoRow(video)
  local subdir = video.rel:match("^(.*)/[^/]+$")
  local meta = `{formatDate(video.mtime)}  •  {formatSize(video.size)}`
  return ui.row({ key = video.path, align = "center", gap = 10 }, {
    ui.column({ width = 36, height = 36, radius = 10, fill = "primary/0.15", align = "center", justify = "center" }, {
      ui.glyph({ name = "movie", size = 18, color = "primary" }),
    }),
    ui.column({ flexGrow = 1, gap = 2 }, {
      ui.label({ text = video.name, fontSize = 13, fontWeight = "bold", color = "on_surface", maxLines = 1 }),
      subdir and subdir ~= "" and ui.label({ text = subdir, fontSize = 11, color = "on_surface_variant", maxLines = 1 }) or nil,
      ui.label({ text = meta, fontSize = 11, color = "on_surface_variant", maxLines = 1 }),
    }),
    ui.button({
      text = "Copy",
      glyph = "copy",
      controlSize = "sm",
      variant = "default",
      onClick = function()
        copyVideo(video)
      end,
    }),
    ui.button({
      text = "Open",
      glyph = "play",
      controlSize = "sm",
      variant = "primary",
      onClick = function()
        openVideo(video)
      end,
    }),
  })
end

local function videoList()
  if loadError ~= "" then
    return ui.column({ flexGrow = 1, gap = 8, align = "center", paddingV = 48 }, {
      ui.glyph({ name = "folder-off", size = 40, color = "outline" }),
      ui.label({ text = loadError, fontSize = 14, color = "on_surface_variant" }),
    })
  end
  if #videos == 0 then
    return ui.column({ flexGrow = 1, gap = 8, align = "center", paddingV = 48 }, {
      ui.glyph({ name = "movie", size = 40, color = "outline" }),
      ui.label({ text = "No videos found", fontSize = 14, color = "on_surface_variant" }),
      ui.label({ text = videoDir, fontSize = 11, color = "on_surface_variant" }),
    })
  end

  local rows = {}
  for _, video in ipairs(videos) do
    table.insert(rows, videoRow(video))
  end
  return ui.column({ gap = 8, align = "stretch" }, rows)
end

local function render()
  local countText = loadError ~= "" and "" or `{#videos} videos`
  panel.render(ui.column({ flexGrow = 1, gap = 12, align = "stretch" }, {
    ui.row({ align = "center", gap = 8 }, {
      ui.glyph({ name = "movie", size = 20, color = "primary" }),
      ui.label({ text = "Video Browser", fontSize = 16, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
      ui.label({ text = countText, fontSize = 12, color = "on_surface_variant" }),
      ui.button({ glyph = "refresh", onClick = "onRefresh" }),
      ui.button({ glyph = "close", onClick = "onClose" }),
    }),
    ui.label({ text = videoDir, fontSize = 11, color = "on_surface_variant", maxLines = 1 }),

    ui.scroll({ key = "video-list", flexGrow = 1, gap = 8 }, {
      videoList(),
    }),
  }))
end

-- ── Callbacks ──────────────────────────────────────────────────────────────

function onOpen(_context)
  loadVideos()
  render()
end

function onClose()
  panel.close()
end

function onRefresh()
  loadVideos()
  render()
end

function onKey(chord, pressed)
  if pressed and chord == "Escape" then
    panel.close()
  end
end

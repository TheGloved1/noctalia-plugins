--!nonstrict
-- Video Browser — thumbnail grid (screenshot-actions history layout).
-- Recursive scan of the video folder; one tile per video with a cached
-- thumbnail and title. Selecting a tile opens the preview panel.

local PANEL_WIDTH = 920
local PANEL_PADDING = 28
local COLUMNS = 4
local PAGE_SIZE = COLUMNS * 4
local COLUMN_GAP = 12
local ROW_GAP = 12
local TILE_RADIUS = 12
local MAX_DEPTH = 32

local PLACEHOLDER = noctalia.pluginDir() .. "/assets/video-placeholder.png"

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

local videos = {} -- { { path =, name =, rel =, mtime =, size =, thumb = }, ... }
local videoDir = ""
local loadError = ""
local cursor = 1
local panelOpen = false

local REPEAT_DELAY = 350 -- ms before a held key starts repeating
local REPEAT_INTERVAL = 50 -- ms between repeats
local heldChord = nil
local repeatElapsed = 0

-- Thumbnail generation (sequential background queue)
local thumbIndex = 1
local thumbRunning = false
local thumbTool = "" -- "ffmpegthumbnailer" | "ffmpeg" | "" (unavailable)

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

-- Stable cache key from full path + mtime, so re-encodes refresh thumbs.
local function thumbKey(path, mtime)
  local h = 5381
  local s = path .. "|" .. tostring(mtime or 0)
  for i = 1, #s do
    h = (h * 33 + string.byte(s, i)) % 4294967296
  end
  return string.format("%08x", h)
end

local function thumbBase()
  return noctalia.pluginDataDir() .. "/thumbs"
end

-- ── Loading ──────────────────────────────────────────────────────────────

-- Forward declarations (assigned further below).
local pruneThumbs, pumpThumbs, render

local function loadVideos()
  videos = {}
  loadError = ""
  thumbIndex = 1
  thumbRunning = false
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

  local base = thumbBase()
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
              local mtime = info.mtime or 0
              table.insert(videos, {
                path = path,
                name = name,
                rel = path:sub(#videoDir + 2),
                mtime = mtime,
                size = info.size or 0,
                thumb = base .. "/" .. thumbKey(path, mtime) .. ".jpg",
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

  pruneThumbs()
  pumpThumbs()
end

-- Drop cached thumbs that no longer match any scanned video.
pruneThumbs = function()
  local entries = noctalia.listDir(thumbBase())
  if type(entries) ~= "table" then return end
  local valid = {}
  for _, v in ipairs(videos) do
    valid[thumbKey(v.path, v.mtime) .. ".jpg"] = true
  end
  for _, name in ipairs(entries) do
    if not valid[name] then
      noctalia.removeFile(thumbBase() .. "/" .. name)
    end
  end
end

local function thumbCommand(video, out)
  local base = thumbBase()
  if thumbTool == "ffmpegthumbnailer" then
    return "mkdir -p " .. shellQuote(base)
      .. " && ffmpegthumbnailer -i " .. shellQuote(video.path)
      .. " -o " .. shellQuote(out) .. " -s 384 -q 8 >/dev/null 2>&1"
  end
  return "mkdir -p " .. shellQuote(base)
    .. " && ffmpeg -y -v error -ss 1 -i " .. shellQuote(video.path)
    .. " -vframes 1 -vf scale=384:-1 " .. shellQuote(out) .. " >/dev/null 2>&1"
end

-- Generate missing thumbs one at a time; re-render as each lands.
pumpThumbs = function()
  if thumbRunning or thumbTool == "" then return end
  while thumbIndex <= #videos do
    local v = videos[thumbIndex]
    thumbIndex += 1
    if not noctalia.fileExists(v.thumb) then
      thumbRunning = true
      noctalia.runAsync(thumbCommand(v, v.thumb), function(_)
        thumbRunning = false
        if panelOpen then render() end
        pumpThumbs()
      end)
      return
    end
  end
end

-- ── Actions ────────────────────────────────────────────────────────────────

local function selectVideo(video)
  local thumb = ""
  if video.thumb and noctalia.fileExists(video.thumb) then
    thumb = video.thumb
  end
  noctalia.state.set("selectedVideo", {
    path = video.path,
    name = video.name,
    rel = video.rel,
    mtime = video.mtime,
    size = video.size,
    thumb = thumb,
  })
  panelOpen = false
  panel.close()
  noctalia.togglePanel("gloves/video-browser:preview")
end

-- ── Pagination helpers ──────────────────────────────────────────────────────

local function pageFor(index)
  return math.floor((index - 1) / PAGE_SIZE) + 1
end

local function pageStart(page)
  return (page - 1) * PAGE_SIZE + 1
end

local function pageEnd(page)
  return math.min(page * PAGE_SIZE, #videos)
end

local function totalPages()
  if #videos == 0 then
    return 1
  end
  return math.max(1, math.ceil(#videos / PAGE_SIZE))
end

-- ── Rendering ──────────────────────────────────────────────────────────────

local function columnWidth()
  return math.floor((PANEL_WIDTH - PANEL_PADDING - COLUMN_GAP * (COLUMNS - 1)) / COLUMNS)
end

local function tileSize()
  local width = columnWidth()
  return width, math.floor(width * 9 / 16)
end

local function videoTile(video, index)
  local frameWidth, frameHeight = tileSize()
  local isCursor = index == cursor

  local border = "outline"
  local borderWidth = 1
  if isCursor then
    border = "primary"
    borderWidth = 3
  end

  local thumb = PLACEHOLDER
  if video.thumb and noctalia.fileExists(video.thumb) then
    thumb = video.thumb
  end

  return ui.column({ key = video.path, gap = 4, flexGrow = 1, align = "center" }, {
    ui.image({
      width = frameWidth,
      height = frameHeight,
      path = thumb,
      fit = "cover",
      radius = TILE_RADIUS,
      border = border,
      borderWidth = borderWidth,
      onClick = function()
        cursor = index
        selectVideo(video)
      end,
    }),
    ui.label({
      text = video.name,
      fontSize = 11,
      color = isCursor and "primary" or "on_surface_variant",
      maxLines = 1,
      maxWidth = frameWidth,
      textAlign = "center",
    }),
  })
end

local function videoGrid()
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

  local first = pageStart(pageFor(cursor))
  local last = pageEnd(pageFor(cursor))
  local rows = {}
  local row = {}
  for i = first, last do
    table.insert(row, videoTile(videos[i], i))
    if #row == COLUMNS or i == last then
      table.insert(rows, ui.row({ gap = COLUMN_GAP, align = "stretch" }, row))
      row = {}
    end
  end
  return ui.column({ gap = ROW_GAP, align = "stretch" }, rows)
end

local function pager()
  local page = pageFor(cursor)
  local total = totalPages()
  return ui.row({ align = "center", justify = "center" }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.button({
        key = "prev_page",
        glyph = "chevron-left",
        variant = "ghost",
        onClick = "onPrevPage",
        enabled = page > 1,
      }),
      ui.label({ text = `Page {page} / {total}`, color = "on_surface_variant" }),
      ui.button({
        key = "next_page",
        glyph = "chevron-right",
        variant = "ghost",
        onClick = "onNextPage",
        enabled = page < total,
      }),
    }),
  })
end

render = function()
  local page = pageFor(cursor)
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

    -- Native scroll container, keyed by page so flipping pages resets to top.
    ui.scroll({ key = `page-{page}`, flexGrow = 1, gap = 12 }, {
      videoGrid(),
    }),

    pager(),
  }))
end

-- ── Key handling ────────────────────────────────────────────────────────────

-- Apply a directional chord. Returns whether the cursor actually moved.
local function moveFor(chord)
  if #videos == 0 then
    return false
  end
  local nextCursor = nil
  if chord == "Right" or chord == "ctrl+l" then
    nextCursor = math.min(cursor + 1, #videos)
  elseif chord == "Left" or chord == "ctrl+h" then
    nextCursor = math.max(cursor - 1, 1)
  elseif chord == "Down" or chord == "ctrl+j" then
    nextCursor = math.min(cursor + COLUMNS, #videos)
  elseif chord == "Up" or chord == "ctrl+k" then
    nextCursor = math.max(cursor - COLUMNS, 1)
  end
  if nextCursor == nil or nextCursor == cursor then
    return false
  end
  cursor = nextCursor
  return true
end

local function isDirectional(chord)
  return chord == "Right" or chord == "Left" or chord == "Down" or chord == "Up"
    or chord == "ctrl+l" or chord == "ctrl+h" or chord == "ctrl+j" or chord == "ctrl+k"
end

function onKey(chord, pressed)
  if not pressed then
    if isDirectional(chord) and chord == heldChord then
      heldChord = nil
      repeatElapsed = 0
    end
    return
  end

  if chord == "Escape" then
    onClose()
    return
  end

  if chord == "Return" or chord == "Enter" or chord == "Space" then
    if #videos > 0 then
      selectVideo(videos[cursor])
    end
    return
  end

  if moveFor(chord) then
    render()
  end
  if isDirectional(chord) then
    heldChord = chord
    repeatElapsed = 0
  end
end

function onFrameTick(deltaMs)
  if heldChord == nil then
    return
  end
  repeatElapsed += deltaMs
  local moved = false
  while repeatElapsed >= REPEAT_DELAY do
    if moveFor(heldChord) then
      moved = true
    end
    repeatElapsed -= REPEAT_INTERVAL
    if repeatElapsed < REPEAT_DELAY then
      break
    end
  end
  if moved then
    render()
  end
end

-- ── Callbacks ──────────────────────────────────────────────────────────────

function onOpen(_context)
  if noctalia.commandExists("ffmpegthumbnailer") then
    thumbTool = "ffmpegthumbnailer"
  elseif noctalia.commandExists("ffmpeg") then
    thumbTool = "ffmpeg"
  else
    thumbTool = ""
  end
  loadVideos()
  cursor = 1
  heldChord = nil
  repeatElapsed = 0
  panelOpen = true
  panel.setNeedsFrameTick(true)
  render()
end

function onClose()
  panelOpen = false
  panel.close()
end

function onRefresh()
  thumbIndex = 1
  thumbRunning = false
  loadVideos()
  if cursor > #videos then cursor = #videos end
  if cursor < 1 then cursor = 1 end
  render()
end

function onPrevPage()
  local page = pageFor(cursor) - 1
  if page < 1 then
    return
  end
  cursor = math.min(pageStart(page), #videos)
  render()
end

function onNextPage()
  local page = pageFor(cursor) + 1
  if page > totalPages() then
    return
  end
  cursor = pageStart(page)
  render()
end

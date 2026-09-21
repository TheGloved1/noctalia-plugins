--!nonstrict
-- Video Browser — Preview panel (screenshot-actions actions layout).
-- Large thumbnail, filename, details, and the Copy / Open actions for the
-- video selected in the browser grid.

local STATE_SELECTED_VIDEO = "selectedVideo"

local PLACEHOLDER = noctalia.pluginDir() .. "/assets/video-placeholder.png"

local function shellQuote(value)
  return "'" .. tostring(value):gsub("'", [["'"']]) .. "'"
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

local function render()
  local video = noctalia.state.get(STATE_SELECTED_VIDEO)

  local hasVideo = video and video.path and video.path ~= ""
  local previewPath = PLACEHOLDER
  if hasVideo and video.thumb and video.thumb ~= "" and noctalia.fileExists(video.thumb) then
    previewPath = video.thumb
  end

  local body = ui.column({ flexGrow = 1, gap = 10, padding = 16 }, {
    ui.row({ align = "center", gap = 10 }, {
      ui.glyph({ name = "movie", size = 20, color = "primary" }),
      ui.label({ text = "Preview", flexGrow = 1, fontSize = 18, fontWeight = "bold", color = "on_surface" }),
      ui.button({
        text = "Back",
        glyph = "arrow-left",
        variant = "ghost",
        controlSize = "sm",
        onClick = function()
          panel.close()
          noctalia.togglePanel("gloves/video-browser:browser")
        end,
      }),
      ui.button({
        glyph = "close",
        onClick = function() panel.close() end,
      }),
    }),

    ui.column({ align = "center", justify = "center", gap = 8 }, {
      ui.image({
        path = previewPath,
        height = 220,
        fit = "contain",
        radius = 12,
        borderWidth = 1,
        border = "outline",
        width = 400,
      }),
      hasVideo and ui.label({
        text = video.name,
        fontSize = 14,
        fontWeight = "bold",
        color = "on_surface",
        maxWidth = 420,
        textAlign = "center",
      }) or ui.label({
        text = "No video selected",
        fontSize = 14,
        color = "on_surface_variant",
      }),
      hasVideo and ui.label({
        text = (video.rel or video.path) .. "  •  " .. formatDate(video.mtime) .. "  •  " .. formatSize(video.size),
        fontSize = 11,
        color = "on_surface_variant",
        maxWidth = 420,
        textAlign = "center",
      }) or nil,
    }),

    ui.row({ align = "center", gap = 12 }, {
      ui.button({
        text = "Copy",
        glyph = "copy",
        flexGrow = 1,
        controlSize = "lg",
        variant = "default",
        enabled = hasVideo and true or false,
        onClick = function()
          local v = noctalia.state.get(STATE_SELECTED_VIDEO)
          if not v or not v.path or v.path == "" then return end
          noctalia.copyToClipboard(v.path, "text/plain;charset=utf-8")
          noctalia.notify("Path copied", v.name)
        end,
      }),
      ui.button({
        text = "Open",
        glyph = "play",
        flexGrow = 1,
        controlSize = "lg",
        variant = "primary",
        enabled = hasVideo and true or false,
        onClick = function()
          local v = noctalia.state.get(STATE_SELECTED_VIDEO)
          if not v or not v.path or v.path == "" then return end
          local ok = noctalia.runAsync("xdg-open " .. shellQuote(v.path))
          if not ok then
            noctalia.notifyError("Video Browser", "launch failed")
          end
          panel.close()
        end,
      }),
    }),
  })

  panel.render(body)
end

function onOpen(_context)
  render()
end

function onClose()
end

function onKey(chord, pressed)
  if pressed and chord == "Escape" then
    panel.close()
  end
end

noctalia.state.watch(STATE_SELECTED_VIDEO, function(_)
  render()
end)

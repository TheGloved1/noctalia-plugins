--!nonstrict
-- Thumbnail cache for screenshot grids (history panel, action preview).
--
-- Problem: history tiles pointed ui.image at full-res PNGs (often 1-3MB).
-- Decoding ~16 of them on every panel open stalled first render ~1s.
-- Fix: 400px JPEG thumbs (~15-25KB via vipsthumbnail, ~0.1s each, cached).
-- Generated at capture time (service) and lazily backfilled per page
-- (history). Missing tool or stale cache falls back to the full image,
-- i.e. today's behavior — never an error.

local M = {}

local THUMB_WIDTH = 400

local function shellQuote(value)
  return "'" .. tostring(value):gsub("'", [["'"']]) .. "'"
end

function M.cacheDir()
  return noctalia.expandPath("~/.cache/noctalia/screenshot-actions/thumbs")
end

local function sanitize(name)
  return (tostring(name):gsub("[^%w%.%-]+", "_"))
end

function M.thumbName(name, mtime)
  return sanitize(name) .. "." .. tostring(mtime or 0) .. ".jpg"
end

-- Pure path construction (no I/O): name + mtime identify the thumb.
function M.thumbPath(name, mtime)
  local base = tostring(name):match("([^/]+)$") or tostring(name)
  return M.cacheDir() .. "/" .. M.thumbName(base, mtime)
end

-- Single-stat freshness check against a known source mtime.
function M.isFresh(thumbPath, srcMtime)
  if type(thumbPath) ~= "string" or thumbPath == "" then
    return false
  end
  local ti = noctalia.fileInfo(thumbPath)
  return ti and ti.size and ti.size > 0 and (ti.mtime or 0) >= (srcMtime or 0)
end

function M.toolAvailable()
  return noctalia.commandExists ~= nil and noctalia.commandExists("vipsthumbnail") == true
end

-- Returns a fresh thumb path, or nil. Fresh = thumb exists, non-empty, and
-- at least as new as the source (covers overwrite-in-place).
function M.freshThumb(srcPath, srcMtime)
  if type(srcPath) ~= "string" or srcPath == "" then
    return nil
  end
  local info = noctalia.fileInfo(srcPath)
  if not info then
    return nil
  end
  local sm = srcMtime or info.mtime or 0
  local tp = M.thumbPath(srcPath, sm)
  if M.isFresh(tp, sm) then
    return tp
  end
  return nil
end

-- Generate thumbs for { { src =, name =, mtime = }, ... } entries that lack a
-- fresh one. One async batch; onDone() runs once at the end (the panel may
-- have closed by then — callers must guard re-render).
function M.backfillAsync(items, onDone)
  local done = function()
    if onDone then
      onDone()
    end
  end
  if not M.toolAvailable() then
    done()
    return
  end
  local jobs = {}
  for _, it in ipairs(items) do
    if type(it.src) == "string" and it.src ~= "" and not M.freshThumb(it.src, it.mtime) then
      table.insert(jobs, it)
    end
  end
  if #jobs == 0 then
    done()
    return
  end
  local dir = M.cacheDir()
  local parts = { "mkdir -p " .. shellQuote(dir) }
  for _, it in ipairs(jobs) do
    local out = dir .. "/" .. M.thumbName(it.name, it.mtime)
    table.insert(
      parts,
      "vipsthumbnail -s "
        .. tostring(THUMB_WIDTH)
        .. " -o "
        .. shellQuote(out)
        .. " "
        .. shellQuote(it.src)
        .. " >/dev/null 2>&1 || true"
    )
  end
  noctalia.runAsync(table.concat(parts, " ; "), function(_)
    done()
  end)
end

return M

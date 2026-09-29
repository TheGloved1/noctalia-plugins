--!nonstrict
-- Screenshot Actions — capture coordinator via Noctalia's built-in screenshot.
--
-- `noctalia msg screenshot-region` is fire-and-forget (returns "ok"
-- immediately), so we snapshot the newest PNG in the screenshot directory,
-- launch the region overlay, then poll for a newer file. Cancel → timeout
-- silently. Requires save_to_file=true in Settings → Screenshot.

local POLL_MS = 500
local TIMEOUT_MS = 120000
local IDLE_MS = 3600000

local capturing = false
local baselineMtime = 0
local baselineName = ""
local elapsedMs = 0
local watchDir = ""

local function resolveScreenshotDir()
  local v = noctalia.getSetting("shell.screenshot.directory")
  if type(v) == "string" and v:match("%S") then
    return noctalia.expandPath(v)
  end
  return noctalia.expandPath("~/Pictures/Screenshots")
end

local function newestPng(dir)
  local entries = noctalia.listDir(dir)
  if type(entries) ~= "table" then
    return nil, 0, ""
  end
  local bestPath = nil
  local bestMtime = 0
  local bestName = ""
  for _, name in ipairs(entries) do
    local ext = name:match("%.([%a%d]+)$")
    if ext and ext:lower() == "png" then
      local path = dir .. "/" .. name
      local info = noctalia.fileInfo(path)
      if info and info.size and info.size > 0 then
        local mtime = info.mtime or 0
        if bestPath == nil or mtime > bestMtime or (mtime == bestMtime and name > bestName) then
          bestPath = path
          bestMtime = mtime
          bestName = name
        end
      end
    end
  end
  return bestPath, bestMtime, bestName
end

function onIpc(ev, _pl)
  if ev ~= "capture" then return end
  if capturing then return end
  if noctalia.getSetting("shell.screenshot.save_to_file") == false then
    noctalia.notifyError("Screenshot", "Enable saving in Settings → Screenshot")
    return
  end
  watchDir = resolveScreenshotDir()
  local _, mtime, name = newestPng(watchDir)
  baselineMtime = mtime or 0
  baselineName = name or ""
  elapsedMs = 0
  capturing = true
  noctalia.setUpdateInterval(POLL_MS)
  local ok = noctalia.runAsync("noctalia msg screenshot-region", function(r)
    if not r then return end
    local out = ((r.stdout or "") .. (r.stderr or "")):lower()
    if out:match("error") then
      capturing = false
      noctalia.setUpdateInterval(IDLE_MS)
      noctalia.notifyError("Screenshot", "capture failed")
    end
  end)
  if not ok then
    capturing = false
    noctalia.setUpdateInterval(IDLE_MS)
    noctalia.notifyError("Screenshot", "launch failed")
  end
end

function update()
  if not capturing then return end
  elapsedMs += POLL_MS
  local path, mtime, name = newestPng(watchDir)
  if path and (mtime > baselineMtime or name ~= baselineName) then
    capturing = false
    noctalia.setUpdateInterval(IDLE_MS)
    noctalia.state.set("lastCapture", path)
    noctalia.togglePanel("gloves/screenshot-actions:actions")
  elseif elapsedMs >= TIMEOUT_MS then
    capturing = false
    noctalia.setUpdateInterval(IDLE_MS)
  end
end

function onExit(_signal)
  capturing = false
end
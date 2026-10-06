--!nonstrict
-- Screenshot Actions — capture coordinator via Noctalia's built-in screenshot.
--
-- Two delivery paths:
-- 1. Pipe notify (recommended): Settings → Screenshot → Run Command with the
--    command from the README fires `... all captured "$NOCTALIA_SCREENSHOT_PATH"`
--    per capture. Event-driven, so ESC-cancel sends nothing and the next press
--    always works. Requires save_to_file=true so the path exists.
-- 2. Directory poll fallback: `capture` snapshots the newest PNG, launches the
--    region overlay, then polls for a newer file. `screenshot-region` is
--    fire-and-forget, so a second `capture` press resets the watch and
--    relaunches the overlay instead of being ignored.

local POLL_MS = 500
local TIMEOUT_MS = 60000
local IDLE_MS = 3600000

local thumbs = require("./lib/thumbs.luau")

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

-- True when the shell's Run Command points back at our `captured` event.
local function isPipeNotifyConfigured()
  if noctalia.getSetting("shell.screenshot.pipe_to_command") ~= true then
    return false
  end
  local cmd = noctalia.getSetting("shell.screenshot.pipe_command")
  return type(cmd) == "string"
    and cmd:find("screenshot%-actions", 1) ~= nil
    and cmd:find("captured", 1, true) ~= nil
end

local function deliverCapture(path, name, mtime, source)
  capturing = false
  noctalia.setUpdateInterval(IDLE_MS)
  noctalia.log("screenshot-actions: captured via " .. source .. ": " .. path)
  -- Thumb now so history/actions panels never decode the full PNG.
  thumbs.backfillAsync({ { src = path, name = name, mtime = mtime } }, nil)
  noctalia.state.set("lastCapture", path)
  noctalia.togglePanel("gloves/screenshot-actions:actions")
end

function onIpc(ev, pl)
  if ev == "status" then
    noctalia.notify(
      "Screenshot service",
      (capturing and "capturing (" .. tostring(elapsedMs) .. "ms in " .. watchDir .. ")"
        or "idle (dir " .. resolveScreenshotDir() .. ")")
        .. (isPipeNotifyConfigured() and " [pipe notify on]" or " [poll fallback]")
    )
    return
  end
  if ev == "captured" then
    -- Fired by the shell's Run Command: anything after the event is the path.
    local path = tostring(pl or ""):match("^%s*(.-)%s*$")
    local q = path:sub(1, 1)
    if (q == "'" or q == '"') and path:sub(-1) == q and #path >= 2 then
      path = path:sub(2, -2)
    end
    if path == "" then
      noctalia.log("screenshot-actions: captured event with empty path")
      return
    end
    local info = noctalia.fileInfo(path)
    if not info or not info.size or info.size == 0 then
      noctalia.log("screenshot-actions: captured path missing/empty: " .. path)
      return
    end
    deliverCapture(path, path:match("([^/]+)$") or path, info.mtime or 0, "pipe")
    return
  end
  if ev ~= "capture" then return end
  if noctalia.getSetting("shell.screenshot.save_to_file") == false then
    noctalia.notifyError("Screenshot", "Enable saving in Settings → Screenshot")
    return
  end
  local restarted = capturing
  watchDir = resolveScreenshotDir()
  local _, mtime, name = newestPng(watchDir)
  baselineMtime = mtime or 0
  baselineName = name or ""
  elapsedMs = 0
  capturing = true
  noctalia.setUpdateInterval(POLL_MS)
  noctalia.log("screenshot-actions: launching region capture"
    .. (restarted and " (restarted watch)" or "")
    .. (isPipeNotifyConfigured() and "" or " [no pipe notify; poll fallback]")
    .. ", watching " .. watchDir)
  local ok = noctalia.runAsync("noctalia msg screenshot-region", function(r)
    if not r then return end
    local out = ((r.stdout or "") .. (r.stderr or "")):lower()
    noctalia.log("screenshot-actions: region launcher exited: " .. out:sub(1, 120))
    if out:match("already active") then
      -- Overlay still open from the previous press; keep watching it.
      noctalia.log("screenshot-actions: overlay already active, keeping watch")
      return
    end
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
    deliverCapture(path, name, mtime, "poll")
  elseif elapsedMs >= TIMEOUT_MS then
    capturing = false
    noctalia.setUpdateInterval(IDLE_MS)
    noctalia.log("screenshot-actions: capture timed out after " .. tostring(TIMEOUT_MS) .. "ms")
  end
end

function onExit(_signal)
  capturing = false
end
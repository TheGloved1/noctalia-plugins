--!nonstrict
-- PokeDash — overview-only panel (Top layer in niri, above overview grids).
--
-- Opens via noctalia.togglePanel() from the overview service when the
-- overview opens; closes automatically when the overview closes or when
-- the close button is clicked.

local rosterMod = nil
do
	local ok, mod = pcall(function() return require("./roster.luau") end)
	if ok and type(mod) == "table" then rosterMod = mod end
end

local roster = rosterMod and rosterMod.defaultRoster or {
	{ name = "Pikachu", dexId = 25, frameW = 32, frameH = 32, animated = true },
}

local function getByName(name)
	if rosterMod then return rosterMod.getByName(name, roster) end
	for _, e in ipairs(roster) do if e.name == name then return e end end
	return roster[1]
end

local function getConfig(key, fallback)
	local v = noctalia.getConfig(key)
	if v == nil then return fallback end
	return v
end

local function cachePaths(dexId, style)
	local base = noctalia.pluginDataDir()
	if base == nil or base == "" then return nil, nil end
	noctalia.mkdirAll(base .. "/sprites")
	local gif = base .. "/sprites/" .. tostring(dexId) .. "-" .. style .. ".gif"
	local dir = base .. "/sprites/" .. tostring(dexId) .. "-" .. style .. "_frames"
	return gif, dir
end

local function loadFrameList(dir)
	if dir == nil or dir == "" then return {} end
	local frames = {}
	for f in io.popen("ls " .. dir .. "/frame_*.png 2>/dev/null"):lines() do
		table.insert(frames, f)
	end
	table.sort(frames)
	return frames
end

local function shellQuote(s)
	return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function triggerExtraction(gif, dir)
	if dir == nil or dir == "" then return end
	noctalia.mkdirAll(dir)
	noctalia.log("PokeDash: extracting frames " .. gif .. " -> " .. dir)
	local ok, py = pcall(function()
		return ([[
import sys
from PIL import Image
im = Image.open(%s)
n = 0
out = %s
import os; os.makedirs(out, exist_ok=True)
try:
	while True:
		im.seek(im.tell() + 1)
		n += 1
except EOFError:
	pass
for i in range(n):
	im.seek(i)
	im.save(os.path.join(out, "frame_%03d.png" %% i))
print(n)
]]):format(shellQuote(gif), shellQuote(dir))
	end)
	if not ok then
		noctalia.log("PokeDash: PIL failed, will try ffmpeg fallback")
		extracting = false
		render()
		return
	end
	local pyCmd = "python3 -c " .. py
	noctalia.runAsync(pyCmd, function(res)
		extracting = false
		if res and res.exitCode == 0 then
			noctalia.log("PokeDash: extraction done for " .. gif)
			framePaths = loadFrameList(dir)
			if #framePaths > 0 then
				frameDurationMs = 80
				startAnimation()
			end
		else
			noctalia.log("PokeDash: PIL extraction failed, trying ffmpeg for " .. gif)
			local ffCmd = "ffmpeg -y -i " .. shellQuote(gif) .. " -vsync 0 " .. shellQuote(dir .. "/frame_%03d.png") .. " >/dev/null 2>&1"
			noctalia.runAsync(ffCmd, function(res2)
				if res2 and res2.exitCode == 0 then
					framePaths = loadFrameList(dir)
					if #framePaths > 0 then
						frameDurationMs = 80
						startAnimation()
					end
				else
					noctalia.log("PokeDash: ffmpeg fallback also failed")
				end
				render()
			end)
		end
		render()
	end)
end

local function ensureSprite(dexId, style)
	local gif, dir = cachePaths(dexId, style)
	if gif == nil then return nil end
	if not noctalia.fileExists(gif) then
		if downloading == gif then return currentGif end
		downloading = gif
		local url = spriteUrl(dexId, style)
		noctalia.log("PokeDash: downloading " .. url .. " -> " .. gif)
		local ok = noctalia.download(url, gif, function(success)
			downloading = nil
			if success then
				currentGif = gif
				framePaths = {}
				frameIndex = 1
				stopAnimation()
				triggerExtraction(gif, dir)
			else
				noctalia.log("PokeDash: download failed " .. url)
			end
			render()
		end)
		if not ok then
			noctalia.log("PokeDash: download not accepted " .. url)
			downloading = nil
		end
		return currentGif
	end
	currentGif = gif
	local frames = loadFrameList(dir)
	if #frames > 0 then
		framePaths = frames
		startAnimation()
	else
		framePaths = {}
		stopAnimation()
		triggerExtraction(gif, dir)
	end
	return gif
end

-- State (same as desktop.luau)
local currentGif = nil
local downloading = nil
local frameDir = nil
local framePaths = {}
local frameIndex = 1
local accumMs = 0
local frameDurationMs = 80
local extracting = false
local animating = false

local function startAnimation()
	animating = true
	desktopWidget.setNeedsFrameTick(true)
end

local function stopAnimation()
	animating = false
	desktopWidget.setNeedsFrameTick(false)
end

function onFrameTick(deltaMs)
	if #framePaths <= 1 then
		stopAnimation()
		return
	end
	if cachedOverviewOpen ~= true then
		return
	end
	accumMs = accumMs + deltaMs
	while accumMs >= frameDurationMs do
		accumMs = accumMs - frameDurationMs
		frameIndex = frameIndex + 1
		if frameIndex > #framePaths then frameIndex = 1 end
	end
	render()
end

local cachedOverviewOpen = nil
local render

local function setOverviewState(isOpen)
	if cachedOverviewOpen == isOpen then return end
	cachedOverviewOpen = isOpen
	render()
end

local function queryOverviewState()
	noctalia.runAsync("niri msg -j overview-state 2>/dev/null", function(res)
		if res and res.exitCode == 0 and res.stdout then
			local isOpen = res.stdout:find('"is_open"%s*:%s*true') ~= nil
			setOverviewState(isOpen)
		end
	end)
end

local streamOk = noctalia.runStream("niri msg -j event-stream 2>/dev/null", function(line)
	if line:find("OverviewOpenedOrClosed") then
		local isOpen = line:find('"is_open"%s*:%s*true') ~= nil
		setOverviewState(isOpen)
	end
end)

if not streamOk then
	noctalia.setUpdateInterval(500)
	function update()
		queryOverviewState()
	end
end

queryOverviewState()

render = function()
	local selected = getConfig("selected_critter", "Pikachu")
	if type(selected) ~= "string" or selected == "" then selected = "Pikachu" end
	local style = getConfig("sprite_style", "normal")
	if type(style) ~= "string" then style = "normal" end
	local bg = getConfig("background_style", "transparent")
	if type(bg) ~= "string" then bg = "transparent" end
	local scale = getConfig("sprite_scale", 100)
	if type(scale) ~= "number" then scale = 100 end
	scale = math.clamp(scale, 50, 250) / 100

	if cachedOverviewOpen ~= true then
		stopAnimation()
		panel.render(ui.box({ visible = false, width = 1, height = 1 }))
		return
	end

	local critter = getByName(selected)
	ensureSprite(critter.dexId, style)

	local bgFill = nil
	local border = nil
	local borderWidth = 0
	if bg == "dms" then bgFill = "surface_container"
	elseif bg == "glass" then
		bgFill = "#00000026"
		border = "#FFFFFF1A"
		borderWidth = 1
	end

	local w = math.floor(critter.frameW * 2 * scale)
	local h = math.floor(critter.frameH * 2 * scale)
	w = math.max(w, 32)
	h = math.max(h, 32)

	local imagePath = nil
	if #framePaths > 0 then
		imagePath = framePaths[frameIndex]
	elseif currentGif and noctalia.fileExists(currentGif) then
		imagePath = currentGif
	end

	local content = {}
	if imagePath and noctalia.fileExists(imagePath) then
		table.insert(content, ui.image({ path = imagePath, width = w, height = h, fit = "contain" }))
	else
		table.insert(content, ui.column({ gap = 6, align = "center" }, {
			ui.glyph({ name = "egg", size = math.floor(24 * scale), color = "primary" }),
			ui.label({ text = critter.name, fontSize = 12, color = "on_surface_variant" }),
			(downloading or extracting) and ui.label({ text = extracting and "Extracting…" or "Downloading…", fontSize = 10, color = "on_surface_variant" }) or nil,
		}))
	end

	local inner = ui.column({ gap = 0, align = "center", justify = "center" }, content)
	local wrapped
	if bgFill then
		wrapped = ui.column({ align = "center", justify = "center", padding = 10, fill = bgFill, radius = 12, border = border, borderWidth = borderWidth }, { inner })
	else wrapped = inner end
	panel.render(wrapped)
end

function onConfigChanged()
	framePaths = {}
	frameIndex = 1
	accumMs = 0
	stopAnimation()
	render()
end

local isOverview = noctalia.state.get("overview.is_open")
if isOverview ~= true then
	panel.close()
	return
end
render()

noctalia.state.watch("overview.is_open", function(value)
	if value ~= true then
		panel.close()
		return
	end
	render()
end)

function onIpc(event, _payload)
	if event == "close" then
		panel.close()
	end
end
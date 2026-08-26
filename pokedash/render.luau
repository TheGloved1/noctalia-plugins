--!nonstrict
-- Shared rendering helpers for PokeDash (desktop widget + overview panel).
--
-- Sprite download, extraction and animation state live here so that
-- desktop.luau and panel.luau share one module instance.
--
-- NOTE: needsFrameTick is a widget-context API only. This module does NOT
-- call it. The desktop widget calls setNeedsFrameTick itself; the panel
-- drives its own render loop via onFrameTick registered there.

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

local function spriteUrl(dexId, style)
	if rosterMod then return rosterMod.spriteUrl(dexId, style) end
	if style == "showdown" then
		return "https://raw.githubusercontent.com/PokeAPI/sprites/refs/heads/master/sprites/pokemon/other/showdown/" .. tostring(dexId) .. ".gif"
	end
	return "https://raw.githubusercontent.com/PokeAPI/sprites/refs/heads/master/sprites/pokemon/versions/generation-v/black-white/animated/" .. tostring(dexId) .. ".gif"
end

local function getConfig(key, fallback)
	local v = noctalia.getConfig(key)
	if v == nil then return fallback end
	return v
end

local function shellQuote(s)
	return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
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
	for i = 0, 99 do
		local path = dir .. "/frame_" .. string.format("%03d", i) .. ".png"
		if noctalia.fileExists(path) then
			table.insert(frames, path)
		elseif i > 0 then
			break
		end
	end
	return frames
end

local function triggerExtraction(gif, dir, onDone)
	if dir == nil or dir == "" then
		if onDone then onDone() end
		return
	end
	noctalia.mkdirAll(dir)
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
	im.save(os.path.join(out, "frame_%%03d.png" %% i))
print(n)
]]):format(shellQuote(gif), shellQuote(dir))
	end)
	if not ok then
		extracting = false
		if onDone then onDone() end
		return
	end
	local pyCmd = "python3 -c " .. py
	noctalia.runAsync(pyCmd, function(res)
		extracting = false
		if res and res.exitCode == 0 then
			framePaths = loadFrameList(dir)
			if #framePaths > 0 then
				frameDurationMs = 80
			end
		else
			local ffCmd = "ffmpeg -y -i " .. shellQuote(gif) .. " -vsync 0 " .. shellQuote(dir .. "/frame_%03d.png") .. " >/dev/null 2>&1"
			noctalia.runAsync(ffCmd, function(res2)
				if res2 and res2.exitCode == 0 then
					framePaths = loadFrameList(dir)
					if #framePaths > 0 then
						frameDurationMs = 80
					end
				end
				if onDone then onDone() end
			end)
			return
		end
		if onDone then onDone() end
	end)
end

local function ensureSprite(dexId, style, onDone)
	local gif, dir = cachePaths(dexId, style)
	if gif == nil then
		if onDone then onDone() end
		return nil
	end
	if not noctalia.fileExists(gif) then
		if downloading == gif then
			if onDone then onDone() end
			return currentGif
		end
		downloading = gif
		local url = spriteUrl(dexId, style)
		noctalia.log("PokeDash: downloading " .. url .. " -> " .. gif)
		local ok = noctalia.download(url, gif, function(success)
			downloading = nil
			if success then
				currentGif = gif
				framePaths = {}
				frameIndex = 1
				triggerExtraction(gif, dir, onDone)
			else
				noctalia.log("PokeDash: download failed " .. url)
				if onDone then onDone() end
			end
		end)
		if not ok then
			noctalia.log("PokeDash: download not accepted " .. url)
			downloading = nil
			if onDone then onDone() end
		end
		return currentGif
	end
	currentGif = gif
	local frames = loadFrameList(dir)
	if #frames > 0 then
		framePaths = frames
	else
		framePaths = {}
	end
	return gif
end

-- Shared state
local currentGif = nil
local downloading = nil
local frameDir = nil
local framePaths = {}
local frameIndex = 1
local accumMs = 0
local frameDurationMs = 80
local extracting = false

function onFrameTick(deltaMs)
	if #framePaths <= 1 then return end
	accumMs = accumMs + deltaMs
	while accumMs >= frameDurationMs do
		accumMs = accumMs - frameDurationMs
		frameIndex = frameIndex + 1
		if frameIndex > #framePaths then frameIndex = 1 end
	end
end

local function computeConfig()
	local selected = getConfig("selected_critter", "Pikachu")
	if type(selected) ~= "string" or selected == "" then selected = "Pikachu" end
	local style = getConfig("sprite_style", "normal")
	if type(style) ~= "string" then style = "normal" end
	local bg = getConfig("background_style", "transparent")
	if type(bg) ~= "string" then bg = "transparent" end
	local scale = getConfig("sprite_scale", 100)
	if type(scale) ~= "number" then scale = 100 end
	scale = math.clamp(scale, 50, 250) / 100

	local critter = getByName(selected)

	local bgFill = nil
	local border = nil
	local borderWidth = 0
	if bg == "dms" then bgFill = "surface_container"
	elseif bg == "glass" then
		bgFill = "#00000026"
		border = "#FFFFFF1A"
		borderWidth = 1
	end

	local w = math.max(32, math.floor(critter.frameW * 2 * scale))
	local h = math.max(32, math.floor(critter.frameH * 2 * scale))

	return {
		critter = critter,
		style = style,
		scale = scale,
		bgFill = bgFill,
		border = border,
		borderWidth = borderWidth,
		w = w,
		h = h,
	}
end

local function buildContent(cfg)
	local imagePath = nil
	if #framePaths > 0 then
		imagePath = framePaths[frameIndex]
	elseif currentGif and noctalia.fileExists(currentGif) then
		imagePath = currentGif
	end

	if imagePath and noctalia.fileExists(imagePath) then
		return ui.image({ path = imagePath, width = cfg.w, height = cfg.h, fit = "contain" })
	end

	return ui.column({ gap = 6, align = "center" }, {
		ui.glyph({ name = "egg", size = math.floor(24 * cfg.scale), color = "primary" }),
		ui.label({ text = cfg.critter.name, fontSize = 12, color = "on_surface_variant" }),
		(downloading or extracting) and ui.label({ text = extracting and "Extracting…" or "Downloading…", fontSize = 10, color = "on_surface_variant" }) or nil,
	})
end

local function renderTree(cfg)
	local content = { buildContent(cfg) }
	local inner = ui.column({ gap = 0, align = "center", justify = "center" }, content)
	if cfg.bgFill then
		return ui.column({ align = "center", justify = "center", padding = 10, fill = cfg.bgFill, radius = 12, border = cfg.border, borderWidth = cfg.borderWidth }, { inner })
	end
	return inner
end

local function stopAnimation()
	animating = false
end

local function hasAnimatedFrames()
	return #framePaths > 1
end

return {
	getConfig = getConfig,
	ensureSprite = ensureSprite,
	computeConfig = computeConfig,
	renderTree = renderTree,
	onFrameTick = onFrameTick,
	stopAnimation = stopAnimation,
	hasAnimatedFrames = hasAnimatedFrames,
}
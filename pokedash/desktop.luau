--!nonstrict
-- PokeDash — desktop widget port of samgrande/PokeDash (DMS)
-- Downloads PokeAPI GIFs, extracts frames via PIL, then animates via
-- desktopWidget.setNeedsFrameTick / onFrameTick. Falls back to static image
-- if extraction fails. Plugin API 22 required for require().

local rosterMod = nil
do
	local ok, mod = pcall(function() return require("./roster.luau") end)
	if ok and type(mod) == "table" then rosterMod = mod end
end

local roster = rosterMod and rosterMod.defaultRoster or {
	{ name = "Pikachu", dexId = 25, frameW = 32, frameH = 32, animated = true },
	{ name = "Ditto", dexId = 132, frameW = 32, frameH = 32, animated = true },
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

-- State
local currentGif = nil
local downloading = nil
local frameDir = nil
local framePaths = {}
local frameIndex = 1
local accumMs = 0
local frameDurationMs = 80
local extracting = false
local animating = false

local function cachePaths(dexId, style)
	local base = noctalia.pluginDataDir()
	if base == nil or base == "" then return nil, nil end
	noctalia.mkdirAll(base .. "/sprites")
	local gif = base .. "/sprites/" .. tostring(dexId) .. "-" .. style .. ".gif"
	local dir = base .. "/sprites/" .. tostring(dexId) .. "-" .. style .. "_frames"
	return gif, dir
end

local function loadFrameList(dir)
	if dir == nil then return {} end
	local entries = noctalia.listDir(dir)
	if type(entries) ~= "table" then return {} end
	local out = {}
	for _, name in ipairs(entries) do
		if name:match("^frame_%d+%.png$") then table.insert(out, dir .. "/" .. name) end
	end
	table.sort(out)
	return out
end

local function startAnimation()
	if #framePaths <= 1 then
		if animating then
			desktopWidget.setNeedsFrameTick(false)
			animating = false
		end
		return
	end
	if not animating then
		accumMs = 0
		frameIndex = 1
		desktopWidget.setNeedsFrameTick(true)
		animating = true
	end
end

local function stopAnimation()
	if animating then
		desktopWidget.setNeedsFrameTick(false)
		animating = false
	end
end

local function triggerExtraction(gifPath, dir)
	if extracting then return end
	if noctalia.fileExists(dir) and #loadFrameList(dir) > 0 then return end
	extracting = true
	noctalia.mkdirAll(dir)
	-- Prefer Python PIL, fallback to ffmpeg
	local pyCode = [[
import sys, os
gif_path=sys.argv[1]
outdir=sys.argv[2]
try:
    from PIL import Image
    im=Image.open(gif_path)
    n=getattr(im, 'n_frames', 1)
    for i in range(n):
        try:
            im.seek(i)
        except EOFError:
            break
        frame=im.convert('RGBA')
        frame.save(os.path.join(outdir, f'frame_{i:03d}.png'), 'PNG')
    print(f"extracted {n}")
except Exception as e:
    print(f"PIL failed {e}", file=sys.stderr)
    sys.exit(2)
]]
	-- Write temp script to avoid quoting issues
	local base = noctalia.pluginDataDir()
	local scriptPath = base .. "/sprites/_extract.py"
	noctalia.writeFile(scriptPath, pyCode)
	local cmd = "python3 " .. shellQuote(scriptPath) .. " " .. shellQuote(gifPath) .. " " .. shellQuote(dir)
	noctalia.log("PokeDash: extracting frames " .. gifPath .. " -> " .. dir)
	noctalia.runAsync(cmd, function(res)
		extracting = false
		if res and res.exitCode == 0 then
			noctalia.log("PokeDash: extraction done for " .. gifPath)
			framePaths = loadFrameList(dir)
			if #framePaths > 0 then
				-- Try to read durations: use PIL again to estimate average delay
				-- For now use 80ms default; GIFs from PokeAPI report 50-100ms
				frameDurationMs = 80
				startAnimation()
				render()
				return
			end
		end
		noctalia.log("PokeDash: PIL extraction failed, trying ffmpeg for " .. gifPath)
		local ffCmd = "ffmpeg -y -i " .. shellQuote(gifPath) .. " -vsync 0 " .. shellQuote(dir .. "/frame_%03d.png") .. " >/dev/null 2>&1"
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
		render()
	end)
end

local function ensureSprite(dexId, style)
	local gif, dir = cachePaths(dexId, style)
	if gif == nil then return nil end
	frameDir = dir
	-- If GIF missing, download it
	if not noctalia.fileExists(gif) then
		if downloading == gif then return currentGif end
		downloading = gif
		local url = spriteUrl(dexId, style)
		noctalia.log("PokeDash: downloading " .. url .. " -> " .. gif)
		local ok = noctalia.download(url, gif, function(success)
			downloading = nil
			if success then
				currentGif = gif
				-- Reset frames for new sprite
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
	-- GIF exists
	currentGif = gif
	-- Load frames if already extracted
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

-- Direct Niri overview state tracking (mirrors DMS NiriService.inOverview)
local cachedOverviewOpen = nil

-- Forward-declare render so setOverviewState can call it unconditionally.
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

	local overviewMode = getConfig("overview_mode", "always")
	if type(overviewMode) ~= "string" then overviewMode = "always" end
	local isOverview = cachedOverviewOpen

	-- overview_only: visible only in Niri overview.
	-- Nil/unknown state: hide until we can confirm overview is open.
	if overviewMode == "overview_only" and isOverview ~= true then
		stopAnimation()
		desktopWidget.render(ui.box({ visible = false, width = 1, height = 1 }))
		return
	end
	if overviewMode == "hidden_in_overview" and isOverview == true then
		stopAnimation()
		desktopWidget.render(ui.box({ visible = false, width = 1, height = 1 }))
		return
	end
	-- nil -> fallback to always

	local critter = getByName(selected)
	-- Ensure gif/frames are being prepared (async, may re-render)
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

	local content = {}

	local imagePath = nil
	if #framePaths > 0 then
		imagePath = framePaths[frameIndex]
	elseif currentGif and noctalia.fileExists(currentGif) then
		-- Show static first frame while frames extract, or if single-frame GIF
		imagePath = currentGif
	end

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
	desktopWidget.render(wrapped)
end

function onConfigChanged()
	-- Reset animation state for new critter/style
	framePaths = {}
	frameIndex = 1
	accumMs = 0
	stopAnimation()
	render()
end

function onFrameTick(deltaMs)
	if #framePaths <= 1 then
		stopAnimation()
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

render()

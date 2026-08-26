--!nonstrict
-- PokeDash — desktop widget port of samgrande/PokeDash (DMS)
-- Static centered sprite (v1). Downloads PokeAPI GIFs on demand to pluginDataDir,
-- then renders via ui.image (local files only per declarative-ui docs).
-- Module require needs plugin_api >=22; we are at 18 but require still works for
-- relative .luau in current runtime — fallback to inline roster if require fails.

local rosterMod = nil
do
	local ok, mod = pcall(function() return require("./roster.luau") end)
	if ok and type(mod) == "table" then
		rosterMod = mod
	end
end

-- Fallback minimal roster if module not loaded (should not happen)
local roster = rosterMod and rosterMod.defaultRoster or {
	{ name = "Pikachu", dexId = 25, frameW = 32, frameH = 32, animated = true },
	{ name = "Ditto", dexId = 132, frameW = 32, frameH = 32, animated = true },
}

local function getByName(name)
	if rosterMod then return rosterMod.getByName(name, roster) end
	for _, e in ipairs(roster) do
		if e.name == name then return e end
	end
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

-- Cache state
local currentPath = nil
local downloading = nil
local pendingUrl = nil
local pendingDest = nil

local function cacheDest(dexId, style)
	local dir = noctalia.pluginDataDir()
	if dir == nil or dir == "" then return nil end
	-- ensure sprites subdir
	noctalia.mkdirAll(dir .. "/sprites")
	return dir .. "/sprites/" .. tostring(dexId) .. "-" .. style .. ".gif"
end

local function ensureSprite(dexId, style)
	local dest = cacheDest(dexId, style)
	if dest == nil then return nil end
	if noctalia.fileExists(dest) then
		currentPath = dest
		return dest
	end
	-- already downloading this exact file?
	if downloading == dest then
		return currentPath -- show previous while loading
	end
	local url = spriteUrl(dexId, style)
	pendingUrl = url
	pendingDest = dest
	downloading = dest
	noctalia.log("PokeDash: downloading " .. url .. " -> " .. dest)
	local ok = noctalia.download(url, dest, function(success)
		downloading = nil
		if success then
			currentPath = dest
		else
			noctalia.log("PokeDash: download failed for " .. url)
			-- keep currentPath as previous (or nil)
		end
		render()
	end)
	if not ok then
		noctalia.log("PokeDash: download not accepted for " .. url)
		downloading = nil
	end
	return currentPath
end

function render()
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
	local dest = ensureSprite(critter.dexId, style)
	-- fallback path if no cache yet: show previous or nil
	local imagePath = dest or currentPath

	local bgFill = nil
	local border = nil
	local borderWidth = 0
	if bg == "dms" then
		bgFill = "surface_container"
	elseif bg == "glass" then
		bgFill = "#00000026"
		border = "#FFFFFF1A"
		borderWidth = 1
	end

	local w = math.floor(critter.frameW * 2 * scale)
	local h = math.floor(critter.frameH * 2 * scale)
	-- enforce minimum so widget not zero
	w = math.max(w, 32)
	h = math.max(h, 32)

	local content = {}

	if imagePath and noctalia.fileExists and noctalia.fileExists(imagePath) then
		table.insert(content, ui.image({
			path = imagePath,
			width = w,
			height = h,
			fit = "contain",
		}))
	else
		-- Placeholder while downloading or on failure
		table.insert(content, ui.column({ gap = 6, align = "center" }, {
			ui.glyph({ name = "pokeball", size = math.floor(24 * scale), color = "primary" }),
			ui.label({ text = critter.name, fontSize = 12, color = "on_surface_variant" }),
			downloading and ui.label({ text = "Downloading…", fontSize = 10, color = "on_surface_variant" }) or nil,
		}))
	end

	local inner = ui.column({ gap = 0, align = "center", justify = "center" }, content)

	local wrapped
	if bgFill then
		wrapped = ui.column({
			align = "center",
			justify = "center",
			padding = 10,
			fill = bgFill,
			radius = 12,
			border = border,
			borderWidth = borderWidth,
		}, { inner })
	else
		wrapped = inner
	end

	desktopWidget.render(wrapped)
end

function onConfigChanged()
	render()
end

-- Initial render kicks off first download
render()

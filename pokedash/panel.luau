--!nonstrict
-- PokeDash — overview-only panel (Top layer in niri, above grids).
--
-- Uses plugin-local state key (pokedash.overview.is_open) so it
-- doesn't interfere with other plugins' panels. Transparent background
-- so only the sprite is visible over the overview.

local PokeDash = require("./render.luau")

local cachedOverviewOpen = nil

local function render()
	if cachedOverviewOpen ~= true then return end
	local cfg = PokeDash.computeConfig()
	PokeDash.ensureSprite(cfg.critter.dexId, cfg.style)
	panel.render(PokeDash.renderTree(cfg))
end

noctalia.state.watch("pokedash.overview.is_open", function(value)
	cachedOverviewOpen = value == true
	render()
end)

function onFrameTick(deltaMs)
	PokeDash.onFrameTick(deltaMs)
	render()
end

function onConfigChanged()
	render()
end

function onIpc(event, _payload)
	if event == "close" then
		cachedOverviewOpen = false
	end
end
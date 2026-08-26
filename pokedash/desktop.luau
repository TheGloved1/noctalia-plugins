--!nonstrict
-- PokeDash — desktop widget (Bottom layer on normal desktop).
--
-- overview_only / hidden_in_overview gating is handled here using state
-- set by the overview service. The floating panel (panel.luau, Top layer)
-- is shown by the service whenever the overview opens.

local PokeDash = require("./render.luau")

local function doRender()
	local overviewMode = PokeDash.getConfig("overview_mode", "always")
	if type(overviewMode) ~= "string" then overviewMode = "always" end
	local isOverview = noctalia.state.get("overview.is_open")

	if overviewMode == "overview_only" and isOverview ~= true then
		PokeDash.stopAnimation()
		desktopWidget.render(ui.box({ visible = false, width = 1, height = 1 }))
		return
	end
	if overviewMode == "hidden_in_overview" and isOverview == true then
		PokeDash.stopAnimation()
		desktopWidget.render(ui.box({ visible = false, width = 1, height = 1 }))
		return
	end

	local cfg = PokeDash.computeConfig()
	PokeDash.ensureSprite(cfg.critter.dexId, cfg.style, doRender)
	desktopWidget.render(PokeDash.renderTree(cfg))
end

local render = doRender

function onFrameTick(deltaMs)
	PokeDash.onFrameTick(deltaMs)
	render()
end

function onConfigChanged()
	PokeDash.stopAnimation()
	render()
end

noctalia.state.watch("overview.is_open", function() render() end)

render()
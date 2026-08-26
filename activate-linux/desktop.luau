--!nonstrict
-- Activate Linux — desktop watermark (Bottom layer on normal desktop).
--
-- When overview_mode = "overview_only" or "hidden_in_overview", gates
-- visibility using the overview state tracked by the overview service.
-- The floating panel (panel.luau, Top layer) is shown by the service
-- whenever the overview opens and is the user-visible surface in overview.

local ActivateLinuxRender = require("./render.luau")
local getConfig = ActivateLinuxRender.getConfig

local function render()
	local overviewMode = getConfig("overview_mode", "always")
	if type(overviewMode) ~= "string" then overviewMode = "always" end
	local isOverview = noctalia.state.get("overview.is_open")
	if overviewMode == "overview_only" and isOverview ~= true then
		desktopWidget.render(ui.box({ visible = false, width = 1, height = 1 }))
		return
	end
	if overviewMode == "hidden_in_overview" and isOverview == true then
		desktopWidget.render(ui.box({ visible = false, width = 1, height = 1 }))
		return
	end
	desktopWidget.render(ActivateLinuxRender.buildTree(ActivateLinuxRender.computeLayout()))
end

function onConfigChanged()
	render()
end

noctalia.state.watch("overview.is_open", function() render() end)

render()
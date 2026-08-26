--!nonstrict
-- Activate Linux — overview-only panel (Top layer in niri, above grids).
--
-- Opens via noctalia.togglePanel() from the overview service when the
-- overview opens; closes automatically when the overview closes.

local ActivateLinuxRender = require("./render.luau")

local closing = false
local cachedOverviewOpen = nil

local function render()
	if cachedOverviewOpen ~= true then return end
	local layout = ActivateLinuxRender.computeLayout()
	local col = ui.column({ gap = 4, padding = 20, align = layout.columnAlign }, {
		ui.label({
			text = layout.firstLine,
			fontSize = layout.firstSize,
			fontWeight = "light",
			color = "on_surface_variant",
			opacity = layout.opacity,
			textAlign = layout.textAlign,
		}),
		ui.label({
			text = layout.secondLine,
			fontSize = layout.secondSize,
			color = "on_surface_variant",
			opacity = layout.opacity,
			textAlign = layout.textAlign,
		}),
	})
	panel.render(col)
end

local function setOverviewState(isOpen)
	if cachedOverviewOpen == isOpen then return end
	cachedOverviewOpen = isOpen
	if isOpen then
		render()
	else
		closing = true
		panel.close()
	end
end

noctalia.state.watch("overview.is_open", function(value)
	if closing then
		closing = false
		return
	end
	setOverviewState(value == true)
end)

function onConfigChanged()
	if cachedOverviewOpen == true then
		render()
	end
end

function onIpc(event, _payload)
	if event == "close" then
		closing = true
		panel.close()
	end
end
--!nonstrict
-- Activate Linux — overview-only panel (Top layer in niri, above grids).
--
-- Uses plugin-local state key (activate-linux.overview.is_open) so it
-- doesn't interfere with other plugins' panels. Transparent background
-- so only the watermark text is visible over the overview.

local ActivateLinuxRender = require("./render.luau")

local cachedOverviewOpen = nil

local function render()
	if cachedOverviewOpen ~= true then return end
	local layout = ActivateLinuxRender.computeLayout()
	local col = ui.column({ gap = 4, padding = 20, fill = "transparent", align = layout.columnAlign }, {
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

noctalia.state.watch("activate-linux.overview.is_open", function(value)
	cachedOverviewOpen = value == true
	render()
end)

function onConfigChanged()
	render()
end

function onIpc(event, _payload)
	if event == "close" then
		cachedOverviewOpen = false
	end
end
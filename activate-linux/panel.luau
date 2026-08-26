--!nonstrict
-- Activate Linux — overview-only panel (Top layer in niri, above overview grids).
--
-- Opens via noctalia.togglePanel() from the overview service when the
-- overview opens; closes automatically when the overview closes or when
-- the close button is clicked.

local function getConfig(key, fallback)
	local v = noctalia.getConfig(key)
	if v == nil then return fallback end
	return v
end

local function render()
	local customize = getConfig("customize_text", false) == true

	local firstLine = customize and getConfig("first_line", "Activate Linux") or "Activate Linux"
	local secondLine = customize and getConfig("second_line", "Go to Settings to activate Linux.") or "Go to Settings to activate Linux."

	if firstLine == nil or firstLine == "" then firstLine = "Activate Linux" end
	if secondLine == nil or secondLine == "" then secondLine = "Go to Settings to activate Linux." end

	local opacity = getConfig("watermark_opacity", 40)
	if type(opacity) ~= "number" then opacity = 40 end
	opacity = math.clamp(opacity / 100, 0, 1)

	local firstSize = getConfig("first_line_size", 22)
	if type(firstSize) ~= "number" then firstSize = 22 end

	local secondSize = getConfig("second_line_size", 14)
	if type(secondSize) ~= "number" then secondSize = 14 end

	local alignSetting = getConfig("text_align", "right")
	if type(alignSetting) ~= "string" then alignSetting = "right" end
	local columnAlign = "end"
	local textAlign = "end"
	if alignSetting == "left" then
		columnAlign = "start"
		textAlign = "start"
	elseif alignSetting == "center" then
		columnAlign = "center"
		textAlign = "center"
	end

	local col = ui.column({ gap = 2, align = columnAlign }, {
		ui.label({
			text = firstLine,
			fontSize = firstSize,
			fontWeight = "light",
			color = "on_surface_variant",
			opacity = opacity,
			textAlign = textAlign,
		}),
		ui.label({
			text = secondLine,
			fontSize = secondSize,
			color = "on_surface_variant",
			opacity = opacity,
			textAlign = textAlign,
		}),
	})
	panel.render(col)
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

function onConfigChanged()
	render()
end

function onIpc(event, _payload)
	if event == "close" then
		panel.close()
	end
end
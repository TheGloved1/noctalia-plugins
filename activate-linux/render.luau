--!nonstrict
-- Shared rendering helpers for Activate Linux (desktop widget + overview panel).
-- Desktop widget (desktop.luau) and panel (panel.luau) both require this
-- module so the watermark rendering logic lives in one place.

local function getConfig(key, fallback)
	local v = noctalia.getConfig(key)
	if v == nil then return fallback end
	return v
end

local function computeLayout()
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

	return {
		firstLine = firstLine,
		secondLine = secondLine,
		opacity = opacity,
		firstSize = firstSize,
		secondSize = secondSize,
		columnAlign = columnAlign,
		textAlign = textAlign,
	}
end

local function buildTree(layout)
	return ui.column({ gap = 2, align = layout.columnAlign }, {
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
end

return {
	getConfig = getConfig,
	computeLayout = computeLayout,
	buildTree = buildTree,
}
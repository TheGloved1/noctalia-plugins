--!nonstrict
-- Activate Linux — desktop watermark
-- Port of hthienloc/dms-activate-linux (QML) to Noctalia desktop_widget.
--
-- Renders two lines bottom-right aligned via the host's desktop widget
-- placement (drag to corner in edit mode). Opacity and font sizes are
-- configurable; text can be customized or fall back to the classic strings.

local function getConfig(key, fallback)
	local v = noctalia.getConfig(key)
	if v == nil then return fallback end
	return v
end

local function render()
	local customize = getConfig("customize_text", false) == true

	local firstLine = customize and getConfig("first_line", "Activate Linux") or "Activate Linux"
	local secondLine = customize and getConfig("second_line", "Go to Settings to activate Linux.") or "Go to Settings to activate Linux."

	-- Ensure non-empty fallback (visible_when hides inputs but stored value may be empty)
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

	local overviewMode = getConfig("overview_mode", "always")
	if type(overviewMode) ~= "string" then overviewMode = "always" end
	local isOverview = noctalia.state.get("overview.is_open")
	-- nil = unknown / non-Niri → fallback to always visible
	if overviewMode == "overview_only" and isOverview == false then
		desktopWidget.render(ui.box({ visible = false, width = 1, height = 1 }))
		return
	end
	if overviewMode == "hidden_in_overview" and isOverview == true then
		desktopWidget.render(ui.box({ visible = false, width = 1, height = 1 }))
		return
	end
	-- when isOverview is nil (non-Niri or not yet known), treat as always visible

	-- Use palette role with reduced alpha via opacity prop per-label.
	-- Group opacity fades children uniformly, matching DMS Theme.surfaceVariantText at 40%.
	desktopWidget.render(ui.column({ gap = 2, align = columnAlign }, {
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
	}))
end

function onConfigChanged()
	render()
end

noctalia.state.watch("overview.is_open", function() render() end)

render()

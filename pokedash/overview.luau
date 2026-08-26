--!nonstrict
-- Overview watcher service for Niri — publishes overview.is_open and
-- toggles the floating Top-layer panel that shows PokeDash in the
-- overview, mirroring DMS DesktopPluginWrapper behavior.
--
-- Niri-only: on other compositors, state stays nil and the desktop
-- widget falls back to always visible; no panel is shown.

noctalia.log("Overview service started (pokedash)")
if not noctalia.commandExists("niri") then
	noctalia.log("Overview: niri not found, overview_only disabled (fallback to always)")
	return
end
noctalia.log("Overview: niri found, starting watcher")

local PANEL_ID = "gloves/pokedash:overview-widget"

local function setState(isOpen)
	noctalia.state.set("overview.is_open", isOpen)
	noctalia.log("Overview: is_open=" .. tostring(isOpen))
	if isOpen then
		noctalia.togglePanel(PANEL_ID)
	end
end

-- Initial state (runs once, sets state before panel.luau self-gates)
noctalia.runAsync("niri msg -j overview-state 2>/dev/null", function(res)
	if res and res.exitCode == 0 and res.stdout then
		if res.stdout:find('"is_open"%s*:%s*true') then
			setState(true)
		elseif res.stdout:find('"is_open"%s*:%s*false') then
			setState(false)
		end
	end
end)

-- Stream overview events
local ok = noctalia.runStream("niri msg -j event-stream 2>/dev/null", function(line)
	if line:find("OverviewOpenedOrClosed") then
		if line:find('"is_open"%s*:%s*true') then
			setState(true)
		elseif line:find('"is_open"%s*:%s*false') then
			setState(false)
		end
	end
end)

if not ok then
	noctalia.log("Overview: event-stream failed, falling back to polling")
	noctalia.setUpdateInterval(500)
	function update()
		noctalia.runAsync("niri msg -j overview-state 2>/dev/null", function(res)
			if res and res.stdout then
				if res.stdout:find('"is_open"%s*:%s*true') then setState(true)
				elseif res.stdout:find('"is_open"%s*:%s*false') then setState(false) end
			end
		end)
	end
end
--!nonstrict
-- Overview watcher service for Niri — opens the floating Top-layer panel
-- that shows PokeDash in the overview.
--
-- Uses its own state key (not shared with other plugins) so multiple
-- plugins can independently track overview state without interference.

noctalia.log("Overview service started (pokedash)")
if not noctalia.commandExists("niri") then
	noctalia.log("Overview: niri not found, overview_only disabled (fallback to always)")
	return
end
noctalia.log("Overview: niri found, starting watcher")

local PANEL_ID = "gloves/pokedash:overview-widget"
local STATE_KEY = "pokedash.overview.is_open"

function setState(isOpen)
	noctalia.state.set(STATE_KEY, isOpen)
	noctalia.log("Overview: is_open=" .. tostring(isOpen))
	if isOpen then
		noctalia.runAsync("noctalia msg panel-open " .. PANEL_ID .. " 2>/dev/null")
	else
		noctalia.runAsync("noctalia msg panel-close " .. PANEL_ID .. " 2>/dev/null")
	end
end

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
--!nonstrict
-- Activate Linux — overview-only panel (Top layer in niri, above grids).
--
-- Opens via noctalia.togglePanel() from the overview service when the
-- overview opens; closes automatically when the overview closes. The
-- initial state is set by the service before the panel loads, so no
-- startup query is needed here (avoids double-toggle race).

local ActivateLinuxRender = require("./render.luau")

local closing = false
local cachedOverviewOpen = nil

local function render()
	if cachedOverviewOpen ~= true then return end
	local layout = ActivateLinuxRender.computeLayout()
	panel.render(ActivateLinuxRender.buildTree(layout))
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

if noctalia.commandExists("niri") then
	local streamOk = noctalia.runStream("niri msg -j event-stream 2>/dev/null", function(line)
		if line:find("OverviewOpenedOrClosed") then
			local isOpen = line:find('"is_open"%s*:%s*true') ~= nil
			setOverviewState(isOpen)
		end
	end)

	if not streamOk then
		noctalia.setUpdateInterval(500)
		function update()
			noctalia.runAsync("niri msg -j overview-state 2>/dev/null", function(res)
				if res and res.exitCode == 0 and res.stdout then
					local isOpen = res.stdout:find('"is_open"%s*:%s*true') ~= nil
					setOverviewState(isOpen)
				end
			end)
		end
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
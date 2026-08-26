--!nonstrict
-- Activate Linux — overview-only panel (Top layer in niri, above grids).
--
-- Opens via noctalia.togglePanel() from the overview service when the
-- overview opens; closes automatically when the overview closes.

local ActivateLinuxRender = require("./render.luau")

local closing = false

local function render()
	local tree = ActivateLinuxRender.buildTree(ActivateLinuxRender.computeLayout())
	panel.render(tree)
end

local cachedOverviewOpen = nil

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

local function queryOverviewState()
	noctalia.runAsync("niri msg -j overview-state 2>/dev/null", function(res)
		if res and res.exitCode == 0 and res.stdout then
			local isOpen = res.stdout:find('"is_open"%s*:%s*true') ~= nil
			setOverviewState(isOpen)
		end
	end)
end

local streamOk = noctalia.runStream("niri msg -j event-stream 2>/dev/null", function(line)
	if line:find("OverviewOpenedOrClosed") then
		local isOpen = line:find('"is_open"%s*:%s*true') ~= nil
		setOverviewState(isOpen)
	end
end)

if not streamOk then
	noctalia.setUpdateInterval(500)
	function update()
		queryOverviewState()
	end
end

noctalia.state.watch("overview.is_open", function(value)
	if closing then
		closing = false
		return
	end
	setOverviewState(value == true)
end)

queryOverviewState()

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
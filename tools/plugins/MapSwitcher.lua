-- MapSwitcher: a Studio toolbar, "Canyon Maps", with a button per map (2026-10-11, the user's ask: switch between the
-- maps to work on each). Not shipped: a local plugin, copied to %LOCALAPPDATA%\Roblox\Plugins. In Edit, a button makes
-- that map live with MapService.swap (src/server/Services/MapService.luau): the live map's terrain is saved back into
-- its ServerStorage.Maps folder first, then its pieces, terrain and sky trade places with the chosen map's. Edit the
-- live one as usual; switching away keeps the edits. Servers always start on the first canyon (MapService.init), so
-- the place can be published with any map live, but switching back to the Grand Canyon first saves that work at boot.

local RunService = game:GetService("RunService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local MAPS = { -- button, ServerStorage.Maps folder, the camp sign's canyon
	{ "Grand Canyon", "GrandCanyon", "Grand Canyon" },
	{ "Verdon", "Verdon", "Verdon Gorge" },
	{ "Zion", "Zion", "Zion Canyon" },
}

local toolbar = plugin:CreateToolbar("Canyon Maps")
for _, entry in MAPS do
	local button = toolbar:CreateButton(entry[1], `Make {entry[1]} the live map to edit it`, "")
	button.ClickableWhenViewportHidden = true
	button.Click:Connect(function()
		button:SetActive(false)
		if not RunService:IsEdit() then
			warn("[MapSwitcher] only in Edit")
			return
		end
		local source = game:GetService("ServerScriptService"):FindFirstChild("MapService", true)
		if not (source and source:IsA("ModuleScript")) then
			warn("[MapSwitcher] no MapService")
			return
		end
		-- A fresh copy each time, so an updated MapService is the one that runs.
		local MapService = require(source:Clone()) :: any
		local started = os.clock()
		local ok, swapped = pcall(MapService.swap, entry[2], entry[3], true)
		if not ok then
			warn(`[MapSwitcher] {swapped}`)
		elseif swapped then
			ChangeHistoryService:SetWaypoint(`Switch to {entry[1]}`)
			print(`[MapSwitcher] {entry[1]} is live ({string.format("%.1f", os.clock() - started)} s)`)
		else
			print(`[MapSwitcher] {entry[1]} is already live`)
		end
	end)
end

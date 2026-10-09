--!strict
-- The only client LocalScript. Starts every module in Controllers/ in two phases:
-- all init() calls finish before any start() runs (docs/ARCHITECTURE.md section 1).

type Module = { init: (() -> ())?, start: (() -> ())? }

-- The GUI previews in StarterGui (tools/gui_snapshot_build.luau, for looking at in Edit mode) are copied into
-- PlayerGui like any StarterGui item; the real GUIs are built by the controllers, so the copies go.
local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local function dropPreview(item: Instance)
	if item:GetAttribute("GuiPreview") then
		item:Destroy()
	end
end
playerGui.ChildAdded:Connect(dropPreview)
for _, item in playerGui:GetChildren() do
	dropPreview(item)
end

local children = {}
local controllersFolder = script:FindFirstChild("Controllers")
if controllersFolder then
	for _, child in controllersFolder:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(children, child)
		end
	end
end
table.sort(children, function(a, b)
	return a.Name < b.Name
end)

local modules: { Module } = {}
for _, child in children do
	table.insert(modules, (require :: any)(child))
end
for _, module in modules do
	if module.init then
		module.init()
	end
end
for _, module in modules do
	if module.start then
		task.spawn(module.start)
	end
end

print(`[Client] Plant the Forest started ({#modules} controllers)`)

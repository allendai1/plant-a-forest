--!strict
-- The only server Script. Creates the remotes, then starts every module in Services/
-- in two phases: all init() calls finish before any start() runs (docs/ARCHITECTURE.md section 1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

type Module = { init: (() -> ())?, start: (() -> ())? }

Remotes.createAll()

local children = {}
local servicesFolder = script:FindFirstChild("Services")
if servicesFolder then
	for _, child in servicesFolder:GetChildren() do
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

print(`[Server] Plant the Forest started ({#modules} services)`)

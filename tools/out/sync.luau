local function ensure(parent: Instance, name: string, class: string): Instance
	local inst = parent:FindFirstChild(name)
	if inst and inst.ClassName ~= class then
		local replacement = Instance.new(class)
		replacement.Name = name
		for _, child in inst:GetChildren() do
			child.Parent = replacement
		end
		inst:Destroy()
		replacement.Parent = parent
		return replacement
	end
	if not inst then
		inst = Instance.new(class)
		inst.Name = name
		inst.Parent = parent
	end
	return inst :: Instance
end
local written = 0
do
local node = ensure(game:GetService("ReplicatedStorage"), "Shared", "Folder")
local script: any = ensure(node, "GameConfig", "ModuleScript")
local body = game:GetService("HttpService"):GetAsync("http://127.0.0.1:34877/src/shared/GameConfig.luau", true)
assert(#body == 57876, "src/shared/GameConfig.luau: got " .. #body .. " bytes, expected 57876")
script.Source = body
written += 1
end
do
local node = ensure(game:GetService("StarterPlayer").StarterPlayerScripts, "Client", "LocalScript")
node = ensure(node, "Controllers", "Folder")
local script: any = ensure(node, "CharacterDisplayController", "ModuleScript")
local body = game:GetService("HttpService"):GetAsync("http://127.0.0.1:34877/src/client/Controllers/CharacterDisplayController.luau", true)
assert(#body == 6781, "src/client/Controllers/CharacterDisplayController.luau: got " .. #body .. " bytes, expected 6781")
script.Source = body
written += 1
end
return `synced {written} files`

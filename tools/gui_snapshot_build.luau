--!strict
-- gui_snapshot_build.luau: step 2 of copying the game's GUIs into StarterGui for viewing (2026-10-08). Run in Edit with
-- _G.GuiSnapshotJson set to the JSON from tools/gui_snapshot_capture.luau. Replaces the previous preview: every
-- ScreenGui lands in StarterGui named "<name> (preview)" with the GuiPreview attribute; only the HUD is left
-- enabled. The client (init.client.luau) deletes them from players' PlayerGui, and the game's scripts still build the
-- real GUIs, so editing a preview changes nothing in the game: it's a picture to look at.

local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local SHOWN = { HUD = true } -- left enabled in Edit; toggle the others' Enabled to look at them

local json = (_G :: any).GuiSnapshotJson
assert(typeof(json) == "string", "set _G.GuiSnapshotJson first")
local nodes = HttpService:JSONDecode(json)

local function decode(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local tag = value[1]
	if tag == "C3" then
		return Color3.new(value[2], value[3], value[4])
	elseif tag == "U2" then
		return UDim2.new(value[2], value[3], value[4], value[5])
	elseif tag == "U" then
		return UDim.new(value[2], value[3])
	elseif tag == "V2" then
		return Vector2.new(value[2], value[3])
	elseif tag == "R" then
		return Rect.new(value[2], value[3], value[4], value[5])
	elseif tag == "E" then
		local enumType = (Enum :: any)[value[2]]
		return enumType and enumType[value[3]]
	elseif tag == "F" then
		return Font.new(value[2], (Enum.FontWeight :: any)[value[3]], (Enum.FontStyle :: any)[value[4]])
	elseif tag == "CS" then
		local keys = {}
		for i = 2, #value do
			local k = value[i]
			table.insert(keys, ColorSequenceKeypoint.new(k[1], Color3.new(k[2], k[3], k[4])))
		end
		return ColorSequence.new(keys)
	elseif tag == "NS" then
		local keys = {}
		for i = 2, #value do
			local k = value[i]
			table.insert(keys, NumberSequenceKeypoint.new(k[1], k[2], k[3]))
		end
		return NumberSequence.new(keys)
	end
	return nil
end

for _, old in StarterGui:GetChildren() do
	if old:GetAttribute("GuiPreview") then
		old:Destroy()
	end
end

local made: { Instance } = {}
local failed = 0
for i, node in nodes do
	local ok, item = pcall(Instance.new, node.c)
	if not ok then
		failed += 1
		continue
	end
	item.Name = node.n
	for name, value in node.v do
		local decoded = decode(value)
		if decoded ~= nil then
			pcall(function()
				(item :: any)[name] = decoded
			end)
		end
	end
	made[i] = item
	if node.p == 0 then
		item.Name = `{node.n} (preview)`
		item:SetAttribute("GuiPreview", true)
		if item:IsA("ScreenGui") then
			item.Enabled = SHOWN[node.n] == true
		end
		item.Parent = StarterGui
	else
		local parent = made[node.p]
		if parent then
			item.Parent = parent
		end
	end
end
return `built {#nodes - failed} instances ({failed} skipped)`

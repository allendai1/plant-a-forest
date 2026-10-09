--!strict
-- gui_snapshot_capture.luau: step 1 of copying the game's GUIs into StarterGui for viewing in Edit mode (2026-10-08).
-- A playtest client can't make web requests, so the snapshot travels client -> server -> DataStore -> Edit:
--   1. Server datamodel: make ReplicatedStorage.GuiSnapshotTransfer (RemoteEvent) whose handler joins the chunks
--      (index, total, text) and SetAsync's the JSON to DataStore "DevGuiPreview_Studio", key "snapshot".
--   2. Client datamodel: paste this file's body (loadstring isn't fed by HTTP here); it opens the windows built on
--      demand, serializes every game ScreenGui and fires it to the server in 30,000-character chunks.
--   3. Edit: GetAsync that key into _G.GuiSnapshotJson and run tools/gui_snapshot_build.luau.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local SKIP = { -- Roblox's own and TopbarPlus's
	Freecam = true,
	TouchGui = true,
	ContextActionGui = true,
	TopbarStandard = true,
	TopbarCentered = true,
	TopbarStandardClipped = true,
	TopbarCenteredClipped = true,
	BubbleChat = true,
}

-- Open the windows built on first use, so they're in the snapshot.
local controllers = player:FindFirstChild("PlayerScripts") and player.PlayerScripts:FindFirstChild("Client")
local robuxShop = controllers and controllers:FindFirstChild("RobuxShopController", true)
if robuxShop and robuxShop:IsA("ModuleScript") then
	pcall(function()
		(require :: any)(robuxShop).open("Boosts")
	end)
	task.wait(0.5)
end

local PROPS = {
	"Enabled",
	"DisplayOrder",
	"IgnoreGuiInset",
	"ZIndexBehavior",
	"ScreenInsets",
	"Position",
	"Size",
	"AnchorPoint",
	"BackgroundColor3",
	"BackgroundTransparency",
	"BorderSizePixel",
	"Visible",
	"ZIndex",
	"LayoutOrder",
	"Rotation",
	"ClipsDescendants",
	"AutomaticSize",
	"SizeConstraint",
	"AutoButtonColor",
	"Text",
	"TextColor3",
	"TextSize",
	"FontFace",
	"TextScaled",
	"TextWrapped",
	"TextXAlignment",
	"TextYAlignment",
	"TextTransparency",
	"RichText",
	"TextStrokeTransparency",
	"TextStrokeColor3",
	"LineHeight",
	"PlaceholderText",
	"Image",
	"ImageColor3",
	"ImageTransparency",
	"ScaleType",
	"ImageRectOffset",
	"ImageRectSize",
	"SliceCenter",
	"CanvasSize",
	"ScrollBarThickness",
	"ScrollingDirection",
	"AutomaticCanvasSize",
	"CornerRadius",
	"Thickness",
	"Color",
	"Transparency",
	"ApplyStrokeMode",
	"LineJoinMode",
	"Offset",
	"FillDirection",
	"HorizontalAlignment",
	"VerticalAlignment",
	"Padding",
	"SortOrder",
	"Wraps",
	"CellSize",
	"CellPadding",
	"PaddingTop",
	"PaddingBottom",
	"PaddingLeft",
	"PaddingRight",
	"Scale",
	"AspectRatio",
	"AspectType",
	"DominantAxis",
	"MinSize",
	"MaxSize",
	"MinTextSize",
	"MaxTextSize",
}

local function encode(value: any): any
	local kind = typeof(value)
	if kind == "boolean" or kind == "number" or kind == "string" then
		return value
	elseif kind == "Color3" then
		return { "C3", value.R, value.G, value.B }
	elseif kind == "UDim2" then
		return { "U2", value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset }
	elseif kind == "UDim" then
		return { "U", value.Scale, value.Offset }
	elseif kind == "Vector2" then
		return { "V2", value.X, value.Y }
	elseif kind == "Rect" then
		return { "R", value.Min.X, value.Min.Y, value.Max.X, value.Max.Y }
	elseif kind == "EnumItem" then
		return { "E", tostring(value.EnumType), value.Name }
	elseif kind == "Font" then
		return { "F", value.Family, value.Weight.Name, value.Style.Name }
	elseif kind == "ColorSequence" then
		local keys = { "CS" }
		for _, k in value.Keypoints do
			table.insert(keys, { k.Time, k.Value.R, k.Value.G, k.Value.B })
		end
		return keys
	elseif kind == "NumberSequence" then
		local keys = { "NS" }
		for _, k in value.Keypoints do
			table.insert(keys, { k.Time, k.Value, k.Envelope })
		end
		return keys
	end
	return nil
end

local nodes = {}
local function walk(item: Instance, parent: number)
	if item:IsA("LuaSourceContainer") or not (item:IsA("GuiBase") or item:IsA("UIComponent")) then
		return
	end
	local props = {}
	for _, name in PROPS do
		local ok, value = pcall(function()
			return (item :: any)[name]
		end)
		if ok and value ~= nil then
			local encoded = encode(value)
			if encoded ~= nil then
				props[name] = encoded
			end
		end
	end
	table.insert(nodes, { c = item.ClassName, n = item.Name, p = parent, v = props })
	local index = #nodes
	if item:IsA("ViewportFrame") then
		return -- its 3D models aren't GUI
	end
	for _, child in item:GetChildren() do
		walk(child, index)
	end
end

for _, gui in playerGui:GetChildren() do
	if gui:IsA("ScreenGui") and not SKIP[gui.Name] and not gui:GetAttribute("GuiPreview") then
		walk(gui, 0)
	end
end
local json = HttpService:JSONEncode(nodes)
local CHUNK = 30000
local total = math.ceil(#json / CHUNK)
local remote = game:GetService("ReplicatedStorage"):WaitForChild("GuiSnapshotTransfer") :: RemoteEvent
for i = 1, total do
	remote:FireServer(i, total, string.sub(json, (i - 1) * CHUNK + 1, i * CHUNK))
	task.wait(0.15)
end
return `{#nodes} instances, {#json} characters in {total} chunks`

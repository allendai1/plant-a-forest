--!strict
-- SeedBagController: your seed bag and tree boosts on the HUD (docs/plans/SeedShop.md).
-- Bottom left, above the Friend Boost: a bag button that opens your special seeds (Bag_<id> attributes).
-- Tapping a seed holds it (tap again to put it away); while you hold one, TargetController and
-- CarryController plant it instead of acorns. Next to the bag, a line with your tree boost (TreeBoost)
-- and the server-wide one (ForestState ServerTreeBoost) while either is active. Banners when your own
-- tree boost grows and when someone's tree boosts everyone. preview() is the seed's 3D picture, also
-- used by the shop.
-- Polish pass (2026-10-07): above the bag, a line counting down to the seed shop's next restock, in the
-- rarity color of the rarest seed when an Epic or Legendary one is in stock now.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Trees = require(ReplicatedStorage.Shared.Trees)
local HUD = require(script.Parent.HUD)
local UIStyle = require(script.Parent.Parent.UIStyle)

local SLOT = 76 -- pixels per seed in the bag
local BOOST_COLOR = Color3.fromRGB(150, 255, 120)

local SeedBagController = {}

local localPlayer = Players.LocalPlayer
local heldSeed: string? = nil
local onHeldChanged: { () -> () } = {}

local function attribute(instance: Instance, name: string): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

function SeedBagController.held(): string?
	return heldSeed
end

function SeedBagController.setHeld(seedId: string?)
	heldSeed = seedId
	for _, callback in onHeldChanged do
		callback()
	end
end

-- "+150%" for an owner boost of 1.5.
local function percent(boost: number): string
	return `+{math.round(boost * 100)}%`
end

-- A seed's model in a ViewportFrame, turned a little toward the camera.
function SeedBagController.preview(parent: Instance, seedId: string, pixels: number): ViewportFrame
	local frame = Instance.new("ViewportFrame")
	frame.Size = UDim2.fromOffset(pixels, pixels)
	frame.BackgroundTransparency = 1
	frame.Ambient = Color3.fromRGB(170, 170, 170)
	frame.LightDirection = Vector3.new(-1, -1.5, -1)
	frame.Parent = parent
	local seeds = ReplicatedStorage:WaitForChild("Assets"):FindFirstChild("Seeds")
	local template = seeds and seeds:FindFirstChild(seedId .. "Seed")
	if template and template:IsA("Model") then
		local model = template:Clone()
		model:PivotTo(CFrame.Angles(0, math.rad(25), 0))
		model.Parent = frame
		local box, size = model:GetBoundingBox()
		local camera = Instance.new("Camera")
		local distance = math.max(size.X, size.Y, size.Z) * 1.7
		camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(0, size.Y * 0.25, distance), box.Position)
		camera.FieldOfView = 40
		camera.Parent = frame
		frame.CurrentCamera = camera
	end
	return frame
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SeedBag"
	gui.ResetOnSpawn = false
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0, 1)
	holder.Position = UDim2.new(0, 14, 1, -84) -- above the Friend Boost
	holder.AutomaticSize = Enum.AutomaticSize.XY
	holder.Parent = gui
	UIStyle.autoScale(holder)
	UIStyle.list(holder, false, 8)

	-- The bag's seeds (opens upward, above the button).
	local panel = UIStyle.panel(holder)
	panel.Name = "Bag"
	panel.LayoutOrder = 1
	panel.AutomaticSize = Enum.AutomaticSize.XY
	panel.Visible = false
	UIStyle.padding(panel, 10)
	UIStyle.list(panel, true, 8)
	local empty = UIStyle.text(panel, "No seeds yet. Buy them at the shop!", 22, UIStyle.GREY)
	empty.LayoutOrder = 100

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.AutomaticSize = Enum.AutomaticSize.XY
	row.LayoutOrder = 3
	row.Parent = holder
	UIStyle.list(row, true, 12)
	local button = UIStyle.button(row, "Seeds", UIStyle.Colors.Green, UDim2.fromOffset(150, 56), 28)
	button.Name = "BagButton"
	button.AutomaticSize = Enum.AutomaticSize.X -- "Holding Cherry Blossom" grows it
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
	pad.Parent = button
	local boosts = UIStyle.text(row, "", 30, BOOST_COLOR)
	boosts.Name = "Boosts"
	boosts.LayoutOrder = 2

	-- The restock line, above the bag button.
	local restockRow = Instance.new("Frame")
	restockRow.Name = "Restock"
	restockRow.BackgroundTransparency = 1
	restockRow.AutomaticSize = Enum.AutomaticSize.XY
	restockRow.LayoutOrder = 2
	restockRow.Parent = holder
	UIStyle.list(restockRow, true, 6)
	UIStyle.icon(restockRow, UIStyle.Icons.Restock, 28)
	local restockText = UIStyle.text(restockRow, "", 22, UIStyle.GOLD, true)
	restockText.LayoutOrder = 2
	task.spawn(function()
		while true do
			local now = workspace:GetServerTimeNow()
			local restock = GameConfig.restockIndex(now)
			local left = (restock + 1) * GameConfig.SeedShop.RestockSeconds - now
			local stock = GameConfig.seedStock(restock)
			local rare: GameConfig.SeedDef? = nil
			for _, def in GameConfig.SeedShop.Seeds do
				if stock[def.Id] > 0 and def.ServerBoost > 0 then
					rare = def
				end
			end
			if rare then
				restockText.Text = `{rare.DisplayName} in the seed shop! {UIStyle.clock(left)}`
				restockText.TextColor3 = Trees.RarityColors[rare.Rarity]
			else
				restockText.Text = `New seeds in {UIStyle.clock(left)}`
				restockText.TextColor3 = UIStyle.GOLD
			end
			task.wait(1)
		end
	end)

	local slots: { [string]: TextButton } = {}
	for i, def in GameConfig.SeedShop.Seeds do
		local slot = Instance.new("TextButton")
		slot.Name = def.Id
		slot.Text = ""
		slot.LayoutOrder = i
		slot.Size = UDim2.fromOffset(SLOT, SLOT + 26)
		UIStyle.glow(slot, UIStyle.CARD_EDGE, UIStyle.CARD_MIDDLE) -- the shop cards' look
		slot.Parent = panel
		UIStyle.corner(slot, 12)
		local stroke = UIStyle.stroke(slot, 3, Trees.RarityColors[def.Rarity])
		stroke.Name = "Edge"
		local picture = SeedBagController.preview(slot, def.Id, SLOT - 12)
		picture.Position = UDim2.fromOffset(6, 4)
		local count = UIStyle.text(slot, "", 24)
		count.Name = "Count"
		count.AnchorPoint = Vector2.new(1, 0)
		count.Position = UDim2.new(1, -6, 0, 2)
		local name = UIStyle.text(slot, def.DisplayName, 14, Trees.RarityColors[def.Rarity])
		name.AnchorPoint = Vector2.new(0.5, 1)
		name.Position = UDim2.new(0.5, 0, 1, -4)
		slot.Activated:Connect(function()
			SeedBagController.setHeld(if heldSeed == def.Id then nil else def.Id)
		end)
		slots[def.Id] = slot
	end

	local forestState = ReplicatedStorage:WaitForChild("ForestState")
	local function refresh()
		local any = false
		for _, def in GameConfig.SeedShop.Seeds do
			local count = attribute(localPlayer, `Bag_{def.Id}`)
			local slot = slots[def.Id]
			slot.Visible = count > 0
			any = any or count > 0
			local label = slot:FindFirstChild("Count") :: TextLabel?
			if label then
				label.Text = `x{count}`
			end
			local edge = slot:FindFirstChild("Edge") :: UIStroke?
			if edge then
				edge.Thickness = if heldSeed == def.Id then 6 else 3
			end
			slot.BackgroundColor3 = if heldSeed == def.Id then Color3.fromRGB(95, 80, 45) else Color3.fromRGB(60, 48, 38)
			if heldSeed == def.Id and count <= 0 then
				heldSeed = nil -- planted the last one
			end
		end
		empty.Visible = not any
		local held = heldSeed and GameConfig.seedDef(heldSeed)
		button.Text = if held then `Holding {held.DisplayName}` else "Seeds"
		UIStyle.recolor(button, if held then UIStyle.Colors.Gold else UIStyle.Colors.Green)

		local own = attribute(localPlayer, "TreeBoost")
		local server = forestState:GetAttribute("ServerTreeBoost")
		local everyone = if typeof(server) == "number" then server else 1
		local parts = {}
		if own > 0 then
			table.insert(parts, `Trees: {percent(own)}`)
		end
		if everyone > 1 then
			table.insert(parts, `Server: {math.round(everyone * 100) / 100}x`)
		end
		boosts.Text = table.concat(parts, " · ")
		boosts.Visible = #parts > 0
	end
	button.Activated:Connect(function()
		if heldSeed then
			SeedBagController.setHeld(nil) -- put the seed away
		else
			panel.Visible = not panel.Visible
		end
	end)
	table.insert(onHeldChanged, function()
		if heldSeed then
			panel.Visible = false
		end
		refresh()
	end)
	for _, def in GameConfig.SeedShop.Seeds do
		localPlayer:GetAttributeChangedSignal(`Bag_{def.Id}`):Connect(refresh)
	end
	local lastOwn = attribute(localPlayer, "TreeBoost")
	localPlayer:GetAttributeChangedSignal("TreeBoost"):Connect(function()
		local own = attribute(localPlayer, "TreeBoost")
		if own > lastOwn then
			HUD.banner(`Your trees: {percent(own)} training!`)
		end
		lastOwn = own
		refresh()
	end)
	forestState:GetAttributeChangedSignal("ServerTreeBoost"):Connect(refresh)
	forestState:GetAttributeChangedSignal("TreeBoosts"):Connect(function()
		local def = GameConfig.seedDef(tostring(forestState:GetAttribute("TreeBoostSeed")))
		local by = forestState:GetAttribute("TreeBoostBy")
		local everyone = attribute(forestState, "ServerTreeBoost")
		if def and typeof(by) == "string" then
			HUD.banner(`{by}'s {def.DisplayName}: everyone trains {math.round(everyone * 100) / 100}x!`)
		end
	end)
	refresh()
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

function SeedBagController.start()
	if not GameConfig.Features.SeedShop then
		return -- the feature is off: no bag, no restock line
	end
	build()
end

return SeedBagController

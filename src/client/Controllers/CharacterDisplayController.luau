--!strict
-- CharacterDisplayController: the shop-display look of the character pass NPCs (2026-10-07, after Build the Pyramid's
-- Pharaoh stand): the Builderman since the bridge (2026-10-10; was the Forest Ranger), and the Lord of the Forest. Over each NPC (tagged CharacterNpc, with an Outfit attribute): the
-- pass's Robux price, its name in big colored letters and its boosts (sparkles removed 2026-10-08), in
-- the same color. The prompt that sells the pass is OutfitService's.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local UIStyle = require(script.Parent.Parent.UIStyle)

local PRICE_COLOR = Color3.fromRGB(110, 255, 110)
local COLORS: { [string]: Color3 } = { -- the stands' rim colors
	Builderman = Color3.fromRGB(255, 160, 50), -- the Turbo Builders Club orange
	God = Color3.fromRGB(255, 205, 40), -- the God of Hammers robot's construction yellow
}
-- Studs over the NPC's head to the bottom of the sign: right above his head, just clear of the hammer in his raised
-- hand (2026-10-11, the user; it was 11.5 for a while, up above his stage's arch).
local ABOVE_HEAD = 2.5
-- The sign's width in the world: 22 since 2026-10-10 (the user's ask, after Build the Pyramid's hard-to-miss Sun God
-- stand; was 7), so it reads from across camp.
local SIGN_STUDS = 22
local DESIGN = Vector2.new(600, 170) -- the layout's size in pixels before it's scaled to the sign
-- Each line's top and height, as shares of the sign's height: the price, a big name, then the boosts on one line
-- (short words keep them big: the text shrinks to fit the sign's width).
local LINES = { Price = { 0, 0.22 }, PassName = { 0.18, 0.46 }, Boosts = { 0.64, 0.34 } }
local MAX_DISTANCE = 250
local SHADOW_DROP = 0.08 -- the shadow's offset, as a share of each line's height

local CharacterDisplayController = {}

local function passFor(outfit: unknown): GameConfig.HandsPass?
	for _, pass in GameConfig.availableHandsPasses() do
		if pass.Outfit == outfit then
			return pass
		end
	end
	return nil
end

-- Sets an outlined label's text on its Face and Shadow copies too: in a sign built in Edit (a saved place), the
-- label's own Changed mirror isn't connected.
local function setText(label: TextLabel, text: string)
	label.Text = text
	for _, copy in label:GetChildren() do
		if copy:IsA("TextLabel") then
			copy.Text = text
		end
	end
end

-- One line of the sign: outlined text filling a share of its height, scaled to fit (no script needed to lay it
-- out, so the sign looks right in Studio's Edit mode too).
local function line(content: Instance, name: string, text: string, color: Color3, top: number, height: number): TextLabel
	local label = UIStyle.text(content, text, 40, color)
	label.Name = name
	label.AutomaticSize = Enum.AutomaticSize.None
	label.Position = UDim2.fromScale(0, top)
	label.Size = UDim2.fromScale(1, height)
	label.TextScaled = true
	for _, copy in label:GetChildren() do
		if copy:IsA("TextLabel") then
			copy.TextScaled = true
		end
	end
	return label
end

local function boostsText(pass: GameConfig.HandsPass): string
	local text = "Quick Pickup · Quick Build" -- not "2x Pickup": it's faster, not more planks (the user's call)
	return if pass.BridgeMultiplier then `{pass.BridgeMultiplier}x Bridges · {text}` else text -- bridges first (the user's call)
end

-- Builds the sign over an NPC's head (2026-10-08: built into the place so it shows in Edit mode; the game only
-- fills in the live price). Sized in studs, so it shrinks with distance like a real sign.
-- The sign's size, placement and line layout (also put on a sign saved in the place, so a resize reaches it).
local function place(sign: BillboardGui)
	sign.Size = UDim2.fromScale(SIGN_STUDS, SIGN_STUDS * DESIGN.Y / DESIGN.X)
	sign.SizeOffset = Vector2.new(0, 0.5) -- its bottom edge sits at the offset point
	sign.StudsOffsetWorldSpace = Vector3.new(0, ABOVE_HEAD, 0)
	sign.MaxDistance = MAX_DISTANCE
	for name, at in LINES do
		local label = sign:FindFirstChild(name)
		if label and label:IsA("TextLabel") then
			label.Position = UDim2.fromScale(0, at[1])
			label.Size = UDim2.fromScale(1, at[2])
			-- A drop shadow that scales with the text (it was 4 pixels down on a 22-stud sign, hidden by the outline)
			-- and Build the Pyramid's gradient (2026-10-11, the user).
			local shadow = label:FindFirstChild("Shadow")
			if shadow and shadow:IsA("TextLabel") then
				shadow.Position = UDim2.fromScale(0, SHADOW_DROP)
			end
			UIStyle.textGradient(label)
		end
	end
end

function CharacterDisplayController.buildSign(head: BasePart, pass: GameConfig.HandsPass): BillboardGui
	local color = COLORS[pass.Outfit] or UIStyle.WHITE
	local sign = Instance.new("BillboardGui")
	sign.Name = "CharacterSign"
	sign.Adornee = head
	place(sign)
	sign.LightInfluence = 0
	-- A dark strip fading out at the sides behind the three lines (2026-10-08, like Build the Pyramid's).
	UIStyle.band(sign).Size = UDim2.fromScale(1, 1)
	line(sign, "Price", "R$ ...", PRICE_COLOR, LINES.Price[1], LINES.Price[2])
	line(sign, "PassName", pass.Name, color, LINES.PassName[1], LINES.PassName[2])
	line(sign, "Boosts", boostsText(pass), color, LINES.Boosts[1], LINES.Boosts[2])
	sign.Parent = head
	return sign
end

local function decorate(model: Instance)
	local pass = passFor(model:GetAttribute("Outfit"))
	local head = model:WaitForChild("Head", 10)
	if not (pass and head and head:IsA("BasePart")) then
		return
	end
	local sign = head:FindFirstChild("CharacterSign") or CharacterDisplayController.buildSign(head, pass)
	if sign:IsA("BillboardGui") then
		place(sign)
	end
	-- A sign saved in the place may still have older words (the bridge renamed the Ranger, 2026-10-10).
	for name, text in { PassName = pass.Name, Boosts = boostsText(pass) } do
		local label = sign:FindFirstChild(name, true)
		if label and label:IsA("TextLabel") then
			setText(label, text)
		end
	end
	local price = sign:FindFirstChild("Price", true)
	if price and price:IsA("TextLabel") then
		-- The Robux price and the coin price side by side, e.g. "R$720 · 400K coins" (2026-10-11, the user's call: no
		-- progress, no "or").
		local function showPrice()
			local robux = UIStyle.priceText(pass.PassId, Enum.InfoType.GamePass, showPrice)
			setText(price, if pass.CoinPrice then `{robux}  ·  {UIStyle.short(pass.CoinPrice)} coins` else robux)
		end
		showPrice()
	end
	-- (The sparkles rising around the NPC were removed on 2026-10-08: the user wanted him plain.)
end

function CharacterDisplayController.start()
	CollectionService:GetInstanceAddedSignal("CharacterNpc"):Connect(function(model)
		task.spawn(decorate, model)
	end)
	for _, model in CollectionService:GetTagged("CharacterNpc") do
		task.spawn(decorate, model)
	end
end

return CharacterDisplayController

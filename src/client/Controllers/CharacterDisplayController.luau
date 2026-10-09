--!strict
-- CharacterDisplayController: the shop-display look of the Forest Ranger and Lord of the Forest NPCs (2026-10-07,
-- after Build the Pyramid's Pharaoh stand). Over each NPC (tagged CharacterNpc, with an Outfit attribute): the
-- pass's Robux price, its name in big colored letters and its boosts (sparkles removed 2026-10-08), in
-- the same color. The prompt that sells the pass is OutfitService's.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local UIStyle = require(script.Parent.Parent.UIStyle)

local PRICE_COLOR = Color3.fromRGB(110, 255, 110)
local COLORS: { [string]: Color3 } = { -- the stands' rim colors
	Ranger = Color3.fromRGB(240, 210, 140),
	Lord = Color3.fromRGB(150, 255, 150),
}
local ABOVE_HEAD = 2 -- studs over the NPC's head to the bottom of the sign
local SIGN_STUDS = 7 -- the sign's width in the world
local DESIGN = Vector2.new(460, 150) -- the layout's size in pixels before it's scaled to the sign
local MAX_DISTANCE = 80

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

-- Builds the sign over an NPC's head (2026-10-08: built into the place so it shows in Edit mode; the game only
-- fills in the live price). Sized in studs, so it shrinks with distance like a real sign.
function CharacterDisplayController.buildSign(head: BasePart, pass: GameConfig.HandsPass): BillboardGui
	local color = COLORS[pass.Outfit] or UIStyle.WHITE
	local sign = Instance.new("BillboardGui")
	sign.Name = "CharacterSign"
	sign.Adornee = head
	sign.Size = UDim2.fromScale(SIGN_STUDS, SIGN_STUDS * DESIGN.Y / DESIGN.X)
	sign.SizeOffset = Vector2.new(0, 0.5) -- its bottom edge sits at the offset point
	sign.StudsOffsetWorldSpace = Vector3.new(0, ABOVE_HEAD, 0)
	sign.MaxDistance = MAX_DISTANCE
	sign.LightInfluence = 0
	-- A dark strip fading out at the sides behind the three lines (2026-10-08, like Build the Pyramid's).
	UIStyle.band(sign).Size = UDim2.fromScale(1, 1)
	line(sign, "Price", "R$ ...", PRICE_COLOR, 0, 0.26)
	line(sign, "PassName", pass.Name, color, 0.24, 0.46)
	line(sign, "Boosts", `{pass.Multiplier}x Quick Pickup · {pass.Multiplier}x Quick Plant`, color, 0.72, 0.22)
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
	local price = sign:FindFirstChild("Price", true)
	if price and price:IsA("TextLabel") then
		local function showPrice()
			setText(price, UIStyle.priceText(pass.PassId, Enum.InfoType.GamePass, showPrice))
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

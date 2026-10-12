--!strict
-- BeltLabelController: while you ride a conveyor belt, a label over your nameplate shows how much it speeds you up
-- (2026-10-10, the user's ask): "CONVEYOR x1.3", your walk speed plus the belt's (BridgeController.beltSpeed, the slot
-- under you) over your walk speed. Only over your own character: the belts move each player on their own device.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BridgeGrid = require(ReplicatedStorage.Shared.BridgeGrid)
local BridgeController = require(script.Parent.BridgeController)
local UIStyle = require(script.Parent.Parent.UIStyle)

local CHECK_SECONDS = 0.15
local ABOVE_HEAD = 5.3 -- right on top of the nameplate (NameplateController: 2.4 up, 7.5 x 120/320 = 2.8 tall)
local LABEL_STUDS = 6 -- the label's width in the world
local DESIGN = Vector2.new(320, 64) -- the layout's size in pixels before it's scaled to the label
local DECK_REACH = 9 -- your root this far over the deck still counts as on the belt (standing is about 3, jumps more)
local MIN_BELT = 0.5 -- studs per second: slower belts (the end of the outward one) show nothing
local COLOR = Color3.fromRGB(255, 214, 64)

local BeltLabelController = {}

-- "1.3" for a big boost, "1.03" for a small one, so a fast walker still sees the belt helping.
local function times(multiplier: number): string
	return if multiplier < 1.1 then string.format("%.2f", multiplier) else string.format("%.1f", multiplier)
end

function BeltLabelController.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("BillboardGui")
	gui.Name = "BeltLabel"
	gui.Size = UDim2.fromScale(LABEL_STUDS, LABEL_STUDS * DESIGN.Y / DESIGN.X)
	gui.SizeOffset = Vector2.new(0, 0.5) -- grows up from the offset point, like the nameplate
	gui.StudsOffsetWorldSpace = Vector3.new(0, ABOVE_HEAD, 0)
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromOffset(DESIGN.X, DESIGN.Y)
	content.Parent = gui
	local fit = Instance.new("UIScale")
	fit.Parent = content
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fit.Scale = gui.AbsoluteSize.X / DESIGN.X
	end)
	local text = UIStyle.text(content, "", 40, COLOR)
	text.AutomaticSize = Enum.AutomaticSize.None
	text.Size = UDim2.fromScale(1, 1)
	gui.Parent = player:WaitForChild("PlayerGui")

	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local head = character and character:FindFirstChild("Head")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local belt = 0
			if BridgeController.ready() and root and root:IsA("BasePart") and humanoid then
				local frame = BridgeController.frame()
				local q, r = BridgeGrid.fromWorld(root.Position, frame)
				q = BridgeController.laneAt(root.Position) or q -- the belts are wider than their lanes
				local plot = BridgeController.plotAt(q, r)
				local above = frame:PointToObjectSpace(root.Position).Y -- the deck's top is the frame's height
				if plot and plot.deck and above > 0 and above < DECK_REACH then
					belt = BridgeController.beltSpeed(plot)
				end
			end
			if belt >= MIN_BELT and humanoid and head and head:IsA("BasePart") then
				local walk = math.max(humanoid.WalkSpeed, 1)
				text.Text = `CONVEYOR x{times((walk + belt) / walk)}`
				gui.Adornee = head
				gui.Enabled = true
			else
				gui.Enabled = false
			end
		end
	end)
end

return BeltLabelController

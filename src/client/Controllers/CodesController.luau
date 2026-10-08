--!strict
-- CodesController: the CODES panel (polish pass, 2026-10-07), opened by the HUD's Codes button. Type a code
-- and press Redeem (or Enter): the server checks it (RedeemCode, CodeService) and the panel shows its answer,
-- green with the level up sound when it worked, red with a shake when it didn't.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(script.Parent.Parent.Sounds)
local UIStyle = require(script.Parent.Parent.UIStyle)

local CodesController = {}

local localPlayer = Players.LocalPlayer
local gui: ScreenGui? = nil

function CodesController.toggle()
	if gui then
		gui.Enabled = not gui.Enabled
	end
end

function CodesController.start()
	local screen = Instance.new("ScreenGui")
	screen.Name = "Codes"
	screen.ResetOnSpawn = false
	screen.Enabled = false
	UIStyle.blurBehind(screen) -- blur and vignette behind the window, like the shops
	screen.DisplayOrder = 2
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.4) -- a little high, so a phone keyboard doesn't cover it
	holder.Size = UDim2.fromOffset(480, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.Parent = screen
	UIStyle.autoScale(holder)
	local panel = UIStyle.panel(holder)
	panel.Size = UDim2.fromScale(1, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	UIStyle.padding(panel, 18)
	UIStyle.list(panel, false, 14, Enum.HorizontalAlignment.Center)
	UIStyle.closeButton(holder, CodesController.toggle)
	local titleRow = Instance.new("Frame")
	titleRow.BackgroundTransparency = 1
	titleRow.AutomaticSize = Enum.AutomaticSize.XY
	titleRow.LayoutOrder = 1
	titleRow.Parent = panel
	UIStyle.list(titleRow, true, 10)
	UIStyle.icon(titleRow, UIStyle.Icons.Codes, 48)
	UIStyle.text(titleRow, "Codes", 44, UIStyle.GOLD).LayoutOrder = 2
	UIStyle.text(panel, "Find codes in our group and updates!", 18, UIStyle.GREY).LayoutOrder = 2

	local box = Instance.new("TextBox")
	box.Name = "Code"
	box.LayoutOrder = 3
	box.Size = UDim2.new(1, 0, 0, 56)
	box.BackgroundColor3 = Color3.fromRGB(20, 16, 12)
	box.Font = UIStyle.FONT
	box.TextSize = 28
	box.TextColor3 = UIStyle.WHITE
	box.PlaceholderText = "Type a code"
	box.PlaceholderColor3 = Color3.fromRGB(130, 120, 110)
	box.Text = ""
	box.ClearTextOnFocus = false
	box.Parent = panel
	UIStyle.corner(box, 12)
	UIStyle.stroke(box, 3, UIStyle.GOLD, true)
	local sizeLimit = Instance.new("UITextSizeConstraint")
	sizeLimit.MaxTextSize = 28
	sizeLimit.Parent = box

	local redeem = UIStyle.button(panel, "Redeem", UIStyle.Colors.Green, UDim2.fromOffset(200, 52), 30)
	redeem.LayoutOrder = 4
	local answer = UIStyle.text(panel, "", 22, UIStyle.GREY)
	answer.LayoutOrder = 5
	answer.Visible = false

	local busy = false
	local function send()
		if busy then
			return
		end
		local typed = box.Text
		if typed:gsub("%s", "") == "" then
			UIStyle.deny(box)
			return
		end
		busy = true
		local ok, okOrErr, message = pcall(function()
			return Remotes.func("RedeemCode"):InvokeServer(string.sub(typed, 1, GameConfig.Codes.MaxLength))
		end)
		busy = false
		local worked = ok and okOrErr == true
		answer.Visible = true
		answer.Text = if ok and typeof(message) == "string" then message else "Try again in a moment."
		answer.TextColor3 = if worked then UIStyle.PRICE else Color3.fromRGB(255, 120, 110)
		if worked then
			Sounds.play("LevelUp")
			UIStyle.flash(panel)
			box.Text = ""
		else
			UIStyle.deny(box)
		end
	end
	redeem.Activated:Connect(send)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			send()
		end
	end)
	screen.Parent = localPlayer:WaitForChild("PlayerGui")
	gui = screen
end

return CodesController

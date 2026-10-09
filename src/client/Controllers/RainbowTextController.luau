--!strict
-- RainbowTextController: a rainbow sweeping through the letters of any TextLabel with the attribute Rainbow = true
-- (2026-10-08, the user's ask: the 100x pad's title, like the spring's "2X TRAINING" sign). The rainbow tints the
-- label's colored face (UIStyle's outlined text draws a Face over a Shadow; a plain label is tinted itself), which
-- is turned white so the colors show true. One loop drives them all.

local RunService = game:GetService("RunService")

local UIStyle = require(script.Parent.Parent.UIStyle)

local SPEED = 0.7 -- turns of the rainbow per second (0.4 felt slow, 2026-10-08)

local RainbowTextController = {}

local gradients: { UIGradient } = {}

local function add(label: Instance)
	if not label:IsA("TextLabel") or label:GetAttribute("Rainbow") ~= true or label:FindFirstChild("Rainbow", true) then
		return
	end
	local face = label:FindFirstChild("Face")
	local target: TextLabel = if face and face:IsA("TextLabel") then face else label
	target.TextColor3 = Color3.new(1, 1, 1)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Rainbow"
	gradient.Color = UIStyle.rainbowSequence(0)
	gradient.Parent = target
	table.insert(gradients, gradient)
end

local function scan(root: Instance)
	for _, item in root:GetDescendants() do
		add(item)
	end
end

function RainbowTextController.start()
	scan(workspace)
	workspace.DescendantAdded:Connect(function(item)
		if item:IsA("TextLabel") then
			task.defer(add, item) -- after its Face is parented
		end
	end)
	RunService.RenderStepped:Connect(function()
		local colors = UIStyle.rainbowSequence(os.clock() * SPEED)
		for i = #gradients, 1, -1 do
			local gradient = gradients[i]
			if gradient.Parent then
				gradient.Color = colors
			else
				table.remove(gradients, i)
			end
		end
	end)
end

return RainbowTextController

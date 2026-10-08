--!strict
-- DispenserController: acorns rolling down an acorn dispenser's spiral slide when you grab (2026-10-07).
-- The seed racks are acorn dispensers (tools/build_map.luau): hidden markers AcornDispenser_Slide01, 02, ...
-- trace the slide from the hopper down to the basket. When your Carried goes up near one, a few small acorns
-- (copies of Assets.Acorn) roll down the markers' path, spinning, and drop into the basket. Only you see your
-- own; at most MAX_ROLLING at once. Visual only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NEAR_STUDS = 16 -- the grab happened at a dispenser this close
local ACORN_STUDS = 1.2 -- a rolling acorn's height on a dispenser at scale 1 (bigger ones roll bigger acorns)
local ACORN_HEIGHT = 10 -- Assets.Acorn's height as modeled
local ROLL_SECONDS = 1.1 -- top to basket
local PER_GRAB = 2 -- acorns per grab (more seeds in one grab still sends at most this many)
local STAGGER = 0.12
local MAX_ROLLING = 10
local SPIN = 14 -- radians per second as they roll

type Roll = { model: Model, path: { Vector3 }, lengths: { number }, total: number, started: number }

local DispenserController = {}

local localPlayer = Players.LocalPlayer
local rolling: { Roll } = {}
local folder: Folder

-- The slide's path in a dispenser (its markers in order), or nil if it has none (an old acorn pile).
local function slidePath(rack: Instance): { Vector3 }?
	local markers = {}
	for _, part in rack:GetChildren() do
		if part:IsA("BasePart") and part.Name:match("_Slide%d+$") then
			table.insert(markers, part)
		end
	end
	if #markers < 2 then
		return nil
	end
	table.sort(markers, function(a, b)
		return a.Name < b.Name
	end)
	local path = {}
	for _, part in markers do
		table.insert(path, part.Position)
	end
	return path
end

local function nearestRack(): Instance?
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local best, bestDistance = nil, NEAR_STUDS
	for _, rack in CollectionService:GetTagged("SeedRack") do
		if rack:IsA("Model") then
			local distance = (rack:GetPivot().Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = rack, distance
			end
		end
	end
	return best
end

local function launch(path: { Vector3 }, scale: number)
	if #rolling >= MAX_ROLLING then
		return
	end
	local template = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Acorn")
	if not (template and template:IsA("Model")) then
		return
	end
	local model = template:Clone()
	model:ScaleTo(ACORN_STUDS * scale / ACORN_HEIGHT)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
			part.CastShadow = false
		end
	end
	local lengths, total = {}, 0
	for i = 2, #path do
		lengths[i] = (path[i] - path[i - 1]).Magnitude
		total += lengths[i]
	end
	model:PivotTo(CFrame.new(path[1]))
	model.Parent = folder
	table.insert(rolling, { model = model, path = path, lengths = lengths, total = total, started = os.clock() })
end

-- Every frame: moves each rolling acorn along its path, spinning; removes it once it's in the basket.
local function step()
	local now = os.clock()
	for i = #rolling, 1, -1 do
		local roll = rolling[i]
		local t = (now - roll.started) / ROLL_SECONDS
		if t >= 1 then
			roll.model:Destroy()
			table.remove(rolling, i)
			continue
		end
		local along = roll.total * t * t * (3 - 2 * t) -- eases in and out
		local position = roll.path[#roll.path]
		local direction = Vector3.new(1, 0, 0)
		for k = 2, #roll.path do
			if along <= roll.lengths[k] then
				position = roll.path[k - 1]:Lerp(roll.path[k], along / roll.lengths[k])
				direction = roll.path[k] - roll.path[k - 1]
				break
			end
			along -= roll.lengths[k]
		end
		local spin = CFrame.Angles(0, 0, -(now - roll.started) * SPIN)
		roll.model:PivotTo(CFrame.lookAt(position, position + direction) * spin)
	end
end

function DispenserController.start()
	folder = Instance.new("Folder")
	folder.Name = "RollingAcorns"
	folder.Parent = workspace
	local last = localPlayer:GetAttribute("Carried")
	localPlayer:GetAttributeChangedSignal("Carried"):Connect(function()
		local now = localPlayer:GetAttribute("Carried")
		local grabbed = typeof(now) == "number" and typeof(last) == "number" and now > last
		last = now
		if not grabbed then
			return
		end
		local rack = nearestRack()
		local path = rack and slidePath(rack)
		if path then
			for k = 1, PER_GRAB do
				task.delay((k - 1) * STAGGER, launch, path, (rack :: Model):GetScale())
			end
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return DispenserController

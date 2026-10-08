--!strict
-- CarryController: the acorn stack over every player's head, built from their Carried attribute
-- (GameConfig.AcornStack, 2026-10-08; it was acorns circling the head, docs/plans/AcornOrbit.md, and before that
-- one giant seed, M3). One acorn grows with the seeds; a full one stays and the next grows on top of it, with
-- a puff when a new one starts. Sizes ease toward their targets, so picking up and planting grow and shrink it
-- smoothly. The acorns are anchored, non-colliding parts moved by one RenderStepped loop (BulkMoveTo), only
-- for players near the camera.
-- It also owns the plant action (docs/plans/M4.md): E, left mouse, the gamepad X button, the on-screen mobile
-- button and, on touch screens, a tap anywhere on the game view. It plants into TargetController's
-- target and repeats every HoldRepeatSeconds (faster with a Hands pass) while held. While a ProximityPrompt is showing (the rack
-- or a bench), E is left to the prompt.
-- A special seed in hand (SeedBagController, docs/plans/SeedShop.md) is planted first with PlantSpecial.
-- While you carry seeds in the lobby, a "Q Drop Seeds" button shows under the pick-up prompt: Q, the gamepad Y
-- button or a tap on it drops them all (DropSeeds; the server checks you're in the lobby, GameConfig.Drop).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)
local SeedBagController = require(script.Parent.SeedBagController)
local TargetController = require(script.Parent.TargetController)
local UIStyle = require(script.Parent.Parent.UIStyle)

-- Look of the acorn stack (visual only; the sizes are in GameConfig.AcornStack).
local ACORN_HEIGHT = 10 -- Assets.Acorn's height as modeled
local SHOW_STUDS = 250 -- acorns of players farther than this from the camera aren't shown
local EASE_RATE = 10 -- how fast a size eases to its target (per second; higher is snappier)
local GONE = 0.05 -- a leaving acorn smaller than this (studs) is removed
local HEAD_GAP = 0.4 -- studs between the top of the head and the bottom acorn
local SPIN = 0.6 -- radians per second, each acorn a little behind the one under it
local SWAY = math.rad(5) -- the stack's gentle wobble
local PUFF_COUNT = 14
local PLANT_ACTION = "Plant"
local DROP_ACTION = "DropSeeds"
local DROP_SCREEN_Y = 0.97 -- the drop button's bottom edge, under the pick-up prompt (PromptController, 0.86)
local DROP_HEIGHT = 56
local DIMMED = 0.6 -- mobile plant button transparency with nothing to plant

type Piece = { part: BasePart, rel: CFrame, size: Vector3 }
type Acorn = {
	model: Model,
	pieces: { Piece },
	size: number, -- its height in studs right now (easing toward its target)
	scale: number, -- the scale its parts were last sized at
}
type Orbit = { head: BasePart?, acorns: { Acorn }, sizes: { number }, shown: boolean }

local CarryController = {}

local orbits: { [Player]: Orbit } = {}
local folder: Folder
local puffPart: Part
local puffEmitter: ParticleEmitter
local promptsShown = 0
local holding = false
local moveParts: { BasePart } = {}
local moveFrames: { CFrame } = {}

local function carriedOf(player: Player): number
	local value = player:GetAttribute("Carried")
	return if typeof(value) == "number" then value else 0
end

local function headOf(player: Player): BasePart?
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

local function clearOrbit(player: Player)
	local orbit = orbits[player]
	if orbit then
		for _, acorn in orbit.acorns do
			acorn.model:Destroy()
		end
		orbits[player] = nil
	end
end

local function newAcorn(): Acorn
	local model = (ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Acorn") :: Model):Clone()
	local pivot = model:GetPivot()
	local pieces: { Piece } = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			table.insert(pieces, { part = part, rel = pivot:ToObjectSpace(part.CFrame), size = part.Size })
		end
	end
	-- Parented by step() once it's sized and placed, so it never shows a frame at the model's full size.
	return { model = model, pieces = pieces, size = 0, scale = -1 }
end

local function puffAt(position: Vector3)
	puffPart.Position = position
	puffEmitter:Emit(PUFF_COUNT)
end

-- Brings a player's stack in line with their Carried count: the target sizes, a new acorn for each new
-- level (it grows in from nothing) and a puff when one starts on top of a full one. Acorns no longer
-- needed shrink away in step().
local function refresh(player: Player)
	local head = headOf(player)
	if not head then
		clearOrbit(player)
		return
	end
	local o: Orbit
	local existing = orbits[player]
	if existing and existing.head == head then
		o = existing
	else
		clearOrbit(player)
		o = { head = head, acorns = {}, sizes = {}, shown = true }
		orbits[player] = o
	end
	local sizes = GameConfig.acornStack(carriedOf(player))
	if #sizes > #o.sizes and #o.sizes > 0 then
		puffAt(head.Position + Vector3.new(0, head.Size.Y / 2 + HEAD_GAP, 0))
	end
	for _ = #o.acorns + 1, #sizes do
		table.insert(o.acorns, newAcorn())
	end
	o.sizes = sizes
end

-- Every frame: eases each shown acorn toward its size and stacks them over the head (one BulkMoveTo for all).
local function step(dt: number)
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local now = os.clock()
	local ease = 1 - math.exp(-EASE_RATE * dt)
	table.clear(moveParts)
	table.clear(moveFrames)
	for _, orbit in orbits do
		local head = orbit.head
		if not head or head.Parent == nil then
			continue
		end
		local near = (head.Position - eye).Magnitude <= SHOW_STUDS
		if near ~= orbit.shown then
			orbit.shown = near
			for _, acorn in orbit.acorns do
				acorn.model.Parent = if near then folder else nil
			end
		end
		if not near then
			continue
		end
		-- Acorns past the wanted ones are always on top: they shrink away, then go.
		for i = #orbit.acorns, #orbit.sizes + 1, -1 do
			if orbit.acorns[i].size < GONE then
				orbit.acorns[i].model:Destroy()
				table.remove(orbit.acorns, i)
			end
		end
		local sway = CFrame.Angles(math.sin(now * 1.3) * SWAY, 0, math.cos(now * 1.1) * SWAY)
		local base = CFrame.new(head.Position + Vector3.new(0, head.Size.Y / 2 + HEAD_GAP, 0)) * sway
		local height = 0
		for i, acorn in orbit.acorns do
			acorn.size += ((orbit.sizes[i] or 0) - acorn.size) * ease
			if acorn.model.Parent == nil then
				acorn.model.Parent = folder
			end
			-- The model's pivot is its bottom, so each acorn sits on top of the ones below it.
			local bottom = base * CFrame.new(0, height, 0) * CFrame.Angles(0, now * SPIN - i * 0.7, 0)
			height += acorn.size
			local factor = math.max(acorn.size, 0.01) / ACORN_HEIGHT
			local resize = math.abs(factor - acorn.scale) > 1e-3
			if resize then
				acorn.scale = factor
			end
			for _, piece in acorn.pieces do
				if resize then
					piece.part.Size = piece.size * factor
				end
				table.insert(moveParts, piece.part)
				table.insert(moveFrames, bottom * CFrame.new(piece.rel.Position * factor) * piece.rel.Rotation)
			end
		end
	end
	workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
end

local function watchCharacter(player: Player, character: Model)
	refresh(player)
	-- With StreamingEnabled another player's head can unload and come back as a new part.
	character.ChildAdded:Connect(function(child)
		if child.Name == "Head" then
			refresh(player)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child.Name == "Head" then
			clearOrbit(player)
		end
	end)
end

local function watchPlayer(player: Player)
	player:GetAttributeChangedSignal("Carried"):Connect(function()
		refresh(player)
	end)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		clearOrbit(player)
	end)
	if player.Character then
		watchCharacter(player, player.Character)
	end
end

local function tryPlant()
	local target = TargetController.getTarget()
	local held = SeedBagController.held()
	if held then -- a special seed in hand goes in first; the held seed is put away, so a held E then plants acorns
		if target and TargetController.canPlantSpecial() then
			Remotes.event("PlantSpecial"):FireServer(held, target.q, target.r)
			TargetController.notePlanted(target)
			SeedBagController.setHeld(nil)
		end
		return
	end
	if target and carriedOf(Players.LocalPlayer) > 0 then
		Remotes.event("PlantSeeds"):FireServer(target.q, target.r)
		TargetController.notePlanted(target) -- the guide arrow leads back here next trip
	end
end

local function onPlantAction(_: string, state: Enum.UserInputState, _: InputObject): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		holding = false -- always stop on release, even if a prompt appeared while held
		return Enum.ContextActionResult.Pass
	end
	if promptsShown > 0 then
		return Enum.ContextActionResult.Pass -- E belongs to the rack or bench prompt right now
	end
	if not holding then
		holding = true
		task.spawn(function()
			local first = true
			while holding do
				tryPlant()
				local hands = Players.LocalPlayer:GetAttribute("HandsSpeed")
				local pace = GameConfig.pressSeconds(if typeof(hands) == "number" then hands else 1)
				-- A pause before the repeat starts, so a tap is one plant (Planting.HoldDelaySeconds).
				task.wait(if first then math.max(pace, GameConfig.Planting.HoldDelaySeconds) else pace)
				first = false
			end
		end)
	end
	return Enum.ContextActionResult.Sink
end

local function bindPlanting()
	ProximityPromptService.PromptShown:Connect(function()
		promptsShown += 1
	end)
	ProximityPromptService.PromptHidden:Connect(function()
		promptsShown = math.max(0, promptsShown - 1)
	end)
	ContextActionService:BindAction(
		PLANT_ACTION,
		onPlantAction,
		true,
		Enum.KeyCode.E,
		Enum.KeyCode.ButtonX,
		Enum.UserInputType.MouseButton1
	)
	ContextActionService:SetTitle(PLANT_ACTION, "Plant")
	-- Phones: Roblox puts action buttons over the jump button; put Plant just left of it instead (2026-10-07).
	local function placeButton()
		local button = ContextActionService:GetButton(PLANT_ACTION)
		local touchGui = Players.LocalPlayer.PlayerGui:FindFirstChild("TouchGui")
		local jump = touchGui and touchGui:FindFirstChild("JumpButton", true)
		local frame = button and button.Parent
		if not (button and jump and jump:IsA("GuiObject") and frame and frame:IsA("GuiObject")) then
			return
		end
		local spot = jump.AbsolutePosition
			+ Vector2.new(-(button.AbsoluteSize.X + 14), (jump.AbsoluteSize.Y - button.AbsoluteSize.Y) / 2)
		ContextActionService:SetPosition(
			PLANT_ACTION,
			UDim2.fromOffset(spot.X - frame.AbsolutePosition.X, spot.Y - frame.AbsolutePosition.Y)
		)
	end
	task.spawn(function()
		local camera = workspace.CurrentCamera
		while true do -- the touch controls appear a moment after joining, and move when the screen turns
			placeButton()
			if camera then
				camera:GetPropertyChangedSignal("ViewportSize"):Wait()
				task.wait(0.2)
			else
				task.wait(1)
			end
		end
	end)
	task.spawn(function()
		for _ = 1, 8 do -- and again for the first few seconds, until the touch controls exist
			task.wait(1)
			placeButton()
		end
	end)
	-- A release can be lost when the window loses focus; never keep planting after that.
	UserInputService.WindowFocusReleased:Connect(function()
		holding = false
	end)
	-- Touch screens: a tap on the game view (not on a button, and not a camera drag) plants once.
	UserInputService.TouchTapInWorld:Connect(function(_, processedByUI)
		if not processedByUI and promptsShown == 0 then
			tryPlant()
		end
	end)
	-- Dim the mobile button when there's nothing to plant into.
	local dimmed: boolean? = nil
	RunService.Heartbeat:Connect(function()
		local button = ContextActionService:GetButton(PLANT_ACTION)
		local want = if SeedBagController.held()
			then not TargetController.canPlantSpecial()
			else TargetController.getTarget() == nil or carriedOf(Players.LocalPlayer) == 0
		if button and want ~= dimmed then
			dimmed = want
			button.ImageTransparency = if want then DIMMED else 0
		end
	end)
end

-- Is the local player inside the lobby (GameConfig.Drop.LobbyRadiusStuds of the hub center)? The server
-- checks the same before it drops anything.
local function inLobby(): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local center = ReplicatedStorage:WaitForChild("ForestState"):GetAttribute("Center")
	if not (root and root:IsA("BasePart") and typeof(center) == "Vector3") then
		return false
	end
	local offset = root.Position - center
	return Vector2.new(offset.X, offset.Z).Magnitude <= GameConfig.Drop.LobbyRadiusStuds
end

-- The "Q Drop Seeds" button: the prompts' dark panel with a key box, shown while you carry seeds in the lobby.
local function bindDropping()
	local drop = Remotes.event("DropSeeds")
	local screen = Instance.new("ScreenGui")
	screen.Name = "DropSeeds"
	screen.ResetOnSpawn = false
	screen.Enabled = false
	local scale = UIStyle.screenScale()
	local panel = Instance.new("TextButton")
	panel.Name = "Drop"
	panel.Text = ""
	panel.AutoButtonColor = false
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.fromScale(0.5, DROP_SCREEN_Y)
	panel.Size = UDim2.fromOffset(0, DROP_HEIGHT)
	panel.AutomaticSize = Enum.AutomaticSize.X
	panel.BackgroundColor3 = Color3.fromRGB(28, 22, 16)
	panel.BackgroundTransparency = 0.2
	panel.Parent = screen
	local fit = Instance.new("UIScale")
	fit.Scale = scale
	fit.Parent = panel
	UIStyle.corner(panel, DROP_HEIGHT // 2 - 6)
	UIStyle.stroke(panel, 3, UIStyle.BLACK, true)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 18), UDim.new(0, 22)
	pad.Parent = panel
	UIStyle.list(panel, true, 12)
	local key = Instance.new("Frame")
	key.Size = UDim2.fromOffset(DROP_HEIGHT - 14, DROP_HEIGHT - 14)
	key.BackgroundColor3 = Color3.fromRGB(12, 10, 8)
	key.Parent = panel
	UIStyle.corner(key, 10)
	local letter = UIStyle.text(key, if UIStyle.isTouch() then "TAP" else "Q", if UIStyle.isTouch() then 16 else 28)
	letter.AnchorPoint = Vector2.new(0.5, 0.5)
	letter.Position = UDim2.fromScale(0.5, 0.5)
	local words = UIStyle.text(panel, "Drop Seeds", 26)
	words.LayoutOrder = 2
	UIStyle.clicky(panel)
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local function dropNow()
		if carriedOf(Players.LocalPlayer) > 0 and inLobby() then
			drop:FireServer()
		end
	end
	panel.Activated:Connect(dropNow)
	local bound = false
	local function onDropAction(_: string, state: Enum.UserInputState, _: InputObject): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			dropNow()
		end
		return Enum.ContextActionResult.Sink
	end
	-- Shown (and Q bound) only while you carry seeds inside the lobby; checked a few times a second.
	task.spawn(function()
		while true do
			local show = carriedOf(Players.LocalPlayer) > 0 and inLobby()
			screen.Enabled = show
			if show ~= bound then
				bound = show
				if show then
					ContextActionService:BindAction(DROP_ACTION, onDropAction, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonY)
				else
					ContextActionService:UnbindAction(DROP_ACTION)
				end
			end
			task.wait(0.15)
		end
	end)
end

function CarryController.start()
	folder = Instance.new("Folder")
	folder.Name = "CarriedAcorns"
	folder.Parent = workspace
	puffPart = Instance.new("Part")
	puffPart.Name = "AcornPuff"
	puffPart.Size = Vector3.one
	puffPart.Transparency = 1
	puffPart.Anchored, puffPart.CanCollide, puffPart.CanQuery, puffPart.CanTouch = true, false, false, false
	puffPart.Parent = folder
	puffEmitter = Instance.new("ParticleEmitter")
	puffEmitter.Rate = 0
	puffEmitter.Color = ColorSequence.new(Color3.fromRGB(176, 120, 61), Color3.fromRGB(255, 215, 120))
	puffEmitter.LightEmission, puffEmitter.LightInfluence = 0.3, 0
	puffEmitter.Size = NumberSequence.new(0.9, 0.2)
	puffEmitter.Lifetime = NumberRange.new(0.5, 0.9)
	puffEmitter.Speed = NumberRange.new(8, 14)
	puffEmitter.SpreadAngle = Vector2.new(180, 180)
	puffEmitter.Drag = 4
	puffEmitter.Parent = puffPart
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(clearOrbit)
	RunService.RenderStepped:Connect(step)
	bindPlanting()
	bindDropping()
end

return CarryController

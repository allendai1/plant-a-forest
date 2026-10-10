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
-- While you carry seeds, Q or the gamepad Y button drops them all (DropSeeds), anywhere (2026-10-08, the user's
-- call; it was lobby only). Computers show a small "Q to drop" hint bottom right; phones get a Drop button.

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
local Sounds = require(script.Parent.Parent.Sounds)
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
local DROP_HINT_SIZE = 16 -- computers: the small "Q to drop" text in the bottom right corner
local DROP_HINT_MARGIN = 8
local BUTTON_FILL = 0.45 -- the mobile Plant button's dark fill transparency (like the jump button)
local DIMMED = 0.75 -- the Plant button's fill transparency with nothing to plant; its label fades too
local PLANT_BUTTON_SCALE = 0.9 -- the mobile Plant button's size, as a share of the jump button's (Roblox's is ~45 px)
local DROP_BAR_GAP = 10 -- phones: the gap between the Forest Bar and the Drop button right of it, in the bar's pixels

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

-- A soft step into the soil on your own plant press (2026-10-08, the user's ask), only for you. The pitch wanders a
-- little so a held E doesn't sound like one clip on repeat, and PLANT_SOUND_GAP keeps a fast streak from piling up.
local PLANT_SOUND_GAP = 0.12
local lastPlantSound = 0
local function plantSound()
	local now = os.clock()
	if now - lastPlantSound >= PLANT_SOUND_GAP then
		lastPlantSound = now
		Sounds.play("Plant", 0.9 + math.random() * 0.2)
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
			plantSound()
		end
		return
	end
	if target and carriedOf(Players.LocalPlayer) > 0 then
		Remotes.event("PlantSeeds"):FireServer(target.q, target.r)
		TargetController.notePlanted(target) -- the guide arrow leads back here next trip
		plantSound()
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

-- Phones: Roblox puts action buttons over the jump button; this moves one next to it instead, nearly the jump
-- button's size so it's easy to find and hit (2026-10-08; Roblox's default was small). `offset` gives the button's
-- top-left corner from the jump button's, for a button `size` pixels wide.
-- They're dark rounds like the jump button instead of Roblox's see-through bubble (2026-10-08, the user's ask): no
-- image (the jump button's has its arrow), a dark see-through circle with a soft white rim. Roblox swaps its bubble
-- image back in on every press, so the image is cleared again whenever it changes.
local styled: { [ImageButton]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function darkRound(button: ImageButton)
	if styled[button] then
		return
	end
	styled[button] = true
	local function clear()
		if button.Image ~= "" then
			button.Image = ""
		end
	end
	button:GetPropertyChangedSignal("Image"):Connect(clear)
	clear()
	button.BackgroundColor3 = Color3.new(0, 0, 0)
	button.BackgroundTransparency = BUTTON_FILL
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	local rim = Instance.new("UIStroke")
	rim.Color = Color3.new(1, 1, 1)
	rim.Thickness = 2
	rim.Transparency = 0.55
	rim.Parent = button
end

local function placeNearJump(action: string, offset: (jumpSize: Vector2, size: number) -> Vector2)
	local button = ContextActionService:GetButton(action)
	local touchGui = Players.LocalPlayer.PlayerGui:FindFirstChild("TouchGui")
	local jump = touchGui and touchGui:FindFirstChild("JumpButton", true)
	local frame = button and button.Parent
	if not (button and jump and jump:IsA("GuiObject") and frame and frame:IsA("GuiObject")) then
		return
	end
	darkRound(button)
	local size = math.round(jump.AbsoluteSize.X * PLANT_BUTTON_SCALE)
	button.Size = UDim2.fromOffset(size, size)
	local spot = jump.AbsolutePosition + offset(jump.AbsoluteSize, size)
	ContextActionService:SetPosition(
		action,
		UDim2.fromOffset(spot.X - frame.AbsolutePosition.X, spot.Y - frame.AbsolutePosition.Y)
	)
end

-- Plant: up and to the left of the jump button, where the right thumb rests (2026-10-08, the user's ask; it was
-- level with the jump button, too low). A full width left, clear of the Strength boost label above the jump button.
local function plantSpot(_: Vector2, size: number): Vector2
	return Vector2.new(-size, -(size + 12))
end

local function placeButtons()
	placeNearJump(PLANT_ACTION, plantSpot)
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
	task.spawn(function()
		local camera = workspace.CurrentCamera
		while true do -- the touch controls appear a moment after joining, and move when the screen turns
			placeButtons()
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
			placeButtons()
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
	-- Dim the mobile button when there's nothing to plant into. (Set every frame: darkRound can restyle it later.)
	RunService.Heartbeat:Connect(function()
		local button = ContextActionService:GetButton(PLANT_ACTION)
		local want = if SeedBagController.held()
			then not TargetController.canPlantSpecial()
			else TargetController.getTarget() == nil or carriedOf(Players.LocalPlayer) == 0
		if button then
			button.BackgroundTransparency = if want then DIMMED else BUTTON_FILL
			local title = button:FindFirstChildWhichIsA("TextLabel")
			if title then
				title.TextTransparency = if want then 0.4 else 0
			end
		end
	end)
end

-- Phones: a small dark "Drop" button just right of the Forest Bar (at the bottom there), as tall as the bar, with a
-- gap (2026-10-08, the user's ask: by the jump button it was too easy to hit by mistake). It lives in the bar, so
-- it follows the bar's size and spot; it's made once the HUD has built the bar.
local function phoneDropButton(onDrop: () -> ()): TextButton
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local bar = playerGui:FindFirstChild("ForestBar", true)
	while not (bar and bar:IsA("GuiObject")) do
		task.wait(0.5)
		bar = playerGui:FindFirstChild("ForestBar", true)
	end
	local button = Instance.new("TextButton")
	button.Name = "Drop"
	button.Text = ""
	button.AutoButtonColor = false
	button.Visible = false
	button.AnchorPoint = Vector2.new(0, 0.5)
	button.Position = UDim2.new(1, DROP_BAR_GAP, 0.5, 0)
	button.Size = UDim2.new(0, 0, 1, 0) -- the bar's height
	button.AutomaticSize = Enum.AutomaticSize.X
	button.BackgroundColor3 = Color3.fromRGB(28, 22, 16)
	button.BackgroundTransparency = 0.2
	button.Parent = bar
	UIStyle.corner(button, 16)
	UIStyle.stroke(button, 4, UIStyle.BLACK, true)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 18), UDim.new(0, 18)
	pad.Parent = button
	UIStyle.list(button, true, 0, Enum.HorizontalAlignment.Center).VerticalAlignment = Enum.VerticalAlignment.Center
	UIStyle.text(button, "Drop", 28)
	UIStyle.clicky(button)
	button.Activated:Connect(onDrop)
	return button
end

-- The drop hint, shown while you carry seeds. On a computer: small "Q to drop" text in the bottom right corner
-- (2026-10-08, the user's ask: the big "Q Drop Seeds" bar in the middle made dropping look like the main action).
-- On phones: phoneDropButton, right of the Forest Bar.
local function bindDropping()
	local drop = Remotes.event("DropSeeds")
	local touch = UIStyle.isTouch()
	local screen: ScreenGui? = nil
	local phoneButton: TextButton? = nil
	if touch then
		task.spawn(function()
			phoneButton = phoneDropButton(function()
				if carriedOf(Players.LocalPlayer) > 0 then
					drop:FireServer()
				end
			end)
		end)
	else
		local gui = Instance.new("ScreenGui")
		gui.Name = "DropSeeds"
		gui.ResetOnSpawn = false
		gui.Enabled = false
		local hint = UIStyle.text(gui, "Q to drop", DROP_HINT_SIZE)
		hint.Name = "Drop"
		hint.AnchorPoint = Vector2.new(1, 1)
		hint.Position = UDim2.new(1, -DROP_HINT_MARGIN, 1, -DROP_HINT_MARGIN)
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		screen = gui
	end

	local bound = false
	local function onDropAction(_: string, state: Enum.UserInputState, _: InputObject): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin and carriedOf(Players.LocalPlayer) > 0 then
			drop:FireServer()
		end
		return Enum.ContextActionResult.Sink
	end
	-- Shown (and Q bound) only while you carry seeds; checked a few times a second.
	task.spawn(function()
		while true do
			local show = carriedOf(Players.LocalPlayer) > 0
			if screen then
				screen.Enabled = show
			end
			if phoneButton then
				phoneButton.Visible = show
			end
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

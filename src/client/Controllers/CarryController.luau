--!strict
-- CarryController: the stack of plank bundles over every player's head (bundles since 2026-10-10; they were acorns),
-- built from their Carried attribute
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
-- Auto Build pass owners (AutoBuild attribute, 2026-10-11) place without holding anything: while they carry planks
-- and have a target, a loop places at their usual pace, the same request a held E sends. Lucky Planks (2026-10-11):
-- planks that come back to your hands show a "Lucky! +N" pop rising from the slot they were placed in (LuckyPlanks).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)
local SeedBagController = require(script.Parent.SeedBagController)
local Sounds = require(script.Parent.Parent.Sounds)
local TargetController = require(script.Parent.TargetController)
local UIStyle = require(script.Parent.Parent.UIStyle)

-- Look of the bundle stack (visual only; the sizes are in GameConfig.AcornStack).
local ACORN_HEIGHT = 1 -- a plank bundle's height as built by newAcorn()
local BUNDLE_SIZE = Vector3.new(5, 1, 1.8) -- planks run along X: about one plank's length and two planks wide
local SPREAD = 0.3 -- the bundle's length and width grow with its height to this power (height grows fully)
local MAX_SPREAD = 2.2 -- ... up to this many times
local STRAP_COLOR = Color3.fromRGB(70, 46, 30)
local SHOW_STUDS = 250 -- acorns of players farther than this from the camera aren't shown
local EASE_RATE = 10 -- how fast a size eases to its target (per second; higher is snappier)
local GONE = 0.05 -- a leaving acorn smaller than this (studs) is removed
local HEAD_GAP = 0 -- studs between the top of the head and the bottom bundle (0.4 until it stopped floating)
local PUFF_COUNT = 14
local PLANT_ACTION = "Plant"
local DROP_ACTION = "DropSeeds"
local DROP_HINT_SIZE = 16 -- computers: the small "Q to drop" text in the bottom right corner
local DROP_HINT_MARGIN = 8
local BUTTON_FILL = 0.45 -- the mobile Plant button's dark fill transparency (like the jump button)
local DIMMED = 0.75 -- the Plant button's fill transparency with nothing to plant; its label fades too
local PLANT_BUTTON_SCALE = 0.9 -- the mobile Plant button's size, as a share of the jump button's (Roblox's is ~45 px)
-- The Build button's icon: a white outlined plank (tools/make_ui_icons.py), after Build the Pyramid's outlined block
-- (2026-10-10, the user's ask; it said "Build"). Decal 136165727060497.
local PLANK_ICON = "rbxassetid://93968072318922"
local ICON_SCALE = 0.62 -- the icon's size, as a share of the button's
local DROP_ICON = "rbxassetid://73901267496151" -- the Drop button's: a down arrow onto a line (make_ui_icons.py; decal 127276746461495)
local DROP_SCALE = 0.85 -- phones: the Drop button's size, as a share of Build's (the user: slightly smaller)
local BUTTON_GAP = 0.2 -- phones: the gap between the round buttons, as a share of Build's size (the reference's)

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
local dropBound = false -- DROP_ACTION is bound only while you carry planks (GetButton warns when it isn't)
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

-- The live map's building material (GameConfig.Decks): what the carried bundles are made of.
local function deckLook(): GameConfig.Deck
	local map = workspace:FindFirstChild("Map")
	return GameConfig.deckFor(map and map:GetAttribute("CurrentMap"))
end

-- A bundle of planks: a block of the map's material (concrete slabs, steel plates or asphalt since 2026-10-11; wood
-- before) with two dark straps, its pivot at its bottom middle.
local function bundleModel(): Model
	local model = Instance.new("Model")
	model.Name = "PlankBundle"
	local block = Instance.new("Part")
	block.Name = "Planks"
	block.Size = BUNDLE_SIZE
	block.CFrame = CFrame.new(0, BUNDLE_SIZE.Y / 2, 0)
	local look = deckLook()
	block.Color = look.Color
	block.Material = look.Material
	block.Parent = model
	for _, x in { -BUNDLE_SIZE.X / 4, BUNDLE_SIZE.X / 4 } do
		local strap = Instance.new("Part")
		strap.Name = "Strap"
		strap.Size = Vector3.new(0.35, BUNDLE_SIZE.Y * 1.04, BUNDLE_SIZE.Z + 0.1) -- scaled with the bundle, so kept proportional
		strap.CFrame = CFrame.new(x, BUNDLE_SIZE.Y / 2, 0)
		strap.Color = STRAP_COLOR
		strap.Material = Enum.Material.Fabric
		strap.Parent = model
	end
	model.WorldPivot = CFrame.identity
	return model
end

local function newAcorn(): Acorn
	local model = bundleModel()
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
		-- Resting on top of the head, turned with the character (no spin or wobble since 2026-10-10, the user's call).
		local look = head.CFrame.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		-- Turned a quarter: the planks run front to back over the head (the user's call; they ran across the shoulders).
		local base = CFrame.new(head.Position + Vector3.new(0, head.Size.Y / 2 + HEAD_GAP, 0))
			* CFrame.Angles(0, yaw + math.pi / 2, 0)
		local height = 0
		for i, acorn in orbit.acorns do
			acorn.size += ((orbit.sizes[i] or 0) - acorn.size) * ease
			if acorn.model.Parent == nil then
				acorn.model.Parent = folder
			end
			-- The model's pivot is its bottom, so each acorn sits on top of the ones below it.
			local bottom = base * CFrame.new(0, height, 0)
			height += acorn.size
			-- Taller with more planks; longer and wider only a little, so a few planks look like a few planks.
			local tall = math.max(acorn.size, 0.01) / ACORN_HEIGHT
			local wide = math.clamp(tall ^ SPREAD, 1, MAX_SPREAD)
			local factor = Vector3.new(wide, tall, wide)
			local resize = math.abs(tall - acorn.scale) > 1e-3
			if resize then
				acorn.scale = tall
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
	if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		holding = false -- always stop on release, even if a prompt appeared while held
		return Enum.ContextActionResult.Pass
	elseif state ~= Enum.UserInputState.Begin then
		-- Change: a finger moving on the phone's Build button while it's held (easy while walking with the other thumb).
		-- It's still held, so keep going (2026-10-11, the user: it stopped, and walking back in range didn't resume).
		return Enum.ContextActionResult.Sink
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

-- Auto Build: places for pass owners while they carry planks and have a target, at their pace. Holding E (or a
-- special seed in hand) takes over.
local AUTO_IDLE_SECONDS = 0.1
local function autoPlace()
	local player = Players.LocalPlayer
	while true do
		if
			player:GetAttribute("AutoBuild") == true
			and player:GetAttribute("AutoBuildOn") ~= 0 -- its Settings switch
			and not holding
			and not SeedBagController.held()
			and TargetController.getTarget()
			and carriedOf(player) > 0
		then
			tryPlant()
			local hands = player:GetAttribute("HandsSpeed")
			task.wait(GameConfig.pressSeconds(if typeof(hands) == "number" then hands else 1))
		else
			task.wait(AUTO_IDLE_SECONDS)
		end
	end
end

-- Lucky Planks: a gold "Lucky! +N" rises from the slot the lucky plank was placed in and fades (the user's ask: from the
-- block, not over your head). Lucky planks on the same slot close together are added into one pop (LUCKY_GAP).
local LUCKY_GAP = 0.4
local LUCKY_COLOR = Color3.fromRGB(255, 220, 90)
local luckyWaiting: { [Vector3]: number } = {}

local function luckyPop(position: Vector3, count: number)
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position + Vector3.new(0, 1.5, 0)
	anchor.Parent = workspace.Terrain
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(240, 60)
	sign.AlwaysOnTop = true
	sign.LightInfluence = 0
	sign.Adornee = anchor
	local label = UIStyle.text(sign, `Lucky! +{count}`, 34, LUCKY_COLOR)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	sign.Parent = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	Sounds.play("Gain", 1.3)
	local rise = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(sign, rise, { StudsOffsetWorldSpace = Vector3.new(0, 3, 0) }):Play()
	for _, text in sign:GetDescendants() do
		if text:IsA("TextLabel") then
			TweenService:Create(text, rise, { TextTransparency = 1 }):Play()
		elseif text:IsA("UIStroke") then
			TweenService:Create(text, rise, { Transparency = 1 }):Play()
		end
	end
	task.delay(0.95, function()
		sign:Destroy()
		anchor:Destroy()
	end)
end

-- spots = { position, count, position, count, ... } (ForestService).
local function onLucky(spots: unknown)
	if typeof(spots) ~= "table" then
		return
	end
	local list = spots :: { any }
	for i = 1, #list - 1, 2 do
		local position, count = list[i], list[i + 1]
		if typeof(position) == "Vector3" and typeof(count) == "number" then
			local waiting = luckyWaiting[position]
			luckyWaiting[position] = (waiting or 0) + count
			if not waiting then
				task.delay(LUCKY_GAP, function()
					local total = luckyWaiting[position]
					luckyWaiting[position] = nil
					if total then
						luckyPop(position, total)
					end
				end)
			end
		end
	end
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

-- `scale` is the button's size as a share of Build's; `offset` gets the jump button's size, Build's and this button's.
local function placeNearJump(action: string, scale: number, offset: (jumpSize: Vector2, build: number, size: number) -> Vector2)
	local button = ContextActionService:GetButton(action)
	local touchGui = Players.LocalPlayer.PlayerGui:FindFirstChild("TouchGui")
	local jump = touchGui and touchGui:FindFirstChild("JumpButton", true)
	local frame = button and button.Parent
	if not (button and jump and jump:IsA("GuiObject") and frame and frame:IsA("GuiObject")) then
		return
	end
	darkRound(button)
	local icon = button:FindFirstChild("ActionIcon")
	if icon and icon:IsA("ImageLabel") then
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Size = UDim2.fromScale(ICON_SCALE, ICON_SCALE)
	end
	local build = math.round(jump.AbsoluteSize.X * PLANT_BUTTON_SCALE)
	local size = math.round(build * scale)
	button.Size = UDim2.fromOffset(size, size)
	local spot = jump.AbsolutePosition + offset(jump.AbsoluteSize, build, size)
	ContextActionService:SetPosition(
		action,
		UDim2.fromOffset(spot.X - frame.AbsolutePosition.X, spot.Y - frame.AbsolutePosition.Y)
	)
end

-- The layout copies Build the Pyramid's (2026-10-10, the user's call): Build level with the jump button on its left,
-- and a slightly smaller Drop above, halfway between them. (Build sat up and to the left of jump from 2026-10-08,
-- and Drop was a text button right of the Forest Bar.)
local function plantSpot(jumpSize: Vector2, build: number, _: number): Vector2
	return Vector2.new(-(build + math.round(build * BUTTON_GAP)), (jumpSize.Y - build) / 2)
end

local function dropSpot(jumpSize: Vector2, build: number, size: number): Vector2
	local gap = math.round(build * BUTTON_GAP)
	local buildMiddle = -(gap + build / 2)
	local middle = (buildMiddle + jumpSize.X / 2) / 2
	local top = math.min((jumpSize.Y - build) / 2, 0) -- the higher of Build's and jump's tops
	return Vector2.new(middle - size / 2, top - gap / 2 - size)
end

local function placeButtons()
	placeNearJump(PLANT_ACTION, 1, plantSpot)
	if dropBound then
		placeNearJump(DROP_ACTION, DROP_SCALE, dropSpot)
	end
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
	ContextActionService:SetImage(PLANT_ACTION, PLANK_ICON)
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
			local icon = button:FindFirstChild("ActionIcon")
			if icon and icon:IsA("ImageLabel") then
				icon.ImageTransparency = if want then 0.6 else 0
			end
		end
	end)
end

-- The drop hint, shown while you carry seeds. On a computer: small "Q to drop" text in the bottom right corner
-- (2026-10-08, the user's ask: the big "Q Drop Seeds" bar in the middle made dropping look like the main action).
-- On phones: a round Drop button above, between Build and jump (dropSpot), the action's own touch button.
local function bindDropping()
	local drop = Remotes.event("DropSeeds")
	local touch = UIStyle.isTouch()
	local screen: ScreenGui? = nil
	if not touch then
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
			if show ~= bound then
				bound = show
				dropBound = show
				if show then
					ContextActionService:BindAction(DROP_ACTION, onDropAction, touch, Enum.KeyCode.Q, Enum.KeyCode.ButtonY)
					if touch then
						ContextActionService:SetImage(DROP_ACTION, DROP_ICON)
						placeNearJump(DROP_ACTION, DROP_SCALE, dropSpot)
					end
				else
					ContextActionService:UnbindAction(DROP_ACTION)
				end
			end
			task.wait(0.15)
		end
	end)
end

function CarryController.start()
	-- A map swap changes the material of the bundles already being carried.
	task.spawn(function()
		local map = workspace:WaitForChild("Map")
		map:GetAttributeChangedSignal("CurrentMap"):Connect(function()
			local look = deckLook()
			for _, orbit in orbits do
				for _, acorn in orbit.acorns do
					for _, piece in acorn.pieces do
						if piece.part.Name == "Planks" then
							piece.part.Color, piece.part.Material = look.Color, look.Material
						end
					end
				end
			end
		end)
	end)
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
	task.spawn(autoPlace)
	Remotes.event("LuckyPlanks").OnClientEvent:Connect(onLucky)
end

return CarryController

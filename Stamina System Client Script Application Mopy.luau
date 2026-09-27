local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local MAX_STAMINA = 100

local NORMAL_SPEED = 16
local SPRINT_SPEED = 24
local EXHAUSTED_SPEED = 12

local SPRINT_DRAIN = 18
local JUMP_COST = 14

local REGEN_RATE = 15
local REGEN_DELAY = 1.5

local main = script.Parent
local staminaUI = main:WaitForChild("Stamina")
local fill = staminaUI:WaitForChild("Fill")
local filling = fill:WaitForChild("Filling")

local character
local humanoid

local stamina = MAX_STAMINA
local sprinting = false
local exhausted = false
local shiftHeld = false
local lastStaminaUse = 0

local staminaTween

filling.AnchorPoint = Vector2.new(1, 0.5)
filling.Position = UDim2.new(1, 0, 0.5, 0)

local function updateStaminaBar()
	local percentage = math.clamp(stamina / MAX_STAMINA, 0, 1)

	local targetSize = UDim2.new(
		percentage,
		0,
		1,
		0
	)

	if staminaTween then
		staminaTween:Cancel()
	end

	staminaTween = TweenService:Create(
		filling,
		TweenInfo.new(
			0.12,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{
			Size = targetSize
		}
	)

	staminaTween:Play()
end

local function stopSprint()
	if not humanoid then
		return
	end

	sprinting = false

	if exhausted then
		humanoid.WalkSpeed = EXHAUSTED_SPEED
	else
		humanoid.WalkSpeed = NORMAL_SPEED
	end
end

local function startSprint()
	if not humanoid then
		return
	end

	if exhausted then
		return
	end

	if stamina <= 0 then
		return
	end

	if humanoid.Health <= 0 then
		return
	end

	if humanoid.MoveDirection.Magnitude <= 0 then
		return
	end

	sprinting = true
	humanoid.WalkSpeed = SPRINT_SPEED
end

local function useStamina(amount)
	stamina = math.max(0, stamina - amount)
	lastStaminaUse = os.clock()

	updateStaminaBar()

	if stamina <= 0 then
		stamina = 0
		exhausted = true

		stopSprint()

		if humanoid then
			humanoid.WalkSpeed = EXHAUSTED_SPEED
			humanoid:SetStateEnabled(
				Enum.HumanoidStateType.Jumping,
				false
			)
		end
	end
end

local function setupCharacter(newCharacter)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")

	stamina = MAX_STAMINA
	sprinting = false
	exhausted = false
	shiftHeld = false
	lastStaminaUse = 0

	humanoid.WalkSpeed = NORMAL_SPEED

	humanoid:SetStateEnabled(
		Enum.HumanoidStateType.Jumping,
		true
	)

	updateStaminaBar()

	humanoid.Jumping:Connect(function(active)
		if not active then
			return
		end

		if exhausted then
			return
		end

		if stamina < JUMP_COST then
			humanoid:SetStateEnabled(
				Enum.HumanoidStateType.Jumping,
				false
			)

			task.defer(function()
				if humanoid and humanoid.Health > 0 and not exhausted then
					humanoid:SetStateEnabled(
						Enum.HumanoidStateType.Jumping,
						true
					)
				end
			end)

			return
		end

		useStamina(JUMP_COST)
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		shiftHeld = true

		UserInputService.MouseBehavior = Enum.MouseBehavior.Default

		if not gameProcessed then
			startSprint()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		shiftHeld = false
		stopSprint()

		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end)

RunService.Heartbeat:Connect(function(deltaTime)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end

	if sprinting then
		if humanoid.MoveDirection.Magnitude <= 0 then
			stopSprint()
		else
			useStamina(SPRINT_DRAIN * deltaTime)

			if exhausted then
				stopSprint()
			end
		end
	end

	if shiftHeld and not sprinting and not exhausted then
		if humanoid.MoveDirection.Magnitude > 0 then
			startSprint()
		end
	end

	if exhausted then
		stamina = math.min(
			MAX_STAMINA,
			stamina + REGEN_RATE * deltaTime
		)

		updateStaminaBar()

		if stamina >= MAX_STAMINA then
			stamina = MAX_STAMINA
			exhausted = false

			humanoid:SetStateEnabled(
				Enum.HumanoidStateType.Jumping,
				true
			)

			humanoid.WalkSpeed = NORMAL_SPEED

			updateStaminaBar()
		end

		return
	end

	if os.clock() - lastStaminaUse < REGEN_DELAY then
		return
	end

	if sprinting then
		return
	end

	local state = humanoid:GetState()

	if state == Enum.HumanoidStateType.Jumping
		or state == Enum.HumanoidStateType.Freefall then
		return
	end

	if stamina < MAX_STAMINA then
		stamina = math.min(
			MAX_STAMINA,
			stamina + REGEN_RATE * deltaTime
		)

		updateStaminaBar()
	end
end)

if player.Character then
	setupCharacter(player.Character)
end

player.CharacterAdded:Connect(setupCharacter)

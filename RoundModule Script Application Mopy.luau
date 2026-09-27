local RoundModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DataStore = DataStoreService:GetDataStore("PlayerData_v1")
local TimeModule = require(script.Parent.TimeModule)
local DisasterModule = require(script.Parent.DisasterModule)

local QuestReward = 50
local IntermissionTime = 5
local AnnounceSpeed = 0.05
local DesribeSpeed = 0.03
local AnnounceDisplayTime = 3
local DescribeDisplayTime = 2

Players.CharacterAutoLoads = false

local function announce(text)
	Remotes.Announce:FireAllClients(text)
end

local function describe(text)
	Remotes.Describe:FireAllClients(text)
end

local function GetTextTime(text, speed, displayTime)
	return (#text * speed) + displayTime
end

local function Show(text1, text2)
	announce(text1)
	describe(text2)

	local announceTime = GetTextTime(text1, AnnounceSpeed, AnnounceDisplayTime)
	local describeTime = GetTextTime(text2, DesribeSpeed, DescribeDisplayTime)

	task.wait(math.max(announceTime, describeTime))
end

local Quests = {
	[1] = {
		name = "Taxes have started! Mr Crab wants: A BLACK COFFEE!",
		description = "Find a Black coffee on the map and bring it back to Mr Crab...",
		partneededTag = "Quest1",
		active = false,
		completed = false,
	},
	[2] = {
		name = "Taxes have started! Mr Crab wants: A CUP OF TEA!",
		description = "Find a Cup of Tea on the map and bring it back to Mr Crab...",
		partneededTag = "Quest2",
		active = false,
		completed = false,
	},
}

local CurrentQuest = nil
local QuestConnection = nil
local CurrentTime = nil
local TimerRunning = false
local DisasterRunning = false

local function SetupLeaderstats(player, crabTokens)
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local crabTokenValue = leaderstats:FindFirstChild("Crab Tokens")

	if not crabTokenValue then
		crabTokenValue = Instance.new("IntValue")
		crabTokenValue.Name = "Crab Tokens"
		crabTokenValue.Parent = leaderstats
	end

	crabTokenValue.Value = crabTokens
end

local function LoadCrabTokens(player)
	local success, data = pcall(function()
		return DataStore:GetAsync(tostring(player.UserId))
	end)

	if success then
		local crabTokens = 0

		if type(data) == "table" then
			crabTokens = data["Crab Tokens"] or 0
		end

		SetupLeaderstats(player, crabTokens)
	else
		warn("Failed to load Crab Tokens for " .. player.Name)
		SetupLeaderstats(player, 0)
	end
end

local function ClearAllInventories()
	for _, player in ipairs(Players:GetPlayers()) do
		local backpack = player:FindFirstChildOfClass("Backpack")

		if backpack then
			for _, item in ipairs(backpack:GetChildren()) do
				if item:IsA("Tool") then
					item:Destroy()
				end
			end
		end

		local character = player.Character

		if character then
			for _, item in ipairs(character:GetChildren()) do
				if item:IsA("Tool") then
					item:Destroy()
				end
			end
		end
	end
end

local function GiveCrabTokens(player, amount)
	local newAmount

	local success, result = pcall(function()
		return DataStore:UpdateAsync(tostring(player.UserId), function(data)
			data = data or {}
			data["Crab Tokens"] = data["Crab Tokens"] or 0
			data["Crab Tokens"] += amount
			newAmount = data["Crab Tokens"]
			return data
		end)
	end)

	if not success then
		warn("Failed to give " .. amount .. " Crab Tokens to " .. player.Name)
		warn(result)
		return false
	end

	local leaderstats = player:FindFirstChild("leaderstats")

	if leaderstats then
		local crabTokens = leaderstats:FindFirstChild("Crab Tokens")

		if crabTokens then
			crabTokens.Value = newAmount
		end
	end

	return true
end

local function GiveServerCrabTokens(amount)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			GiveCrabTokens(player, amount)
		end)
	end
end

local function ActivateQuest(Quest)
	Quest.active = true
	Quest.completed = false
	CurrentQuest = Quest
end

local function GetPlayerToolWithTag(player, tag)
	local character = player.Character

	if character then
		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("Tool") and CollectionService:HasTag(item, tag) then
				return item
			end
		end
	end

	local backpack = player:FindFirstChildOfClass("Backpack")

	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") and CollectionService:HasTag(item, tag) then
				return item
			end
		end
	end

	return nil
end

local function ResetQuests()
	for _, quest in pairs(Quests) do
		quest.completed = false
		quest.active = false
	end
end

local function AllQuestsCompleted()
	for _, quest in pairs(Quests) do
		if not quest.completed then
			return false
		end
	end

	return true
end

local function StartIntermission()
	announce("Intermission")

	for i = IntermissionTime, 0, -1 do
		describe(tostring(i))

		if i > 0 then
			task.wait(1)
		end
	end
end

local function StartDisaster(disaster)
	if DisasterRunning then
		return
	end

	if not disaster then
		return
	end

	DisasterRunning = true

	Show(disaster.name, disaster.description)

	if disaster.module and disaster.module.Start then
		disaster.module.Start()
	end

	DisasterRunning = false

	StartIntermission()

	if AllQuestsCompleted() then
		ResetQuests()
	end

	RoundModule.StartQuest()
end

local function StartRandomDisaster()
	local disaster = DisasterModule.GetRandomDisaster()

	if not disaster then
		warn("No disasters found!")
		return
	end

	StartDisaster(disaster)
end

local function StartQuestTimer()
	if not CurrentTime or not CurrentQuest then
		return
	end

	TimerRunning = true

	for timeLeft = CurrentTime.time, 0, -1 do
		if not TimerRunning or not CurrentQuest then
			return
		end

		describe(tostring(timeLeft))

		if timeLeft > 0 then
			task.wait(1)
		end
	end

	if not TimerRunning or not CurrentQuest then
		return
	end

	TimerRunning = false

	if QuestConnection then
		QuestConnection:Disconnect()
		QuestConnection = nil
	end

	CurrentQuest.active = false
	CurrentQuest = nil
	CurrentTime = nil

	Show("TIME'S UP!", "Nobody completed the tax in time!")

	task.spawn(StartRandomDisaster)
end

local function CompleteQuest(player)
	if not CurrentQuest or CurrentQuest.completed then
		return
	end

	local requiredTag = CurrentQuest.partneededTag
	local tool = GetPlayerToolWithTag(player, requiredTag)

	if not tool then
		return
	end

	TimerRunning = false
	CurrentQuest.completed = true
	CurrentQuest.active = false

	tool:Destroy()

	ClearAllInventories()

	if QuestConnection then
		QuestConnection:Disconnect()
		QuestConnection = nil
	end

	CurrentQuest = nil
	CurrentTime = nil

	GiveServerCrabTokens(QuestReward)

	Show(
		"Crab Tokens!",
		"All players received " .. QuestReward .. " Crab Tokens!"
	)

	StartIntermission()

	if AllQuestsCompleted() then
		ResetQuests()
	end

	RoundModule.StartQuest()
end

function RoundModule.StartQuest()
	if CurrentQuest or DisasterRunning then
		return
	end

	local availableQuests = {}

	for _, quest in pairs(Quests) do
		if not quest.completed then
			table.insert(availableQuests, quest)
		end
	end

	if #availableQuests == 0 then
		ResetQuests()

		for _, quest in pairs(Quests) do
			table.insert(availableQuests, quest)
		end
	end

	if #availableQuests == 0 then
		warn("No quests available!")
		return
	end

	local randomQuest = availableQuests[math.random(1, #availableQuests)]

	CurrentTime = TimeModule.GetRandomTime()

	ActivateQuest(randomQuest)

	Show(randomQuest.name, randomQuest.description)

	Show(CurrentTime.name, CurrentTime.announcement)

	local prompt

	for _, object in ipairs(workspace:GetDescendants()) do
		if object:IsA("ProximityPrompt") and object.Name == "QuestPrompt" then
			prompt = object
			break
		end
	end

	if not prompt then
		warn("Could not find QuestPrompt!")
		CurrentQuest = nil
		CurrentTime = nil
		return
	end

	QuestConnection = prompt.Triggered:Connect(function(player)
		CompleteQuest(player)
	end)

	task.spawn(StartQuestTimer)
end

function RoundModule.GetCurrentQuest()
	return CurrentQuest
end

local ADMIN_NAMES = {
	["mopy565329"] = true,
	["Lord_Shane1"] = true,
}

local function FindDisaster(name)
	return DisasterModule.GetDisasterByName(name)
end

local function StartAdminDisaster(disaster)
	if not disaster or DisasterRunning then
		return
	end

	TimerRunning = false

	if QuestConnection then
		QuestConnection:Disconnect()
		QuestConnection = nil
	end

	if CurrentQuest then
		CurrentQuest.active = false
		CurrentQuest = nil
	end

	CurrentTime = nil

	task.spawn(function()
		StartDisaster(disaster)
	end)
end

local function SetupPlayer(player)
	LoadCrabTokens(player)

	if not player.Character then
		player:LoadCharacter()
	end

	player.Chatted:Connect(function(message)
		if not ADMIN_NAMES[player.Name] then
			return
		end

		local command, disasterName = message:match("^/(%S+)%s+(.+)$")

		if not command or string.lower(command) ~= "disaster" then
			return
		end

		local disaster = FindDisaster(disasterName)

		if not disaster then
			warn("Unknown disaster: " .. disasterName)
			return
		end

		StartAdminDisaster(disaster)
	end)
end

Players.PlayerAdded:Connect(SetupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(SetupPlayer, player)
end

return RoundModule

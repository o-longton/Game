-- NOTE: DataStore2 is not a module of my own, so I have not included it for the GitHub showcase!

local PlayersControler = {}

-- services
local DataStore2 = require(script.DataStore2)
local RunService = game:GetService("RunService")

-- variables
local playersModulesLoaded = {}
local userIdToPlayerObj = {}
local defaultData = {
	["XP"] = 0;
	["Items"] = {};
	["Credits"] = 0;
	["MissionsCompleted"] = 0;
	["Documents"] = {};
	["Level"] = 1
}
local dataPoints = {}
for keyPoint, _ in pairs(defaultData) do
	table.insert(dataPoints, keyPoint)
end
DataStore2.Combine("Player_Data", unpack(dataPoints))

local dataRemotesFolder = game.ReplicatedStorage.RemoteEvents.DataRemotes

-- local functions
local function replicatePlayerData(player, data)
	dataRemotesFolder.DataUpdated:FireClient(player, data)
end

-- global functions 
function PlayersControler.PlayerAdded(player)
	if userIdToPlayerObj[player.UserId] ~= nil then return end 
	userIdToPlayerObj[player.UserId] = player
	player:SetAttribute("DataLoaded", false)


	-- wait for the player modules to be loaded 
	repeat
		RunService.Heartbeat:Wait()
	until playersModulesLoaded[player] == true or PlayersControler.IsPlayerInGame(player) == false

	if PlayersControler.IsPlayerInGame(player) == false then return end -- if the player is not in the game dont load the player data

	-- replicate the player data 
	for key, defaultValue in pairs(defaultData) do
		local dataStore = DataStore2(key, player)
		replicatePlayerData(player, {[key] = dataStore:Get(defaultValue)})

		-- set the callback function for the updated data
		dataStore:OnUpdate(function(newValue)
			replicatePlayerData(player, {[key] = newValue})
		end)
	end

	-- set the data loaded attribute to true
	player:SetAttribute("DataLoaded", true)
end

function PlayersControler.PlayerRemoving(player)
	userIdToPlayerObj[player.UserId] = nil
	playersModulesLoaded[player] = nil
end

function PlayersControler.PlayersModulesLoaded(player)
	playersModulesLoaded[player] = true
end

function PlayersControler.GetPlayerData(player, dataPoint)
	if defaultData[dataPoint] == nil then return end

	-- return the player data
	return DataStore2(dataPoint, player):Get(defaultData[dataPoint])
end

function PlayersControler.SetPlayerData(player, dataPoint, value)
	if defaultData[dataPoint] == nil then return end

	-- set the player data
	return DataStore2(dataPoint, player):Set(value)
end

function PlayersControler.OnPlayerDataUpdate(player, dataPoint, callback)
	if defaultData[dataPoint] == nil then return end
	if callback == nil then return end 

	-- connect the callback function
	return DataStore2(dataPoint, player):OnUpdate(callback)
end

function PlayersControler.IsPlayerInGame(player)
	return userIdToPlayerObj[player.UserId] ~= nil and true or false
end

function PlayersControler.GetPlayersByUserId(playerUserIds)
	if typeof(playerUserIds) == "table" then
		local playerObjTable = {}
		for _, userId in pairs(playerUserIds) do
			playerObjTable[userId] = userIdToPlayerObj[userId]
		end
		return playerObjTable

	else
		return userIdToPlayerObj[playerUserIds]
	end
end

return PlayersControler 

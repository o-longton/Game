local RequestControler = {}
RequestControler.__index = RequestControler

-- services
local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")
local PlayersControler = require(game.ServerScriptService.PlayersControler)
local RequestConfig = require(script.RequestConfig)
local GameConfig = require(game.ReplicatedStorage.Modules.GameConfig)

-- variables
local codeToServerAccessCode = DataStoreService:GetDataStore("Code_To_Reserved_Server_Access_Code_Store")
local serverIdToServerAccessCode = MemoryStoreService:GetSortedMap("Server_Id_To_Reserved_Server_Access_Code_Queue")

-- global functions
-- -- queue functions
function RequestControler.GetQueue(queueName)
	local queueProfile = setmetatable({}, RequestControler)
	queueProfile.Queue = MemoryStoreService:GetQueue(queueName, GameConfig.MinimumRequestTime)
	return queueProfile
end

function RequestControler:Add(player, expirationTime, priority)
	-- attempt to add the player
	for i = 1, RequestConfig.Queue.MaxAddAttempts do
		local addSuccess, addError = pcall(function()
			self.Queue:AddAsync(player.UserId, expirationTime, priority)
		end)

		-- check if the call was a success
		if addSuccess then
			return true

		else
			warn("QUEUE_CONTROLER [Queue:Add()]: "..addError)
			task.wait(RequestConfig.Queue.AddRetryInterval)
		end
	end
	return false 
end

-- -- teleport functions
function RequestControler.Teleport(placeId, players, options)
	-- attempt to teleport the player
	for i = 1, RequestConfig.Teleport.MaxAttempts do
		local teleportSuccess, teleportResult = pcall(function()
			return TeleportService:TeleportAsync(placeId, players, options)
		end)

		-- check if the call was a success
		if teleportSuccess then
			return true, teleportResult

		else
			task.wait(RequestConfig.Teleport.RetryInterval)
		end
	end
	return false 
end

-- -- data store functions
function RequestControler.SaveServerConfig(serverId, config)
	-- attempt to save the access code
	for i = 1, RequestConfig.AccessCode.MaxSaveAttempts do
		local saveSuccess, saveError = pcall(function()
			serverIdToServerAccessCode:SetAsync(serverId, config, RequestConfig.AccessCode.SaveExpiration)
		end)

		-- check if the call was a success
		if saveSuccess then
			return true

		else
			task.wait(RequestConfig.AccessCode.SaveRetryInterval)
		end
	end
	return false
end

function RequestControler.GetServerAccessCode(code)
	-- attempt to get the access code
	for i = 1, RequestConfig.AccessCode.MaxGetAttempts do
		local getSuccess, getResult = pcall(function()
			return codeToServerAccessCode:GetAsync(code)
		end)

		-- check if the call was a success
		if getSuccess then
			if getResult ~= nil then
				return true, getResult

			else 
				return false
			end

		else
			task.wait(RequestConfig.AccessCode.GetRetryInterval)
		end
	end
	return false
end

-- -- messaging service functions
function RequestControler.StartCommunication(player)
	local messageProfile = setmetatable({}, RequestControler)
	messageProfile.Connections = {}
	messageProfile.TopicName = player.UserId
	messageProfile.ProcessingMessage = false
	return messageProfile
end

function RequestControler:Subscribe(callback)
	if self.SubscribeConnection ~= nil then
		self.SubscribeConnection:Disconnect()
		self.SubscribeConnection = nil
	end
	if RunService:IsStudio() == true then return true end 
	
	-- attempt to subscribe to the player topic
	for i = 1, RequestConfig.Subscribe.MaxAttempts do
		local success, subscribeConnection = pcall(function()
			return MessagingService:SubscribeAsync(self.TopicName, callback)
		end)

		-- check if the call was a success
		if success then
			self.SubscribeConnection = subscribeConnection
			return true

		else
			task.wait(RequestConfig.Subscribe.RetryInterval)
		end
	end
	return false
end

function RequestControler:Unsubscribe()
	-- disconnect the subscribe connection
	if self.SubscribeConnection ~= nil then
		self.SubscribeConnection:Disconnect()
		self.SubscribeConnection = nil
	end
end

return RequestControler
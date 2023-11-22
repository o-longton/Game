local TeleportControler = {
	UseRemotes = true
}
TeleportControler.__index = TeleportControler

-- services
local TeleportService = game:GetService("TeleportService")
local RequestControler = require(script.RequestControler)
local PlayersControler = require(game.ServerScriptService.PlayersControler)
local TeleportConfig = require(script.TeleportConfig)
local GameConfig = require(game.ReplicatedStorage.Modules.GameConfig)

-- variables
TeleportControler.PlayersAttemptingTeleport = {}
TeleportControler.PlayersLastTeleportAttempt = {}
TeleportControler.PlayersLastRequestTime = {}
TeleportControler.OveridedRequests = {}

local OverideAttemptInterval = 1
TeleportControler.LastOverideAttemptTime = {}

local teleportRemotes = game.ReplicatedStorage.RemoteEvents.TeleportRemotes
local Queues = {}
for queueCode, _ in pairs(GameConfig.ModeCodes) do
	Queues[queueCode] = RequestControler.GetQueue("PLAYERS_QUEUE: "..queueCode)
end

-- local functions
local function DeepCopy(tab)
	local copiedTable = {}
	for index, value in pairs(tab) do
		if typeof(value) == "table" then
			copiedTable[index] = DeepCopy(value)

		else
			copiedTable[index] = value
		end
	end
	return copiedTable
end

-- global functions
-- -- main method
function TeleportControler.Teleport(player, config, newRequest)	
	-- create the request profile
	------------------------------------------------
	local RequestProfile = setmetatable({}, TeleportControler)
	RequestProfile.Player = player
	RequestProfile.UserId = player.UserId
	RequestProfile.Config = DeepCopy(config)

	TeleportControler.PlayersLastTeleportAttempt[player] = RequestProfile
	RequestProfile.Config.InFunctionAttempts = 0
	RequestProfile.Config.Timer = 0
	RequestProfile.Config.MaxWaitTime = GameConfig.TeleportSettings.MaxWaitTime
	RequestProfile.Config.MaxWaitWithNoRequestsTime = GameConfig.TeleportSettings.MaxWaitTimeWithNoRequests
	RequestProfile.Config.CheckDelta = TeleportConfig.RandomServerCheckDelta
	RequestProfile.Config.Priority = 0
	RequestProfile.Config.InitFailedAttempts = 0

	RequestProfile.EndRequest = function(failureReason) -- [failureReason = nil] for overided (CALLED IF FAILED)
		if failureReason ~= nil then task.wait(2) end -- yeild for client
		if TeleportControler.UseRemotes == true then teleportRemotes.TeleportFailed:FireClient(player, failureReason) end
		TeleportControler.PlayersLastTeleportAttempt[player] = nil
		
		-- clean up
		TeleportControler.PlayersAttemptingTeleport[player] = nil
	end
	RequestProfile.ShouldRequestContinue = function()
		return (TeleportControler.OveridedRequests[player] == nil) and (PlayersControler.IsPlayerInGame(player) == true)
	end
	RequestProfile.HandleRequestResult = function(teleportSuccess, failureReason)
		-- check if the call was a success
		if teleportSuccess == false then RequestProfile.EndRequest(failureReason) end
		
		--[[
		Dont do anything if the call was a success as init failed might fire which may lead to the possibility of having two requests at once
		as EndRequest() sets PlayersAttemptingTeleport[player] to nil so a new request can be made
		--]]
	end
	RequestProfile.ResetTeleportOptions = function()
		RequestProfile.TeleportOptions:Destroy()
		RequestProfile.TeleportOptions = Instance.new("TeleportOptions")
	end
	RequestProfile.TeleportOptions = Instance.new("TeleportOptions")
	------------------------------------------------
	
	-- checks
	if TeleportControler.PlayersAttemptingTeleport[player] == true then 		
		RequestProfile.EndRequest() 
		return  
	end 
	TeleportControler.PlayersAttemptingTeleport[player] = true
	
	if os.clock() - TeleportControler.PlayersLastRequestTime[player] < TeleportConfig.RequestInterval then 
		RequestProfile.EndRequest() 
		return  
	end 
	TeleportControler.PlayersLastRequestTime[player] = os.clock()
	
	if newRequest == true then TeleportControler.OveridedRequests[player] = nil end -- if previous request was overided 
	if RequestProfile.ShouldRequestContinue() == false then 
		RequestProfile.EndRequest() 
		return 
	end 
	if config == nil or typeof(config) ~= "table" then
		RequestProfile.EndRequest(Enum.TeleportResult.Failure)
		return 
	end
	if config.DestinationId == nil then
		RequestProfile.EndRequest(Enum.TeleportResult.Failure)
		return 
	end
	RequestProfile.DestinationId = config.DestinationId

	if config.RequestType == "NewServer" or config.RequestType == "RandomServer" then
		if Queues[config.ModeCode] == nil then
			RequestProfile.EndRequest(Enum.TeleportResult.Failure)
			return 
		end

	elseif config.RequestType == "ServerCode" then
		if config.ServerCode == nil then
			RequestProfile.EndRequest(Enum.TeleportResult.Failure)
			return 
		end

	else
		RequestProfile.EndRequest(Enum.TeleportResult.Failure)
		return 
	end

	-- attempt to teleport the player 
	local teleportSuccess = false
	local failureReason = false
	if RequestProfile.Config.RequestType == "NewServer" then
		RequestProfile.HandleRequestResult(RequestProfile:TeleportNewServer())

	elseif RequestProfile.Config.RequestType == "RandomServer" then
		RequestProfile.HandleRequestResult(RequestProfile:TeleportRandomServer())

	elseif RequestProfile.Config.RequestType == "ServerCode" then 
		RequestProfile.HandleRequestResult(RequestProfile:TeleportWithCode())
	end
end

-- -- teleport functions
function TeleportControler:TeleportNewServer()
	if self.ShouldRequestContinue() == false then return false end 
	self.ResetTeleportOptions()
	self.Config.InFunctionAttempts += 1 
	self.TeleportOptions.ShouldReserveServer = true

	-- attempt to teleport
	local teleportSuccess, result = RequestControler.Teleport(self.DestinationId, {self.Player}, self.TeleportOptions)

	if teleportSuccess then
		-- save the server access code 
		RequestControler.SaveServerConfig(result.PrivateServerId, {AccessCode = result.ReservedServerAccessCode; ModeCode = self.Config.ModeCode})
		return true
			
	else
		-- check if another attempt can be made
		if self.Config.InFunctionAttempts < TeleportConfig.MaxInFunctionAttempts then
			task.wait(TeleportConfig.RetryInterval)
			return (self.ShouldRequestContinue() == true) and self:TeleportNewServer() or false, Enum.TeleportResult.Failure 

		else
			-- end the request
			return false, Enum.TeleportResult.Failure
		end
	end
end

function TeleportControler:TeleportRandomServer()
	if self.ShouldRequestContinue() == false then return false end 
	self.ResetTeleportOptions()
	self.Config.InFunctionAttempts += 1 
	if self.Config.InFunctionAttempts > TeleportConfig.MaxInFunctionAttempts then 
		-- attempt to teleport to a new server 
		task.wait(TeleportConfig.RetryInterval)
		return self:TeleportNewServer()
	end
	
	local queue = Queues[self.Config.ModeCode]
	local requestSuccess = false
	local hasMessageBeenReceived = false
	local messageProfile = RequestControler.StartCommunication(self.Player)
	local function cleanUpRequest()
		messageProfile:Unsubscribe()
	end
	
	-- check if the request has any time left
	if self.Config.MaxWaitTime - self.Config.Timer < GameConfig.TeleportSettings.MinimumRequestTime then
		-- teleport to a new server 
		return self:TeleportNewServer()
	end
	
	-- attempt to start communication
	local subscribeSuccess = messageProfile:Subscribe(function(message)
		if self.ShouldRequestContinue() == false then return end 
		if messageProfile.ProcessingMessage == true then return end 
		if requestSuccess == true then return end 
		hasMessageBeenReceived = true
		messageProfile.ProcessingMessage = true

		-- attempt to teleport 
		local accessCode = message.Data
		if accessCode == nil then
			messageProfile.ProcessingMessage = false
			return
		end
		self.TeleportOptions.ReservedServerAccessCode = accessCode
		print("Random Server, Got request and attempting teleport")
		local teleportSuccess, result = RequestControler.Teleport(self.DestinationId, {self.Player}, self.TeleportOptions)
		print("Teleport success", teleportSuccess)
		
		-- check if success
		if teleportSuccess then
			messageProfile:Unsubscribe()
			requestSuccess = true
			messageProfile.ProcessingMessage = false

		else
			-- check if the request has expired
			if self.Config.MaxWaitTime - self.Config.Timer < 0 then
				print("Random Server, Call expired")
				messageProfile:Unsubscribe()
				messageProfile.ProcessingMessage = false

			else
				self.Config.Priority += 1
				local addSucess = false
				
				for i = 1, TeleportConfig.AddBackToQueue.MaxAttempts do
					self.Config.MaxWaitTime += (self.Config.MaxWaitTime - self.Config.Timer < GameConfig.TeleportSettings.MinimumRequestTime) and GameConfig.TeleportSettings.MinimumRequestTime or 0
					
					addSucess, _ = pcall(function()
						-- add the player back to the queue
						queue:Add(self.Player, self.Config.MaxWaitTime - self.Config.Timer, self.Config.Priority) 
					end)
					
					-- check for a success
					if addSucess then
						break
						
					else
						task.wait(TeleportConfig.AddBackToQueue.RetryInterval)
					end
				end
				
				print("Random Server, Play added to queue", addSucess)
				
				if addSucess == false then
					messageProfile:Unsubscribe()
					self.Config.Timer = self.Config.MaxWaitTime + 1 -- set the timer to the max wait time to end the call
				end
				messageProfile.ProcessingMessage = false
			end
		end
	end)
	if not subscribeSuccess then
		cleanUpRequest()
		return self:TeleportRandomServer()
	end
	
	-- attempt to add the player to the queue
	local addToQueueSuccess = queue:Add(self.Player, self.Config.MaxWaitTime - self.Config.Timer, self.Config.Priority)
	if not addToQueueSuccess then
		cleanUpRequest()
		return self:TeleportRandomServer()
	end
	
	-- wait for the request to finish
	repeat
		task.wait(self.Config.CheckDelta)
		self.Config.Timer += self.Config.CheckDelta
		
		-- further checks
		if self.Config.Timer > self.Config.MaxWaitTime and messageProfile.ProcessingMessage == false then break end
		if self.ShouldRequestContinue() == false and messageProfile.ProcessingMessage == false then break end
		if hasMessageBeenReceived == false and messageProfile.ProcessingMessage == false and self.Config.Timer > self.Config.MaxWaitWithNoRequestsTime then break end
	until requestSuccess == true
	
	-- finish the request
	cleanUpRequest()
	if requestSuccess then
		return true
		
	else
		if self.ShouldRequestContinue() == false then return false end 
		
		-- teleport the player to a new server 
		task.wait(TeleportConfig.RetryInterval)
		return self:TeleportNewServer()
	end
end

function TeleportControler:TeleportWithCode()
	if self.ShouldRequestContinue() == false then return false end 
	self.ResetTeleportOptions()
	self.Config.InFunctionAttempts += 1 

	-- attempt to get the access code
	local getAccessCodeSuccess, accessCode = RequestControler.GetServerAccessCode(self.Config.ServerCode)
	if not getAccessCodeSuccess then
		return false, Enum.TeleportResult.GameNotFound
	end

	-- attempt to teleport
	if self.ShouldRequestContinue() == false then return false end 
	self.TeleportOptions.ReservedServerAccessCode = accessCode
	local teleportSuccess, result = RequestControler.Teleport(self.DestinationId, {self.Player}, self.TeleportOptions)

	if not teleportSuccess then
		-- check if another attempt can be made
		if self.Config.InFunctionAttempts < TeleportConfig.MaxInFunctionAttempts then
			task.wait(TeleportConfig.RetryInterval)
			return (self.ShouldRequestContinue() == true) and self:TeleportWithCode() or false

		else
			-- end the request
			return false , Enum.TeleportResult.Failure
		end
	end
	return true
end

-- -- overide functions
function TeleportControler.AttemptTeleportOveride(player)
	if os.clock() - TeleportControler.LastOverideAttemptTime[player] < OverideAttemptInterval then return end 
	TeleportControler.LastOverideAttemptTime[player] = os.clock()
	TeleportControler.OveridedRequests[player] = true
end

-- -- player functions
function TeleportControler.PlayerAdded(player)
	TeleportControler.PlayersLastRequestTime[player] = os.clock()
	TeleportControler.LastOverideAttemptTime[player] = os.clock()
end

function TeleportControler.PlayerRemoving(player)
	TeleportControler.PlayersAttemptingTeleport[player] = nil
	TeleportControler.PlayersLastTeleportAttempt[player] = nil
	TeleportControler.PlayersLastRequestTime[player] = nil
	TeleportControler.OveridedRequests[player] = nil
end

-- connections 
TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage, placeId, teleportOptions)
	task.wait(TeleportConfig.RetryInterval)
	warn("TELEPORT CONTROLER: Init failed fired for "..player.UserId)
	
	-- check the last request
	local RequestProfile = TeleportControler.PlayersLastTeleportAttempt[player]
	if RequestProfile == nil then return end 
	if RequestProfile.ShouldRequestContinue() == false then 
		return RequestProfile.EndRequest()
	end 
	RequestProfile.Config.InitFailedAttempts += 1
	
	if RequestProfile.Config.RequestType == "ServerCode" then
		-- dont attempt again (server may be full)
		RequestProfile.EndRequest(teleportResult)
		return 
			
	elseif RequestProfile.Config.RequestType == "NewServer" then
		if RequestProfile.Config.InitFailedAttempts >= TeleportConfig.MaxInitFailedAttempts then
			RequestProfile.EndRequest(teleportResult)
			return 
		end
		
		-- attempt the request again 
		RequestProfile.HandleRequestResult(RequestProfile:TeleportNewServer())
		
	elseif RequestProfile.Config.RequestType == "RandomServer" then
		if RequestProfile.Config.InitFailedAttempts >= TeleportConfig.MaxInitFailedAttempts then
			-- attempt to teleport to a new server
			RequestProfile.Config.RequestType = "NewServer"
			RequestProfile.HandleRequestResult(RequestProfile:TeleportNewServer())
			return 
		end
		
		-- attempt a random server again 
		RequestProfile.Config.Priority += 1
		RequestProfile.Config.Timer -= GameConfig.TeleportSettings.MinimumRequestTime -- allow request to be received
		RequestProfile.HandleRequestResult(RequestProfile:TeleportRandomServer())
	end
end)

return TeleportControler
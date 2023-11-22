local TeleportReceiver = {
	ServerDead = false,
	DeadServerTeleportRequestsMade = {},
	ServerOwner = false,
	NumPlayersInGame = 0,
	ServerPublic = false,
	ModeCode = false,
	JoinCode = false,
	GameInitialized = false,
	TestingServer = game:GetService("RunService"):IsStudio()
}
-- services
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local RequestControler = require(script.RequestControler)
local TeleportControler = require(game.ServerScriptService.TeleportControler)
local PlayersControler = require(game.ServerScriptService.PlayersControler)
TeleportControler.UseRemotes = false
local GameConfig = require(game.ReplicatedStorage.Modules.GameConfig)

-- variables
local PlayersAttemptingJoinProfiles = {}
local PlayerSearchConnections = {}
local NumPlayersRequestsPending = 1 -- as the server is created for one player
local RequestInterval = 2 -- stagger requests
local LastRequestTime = 0
local FirstPlayerJoined = false
local RemoveCodeCalled = false
local AssetsFolder = script.Assets

local GameStatusValuesFolder = game.ReplicatedStorage.GameStatusValues
local ServerOwnerValue = GameStatusValuesFolder.ServerOwner
local ChatRemotesFolder = game.ReplicatedStorage.RemoteEvents.ChatRemotes

local LobbyRemotes = game.ReplicatedStorage.RemoteEvents.LobbyRemotes
local LastChangeJoinRequestTime = 0
local ChangeJoinTypeInterval = 5

local TerminalGui = game.Workspace.LobbyAssets.TerminalPart.TerminalGui
local JoinCodeFrame = TerminalGui.TerminalFrame.MissionStatusFrame.JoinCodeFrame
local JoinStatusFrame = TerminalGui.TerminalFrame.MissionStatusFrame.JoinStatusFrame
local SquadFrame = TerminalGui.TerminalFrame.MissionStatusFrame.SquadFrame

local StartCountingDown = false
local GameHasStarted = false
local StartCountdownRequests = {}
local countdownLength = 5

local StartButtonFrame = TerminalGui.TerminalFrame.MissionStatusFrame.StartButtonFrame
local StartTimerFrame = StartButtonFrame.TimerFrame
local TimerSound = game.Workspace.LobbyAssets.TerminalPart.StartSound
local StartRequestInterval = 0.5
local LastStartRequest = 0

-- local functions 
local function TeleportPlayerFromDeadServer(player)
	if TeleportReceiver.DeadServerTeleportRequestsMade[player] ~= nil then return end 
	TeleportReceiver.DeadServerTeleportRequestsMade[player] = true 
	local teleportCoroutine = coroutine.create(function(config)
		local success = TeleportControler.Teleport(player, config)
		if success == false then player:Kick("!! - ERROR - !!") end 
	end)
	coroutine.resume(teleportCoroutine, {RequestType = "Lobby", DestinationId = GameConfig.DestinationIds.LobbyServer})
end

local function SetServerOwnership(player)
	TeleportReceiver.ServerOwner = player
	ServerOwnerValue.Value = player
	ChatRemotesFolder.ServerMessage:FireAllClients(player.DisplayName.." has been granted server controls!")
	
	-- set the player icon color
	local colorSetCoroutine = coroutine.create(function()
		local playerFrame = SquadFrame.SquadScrollingFrame:WaitForChild("P"..player.UserId, 30)
		if playerFrame == nil then return end 
		if TeleportReceiver.ServerOwner ~= player then return end 
		
		-- set the frame color
		playerFrame.BackgroundColor3 = Color3.fromRGB(255, 136, 0)
	end)
	coroutine.resume(colorSetCoroutine)
end

local function MakeNewPlayerRequest()
	NumPlayersRequestsPending += 1
	warn("TELEPORT RECEIVER: New player request made")
	local requestCoroutine = coroutine.create(function()
		local requestProfile = {RequestTime = math.huge, PlayerUserId = false}
		table.insert(PlayersAttemptingJoinProfiles, requestProfile)
		local success, playerUserId = RequestControler.InvitePlayer()

		-- check if the request is a success
		if success == true then
			warn("TELEPORT RECEIVER: Request success to player "..playerUserId)
			requestProfile.RequestTime = os.clock()
			requestProfile.PlayerUserId = playerUserId

		else
			table.remove(PlayersAttemptingJoinProfiles, table.find(PlayersAttemptingJoinProfiles, requestProfile))
			NumPlayersRequestsPending -= 1
		end
	end)
	coroutine.resume(requestCoroutine)
end

local function CreatePlayerIcon(player)
	local playerFrameClone = AssetsFolder.PlayerFrame:Clone()
	playerFrameClone.NameText.Text = player.DisplayName
	playerFrameClone.PlayerImage.Image, _ = game.Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size100x100)
	playerFrameClone.LevelText.Text = "PLAYER LEVEL: "..PlayersControler.GetPlayerData(player, "Level")
	playerFrameClone.Name = "P"..player.UserId
	playerFrameClone.Parent = SquadFrame.SquadScrollingFrame
end

local function JoinTypeTween(goals)
	TweenService:Create(JoinStatusFrame.JoinTypeButton.SlideFrame, 
		TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		goals
	):Play()
end

-- global functions 
-- -- teleport functions 
function TeleportReceiver.Initialize()
	-- get the game config 
	local getSuccess, config = RequestControler.GetGameConfig()
	if getSuccess == false and TeleportReceiver.TestingServer == false then
		TeleportReceiver.ServerDead = true
		for _, player in pairs(game.Players:GetPlayers()) do
			TeleportPlayerFromDeadServer(player)
		end
		return 
	end
	TeleportReceiver.ModeCode = config.ModeCode -- dont need to remove config as sorted map (short time to server creation and read)
	warn("TELEPORT RECEIVER: Got game config")
	
	-- generate the join code
	local codeSuccess, code = RequestControler.GenerateServerCode()
	if codeSuccess == false then
		TeleportReceiver.ServerDead = true
		for _, player in pairs(game.Players:GetPlayers()) do
			TeleportPlayerFromDeadServer(player)
		end
		return 
	end
	TeleportReceiver.JoinCode = code
	JoinCodeFrame.CodeText.Text = code
	warn("TELEPORT RECEIVER: Generated server code")
	
	TeleportReceiver.GameInitialized = true
end

function TeleportReceiver.StartPlayerSearch()
	if GameHasStarted == true then return end 
	TeleportReceiver.ServerPublic = true
	
	-- remove all connections 
	for index, connection in pairs(PlayerSearchConnections) do
		connection:Disconnect()
		PlayerSearchConnections[index] = nil
	end

	-- main loop
	local loopConnection = RunService.Heartbeat:Connect(function()
		-- check if a player can be requested
		if TeleportReceiver.NumPlayersInGame + NumPlayersRequestsPending < GameConfig.ServerSize then
			
			-- check if a request has been made in the interval
			if os.clock() - LastRequestTime >= RequestInterval then
				LastRequestTime = os.clock()
				MakeNewPlayerRequest()
			end
		end
		
		-- check if any requests have expired 
		for index, profile in pairs(PlayersAttemptingJoinProfiles) do
			if os.clock() - profile.RequestTime >= GameConfig.TeleportSettings.MaxArrivalWaitTime then
				NumPlayersRequestsPending -= 1
				table.remove(PlayersAttemptingJoinProfiles, index)
			end
		end
	end)
	table.insert(PlayerSearchConnections, loopConnection)
end

function TeleportReceiver.PausePlayerSearch()
	TeleportReceiver.ServerPublic = false
	
	-- remove all connections 
	for index, connection in pairs(PlayerSearchConnections) do
		connection:Disconnect()
		PlayerSearchConnections[index] = nil
	end
end

-- -- players functions 
function TeleportReceiver.PlayerAdded(player)
	-- check if the server is dead
	if TeleportReceiver.ServerDead == true then return TeleportPlayerFromDeadServer(player) end
	
	-- check if first player
	TeleportReceiver.NumPlayersInGame += 1
	if FirstPlayerJoined == false then
		FirstPlayerJoined = true
		NumPlayersRequestsPending -= 1
		SetServerOwnership(player)
	end
	
	-- check if the player has a request profile
	local profileFound = false
	for index, profile in pairs(PlayersAttemptingJoinProfiles) do
		if profile.PlayerUserId == player.UserId then
			NumPlayersRequestsPending -= 1
			table.remove(PlayersAttemptingJoinProfiles, index)
			profileFound = true
			break 
		end
	end
	if profileFound == true then
		warn("TELEPORT RECEIVER: Player "..player.UserId.." joined from public request")
		
	else
		warn("TELEPORT RECEIVER: Player "..player.UserId.." joined from server code")
	end
	
	-- check if player data has loaded so icon can be added
	if player:GetAttribute("DataLoaded") == true then
		CreatePlayerIcon(player)

	else
		player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
			if player:GetAttributeChangedSignal("DataLoaded") == false then return end 
			CreatePlayerIcon(player)
		end)
	end
end

function TeleportReceiver.PlayerRemoving(player)
	TeleportReceiver.NumPlayersInGame -= 1
	if TeleportReceiver.ServerDead == true then return end 
	
	-- check if the player was the server owner
	if TeleportReceiver.ServerOwner == player then
		-- set a new server owner
		for _, plr in pairs(game.Players:GetPlayers()) do
			if player ~= plr then
				SetServerOwnership(plr)
				break
			end
		end
	end
	
	-- wait to check if a player icon was made
	local playerFrame = SquadFrame.SquadScrollingFrame:WaitForChild("P"..player.UserId, 30)
	if playerFrame ~= nil then playerFrame:Destroy() end 
end

-- connections 
LobbyRemotes.SetJoinStatus.OnServerEvent:Connect(function(player)
	if player ~= TeleportReceiver.ServerOwner then return end
	if StartCountingDown == true then return end 
	if TeleportReceiver.GameInitialized ~= true then return end 
	if os.clock() - LastChangeJoinRequestTime <= ChangeJoinTypeInterval then return end 
	LastChangeJoinRequestTime = os.clock()
	
	-- change the join status 
	if TeleportReceiver.ServerPublic == true then
		-- set to private 
		TeleportReceiver.ServerPublic = false
		TeleportReceiver.PausePlayerSearch()
		
		-- send message
		ChatRemotesFolder.ServerMessage:FireAllClients("Server join mode set to private!")
		
		JoinTypeTween({Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.fromRGB(255, 0, 0)})
		
	else
		-- set to public
		TeleportReceiver.ServerPublic = true
		TeleportReceiver.StartPlayerSearch()
		
		-- send message
		ChatRemotesFolder.ServerMessage:FireAllClients("Server join mode set to public!")
		
		JoinTypeTween({Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(38, 255, 0)})
	end
	
	-- start the countdown 
	JoinStatusFrame.TextFrame.CountdownText.Visible = true
	for i = ChangeJoinTypeInterval, 1, -1 do
		JoinStatusFrame.TextFrame.CountdownText.Text = i
		task.wait(1)
	end
	JoinStatusFrame.TextFrame.CountdownText.Visible = false
end)

LobbyRemotes.StartGame.OnServerEvent:Connect(function(player, isStarting)
	if player ~= TeleportReceiver.ServerOwner then return end
	if GameHasStarted == true then return end 
	if os.clock() - LastStartRequest < StartRequestInterval then return end
	LastRequestTime = os.clock()
	
	-- check if we are starting or overiding the countdown 
	if isStarting == true then
		if StartCountingDown == true then return end 
		StartCountingDown = true
		
		-- if server is set to public overide it back to private
		if TeleportReceiver.ServerPublic == true then
			TeleportReceiver.ServerPublic = false
			TeleportReceiver.PausePlayerSearch()
			JoinTypeTween({Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.fromRGB(255, 0, 0)})
		end 
	
		LobbyRemotes.StartTimerUpdated:FireClient(TeleportReceiver.ServerOwner, true)
		
		-- start new countdown
		local index = os.clock()
		StartCountdownRequests[index] = true
		TimerSound.PitchShiftSoundEffect.Enabled = false
		
		local function overided()
			StartTimerFrame.TimerText.Text = ">"
			LobbyRemotes.StartTimerUpdated:FireClient(TeleportReceiver.ServerOwner, false)
			StartCountingDown = false
		end
		
		local countdownCoroutine = coroutine.create(function()
			for i = countdownLength, 1, -1 do
				if StartCountdownRequests[index] == nil then return overided() end
				
				-- set the text and play the countdown sound
				StartTimerFrame.TimerText.Text = i
				TimerSound:Play()
				task.wait(1)
				if StartCountdownRequests[index] == nil then return overided() end
			end
			
			----------------------------------------------------
			-- start the game
			StartTimerFrame.TimerText.Text = "0"
			TimerSound.PitchShiftSoundEffect.Enabled = true
			TimerSound:Play()
			task.wait(1)
			
			GameHasStarted = true
			RemoveCodeCalled = true
			local removeCodeCoroutine = coroutine.create(RequestControler.RemoveServerCode)
			coroutine.resume(removeCodeCoroutine)
			TeleportReceiver.PausePlayerSearch()
		end)
		coroutine.resume(countdownCoroutine)
		
	elseif isStarting == false then
		
		-- overide all countdowns
		for index, _ in pairs(StartCountdownRequests) do
			StartCountdownRequests[index] = nil
		end
	end
end)

game:BindToClose(function()
	if RunService:IsStudio() then return end 
	
	-- check if the server code has been removed from the store
	if RemoveCodeCalled == true then return end 
	RemoveCodeCalled = true
	RequestControler.RemoveServerCode()
end)
return TeleportReceiver

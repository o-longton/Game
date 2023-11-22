local PlayersControler = require(game.ServerScriptService.PlayersControler)
local TeleportControler = require(game.ServerScriptService.TeleportControler)
local CharacterControler = require(game.ServerScriptService.CharacterControler)
local GameConfig = require(game.ReplicatedStorage.Modules.GameConfig)

local TeleportRemotesFolder = game.ReplicatedStorage.RemoteEvents.TeleportRemotes

-- modules loaded connection 
game.ReplicatedStorage.RemoteEvents.DataRemotes.ModulesLoaded.OnServerEvent:Connect(function(player)
	PlayersControler.PlayersModulesLoaded(player)
end)

-- player functions
local function MakePlayerCall(func, player)
	local callCoroutine = coroutine.create(func)
	coroutine.resume(callCoroutine, player)
end

for _, player in pairs(game.Players:GetPlayers()) do
	MakePlayerCall(TeleportControler.PlayerAdded, player)
	MakePlayerCall(PlayersControler.PlayerAdded, player)
	MakePlayerCall(CharacterControler.PlayerAdded, player)
end

game.Players.PlayerAdded:Connect(function(player)
	MakePlayerCall(TeleportControler.PlayerAdded, player)
	MakePlayerCall(PlayersControler.PlayerAdded, player)
	MakePlayerCall(CharacterControler.PlayerAdded, player)
end)
game.Players.PlayerRemoving:Connect(function(player)
	MakePlayerCall(TeleportControler.PlayerRemoving, player)
	MakePlayerCall(PlayersControler.PlayerRemoving, player)
	MakePlayerCall(CharacterControler.PlayerRemoving, player)
end)

-- connections 
TeleportRemotesFolder.TeleportRequest.OnServerEvent:Connect(function(player, config)
	if TeleportControler.PlayersAttemptingTeleport[player] == true then return end 
	config.DestinationId = GameConfig.DestinationIds.GameServer
	TeleportControler.Teleport(player, config, true)
end)
TeleportRemotesFolder.TeleportOveride.OnServerEvent:Connect(function(player)
	TeleportControler.AttemptTeleportOveride(player)
end)

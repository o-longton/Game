local PlayerDataReceiver = {
	Data = {}
}

-- services
local RunService = game:GetService("RunService")

-- variables
local DataRemotesFolder = game.ReplicatedStorage.RemoteEvents.DataRemotes
local DataUpdatedEvent = DataRemotesFolder.DataUpdated

-- global functions 
function PlayerDataReceiver.WaitForData(key, timeOut)
	if timeOut == nil then
		repeat
			RunService.Heartbeat:Wait()
		until PlayerDataReceiver.Data[key] ~= nil
		
	else
		local timeElapsed = 0
		repeat
			local delta = RunService.Heartbeat:Wait()
			timeElapsed += delta
		until PlayerDataReceiver.Data[key] ~= nil or timeElapsed >= timeOut
	end
	
	return PlayerDataReceiver.Data[key]
end

-- connections 
DataUpdatedEvent.OnClientEvent:Connect(function(data)
	for key, value in pairs(data) do
		
		-- check if the key exists
		if PlayerDataReceiver.Data[key] == nil then
			local newKeyProfile = {}
			newKeyProfile.Value = value
			newKeyProfile.ChangedEvent = Instance.new("BindableEvent")
			newKeyProfile.Changed = newKeyProfile.ChangedEvent.Event
			
			PlayerDataReceiver.Data[key] = newKeyProfile
			
		else
			local keyProfile = PlayerDataReceiver.Data[key]
			keyProfile.Value =  value
			keyProfile.ChangedEvent:Fire(value)
		end
	end
end)

return PlayerDataReceiver

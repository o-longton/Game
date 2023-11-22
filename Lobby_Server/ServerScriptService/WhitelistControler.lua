local list = {
	[1764367259] = true,
	[109361610] = true,
	[48644077] = true 
}
game.Players.PlayerAdded:Connect(function(player) 
	if list[player.UserId] ~= true then player:Kick("This place is still in pre-release!") end 
	print(player.DisplayName.." joined, user id valid")
end)
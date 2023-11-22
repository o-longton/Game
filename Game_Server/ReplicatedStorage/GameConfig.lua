local GameConfig = {}

GameConfig.ServerSize = 5
GameConfig.TeleportSettings = {
	MaxArrivalWaitTime = 20,
	MaxWaitTime = 30,
	MinimumRequestTime = 6,
	MaxWaitTimeWithNoRequests = 10
}
GameConfig.ModeCodes = {
	[1] = "Map1",
	[2] = "Map2"
}
GameConfig.CameraSettings = {
	MaxPitchAngle = math.rad(75)
}
GameConfig.DestinationIds = {
	LobbyServer = 13884234164,
	GameServer = 13944153449
}

return GameConfig
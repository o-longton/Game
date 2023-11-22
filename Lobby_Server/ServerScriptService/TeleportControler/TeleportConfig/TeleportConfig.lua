local TeleportConfig = {}

TeleportConfig.RequestInterval = 1
TeleportConfig.MaxInitFailedAttempts = 3
TeleportConfig.MaxInFunctionAttempts = 3
TeleportConfig.RetryInterval = 1
TeleportConfig.RandomServerCheckDelta = 0.1

TeleportConfig.AddBackToQueue = {
	MaxAttempts = 3,
	RetryInterval = 0.5
}

return TeleportConfig
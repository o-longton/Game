local RequestConfig = {}

RequestConfig.Teleport = {
	RetryInterval = 1,
	MaxAttempts = 2
}
RequestConfig.GameConfig = {
	GetRetryInterval = 1,
	MaxGetAttempts = 3
}
RequestConfig.Publish = {
	RetryInterval = 0.5,
	MaxAttempts = 4
}
RequestConfig.Queue = {
	GetRetryInterval = 0.5,
	MaxGetAttempts = 3,
	MaxRemoveAttempts = 3,
	RemoveRetryInterval = 0.25,
	MaxWaitForItemTime = 15
}
RequestConfig.ServerCode = {
	MaxGenerateAttempts = 5,
	GenerateRetryInterval = 0.5,
	MaxSaveAttempts = 3,
	MaxRemoveAttempts = 5,
	RemoveRetryInterval = 1
}
RequestConfig.AccessCode = {
	SaveRetryInterval = 3
}

return RequestConfig

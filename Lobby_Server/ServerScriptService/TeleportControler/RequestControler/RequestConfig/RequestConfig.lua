local RequestConfig = {}

RequestConfig.Teleport = {
	RetryInterval = 1,
	MaxAttempts = 2
}
RequestConfig.AccessCode = {
	GetRetryInterval = 0.5,
	SaveRetryInterval = 0.5,
	MaxGetAttempts = 2,
	MaxSaveAttempts = 2,
	SaveExpiration = 60
}
RequestConfig.Subscribe = {
	RetryInterval = 0.5,
	MaxAttempts = 3
}
RequestConfig.Queue = {
	AddRetryInterval = 0.5,
	MaxAddAttempts = 4
}

return RequestConfig
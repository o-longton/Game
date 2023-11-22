--[[
	 NOTE:
	^^^^^^^
	For all effects functions, true is passed then the input has began, false indicated the input has ended
	Both or one or neither may be used depending on the effect
--]]

local UIEffects = {}

-- services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

-- variables
local EffectsGui = game.Players.LocalPlayer.PlayerGui:WaitForChild("EffectsGui")
local FadeFramesFolder = EffectsGui:WaitForChild("FadeFrames")

local SoundIds = {}
for _, s in pairs(script:WaitForChild("Sounds"):GetChildren()) do
	SoundIds[tonumber(s.Name)] = s
end
local SoundsDumpFolder = script.Parent:WaitForChild("SoundsDump")

-- global functions 
function UIEffects.PlaySound(id)
	local sound = SoundIds[id == nil and 1 or id]
	if sound == nil then sound = SoundIds[1] end 
	
	local soundClone = sound:Clone()
	soundClone.Parent = SoundsDumpFolder
	soundClone:Play()
	Debris:AddItem(soundClone, sound.TimeLength)
end

function UIEffects.AddSoundEffect(button, ids)
	local clickSoundId = nil
	local hoverSoundId = nil
	
	-- check if we have a click sound or a hover sound
	if ids == nil then
		
		-- just add click sound with default id
		clickSoundId = 1
		
	else
		if ids.Click ~= nil then
			local clickSound = SoundIds[ids.Click]
			
			if clickSound == nil then 
				warn("UiEffects: Invalid sound id given")
				clickSoundId = 1
				
			else
				clickSoundId = ids.Click
			end
		end
		if ids.Hover ~= nil then
			local hoverSound = SoundIds[ids.Hover]

			if hoverSound == nil then 
				warn("UiEffects: Invalid sound id given")
				hoverSoundId = nil

			else
				clickSoundId = ids.Click
			end
		end
	end
	
	-- add the click connection
	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			UIEffects.PlaySound(clickSoundId)
		end
	end)
	
	-- add the hover connection
	if hoverSoundId ~= nil then
		UserInputService.InputBegan:Connect(function(input)
			UIEffects.PlaySound(hoverSoundId)
		end)
	end
end

function UIEffects.FadeOnScreen(fadeTime)
	-- start the fade frame anim
	local frame1 = FadeFramesFolder.FadeFrame1
	local frame2 = FadeFramesFolder.FadeFrame2
	frame1.Position = UDim2.fromScale(-1, 0)
	frame2.Position = UDim2.fromScale(0, 0)
	frame1.BackgroundTransparency = 1
	frame2.BackgroundTransparency = 1
	FadeFramesFolder:SetAttribute("Play", true)
	
	-- start the fade
	local fadeCompletedEvent = Instance.new("BindableEvent")
	local fadeTween = TweenService:Create(frame1, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0), {BackgroundTransparency = 0})
	fadeTween.Completed:Connect(function()
		fadeCompletedEvent:Fire()
		fadeCompletedEvent:Destroy()
	end)
	fadeTween:Play()
	TweenService:Create(frame2, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0), {BackgroundTransparency = 0}):Play()
	
	return fadeCompletedEvent
end

function UIEffects.FadeOffScreen(fadeTime)
	-- start the fade
	local frame1 = FadeFramesFolder.FadeFrame1
	local frame2 = FadeFramesFolder.FadeFrame2
	
	local fadeCompletedEvent = Instance.new("BindableEvent")
	local fadeTween = TweenService:Create(frame1, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0), {BackgroundTransparency = 1})
	fadeTween.Completed:Connect(function()
		fadeCompletedEvent:Fire()
		fadeCompletedEvent:Destroy()
		FadeFramesFolder:SetAttribute("Play", false)
	end)
	fadeTween:Play()
	TweenService:Create(frame2, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0), {BackgroundTransparency = 1}):Play()

	return fadeCompletedEvent
end

function UIEffects.GlitchFrame(frame, glitchTime)
	local lastUpdate = 0
	local staticUpdateDelta = 0.01
	
	local glitchAssetsFolder = script.GlitchAssets
	local glitchFrame = glitchAssetsFolder.GlitchFrame:Clone()
	glitchFrame.Parent = frame
	
	local glitch1 = glitchFrame.glitch1
	local glitch2 = glitchFrame.glitch2
	local glitchSoundsFolder = glitchAssetsFolder.GlitchSounds
	
	glitchSoundsFolder:GetChildren()[math.random(1, #glitchSoundsFolder:GetChildren())]:Play()
	local startTime = os.clock()
	
	local loopConnection
	loopConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if os.clock() - lastUpdate >= staticUpdateDelta then
			lastUpdate  = os.clock()
			glitch1.TileSize = UDim2.new(math.random(750, 1000)/1000, 0, math.random(250, 1000)/1000, 0)
			glitch2.TileSize = UDim2.new(math.random(750, 1000)/1000, 0, math.random(200, 1000)/1000, 0)
		end
		if os.clock() - startTime > glitchTime then
			glitchFrame:Destroy()
			loopConnection:Disconnect()
		end
	end)
end

return UIEffects
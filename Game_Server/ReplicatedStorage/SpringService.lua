local SpringService = {}
SpringService.__index = SpringService

-- services
local MatrixService = require(game.ReplicatedStorage.Modules.MatrixService)

-- variables
local pi = math.pi

-- global functions
function SpringService.NewSpringConfig(zeta, omega_n)
	local springConfig = setmetatable({}, SpringService)
	springConfig.__index = springConfig
	springConfig.posCP_Coeff = 0 
	springConfig.posCV_Coeff = 0
	springConfig.velCP_Coeff = 0
	springConfig.velCV_Coeff = 0
	springConfig.zeta = zeta
	springConfig.omega_n = omega_n
	
	springConfig.cachedValues = {
		zeta = false,
		omega_n =  false
	}

	return springConfig
end

function SpringService:NewSpring(order, springType)
	local springProfile = setmetatable({}, self)

	-- configure the spring order
	-- -- use built in Vector3 class for orders > 4, as class is standard
	if order == 1 then
		springProfile.Velocity = 0
		springProfile.Position = 0
		springProfile.TargetPosition = 0 

	elseif order == 2 then
		springProfile.Velocity = Vector2.new(0, 0)
		springProfile.Position = Vector2.new(0, 0)
		springProfile.TargetPosition = Vector2.new(0, 0)

	elseif order == 3 then
		springProfile.Velocity = Vector3.new(0, 0, 0)
		springProfile.Position = Vector3.new(0, 0, 0)
		springProfile.TargetPosition = Vector3.new(0, 0, 0)

	else -- custom matrix class for higher orders
		springProfile.Velocity = MatrixService.New(1, order)
		springProfile.Position = MatrixService.New(1, order)
		springProfile.TargetPosition = MatrixService.New(1, order)
	end

	-- configure the spring type
	springProfile.springType = springType == nil and "Default" or springType
	if springProfile.springType == "Sway" then
		springProfile.XPeriod = 1
		springProfile.YPeriod = 1
		springProfile.ZPeriod = 1

		springProfile.Damping = 10
		springProfile.MoveToCenter = false
		springProfile.CurrentTime = 0
		springProfile.Multiplier = Vector3.new(1, 1, 1)
	end

	return springProfile
end

function SpringService:UpdateParams(deltaTime)
	
	-- UPDATE THE PARAMS
	if self.zeta > 1 then
		-----------------
		-- Over Damped --
		-----------------
		
		-- check if the cached values need updating
		if self.zeta ~= self.cachedValues.zeta or self.omega_n ~= self.cachedValues.omega_n then
			self.cachedValues.zeta = self.zeta
			self.cachedValues.omega_n = self.omega_n
			
			local E_zeta = self.omega_n + math.sqrt(self.zeta^2 - 1)
			self.cachedValues.E_plus = -self.zeta*self.omega_n + E_zeta
			self.cachedValues.E_min = -self.zeta*self.omega_n - E_zeta
		end
		
		-- calc new coeffs
		local E_plus = self.cachedValues.E_plus
		local E_min = self.cachedValues.E_min
		
		local exp_plus = math.exp(E_plus*deltaTime)
		local exp_min = math.exp(E_min*deltaTime)
		
		local posCPp = ((1-E_plus) / (E_plus-E_min))*exp_plus
		local posCPm = (E_plus / (E_plus-E_min))*exp_min
		local velCPp = (1 / (E_plus-E_min))*exp_plus
		local velCPm = (1 / (E_plus-E_min))*exp_min
		
		self.posCP_Coeff = posCPp + posCPm
		self.posCV_Coeff = velCPp - velCPm
		self.velCP_Coeff = E_plus*posCPp + E_min*posCPm
		self.velCV_Coeff = E_plus*velCPp - E_min*velCPm
		
	elseif self.zeta == 1 then
		-----------------------
		-- Critically Damped --
		-----------------------

		-- calc new coeffs
		local expTerm = math.exp(-self.omega_n*deltaTime)

		self.posCP_Coeff = (1 + self.omega_n*deltaTime) * expTerm
		self.posCV_Coeff = deltaTime*expTerm
		self.velCP_Coeff = -deltaTime*expTerm * (self.omega_n^2)
		self.velCV_Coeff = (1 - self.omega_n*deltaTime) * expTerm
		
	else
		------------------
		-- Under Damped --
		------------------
		
		-- check if the cached values need updating
		if self.zeta ~= self.cachedValues.zeta or self.omega_n ~= self.cachedValues.omega_n then
			self.cachedValues.zeta = self.zeta
			self.cachedValues.omega_n = self.omega_n

			self.cachedValues.omega_d = self.omega_n*math.sqrt(1 - self.zeta^2)
		end
		
		-- calc new coeffs
		local omega_d = self.cachedValues.omega_d
		local omega_d_inv = 1/omega_d
		local expTerm = math.exp(-self.zeta*self.omega_n*deltaTime)
		local sinTerm = math.sin(omega_d*deltaTime) -- could use TEService for these (deltaTime usualy <<)
		local cosTerm = math.cos(omega_d*deltaTime)

		self.posCP_Coeff = (cosTerm + self.zeta*self.omega_n*omega_d_inv*sinTerm)*expTerm
		self.posCV_Coeff = omega_d_inv*sinTerm*expTerm
		self.velCP_Coeff = (-omega_d - omega_d_inv*(self.zeta*self.omega_n)^2)*sinTerm*expTerm
		self.velCV_Coeff = (-omega_d_inv*self.zeta*self.omega_n*sinTerm + cosTerm)*expTerm
	end
end

function SpringService:UpdateSpring(deltaTime)
	-- update any custom params
	if self.springType == "Sway" then
		-- update the current time
		self.CurrentTime = self.MoveToCenter == false and (self.CurrentTime + deltaTime) or 0

		-- update the target position
		local currentScaledTime = 2 * math.pi * self.CurrentTime
		self.TargetPosition = Vector3.new(math.sin(currentScaledTime / self.XPeriod), math.sin(currentScaledTime / self.YPeriod), math.sin(currentScaledTime / self.ZPeriod)) * self.Multiplier
	end

	-- update the spring
	local targetPos = self.TargetPosition
	local oldPos = self.Position - targetPos
	local velocity = self.Velocity
	self.Position = (oldPos * self.posCP_Coeff) + (velocity * self.posCV_Coeff) + targetPos
	self.Velocity = (oldPos * self.velCP_Coeff) + (velocity * self.velCV_Coeff)
end

return SpringService
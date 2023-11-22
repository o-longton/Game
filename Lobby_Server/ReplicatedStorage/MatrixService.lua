local Matrix = {}
Matrix.__index = Matrix

-- local functions
local function CheckType(m)
	return getmetatable(m) == Matrix
end

-- global functions
-- -- metamethods
function Matrix.__add(m1, m2)
	if CheckType(m2) then
		if m2:CheckDimensions(m1.r, m1.c) then
			local m3 = Matrix.New(m1.r, m1.c)
			for i = 1, m1.r do
				for j = 1, m1.c do
					m3[i][j] = m1[i][j] + m2[i][j]
				end
			end
			return m3
			
		else
			return warn("Matrix: Incompatable matrix for addition")
		end
		
	elseif typeof(m2) == "number" then
		local m3 = Matrix.New(m1.r, m1.c)
		for i = 1, m1.r do
			for j = 1, m1.c do
				m3[i][j] = m1[i][j] + m2
			end
		end
		return m3
	end
	
	warn("Matrix: Incompatable parameters for matrix addition (number or matrix)")
end

function Matrix.__sub(m1, m2)
	if CheckType(m2) then
		if m2:CheckDimensions(m1.r, m1.c) then
			local m3 = Matrix.New(m1.r, m1.c)
			for i = 1, m1.r do
				for j = 1, m1.c do
					m3[i][j] = m1[i][j] - m2[i][j]
				end
			end
			return m3

		else
			return warn("Matrix: Incompatable matrix for subtraction")
		end

	elseif typeof(m2) == "number" then
		local m3 = Matrix.New(m1.r, m1.c)
		for i = 1, m1.r do
			for j = 1, m1.c do
				m3[i][j] = m1[i][j] - m2
			end
		end
		return m3
	end

	warn("Matrix: Incompatable parameters for matrix subtraction (number or matrix)")
end

function Matrix.__mul(m1, m2)
	if typeof(m2) == "number" then
		local m3 = Matrix.New(m1.r, m1.c)
		for i = 1, m1.r do
			for j = 1, m1.c do
				m3[i][j] = m1[i][j] * m2
			end
		end
		return m3
	end 
	
	-- check if m2 is a vector class
	local isVector = false
	if typeof(m2) == "Vector3" then
		isVector = 3
		local mat = Matrix.New(3, 1)
		mat[1][1] = m2.X
		mat[2][1] = m2.Y
		mat[3][1] = m2.Z
		m2 = mat
		
	elseif typeof(m2) == "Vector2" then
		isVector = 2
		local mat = Matrix.New(2, 1)
		mat[1][1] = m2.X
		mat[2][1] = m2.Y
		m2 = mat
	end
	
	if CheckType(m2) then
		if m1.c == m2.r then
			local m3 = Matrix.New(m2.r, m1.c)
			for i = 1, m3.r do
				for j = 1, m3.c do
					local val = 0
					for k = 1, m1.c do
						val += m1[i][k] * m2[k][j]
					end 
					m3[i][j] = val
				end
			end
			
			if isVector == false then 
				return m3 
				
			elseif isVector == 2 then 
				return Vector2.new(m3[1][1], m3[2][1])
				
			elseif isVector == 3 then 
				return Vector3.new(m3[1][1], m3[2][1], m3[3][1])
			end

		else
			return warn("Matrix: Incompatable matrix dimensions for multliplication")
		end
	end

	warn("Matrix: Incompatable parameters for matrix addition (number or matrix)")
end

function Matrix.__pow(m1, x)
	if typeof(x) ~= "number" then return warn("Matrix: Invalid parameter for matrix ^ x (number)") end
	if not m1:CheckSquare() then return warn("Matrix: Cant perform matrix ^ x on non square matrix") end
	
	local m2 = m1:Copy()
	for i = 1, x-1 do
		m2 = m2 * m1
	end
	return m2 
end

function Matrix.__eq(m1, m2)
	if CheckType(m2) then
		if m1.r == m2.r and m1.c == m2.c then
			for i = 1, m1.r do
				for j = 1, m2.c do
					if m1[i][j] ~= m2[i][j] then return false end 
				end
			end
			return true
		end
	end
	return false
end

-- -- matrix function
function Matrix.New(r, c)
	local m = setmetatable({}, Matrix)
	m.c = c
	m.r = r
	
	for i = 1, r do
		m[i] = {}
		for j = 1, c do
			m[i][j] = 0
		end
	end
	
	return m 
end

function Matrix:CheckDimensions(r, c)
	return c == self.c and r == self.r 
end

function Matrix:CheckSquare()
	return self.c == self.r 
end

function Matrix:SetRotation(rot)
	if self:CheckDimensions(2, 2) == false then 
		return warn("Matrix: Rotation attempted to be set but incorrect dimensions (2x2 only)")
	end
	
	-- apply the rotation matrix
	local rads = math.rad(rot)
	self[1][1] = math.cos(rads)
	self[1][2] = -math.sin(rads)
	self[2][1] = math.sin(rads)
	self[2][2] = math.cos(rads)
end

function Matrix:Copy()
	local m = Matrix.New(self.r, self.c)
	
	for i = 1, m.r do
		m[i] = {}
		for j = 1, m.c do
			m[i][j] = self[i][j]
		end
	end
	return m 
end

function Matrix:Print()
	local matString = "Matrix ("..(self.r)..", "..(self.c)..")"
	for i = 1, self.r do
		matString = matString.."\n| "
		for j = 1, self.c do
			matString = matString..(self[i][j]).." "
		end
		matString = matString.."|"
	end
	print(matString)
end

return Matrix
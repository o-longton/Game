local TEService = {}

-- variables
local numDefault = 5

-- global functions
function TEService.Factorial(num)
	local fact = 1
	for i = 1, num do
		fact *= i
	end
	return fact
end

function TEService.Cos(val, num)
	local approx = 0
	for i = 0, num ~= nil and num or numDefault do
		approx += (val^(2*i) / TEService.Factorial(2*i)) * (-1)^i
	end
end

function TEService.Sin(val, num)
	local approx = 0
	for i = 0, num ~= nil and num or numDefault do
		approx += (val^(2*i + 1) / TEService.Factorial(2*i + 1)) * (-1)^i
	end
end

function TEService.Exp(val, num)
	local approx = 0
	for i = 0, num ~= nil and num or numDefault do
		approx += val^i / TEService.Factorial(i)
	end
end

return TEService
local Players = game:GetService("Players")

local Hitbox = {}

local function getHRP(char)
	return char and char:FindFirstChild("HumanoidRootPart")
end

function Hitbox.FindNearestInFront(attacker: Player, range: number, coneDeg: number)
	local aChar = attacker.Character
	local aHRP = getHRP(aChar)
	if not aHRP then return nil end
	local origin = aHRP.Position
	local forward = aHRP.CFrame.LookVector
	local best, bestDist = nil, math.huge
	local cosHalf = math.cos(math.rad((coneDeg or 60)/2))
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= attacker then
			local char = p.Character
			local hrp = getHRP(char)
			if hrp then
				local offset = hrp.Position - origin
				local dist = offset.Magnitude
				if dist <= (range or 8) then
					local dir = offset.Unit
					local dot = forward:Dot(dir)
					if dot >= cosHalf then
						if dist < bestDist then
							best = p
							bestDist = dist
						end
					end
				end
			end
		end
	end
	return best
end

return Hitbox

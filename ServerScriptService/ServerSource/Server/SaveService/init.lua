local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local SaveService = Knit.CreateService({
	Name = "SaveService",
	-- No Client remotes: server-only API wrapper around ProfileService
})

---- Components
--- component utilities
local componentsInitializer = require(ReplicatedStorage.SharedSource.Utilities.ScriptsLoader.ComponentsInitializer)
--- component folders
local componentsFolder = script:WaitForChild("Components", 5)
SaveService.Components = {}
for _, v in pairs(componentsFolder:WaitForChild("Others", 10):GetChildren()) do
	SaveService.Components[v.Name] = require(v)
end
local self_GetComponent = require(componentsFolder["Get()"])
SaveService.GetComponent = self_GetComponent
SaveService.SetComponent = require(componentsFolder["Set()"])

---- Knit Services
local ProfileService -- resolved in :KnitInit()

-- Public (server) API
-- Get the player's profile data table (do not mutate without Change/Update helpers)
function SaveService:Get(player: Player)
	return self_GetComponent:Get(player)
end

-- Update the player's profile data via a mutator function
-- NOTE: This does NOT automatically notify clients; use :Change for client sync of specific paths.
function SaveService:Update(player: Player, mutator: (any) -> ())
	return self.SetComponent:Update(player, mutator)
end

-- Change a specific nested path (array of keys) and notify clients via ProfileService
function SaveService:Change(player: Player, path: {any}, newValue: any)
	return self.SetComponent:Change(player, path, newValue)
end

function SaveService:KnitStart()
	-- No-op for now. Lifecycle handled by ProfileService
	Players.PlayerRemoving:Connect(function(player)
		-- Reserved for future cleanup hooks if needed
	end)
end

function SaveService:KnitInit()
	---- Knit Services
	ProfileService = Knit.GetService("ProfileService")

	---- Components Initializer
	componentsInitializer(script)
end

return SaveService
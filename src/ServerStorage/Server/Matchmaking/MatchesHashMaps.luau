local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Gamemodes = require(Shared.Gamemodes)

local MATCH_PREFIX = "Matches"

return {
	[Gamemodes.GAME_MODES.Solo] = MemoryStoreService:GetHashMap(
		`{MATCH_PREFIX}{Gamemodes.GAME_MODES.Solo}`
	),
	[Gamemodes.GAME_MODES.Duo] = MemoryStoreService:GetHashMap(
		`{MATCH_PREFIX}{Gamemodes.GAME_MODES.Duo}`
	),
	[Gamemodes.GAME_MODES.Squad] = MemoryStoreService:GetHashMap(
		`{MATCH_PREFIX}{Gamemodes.GAME_MODES.Squad}`
	),
} :: {[string]: MemoryStoreHashMap}

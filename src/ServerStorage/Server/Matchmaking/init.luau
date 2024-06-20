--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Gamemodes = require(Shared.Gamemodes)
local MatchmakingWorker = require(script.MatchmakingWorker)
local TableKit = require(Shared.Utils.TableKit)
local Types = require(Shared.Utils.Types)

local Matchmaking = {}
Matchmaking._joinRequests = {
	[Gamemodes.GAME_MODES.Solo] = {},
	[Gamemodes.GAME_MODES.Duo] = {},
	[Gamemodes.GAME_MODES.Squad] = {},
}
Matchmaking._workingRequests = {
	[Gamemodes.GAME_MODES.Solo] = {},
	[Gamemodes.GAME_MODES.Duo] = {},
	[Gamemodes.GAME_MODES.Squad] = {},
}
Matchmaking.MatchFound = MatchmakingWorker.MatchFound

local function checkGamemode(value: string)
	return Gamemodes.GAME_MODES[value] ~= nil
end

function Matchmaking:addJoinRequest(request: Types.JoinRequest)
	Types.strictInterface({
		gamemode = checkGamemode,
		ownerId = Types.integer,
		avgRating = Types.number,
		partyMembersId = Types.array(Types.number),
		active = Types.boolean,
	})

	Matchmaking._joinRequests[request.gamemode][request.ownerId] = request
end

function Matchmaking:removeJoinRequest(ownerId: number)
	for _, gamemodesRequests in pairs(Matchmaking._joinRequests) do
		local request = gamemodesRequests[ownerId]
		if not request then
			continue
		end
		request.active = false
		gamemodesRequests[ownerId] = nil
	end
	for _, gamemodesRequests in pairs(Matchmaking._workingRequests) do
		local request = gamemodesRequests[ownerId]
		if not request then
			continue
		end
		request.active = false
		gamemodesRequests[ownerId] = nil
	end
end


local function proceedGamemodeJoinRequests(gamemode: string)
	local requests = Matchmaking._joinRequests[gamemode]
	local requestsCount = #TableKit.Values(requests)
	if requestsCount <= 0 then
		return
	end
	local requestsOnWork = table.clone(requests)
	Matchmaking._workingRequests[gamemode] = requestsOnWork
	
	table.clear(requests)
	MatchmakingWorker:start(gamemode, requestsOnWork)
	table.clear(Matchmaking._workingRequests)
end

task.spawn(function()
	while task.wait(5) do
		proceedGamemodeJoinRequests(Gamemodes.GAME_MODES.Solo)
	end
end)
task.spawn(function()
	while task.wait(5) do
		proceedGamemodeJoinRequests(Gamemodes.GAME_MODES.Duo)
	end
end)
task.spawn(function()
	while task.wait(5) do
		proceedGamemodeJoinRequests(Gamemodes.GAME_MODES.Squad)
	end
end)

return Matchmaking

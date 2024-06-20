local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Constants = require(Shared.Constants)
local Gamemodes = require(Shared.Gamemodes)
local GoodSignal = require(Shared.Utils.GoodSignal)
local MatchesHashMaps = require(script.Parent.MatchesHashMaps)
local MatchSuitability = require(script.Parent.MatchSuitability)
local MatchTeleporter = require(script.Parent.MatchTeleporter)
local pcalls = require(Shared.Utils.pcalls)
local TableKit = require(Shared.Utils.TableKit)
local Types = require(Shared.Utils.Types)

local MatchMakingWorker = {}
MatchMakingWorker.MatchFound = GoodSignal.new()

do
	local function updateAvgRating(match: Types.Match, joinRequest: Types.JoinRequest)
		local partyPlayersCount = #joinRequest.partyMembersId + 1
		local matchPlayersCount = #match.playersId

		local matchRatingSum = match.avgRating * matchPlayersCount
		local partyRatingSum = joinRequest.avgRating * partyPlayersCount

		match.avgRating = (matchRatingSum + partyRatingSum) // (partyPlayersCount + matchPlayersCount)
	end

	local function updatePlayers(match: Types.Match, joinRequest: Types.JoinRequest)
		table.insert(match.playersId, joinRequest.ownerId)

		for _, memberUserId in ipairs(joinRequest.partyMembersId) do
			table.insert(match.playersId, memberUserId)
		end
	end

	local function updateParties(match: Types.Match, joinRequest: Types.JoinRequest)
		local partyPlayersCount = #joinRequest.partyMembersId + 1
		table.insert(match.parties, partyPlayersCount)
	end

	function addJoinRequestToMatch(match: Types.Match, joinRequest: Types.JoinRequest)
		updateAvgRating(match, joinRequest)
		updatePlayers(match, joinRequest)
		updateParties(match, joinRequest)
	end
end

local function checkForMatch(match: Types.Match, joinRequests: {[Types.usedId]: Types.JoinRequest})
	local isUpdated = false
	for key, joinRequest in pairs(joinRequests) do
		if not joinRequest.active then
			continue
		end
		if not MatchSuitability:isSuitableFor(match, joinRequest) then
			continue
		end
		isUpdated = true
		MatchMakingWorker.MatchFound:Fire(joinRequest)

		joinRequests[key] = nil
		addJoinRequestToMatch(match, joinRequest)
		MatchTeleporter:teleportToMatch(match, joinRequest)
	end
	return isUpdated
end

local function updateMatch(key, match: Types.Match, hashmap: MemoryStoreHashMap)
	pcalls.untilSucceed(1, true, function()
		hashmap:SetAsync(key, match, Constants.MATCH_EXPIRATION_TIME)
	end)
end

local function startSearching(hashMap: MemoryStoreHashMap, requests, quota: number)
	local _, pages = pcalls.untilSucceed(1, true, function(...: any)
		local playerCount = #Players:GetPlayers()
		return hashMap:ListItemsAsync(math.max(playerCount - 5, 5))
	end)
	
	while not pages.IsFinished do
		local items = pages:GetCurrentPage()
		local itemsCount = #TableKit.Values(items)

		for _, entry in pairs(items) do
			local isUpdated = checkForMatch(entry.value, requests)
			if not isUpdated then
				continue
			end
			updateMatch(entry.key, entry.value, hashMap)
		end
		
		local joinRequestsCount = #TableKit.Keys(requests)
		if joinRequestsCount <= 0 then
			break
		end
		
		if not pages.IsFinished then
			if itemsCount <= 0 then
				task.wait(0.2)
			else
				task.wait(1)
			end
			pcalls.untilSucceed(1, true, function(...: any)
				pages:AdvanceToNextPageAsync()
			end)
		end
	end
	pages:Destroy()
end

do
	local function createNewMatch(gamemode: string)
		local accessCode, privateServerId = MatchTeleporter:reserveServerForGamemodeWithName(gamemode)
		local match = {
			accessCode = accessCode,
			gamemode = gamemode,
			playersId = {},
			avgRating = 0,
			parties = {},
		}
		return match, privateServerId
	end

	local function loadNewMatchToHashmap(gamemode: string, match: Types.Match, privateServerId)
		local gamemodeHashMap = MatchesHashMaps[gamemode]
		pcalls.untilSucceed(3, true, function()
			gamemodeHashMap:SetAsync(privateServerId, match, Constants.MATCH_EXPIRATION_TIME)
		end)
	end

	function createNewMatchesFor(gamemode: string, joinRequests: {[Types.usedId]: Types.JoinRequest})
		for _, joinRequest in pairs(joinRequests) do
			local newMatch, privateServerId = createNewMatch(gamemode)
			checkForMatch(newMatch, joinRequests)
			loadNewMatchToHashmap(gamemode, newMatch, privateServerId)
		end
	end
end

function MatchMakingWorker:start(gamemode: string, joinRequests: {[Types.usedId]: Types.JoinRequest})
	local gamemodeHashMap = MatchesHashMaps[gamemode]

	startSearching(gamemodeHashMap, joinRequests, 15)
	createNewMatchesFor(gamemode, joinRequests)
end

return MatchMakingWorker

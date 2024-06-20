local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Gamemodes = require(Shared.Gamemodes)
local pcalls = require(Shared.Utils.pcalls)
local Types = require(Shared.Utils.Types)

local IS_STUDIO = RunService:IsStudio()

local MatchMakingTeleporter = {}

local function getPlayersFromJoinRequest(joinRequest: Types.JoinRequest)
	local result = {}
	
	table.insert(result, Players:GetPlayerByUserId(joinRequest.ownerId))
	for _, membersUserId in ipairs(joinRequest.partyMembersId) do
		table.insert(result, Players:GetPlayerByUserId(membersUserId))
	end
	
	return result
end

function MatchMakingTeleporter:teleportToMatch(match: Types.Match, joinRequest: Types.JoinRequest)
	local accessCode = match.accessCode
	local placeId = Gamemodes.GAME_MODES_PLACES_ID[match.gamemode]
	
	if IS_STUDIO then
		warn(`PLAYER TELEPORTED TO {match.gamemode}`)
		return
	end
	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions:SetTeleportData({
		partyOwner = joinRequest.ownerId
	})
	teleportOptions.ShouldReserveServer = false
	teleportOptions.ReservedServerAccessCode = match.accessCode
	
	local playersToTeleport = getPlayersFromJoinRequest(joinRequest)
	if #playersToTeleport <= 0 then
		teleportOptions:Destroy()
		return
	end
	pcalls.withRetry(5, 1, true, function(...: any)
		TeleportService:TeleportAsync(
			placeId, 
			playersToTeleport, 
			teleportOptions
		)
	end)
	teleportOptions:Destroy()
end

function MatchMakingTeleporter:reserveServerForGamemodeWithName(gamemodeName: string)
	if IS_STUDIO then
		return 0
	end
	local _, accessCode, privateServerId = pcalls.untilSucceed(1, true, function(...: any)
		return TeleportService:ReserveServer(Gamemodes.GAME_MODES_PLACES_ID[gamemodeName])
	end)
	return accessCode, privateServerId
end

return MatchMakingTeleporter

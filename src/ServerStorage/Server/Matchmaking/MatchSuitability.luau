local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Constants = require(Shared.Constants)
local Gamemodes = require(Shared.Gamemodes)
local PlayerStats = require(Shared.PlayerStats)
local TableKit = require(Shared.Utils.TableKit)
local Types = require(Shared.Utils.Types)

local MatchSuitability = {}

local function isPartyFits(match: Types.Match, joinRequest: Types.JoinRequest)
	if match.gamemode ~= Gamemodes.GAME_MODES.Squad then
		return true
	end
	local maxPlayersInTeam = Gamemodes.GAME_MODES_MAX_PLAYERS_IN_TEAM[match.gamemode]
	local maxPlayersInMatch = Gamemodes.GAME_MODES_MAX_PLAYERS[match.gamemode]
	local teamsCount = maxPlayersInMatch / maxPlayersInTeam
	
	local parties = table.clone(match.parties)
	local teams = table.create(teamsCount, 0)
	
	for i, teamPlayersCount in ipairs(teams) do
		for key, partyPlayersCount in pairs(parties) do
			if teamPlayersCount + partyPlayersCount > maxPlayersInTeam then
				continue
			end
			teamPlayersCount += partyPlayersCount
			parties[key] = nil
		end
		teams[i] = teamPlayersCount
	end
	
	for _, _ in pairs(parties) do
		return false
	end
	
	return true
end

function MatchSuitability:isSuitableFor(match: Types.Match, joinRequest: Types.JoinRequest)
	local matchPlayersCount = #match.playersId
	local matchAvgRating = match.avgRating

	local requestPlayersCount = #joinRequest.partyMembersId + 1
	local partyAvgRating = joinRequest.avgRating

	local maxPlayersForGamemode = Gamemodes.GAME_MODES_MAX_PLAYERS[match.gamemode]

	local isPlayersFits = matchPlayersCount + requestPlayersCount < maxPlayersForGamemode

	local ratingFitValue = math.min(partyAvgRating / matchAvgRating, 1)
	local isPartyRatingFits = ratingFitValue >= Constants.MATCH_FITTING_MIN_VALUE

	return isPlayersFits and isPartyRatingFits and isPartyFits(match, joinRequest)
end

return MatchSuitability

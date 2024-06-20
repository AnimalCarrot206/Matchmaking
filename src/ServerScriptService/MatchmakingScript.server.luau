local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Server = ServerStorage.Server
local Shared = ReplicatedStorage.Shared

local Bridges = require(Shared.Bridges)
local Gamemodes = require(Shared.Gamemodes)
local PartyManager = require(Server.PartyManager)
local Types = require(Shared.Utils.Types)
local Matchmaking = require(Server.Matchmaking)
local Util = require(Shared.Util)

local getPlayersUserIds = Util.getPlayersUserId

Bridges.searchStarted:Connect(function(player: Player, args: {gamemode: string})
	if not Gamemodes.GAME_MODES[args.gamemode] then
		return
	end
	local foundParty = PartyManager:getPartyByOwner(player)
	if not foundParty then
		Bridges.wrongAction:Fire(player, {message = "You are not a party owner!"})
		return
	end
	if #foundParty.members >= 1 and args.gamemode == Gamemodes.GAME_MODES.Solo then
		Bridges.wrongAction:Fire(player, {message = "You can't play solo with party!"})
		return
	end
	
	local newJoinRequest: Types.JoinRequest = {
		ownerId = player.UserId,
		gamemode = args.gamemode,
		avgRating = PartyManager:getAveragePartyRating(foundParty),
		partyMembersId = getPlayersUserIds(foundParty.members),
		active = true,
	}
	Matchmaking:addJoinRequest(newJoinRequest)
	
	Bridges.searchStarted:Fire(player, args)
	Bridges.searchStarted:Fire(
		Bridges.BridgeNet2.Players(foundParty.members),
		args
	)
	PartyManager:bindOnDisband(foundParty, function()
		Matchmaking:removeJoinRequest(player.UserId)

		Bridges.searchCancelled:Fire(player)
		Bridges.searchCancelled:Fire(Bridges.BridgeNet2.Players(foundParty.members))
	end)
end)

Bridges.searchCancelled:Connect(function(player: Player)
	local foundParty = PartyManager:getPartyByOwner(player)
	if not foundParty then
		return
	end
	Matchmaking:removeJoinRequest(player.UserId)
	
	Bridges.searchCancelled:Fire(player)
	Bridges.searchCancelled:Fire(Bridges.BridgeNet2.Players(foundParty.members))
end)

Matchmaking.MatchFound:Connect(function(joinRequest: Types.JoinRequest)
	local players = {}
	table.insert(players, Players:GetPlayerByUserId(joinRequest.ownerId))
	for _, memberUserId in ipairs(joinRequest.partyMembersId) do
		table.insert(players, Players:GetPlayerByUserId(memberUserId))
	end
	
	Bridges.gameFound:Fire(Bridges.BridgeNet2.Players(players))
end)
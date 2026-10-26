--!strict
-- Who may do what on the Roblox side. Milestone 1 knows the Owner and staff (Roblox group ranks).
-- Economic and faction permissions are NOT decided here: the economy bot checks them with the
-- player's Discord roles (Milestone 6).

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("Permissions")

local PermissionService = {}

local groupRank: { [Player]: number } = {}

-- Highest rank the player holds in the Ro-Nation group (0 = not a member).
-- GroupService:GetRolesInGroupAsync answers { IsMember = boolean, Roles = { { Name, Rank } } }.
local function loadRank(player: Player)
	local ok, info = pcall(function()
		return GroupService:GetRolesInGroupAsync(player.UserId, GameConfig.GroupId)
	end)
	if not ok or type(info) ~= "table" then
		groupRank[player] = 0
		log.warn(`Could not read the group roles of {player.Name}; treating as rank 0.`, info)
		return
	end
	local best = 0
	if info.IsMember == true and type(info.Roles) == "table" then
		for _, role in info.Roles do
			if type(role) == "table" and type(role.Rank) == "number" and role.Rank > best then
				best = role.Rank
			end
		end
	end
	groupRank[player] = best
end

function PermissionService.isOwner(player: Player): boolean
	return player.UserId == GameConfig.OwnerUserId or (groupRank[player] or 0) >= 255
end

function PermissionService.isStaff(player: Player): boolean
	return PermissionService.isOwner(player) or (groupRank[player] or 0) >= GameConfig.StaffMinGroupRank
end

function PermissionService.init() end

function PermissionService.start()
	Players.PlayerAdded:Connect(loadRank)
	for _, player in Players:GetPlayers() do
		task.spawn(loadRank, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		groupRank[player] = nil
	end)
end

return PermissionService

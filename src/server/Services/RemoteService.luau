--!strict
-- Creates the remotes declared in Shared/Net/Remotes and protects them:
-- per-player rate limits, errors never reach the client as crashes, every answer is a Reply table.
-- Handlers must validate every argument themselves: anything from a client can be forged.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local EconomyTypes = require(ReplicatedStorage.Shared.Types.Economy)

type Reply = EconomyTypes.Reply

export type Limit = {
	count: number, -- at most this many calls ...
	perSeconds: number, -- ... in this many seconds, per player
}

local log = Log.new("Remotes")

local RemoteService = {}

local remoteFolder: Folder? = nil
local calls: { [Player]: { [string]: { number } } } = {}

local function getRemote(name: string): Instance
	local container = remoteFolder
	assert(container, "RemoteService.init has not run")
	local remote = container:FindFirstChild(name)
	assert(remote, `Remote {name} is not declared in Shared/Net/Remotes`)
	return remote
end

local function allow(player: Player, name: string, limit: Limit): boolean
	local now = os.clock()
	local perPlayer = calls[player]
	if not perPlayer then
		perPlayer = {}
		calls[player] = perPlayer
	end
	local recent: { number } = {}
	local previous = perPlayer[name]
	if previous then
		for _, t in previous do
			if now - t < limit.perSeconds then
				table.insert(recent, t)
			end
		end
	end
	if #recent >= limit.count then
		perPlayer[name] = recent
		return false
	end
	table.insert(recent, now)
	perPlayer[name] = recent
	return true
end

function RemoteService.init()
	local folder = Instance.new("Folder")
	folder.Name = Remotes.FolderName
	for _, name in Remotes.Functions do
		local remote = Instance.new("RemoteFunction")
		remote.Name = tostring(name)
		remote.Parent = folder
	end
	for _, name in Remotes.Events do
		local remote = Instance.new("RemoteEvent")
		remote.Name = tostring(name)
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
	remoteFolder = folder
	Players.PlayerRemoving:Connect(function(player)
		calls[player] = nil
	end)
end

function RemoteService.start() end

-- Answers a RemoteFunction. The handler gets the player plus the raw client arguments.
function RemoteService.onInvoke(name: string, limit: Limit, handler: (Player, ...any) -> Reply)
	local remote = getRemote(name)
	assert(remote:IsA("RemoteFunction"), `{name} is not a RemoteFunction`)
	remote.OnServerInvoke = function(player: Player, ...: any): Reply
		if not allow(player, name, limit) then
			return { ok = false, error = "rate_limited", message = "Please wait a moment and try again." }
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			log.error(`{name} failed for {player.UserId}:`, result)
			return { ok = false, error = "internal", message = "Something went wrong. Nothing was changed." }
		end
		return result
	end
end

-- Sends a short notice to one player.
function RemoteService.notify(player: Player, message: string, kind: "info" | "success" | "error")
	local remote = getRemote(Remotes.Events.Notify)
	if remote:IsA("RemoteEvent") then
		remote:FireClient(player, message, kind)
	end
end

return RemoteService

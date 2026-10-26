--!strict
-- Every remote the game uses is declared here. The server creates them (RemoteService);
-- the client only looks them up. Clients send intentions, never amounts, balances or results:
-- the server decides and the economy bot is the only place where money exists.
--
-- RemoteFunctions (client asks, server answers with a Reply table, see Types/Economy):
--   GetAccount()                      -> account status, link status, balances (read-only)
--   RequestLinkCode()                 -> a one-time code to confirm in Discord with /link confirm
--   GetTransactions(account, page)    -> account: "bank" | "cash", page: 1-50
--   RunTestTransfer(direction)        -> staging only, Owner/staff only: "withdraw" | "deposit" 1.00 KGD
-- RemoteEvents (server -> client):
--   Notify(message, kind)             -> short notice for the player; kind: "info" | "success" | "error"

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

Remotes.FolderName = "RoNationRemotes"

Remotes.Functions = table.freeze({
	GetAccount = "GetAccount",
	RequestLinkCode = "RequestLinkCode",
	GetTransactions = "GetTransactions",
	RunTestTransfer = "RunTestTransfer",
})

Remotes.Events = table.freeze({
	Notify = "Notify",
})

local function folder(): Instance
	return ReplicatedStorage:WaitForChild(Remotes.FolderName)
end

-- Client side: waits until the server has created the remote.
function Remotes.getFunction(name: string): RemoteFunction
	local remote = folder():WaitForChild(name)
	assert(remote:IsA("RemoteFunction"), `{name} is not a RemoteFunction`)
	return remote
end

function Remotes.getEvent(name: string): RemoteEvent
	local remote = folder():WaitForChild(name)
	assert(remote:IsA("RemoteEvent"), `{name} is not a RemoteEvent`)
	return remote
end

return Remotes

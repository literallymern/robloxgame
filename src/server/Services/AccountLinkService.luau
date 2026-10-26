--!strict
-- The player's side of the economy in Milestone 1: link status, "Link Discord", read-only account
-- view and, on the staging bridge only, a small test transfer for the Owner and staff.
-- Every value shown comes from the economy bot through the EconomyGateway; nothing is stored here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local EconomyTypes = require(ReplicatedStorage.Shared.Types.Economy)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local EconomyGateway = require(script.Parent.EconomyGateway)
local PermissionService = require(script.Parent.PermissionService)
local RemoteService = require(script.Parent.RemoteService)

type Reply = EconomyTypes.Reply
type AccountView = EconomyTypes.AccountView

local log = Log.new("AccountLink")

local AccountLinkService = {}

local function unavailable(): Reply
	if EconomyGateway.getStatus() == "not_configured" then
		return {
			ok = false,
			error = "not_configured",
			message = "Financial services are not set up on this server.",
		}
	end
	return {
		ok = false,
		error = "unavailable",
		message = "Financial services are temporarily unavailable. Roleplay continues; money features are paused.",
	}
end

local function refusal(body: { [string]: any }): Reply
	return {
		ok = false,
		error = if type(body.error) == "string" then body.error else "refused",
		message = if type(body.message) == "string" then body.message else "The economy refused this request.",
	}
end

local function emptyView(): AccountView
	return {
		status = EconomyGateway.getStatus(),
		linked = false,
		frozen = false,
		maintenance = EconomyGateway.getStatus() == "maintenance",
		canRunTests = false,
	}
end

local function getAccount(player: Player): Reply
	local response = EconomyGateway.getSummary(player.UserId)
	if not response.reached or response.status ~= 200 then
		local reply = if response.reached then refusal(response.body) else unavailable()
		reply.data = emptyView()
		return reply
	end
	local body = response.body
	local accounts = if type(body.accounts) == "table" then body.accounts else {}
	local discord = if type(body.discord) == "table" then body.discord else {}
	local bank = if type(accounts.bank) == "table" then accounts.bank else nil
	local cash = if type(accounts.cash) == "table" then accounts.cash else nil
	local linked = body.linked == true
	local view: AccountView = {
		status = EconomyGateway.getStatus(),
		linked = linked,
		displayName = discord.displayName,
		bank = if bank then bank.balance else nil,
		cash = if cash then cash.balance else nil,
		frozen = (bank ~= nil and bank.frozen == true) or (cash ~= nil and cash.frozen == true),
		creditScore = body.creditScore,
		removalEffectiveAt = discord.removalEffectiveAt,
		maintenance = body.maintenance == true,
		asOf = body.asOf,
		canRunTests = linked and EconomyGateway.testOperationsEnabled() and PermissionService.isStaff(player),
	}
	return { ok = true, data = view }
end

local function requestLinkCode(player: Player): Reply
	local response = EconomyGateway.startLink(player)
	if not response.reached then
		return unavailable()
	end
	if response.status ~= 200 then
		return refusal(response.body)
	end
	if response.body.status == "linked" then
		return { ok = true, data = { linked = true } }
	end
	return {
		ok = true,
		data = {
			linked = false,
			code = response.body.code,
			expiresAt = response.body.expiresAt,
			command = "/link confirm",
		},
	}
end

local function getTransactions(player: Player, account: unknown, page: unknown): Reply
	if account ~= "bank" and account ~= "cash" then
		return { ok = false, error = "bad_request", message = "Unknown account." }
	end
	if type(page) ~= "number" or page ~= math.floor(page) or page < 1 or page > 50 then
		return { ok = false, error = "bad_request", message = "Unknown page." }
	end
	local response = EconomyGateway.getTransactions(player.UserId, account, page)
	if not response.reached then
		return unavailable()
	end
	if response.status ~= 200 then
		return refusal(response.body)
	end
	return {
		ok = true,
		data = {
			account = account,
			page = page,
			items = if type(response.body.items) == "table" then response.body.items else {},
		},
	}
end

local function runTestTransfer(player: Player, direction: unknown): Reply
	if direction ~= "withdraw" and direction ~= "deposit" then
		return { ok = false, error = "bad_request", message = "Unknown direction." }
	end
	if not PermissionService.isStaff(player) then
		return { ok = false, error = "forbidden", message = "Only the Owner and staff can run test transfers." }
	end
	if not EconomyGateway.testOperationsEnabled() then
		return { ok = false, error = "unavailable", message = "Test transfers only work with the staging bridge." }
	end
	local result = EconomyGateway.testCashTransfer(player.UserId, direction)
	log.info(`Test transfer ({direction}) by {player.UserId}: {result.state}`)
	if result.state == "succeeded" then
		local accounts = if type(result.body.accounts) == "table" then result.body.accounts else {}
		return {
			ok = true,
			message = `Done: transaction #{result.body.transactionId}.`,
			data = {
				transactionId = result.body.transactionId,
				replayed = result.body.replayed == true,
				bank = if type(accounts.bank) == "table" then accounts.bank.balance else nil,
				cash = if type(accounts.cash) == "table" then accounts.cash.balance else nil,
			},
		}
	end
	return {
		ok = false,
		error = result.state,
		message = result.message or "The test transfer was not carried out. Nothing was changed.",
	}
end

function AccountLinkService.init() end

function AccountLinkService.start()
	RemoteService.onInvoke(Remotes.Functions.GetAccount, { count = 10, perSeconds = 30 }, getAccount)
	RemoteService.onInvoke(Remotes.Functions.RequestLinkCode, { count = 3, perSeconds = 60 }, requestLinkCode)
	RemoteService.onInvoke(Remotes.Functions.GetTransactions, { count = 10, perSeconds = 30 }, getTransactions)
	RemoteService.onInvoke(Remotes.Functions.RunTestTransfer, { count = 5, perSeconds = 60 }, runTestTransfer)

	EconomyGateway.OperationSettled:Connect(function(settlement)
		local player = Players:GetPlayerByUserId(settlement.userId)
		if not player then
			return
		end
		if settlement.state == "succeeded" then
			RemoteService.notify(player, "A delayed economy request has now been completed.", "success")
		elseif settlement.state == "voided" then
			RemoteService.notify(player, "A delayed economy request was cancelled. Nothing was changed.", "info")
		else
			RemoteService.notify(player, settlement.message or "A delayed economy request was not carried out.", "info")
		end
	end)

	EconomyGateway.StatusChanged:Connect(function(status)
		if status == "unavailable" then
			log.warn("The economy bot cannot be reached. Money features are paused; no balances are invented.")
		end
	end)

	log.info("Ready.", `Amounts are shown like {Format.kgd(250000)}.`)
end

return AccountLinkService

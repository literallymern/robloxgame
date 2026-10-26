--!strict
-- The only door between the game and money. SERVER ONLY.
--
-- The Discord economy bot is the single source of truth for every balance and transaction.
-- This module talks to the bot's Roblox bridge over HTTP and never keeps a balance of its own:
--   * reads return the bot's current values (shown to players as "as of <time>")
--   * writes carry an operation ID created before the first attempt and reused on every retry,
--     so the bot executes each operation exactly once
--   * operations whose answer never arrived are saved in a DataStore and settled later with the
--     bridge's "resolve" call (stored answer, or cancelled so a late copy can never run)
--   * if the bot cannot be reached, nothing is invented: callers get "unavailable"

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BridgeConfig = require(script.Parent.Parent.Config.BridgeConfig)
local EconomyTypes = require(ReplicatedStorage.Shared.Types.Economy)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

type ServiceStatus = EconomyTypes.ServiceStatus

export type Response = {
	reached: boolean, -- true when the bridge itself answered (JSON with an "ok" field)
	status: number, -- HTTP status code, 0 when there was no answer
	body: { [string]: any }, -- decoded JSON answer, {} when there was none
	problem: string?, -- "disabled" | "not_configured" | "timeout" | "network" | "bad_response"
}

export type OperationResult = {
	-- succeeded: executed once; refused: the economy said no (nothing changed);
	-- not_executed: never ran (safe to try again as a new operation);
	-- pending: no answer yet, saved and settled automatically later.
	state: "succeeded" | "refused" | "not_executed" | "pending",
	message: string?,
	body: { [string]: any },
}

export type Settlement = {
	userId: number,
	operationId: string,
	state: string,
	message: string?,
}

local log = Log.new("EconomyGateway")

local EconomyGateway = {}

EconomyGateway.StatusChanged = Signal.new() :: Signal.Signal<ServiceStatus>
EconomyGateway.OperationSettled = Signal.new() :: Signal.Signal<Settlement>

local enabled = false
local status: ServiceStatus = "unknown"
local testOperations = false
local pendingStore: DataStore? = nil
local inFlight: { [string]: boolean } = {}

local function setStatus(newStatus: ServiceStatus)
	if newStatus ~= status then
		status = newStatus
		log.info("Economy status:", newStatus)
		EconomyGateway.StatusChanged:Fire(newStatus)
	end
end

local function noAnswer(problem: string): Response
	return { reached = false, status = 0, body = {}, problem = problem }
end

-- Headers with the API key from the experience's Secrets. Returns nil if no key is available.
local function buildHeaders(hasBody: boolean): { [string]: any }?
	local ok, secret = pcall(function()
		return HttpService:GetSecret(BridgeConfig.SecretName)
	end)
	if not ok then
		return nil
	end
	local headers: { [string]: any } = {}
	if BridgeConfig.AuthHeader == "X-Api-Key" then
		headers["X-Api-Key"] = secret
	else
		headers["Authorization"] = secret:AddPrefix("Bearer ")
	end
	if hasBody then
		headers["Content-Type"] = "application/json"
	end
	return headers
end

-- RequestAsync with a time limit. A late answer after the limit is ignored; the operation ID
-- makes a retry safe even if the first request did arrive.
local function requestWithTimeout(
	url: string,
	method: string,
	headers: { [string]: any },
	body: string?
): (boolean, any)
	local thread = coroutine.running()
	local finished = false
	task.spawn(function()
		local ok, result = pcall(function()
			return HttpService:RequestAsync({
				Url = url,
				Method = method,
				Headers = headers,
				Body = body,
			})
		end)
		if finished then
			return
		end
		finished = true
		task.defer(thread, ok, result)
	end)
	task.delay(BridgeConfig.TimeoutSeconds, function()
		if finished then
			return
		end
		finished = true
		task.defer(thread, false, "timeout")
	end)
	return coroutine.yield()
end

local function decode(text: any): { [string]: any }?
	if type(text) ~= "string" then
		return nil
	end
	local ok, value = pcall(function()
		return HttpService:JSONDecode(text)
	end)
	if ok and type(value) == "table" then
		return value
	end
	return nil
end

local function request(method: string, path: string, payload: { [string]: any }?): Response
	if not enabled then
		return noAnswer("disabled")
	end
	local headers = buildHeaders(payload ~= nil)
	if not headers then
		setStatus("not_configured")
		return noAnswer("not_configured")
	end
	local body = if payload then HttpService:JSONEncode(payload) else nil
	local ok, result = requestWithTimeout(BridgeConfig.BaseUrl .. path, method, headers, body)
	if not ok then
		if result ~= "timeout" then
			log.warn(`{method} {path} failed:`, result)
		end
		return noAnswer(if result == "timeout" then "timeout" else "network")
	end
	local decoded = decode(result.Body)
	if decoded == nil or type(decoded.ok) ~= "boolean" then
		return { reached = false, status = result.StatusCode, body = {}, problem = "bad_response" }
	end
	if result.StatusCode == 401 then
		log.warn("The bridge refused the API key. Check the secret " .. BridgeConfig.SecretName .. ".")
		setStatus("not_configured")
	end
	return { reached = true, status = result.StatusCode, body = decoded, problem = nil }
end

-- Keeps the status up to date from the answer of a read request.
local function noteRead(response: Response)
	if response.reached and response.status == 200 then
		setStatus(if response.body.maintenance == true then "maintenance" else "available")
	elseif response.problem == "timeout" or response.problem == "network" or response.problem == "bad_response" then
		setStatus("unavailable")
	end
end

local function checkHealth()
	local response = request("GET", "/v1/health")
	if response.problem == "disabled" or response.problem == "not_configured" then
		return
	end
	if response.reached and response.status == 200 then
		testOperations = response.body.testOperations == true
	end
	if response.status ~= 401 then
		noteRead(response)
	end
end

-- Pending operations (only IDs and what they were for; never balances) -------------------------

local function savePending(operationId: string, record: { [string]: any })
	local store = pendingStore
	if not store then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(operationId, record)
	end)
	if not ok then
		log.warn(`Could not save pending operation {operationId}:`, err)
	end
end

local function removePending(operationId: string)
	local store = pendingStore
	if not store then
		return
	end
	local ok, err = pcall(function()
		store:RemoveAsync(operationId)
	end)
	if not ok then
		log.warn(`Could not remove pending operation {operationId}:`, err)
	end
end

-- True when the answer is final for this operation ID (it ran, was refused, or will never run).
local function isFinal(response: Response): boolean
	if not response.reached then
		return false
	end
	if response.status == 503 then
		return response.body.error == "maintenance" -- refused before anything was stored
	end
	return response.status < 500 and response.status ~= 429
end

local function interpret(response: Response): OperationResult
	local message = response.body.message
	if type(message) ~= "string" then
		message = nil
	end
	if response.status == 200 then
		return { state = "succeeded", message = message, body = response.body }
	elseif response.status == 422 then
		return { state = "refused", message = message, body = response.body }
	end
	-- 400, 401, 404, 409, 410 and 503 (maintenance): nothing was executed for this request.
	return { state = "not_executed", message = message, body = response.body }
end

-- Sends a write operation exactly once. Yields up to about 50 seconds in the worst case.
local function sendOperation(path: string, userId: number, payload: { [string]: any }): OperationResult
	local operationId = HttpService:GenerateGUID(false)
	local body = table.clone(payload)
	body.operationId = operationId
	body.robloxUserId = tostring(userId)

	inFlight[operationId] = true
	savePending(operationId, { path = path, userId = userId, createdAt = os.time() })

	local result: OperationResult? = nil
	for attempt = 1, #BridgeConfig.RetryDelays + 1 do
		if attempt > 1 then
			task.wait(BridgeConfig.RetryDelays[attempt - 1])
		end
		local response = request("POST", path, body)
		if response.problem == "disabled" or response.problem == "not_configured" then
			result = {
				state = "not_executed",
				message = "Financial services are not set up on this server.",
				body = {},
			}
			break
		end
		if isFinal(response) then
			result = interpret(response)
			break
		end
	end
	inFlight[operationId] = nil

	if result then
		removePending(operationId)
		return result
	end
	setStatus("unavailable")
	return {
		state = "pending",
		message = "The economy did not answer in time. The request is saved and will be settled automatically. Nothing is charged twice.",
		body = { operationId = operationId },
	}
end

-- Settles operations whose answer never arrived (this server or a server that shut down).
local function reconcile()
	local store = pendingStore
	if not store or not enabled or status == "not_configured" then
		return
	end
	local ok, pages = pcall(function()
		return store:ListKeysAsync()
	end)
	if not ok then
		return
	end
	while true do
		for _, key in pages:GetCurrentPage() do
			local operationId = key.KeyName
			if
				type(operationId) == "string"
				and string.match(operationId, "^[%w%-]+$")
				and not inFlight[operationId]
			then
				local okGet, record = pcall(function()
					return store:GetAsync(operationId)
				end)
				local createdAt = if okGet and type(record) == "table" then tonumber(record.createdAt) else nil
				if createdAt and os.time() - createdAt >= BridgeConfig.ReconcileAfterSeconds then
					local response = request("POST", `/v1/operations/{operationId}/resolve`, {})
					if response.reached and table.find({ 200, 409, 410, 422 }, response.status) then
						removePending(operationId)
						local state = tostring(response.body.state)
						log.info(`Settled operation {operationId}: {state}`)
						EconomyGateway.OperationSettled:Fire({
							userId = tonumber(record.userId) or 0,
							operationId = operationId,
							state = state,
							message = if type(response.body.message) == "string" then response.body.message else nil,
						})
					end
				end
			end
		end
		if pages.IsFinished then
			break
		end
		local okNext = pcall(function()
			pages:AdvanceToNextPageAsync()
		end)
		if not okNext then
			break
		end
	end
end

-- Public API ------------------------------------------------------------------------------------

function EconomyGateway.getStatus(): ServiceStatus
	return status
end

-- True only on a staging bridge (it reports testOperations = true).
function EconomyGateway.testOperationsEnabled(): boolean
	return testOperations and status ~= "not_configured"
end

function EconomyGateway.getSummary(userId: number): Response
	local response = request("GET", `/v1/players/{userId}/summary`)
	noteRead(response)
	return response
end

function EconomyGateway.getTransactions(userId: number, account: "bank" | "cash", page: number): Response
	local response = request("GET", `/v1/players/{userId}/transactions?account={account}&page={page}`)
	noteRead(response)
	return response
end

function EconomyGateway.startLink(player: Player): Response
	return request("POST", "/v1/links/start", { robloxUserId = tostring(player.UserId), robloxName = player.Name })
end

-- Staging only: moves TestTransferAmount between the player's own bank and cash accounts.
function EconomyGateway.testCashTransfer(userId: number, direction: "withdraw" | "deposit"): OperationResult
	return sendOperation("/v1/operations/test-cash-transfer", userId, {
		direction = direction,
		amount = BridgeConfig.TestTransferAmount,
	})
end

function EconomyGateway.init()
	enabled = BridgeConfig.Enabled and (not BridgeConfig.StudioOnly or RunService:IsStudio())
	if not enabled then
		status = "not_configured"
		return
	end
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(BridgeConfig.PendingStoreName)
	end)
	if ok then
		pendingStore = store
	else
		log.warn("No DataStore for pending operations (publish the place and enable Studio API access):", store)
	end
end

function EconomyGateway.start()
	if not enabled then
		log.info("Economy bridge is off on this server. Money features show as unavailable.")
		return
	end
	task.spawn(function()
		while true do
			checkHealth()
			task.wait(BridgeConfig.HealthIntervalSeconds)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(BridgeConfig.ReconcileIntervalSeconds)
			xpcall(reconcile, function(err)
				log.warn("Reconciling pending operations failed:", err)
			end)
		end
	end)
end

return EconomyGateway

--!strict
-- Connection to the economy bot's Roblox bridge. SERVER ONLY: this module lives in
-- ServerScriptService, which clients cannot see. The API key is NOT here: it is read from the
-- experience's Secrets (HttpService:GetSecret) and never appears in a script, log or Git.

local BridgeConfig = {
	Enabled = true,

	-- Milestone 1: the staging bridge on Justin's PC ("npm run bridge-staging" in discord/bot).
	-- The live address (HTTPS on the 24/7 host) replaces this in Milestone 4.
	BaseUrl = "http://localhost:8788",
	-- true = only used in Roblox Studio (a localhost address cannot work on Roblox's servers).
	StudioOnly = true,

	-- Name of the secret that holds the API key.
	-- Studio: File > Experience Settings > Security > Local Secrets. Live: Creator Dashboard > Secrets.
	SecretName = "RoNationBridgeKey",
	-- How the key is sent. "Authorization" sends "Bearer <key>"; use "X-Api-Key" if Roblox refuses the first.
	AuthHeader = "Authorization",

	TimeoutSeconds = 10,
	-- Retries after the first attempt, always with the same operation ID.
	RetryDelays = { 1, 2, 4 },

	HealthIntervalSeconds = 30,
	ReconcileIntervalSeconds = 60,
	-- Unfinished operations older than this are settled with the bridge.
	ReconcileAfterSeconds = 30,

	-- DataStore for operations whose answer has not arrived yet (never balances).
	PendingStoreName = "RoNation_PendingEconomyOps_v1",

	-- Staging test transfer between the player's own bank and cash: 1.00 KGD.
	TestTransferAmount = 100,
}

return table.freeze(BridgeConfig)

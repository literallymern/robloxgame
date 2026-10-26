--!strict
-- Shapes of the data the server sends to the client about a player's economy account.
-- All values are read-only views of the economy bot's data. Amounts are minor units (100 = 1.00 KGD).

-- "available": the bot answers; "maintenance": the bot is in maintenance mode (read-only);
-- "unavailable": the bot cannot be reached; "not_configured": this server has no bridge address or key.
export type ServiceStatus = "unknown" | "available" | "maintenance" | "unavailable" | "not_configured"

-- Every RemoteFunction answers with this shape.
export type Reply = {
	ok: boolean,
	error: string?, -- short code, e.g. "unavailable", "refused", "rate_limited"
	message: string?, -- text that can be shown to the player
	data: any?,
}

export type AccountView = {
	status: ServiceStatus,
	linked: boolean,
	displayName: string?,
	bank: number?,
	cash: number?,
	frozen: boolean,
	creditScore: number?,
	removalEffectiveAt: string?,
	maintenance: boolean,
	asOf: string?,
	canRunTests: boolean,
}

export type LinkCode = {
	linked: boolean,
	code: string?,
	expiresAt: string?,
	command: string?,
}

export type TransactionItem = {
	id: number,
	day: number,
	direction: "in" | "out",
	amount: number,
	counterparty: string?,
	category: string,
	memo: string?,
}

return {}

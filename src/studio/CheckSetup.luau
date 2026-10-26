--!strict
-- Studio check for Justin. Run it in the Studio command bar (View > Command Bar):
--     require(game.ServerStorage.StudioTools.CheckSetup)()
-- It only reads settings and prints a report in Output. It changes nothing.

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function line(ok: boolean?, text: string)
	local mark = if ok == true then "OK  " elseif ok == false then "FIX " else "INFO"
	print(`[CheckSetup] {mark} {text}`)
end

-- Asset type 1 = Image (scripts can show it), 13 = Decal (scripts need the image ID instead).
local function checkImage(label: string, contentId: string)
	local id = tonumber(string.match(contentId, "%d+"))
	if not id then
		line(false, `{label}: no asset ID in "{contentId}"`)
		return
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, Enum.InfoType.Asset)
	end)
	if not ok or type(info) ~= "table" then
		line(false, `{label} ({id}): could not read the asset ({info})`)
	elseif info.AssetTypeId == 1 then
		line(true, `{label} ({id}) is an image: "{info.Name}"`)
	elseif info.AssetTypeId == 13 then
		line(false, `{label} ({id}) is a DECAL ID. Tell Claude; the image ID is needed instead.`)
	else
		line(false, `{label} ({id}) has asset type {info.AssetTypeId}, expected 1 (image)`)
	end
end

return function()
	local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
	local Assets = require(ReplicatedStorage.Shared.Config.Assets)

	print("[CheckSetup] ---- Ro-Nation setup check ----")
	line(
		game.GameId == GameConfig.UniverseId,
		`Experience ID {game.GameId} (expected {GameConfig.UniverseId}; 0 = not published)`
	)
	line(
		game.CreatorType == Enum.CreatorType.Group and game.CreatorId == GameConfig.GroupId,
		`Owner: {game.CreatorType.Name} {game.CreatorId} (expected Group {GameConfig.GroupId})`
	)
	line(HttpService.HttpEnabled, `Allow HTTP Requests: {HttpService.HttpEnabled}`)
	line(workspace.StreamingEnabled, `Workspace.StreamingEnabled: {workspace.StreamingEnabled}`)
	line(nil, "Studio API access cannot be read by scripts: check File > Experience Settings > Security by hand.")
	checkImage("Flag", Assets.Images.Flag)
	checkImage("Emblem", Assets.Images.Emblem)
	local remotes = ReplicatedStorage:FindFirstChild("RoNationRemotes")
	line(nil, if remotes then "Remotes exist (the game is running)." else "Remotes are created when you press Play.")
	print("[CheckSetup] ---- done ----")
end

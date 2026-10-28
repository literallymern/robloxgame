--!strict
-- Server entry point. Loads the services in a fixed order: first init() for all, then start().
-- A failing service is reported in Output and does not stop the others.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("Server")

type Service = {
	init: () -> (),
	start: () -> (),
}

-- Order matters: a service may only use services listed before it.
local ORDER = {
	"EnvironmentService",
	"PermissionService",
	"RemoteService",
	"EconomyGateway",
	"AccountLinkService",
	"DoorService",
}

-- Runs fn and returns whether it worked plus the error text if it did not.
local function try(fn: () -> ()): (boolean, string?)
	local message: string? = nil
	local ok = xpcall(fn, function(err)
		message = tostring(err)
		return nil
	end)
	return ok, message
end

local servicesFolder = script.Parent:WaitForChild("Services")
local loaded: { { name: string, service: Service } } = {}

for _, name in ORDER do
	local module = servicesFolder:FindFirstChild(name)
	if not module or not module:IsA("ModuleScript") then
		log.error(`Service {name} is missing.`)
		continue
	end
	local ok, result = pcall(require, module)
	if not ok then
		log.error(`Service {name} could not be loaded:`, result)
		continue
	end
	local service = result :: Service
	local initOk, initErr = try(service.init)
	if initOk then
		table.insert(loaded, { name = name, service = service })
	else
		log.error(`Service {name} failed to initialise:`, initErr)
	end
end

for _, entry in loaded do
	task.spawn(function()
		local ok, err = try(entry.service.start)
		if not ok then
			log.error(`Service {entry.name} failed to start:`, err)
		end
	end)
end

log.info(`{GameConfig.GameName} {GameConfig.Version} server started ({#loaded}/{#ORDER} services).`)

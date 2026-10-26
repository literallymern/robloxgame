--!strict
-- Client entry point. Starts the controllers in order; a failing controller does not stop the others.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("Client")

type Controller = {
	start: () -> (),
}

local ORDER = {
	"NotificationController",
	"UIController",
	"AccountController",
}

local controllers = script.Parent:WaitForChild("Controllers")
local started = 0

for _, name in ORDER do
	local module = controllers:FindFirstChild(name)
	if not module or not module:IsA("ModuleScript") then
		log.error(`Controller {name} is missing.`)
		continue
	end
	local ok, err = pcall(function()
		local controller = require(module) :: Controller
		controller.start()
	end)
	if ok then
		started += 1
	else
		log.error(`Controller {name} failed:`, err)
	end
end

log.info(
	`{GameConfig.GameName} {GameConfig.Version} client started for {Players.LocalPlayer.Name} ({started}/{#ORDER} controllers).`
)

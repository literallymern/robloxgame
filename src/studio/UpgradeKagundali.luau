--!strict
-- New standalone entry point also avoids a previously cached BuildMap table lacking a new method.
-- Edit-mode command: require(game.ServerStorage.StudioTools.UpgradeKagundali)()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Heightfield = require(script.Parent.Map.Heightfield)
local Update = require(script.Parent.Map.KagundaliUpdate)
local Junction = require(script.Parent.Map.JunctionLandscape)
local Util = require(script.Parent.Map.Builders.Util)

return function(options: { DryRun: boolean?, Focus: boolean? }?): any
	assert(not game:GetService("RunService"):IsRunning(), "Stop Play before upgrading the saved Kagundali junction")
	local map = workspace:FindFirstChild("Map")
	assert(map, "No saved Map. Use BuildMap.run() once for a new place")
	local layout = require(ReplicatedStorage.Shared.Config.MapLayout)
	local hf = Heightfield.new(layout, Util.yield)
	local result = Update.apply(hf, layout, map, options)
	local opts: { DryRun: boolean?, Focus: boolean? } = options or {}
	if not opts.DryRun and opts.Focus ~= false then
		local camera = workspace.CurrentCamera
		if camera then
			local target = Junction.Centre + Vector3.new(0, 5, 0)
			camera.CFrame = CFrame.lookAt(target + Vector3.new(-120, 40, 100), target)
			camera.Focus = CFrame.new(target)
		end
	end
	return result
end

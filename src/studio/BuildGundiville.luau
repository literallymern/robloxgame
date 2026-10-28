--!strict
-- Builds the Gundiville government district (Milestone 3) from
-- src/shared/Config/GovernmentDistrict.luau: streets, the main square with its market stalls,
-- the General People's Congress, the Hausali, the central bank, the Leader's residence and the
-- statue of Dr. Justin Wachmann. Terrain is not touched.
--
-- Run it in Studio in EDIT mode, from the command bar (View > Command Bar):
--     require(game.ServerStorage.StudioTools.BuildGundiville).run()
-- Statue finish for decision D3 ("Original", "Bronze" or "Stone"), statue only:
--     require(game.ServerStorage.StudioTools.BuildGundiville).statue({ Finish = "Bronze" })
-- Camera to the square:
--     require(game.ServerStorage.StudioTools.BuildGundiville).focus()
-- Remove the district and put the placeholder blocks back:
--     require(game.ServerStorage.StudioTools.BuildGundiville).remove()
--
-- Everything goes into one folder, Workspace.Map.GovernmentDistrict (attribute
-- GeneratedBy = "BuildGundiville"). A rerun replaces exactly that folder. BuildMap.run() keeps
-- it and no longer builds the placeholder blocks it replaces. Hand-built parts elsewhere stay.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Gundiville = script.Parent:WaitForChild("Gundiville")
local District = require(Gundiville.District)
local Statue = require(Gundiville.Statue)
local Kit = require(Gundiville.Kit)
local Places = require(script.Parent.Map.Builders.Places)
local Util = require(script.Parent.Map.Builders.Util)

local BuildGundiville = {}

local function log(text: string)
	print(`[Ro-Nation:BuildGundiville] {text}`)
end

local function config(): any
	return require(ReplicatedStorage.Shared.Config.GovernmentDistrict)
end

-- Runs `change` as one undo step in Studio (Ctrl+Z undoes the whole build).
local function recorded(name: string, change: () -> any): any
	local recording: string? = nil
	pcall(function()
		recording = ChangeHistoryService:TryBeginRecording(name, name)
	end)
	local ok, result = pcall(change)
	if recording then
		pcall(function()
			ChangeHistoryService:FinishRecording(
				recording,
				if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
			)
		end)
	end
	if not ok then
		error(`[Ro-Nation:BuildGundiville] Stopped, nothing was changed: {tostring(result)}`, 0)
	end
	return result
end

local function existing(map: Instance): (Instance?, boolean)
	local folder = map:FindFirstChild(District.FolderName)
	if not folder then
		return nil, true
	end
	return folder, folder:GetAttribute("GeneratedBy") == config().GeneratedBy
end

local function removePlaceholders(map: Instance, ids: { string }): number
	local folder = map:FindFirstChild("GundivillePlaceholders")
	if not folder then
		return 0
	end
	local removed = 0
	for _, child in folder:GetChildren() do
		if child:GetAttribute("Placeholder") == true and table.find(ids, child.Name) then
			child:Destroy()
			removed += 1
		end
	end
	return removed
end

function BuildGundiville.focus()
	local camera = workspace.CurrentCamera
	if camera then
		local y = config().GroundY
		camera.CFrame = CFrame.lookAt(Vector3.new(60, y + 70, 90), Vector3.new(0, y + 30, -260))
	end
end

local function summary(report: District.Report): string
	local by = {}
	for name, n in report.PartsBy do
		table.insert(by, `{name} {n}`)
	end
	table.sort(by)
	return `{report.Parts} parts ({table.concat(by, ", ")})`
end

function BuildGundiville.run(options: Statue.Options?): District.Report?
	if RunService:IsRunning() then
		warn("[Ro-Nation:BuildGundiville] Stop Play first: the district must be built in edit mode to be saved.")
		return nil
	end
	local district = config()
	local map = Util.container(workspace, "Map")
	local old, ours = existing(map)
	if old and not ours then
		warn(
			`[Ro-Nation:BuildGundiville] Map.{District.FolderName} was not built by this tool. Rename or move it, then run again.`
		)
		return nil
	end
	local started = os.clock()
	log(`District version {district.Version}. Building streets, square, buildings and the statue...`)
	local report = recorded("Ro-Nation: build Gundiville government district", function()
		-- Build into a detached folder first; the place only changes when everything worked.
		local folder = District.newFolder(district)
		local result = District.build(district, folder, options)
		if old then
			old:Destroy()
		end
		local removed = removePlaceholders(map, district.Replaces)
		folder.Parent = map
		if removed > 0 then
			log(`Removed {removed} placeholder blocks that the district replaces.`)
		end
		return result
	end) :: District.Report
	log(`Built {summary(report)}.`)
	local s = report.Statue
	log(`Statue: {s.Source}, finish {s.Finish}, figure {string.format("%.1f", s.Height)} studs high.`)
	if report.Parts > district.MaxParts then
		warn(`[Ro-Nation:BuildGundiville] {report.Parts} parts is over the district budget of {district.MaxParts}.`)
	end
	BuildGundiville.focus()
	log(string.format("Done in %.0f s. Walk through the district, then save the place.", os.clock() - started))
	return report
end

-- Rebuilds only the statue (after placing Workspace.StatueSource or to compare finishes).
function BuildGundiville.statue(options: Statue.Options?): Statue.Report?
	if RunService:IsRunning() then
		warn("[Ro-Nation:BuildGundiville] Stop Play first.")
		return nil
	end
	local map = workspace:FindFirstChild("Map")
	local folder: Instance?, ours = nil, false
	if map then
		folder, ours = existing(map)
	end
	if not folder or not ours then
		warn("[Ro-Nation:BuildGundiville] No government district yet. Run BuildGundiville.run() first.")
		return nil
	end
	local district = config()
	local report = recorded("Ro-Nation: rebuild the statue", function()
		local scratch = Instance.new("Folder")
		Kit.resetCount()
		local result = Statue.build(district, scratch, options)
		local old = folder:FindFirstChild("LeaderStatue")
		if old then
			old:Destroy()
		end
		local statue = scratch:FindFirstChild("LeaderStatue") :: Instance
		statue.Parent = folder
		scratch:Destroy()
		return result
	end) :: Statue.Report
	log(
		`Statue rebuilt: {report.Source}, finish {report.Finish}, figure {string.format("%.1f", report.Height)} studs high.`
	)
	return report
end

-- Removes the district and restores the placeholder blocks it replaced.
function BuildGundiville.remove(): boolean
	if RunService:IsRunning() then
		warn("[Ro-Nation:BuildGundiville] Stop Play first.")
		return false
	end
	local map = workspace:FindFirstChild("Map")
	local folder: Instance?, ours = nil, false
	if map then
		folder, ours = existing(map)
	end
	if not map or not folder or not ours then
		warn("[Ro-Nation:BuildGundiville] There is no generated government district to remove.")
		return false
	end
	local district = config()
	local layout = require(ReplicatedStorage.Shared.Config.MapLayout) :: any
	recorded("Ro-Nation: remove Gundiville government district", function()
		folder:Destroy()
		local placeholders = map:FindFirstChild("GundivillePlaceholders") or Util.folder(map, "GundivillePlaceholders")
		for _, block in layout.GundivillePlaceholders do
			if table.find(district.Replaces, block.Id) and not placeholders:FindFirstChild(block.Id) then
				Places.placeholder(block, placeholders, district.GroundY)
			end
		end
		return true
	end)
	log("District removed; placeholder blocks restored.")
	return true
end

return BuildGundiville

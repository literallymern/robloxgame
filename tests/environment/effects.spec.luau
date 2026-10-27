--!nocheck
-- needs: roblox-mock
-- Executes the actual bounded rain pool under a strict geometry stand-in. No engine rendering
-- or audio playback is claimed. The mock supplies only the camera, raycasts and sound state.
local oldInstance = Instance
local oldGame = game
local sounds = {}
local dropWrites = 0
local probe = oldInstance.new("Part")
local instanceApi = getmetatable(probe)
local originalWrite = instanceApi.__newindex
local originalRead = instanceApi.__index
instanceApi.__index = function(self, key)
	if self == workspace and key == "CurrentCamera" then
		return rawget(self, "__props").CurrentCamera
	end
	return originalRead(self, key)
end
instanceApi.__newindex = function(self, key, value)
	if rawget(self, "__props").Name == "RainStreak" then
		dropWrites += 1
	end
	originalWrite(self, key, value)
end
probe:Destroy()
Instance = {
	new = function(class)
		if class ~= "Sound" then
			return oldInstance.new(class)
		end
		local sound = { IsPlaying = false }
		function sound:Play()
			self.IsPlaying = true
		end
		function sound:Stop()
			self.IsPlaying = false
		end
		function sound:Destroy()
			self.destroyed = true
		end
		table.insert(sounds, sound)
		return sound
	end,
}
Random = {
	new = function()
		return {
			NextNumber = function(_, low, high)
				return (low + high) / 2
			end,
		}
	end,
}
RaycastParams = {
	new = function()
		return {}
	end,
}
Enum.RaycastFilterType = { Exclude = {} }
local player = {}
game = {
	GetService = function(_, name)
		if name == "Players" then
			return { LocalPlayer = player }
		elseif name == "SoundService" then
			return {}
		end
		return oldGame:GetService(name)
	end,
}
local camera = { CFrame = CFrame.new(0, 12, 0), __children = {} }
rawget(workspace, "__props").CurrentCamera = camera
local roof = false
local queries = 0
rawset(workspace, "__methods", {
	Raycast = function(_, origin, direction)
		queries += 1
		if direction.Y > 0 then
			return if roof then { Position = Vector3.new(origin.X, origin.Y + 4, origin.Z) } else nil
		end
		return { Position = Vector3.new(origin.X, 0, origin.Z) }
	end,
})
local Effects = load("Client/Controllers/WeatherEffects")
local passed = 0
local function check(ok, message)
	assert(ok, message)
	passed += 1
	print("PASS " .. message)
end
local function pool()
	return camera.__children[1]
end
local function visible()
	local count = 0
	if not pool() then
		return count
	end
	for _, drop in pool():GetChildren() do
		if drop.Transparency < 1 then
			count += 1
		end
	end
	return count
end
local effects = Effects.new({ MaxStreaks = 64, Audio = { Rain = "", Thunder = "" } })
local allocated = MockStats.parts
for n = 1, 60 do
	effects:update(1 / 60, 0, 0, 1, 998 + n / 60, 0, 0)
end
check(
	pool() == nil and MockStats.parts == allocated and queries == 0,
	"clear weather creates no rain parts and makes no shelter probes"
)
effects:update(1 / 60, 1, 0, 0, 999.1, 0, 0)
check(pool() == nil and MockStats.parts == allocated, "minimal quality from startup allocates no visual rain pool")
roof = true
effects:update(1 / 60, 1, 0, 1, 999.2, 0, 0)
check(pool() == nil and MockStats.parts == allocated, "sheltered rain from startup allocates no visual rain pool")
roof = false
camera.CFrame = CFrame.new(40, 12, 0)
effects:update(1 / 60, 1, 0, 1, 1000, 0, 0)
effects:update(0.4, 1, 0, 1, 1000.4, 0, 0)
check(#pool():GetChildren() == 64 and visible() == 64, "rain uses one fixed 64-part pool")
local clearances = true
for _, drop in pool():GetChildren() do
	clearances = clearances
		and drop.CanCollide == false
		and drop.CanQuery == false
		and drop.CanTouch == false
		and drop.Position.Y - drop.Size.Y / 2 > 0
end
check(clearances, "rain parts do not collide and remain above sampled ground")
local before = queries
for n = 1, 60 do
	effects:update(1 / 60, 1, 0, 1, 1000 + n / 60, 0, 0)
end
local highQueries = queries - before
check(highQueries <= 85, "stationary high-quality rain stays within 85 terrain and shelter queries per second")
before = queries
for n = 1, 60 do
	effects:update(1 / 60, 1, 0, 1 / 3, 1001 + n / 60, 0, 0)
end
local lowQueries = queries - before
check(lowQueries < highQueries and visible() <= 22, "low graphics reduces both rain geometry and terrain probing")
local oldPool = pool()
effects:update(1 / 60, 0, 0, 1, 1002.1, 0, 0)
local writesWhenHidden = dropWrites
for n = 1, 60 do
	effects:update(1 / 60, 0, 0, 1, 1002.1 + n / 60, 0, 0)
end
check(
	visible() == 0 and dropWrites == writesWhenHidden,
	"dry weather hides existing rain once and stops writing rain parts"
)
effects:update(1 / 60, 1, 0, 1, 1003, 0, 0)
check(pool() == oldPool and visible() == 64, "rain resumption reuses its pool after checking current shelter")
roof = true
camera.CFrame = CFrame.new(100, 12, 0)
before = queries
effects:update(1 / 60, 1, 0, 1, 1003, 0, 0)
check(visible() == 0 and queries > before, "camera teleport into shelter hides old rain immediately")
roof = false
camera.CFrame = CFrame.new(0, 12, 0)
for n = 1, 20 do
	effects:update(1 / 60, 1, 0, 1, 1003 + n / 60, 0, 0)
end
check(visible() > 0 and #pool():GetChildren() == 64, "rain resumes outdoors using the same bounded pool")
before = queries
for n = 1, 60 do
	effects:update(1 / 60, 1, 0, 0, 1004 + n / 60, 0, 0)
end
check(visible() == 0 and queries - before <= 3, "minimal quality disables rain rendering and shared ground probes")
local minimalWrites = dropWrites
effects:update(1 / 60, 1, 0, 0, 1005.1, 0, 0)
check(dropWrites == minimalWrites, "minimal quality does not repeatedly write hidden rain parts")
local secondCamera = { CFrame = CFrame.new(0, 12, 0), __children = {} }
rawget(workspace, "__props").CurrentCamera = secondCamera
effects:update(1 / 60, 1, 0, 1, 1006, 0, 0)
check(#camera.__children == 0 and #secondCamera.__children == 1, "camera replacement removes the old rain pool")
rawget(workspace, "__props").CurrentCamera = nil
effects:update(1 / 60, 1, 0, 1, 1006.1, 0, 0)
check(#secondCamera.__children == 0, "camera removal cleans up frozen rain geometry")
effects:destroy()
check(
	#secondCamera.__children == 0 and sounds[1].destroyed and sounds[2].destroyed,
	"effect cleanup removes local geometry and sound instances"
)
rawget(workspace, "__props").CurrentCamera = secondCamera
local audible = Effects.new({ MaxStreaks = 64, Audio = { Rain = "test-rain", Thunder = "test-thunder" } })
audible:update(1 / 60, 1, 1, 0, 2000, 2000, 0)
check(
	#secondCamera.__children == 0 and sounds[3].IsPlaying and sounds[3].Volume > 0,
	"minimal rendering quality still plays configured rain audio without allocating geometry"
)
local flash = oldGame:GetService("Lighting"):FindFirstChild("RoNationLightning")
check(flash.Enabled, "minimal rendering quality retains storm lightning")
audible:update(0.6, 1, 1, 0, 2001.6, 2000, 0)
check(sounds[4].IsPlaying and sounds[4].Volume > 0, "minimal rendering quality retains delayed thunder audio")
audible:destroy()
print(`ALL CHECKS PASSED ({passed} weather effects checks)`)

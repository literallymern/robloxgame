--!nocheck
-- Runs the actual service with a minimal scheduler and attributes, not Roblox Studio.
local Config = load("ReplicatedStorage/Shared/Config/Environment")
local Model = load("ReplicatedStorage/Shared/Environment/Model")
local now = 1000
local instances = {}
local encoded = {}
local attributeWrites = {}
local storage = { Shared = __requireNode("ReplicatedStorage/Shared") }
function storage:FindFirstChild(name)
	for _, instance in instances do
		if instance.Parent == self and instance.Name == name then
			return instance
		end
	end
	return nil
end
local lighting = {}
local http = {}
function http:JSONEncode(data)
	-- Atomic serialization is represented by a unique token holding the copied payload.
	local token = "snapshot:" .. tostring(#encoded + 1)
	table.insert(encoded, { token = token, value = data })
	return token
end
local function snapshot(folder)
	local token = folder:GetAttribute("Snapshot")
	for _, entry in encoded do
		if entry.token == token then
			return entry.value
		end
	end
	error("snapshot not serialized")
end
Instance = {}
function Instance.new(class)
	assert(class == "Folder")
	local folder = { attributes = {} }
	function folder:IsA(expected)
		return class == expected
	end
	function folder:SetAttribute(name, value)
		self.attributes[name] = value
		table.insert(attributeWrites, { name = name, value = value, time = now })
	end
	function folder:GetAttribute(name)
		return self.attributes[name]
	end
	table.insert(instances, folder)
	return folder
end
Random = {}
function Random.new()
	return {
		NextNumber = function(_, a, b)
			return if a then (a + b) / 2 else 0.6
		end,
		NextInteger = function(_, a, b)
			return math.floor((a + b) / 2)
		end,
	}
end
workspace = {
	GetServerTimeNow = function()
		return now
	end,
}
game = {
	GetService = function(_, name)
		return if name == "ReplicatedStorage"
			then storage
			elseif name == "Lighting" then lighting
			elseif name == "HttpService" then http
			else error(name)
	end,
}
task = {
	wait = function(seconds)
		now += seconds
		coroutine.yield()
	end,
}
local Service = load("Server/Services/EnvironmentService")
local passed = 0
local function check(value, message)
	assert(value, message)
	passed += 1
	print("PASS " .. message)
end
Service.init()
local folder = storage:FindFirstChild(Config.StateName)
check(
	folder ~= nil and folder:GetAttribute("ManagedBy") == "RoNationEnvironment",
	"service init publishes its owned state folder without calling nil"
)
check(
	type(folder:GetAttribute("Snapshot")) == "string" and snapshot(folder).Clock == Config.StartClockTime,
	"initial clock and weather are one atomic snapshot"
)
Service.init()
check(#instances == 1, "service initialization is idempotent")
check(not Service.setWeather("Snowstorm"), "unsupported climate conditions are rejected")
check(Service.setWeather("Rain"), "manual rain uses the same gradual transition")
local first = snapshot(folder)
now += 25
local current = Model.sample(first.From, first.To, first.Start, first.Duration, now)
check(Service.setWeather("Thunderstorm"), "manual storm transition is accepted")
local interrupted = snapshot(folder)
check(
	math.abs(interrupted.From.Rain - current.Rain) < 1e-8,
	"interrupting weather continues from the currently rendered rainfall"
)
check(Service.setClockTime(23.5), "server time override is accepted")
check(not Service.setClockTime(0 / 0) and not Service.setClockTime(math.huge), "nonfinite clock values are rejected")
local clockState = snapshot(folder)
local loop = coroutine.create(Service.start)
for _ = 1, 24 do
	local ok, err = coroutine.resume(loop)
	assert(ok, err)
end
local lightning = nil
for _, write in attributeWrites do
	if write.name == "LightningAt" then
		lightning = write
	end
end
check(
	lightning ~= nil and lightning.value > lightning.time,
	"storm scheduler publishes a future lightning timestamp without chaining nil calls"
)
check(
	lighting.ClockTime >= 0 and lighting.ClockTime < 24 and lighting.ClockTime ~= clockState.Clock,
	"service advances the baseline clock through midnight"
)
local before = #attributeWrites
Service.start()
check(#attributeWrites == before, "duplicate service start does not create another schedule")
print(`ALL CHECKS PASSED ({passed} environment service checks)`)

--!nocheck
-- needs: roblox-mock
-- Actual presentation module against the map's strict instance mock. This verifies saved-place
-- migration and effect ownership, not Roblox rendering or Studio visuals.
local Presentation = load("ReplicatedStorage/Shared/Environment/Presentation")
local Config = load("ReplicatedStorage/Shared/Config/Environment")
local lighting = game:GetService("Lighting")
local terrain = workspace.Terrain
local passed = 0
local function check(ok, message)
	assert(ok, message)
	passed += 1
	print("PASS " .. message)
end
local function reset()
	for _, parent in { lighting, terrain } do
		for _, instance in parent:GetChildren() do
			instance:Destroy()
		end
	end
end
local function make(class, name, properties)
	local instance = Instance.new(class)
	instance.Name = name
	for property, value in properties or {} do
		instance[property] = value
	end
	if instance:IsA("PostEffect") then
		instance.Enabled = true
	end
	instance.Parent = lighting
	return instance
end
local function legacy()
	return {
		make("Atmosphere", "Atmosphere", {
			Density = 0.28,
			Offset = 0.25,
			Color = Color3.new(0.78, 0.83, 0.89),
			Decay = Color3.new(0.42, 0.45, 0.5),
			Glare = 0.15,
			Haze = 1.4,
		}),
		make("BloomEffect", "Bloom", { Intensity = 0.6, Size = 24, Threshold = 1.6 }),
		make("SunRaysEffect", "SunRays", { Intensity = 0.06, Spread = 0.8 }),
		make("ColorCorrectionEffect", "ColorCorrection", {
			Brightness = 0.01,
			Contrast = 0.06,
			Saturation = 0.08,
			TintColor = Color3.new(1, 0.99, 0.96),
		}),
	}
end
local function count(parent, class)
	local total = 0
	for _, child in parent:GetChildren() do
		if child:IsA(class) then
			total += 1
		end
	end
	return total
end
local function apply(handles)
	Presentation.apply(handles, Config.Profiles[Config.InitialWeather], Config.StartClockTime, Config.Altitude.Base)
end

-- Regression: saved pre-overhaul effects previously blocked the new atmosphere and stacked bloom.
local old = legacy()
local report = Presentation.migrateLegacy()
check(
	report.Adopted == 4 and report.RemovedDuplicates == 0 and report.KeptCustom == 0,
	"all four exact pre-overhaul project effects are adopted"
)
local handles = Presentation.new()
check(
	handles.Atmosphere == old[1] and handles.Bloom == old[2],
	"migration keeps the original instances as controlled handles"
)
apply(handles)
check(
	old[2].Intensity == 0.08 and old[4].Saturation < 0,
	"saved bright bloom and saturation are replaced with the natural preset"
)
check(
	old[1].Density ~= 0.28 and old[1]:GetAttribute("ManagedBy") == "RoNationEnvironment",
	"old atmosphere now receives the new lighting model"
)
check(
	count(lighting, "Atmosphere") == 1 and count(lighting, "BloomEffect") == 1,
	"migration does not stack atmosphere or bloom effects"
)
report = Presentation.migrateLegacy()
check(report.Adopted == 0 and report.RemovedDuplicates == 0, "legacy lighting migration is idempotent")

reset()
old = legacy()
local newBloom = make("BloomEffect", "RoNationBloom", { Intensity = 0.08, Size = 18, Threshold = 1.8 })
report = Presentation.migrateLegacy()
check(
	report.Adopted == 3 and report.RemovedDuplicates == 1,
	"a proven old duplicate is removed when its new reserved counterpart exists"
)
check(
	lighting:FindFirstChild("Bloom") == nil and lighting:FindFirstChild("RoNationBloom") == newBloom,
	"duplicate cleanup preserves the new reserved effect"
)
check(count(lighting, "BloomEffect") == 1, "old and new bloom no longer stack")

reset()
old = legacy()
old[1].Density = 0.41
old[2].Intensity = 0.35
report = Presentation.migrateLegacy()
check(report.Adopted == 2 and report.KeptCustom == 2, "edited old-name atmosphere and bloom remain custom")
handles = Presentation.new()
check(
	handles.Atmosphere == nil and handles.Bloom == nil and #handles.Skipped == 2,
	"conflicting custom components are reported as skipped"
)
apply(handles)
check(old[1].Density == 0.41 and old[2].Intensity == 0.35, "custom lighting values are never overwritten")
check(
	count(lighting, "Atmosphere") == 1 and count(lighting, "BloomEffect") == 1,
	"custom lighting does not cause an extra managed effect to be created"
)

reset()
local ownedAtmosphere = make("Atmosphere", "RoNationAtmosphere", { Density = 0.22 })
local customAtmosphere = make("Atmosphere", "ArtDirectedAtmosphere", { Density = 0.4 })
local ownedBloom = make("BloomEffect", "RoNationBloom", { Intensity = 0.08 })
local customBloom = make("BloomEffect", "ArtDirectedBloom", { Intensity = 0.3 })
handles = Presentation.new()
check(
	handles.Atmosphere == nil and #handles.Skipped == 2,
	"a reserved singleton is not assumed active when another custom singleton exists"
)
check(
	handles.Bloom == nil and ownedBloom.Enabled == false and customBloom.Enabled == true,
	"custom postprocessing disables only the competing owned effect"
)
apply(handles)
check(
	ownedAtmosphere.Density == 0.22 and customAtmosphere.Density == 0.4 and customBloom.Intensity == 0.3,
	"conflicted atmosphere handles and custom effects remain unchanged"
)
customBloom:Destroy()
handles = Presentation.new()
check(handles.Bloom == ownedBloom and ownedBloom.Enabled, "managed bloom resumes when its custom conflict is removed")

reset()
old = legacy()
old[2].Enabled = false
report = Presentation.migrateLegacy()
check(
	report.Adopted == 3 and report.KeptCustom == 1 and old[2].Enabled == false,
	"a user's disabled legacy effect is preserved"
)
handles = Presentation.new()
check(
	handles.Bloom ~= nil and count(lighting, "BloomEffect") == 2 and old[2].Enabled == false,
	"disabled custom effects do not block an active managed effect"
)

reset()
old = legacy()
local originalGetService = game.GetService
game.GetService = function(self, name)
	if name == "RunService" then
		return {
			IsRunning = function()
				return true
			end,
		}
	end
	return originalGetService(self, name)
end
local ok = pcall(Presentation.migrateLegacy)
game.GetService = originalGetService
check(
	not ok and old[1].Name == "Atmosphere" and old[2].Name == "Bloom",
	"legacy migration refuses Play mode without modifying anything"
)
print(`ALL CHECKS PASSED ({passed} presentation checks)`)

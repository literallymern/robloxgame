--!strict
-- Opens and closes the doors of the government buildings. Every working door is a model tagged
-- "RoNationDoor" (built by StudioTools Architecture.Openings): its leaf parts carry the attribute
-- MovesWithLeaf, the model (or, for a double door, each leaf model inside it) carries the hinge
-- point and the opening angle, and a ProximityPrompt "DoorPrompt" sits on the first leaf.
--
-- At start the service gives each leaf an invisible anchored hinge part, welds the leaf parts to
-- it and unanchors them, so turning the hinge swings the whole leaf; the server tweens the hinge
-- and the movement replicates to every client. There is no remote: the prompt is the only
-- input, and each door ignores triggers while it is still moving. Doors marked StartOpen are
-- opened at start. Access rules for doors follow with the institutional gameplay (Milestone 6).

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Service = {}

Service.Tag = "RoNationDoor"
Service.SwingSeconds = 0.5
Service.Cooldown = 0.6 -- seconds between two swings of the same door

type Leaf = { Hinge: BasePart, Closed: CFrame, Open: CFrame }
export type Door = {
	Model: Model,
	Leaves: { Leaf },
	Open: boolean,
	Last: number,
	Prompt: ProximityPrompt?,
}

local doors: { [Instance]: Door } = {}
local connections: { RBXScriptConnection } = {}
local started = false

-- The leaf models of a door: the model itself when it carries a hinge, else its child models
-- that do (the two leaves of a double door).
local function leafModels(model: Model): { Model }
	if model:GetAttribute("Hinge") ~= nil then
		return { model }
	end
	local list: { Model } = {}
	for _, child in model:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("Hinge") ~= nil then
			table.insert(list, child)
		end
	end
	return list
end

local function findPrompt(model: Model): ProximityPrompt?
	for _, item in model:GetDescendants() do
		if item:IsA("ProximityPrompt") and item.Name == "DoorPrompt" then
			return item
		end
	end
	return nil
end

-- Swings a door open or shut (instantly when `instant`).
function Service.set(door: Door, open: boolean, instant: boolean?)
	door.Open = open
	door.Last = os.clock()
	for _, leaf in door.Leaves do
		local goal = if open then leaf.Open else leaf.Closed
		if instant then
			leaf.Hinge.CFrame = goal
		else
			local info = TweenInfo.new(Service.SwingSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(leaf.Hinge, info, { CFrame = goal }):Play()
		end
	end
	local prompt = door.Prompt
	if prompt then
		prompt.ActionText = if open then "Close" else "Open"
	end
end

-- Toggles a door unless it is still moving. Returns whether it swung.
function Service.toggle(door: Door): boolean
	if os.clock() - door.Last < Service.Cooldown then
		return false
	end
	Service.set(door, not door.Open)
	return true
end

-- Prepares one tagged door model. Returns nil when it is not a usable door.
function Service.register(instance: Instance): Door?
	if doors[instance] or not instance:IsA("Model") then
		return doors[instance]
	end
	local model = instance :: Model
	local leaves: { Leaf } = {}
	for _, leafModel in leafModels(model) do
		local at = leafModel:GetAttribute("Hinge")
		local angle = leafModel:GetAttribute("OpenAngle")
		if typeof(at) ~= "Vector3" or typeof(angle) ~= "number" then
			continue
		end
		local hinge = Instance.new("Part")
		hinge.Name = "DoorHinge"
		hinge.Size = Vector3.new(0.2, 0.2, 0.2)
		hinge.Transparency = 1
		hinge.CanCollide = false
		hinge.CanQuery = false
		hinge.CanTouch = false
		hinge.Anchored = true
		hinge.CFrame = CFrame.new(at :: Vector3)
		hinge.Parent = leafModel
		for _, item in leafModel:GetDescendants() do
			if item:IsA("BasePart") and item:GetAttribute("MovesWithLeaf") then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = hinge
				weld.Part1 = item
				weld.Parent = item
				item.Anchored = false
			end
		end
		local closed = hinge.CFrame
		local leaf: Leaf = {
			Hinge = hinge,
			Closed = closed,
			Open = closed * CFrame.Angles(0, math.rad(angle :: number), 0),
		}
		table.insert(leaves, leaf)
	end
	if #leaves == 0 then
		return nil
	end
	local door: Door = { Model = model, Leaves = leaves, Open = false, Last = -math.huge, Prompt = findPrompt(model) }
	doors[model] = door
	local prompt = door.Prompt
	if prompt then
		table.insert(
			connections,
			prompt.Triggered:Connect(function()
				Service.toggle(door)
			end)
		)
	end
	Service.set(door, model:GetAttribute("StartOpen") == true, true)
	door.Last = -math.huge
	return door
end

function Service.get(model: Instance): Door?
	return doors[model]
end

function Service.count(): number
	local n = 0
	for _ in doors do
		n += 1
	end
	return n
end

-- Stops listening to prompts and tags (tests; a server never needs it).
function Service.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(doors)
	started = false
end

function Service.init() end

function Service.start()
	if started then
		return
	end
	started = true
	for _, instance in CollectionService:GetTagged(Service.Tag) do
		Service.register(instance)
	end
	table.insert(
		connections,
		CollectionService:GetInstanceAddedSignal(Service.Tag):Connect(function(instance: Instance)
			Service.register(instance)
		end)
	)
	table.insert(
		connections,
		CollectionService:GetInstanceRemovedSignal(Service.Tag):Connect(function(instance: Instance)
			doors[instance] = nil
		end)
	)
end

return Service

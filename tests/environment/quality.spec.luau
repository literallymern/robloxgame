--!nocheck
-- Actual quality controller and UI helpers with event/attribute stand-ins. This checks
-- interaction and layout constraints, not Roblox font measurement or touchscreen rendering.
local instances = {}
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			table.insert(callbacks, callback)
		end,
		Fire = function()
			for _, callback in callbacks do
				callback()
			end
		end,
	}
end
local classes = {
	Frame = true,
	ScreenGui = true,
	TextButton = true,
	TextLabel = true,
	UICorner = true,
	UIPadding = true,
	UIListLayout = true,
	UISizeConstraint = true,
	UITextSizeConstraint = true,
	ScrollingFrame = true,
}
Instance = {
	new = function(class)
		assert(classes[class], `Unexpected UI instance {class}`)
		local item = { ClassName = class }
		if class == "TextButton" then
			item.Activated = signal()
		end
		table.insert(instances, item)
		return item
	end,
}
Color3 = {
	new = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
	fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end,
}
Vector2 = {
	new = function(x, y)
		return { X = x, Y = y }
	end,
}
UDim = {
	new = function(scale, offset)
		return { Scale = scale, Offset = offset }
	end,
}
UDim2 = {
	new = function(xs, xo, ys, yo)
		return { X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }
	end,
}
function UDim2.fromScale(x, y)
	return UDim2.new(x, 0, y, 0)
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x, 0, y)
end
Enum = {
	AutomaticSize = { None = "None", X = "X", Y = "Y" },
	Font = { Gotham = "Gotham", GothamBold = "GothamBold" },
	TextXAlignment = { Left = "Left" },
	SortOrder = { LayoutOrder = "LayoutOrder" },
	FillDirection = { Vertical = "Vertical", Horizontal = "Horizontal" },
	ZIndexBehavior = { Sibling = "Sibling" },
	ScrollingDirection = { Y = "Y" },
}
local attributes, changed = {}, {}
local playerGui = {}
local player = {}
function player:GetAttribute(key)
	return attributes[key]
end
function player:SetAttribute(key, value)
	local previous = attributes[key]
	attributes[key] = value
	if previous ~= value and changed[key] then
		changed[key]:Fire()
	end
end
function player:GetAttributeChangedSignal(key)
	changed[key] = changed[key] or signal()
	return changed[key]
end
function player:WaitForChild(name)
	assert(name == "PlayerGui")
	return playerGui
end
game = {
	GetService = function(_, name)
		if name == "Players" then
			return { LocalPlayer = player }
		elseif name == "ReplicatedStorage" then
			return { Shared = __requireNode("ReplicatedStorage/Shared") }
		end
		error(`Quality controls unexpectedly requested {name}`)
	end,
}
local Config = load("ReplicatedStorage/Shared/Config/Environment")
local Ui = load("Client/Util/Ui")
local UIController = load("Client/Controllers/UIController")
local Controller = load("Client/Controllers/EnvironmentQualityController")
local passed = 0
local function check(ok, label)
	assert(ok, label)
	passed += 1
	print("PASS " .. label)
end
local function find(predicate)
	for _, item in instances do
		if predicate(item) then
			return item
		end
	end
	error("Expected UI element not found")
end
Config.Enabled = false
Controller.start()
check(#instances == 0, "disabled weather creates no quality UI")
Config.Enabled = true
UIController.start()
Controller.start()
local count = #instances
Controller.start()
check(#instances == count, "repeated quality startup creates no duplicate controls")
local window = find(function(item)
	return item.Name == "EnvironmentQualityWindow"
end)
local choices = find(function(item)
	return item.Name == "QualityChoices"
end)
local status = find(function(item)
	return item.ClassName == "TextLabel" and string.find(item.Text, "Ausgewählt:", 1, true) ~= nil
end)
local menu = find(function(item)
	return item.ClassName == "TextButton" and item.Text == "Wetter"
end)
local close = find(function(item)
	return item.ClassName == "TextButton" and item.Text == "Schließen"
end)
local buttons = {}
for _, item in instances do
	if item.Parent == choices and item.ClassName == "TextButton" then
		table.insert(buttons, item)
	end
end
table.sort(buttons, function(a, b)
	return a.LayoutOrder < b.LayoutOrder
end)
check(#buttons == 5 and buttons[1].Text == "Automatisch", "five accessible weather choices include automatic mode")
check(
	window.Parent == UIController.getScreen() and not window.Visible and attributes[Config.QualityAttribute] == nil,
	"quality window starts closed without overriding Roblox graphics preferences"
)
menu.Activated:Fire()
check(window.Visible, "weather menu opens the quality window")
close.Activated:Fire()
menu.Activated:Fire()
menu.Activated:Fire()
check(not window.Visible, "close button and repeated menu activation close the window")
local valuesCorrect, highlightsCorrect = true, true
for index = 2, #buttons do
	buttons[index].Activated:Fire()
	valuesCorrect = valuesCorrect and attributes[Config.QualityAttribute] == index - 2
	for i, button in buttons do
		highlightsCorrect = highlightsCorrect
			and button.BackgroundColor3 == (if i == index then Ui.Colors.Accent else Ui.Colors.Panel)
	end
	highlightsCorrect = highlightsCorrect and string.find(status.Text, buttons[index].Text, 1, true) ~= nil
end
check(valuesCorrect, "minimal through high buttons write the renderer's four supported quality values")
check(highlightsCorrect, "selection highlight and status track every chosen quality")
buttons[1].Activated:Fire()
check(
	attributes[Config.QualityAttribute] == nil and buttons[1].BackgroundColor3 == Ui.Colors.Accent,
	"automatic removes the override after manual selection"
)
player:SetAttribute(Config.QualityAttribute, 1)
check(
	buttons[3].BackgroundColor3 == Ui.Colors.Accent and string.find(status.Text, "Niedrig", 1, true) ~= nil,
	"external quality changes update the visible selection"
)
local bounds = find(function(item)
	return item.Parent == window and item.ClassName == "UISizeConstraint"
end)
local fits = true
for _, viewport in { Vector2.new(320, 240), Vector2.new(360, 640), Vector2.new(1920, 1080) } do
	local w = math.min(bounds.MaxSize.X, window.Size.X.Scale * viewport.X + window.Size.X.Offset)
	local h = math.min(bounds.MaxSize.Y, window.Size.Y.Scale * viewport.Y + window.Size.Y.Offset)
	local choiceHeight = choices.Size.Y.Scale * h + choices.Size.Y.Offset
	fits = fits and w <= viewport.X and h <= viewport.Y and choiceHeight >= 44
end
check(
	fits
		and choices.AutomaticCanvasSize == Enum.AutomaticSize.Y
		and choices.ScrollingDirection == Enum.ScrollingDirection.Y,
	"quality panel fits small viewports with scrolling choices"
)
local touchTargets = true
for _, button in buttons do
	touchTargets = touchTargets and button.Size.Y.Offset >= 44
end
check(touchTargets, "quality choices retain usable touch target heights")
print(`ALL CHECKS PASSED ({passed} environment quality checks)`)

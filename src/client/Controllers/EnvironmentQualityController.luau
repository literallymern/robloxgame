--!strict
-- Session-local weather detail controls; the environment renderer follows this attribute.
-- Automatic removes the override and follows Roblox's saved graphics quality again.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Environment)
local Ui = require(script.Parent.Parent.Util.Ui)
local UIController = require(script.Parent.UIController)

local Controller = {}
local started = false
type Option = { Label: string, Value: number? }
local OPTIONS: { Option } = {
	{ Label = "Automatic", Value = nil },
	{ Label = "Minimal", Value = 0 },
	{ Label = "Low", Value = 1 },
	{ Label = "Medium", Value = 2 },
	{ Label = "High", Value = 3 },
}

function Controller.start()
	if started or not Config.Enabled then
		return
	end
	local player = Players.LocalPlayer
	local window = Instance.new("Frame")
	window.Name = "EnvironmentQualityWindow"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.new(1, -24, 1, -24)
	window.BackgroundColor3 = Ui.Colors.Background
	window.Visible = false
	window.ZIndex = 5
	Ui.corner(window, 10)
	local bounds = Instance.new("UISizeConstraint")
	bounds.MaxSize = Vector2.new(430, 436)
	bounds.Parent = window

	local title = Ui.label(window, 0, "Weather effects", 20)
	title.Position = UDim2.fromOffset(16, 14)
	title.Size = UDim2.new(1, -128, 0, 30)
	title.AutomaticSize = Enum.AutomaticSize.None
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Ui.Colors.Accent
	title.TextScaled = true
	local titleSize = Instance.new("UITextSizeConstraint")
	titleSize.MinTextSize = 12
	titleSize.MaxTextSize = 20
	titleSize.Parent = title
	local close = Ui.button(window, 0, "Close", Ui.Colors.Panel)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Activated:Connect(function()
		window.Visible = false
	end)

	local description = Ui.label(window, 0, "Fewer rain effects can make the game run more smoothly.", 14)
	description.Position = UDim2.fromOffset(16, 52)
	description.Size = UDim2.new(1, -32, 0, 44)
	description.AutomaticSize = Enum.AutomaticSize.None
	description.TextColor3 = Ui.Colors.Muted

	local choices = Instance.new("ScrollingFrame")
	choices.Name = "QualityChoices"
	choices.BackgroundTransparency = 1
	choices.BorderSizePixel = 0
	choices.Position = UDim2.fromOffset(16, 102)
	choices.Size = UDim2.new(1, -32, 1, -146)
	choices.CanvasSize = UDim2.fromOffset(0, 0)
	choices.AutomaticCanvasSize = Enum.AutomaticSize.Y
	choices.ScrollingDirection = Enum.ScrollingDirection.Y
	choices.ScrollBarThickness = 4
	Ui.list(choices, 8)
	choices.Parent = window

	local status = Ui.label(window, 0, "", 14)
	status.Position = UDim2.new(0, 16, 1, -38)
	status.Size = UDim2.new(1, -32, 0, 30)
	status.AutomaticSize = Enum.AutomaticSize.None
	status.TextColor3 = Ui.Colors.Muted
	local buttons: { TextButton } = {}
	for index, option in OPTIONS do
		local button = Ui.button(choices, index, option.Label, Ui.Colors.Panel)
		button.Name = `Quality{index}`
		button.Size = UDim2.new(1, -10, 0, 44)
		button.AutomaticSize = Enum.AutomaticSize.None
		button.Activated:Connect(function()
			player:SetAttribute(Config.QualityAttribute, option.Value)
		end)
		buttons[index] = button
	end
	local function render()
		local current = player:GetAttribute(Config.QualityAttribute)
		local selected = 1
		for index, option in OPTIONS do
			if current == option.Value then
				selected = index
			end
		end
		for index, button in buttons do
			button.BackgroundColor3 = if index == selected then Ui.Colors.Accent else Ui.Colors.Panel
		end
		status.Text = `Selected: {OPTIONS[selected].Label} · this session only`
	end
	player:GetAttributeChangedSignal(Config.QualityAttribute):Connect(render)
	UIController.addMenuButton("Weather").Activated:Connect(function()
		window.Visible = not window.Visible
	end)
	window.Parent = UIController.getScreen()
	render()
	started = true
end

return Controller

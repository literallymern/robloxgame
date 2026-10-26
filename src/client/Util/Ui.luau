--!strict
-- Small helpers to build the interface in code (no uploaded assets needed).

local Ui = {}

Ui.Colors = table.freeze({
	Background = Color3.fromRGB(24, 28, 34),
	Panel = Color3.fromRGB(34, 40, 48),
	Text = Color3.fromRGB(235, 238, 242),
	Muted = Color3.fromRGB(160, 168, 178),
	Accent = Color3.fromRGB(196, 154, 44), -- gold from the national emblem
	Good = Color3.fromRGB(46, 160, 90),
	Bad = Color3.fromRGB(192, 57, 43),
	Info = Color3.fromRGB(46, 134, 193),
})

function Ui.corner(parent: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
end

function Ui.padding(parent: GuiObject, pixels: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, pixels)
	padding.PaddingBottom = UDim.new(0, pixels)
	padding.PaddingLeft = UDim.new(0, pixels)
	padding.PaddingRight = UDim.new(0, pixels)
	padding.Parent = parent
end

function Ui.list(parent: GuiObject, spacing: number, horizontal: boolean?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, spacing)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	layout.Parent = parent
	return layout
end

function Ui.label(parent: Instance, order: number, text: string, size: number?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Font = Enum.Font.Gotham
	label.TextSize = size or 16
	label.TextColor3 = Ui.Colors.Text
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.RichText = false
	label.Text = text
	label.LayoutOrder = order
	label.Parent = parent
	return label
end

function Ui.button(parent: Instance, order: number, text: string, color: Color3?): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 0, 0, 36)
	button.AutomaticSize = Enum.AutomaticSize.X
	button.BackgroundColor3 = color or Ui.Colors.Accent
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.TextColor3 = Color3.new(1, 1, 1)
	button.AutoButtonColor = true
	button.Text = text
	button.LayoutOrder = order
	Ui.corner(button, 6)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = button
	button.Parent = parent
	return button
end

function Ui.row(parent: Instance, order: number): Frame
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 36)
	row.LayoutOrder = order
	Ui.list(row, 8, true)
	row.Parent = parent
	return row
end

return Ui

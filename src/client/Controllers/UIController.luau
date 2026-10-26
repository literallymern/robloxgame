--!strict
-- The main interface: one ScreenGui with a small menu in the top-left corner.
-- Other controllers add their buttons and windows here.

local Players = game:GetService("Players")

local Ui = require(script.Parent.Parent.Util.Ui)

local UIController = {}

local screen: ScreenGui? = nil
local menu: Frame? = nil
local nextOrder = 0

function UIController.getScreen(): ScreenGui
	local gui = screen
	assert(gui, "UIController.start has not run")
	return gui
end

-- Adds a button to the top-left menu.
function UIController.addMenuButton(text: string): TextButton
	local bar = menu
	assert(bar, "UIController.start has not run")
	nextOrder += 1
	return Ui.button(bar, nextOrder, text, Ui.Colors.Panel)
end

function UIController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RoNationUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local bar = Instance.new("Frame")
	bar.Name = "Menu"
	bar.BackgroundTransparency = 1
	bar.Position = UDim2.new(0, 12, 0, 12)
	bar.Size = UDim2.new(0, 0, 0, 36)
	bar.AutomaticSize = Enum.AutomaticSize.X
	Ui.list(bar, 8, true)
	bar.Parent = gui

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screen = gui
	menu = bar
end

return UIController

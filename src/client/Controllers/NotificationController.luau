--!strict
-- Short notices at the bottom of the screen ("toasts"), from the server or from other controllers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Ui = require(script.Parent.Parent.Util.Ui)

export type Kind = "info" | "success" | "error"

local NotificationController = {}

local container: Frame? = nil

function NotificationController.show(message: string, kind: Kind?)
	local holder = container
	if not holder then
		return
	end
	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.new(1, 0, 0, 0)
	toast.AutomaticSize = Enum.AutomaticSize.Y
	toast.BackgroundColor3 = if kind == "success"
		then Ui.Colors.Good
		elseif kind == "error" then Ui.Colors.Bad
		else Ui.Colors.Info
	toast.Font = Enum.Font.GothamMedium
	toast.TextSize = 15
	toast.TextColor3 = Color3.new(1, 1, 1)
	toast.TextWrapped = true
	toast.Text = message
	Ui.corner(toast, 6)
	Ui.padding(toast, 10)
	toast.Parent = holder
	task.delay(6, function()
		toast:Destroy()
	end)
end

function NotificationController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RoNationNotifications"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -90)
	frame.Size = UDim2.new(0, 420, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	local layout = Ui.list(frame, 6)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	frame.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	container = frame

	Remotes.getEvent(Remotes.Events.Notify).OnClientEvent:Connect(function(message: unknown, kind: unknown)
		if type(message) == "string" then
			local k: Kind = if kind == "success" then "success" elseif kind == "error" then "error" else "info"
			NotificationController.show(message, k)
		end
	end)
end

return NotificationController

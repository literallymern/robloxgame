-- Ein Script (läuft auf dem Server).
-- Landet in Studio unter ServerScriptService > Server > Start

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Begruessung = require(ReplicatedStorage.Shared.Begruessung)

print("[Server] Das Spiel ist gestartet.")

Players.PlayerAdded:Connect(function(player)
	print("[Server] " .. Begruessung.text(player.Name))
end)

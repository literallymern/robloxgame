-- Ein LocalScript (läuft beim Spieler auf dem Gerät).
-- Landet in Studio unter StarterPlayer > StarterPlayerScripts > Client > Start

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Begruessung = require(ReplicatedStorage.Shared.Begruessung)

print("[Client] " .. Begruessung.text(Players.LocalPlayer.Name))

--!strict
-- Basic facts about the experience. Shared by server and client, so nothing secret goes here.

local GameConfig = {
	GameName = "Ro-Nation",
	Version = "0.1.0 (Milestone 1)",

	-- The published experience (Creator Dashboard: experiences/10773079581) and its owner group.
	UniverseId = 10773079581,
	GroupId = 60169080,

	-- Owner account (LiterallyDrJustin). Gets Owner rights in game.
	OwnerUserId = 2595858454,
	-- Group members with this rank or higher count as staff (proposal; change when the group ranks are set up).
	StaffMinGroupRank = 250,

	MaxPlayers = 25,
}

return table.freeze(GameConfig)

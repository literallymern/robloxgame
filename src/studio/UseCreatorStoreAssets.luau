--!strict
-- Run in Studio edit mode after Rojo sync and a fresh Studio start.
return function(): any
	local assets = require(script.Parent.Map.CreatorAssets)
	assets.install()
	return require(script.Parent.UpgradeKagundali)()
end

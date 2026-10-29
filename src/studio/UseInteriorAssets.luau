--!strict
-- Installs (or refreshes) the interior asset library from the official Roblox Creator Store
-- packs (Architecture/StoreAssets.luau). Run in Studio EDIT mode from the command bar:
--     require(game.ServerStorage.StudioTools.UseInteriorAssets)()
-- then rebuild the district so the rooms use it:
--     require(game.ServerStorage.StudioTools.BuildGundiville).run()
return function(): any
	local StoreAssets = require(script.Parent.Architecture.StoreAssets)
	local library, report = StoreAssets.install()
	print(
		`[Ro-Nation:InteriorAssets] {report.Templates} templates and {report.Variants} material variants in ServerStorage.{library.Name}.`
	)
	if #report.Missing > 0 then
		warn(
			`[Ro-Nation:InteriorAssets] Not found in the packs (custom furniture is used instead): {table.concat(
				report.Missing,
				", "
			)}`
		)
	end
	return report
end

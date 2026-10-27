--!strict
-- needs: roblox-mock
-- Exports the real tapered source blades and generated tree transforms for a software
-- geometry preview. It does not serialize a Roblox boolean result or simulate its renderer.
local Library = load("StudioTools/Map/Builders/CanopyLibrary")
local Builder = load("StudioTools/Map/Builders/Vegetation")
for _, kind in Library.Kinds do
	for variant = 1, Library.Variants do
		for _, source in Library.blueprint(kind, variant) do
			local f = source.Frame
			local p, r, u, b = f.Position, f.RightVector, f.UpVector, -f.LookVector
			print(
				string.format(
					"BLADE %s %d %s %.8f %.8f %.8f %.8f %.8f %.8f %.8f %.8f %.8f %.8f %.8f %.8f %.8f %.8f %.8f",
					kind,
					variant,
					source.Geometry,
					p.X,
					p.Y,
					p.Z,
					source.Size.X,
					source.Size.Y,
					source.Size.Z,
					r.X,
					r.Y,
					r.Z,
					u.X,
					u.Y,
					u.Z,
					b.X,
					b.Y,
					b.Z
				)
			)
		end
	end
end
for index, kind in { "Broadleaf", "Acacia", "Eucalyptus", "Pine" } do
	local root = Instance.new("Folder")
	Builder.tree(root, { Kind = kind, X = index * 70, Y = 0, Z = 0, Size = 30, Yaw = 0.2, Seed = 0.43, Slope = 0.15 })
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") then
			local frame = if part:IsA("PartOperation") then part.ExtentsCFrame else part.CFrame
			local p, r, u, b = frame.Position, frame.RightVector, frame.UpVector, -frame.LookVector
			print(
				string.format(
					"TREE %s %s %s %d %.8f %.8f %.8f %.8f %.8f %.8f %.8f %.8f %.8f %.8f %.8f %.8f %.8f %.8f %.8f %.8f %.8f %.8f",
					kind,
					part.Name,
					part:GetAttribute("CanopySpecies") or "Stem",
					part:GetAttribute("CanopyVariant") or 0,
					p.X - index * 70,
					p.Y,
					p.Z,
					part.Size.X,
					part.Size.Y,
					part.Size.Z,
					r.X,
					r.Y,
					r.Z,
					u.X,
					u.Y,
					u.Z,
					b.X,
					b.Y,
					b.Z,
					part.Color.R,
					part.Color.G,
					part.Color.B
				)
			)
		end
	end
end

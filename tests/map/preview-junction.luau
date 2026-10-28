-- needs: roblox-mock
local T = load("StudioTools/Map/Builders/JunctionTrees")
for _, kind in T.Kinds do
	for group, parts in T.blueprint(kind, 1).Groups do
		for _, s in parts do
			local f = s.Frame
			local p, r, u, b = f.Position, f.RightVector, f.UpVector, -f.LookVector
			print(
				"SOURCE",
				kind,
				group,
				s.Form,
				p.X,
				p.Y,
				p.Z,
				s.Size.X,
				s.Size.Y,
				s.Size.Z,
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
		end
	end
end

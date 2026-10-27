--!strict
-- Reinforced concrete bridges on the existing road profile: asphalt wearing course, edge
-- beams, open steel parapets, abutments and supported spans. Nothing moves a road anchor.

local Heightfield = require(script.Parent.Parent.Heightfield)
local Hash = require(script.Parent.Parent.Hash)
local Roads = require(script.Parent.Roads)
local Util = require(script.Parent.Util)

local Bridges = {}

local DECK_THICKNESS = 3
local WEARING = 0.24
local UP = Vector3.new(0, 1, 0)
local MAX_SPAN = 64
local POST_SPACING = 10

type BridgeFrame = { Position: Vector3, Along: Vector3, Across: Vector3 }

local function frameAt(road: any, s: number): BridgeFrame
	local line = road.line
	local lo, hi = 1, #line.s
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if line.s[mid] <= s then
			lo = mid
		else
			hi = mid
		end
	end
	local t = math.clamp((s - line.s[lo]) / (line.s[hi] - line.s[lo]), 0, 1)
	local a = Vector3.new(line.xs[lo], road.profile[lo], line.zs[lo])
	local b = Vector3.new(line.xs[hi], road.profile[hi], line.zs[hi])
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
	return { Position = a:Lerp(b, t), Along = flat, Across = Vector3.new(-flat.Z, 0, flat.X) }
end

-- Rock protection is tied to the retaining-wall toe, never distributed through the river
-- or driving surface. The chute is only built when that toe is below the deck drain.
local function approachDrainage(
	hf: Heightfield.Heightfield,
	parent: Instance,
	frame: BridgeFrame,
	outward: Vector3,
	width: number,
	side: number,
	seed: number
): number
	local across = frame.Across * side
	local toe = frame.Position + outward * 9 + across * (width / 2 + 5)
	local count = 0
	local stone: Util.PartOptions = {
		Material = Enum.Material.Rock,
		Color = Color3.fromRGB(112, 109, 100),
		Decoration = true,
	}
	for k = 1, 4 do
		local along = (k - 2.5) * 1.8
		local position = toe + outward * along + across * Hash.range(seed, k, 151, 0, 2.5)
		local ground, _, water = hf.surface(position.X, position.Z)
		local edge = hf.roads.nearest(position.X, position.Z)
		-- Do not put bank protection on a different road or in the open water channel.
		if not edge or edge < 2.5 or (water and water > ground + 0.5) then
			continue
		end
		local size = Hash.range(seed, k, 152, 1.8, 3.2)
		local centre = Vector3.new(position.X, ground + size * 0.1, position.Z)
		local block = Util.wedge(
			parent,
			"AbutmentRiprap",
			CFrame.new(centre) * CFrame.Angles(0.18, Hash.range(seed, k, 153, 0, math.pi * 2), -0.16),
			Vector3.new(size * 1.35, size, size * 1.1),
			stone
		)
		block:SetAttribute("GroundY", ground)
		count += 1
	end
	local exitGround, _, water = hf.surface(toe.X, toe.Z)
	local start = frame.Position - outward * 2 + across * (width / 2 + 1.8) - UP * 0.65
	local finish = Vector3.new(toe.X, exitGround + 0.15, toe.Z)
	local edge = hf.roads.nearest(finish.X, finish.Z)
	if start.Y - finish.Y >= 1.1 and start.Y - finish.Y <= 8 and edge and edge > 3 and water == nil then
		local lining: Util.PartOptions = {
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(121, 119, 110),
			Decoration = true,
		}
		Util.strip(parent, "ApproachDrainInvert", start, finish, 1.05, 0.18, lining)
		local offset = across * 0.59
		for _, wallSide in { -1, 1 } do
			Util.strip(
				parent,
				"ApproachDrainEdge",
				start + offset * wallSide + UP * 0.3,
				finish + offset * wallSide + UP * 0.3,
				0.13,
				0.35,
				lining
			)
		end
		count += 3
	end
	return count
end

function Bridges.build(hf: Heightfield.Heightfield, parent: Instance): number
	local folder = Util.folder(parent, "Bridges")
	local total = 0
	local concrete: Util.PartOptions = { Material = Enum.Material.Concrete, Color = Color3.fromRGB(143, 141, 132) }
	local footing: Util.PartOptions = { Material = Enum.Material.Concrete, Color = Color3.fromRGB(116, 115, 107) }
	local asphalt: Util.PartOptions = { Material = Enum.Material.Asphalt, Color = Color3.fromRGB(61, 61, 64) }
	local steel: Util.PartOptions = { Material = Enum.Material.Metal, Color = Color3.fromRGB(133, 138, 139) }
	local seam: Util.PartOptions =
		{ Material = Enum.Material.Metal, Color = Color3.fromRGB(57, 58, 57), Decoration = true }
	for bridgeIndex, bridge in hf.roads.bridges do
		local road = hf.roads.roads[bridge.RoadIndex]
		local model = Instance.new("Model")
		model.Name = `Bridge {bridge.Road}`
		model:SetAttribute("Road", bridge.Road)
		model:SetAttribute("EnvironmentDetailVersion", 3)
		-- The structural slab projects beyond the original carriageway; its top is below
		-- the wearing course. Asphalt finishes at exactly the existing road elevation.
		local structure = table.clone(road)
		structure.Width = road.Width + 2.4
		structure.profile = table.create(#road.profile)
		for i, y in road.profile do
			structure.profile[i] = y - WEARING
		end
		total += Roads.buildRuns(model, structure, {
			Bridge = true,
			Thickness = DECK_THICKNESS - WEARING,
			Part = concrete,
			First = bridge.First,
			Last = bridge.Last,
		})
		total += Roads.buildRuns(model, road, {
			Bridge = true,
			Thickness = WEARING,
			Part = asphalt,
			First = bridge.First,
			Last = bridge.Last,
			Weathering = true,
		})
		local firstS, lastS = road.line.s[bridge.First], road.line.s[bridge.Last]
		local length = lastS - firstS
		-- A shallow edge beam and two steel rails follow each straight deck run. These
		-- sit outside the traffic lanes, retaining the original usable road width.
		for _, run in road.runs do
			if not run.Bridge or run.First < bridge.First or run.Last > bridge.Last then
				continue
			end
			local a = frameAt(road, road.line.s[run.First])
			local b = frameAt(road, road.line.s[run.Last])
			local flat = Vector3.new(b.Position.X - a.Position.X, 0, b.Position.Z - a.Position.Z).Unit
			local across = Vector3.new(-flat.Z, 0, flat.X)
			for side = -1, 1, 2 do
				local offset = across * (road.Width / 2 + 0.65) * side
				Util.strip(
					model,
					"EdgeBeam",
					a.Position + offset + UP * 0.45,
					b.Position + offset + UP * 0.45,
					0.8,
					1.5,
					concrete
				)
				for _, height in { 1.6, 3.4 } do
					Util.strip(
						model,
						"ParapetRail",
						a.Position + offset + UP * height,
						b.Position + offset + UP * height,
						0.2,
						0.28,
						steel
					)
				end
				total += 3
			end
		end
		local postCount = math.ceil(length / POST_SPACING)
		for k = 0, postCount do
			local f = frameAt(road, firstS + length * k / postCount)
			for side = -1, 1, 2 do
				local centre = f.Position + f.Across * (road.Width / 2 + 0.65) * side + UP * 1.9
				Util.part(
					model,
					"ParapetPost",
					CFrame.lookAt(centre, centre + f.Along),
					Vector3.new(0.3, 3, 0.35),
					steel
				)
				total += 1
			end
		end
		-- Supports are spaced by structural span, rather than putting a wall across the river.
		-- Each bent has buried foundations, two columns and a cap directly below the deck.
		local spans = math.max(1, math.ceil(length / MAX_SPAN))
		for k = 1, spans - 1 do
			local f = frameAt(road, firstS + length * k / spans)
			local p = f.Position
			local bedY = hf.surface(p.X, p.Z) - 2
			local deckBottom = p.Y - DECK_THICKNESS
			local capHeight = 1.2
			local columnTop = deckBottom - capHeight
			local foundationTop = math.min(bedY + 1.2, columnTop - 1)
			if columnTop - foundationTop > 0.5 then
				local base = Vector3.new(p.X, foundationTop - 1, p.Z)
				Util.part(
					model,
					"PierFooting",
					CFrame.lookAt(base, base + f.Along),
					Vector3.new(road.Width - 3, 2, 7),
					footing
				)
				local cap = Vector3.new(p.X, deckBottom - capHeight / 2, p.Z)
				Util.part(
					model,
					"PierCap",
					CFrame.lookAt(cap, cap + f.Along),
					Vector3.new(road.Width, capHeight, 4.5),
					concrete
				)
				for side = -1, 1, 2 do
					local offset = f.Across * (road.Width * 0.27) * side
					Util.cylinder(
						model,
						"PierColumn",
						Vector3.new(p.X, foundationTop, p.Z) + offset,
						Vector3.new(p.X, columnTop, p.Z) + offset,
						2.8,
						concrete
					)
				end
				total += 4
			end
		end
		-- Abutments terminate below the driving surface. Expansion joints lie below road
		-- markings and do not collide. Wing walls retain the approach fill outside the lane.
		for endIndex, endInfo in { { firstS, -1 }, { lastS, 1 } } do
			local f = frameAt(road, endInfo[1])
			local p = f.Position
			local outward = f.Along * endInfo[2]
			local ground = hf.surface(p.X, p.Z)
			local top = p.Y - DECK_THICKNESS
			local bottom = math.min(ground - 2, top - 2)
			local centre = Vector3.new(p.X, (top + bottom) / 2, p.Z)
			Util.part(
				model,
				"Abutment",
				CFrame.lookAt(centre, centre + f.Along),
				Vector3.new(road.Width + 2.4, top - bottom, 4),
				concrete
			)
			Util.part(
				model,
				"AbutmentFooting",
				CFrame.lookAt(Vector3.new(p.X, bottom - 0.7, p.Z), Vector3.new(p.X, bottom - 0.7, p.Z) + f.Along),
				Vector3.new(road.Width + 4, 1.4, 6),
				footing
			)
			Util.strip(
				model,
				"ExpansionJoint",
				p - f.Across * road.Width / 2 + UP * 0.028,
				p + f.Across * road.Width / 2 + UP * 0.028,
				0.18,
				0.02,
				seam
			)
			total += 3
			for side = -1, 1, 2 do
				local a = p + f.Across * (road.Width / 2 + 1) * side - UP * 0.05
				local b = p + outward * 9 + f.Across * (road.Width / 2 + 4) * side - UP * 0.45
				Util.strip(model, "WingWall", a, b, 0.7, 3, concrete)
				total += 1
				total += approachDrainage(
					hf,
					model,
					f,
					outward,
					road.Width,
					side,
					bridgeIndex * 10 + endIndex * 2 + side
				)
			end
		end
		model.Parent = folder
		Util.yield()
	end
	return total
end

return Bridges

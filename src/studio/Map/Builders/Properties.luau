--!strict
-- Plot markers for the 16 state properties of the economy bot. Each plot is a flat, see-through
-- slab tagged "PropertyPlot" with the property's name, city and type as attributes. The bot
-- knows properties by name; their database IDs are looked up through the bridge in a later
-- milestone. Buildings on the plots follow in Milestones 3 and 5.

local CollectionService = game:GetService("CollectionService")

local Heightfield = require(script.Parent.Parent.Heightfield)
local Util = require(script.Parent.Util)

local Properties = {}

Properties.TAG = "PropertyPlot"

function Properties.build(hf: Heightfield.Heightfield, layout: any, parent: Instance): number
	local folder = Util.folder(parent, "Properties")
	for _, property in layout.Properties do
		local r = property.Rect
		local cx, cz = (r.MinX + r.MaxX) / 2, (r.MinZ + r.MaxZ) / 2
		local groundY = hf.surface(cx, cz)
		local plot = Util.part(
			folder,
			property.Name,
			CFrame.new(cx, groundY + 0.1, cz),
			Vector3.new(r.MaxX - r.MinX, 0.2, r.MaxZ - r.MinZ),
			{ Color = Color3.fromRGB(80, 200, 120), Material = Enum.Material.SmoothPlastic, Transparency = 0.45 }
		)
		plot.CanCollide = false
		plot.CanTouch = false
		plot.CastShadow = false
		plot:SetAttribute("PropertyName", property.Name)
		plot:SetAttribute("City", property.City)
		plot:SetAttribute("PropertyType", property.Type)
		CollectionService:AddTag(plot, Properties.TAG)
		Util.label(plot, property.Name, 6, 250, 260)
	end
	return #layout.Properties
end

return Properties

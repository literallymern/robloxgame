-- Ein ModuleScript: Code, den Server UND Client benutzen können.
-- Landet in Studio unter ReplicatedStorage > Shared > Begruessung

local Begruessung = {}

function Begruessung.text(name: string): string
	return "Hallo " .. name .. "! Rojo funktioniert :)"
end

return Begruessung

--!strict
-- Text formatting for the interface. Amounts are integers in minor units (100 = 1.00 KGD),
-- exactly as the economy bot stores them.

local Format = {}

-- 250000 -> "2,500.00 KGD"
function Format.kgd(minor: number): string
	local negative = minor < 0
	local abs = math.abs(math.round(minor))
	local whole = abs // 100
	local cents = abs % 100
	local digits = tostring(whole)
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,")
	grouped = grouped:reverse()
	if grouped:sub(1, 1) == "," then
		grouped = grouped:sub(2)
	end
	return `{if negative then "-" else ""}{grouped}.{string.format("%02d", cents)} KGD`
end

-- ISO time from the bot ("2026-10-26T08:00:00.000Z") -> local clock time ("10:00"), or "" if unreadable.
function Format.localTime(iso: string?): string
	if type(iso) ~= "string" then
		return ""
	end
	local ok, dateTime = pcall(DateTime.fromIsoDate, iso)
	if not ok then
		return ""
	end
	return dateTime:FormatLocalTime("HH:mm", "en-us")
end

return Format

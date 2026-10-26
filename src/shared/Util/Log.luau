--!strict
-- Small logger with a prefix, so Output lines show where they come from.
-- Never log secrets, API keys or full request headers.

export type Logger = {
	info: (...any) -> (),
	warn: (...any) -> (),
	error: (...any) -> (),
}

local Log = {}

function Log.new(tag: string): Logger
	local prefix = `[Ro-Nation:{tag}]`
	return {
		info = function(...: any)
			print(prefix, ...)
		end,
		warn = function(...: any)
			warn(prefix, ...)
		end,
		error = function(...: any)
			warn(prefix, "ERROR:", ...)
		end,
	}
end

return Log

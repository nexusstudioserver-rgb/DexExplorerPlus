--[[
	Dex++ LOADER — safe version (prints real errors instead of "attempt to call a nil value")
	Paste this whole thing in your executor and press Execute.
]]

local URLS = {
	"https://raw.githubusercontent.com/nexusstudioserver-rgb/DexExplorerPlus/main/out.lua",
	"https://cdn.jsdelivr.net/gh/nexusstudioserver-rgb/DexExplorerPlus@main/out.lua",
	"https://github.com/nexusstudioserver-rgb/DexExplorerPlus/releases/latest/download/out.lua",
}

local function log(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring(select(i, ...))
	end
	print("[DexLoader] " .. table.concat(parts, " "))
end

-- 1) do we even have the functions people take for granted?
log("loadstring:", type(loadstring))
log("game.HttpGet:", type(game.HttpGet))
if typeof then log("typeof loadstring:", typeof(loadstring)) end

local compile = loadstring
if type(compile) ~= "function" then
	compile = load -- Lua's `load` sometimes still exists
	log("loadstring missing, falling back to load:", type(compile))
end
if type(compile) ~= "function" then
	log("ERROR: this executor has no loadstring AND no load -> cannot run downloaded scripts at all.")
	return
end
if type(game.HttpGet) ~= "function" then
	log("ERROR: no game:HttpGet -> cannot download the script.")
	return
end

-- 2) download (try every mirror until one gives real Lua code)
local source, usedUrl
for _, url in ipairs(URLS) do
	local ok, body = pcall(function()
		return game:HttpGet(url, true)
	end)
	local looksLikeLua = ok
		and type(body) == "string"
		and #body > 5000
		and body:sub(1, 1) ~= "<"                 -- HTML error page, not Lua
		and not body:lower():find("<!doctype", 1, true)
		and body:find("Dex", 1, true) ~= nil

	if looksLikeLua then
		source, usedUrl = body, url
		log(string.format("downloaded OK: %.0f KB from %s", #body / 1024, url))
		break
	else
		local why
		if not ok then
			why = tostring(body):sub(1, 120)
		elseif type(body) ~= "string" then
			why = "got " .. type(body)
		elseif #body < 5000 then
			why = "too short (" .. #body .. " bytes)"
		elseif body:sub(1, 1) == "<" then
			why = string.format("%.0f KB of HTML (404 / error page), not Lua", #body / 1024)
		else
			why = "does not look like Dex++"
		end
		log("failed:", url, "->", why)
	end
end

if not source then
	log("ERROR: every mirror failed. Check the username/repo name, or open the URL in your phone browser.")
	log("If the browser shows the Lua code but this fails, your executor is blocking raw.githubusercontent.com.")
	return
end

-- 3) compile
local chunk, compileErr = compile(source, "Dex++")
if not chunk then
	log("ERROR: compile failed ->", compileErr)
	return
end
log("compiled OK, executing Dex++ ...")

-- 4) run
local ok, err = pcall(chunk)
if ok then
	log("Dex++ finished without errors.")
else
	log("ERROR while running Dex++ ->", err)
end

--!nonstrict
-- Roster data ported from DMS PokeDash PokeDashGenerator.js
-- Each entry: name, dexId, frameW/H (kept for sizing), animated flag.

local M = {}

M.defaultRoster = {
	{ name = "Pikachu", dexId = 25, frameW = 32, frameH = 32, animated = true },
	{ name = "Bulbasaur", dexId = 1, frameW = 32, frameH = 32, animated = true },
	{ name = "Charmander", dexId = 4, frameW = 32, frameH = 32, animated = true },
	{ name = "Squirtle", dexId = 7, frameW = 32, frameH = 32, animated = true },
	{ name = "Mew", dexId = 151, frameW = 32, frameH = 32, animated = true },
	{ name = "Gengar", dexId = 94, frameW = 32, frameH = 32, animated = true },
	{ name = "Eevee", dexId = 133, frameW = 32, frameH = 32, animated = true },
	{ name = "Lucario", dexId = 448, frameW = 32, frameH = 32, animated = true },
	{ name = "Mimikyu", dexId = 778, frameW = 32, frameH = 32, animated = true },
	{ name = "Snorlax", dexId = 143, frameW = 32, frameH = 32, animated = true },
	{ name = "Lugia", dexId = 249, frameW = 32, frameH = 32, animated = true },
	{ name = "Moltres", dexId = 146, frameW = 32, frameH = 32, animated = true },
	{ name = "Zapdos", dexId = 145, frameW = 32, frameH = 32, animated = true },
	{ name = "Articuno", dexId = 144, frameW = 32, frameH = 32, animated = true },
	{ name = "Cyndaquil", dexId = 155, frameW = 32, frameH = 32, animated = true },
	{ name = "Dragonite", dexId = 149, frameW = 32, frameH = 32, animated = true },
	{ name = "Vulpix", dexId = 37, frameW = 32, frameH = 32, animated = true },
	{ name = "Abra", dexId = 63, frameW = 32, frameH = 32, animated = true },
	{ name = "Jigglypuff", dexId = 39, frameW = 32, frameH = 32, animated = true },
	{ name = "Psyduck", dexId = 54, frameW = 32, frameH = 32, animated = true },
	{ name = "Meowth", dexId = 52, frameW = 32, frameH = 32, animated = true },
	{ name = "Ditto", dexId = 132, frameW = 32, frameH = 32, animated = true },
	{ name = "Cubone", dexId = 104, frameW = 32, frameH = 32, animated = true },
	{ name = "Bellsprout", dexId = 69, frameW = 32, frameH = 32, animated = true },
	{ name = "Zoobat", dexId = 41, frameW = 32, frameH = 32, animated = true },
	{ name = "Arcanine", dexId = 59, frameW = 32, frameH = 32, animated = true },
	{ name = "Exeggutor", dexId = 103, frameW = 32, frameH = 32, animated = true },
	{ name = "Machamp", dexId = 68, frameW = 32, frameH = 32, animated = true },
	{ name = "Lapras", dexId = 131, frameW = 32, frameH = 32, animated = true },
	{ name = "Aerodactyl", dexId = 142, frameW = 32, frameH = 32, animated = true },
	{ name = "Cloyster", dexId = 91, frameW = 32, frameH = 32, animated = true },
	{ name = "Gastly", dexId = 92, frameW = 32, frameH = 32, animated = true },
	{ name = "Haunter", dexId = 93, frameW = 32, frameH = 32, animated = true },
	{ name = "Scyther", dexId = 123, frameW = 32, frameH = 32, animated = true },
	{ name = "Onix", dexId = 95, frameW = 32, frameH = 32, animated = true },
	{ name = "Slowpoke", dexId = 79, frameW = 32, frameH = 32, animated = true },
	{ name = "Geodude", dexId = 74, frameW = 32, frameH = 32, animated = true },
	{ name = "Butterfree", dexId = 12, frameW = 32, frameH = 32, animated = true },
	{ name = "Beedrill", dexId = 15, frameW = 32, frameH = 32, animated = true },
	{ name = "Pidgeot", dexId = 18, frameW = 32, frameH = 32, animated = true },
	{ name = "Raticate", dexId = 20, frameW = 32, frameH = 32, animated = true },
	{ name = "Arbok", dexId = 24, frameW = 32, frameH = 32, animated = true },
	{ name = "Sandslash", dexId = 28, frameW = 32, frameH = 32, animated = true },
	{ name = "Ninetales", dexId = 38, frameW = 32, frameH = 32, animated = true },
	{ name = "Tauros", dexId = 128, frameW = 32, frameH = 32, animated = true },
}

function M.getByName(name, roster)
	local list = roster and #roster > 0 and roster or M.defaultRoster
	for _, e in ipairs(list) do
		if e.name == name then return e end
	end
	return list[1]
end

function M.spriteUrl(dexId, style)
	if style == "showdown" then
		return "https://raw.githubusercontent.com/PokeAPI/sprites/refs/heads/master/sprites/pokemon/other/showdown/" .. tostring(dexId) .. ".gif"
	end
	return "https://raw.githubusercontent.com/PokeAPI/sprites/refs/heads/master/sprites/pokemon/versions/generation-v/black-white/animated/" .. tostring(dexId) .. ".gif"
end

return M

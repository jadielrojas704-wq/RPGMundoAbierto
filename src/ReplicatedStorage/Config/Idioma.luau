-- IDIOMA del juego (cliente y servidor).
-- Ruta en Studio: ReplicatedStorage/Config/Idioma
--
--   * Los SUBTÍTULOS y textos de la historia salen en el idioma de cada jugador:
--       - "Auto" (de fábrica): el idioma de su cuenta de Roblox (español si es español; si no, inglés)
--       - o el que elija en Menú M > Ajustes > Idioma (se guarda en su personaje: Ajustes.Idioma)
--   * Las VOCES siempre hablan en inglés (Idioma.Ingles).
--   * Los textos originales están en español (HistoriaConfig, PueblosConfig...);
--     su traducción al inglés está en ReplicatedStorage/Config/IdiomaIngles.
--
--   Idioma.T("texto en español")      -> el texto en el idioma del jugador
--   Idioma.Ingles("texto en español") -> el texto en inglés (para la voz)
--   Idioma.Actual()                    -> "es" o "en"
--   Idioma.Cambio                      -> evento cuando el jugador cambia de idioma

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local INGLES = require(script.Parent.IdiomaIngles)

local Idioma = {}

Idioma.OPCIONES = {
	{ id = "Auto", nombre = "Automático (tu Roblox)", nombreEn = "Auto (Roblox language)" },
	{ id = "es", nombre = "Español", nombreEn = "Spanish" },
	{ id = "en", nombre = "English", nombreEn = "English" },
}
Idioma.VALIDOS = { Auto = true, es = true, en = true }

local evento = Instance.new("BindableEvent")
Idioma.Cambio = evento.Event

-- Nombres de los pueblos: si el texto ya trae el nombre puesto, se vuelve a {pueblo} para buscarlo
local nombresPueblos = nil
local function pueblos()
	if not nombresPueblos then
		nombresPueblos = {}
		local ok, PueblosConfig = pcall(function()
			return require(script.Parent.PueblosConfig)
		end)
		if ok and PueblosConfig.PUEBLOS then
			for _, p in PueblosConfig.PUEBLOS do
				if p.nombre then
					table.insert(nombresPueblos, p.nombre)
				end
			end
		end
	end
	return nombresPueblos
end

local function escaparPatron(texto)
	return (string.gsub(texto, "[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0"))
end

-- Texto en inglés (si no hay traducción, se devuelve tal cual)
function Idioma.Ingles(texto)
	if type(texto) ~= "string" or texto == "" then
		return texto
	end
	local directo = INGLES[texto]
	if directo then
		return directo
	end
	-- frases con el nombre del pueblo ya puesto
	for _, nombre in pueblos() do
		if string.find(texto, nombre, 1, true) then
			local plantilla = string.gsub(texto, escaparPatron(nombre), "{pueblo}")
			local traducida = INGLES[plantilla]
			if traducida then
				return (string.gsub(traducida, "{pueblo}", nombre))
			end
		end
	end
	-- "Ahora tu tarea es esta: <objetivo>." (lo dice el Custodio)
	local objetivo = string.match(texto, "^Ahora tu tarea es esta: (.-)%.$")
	if objetivo then
		return "Your task now is this: " .. (INGLES[objetivo] or objetivo) .. "."
	end
	return texto
end

-- ===== Idioma de este jugador (en el cliente) =====
local function deRoblox()
	local ok, codigo = pcall(function()
		return game:GetService("LocalizationService").RobloxLocaleId
	end)
	if ok and type(codigo) == "string" and string.sub(string.lower(codigo), 1, 2) == "es" then
		return "es"
	end
	return "en"
end

function Idioma.Actual()
	if not RunService:IsClient() then
		return "es"
	end
	local jugador = Players.LocalPlayer
	local elegido = jugador and jugador:GetAttribute("Idioma")
	if elegido == "es" or elegido == "en" then
		return elegido
	end
	return deRoblox()
end

function Idioma.T(texto)
	if Idioma.Actual() == "en" then
		return Idioma.Ingles(texto)
	end
	return texto
end

-- Elige entre dos textos fijos de la interfaz
function Idioma.Elegir(es, en)
	return if Idioma.Actual() == "en" then en else es
end

if RunService:IsClient() then
	task.spawn(function()
		local jugador = Players.LocalPlayer
		while not jugador do
			task.wait()
			jugador = Players.LocalPlayer
		end
		jugador:GetAttributeChangedSignal("Idioma"):Connect(function()
			evento:Fire(Idioma.Actual())
		end)
	end)
end

return Idioma

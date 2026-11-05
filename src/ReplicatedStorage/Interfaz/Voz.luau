-- VOCES (solo CLIENTE): convierte texto en voz con la voz artificial de Roblox
-- (AudioTextToSpeech) y le da a cada personaje su propia voz.
-- Ruta en Studio: ReplicatedStorage/Interfaz/Voz
--
--   local Voz = require(ReplicatedStorage.Interfaz.Voz)
--   Voz.Decir("Llevas dos días dormido.", Voz.PERFILES.Eldren)       -- habla y devuelve la duración
--   local linea = Voz.Preparar(texto, Voz.PERFILES.Narrador)          -- la genera antes (cinemáticas)
--   linea:Reproducir()  linea.duracion  linea:Parar()
--   Voz.PerfilNPC(npc)  -- voz fija para cada NPC (según su nombre y si es hombre o mujer)
--
-- Notas:
--   * Roblox traduce el texto al idioma del jugador y elige una voz de ese idioma (AutoLocalize).
--   * Máximo 300 letras por frase: las frases largas se cortan por los puntos.
--   * Si la voz no se puede generar (sin conexión, límite de Roblox...), no pasa nada:
--     el subtítulo sale igual y el juego sigue.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Voz = {}

-- VoiceId de Roblox: 1 británico, 2 británica, 3 y 5 estadounidenses, 4 y 6 estadounidenses,
-- 7 australiano, 8 australiana, 9 y 10 voces "retro".
local VOCES_HOMBRE = { "1", "3", "5", "7" }
local VOCES_MUJER = { "2", "4", "6", "8" }

-- tono: semitonos (-12 a 12) · velocidad: 0.5 a 2 · grave: graves potenciados
-- eco: reverberación de sala (catedral para el narrador) · volumen: 0 a 3
Voz.PERFILES = {
	-- La voz que cuenta la historia: profunda, lenta, con eco de catedral
	Narrador = { voz = "1", tono = -6, velocidad = 0.84, grave = true, eco = 0.55, volumen = 1.7 },
	-- El Custodio: un anciano sabio, voz cansada y algo grave
	Eldren = { voz = "1", tono = -3, velocidad = 0.9, grave = true, eco = 0.12, volumen = 1.6 },
	-- Inscripciones de los Guardianes (al leer un texto antiguo)
	Guardian = { voz = "2", tono = -2, velocidad = 0.86, grave = false, eco = 0.45, volumen = 1.4 },
}

local VOLUMEN_GENERAL = 1

-- ===== Cadena de audio: voz -> ecualizador -> eco -> salida =====
local carpeta = SoundService:FindFirstChild("Voces") or Instance.new("Folder")
carpeta.Name = "Voces"
carpeta.Parent = SoundService

local function cable(desde, hasta)
	local w = Instance.new("Wire")
	w.SourceInstance = desde
	w.TargetInstance = hasta
	w.Parent = desde
	return w
end

local function cadena(perfil)
	local tts = Instance.new("AudioTextToSpeech")
	tts.VoiceId = perfil.voz or "1"
	pcall(function()
		tts.Pitch = perfil.tono or 0
	end)
	tts.Speed = perfil.velocidad or 1
	tts.Volume = math.clamp((perfil.volumen or 1.3) * VOLUMEN_GENERAL, 0, 3)
	tts.Parent = carpeta
	local ultimo = tts
	if perfil.grave then
		local eq = Instance.new("AudioEqualizer")
		pcall(function()
			eq.LowGain = 5
			eq.MidGain = 1
			eq.HighGain = -3
		end)
		eq.Parent = tts
		cable(ultimo, eq)
		ultimo = eq
	end
	if perfil.eco and perfil.eco > 0 then
		local reverb = Instance.new("AudioReverb")
		pcall(function()
			reverb.DecayTime = 1 + perfil.eco * 4
			reverb.WetLevel = -14 + perfil.eco * 10
			reverb.DryLevel = 0
			reverb.Density = 1
			reverb.Diffusion = 1
		end)
		reverb.Parent = tts
		cable(ultimo, reverb)
		ultimo = reverb
	end
	local salida = Instance.new("AudioDeviceOutput")
	salida.Parent = tts
	cable(ultimo, salida)
	return tts
end

-- Corta el texto en trozos de menos de 300 letras (por frases)
local function trozos(texto)
	texto = string.gsub(texto, "\n", " ")
	texto = string.gsub(texto, "%s+", " ")
	if #texto <= 280 then
		return { texto }
	end
	local lista, actual = {}, ""
	for frase in string.gmatch(texto, "[^%.%!%?]+[%.%!%?]*") do
		if #actual + #frase > 280 and actual ~= "" then
			table.insert(lista, actual)
			actual = ""
		end
		actual ..= frase
	end
	if actual ~= "" then
		table.insert(lista, actual)
	end
	return lista
end

-- ===== Límite de Roblox: unas 4 voces nuevas por segundo por jugador =====
-- Se espera turno para no pasarse (si no, Roblox responde "Rate limited").
-- Cola en orden (la primera frase pedida es la primera que se genera), una cada ~1 s.
local SEPARACION = 1.05
local siguienteTurno = 0 -- número del próximo turno que se da
local turnoActual = 0 -- turno al que le toca ahora
local ultimaPeticion = -10
local function esperarTurno()
	local mio = siguienteTurno
	siguienteTurno += 1
	while turnoActual ~= mio or os.clock() - ultimaPeticion < SEPARACION do
		task.wait(0.05)
	end
	ultimaPeticion = os.clock()
	turnoActual += 1
end

-- ===== Línea preparada =====
local Linea = {}
Linea.__index = Linea

-- Genera la voz (tarda un momento). Devuelve la línea con .duracion en segundos.
function Voz.Preparar(texto, perfil)
	perfil = perfil or Voz.PERFILES.Narrador
	local linea = setmetatable({ partes = {}, duracion = 0, parada = false }, Linea)
	if not texto or texto == "" then
		return linea
	end
	local hilos = {}
	local terminadas = 0
	local lista = trozos(texto)
	for i, trozo in lista do
		local tts = cadena(perfil)
		tts.Text = trozo
		linea.partes[i] = tts
		table.insert(hilos, task.spawn(function()
			esperarTurno()
			local ok, estado = pcall(function()
				return tts:LoadAsync()
			end)
			if not ok or estado ~= Enum.AssetFetchStatus.Success then
				-- un segundo intento, por si fue el límite de Roblox
				task.wait(1.2)
				esperarTurno()
				ok, estado = pcall(function()
					return tts:LoadAsync()
				end)
			end
			if not ok or estado ~= Enum.AssetFetchStatus.Success then
				linea.partes[i] = false
				tts:Destroy()
			end
			terminadas += 1
		end))
	end
	-- espera a que se hayan generado todas (en la cola puede haber otras antes)
	local inicio = os.clock()
	while terminadas < #lista and os.clock() - inicio < 40 do
		task.wait(0.05)
	end
	for _, tts in linea.partes do
		if tts and tts.IsLoaded then
			linea.duracion += tts.TimeLength / math.max(tts.PlaybackSpeed, 0.01)
		end
	end
	return linea
end

function Linea:Reproducir()
	self.parada = false
	task.spawn(function()
		for _, tts in self.partes do
			if self.parada then
				break
			end
			if tts and tts.Parent and tts.IsLoaded then
				tts.TimePosition = 0
				tts:Play()
				local espera = tts.TimeLength / math.max(tts.PlaybackSpeed, 0.01)
				local inicio = os.clock()
				while os.clock() - inicio < espera + 0.1 and not self.parada do
					task.wait(0.05)
				end
			end
		end
	end)
	return self.duracion
end

function Linea:Parar(fundido)
	self.parada = true
	for _, tts in self.partes do
		if tts and tts.Parent then
			if fundido then
				TweenService:Create(tts, TweenInfo.new(fundido), { Volume = 0 }):Play()
				task.delay(fundido, function()
					if tts.Parent then
						tts:Pause()
					end
				end)
			else
				tts:Pause()
			end
		end
	end
end

function Linea:Destruir()
	self:Parar()
	for _, tts in self.partes do
		if tts and tts.Parent then
			tts:Destroy()
		end
	end
	table.clear(self.partes)
end

-- ===== Uso sencillo: habla ya (corta lo que estuviera diciendo esa misma "boca") =====
local bocas = {} -- [clave] = línea que está sonando
local turnos = {} -- [clave] = número de la última frase pedida
function Voz.Decir(texto, perfil, clave, volumen)
	clave = clave or "general"
	turnos[clave] = (turnos[clave] or 0) + 1
	local miTurno = turnos[clave]
	local anterior = bocas[clave]
	bocas[clave] = nil
	if anterior then
		anterior:Destruir()
	end
	local p = perfil
	if volumen and p then
		p = table.clone(p)
		p.volumen = (p.volumen or 1.3) * volumen
	end
	local linea = Voz.Preparar(texto, p)
	if turnos[clave] ~= miTurno then
		-- mientras se generaba, ya se pidió otra frase: esta sobra
		linea:Destruir()
		return 0
	end
	bocas[clave] = linea
	local duracion = linea:Reproducir()
	task.delay(duracion + 2, function()
		if bocas[clave] == linea then
			bocas[clave] = nil
			linea:Destruir()
		end
	end)
	return duracion
end

function Voz.Callar(clave)
	turnos[clave or "general"] = (turnos[clave or "general"] or 0) + 1
	local linea = bocas[clave or "general"]
	if linea then
		bocas[clave or "general"] = nil
		linea:Parar(0.25)
		task.delay(0.4, function()
			linea:Destruir()
		end)
	end
end

-- ===== Una voz fija para cada NPC =====
local function numeroDe(texto)
	local h = 7
	for i = 1, #texto do
		h = (h * 31 + string.byte(texto, i)) % 1000003
	end
	return h
end

local cachePerfiles = {}
function Voz.PerfilNPC(npc)
	local nombre = (npc:GetAttribute("Nombre") or npc.Name) .. "/" .. tostring(npc:GetAttribute("Pueblo") or "")
	if cachePerfiles[nombre] then
		return cachePerfiles[nombre]
	end
	local h = numeroDe(nombre)
	local mujer = npc:GetAttribute("Genero") == "Mujer"
	local lista = if mujer then VOCES_MUJER else VOCES_HOMBRE
	local clase = npc:GetAttribute("Clase")
	local rol = npc:GetAttribute("Rol")
	local tono = ((h % 7) - 3) * 0.8 -- de -2.4 a +2.4 semitonos
	if rol == "Guardia" then
		tono -= 2 -- los guardias, más graves
	end
	if clase == "Noble" then
		tono += 0.5
	end
	local perfil = {
		voz = lista[(h // 7) % #lista + 1],
		tono = tono,
		velocidad = 0.92 + ((h // 31) % 5) * 0.04, -- de 0.92 a 1.08
		grave = rol == "Guardia",
		eco = 0,
		volumen = 1.3,
	}
	cachePerfiles[nombre] = perfil
	return perfil
end

return Voz

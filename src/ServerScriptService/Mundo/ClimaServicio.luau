-- Controla el clima, el viento y el ciclo de día y noche. Solo en el SERVIDOR.
-- Ruta en Studio: ServerScriptService/Mundo/ClimaServicio
--
-- Todos los jugadores ven el mismo clima porque lo decide el servidor:
--   * Workspace.GlobalWind (viento) y Lighting.ClockTime (hora) se copian solos a todos
--   * El clima actual se publica como atributo de Workspace: "Clima" y "ClimaCambio"
-- El cliente (StarterPlayerScripts/ClimaCliente) dibuja lluvia, rayos y sonidos.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Config.ClimaConfig)

local ClimaServicio = {}

local rng = Random.new()
local PASO = 0.5 -- segundos entre actualizaciones

local climaActual = "Despejado"
local climaAnterior = "Despejado"
local inicioTransicion = 0

-- Viento: dirección (ángulo en radianes) y fuerza, actual y objetivo
local anguloViento = rng:NextNumber(0, math.pi * 2)
local fuerzaViento = 4
local anguloObjetivo = anguloViento
local fuerzaObjetivo = 4

local function mezcla(a, b, t)
	return a + (b - a) * t
end

-- Elige un clima al azar según su peso (nunca repite el actual)
local function elegirClima()
	local total = 0
	for nombre, datos in Config.CLIMAS do
		if nombre ~= climaActual then
			total += datos.peso
		end
	end
	local tirada = rng:NextNumber(0, total)
	for nombre, datos in Config.CLIMAS do
		if nombre ~= climaActual then
			tirada -= datos.peso
			if tirada <= 0 then
				return nombre
			end
		end
	end
	return "Despejado"
end

local function nuevoViento(cambioGrande)
	local datos = Config.CLIMAS[climaActual]
	fuerzaObjetivo = rng:NextNumber(datos.viento[1], datos.viento[2])
	if cambioGrande then
		-- Cualquier dirección: norte, sur, este, oeste o intermedias
		anguloObjetivo = rng:NextNumber(0, math.pi * 2)
	else
		-- Pequeño giro, como el viento real
		anguloObjetivo = anguloViento + rng:NextNumber(-0.7, 0.7)
	end
end

local function cambiarClima(forzado)
	climaAnterior = climaActual
	climaActual = forzado or elegirClima()
	inicioTransicion = os.clock()
	Workspace:SetAttribute("Clima", climaActual)
	Workspace:SetAttribute("ClimaAnterior", climaAnterior)
	Workspace:SetAttribute("ClimaCambio", Workspace:GetServerTimeNow())
	nuevoViento(rng:NextNumber() < 0.6)
	print("[CLIMA] Ahora:", climaActual)
end

-- Cuánto avanzó la transición entre el clima anterior y el actual (0 a 1)
local function avanceTransicion()
	return math.clamp((os.clock() - inicioTransicion) / Config.TRANSICION, 0, 1)
end

-- ===== LUZ SEGÚN LA HORA =====
-- altura del sol: 1 al mediodía, 0 al amanecer/atardecer, negativo de noche
local function alturaSol(hora)
	return math.sin((hora - 6) / 12 * math.pi)
end

-- Paleta del cielo según la hora. El juego es realista pero con un toque de fantasía:
-- atardeceres rosados y dorados, y noches de luna color lavanda/morado.
local PALETA = {
	-- luz ambiente de exteriores (lo que ilumina las sombras)
	ambienteDia = Color3.fromRGB(140, 128, 110),
	ambienteAtardecer = Color3.fromRGB(165, 118, 132),
	ambienteNoche = Color3.fromRGB(120, 88, 190),
	-- luz ambiente de interiores
	interiorDia = Color3.fromRGB(70, 62, 55),
	interiorNoche = Color3.fromRGB(52, 38, 92),
	-- color de la luz del sol / de la luna
	solDia = Color3.fromRGB(255, 242, 222),
	solAtardecer = Color3.fromRGB(255, 150, 105),
	luna = Color3.fromRGB(176, 150, 255),
	-- nubes
	nubesDia = Color3.fromRGB(255, 249, 242),
	nubesAtardecer = Color3.fromRGB(255, 168, 150),
	nubesNoche = Color3.fromRGB(118, 92, 172),
	nubesTormenta = Color3.fromRGB(78, 80, 92),
}

local momentoDelDia = Config.Momento

local function actualizarLuz(oscuridad)
	local dia, atardecer, noche = momentoDelDia(Lighting.ClockTime)

	-- De noche la luna ilumina bastante (noche mágica, no negra), con luz lavanda
	-- (la luna no debe ser muy fuerte: si no, el cielo nocturno se vuelve azul eléctrico)
	Lighting.Brightness = mezcla(0.8, 2.6, dia) * (1 - oscuridad * 0.5)
	local ambiente = PALETA.ambienteNoche:Lerp(PALETA.ambienteDia, dia):Lerp(PALETA.ambienteAtardecer, atardecer * 0.6)
	Lighting.OutdoorAmbient = ambiente:Lerp(Color3.fromRGB(90, 92, 98), oscuridad * 0.5)
	Lighting.Ambient = PALETA.interiorNoche:Lerp(PALETA.interiorDia, dia)
	local luz = PALETA.solDia:Lerp(PALETA.solAtardecer, atardecer)
	Lighting.ColorShift_Top = luz:Lerp(PALETA.luna, noche)
	Lighting.ExposureCompensation = mezcla(0.25, 0.1, dia) - oscuridad * 0.15
	Lighting.EnvironmentDiffuseScale = mezcla(0.5, 1, dia)
	Lighting.EnvironmentSpecularScale = mezcla(0.6, 1, dia)
end

-- Color de las nubes según la hora y el clima
local function colorNubes(gris)
	local _, atardecer, noche = momentoDelDia(Lighting.ClockTime)
	local color = PALETA.nubesDia:Lerp(PALETA.nubesAtardecer, atardecer):Lerp(PALETA.nubesNoche, noche)
	return color:Lerp(PALETA.nubesTormenta, gris)
end

-- Cielo: muchas estrellas, luna grande y un sol cálido
local function prepararCielo()
	local cielo = Lighting:FindFirstChildOfClass("Sky")
	if not cielo then
		cielo = Instance.new("Sky")
		cielo.Parent = Lighting
	end
	cielo.CelestialBodiesShown = true
	cielo.StarCount = 5000 -- el máximo
	cielo.MoonAngularSize = 22
	cielo.SunAngularSize = 16
end

function ClimaServicio.Iniciar()
	Lighting.ClockTime = Config.HORA_INICIAL
	Workspace:SetAttribute("Clima", climaActual)
	Workspace:SetAttribute("ClimaAnterior", climaActual)
	Workspace:SetAttribute("ClimaCambio", Workspace:GetServerTimeNow())
	nuevoViento(true)
	prepararCielo()

	local nubes = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	local finClima = os.clock() + rng:NextNumber(Config.DURACION_CLIMA[1], Config.DURACION_CLIMA[2])
	local proximoGiro = os.clock() + rng:NextNumber(Config.CAMBIO_VIENTO[1], Config.CAMBIO_VIENTO[2])
	local horasPorSegundo = 24 / (Config.MINUTOS_POR_DIA * 60)

	-- Para probar: en Play, en la barra de comandos (vista Server) escribe por ejemplo
	--     workspace:SetAttribute("ForzarClima", "Tormenta")
	-- Solo funciona desde el servidor: un jugador no puede cambiar el clima.
	-- También se puede cambiar la hora para probar la noche:
	--     workspace:SetAttribute("ForzarHora", 22)
	Workspace:GetAttributeChangedSignal("ForzarHora"):Connect(function()
		local hora = Workspace:GetAttribute("ForzarHora")
		if typeof(hora) == "number" then
			Lighting.ClockTime = hora % 24
		end
	end)

	local climaForzado = nil
	Workspace:GetAttributeChangedSignal("ForzarClima"):Connect(function()
		local nombre = Workspace:GetAttribute("ForzarClima")
		if Config.CLIMAS[nombre] then
			climaForzado = nombre
		end
	end)

	task.spawn(function()
		while true do
			local dt = task.wait(PASO)
			local ahora = os.clock()

			if climaForzado then
				cambiarClima(climaForzado)
				climaForzado = nil
				finClima = ahora + rng:NextNumber(Config.DURACION_CLIMA[1], Config.DURACION_CLIMA[2])
			end

			-- Reloj del día
			Lighting.ClockTime = (Lighting.ClockTime + dt * horasPorSegundo) % 24

			-- ¿Toca cambiar de clima?
			if ahora >= finClima then
				cambiarClima()
				finClima = ahora + rng:NextNumber(Config.DURACION_CLIMA[1], Config.DURACION_CLIMA[2])
			end
			-- ¿Toca un giro pequeño del viento?
			if ahora >= proximoGiro then
				nuevoViento(false)
				proximoGiro = ahora + rng:NextNumber(Config.CAMBIO_VIENTO[1], Config.CAMBIO_VIENTO[2])
			end

			-- El viento se acerca poco a poco a su objetivo (nunca cambia de golpe)
			local diferencia = (anguloObjetivo - anguloViento + math.pi) % (math.pi * 2) - math.pi
			anguloViento += diferencia * math.min(1, dt * 0.05)
			fuerzaViento += (fuerzaObjetivo - fuerzaViento) * math.min(1, dt * 0.08)
			-- Ráfagas: la fuerza sube y baja un poco sola
			local rafaga = 1 + 0.35 * math.noise(ahora * 0.15, 7.3, 0)
			local fuerza = math.max(0, fuerzaViento * rafaga)
			Workspace.GlobalWind = Vector3.new(math.cos(anguloViento) * fuerza, 0, math.sin(anguloViento) * fuerza)

			-- Mezcla entre el clima anterior y el actual
			local t = avanceTransicion()
			local antes, despues = Config.CLIMAS[climaAnterior], Config.CLIMAS[climaActual]
			local oscuridad = mezcla(antes.oscuridad, despues.oscuridad, t)
			actualizarLuz(oscuridad)
			if nubes then
				nubes.Cover = mezcla(antes.nubes.Cover, despues.nubes.Cover, t)
				nubes.Density = mezcla(antes.nubes.Density, despues.nubes.Density, t)
				nubes.Color = colorNubes(mezcla(0, 0.6, oscuridad))
			end
		end
	end)
end

-- Para otros sistemas (por ejemplo, enemigos que salen de noche o con tormenta)
function ClimaServicio.ClimaActual()
	return climaActual
end

function ClimaServicio.EsDeNoche()
	return alturaSol(Lighting.ClockTime) < 0
end

return ClimaServicio

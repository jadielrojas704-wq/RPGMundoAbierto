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

local COLOR_DIA = Color3.fromRGB(140, 125, 105)
local COLOR_NOCHE = Color3.fromRGB(46, 54, 78)
local TONO_DIA = Color3.fromRGB(255, 240, 220)
local TONO_ATARDECER = Color3.fromRGB(255, 160, 90)

local function actualizarLuz(oscuridad)
	local sol = alturaSol(Lighting.ClockTime)
	local dia = math.clamp(sol * 3, 0, 1) -- 0 de noche, 1 de día
	local atardecer = math.clamp(1 - math.abs(sol) * 4, 0, 1) -- cerca del horizonte

	Lighting.Brightness = mezcla(0.35, 2.6, dia) * (1 - oscuridad * 0.5)
	Lighting.OutdoorAmbient = COLOR_NOCHE:Lerp(COLOR_DIA, dia):Lerp(Color3.fromRGB(90, 92, 98), oscuridad * 0.5)
	Lighting.ColorShift_Top = TONO_DIA:Lerp(TONO_ATARDECER, atardecer)
	Lighting.ExposureCompensation = mezcla(-0.25, 0.1, dia) - oscuridad * 0.15
	Lighting.EnvironmentDiffuseScale = mezcla(0.4, 1, dia)
end

function ClimaServicio.Iniciar()
	Lighting.ClockTime = Config.HORA_INICIAL
	Workspace:SetAttribute("Clima", climaActual)
	Workspace:SetAttribute("ClimaAnterior", climaActual)
	Workspace:SetAttribute("ClimaCambio", Workspace:GetServerTimeNow())
	nuevoViento(true)

	local nubes = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	local finClima = os.clock() + rng:NextNumber(Config.DURACION_CLIMA[1], Config.DURACION_CLIMA[2])
	local proximoGiro = os.clock() + rng:NextNumber(Config.CAMBIO_VIENTO[1], Config.CAMBIO_VIENTO[2])
	local horasPorSegundo = 24 / (Config.MINUTOS_POR_DIA * 60)

	-- Para probar: en Play, en la barra de comandos (vista Server) escribe por ejemplo
	--     workspace:SetAttribute("ForzarClima", "Tormenta")
	-- Solo funciona desde el servidor: un jugador no puede cambiar el clima.
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
				local gris = mezcla(0, 0.6, oscuridad)
				nubes.Color = Color3.fromRGB(255, 245, 230):Lerp(Color3.fromRGB(80, 84, 92), gris)
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

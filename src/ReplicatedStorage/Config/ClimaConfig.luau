-- Configuración del clima y del ciclo de día y noche.
-- Ruta en Studio: ReplicatedStorage/Config/ClimaConfig
-- El SERVIDOR elige el clima y el viento al azar (ServerScriptService/Mundo/ClimaServicio)
-- y el CLIENTE dibuja la lluvia, la nieve, la arena, los rayos y los sonidos
-- (StarterPlayerScripts/ClimaCliente).

local ClimaConfig = {}

-- ===== DÍA Y NOCHE =====
ClimaConfig.MINUTOS_POR_DIA = 24 -- minutos reales que dura un día completo del juego
ClimaConfig.HORA_INICIAL = 8 -- hora a la que empieza el servidor

-- Cómo de "día", "atardecer" y "noche" es una hora (cada valor de 0 a 1).
-- Lo usan el servidor (luz) y el cliente (cielo, colores de noche, luciérnagas).
function ClimaConfig.Momento(hora)
	local sol = math.sin((hora - 6) / 12 * math.pi) -- 1 mediodía, 0 horizonte, <0 noche
	local dia = math.clamp(sol * 3, 0, 1)
	local atardecer = math.clamp(1 - math.abs(sol + 0.02) * 4, 0, 1)
	local noche = math.clamp(-sol * 4, 0, 1)
	return dia, atardecer, noche
end

-- ===== CAMBIOS DE CLIMA =====
ClimaConfig.DURACION_CLIMA = { 240, 540 } -- segundos que dura cada clima (al azar)
ClimaConfig.TRANSICION = 40 -- segundos que tarda en pasar de un clima a otro
ClimaConfig.CAMBIO_VIENTO = { 25, 70 } -- cada cuánto el viento cambia un poco de dirección

-- Cada clima:
--   peso        -> probabilidad relativa de que salga
--   nubes       -> cuánto cielo cubren y lo espesas que son (0 a 1)
--   viento      -> fuerza mínima y máxima (studs/s)
--   precipitacion -> 0 nada, 1 máxima (lluvia; en la montaña es nieve; en el desierto no llueve)
--   niebla      -> 0 a 1, cuánta niebla añade
--   oscuridad   -> 0 a 1, cuánto oscurece el día
--   rayos       -> si hay relámpagos y truenos
ClimaConfig.CLIMAS = {
	Despejado = {
		peso = 40,
		-- algunas nubes blancas grandes: el cielo despejado no queda vacío
		nubes = { Cover = 0.55, Density = 0.5 },
		viento = { 2, 7 },
		precipitacion = 0,
		niebla = 0,
		oscuridad = 0,
	},
	Nublado = {
		peso = 24,
		nubes = { Cover = 0.82, Density = 0.7 },
		viento = { 5, 12 },
		precipitacion = 0,
		niebla = 0.1,
		oscuridad = 0.18,
	},
	Lluvia = {
		peso = 16,
		nubes = { Cover = 0.92, Density = 0.85 },
		viento = { 6, 14 },
		precipitacion = 0.55,
		niebla = 0.25,
		oscuridad = 0.32,
	},
	Tormenta = {
		peso = 8,
		nubes = { Cover = 1, Density = 1 },
		viento = { 15, 28 },
		precipitacion = 1,
		niebla = 0.35,
		oscuridad = 0.55,
		rayos = true,
	},
	Niebla = {
		peso = 12,
		nubes = { Cover = 0.6, Density = 0.6 },
		viento = { 0.5, 3 },
		precipitacion = 0,
		niebla = 0.75,
		oscuridad = 0.15,
	},
}

-- Viento a partir del cual hay tormenta de arena en el desierto
ClimaConfig.VIENTO_TORMENTA_ARENA = 12

-- ===== SONIDOS =====
local function id(numero)
	return "rbxassetid://" .. numero
end

ClimaConfig.SONIDOS = {
	-- Lluvia continua (DistroKid, con licencia para Roblox)
	LLUVIA_SUAVE = id(138758248122639),
	LLUVIA_FUERTE = id(138168228068971),
	-- Truenos (Pro Sound Effects)
	TRUENO_LEJANO = { id(9120018172), id(9120018216), id(9120018050), id(9120016738), id(9120017047) },
	TRUENO_CERCANO = { id(9120019063), id(9120020523), id(9120016037) },
	-- Ráfagas de viento (Pro Sound Effects)
	RAFAGA = { id(9120698415), id(9120697823), id(9120698168), id(9120697982), id(9120698408) },
}

return ClimaConfig

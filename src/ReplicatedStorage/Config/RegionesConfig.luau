-- Regiones del mundo: dónde está cada una, su nombre y su ambiente.
-- Ruta en Studio: ReplicatedStorage/Config/RegionesConfig
-- Lo usan el generador del mundo (para crear el terreno) y el cliente
-- (para cambiar la niebla, los colores y mostrar el nombre al entrar).
--
-- Mapa de 2048 x 2048 studs (X va de oeste a este, Z de norte a sur):
--                 NORTE: Picos del Velo (montañas) + Isla en el cielo
--   OESTE: Bosque oscuro     CENTRO/SUR: Bosque normal (inicio)     ESTE: Desierto

local RegionesConfig = {}

RegionesConfig.TAMANO = 2048
RegionesConfig.MITAD = 1024
RegionesConfig.NIVEL_AGUA = 20

RegionesConfig.INICIO = Vector2.new(-110, 560) -- (X, Z) donde aparecen los jugadores
RegionesConfig.ALTAR = Vector2.new(0, -430) -- Altar del Ascenso, al pie de las montañas
RegionesConfig.ISLA = Vector3.new(0, 900, -700) -- centro de la isla flotante
RegionesConfig.ALTURA_ISLA = 700 -- por encima de esta altura estás en la isla

local function suave(a, b, x)
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end
RegionesConfig.suave = suave

-- Cuánto pertenece un punto a cada región (los cuatro pesos suman 1)
function RegionesConfig.Pesos(x, z)
	local montana = suave(-380, -620, z)
	local resto = 1 - montana
	local desierto = suave(260, 460, x) * resto
	local oscuro = suave(-260, -460, x) * resto
	local bosque = math.max(0, resto - desierto - oscuro)
	return { Bosque = bosque, Desierto = desierto, Oscuro = oscuro, Montana = montana }
end

-- Nombre interno de la región en una posición
function RegionesConfig.RegionEn(posicion)
	if posicion.Y > RegionesConfig.ALTURA_ISLA then
		return "Isla"
	end
	local pesos = RegionesConfig.Pesos(posicion.X, posicion.Z)
	local mejor, valor = "Bosque", -1
	for nombre, peso in pesos do
		if peso > valor then
			mejor, valor = nombre, peso
		end
	end
	return mejor
end

-- Cada región: nombre en pantalla, orden de progreso y ambiente.
-- Los nombres son propuestas: cámbialos cuando quieras.
--   atmosfera  -> niebla del horizonte (Lighting > Atmosphere)
--   color      -> filtro de color (Lighting > ColorRegion)
--   particulas -> lo que flota en el aire alrededor del jugador
RegionesConfig.REGIONES = {
	Bosque = {
		nombre = "Valle de Aurelia",
		orden = 1,
		atmosfera = {
			Density = 0.32,
			Haze = 1.4,
			Glare = 0.5,
			Color = Color3.fromRGB(205, 185, 150),
			Decay = Color3.fromRGB(120, 100, 75),
		},
		color = { TintColor = Color3.fromRGB(255, 246, 232), Saturation = -0.05, Contrast = 0.1, Brightness = 0.02 },
		particulas = {
			{
				nombre = "Motas",
				color = Color3.fromRGB(255, 235, 180),
				tamano = 0.12,
				tasa = 10,
				vida = 6,
				velocidad = 0.4,
				brillo = 0.6,
				transparencia = 0.3,
			},
		},
	},
	Desierto = {
		nombre = "Dunas de Kharsa",
		orden = 2,
		atmosfera = {
			Density = 0.36,
			Haze = 2.2,
			Glare = 0.8,
			Color = Color3.fromRGB(222, 192, 142),
			Decay = Color3.fromRGB(170, 120, 70),
		},
		color = { TintColor = Color3.fromRGB(255, 238, 212), Saturation = 0, Contrast = 0.12, Brightness = 0.03 },
		particulas = {
			{
				nombre = "Arena",
				color = Color3.fromRGB(215, 190, 140),
				tamano = 0.35,
				tasa = 30,
				vida = 2.5,
				velocidad = 14,
				conViento = true,
				altura = -8,
				brillo = 0,
				transparencia = 0.55,
			},
		},
	},
	Oscuro = {
		nombre = "Bosque Sombrío de Morvane",
		orden = 3,
		atmosfera = {
			Density = 0.55,
			Haze = 2.6,
			Glare = 0,
			Color = Color3.fromRGB(88, 98, 98),
			Decay = Color3.fromRGB(38, 46, 48),
		},
		color = { TintColor = Color3.fromRGB(205, 222, 228), Saturation = -0.25, Contrast = 0.18, Brightness = -0.06 },
		particulas = {
			{
				nombre = "Luciernagas",
				color = Color3.fromRGB(200, 255, 120),
				tamano = 0.18,
				tasa = 6,
				vida = 5,
				velocidad = 0.6,
				brillo = 1,
				transparencia = 0,
				parpadeo = true,
			},
			{
				nombre = "NieblaBaja",
				color = Color3.fromRGB(120, 130, 130),
				tamano = 14,
				tasa = 3,
				vida = 9,
				velocidad = 0.5,
				altura = -9,
				brillo = 0,
				transparencia = 0.85,
				humo = true,
			},
		},
	},
	Montana = {
		nombre = "Picos del Velo",
		orden = 0,
		atmosfera = {
			Density = 0.3,
			Haze = 1.2,
			Glare = 0.3,
			Color = Color3.fromRGB(200, 210, 220),
			Decay = Color3.fromRGB(130, 140, 150),
		},
		color = { TintColor = Color3.fromRGB(240, 246, 255), Saturation = -0.1, Contrast = 0.12, Brightness = 0.02 },
		particulas = {
			{
				nombre = "Copos",
				color = Color3.fromRGB(255, 255, 255),
				tamano = 0.15,
				tasa = 25,
				vida = 6,
				velocidad = 2,
				conViento = true,
				caida = 3,
				brillo = 0.2,
				transparencia = 0.2,
			},
		},
	},
	Isla = {
		nombre = "Isla Celestial",
		orden = 4,
		atmosfera = {
			Density = 0.2,
			Haze = 0.5,
			Glare = 1,
			Color = Color3.fromRGB(255, 232, 195),
			Decay = Color3.fromRGB(255, 200, 140),
		},
		color = { TintColor = Color3.fromRGB(255, 242, 218), Saturation = 0.05, Contrast = 0.1, Brightness = 0.04 },
		particulas = {
			{
				nombre = "MotasDoradas",
				color = Color3.fromRGB(255, 215, 120),
				tamano = 0.15,
				tasa = 14,
				vida = 7,
				velocidad = 0.5,
				brillo = 1,
				transparencia = 0.1,
				parpadeo = true,
			},
		},
	},
}

return RegionesConfig

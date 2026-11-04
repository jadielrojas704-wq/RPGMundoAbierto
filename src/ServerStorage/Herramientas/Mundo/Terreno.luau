-- Terreno del mundo: alturas, materiales y la isla flotante.
-- Ruta en Studio: ServerStorage/Herramientas/Mundo/Terreno
-- Lo usa ServerStorage/Herramientas/GenerarMundo. No se ejecuta solo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Regiones = require(ReplicatedStorage.Config.RegionesConfig)
local PueblosConfig = require(ReplicatedStorage.Config.PueblosConfig)

local Terreno = {}

local RES = 4
local ALTURA_MAX = 256
local MITAD = Regiones.MITAD
local NIVEL_AGUA = Regiones.NIVEL_AGUA
local INICIO = Regiones.INICIO
local ALTAR = Regiones.ALTAR
local SEMILLA = 11

local M = Enum.Material
local suave = Regiones.suave

Terreno.SEMILLA = SEMILLA

-- Ruido en capas: formas grandes + detalles pequeños
local function ruido(x, z, capas, escala, semilla)
	local total, amplitud, frecuencia, maximo = 0, 1, 1 / escala, 0
	for _ = 1, capas do
		total += math.noise(x * frecuencia, z * frecuencia, semilla) * amplitud
		maximo += amplitud
		amplitud *= 0.5
		frecuencia *= 2
	end
	return total / maximo
end
Terreno.ruido = ruido

-- ===== RÍO, LAGOS Y CAMINOS =====

local LAGO = Vector2.new(10, 830)
local OASIS = Vector2.new(660, 240)
local PANTANO = Vector2.new(-680, 260)
Terreno.OASIS = OASIS

local function rioX(z)
	return 40 + math.sin(z / 210) * 120 + ruido(0, z, 2, 220, SEMILLA + 20) * 60
end

-- Caminos: cada uno es una línea que va del inicio a otra región
local function caminoNorteX(z)
	local avance = (z - INICIO.Y) / (ALTAR.Y - INICIO.Y)
	return INICIO.X + (ALTAR.X - INICIO.X) * avance + math.sin(z / 120) * 35
end
local function caminoEsteZ(x)
	return INICIO.Y + math.sin(x / 140) * 45 - (x - INICIO.X) * 0.25
end
local function caminoOesteZ(x)
	return INICIO.Y + math.sin(x / 130) * 45 - (INICIO.X - x) * 0.3
end

-- Puntos a lo largo de cada camino (para poner puentes, etc.)
local function puntosPrincipales(paso)
	local caminos = { Norte = {}, Este = {}, Oeste = {} }
	for z = INICIO.Y, ALTAR.Y, -paso do
		table.insert(caminos.Norte, Vector2.new(caminoNorteX(z), z))
	end
	for x = INICIO.X, 820, paso do
		table.insert(caminos.Este, Vector2.new(x, caminoEsteZ(x)))
	end
	for x = INICIO.X, -820, -paso do
		table.insert(caminos.Oeste, Vector2.new(x, caminoOesteZ(x)))
	end
	return caminos
end

-- Distancia aproximada al camino más cercano
local function distanciaCaminos(x, z)
	local mejor = math.huge
	if z <= INICIO.Y and z >= ALTAR.Y then
		mejor = math.min(mejor, math.abs(x - caminoNorteX(z)))
	end
	if x >= INICIO.X and x <= 820 then
		mejor = math.min(mejor, math.abs(z - caminoEsteZ(x)))
	end
	if x <= INICIO.X and x >= -820 then
		mejor = math.min(mejor, math.abs(z - caminoOesteZ(x)))
	end
	return mejor
end

-- ===== PUEBLOS: sitios llanos y caminos que llegan a ellos =====

local REGION_DE_CULTURA = { Reino = "Bosque", Sol = "Desierto", Brujos = "Oscuro", Norte = "Montana" }
local sitios = nil -- se calcula una sola vez (ver Terreno.SitiosPueblos)
local ramales = {} -- caminos nuevos: { puntos = {Vector2...}, minimo = Vector2, maximo = Vector2 }

-- Curva suave (Bézier) de A a B que se dobla un poco hacia un lado
local function curva(a, b, doblez)
	local medio = (a + b) / 2
	local direccion = b - a
	local lado = Vector2.new(-direccion.Y, direccion.X).Unit
	local control = medio + lado * direccion.Magnitude * doblez
	local puntos = {}
	local pasos = math.max(4, math.floor(direccion.Magnitude / 25))
	for i = 0, pasos do
		local t = i / pasos
		table.insert(puntos, a * (1 - t) ^ 2 + control * 2 * (1 - t) * t + b * t * t)
	end
	return puntos
end

local function distanciaASegmento(p, a, b)
	local ab = b - a
	local largo = ab:Dot(ab)
	if largo < 1e-6 then
		return (p - a).Magnitude
	end
	local t = math.clamp((p - a):Dot(ab) / largo, 0, 1)
	return (p - (a + ab * t)).Magnitude
end

local function distanciaRamales(x, z)
	local p = Vector2.new(x, z)
	local mejor = math.huge
	for _, ramal in ramales do
		if x > ramal.minimo.X and x < ramal.maximo.X and z > ramal.minimo.Y and z < ramal.maximo.Y then
			local puntos = ramal.puntos
			for i = 1, #puntos - 1 do
				mejor = math.min(mejor, distanciaASegmento(p, puntos[i], puntos[i + 1]))
			end
		end
	end
	return mejor
end

-- Busca, cerca de la pista de cada pueblo, el sitio más llano, seco y dentro de su región.
-- Devuelve { [id] = { centro = Vector2, radio = número, altura = número } }
function Terreno.SitiosPueblos()
	if sitios then
		return sitios
	end
	local elegidos = {}
	local listaSitios = {}
	for _, pueblo in PueblosConfig.PUEBLOS do
		local mejor, mejorPuntos = nil, math.huge
		local radio = pueblo.radio
		local busca = radio * 1.4
		local region = REGION_DE_CULTURA[pueblo.cultura]
		for gx = -busca, busca, 16 do
			for gz = -busca, busca, 16 do
				if gx * gx + gz * gz <= busca * busca then
					local c = pueblo.pista + Vector2.new(gx, gz)
					local minimo, maximo, suma, cuenta, castigo = math.huge, -math.huge, 0, 0, 0
					for anillo = 0, 2 do
						local r = radio * anillo / 2
						local vueltas = if anillo == 0 then 1 else 8
						for k = 1, vueltas do
							local angulo = k / vueltas * math.pi * 2
							local px, pz = c.X + math.cos(angulo) * r, c.Y + math.sin(angulo) * r
							local d = Terreno.muestrear(px, pz, true)
							minimo = math.min(minimo, d.altura)
							maximo = math.max(maximo, d.altura)
							suma += d.altura
							cuenta += 1
							if d.rio > 0.05 or d.lago > 0.05 or d.oasis > 0.05 or d.pantano > 0.05 then
								castigo += 400 -- nada de pueblos encima del agua
							end
							if d.altura < NIVEL_AGUA + 4 then
								castigo += 400
							end
						end
					end
					local pesos = Regiones.Pesos(c.X, c.Y)
					if (pesos[region] or 0) < 0.75 then
						castigo += 600 -- que el pueblo quede dentro de su región
					end
					-- lejos del inicio, del altar y de otros pueblos
					if (c - INICIO).Magnitude < radio + 90 or (c - ALTAR).Magnitude < radio + 80 then
						castigo += 1000
					end
					for _, otro in listaSitios do
						if (c - otro.centro).Magnitude < radio + otro.radio + 60 then
							castigo += 1000
						end
					end
					local puntos = (maximo - minimo) + castigo + (c - pueblo.pista).Magnitude * 0.03
					if puntos < mejorPuntos then
						mejorPuntos = puntos
						mejor = { centro = c, radio = radio, altura = math.max(suma / cuenta, NIVEL_AGUA + 5) }
					end
				end
			end
		end
		elegidos[pueblo.id] = mejor
		table.insert(listaSitios, mejor)
	end

	-- Caminos: cada capital se une al camino principal más cercano;
	-- cada aldea, a lo que tenga más cerca (camino principal o la capital de su región)
	local principales = {}
	for _, puntos in puntosPrincipales(8) do
		for _, punto in puntos do
			table.insert(principales, punto)
		end
	end
	local capitales = {}
	for _, pueblo in PueblosConfig.PUEBLOS do
		if pueblo.tipo == "Capital" then
			capitales[pueblo.cultura] = elegidos[pueblo.id]
		end
	end
	for i, pueblo in PueblosConfig.PUEBLOS do
		local sitio = elegidos[pueblo.id]
		local destino, distancia = nil, math.huge
		for _, punto in principales do
			local dd = (punto - sitio.centro).Magnitude
			if dd < distancia then
				destino, distancia = punto, dd
			end
		end
		local capital = capitales[pueblo.cultura]
		if pueblo.tipo ~= "Capital" and capital then
			local dd = (capital.centro - sitio.centro).Magnitude - capital.radio * 0.8
			if dd < distancia then
				destino = capital.centro + (sitio.centro - capital.centro).Unit * capital.radio * 0.8
			end
		end
		if destino and (destino - sitio.centro).Magnitude > sitio.radio then
			local doblez = (if i % 2 == 0 then 1 else -1) * 0.12
			local puntos = curva(sitio.centro, destino, doblez)
			local minimo, maximo = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
			for _, punto in puntos do
				minimo = Vector2.new(math.min(minimo.X, punto.X), math.min(minimo.Y, punto.Y))
				maximo = Vector2.new(math.max(maximo.X, punto.X), math.max(maximo.Y, punto.Y))
			end
			table.insert(ramales, {
				nombre = "Ramal_" .. pueblo.id,
				puntos = puntos,
				minimo = minimo - Vector2.new(12, 12),
				maximo = maximo + Vector2.new(12, 12),
			})
			sitio.entrada = (destino - sitio.centro).Unit -- hacia dónde mira la puerta del pueblo
		else
			sitio.entrada = Vector2.new(0, 1)
		end
	end

	sitios = elegidos
	return sitios
end

-- Puntos a lo largo de todos los caminos, también los que llevan a los pueblos
function Terreno.PuntosCaminos(paso)
	local caminos = puntosPrincipales(paso)
	Terreno.SitiosPueblos()
	for _, ramal in ramales do
		local lista = {}
		for i = 1, #ramal.puntos - 1 do
			local a, b = ramal.puntos[i], ramal.puntos[i + 1]
			local pasos = math.max(1, math.floor((b - a).Magnitude / paso))
			for k = 0, pasos - 1 do
				table.insert(lista, a + (b - a) * (k / pasos))
			end
		end
		caminos[ramal.nombre] = lista
	end
	return caminos
end

-- ===== MUESTREO: altura y zonas de cualquier punto =====

-- sinPueblos = true -> el terreno "natural", sin aplanar los pueblos (para buscar sitio)
function Terreno.muestrear(x, z, sinPueblos)
	local p = Regiones.Pesos(x, z)
	local d = { bosque = p.Bosque, desierto = p.Desierto, oscuro = p.Oscuro, montana = p.Montana }

	-- Bosque normal: colinas suaves
	local hBosque = 40 + ruido(x, z, 4, 380, SEMILLA) * 60 + ruido(x, z, 3, 70, SEMILLA + 1) * 6

	-- Desierto: dunas onduladas + mesetas rojas
	local ondas = math.sin((x * 0.6 + z * 0.8) / 38 + ruido(x, z, 2, 160, SEMILLA + 2) * 4)
	local duna = 1 - math.abs(ondas)
	local hDesierto = 36 + duna * 14 * (0.5 + ruido(x, z, 2, 250, SEMILLA + 3)) + ruido(x, z, 3, 300, SEMILLA + 4) * 25
	d.meseta = suave(0.05, 0.1, ruido(x, z, 3, 200, SEMILLA + 5))
	hDesierto += d.meseta * 85

	-- Bosque oscuro: terreno irregular con barrancos
	local hOscuro = 34
		+ ruido(x, z, 4, 260, SEMILLA + 6) * 55
		- math.abs(ruido(x, z, 3, 90, SEMILLA + 7)) * 18
		+ ruido(x, z, 3, 40, SEMILLA + 8) * 4

	-- Montañas: crestas altas
	local cresta = math.clamp(1 - math.abs(ruido(x, z, 4, 260, SEMILLA + 9) * 2.2), 0, 1) ^ 2
	local hMontana = 90 + cresta * 170 + ruido(x, z, 3, 80, SEMILLA + 10) * 15

	local h = hBosque * p.Bosque + hDesierto * p.Desierto + hOscuro * p.Oscuro + hMontana * p.Montana

	-- Montañas en los bordes del mapa
	local borde = suave(MITAD - 150, MITAD - 20, math.max(math.abs(x), math.abs(z)))
	h += borde * (110 + cresta * 90)

	-- Río (baja desde las montañas y cruza el bosque normal)
	local enRio = 1 - suave(760, 860, z) -- desemboca en el lago
	local anchoRio = 14 + ruido(z, 0, 2, 150, SEMILLA + 11) * 8
	d.rio = (1 - suave(anchoRio, anchoRio + 60, math.abs(x - rioX(z)))) * enRio * (1 - p.Desierto - p.Oscuro)
	h += ((NIVEL_AGUA - 5) - h) * d.rio

	-- Lago (bosque), oasis (desierto) y pantano (bosque oscuro)
	local function hoyo(centro, radioDentro, radioFuera, fondo)
		local distancia = (Vector2.new(x, z) - centro).Magnitude + ruido(x, z, 2, 60, SEMILLA + 12) * 30
		local peso = 1 - suave(radioDentro, radioFuera, distancia)
		h += ((NIVEL_AGUA - fondo) - h) * peso
		return peso
	end
	d.lago = hoyo(LAGO, 80, 170, 12)
	d.oasis = hoyo(OASIS, 25, 70, 6)
	d.pantano = hoyo(PANTANO, 50, 130, 4)

	-- Caminos de tierra (se hunden un poquito, como un sendero gastado)
	local distanciaCamino = distanciaCaminos(x, z)
	if not sinPueblos then
		Terreno.SitiosPueblos()
		distanciaCamino = math.min(distanciaCamino, distanciaRamales(x, z))
	end
	d.camino = 1 - suave(3, 7, distanciaCamino)
	h -= d.camino * 0.6

	-- Zonas llanas: inicio y Altar del Ascenso
	d.inicio = 1 - suave(30, 80, (Vector2.new(x, z) - INICIO).Magnitude)
	h += (40 - h) * d.inicio
	d.altar = 1 - suave(30, 70, (Vector2.new(x, z) - ALTAR).Magnitude)
	h += (62 - h) * d.altar

	-- Pueblos: el terreno se aplana suavemente alrededor de cada uno
	d.pueblo = 0 -- 1 dentro del pueblo (sin árboles), 0 lejos
	d.dentroPueblo = 0
	if not sinPueblos then
		for _, sitio in Terreno.SitiosPueblos() do
			local distancia = (Vector2.new(x, z) - sitio.centro).Magnitude
			if distancia < sitio.radio + 60 then
				local irregular = ruido(x, z, 2, 30, SEMILLA + 40) * 8
				local peso = 1 - suave(sitio.radio, sitio.radio + 45, distancia + irregular)
				h += (sitio.altura - h) * peso
				d.pueblo = math.max(d.pueblo, 1 - suave(sitio.radio + 8, sitio.radio + 25, distancia))
				d.dentroPueblo = math.max(d.dentroPueblo, 1 - suave(sitio.radio * 0.9, sitio.radio, distancia))
			end
		end
	end

	d.altura = math.clamp(h, 6, ALTURA_MAX - 6)
	d.manchas = ruido(x, z, 2, 70, SEMILLA + 13)
	d.borde = ruido(x, z, 2, 40, SEMILLA + 14) * 0.25 -- para que los límites entre regiones no sean rectos
	return d
end

function Terreno.pendienteEn(x, z)
	local a = Terreno.muestrear(x + RES, z).altura - Terreno.muestrear(x - RES, z).altura
	local b = Terreno.muestrear(x, z + RES).altura - Terreno.muestrear(x, z - RES).altura
	return math.max(math.abs(a), math.abs(b)) / (2 * RES)
end

-- ===== MATERIALES =====
-- Cada región usa materiales distintos, porque el color de cada material es
-- el mismo en todo el mapa (Grass = bosque normal, LeafyGrass = bosque oscuro...)

function Terreno.elegirMaterial(d, pendiente, x, z)
	local h = d.altura
	local esDesierto = d.desierto + d.borde > 0.5
	local esOscuro = d.oscuro + d.borde > 0.5

	if h < NIVEL_AGUA + 2.5 then
		if esDesierto then
			return M.Sand
		elseif esOscuro then
			return M.Mud
		elseif d.lago > 0.3 then
			return M.Sand
		end
		return if ruido(x, z, 1, 30, SEMILLA + 15) > 0 then M.Mud else M.Ground
	end

	if d.montana + d.borde > 0.5 then
		if h > 200 and pendiente < 1.3 then
			return M.Snow
		elseif pendiente > 0.9 then
			return M.Rock
		elseif h < 110 and pendiente < 0.6 then
			return M.Grass
		end
		return M.Slate
	end

	if d.camino > 0.5 then
		return M.Ground
	end

	if esDesierto then
		if pendiente > 0.75 or (d.meseta > 0.3 and pendiente > 0.4) then
			return M.Sandstone
		elseif d.manchas > 0.3 then
			return M.Ground -- tierra agrietada
		end
		return M.Sand
	elseif esOscuro then
		if pendiente > 1.0 then
			return M.Basalt
		elseif pendiente > 0.6 or d.manchas > 0.22 then
			return M.Mud
		elseif d.manchas < -0.25 then
			return M.Ground
		end
		return M.LeafyGrass
	end

	-- Bosque normal
	if pendiente > 1.0 then
		return M.Rock
	elseif pendiente > 0.6 or d.manchas > 0.22 then
		return M.Ground
	end
	return M.Grass
end

-- ===== GENERAR EL TERRENO PRINCIPAL =====

function Terreno.Generar()
	local terreno = Workspace.Terrain
	terreno:Clear()

	local columnas = Regiones.TAMANO / RES -- 512
	local capas = ALTURA_MAX / RES -- 64
	local TROZO = 64
	local trozosPorLado = columnas / TROZO
	local total = trozosPorLado * trozosPorLado
	local hecho = 0

	for ci = 0, trozosPorLado - 1 do
		for cj = 0, trozosPorLado - 1 do
			-- Alturas de este trozo (con una columna extra alrededor para las pendientes)
			local datos = {}
			for a = 0, TROZO + 1 do
				datos[a] = {}
				for b = 0, TROZO + 1 do
					local x = -MITAD + (ci * TROZO + a - 0.5) * RES
					local z = -MITAD + (cj * TROZO + b - 0.5) * RES
					datos[a][b] = Terreno.muestrear(x, z)
				end
			end

			local materiales, ocupacion = {}, {}
			for a = 1, TROZO do
				materiales[a], ocupacion[a] = {}, {}
				for k = 1, capas do
					materiales[a][k], ocupacion[a][k] = {}, {}
				end
				for b = 1, TROZO do
					local d = datos[a][b]
					local h = d.altura
					local pendiente = math.max(
						math.abs(datos[a + 1][b].altura - datos[a - 1][b].altura),
						math.abs(datos[a][b + 1].altura - datos[a][b - 1].altura)
					) / (2 * RES)
					local x = -MITAD + (ci * TROZO + a - 0.5) * RES
					local z = -MITAD + (cj * TROZO + b - 0.5) * RES
					local superficie = Terreno.elegirMaterial(d, pendiente, x, z)
					-- Material de dentro: es lo que se ve en las paredes empinadas
					local interior = M.Rock
					if superficie == M.Sand or superficie == M.Sandstone or d.desierto > 0.5 then
						interior = M.Sandstone
					elseif superficie == M.Snow or superficie == M.Slate or d.montana > 0.5 then
						interior = M.Slate
					elseif d.oscuro > 0.5 then
						interior = M.Basalt
					end

					for k = 1, capas do
						local fondo = (k - 1) * RES
						local lleno = math.clamp((h - fondo) / RES, 0, 1)
						ocupacion[a][k][b] = lleno
						if lleno > 0 then
							materiales[a][k][b] = if h - fondo > 10 then interior else superficie
						else
							materiales[a][k][b] = M.Air
						end
					end
				end
			end

			local x0 = -MITAD + ci * TROZO * RES
			local z0 = -MITAD + cj * TROZO * RES
			local region = Region3.new(Vector3.new(x0, 0, z0), Vector3.new(x0 + TROZO * RES, ALTURA_MAX, z0 + TROZO * RES))
			terreno:WriteVoxels(region, RES, materiales, ocupacion)

			hecho += 1
			if hecho % 4 == 0 then
				print(string.format("[MUNDO] Terreno %d / %d", hecho, total))
			end
			task.wait()
		end
	end

	-- Agua: todo lo que quedó vacío por debajo del nivel del agua
	for ci = 0, trozosPorLado - 1 do
		local x0 = -MITAD + ci * TROZO * RES
		local region = Region3.new(Vector3.new(x0, 0, -MITAD), Vector3.new(x0 + TROZO * RES, NIVEL_AGUA, MITAD))
		terreno:ReplaceMaterial(region, RES, M.Air, M.Water)
	end

	-- Colores de los materiales (realistas y apagados)
	local colores = {
		[M.Grass] = Color3.fromRGB(98, 122, 58), -- bosque normal
		[M.LeafyGrass] = Color3.fromRGB(50, 62, 40), -- bosque oscuro
		[M.Ground] = Color3.fromRGB(150, 124, 94), -- con la textura "Clumpy Dirt" (tierra)
		[M.Sand] = Color3.fromRGB(206, 180, 130),
		[M.Sandstone] = Color3.fromRGB(214, 128, 82), -- mesetas rojas del desierto
		[M.Mud] = Color3.fromRGB(84, 68, 52),
		[M.Rock] = Color3.fromRGB(176, 168, 158), -- la textura de roca es oscura: color claro
		[M.Slate] = Color3.fromRGB(128, 124, 118),
		[M.Basalt] = Color3.fromRGB(50, 48, 48),
	}
	for material, color in colores do
		terreno:SetMaterialColor(material, color)
	end

	terreno.WaterColor = Color3.fromRGB(52, 78, 72)
	terreno.WaterTransparency = 0.7
	terreno.WaterReflectance = 0.45
	terreno.WaterWaveSize = 0.12
	terreno.WaterWaveSpeed = 7
	pcall(function()
		terreno.Decoration = true -- hierba 3D que se mueve con el viento
	end)
end

-- ===== ISLA FLOTANTE =====
-- La forma de la isla está en ReplicatedStorage/Mundo/IslaForma porque el cliente
-- también la necesita (para esconderla hasta que el jugador la desbloquee).

local IslaForma = require(ReplicatedStorage.Mundo.IslaForma)

Terreno.alturasIsla = IslaForma.alturas

function Terreno.GenerarIsla()
	IslaForma.Construir()
end

return Terreno

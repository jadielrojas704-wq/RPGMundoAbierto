-- Terreno del mundo: alturas, materiales y la isla flotante.
-- Ruta en Studio: ServerStorage/Herramientas/Mundo/Terreno
-- Lo usa ServerStorage/Herramientas/GenerarMundo. No se ejecuta solo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Regiones = require(ReplicatedStorage.Config.RegionesConfig)

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
function Terreno.PuntosCaminos(paso)
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

-- ===== MUESTREO: altura y zonas de cualquier punto =====

function Terreno.muestrear(x, z)
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
	d.camino = 1 - suave(3, 7, distanciaCamino)
	h -= d.camino * 0.6

	-- Zonas llanas: inicio y Altar del Ascenso
	d.inicio = 1 - suave(30, 80, (Vector2.new(x, z) - INICIO).Magnitude)
	h += (40 - h) * d.inicio
	d.altar = 1 - suave(30, 70, (Vector2.new(x, z) - ALTAR).Magnitude)
	h += (62 - h) * d.altar

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
		[M.Ground] = Color3.fromRGB(118, 98, 72),
		[M.Sand] = Color3.fromRGB(206, 180, 130),
		[M.Sandstone] = Color3.fromRGB(176, 102, 62),
		[M.Mud] = Color3.fromRGB(60, 50, 40),
		[M.Rock] = Color3.fromRGB(114, 108, 100),
		[M.Slate] = Color3.fromRGB(96, 94, 90),
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
-- Arriba plana con hierba; abajo una roca en forma de cono invertido

local RADIO_ISLA = 110

function Terreno.alturasIsla(x, z)
	local centro = Regiones.ISLA
	local dx, dz = x - centro.X, z - centro.Z
	local r = math.sqrt(dx * dx + dz * dz)
	local radio = RADIO_ISLA * (1 + ruido(x, z, 2, 70, SEMILLA + 30) * 0.25)
	if r > radio then
		return nil
	end
	local f = r / radio
	local arriba = centro.Y + ruido(x, z, 3, 60, SEMILLA + 31) * 10 - f ^ 3 * 10
	local abajo = centro.Y - (1 - f) ^ 1.2 * 140 - math.abs(ruido(x, z, 3, 25, SEMILLA + 32)) * 25
	return arriba, abajo
end

function Terreno.GenerarIsla()
	local centro = Regiones.ISLA
	local tamano = 256
	local x0 = math.floor((centro.X - tamano / 2) / RES) * RES
	local z0 = math.floor((centro.Z - tamano / 2) / RES) * RES
	local y0 = math.floor((centro.Y - 150) / RES) * RES
	local alto = 192
	local nx, ny, nz = tamano / RES, alto / RES, tamano / RES

	local materiales, ocupacion = {}, {}
	for a = 1, nx do
		materiales[a], ocupacion[a] = {}, {}
		for k = 1, ny do
			materiales[a][k], ocupacion[a][k] = {}, {}
		end
		for b = 1, nz do
			local x = x0 + (a - 0.5) * RES
			local z = z0 + (b - 0.5) * RES
			local arriba, abajo = Terreno.alturasIsla(x, z)
			for k = 1, ny do
				local fondo = y0 + (k - 1) * RES
				local techo = fondo + RES
				local lleno = 0
				if arriba then
					lleno = math.clamp(math.min(arriba - fondo, techo - abajo) / RES, 0, 1)
				end
				ocupacion[a][k][b] = lleno
				if lleno > 0 then
					if arriba - fondo < 6 then
						materiales[a][k][b] = M.Grass
					elseif ruido(x, fondo, 1, 20, SEMILLA + 33) > 0.1 then
						materiales[a][k][b] = M.Slate
					else
						materiales[a][k][b] = M.Rock
					end
				else
					materiales[a][k][b] = M.Air
				end
			end
		end
	end

	local region = Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + tamano, y0 + alto, z0 + tamano))
	Workspace.Terrain:WriteVoxels(region, RES, materiales, ocupacion)
end

return Terreno

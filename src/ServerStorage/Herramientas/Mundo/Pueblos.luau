-- Ciudades, imperios y aldeas: arquitectura propia de cada cultura, plazas, murallas,
-- tiendas y NPC.
-- Ruta en Studio: ServerStorage/Herramientas/Mundo/Pueblos
-- Lo usa ServerStorage/Herramientas/GenerarMundo. No se ejecuta solo.
--
-- Los pueblos, sus nombres y sus tiendas están en ReplicatedStorage/Config/PueblosConfig.
-- El terreno ya viene aplanado (Terreno.SitiosPueblos) y sin árboles dentro.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PueblosConfig = require(ReplicatedStorage.Config.PueblosConfig)
local TiendasConfig = require(ReplicatedStorage.Config.TiendasConfig)
local Terreno = require(script.Parent.Terreno)
local Vegetacion = require(script.Parent.Vegetacion)
local C = require(script.Parent.Construccion)
local NPCs = require(script.Parent.NPCs)

local Pueblos = {}

local M = Enum.Material
local n = C.n
local variar = C.variar
local bloque = C.bloque
local rng = C.rng

local parametrosSuelo = RaycastParams.new()
parametrosSuelo.FilterType = Enum.RaycastFilterType.Include
parametrosSuelo.FilterDescendantsInstances = { Workspace.Terrain }

local function sueloEn(x, z, porDefecto)
	local r = Workspace:Raycast(Vector3.new(x, 500, z), Vector3.new(0, -1000, 0), parametrosSuelo)
	return if r then r.Position.Y else porDefecto
end

local function elegir(lista)
	return lista[rng:NextInteger(1, #lista)]
end

-- Ángulo de giro (alrededor de Y) para que algo en "posicion" mire hacia "objetivo"
local function mirandoA(posicion, objetivo)
	local plano = Vector3.new(objetivo.X, posicion.Y, objetivo.Z)
	if (plano - posicion).Magnitude < 0.01 then
		return CFrame.new(posicion)
	end
	return CFrame.lookAt(posicion, plano)
end

-- Cimientos de piedra: llegan hasta muy abajo para que nunca se vea un hueco en el suelo
local function cimientos(modelo, cf, ancho, fondo, color, material)
	bloque(modelo, cf * CFrame.new(0, -2.5, 0), Vector3.new(ancho + 1.2, 6, fondo + 1.2), material or M.Cobblestone, color, "Cimientos")
end

-- Vigas de madera de un piso con entramado (estilo medieval). Piso de y0 a y1.
local function entramado(modelo, cf, ancho, fondo, y0, y1, color, diagonales)
	local g = 0.55
	local alto = y1 - y0
	-- esquinas
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			bloque(modelo, cf * CFrame.new(sx * (ancho / 2 + 0.05), y0 + alto / 2, sz * (fondo / 2 + 0.05)), Vector3.new(g, alto, g), M.Wood, color, "Viga")
		end
	end
	-- horizontales arriba y abajo, en las 4 caras
	for _, y in { y0 + 0.3, y1 - 0.3 } do
		for _, sz in { -1, 1 } do
			bloque(modelo, cf * CFrame.new(0, y, sz * (fondo / 2 + 0.12)), Vector3.new(ancho + 0.4, g, 0.3), M.Wood, color, "Viga")
		end
		for _, sx in { -1, 1 } do
			bloque(modelo, cf * CFrame.new(sx * (ancho / 2 + 0.12), y, 0), Vector3.new(0.3, g, fondo + 0.4), M.Wood, color, "Viga")
		end
	end
	-- montantes en la fachada y atrás
	local cuantos = math.max(1, math.floor(ancho / 4.5))
	for i = 1, cuantos do
		local x = -ancho / 2 + i * ancho / (cuantos + 1)
		for _, sz in { -1, 1 } do
			bloque(modelo, cf * CFrame.new(x, y0 + alto / 2, sz * (fondo / 2 + 0.12)), Vector3.new(0.45, alto, 0.3), M.Wood, color, "Viga")
		end
	end
	-- cruces en los extremos de la fachada
	if diagonales then
		for _, sx in { -1, 1 } do
			local x0 = sx * (ancho / 2 - 0.3)
			local x1 = sx * (ancho / 2 - ancho / (cuantos + 1) + 0.3)
			local a = (cf * CFrame.new(x0, y0 + 0.5, -fondo / 2 - 0.15)).Position
			local b = (cf * CFrame.new(x1, y1 - 0.5, -fondo / 2 - 0.15)).Position
			C.liston(modelo, a, b, 0.4, M.Wood, color, "Riostra")
		end
	end
end

-- Ventanas en las 4 caras de un piso (a la altura y). Evita el hueco de la puerta.
local function ventanasPiso(modelo, cf, ancho, fondo, y, opciones, conPuerta)
	local ancho1 = opciones.ancho or 2
	local alto1 = opciones.alto or 2.6
	local cuantas = math.max(1, math.floor(ancho / 6))
	for i = 1, cuantas do
		local x = -ancho / 2 + i * ancho / (cuantas + 1)
		if not (conPuerta and math.abs(x) < 3) then
			C.ventana(modelo, cf * CFrame.new(x, y, -fondo / 2 - 0.05), ancho1, alto1, opciones)
		end
		C.ventana(modelo, cf * CFrame.new(x, y, fondo / 2 + 0.05) * CFrame.Angles(0, math.pi, 0), ancho1, alto1, opciones)
	end
	for _, sx in { -1, 1 } do
		C.ventana(modelo, cf * CFrame.new(sx * (ancho / 2 + 0.05), y, 0) * CFrame.Angles(0, -sx * math.pi / 2, 0), ancho1, alto1, opciones)
	end
end

-- ===================================================================
-- ===== CASAS DE CADA CULTURA =====
-- Todas reciben cf = centro del suelo, con la puerta hacia -Z. Devuelven el modelo,
-- su "radio" (para no chocar con otras) y la altura del alero (para colgar carteles).
-- ===================================================================

local Casas = {}

-- Reino de los caballeros: piedra abajo, entramado de madera arriba, tejado de pizarra azul
function Casas.Reino(padre, cf, opciones)
	opciones = opciones or {}
	local modelo = Instance.new("Model")
	modelo.Name = opciones.nombre or "Casa"
	local ancho, fondo = opciones.ancho or n(13, 18), opciones.fondo or n(11, 14)
	local pisos = opciones.pisos or (if rng:NextNumber() < 0.7 then 2 else 1)
	local madera = variar(Color3.fromRGB(70, 48, 32), 0.04)
	local yeso = variar(Color3.fromRGB(232, 222, 200), 0.03)
	cimientos(modelo, cf, ancho, fondo, variar(Color3.fromRGB(120, 116, 108), 0.03))

	local h1 = 9
	local piedraAbajo = rng:NextNumber() < 0.5
	bloque(modelo, cf * CFrame.new(0, 0.5 + h1 / 2, 0), Vector3.new(ancho, h1, fondo),
		if piedraAbajo then M.Cobblestone else M.Plaster,
		if piedraAbajo then variar(Color3.fromRGB(168, 162, 150), 0.03) else yeso, "Muro")
	if not piedraAbajo then
		entramado(modelo, cf, ancho, fondo, 0.5, 0.5 + h1, madera, pisos == 1)
	end
	local arriba = 0.5 + h1
	local anchoTejado, fondoTejado = ancho, fondo
	if pisos == 2 then
		local h2 = 8
		local a2, f2 = ancho + 1, fondo + 1 -- el piso de arriba sobresale un poco
		bloque(modelo, cf * CFrame.new(0, arriba + h2 / 2, 0), Vector3.new(a2, h2, f2), M.Plaster, yeso, "Muro")
		entramado(modelo, cf, a2, f2, arriba, arriba + h2, madera, true)
		ventanasPiso(modelo, cf, a2, f2, arriba + h2 / 2, { contraventanas = variar(Color3.fromRGB(50, 78, 96), 0.05) }, false)
		arriba += h2
		anchoTejado, fondoTejado = a2, f2
	end
	ventanasPiso(modelo, cf, ancho, fondo, 0.5 + h1 * 0.55, { contraventanas = variar(Color3.fromRGB(50, 78, 96), 0.05) }, true)
	C.puerta(modelo, cf * CFrame.new(0, 0.5, -fondo / 2 - 0.05), 3.4, 6.6, { colorMarco = Color3.fromRGB(110, 106, 98), materialMarco = M.Cobblestone })

	local subida = C.tejado(modelo, cf * CFrame.new(0, arriba, 0), anchoTejado, fondoTejado, 0.8, {
		material = M.Slate,
		color = variar(Color3.fromRGB(74, 88, 116), 0.04),
		colorFronton = yeso,
	})
	-- Chimenea de ladrillo con humo
	local chimenea = cf * CFrame.new(anchoTejado * 0.28, arriba + subida * 0.5 + 1.5, fondoTejado * 0.18)
	bloque(modelo, chimenea, Vector3.new(1.8, subida + 3, 1.8), M.Brick, Color3.fromRGB(128, 72, 56), "Chimenea")
	C.humo(modelo, (chimenea * CFrame.new(0, (subida + 3) / 2 + 0.6, 0)).Position)
	-- Jardinera con flores bajo alguna ventana
	if rng:NextNumber() < 0.6 then
		local jardinera = cf * CFrame.new(-ancho * 0.3, 0.5 + h1 * 0.55 - 1.9, -fondo / 2 - 0.7)
		bloque(modelo, jardinera, Vector3.new(2.6, 0.7, 0.8), M.WoodPlanks, madera, "Jardinera")
		for k = -1, 1 do
			C.bola(modelo, (jardinera * CFrame.new(k * 0.8, 0.5, 0)).Position, 0.8, M.Grass,
				elegir({ Color3.fromRGB(200, 60, 70), Color3.fromRGB(230, 200, 80), Color3.fromRGB(160, 80, 170) }), "Flor")
		end
	end
	modelo.Parent = padre
	return modelo, math.max(ancho, fondo) * 0.62, 0.5 + h1
end

-- Imperio del sol: casas cúbicas de arenisca, azotea, vigas asomando, arcos, toldos y cúpulas
function Casas.Sol(padre, cf, opciones)
	opciones = opciones or {}
	local modelo = Instance.new("Model")
	modelo.Name = opciones.nombre or "Casa"
	local ancho, fondo = opciones.ancho or n(10, 15), opciones.fondo or n(10, 14)
	local pisos = opciones.pisos or (if rng:NextNumber() < 0.5 then 2 else 1)
	local color = variar(elegir({ Color3.fromRGB(226, 196, 150), Color3.fromRGB(236, 214, 178), Color3.fromRGB(214, 180, 134) }), 0.03)
	local material = if rng:NextNumber() < 0.5 then M.Sandstone else M.Plaster
	cimientos(modelo, cf, ancho, fondo, variar(Color3.fromRGB(190, 160, 120), 0.03), M.Sandstone)

	local h = 8
	bloque(modelo, cf * CFrame.new(0, 0.5 + h / 2, 0), Vector3.new(ancho, h, fondo), material, color, "Muro")
	local arriba = 0.5 + h
	local superior = nil
	if pisos == 2 then
		-- el segundo piso es más pequeño y está atrás: delante queda una terraza
		local a2, f2 = ancho * 0.7, fondo * 0.6
		superior = cf * CFrame.new(ancho * 0.15 * (if rng:NextNumber() < 0.5 then 1 else -1), 0, fondo * 0.2)
		bloque(modelo, superior * CFrame.new(0, arriba + h / 2, 0), Vector3.new(a2, h, f2), material, variar(color, 0.02), "Muro")
		-- pretil del piso de arriba
		for _, datos in {
			{ CFrame.new(0, arriba + h + 0.6, -f2 / 2 + 0.3), Vector3.new(a2, 1.2, 0.6) },
			{ CFrame.new(0, arriba + h + 0.6, f2 / 2 - 0.3), Vector3.new(a2, 1.2, 0.6) },
			{ CFrame.new(-a2 / 2 + 0.3, arriba + h + 0.6, 0), Vector3.new(0.6, 1.2, f2) },
			{ CFrame.new(a2 / 2 - 0.3, arriba + h + 0.6, 0), Vector3.new(0.6, 1.2, f2) },
		} do
			bloque(modelo, superior * datos[1], datos[2], material, color, "Pretil")
		end
		ventanasPiso(modelo, superior, a2, f2, arriba + h * 0.5, { ancho = 1.4, alto = 2.2, colorMarco = Color3.fromRGB(80, 50, 30) }, false)
	end
	-- pretil de la azotea (con almenas pequeñas)
	for _, datos in {
		{ CFrame.new(0, arriba + 0.6, -fondo / 2 + 0.3), Vector3.new(ancho, 1.2, 0.6) },
		{ CFrame.new(0, arriba + 0.6, fondo / 2 - 0.3), Vector3.new(ancho, 1.2, 0.6) },
		{ CFrame.new(-ancho / 2 + 0.3, arriba + 0.6, 0), Vector3.new(0.6, 1.2, fondo) },
		{ CFrame.new(ancho / 2 - 0.3, arriba + 0.6, 0), Vector3.new(0.6, 1.2, fondo) },
	} do
		bloque(modelo, cf * datos[1], datos[2], material, color, "Pretil")
	end
	-- vigas de madera que asoman bajo la azotea
	for x = -ancho / 2 + 1.5, ancho / 2 - 1.5, 2.6 do
		for _, sz in { -1, 1 } do
			local p = cf * CFrame.new(x, arriba - 0.9, sz * (fondo / 2 + 0.5))
			C.parte({
				Name = "VigaAsomada",
				Shape = Enum.PartType.Cylinder,
				CFrame = p * CFrame.Angles(0, math.pi / 2, 0),
				Size = Vector3.new(1.4, 0.5, 0.5),
				Material = M.Wood,
				Color = Color3.fromRGB(92, 64, 40),
				Parent = modelo,
			})
		end
	end
	ventanasPiso(modelo, cf, ancho, fondo, 0.5 + h * 0.58, { ancho = 1.4, alto = 2.2, colorMarco = Color3.fromRGB(80, 50, 30) }, true)
	-- puerta con arco
	C.puerta(modelo, cf * CFrame.new(0, 0.5, -fondo / 2 - 0.05), 3, 5.6, { color = Color3.fromRGB(104, 62, 36), colorMarco = variar(color, 0.06), materialMarco = material })
	C.parte({
		Name = "Arco",
		Shape = Enum.PartType.Cylinder,
		CFrame = cf * CFrame.new(0, 0.5 + 5.6, -fondo / 2 - 0.2) * CFrame.Angles(0, math.pi / 2, 0),
		Size = Vector3.new(0.6, 4, 4),
		Material = material,
		Color = variar(color, 0.08),
		Parent = modelo,
	})
	-- toldo de colores
	local colores = {
		{ Color3.fromRGB(36, 120, 132), Color3.fromRGB(236, 226, 206) },
		{ Color3.fromRGB(190, 64, 46), Color3.fromRGB(236, 210, 150) },
		{ Color3.fromRGB(226, 160, 50), Color3.fromRGB(150, 50, 40) },
		{ Color3.fromRGB(110, 40, 90), Color3.fromRGB(230, 200, 120) },
	}
	local par = elegir(colores)
	C.toldo(modelo, cf * CFrame.new(0, 0.5 + 7.2, -fondo / 2 - 0.2), 5, 3, par[1], par[2])
	-- cúpula en algunas casas
	if rng:NextNumber() < 0.35 then
		local base = (superior or cf) * CFrame.new(0, arriba + (if superior then h else 0), 0)
		local diametro = math.min(ancho, fondo) * (if superior then 0.4 else 0.55)
		C.bola(modelo, (base * CFrame.new(0, diametro * 0.05, 0)).Position, diametro,
			if rng:NextNumber() < 0.5 then M.Plaster else M.Marble,
			elegir({ Color3.fromRGB(244, 240, 230), Color3.fromRGB(56, 150, 160), Color3.fromRGB(226, 172, 58) }), "Cupula")
	else
		-- tinajas en la azotea
		for _ = 1, rng:NextInteger(1, 3) do
			local p = cf * CFrame.new(n(-ancho / 3, ancho / 3), arriba, n(-fondo / 3, 0))
			C.columna(modelo, p.Position, 1.4, 1.1, M.Slate, Color3.fromRGB(176, 96, 60), "Tinaja")
		end
	end
	modelo.Parent = padre
	return modelo, math.max(ancho, fondo) * 0.62, 0.5 + h
end

-- Ciudad de los brujos: casas altas y torcidas de madera negra, ventanas que brillan morado
function Casas.Brujos(padre, cf, opciones)
	opciones = opciones or {}
	local modelo = Instance.new("Model")
	modelo.Name = opciones.nombre or "Casa"
	local ancho, fondo = opciones.ancho or n(9, 12), opciones.fondo or n(9, 11)
	local pisos = opciones.pisos or rng:NextInteger(2, 3)
	local madera = variar(Color3.fromRGB(52, 42, 40), 0.03)
	local vigas = Color3.fromRGB(26, 20, 20)
	local luz = elegir({ Color3.fromRGB(170, 100, 255), Color3.fromRGB(150, 90, 255), Color3.fromRGB(130, 255, 160) })
	cimientos(modelo, cf, ancho, fondo, variar(Color3.fromRGB(54, 50, 56), 0.03), M.Basalt)

	local y = 0.5
	local actual = cf
	local a, f = ancho, fondo
	for piso = 1, pisos do
		local h = 8
		-- cada piso un poco más grande y un poco girado: casas torcidas, como de cuento
		if piso > 1 then
			actual = actual * CFrame.new(n(-0.4, 0.4), 0, n(-0.4, 0.4)) * CFrame.Angles(0, math.rad(n(-4, 4)), 0)
			a += 0.8
			f += 0.8
		end
		bloque(modelo, actual * CFrame.new(0, y + h / 2, 0), Vector3.new(a, h, f), M.WoodPlanks, variar(madera, 0.02), "Muro")
		entramado(modelo, actual, a, f, y, y + h, vigas, false)
		ventanasPiso(modelo, actual, a, f, y + h * 0.55, { ancho = 1.6, alto = 2.6, luz = luz, transparencia = 0.3, colorMarco = vigas }, piso == 1)
		y += h
	end
	C.puerta(modelo, cf * CFrame.new(0, 0.5, -fondo / 2 - 0.05), 3, 6.4, { color = Color3.fromRGB(40, 30, 30), colorMarco = vigas })
	-- farol morado junto a la puerta
	local farol = C.parte({
		Name = "FarolPuerta",
		CFrame = cf * CFrame.new(2.6, 5.6, -fondo / 2 - 0.8),
		Size = Vector3.new(0.8, 1.1, 0.8),
		Material = M.Neon,
		Color = Color3.fromRGB(160, 90, 255),
		CanCollide = false,
		CastShadow = false,
		Parent = modelo,
	})
	C.luz(farol, Color3.fromRGB(160, 90, 255), 1.4, 14)
	-- tejado muy empinado y algo girado
	local subida = C.tejado(modelo, actual * CFrame.new(0, y, 0) * CFrame.Angles(0, math.rad(n(-3, 3)), 0), a, f, 1.35, {
		material = M.Slate,
		color = variar(Color3.fromRGB(46, 42, 56), 0.03),
		colorFronton = madera,
		materialFronton = M.WoodPlanks,
		colorCumbrera = vigas,
	})
	-- chimenea torcida con humo morado
	local chimenea = actual * CFrame.new(-a * 0.25, y + subida * 0.4 + 2, f * 0.1) * CFrame.Angles(0, 0, math.rad(n(-6, 6)))
	bloque(modelo, chimenea, Vector3.new(1.6, subida + 4, 1.6), M.Basalt, Color3.fromRGB(60, 56, 62), "Chimenea")
	C.humo(modelo, (chimenea * CFrame.new(0, (subida + 4) / 2 + 0.6, 0)).Position, Color3.fromRGB(110, 90, 130))
	modelo.Parent = padre
	return modelo, math.max(a, f) * 0.62, 6.4
end

-- Fortaleza del norte: casas largas de troncos, tejado empinado con nieve, vigas cruzadas
function Casas.Norte(padre, cf, opciones)
	opciones = opciones or {}
	local modelo = Instance.new("Model")
	modelo.Name = opciones.nombre or "Casa"
	local ancho, fondo = opciones.ancho or n(19, 25), opciones.fondo or n(11, 13)
	local altoMuro = opciones.altoMuro or 7
	local tronco = variar(Color3.fromRGB(112, 82, 54), 0.04)
	cimientos(modelo, cf, ancho, fondo, variar(Color3.fromRGB(104, 104, 108), 0.03), M.Slate)

	bloque(modelo, cf * CFrame.new(0, 0.5 + altoMuro / 2, 0), Vector3.new(ancho, altoMuro, fondo), M.WoodPlanks, Color3.fromRGB(92, 66, 44), "Muro")
	-- troncos horizontales en las cuatro caras (los extremos asoman en las esquinas)
	local diametro = 1.1
	for yy = 0.5 + diametro / 2, 0.5 + altoMuro - diametro / 2, diametro do
		for _, sz in { -1, 1 } do
			C.parte({
				Name = "Tronco",
				Shape = Enum.PartType.Cylinder,
				CFrame = cf * CFrame.new(0, yy, sz * (fondo / 2 + 0.15)),
				Size = Vector3.new(ancho + 1.6, diametro, diametro),
				Material = M.Wood,
				Color = variar(tronco, 0.03),
				Parent = modelo,
			})
		end
		for _, sx in { -1, 1 } do
			C.parte({
				Name = "Tronco",
				Shape = Enum.PartType.Cylinder,
				CFrame = cf * CFrame.new(sx * (ancho / 2 + 0.15), yy + diametro / 2, 0) * CFrame.Angles(0, math.pi / 2, 0),
				Size = Vector3.new(fondo + 1.6, diametro, diametro),
				Material = M.Wood,
				Color = variar(tronco, 0.03),
				Parent = modelo,
			})
		end
	end
	C.puerta(modelo, cf * CFrame.new(0, 0.5, -fondo / 2 - 0.45), 3.6, 6.2, { color = Color3.fromRGB(70, 50, 34), colorMarco = Color3.fromRGB(50, 36, 26) })
	-- escudos redondos colgados junto a la puerta
	for _, sx in { -1, 1 } do
		local escudo = cf * CFrame.new(sx * 4.2, 4.6, -fondo / 2 - 0.9)
		C.parte({
			Name = "Escudo",
			Shape = Enum.PartType.Cylinder,
			CFrame = escudo * CFrame.Angles(0, math.pi / 2, 0),
			Size = Vector3.new(0.3, 2.6, 2.6),
			Material = M.WoodPlanks,
			Color = elegir({ Color3.fromRGB(150, 40, 32), Color3.fromRGB(40, 64, 98), Color3.fromRGB(190, 160, 60) }),
			Parent = modelo,
		})
		C.bola(modelo, (escudo * CFrame.new(0, 0, -0.2)).Position, 0.7, M.Metal, Color3.fromRGB(120, 120, 126), "Umbo")
	end
	-- ventanitas
	for _, sx in { -1, 1 } do
		C.ventana(modelo, cf * CFrame.new(sx * ancho * 0.3, 4.4, -fondo / 2 - 0.6), 1.6, 1.6, { cruz = false, colorMarco = Color3.fromRGB(50, 36, 26) })
	end
	local voladizo = 1.6
	local subida = C.tejado(modelo, cf * CFrame.new(0, 0.5 + altoMuro, 0), ancho, fondo, opciones.inclinacion or 1.05, {
		voladizo = voladizo,
		material = M.WoodPlanks,
		color = variar(Color3.fromRGB(66, 50, 38), 0.03),
		colorFronton = Color3.fromRGB(96, 70, 46),
		materialFronton = M.WoodPlanks,
		nieve = true,
	})
	-- vigas cruzadas en los extremos del tejado (típico del norte)
	local cumbre = 0.5 + altoMuro + subida
	for _, sx in { -1, 1 } do
		local x = sx * (ancho / 2 + voladizo - 0.2)
		for _, sz in { -1, 1 } do
			local desde = (cf * CFrame.new(x, cumbre - 1.6, sz * 1.8)).Position
			local hasta = (cf * CFrame.new(x, cumbre + 2.2, -sz * 1.2)).Position
			C.liston(modelo, desde, hasta, 0.5, M.Wood, Color3.fromRGB(60, 44, 30), "VigaCruzada")
		end
	end
	C.humo(modelo, (cf * CFrame.new(0, cumbre + 1, 0)).Position)
	-- leña apilada a un lado
	for i = 0, 5 do
		C.parte({
			Name = "Lena",
			Shape = Enum.PartType.Cylinder,
			CFrame = cf * CFrame.new(ancho / 2 + 1.6, 0.9 + math.floor(i / 3) * 0.75, -fondo / 4 + (i % 3) * 0.8) * CFrame.Angles(0, 0, 0),
			Size = Vector3.new(2.4, 0.75, 0.75),
			Material = M.Wood,
			Color = variar(Color3.fromRGB(130, 96, 62), 0.05),
			Parent = modelo,
		})
	end
	modelo.Parent = padre
	return modelo, math.max(ancho, fondo) * 0.6, 0.5 + altoMuro
end

-- ===================================================================
-- ===== EDIFICIOS PRINCIPALES (uno por capital) =====
-- ===================================================================

local Principales = {}

local function almenas(modelo, cf, ancho, fondo, y, material, color)
	for _, lado in { { ancho, 0, -1 }, { ancho, 0, 1 }, { fondo, 1, -1 }, { fondo, 1, 1 } } do
		local largo, eje, signo = lado[1], lado[2], lado[3]
		for t = -largo / 2 + 1, largo / 2 - 1, 2.6 do
			local pos = if eje == 0 then CFrame.new(t, y + 0.9, signo * (fondo / 2 - 0.6)) else CFrame.new(signo * (ancho / 2 - 0.6), y + 0.9, t)
			bloque(modelo, cf * pos, Vector3.new(1.3, 1.8, 1.3), material, color, "Almena")
		end
	end
end

-- Castillo del Reino: torre del homenaje con cuatro torres redondas y estandartes rojos
function Principales.Reino(padre, cf, cultura)
	local modelo = Instance.new("Model")
	modelo.Name = "Castillo"
	local piedra = Color3.fromRGB(176, 170, 158)
	local ancho, fondo, alto = 36, 30, 30
	cimientos(modelo, cf, ancho, fondo, Color3.fromRGB(130, 126, 118))
	bloque(modelo, cf * CFrame.new(0, alto / 2 + 0.5, 0), Vector3.new(ancho, alto, fondo), M.Cobblestone, piedra, "TorreHomenaje")
	almenas(modelo, cf, ancho, fondo, alto + 0.5, M.Cobblestone, piedra)
	-- torres de las esquinas con tejado cónico azul
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local base = (cf * CFrame.new(sx * ancho / 2, 0, sz * fondo / 2)).Position
			C.columna(modelo, base - Vector3.new(0, 3, 0), alto + 15, 10, M.Cobblestone, variar(piedra, 0.02), "Torre")
			C.cono(modelo, base + Vector3.new(0, alto + 12, 0), 12, 13, M.Slate, Color3.fromRGB(70, 86, 116), "TejadoTorre")
			-- ventanas estrechas mirando hacia fuera del castillo
			local fuera = ((cf * CFrame.new(sx, 0, sz)).Position - cf.Position).Unit
			for k = 1, 3 do
				local altura = base + Vector3.new(0, 8 + k * 9, 0)
				C.ventana(modelo, CFrame.lookAt(altura, altura + fuera) * CFrame.new(0, 0, -5.05), 0.8, 2.4, { cruz = false, luz = Color3.fromRGB(255, 190, 110) })
			end
			-- banderín en lo alto
			C.parte({
				Name = "Banderin",
				CFrame = CFrame.new(base + Vector3.new(1.5, alto + 27, 0)),
				Size = Vector3.new(3, 1.6, 0.1),
				Material = M.Fabric,
				Color = cultura.bandera,
				CanCollide = false,
				Parent = modelo,
			})
			C.columna(modelo, base + Vector3.new(0, alto + 24, 0), 5, 0.25, M.Metal, Color3.fromRGB(60, 58, 56), "Asta")
		end
	end
	-- portón y estandartes largos en la fachada
	C.puerta(modelo, cf * CFrame.new(0, 0.5, -fondo / 2 - 0.05), 7, 11, { color = Color3.fromRGB(86, 58, 36), colorMarco = Color3.fromRGB(120, 116, 108), materialMarco = M.Cobblestone })
	for _, sx in { -1, 1 } do
		local tela = cf * CFrame.new(sx * 9, alto - 9, -fondo / 2 - 0.2)
		bloque(modelo, tela, Vector3.new(4.4, 15, 0.15), M.Fabric, cultura.bandera, "Estandarte").CanCollide = false
		bloque(modelo, tela * CFrame.new(0, -7.2, -0.02), Vector3.new(4.4, 0.6, 0.16), M.Fabric, cultura.detalle, "Ribete").CanCollide = false
		bloque(modelo, tela * CFrame.new(0, 2, -0.1) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(2, 2, 0.05), M.Fabric, cultura.detalle, "Emblema").CanCollide = false
		for k = 0, 1 do
			C.ventana(modelo, cf * CFrame.new(sx * 14, 12 + k * 9, -fondo / 2 - 0.05), 1, 3, { cruz = false })
		end
	end
	for _, sx in { -1, 1 } do
		C.fuego(modelo, (cf * CFrame.new(sx * 5.5, 1.5, -fondo / 2 - 3)).Position, 2.5)
		C.columna(modelo, (cf * CFrame.new(sx * 5.5, 0, -fondo / 2 - 3)).Position, 1.2, 1.6, M.Metal, Color3.fromRGB(40, 38, 36), "Brasero")
	end
	modelo.Parent = padre
	return modelo, 30
end

-- Palacio del Imperio del sol: gran cúpula dorada, minaretes y arcadas
function Principales.Sol(padre, cf, cultura)
	local modelo = Instance.new("Model")
	modelo.Name = "Palacio"
	local arena = Color3.fromRGB(232, 208, 166)
	local oro = Color3.fromRGB(226, 172, 58)
	local ancho, fondo = 48, 38
	cimientos(modelo, cf, ancho, fondo, Color3.fromRGB(200, 170, 128), M.Sandstone)
	bloque(modelo, cf * CFrame.new(0, 8.5, 2), Vector3.new(ancho, 16, fondo - 4), M.Sandstone, arena, "Cuerpo")
	-- arcada en la fachada
	for i = 0, 6 do
		local x = -ancho / 2 + 3 + i * (ancho - 6) / 6
		C.columna(modelo, (cf * CFrame.new(x, 0.5, -fondo / 2 + 1)).Position, 11, 1.6, M.Marble, Color3.fromRGB(240, 232, 216), "Columna")
		if i < 6 then
			local xm = x + (ancho - 6) / 12
			C.parte({
				Name = "Arco",
				Shape = Enum.PartType.Cylinder,
				CFrame = cf * CFrame.new(xm, 11.5, -fondo / 2 + 1) * CFrame.Angles(0, math.pi / 2, 0),
				Size = Vector3.new(1.4, 7.4, 7.4),
				Material = M.Sandstone,
				Color = variar(arena, 0.04),
				Parent = modelo,
			})
		end
	end
	bloque(modelo, cf * CFrame.new(0, 15.5, -fondo / 2 + 1), Vector3.new(ancho, 2, 2.6), M.Sandstone, arena, "Dintel")
	bloque(modelo, cf * CFrame.new(0, 16.8, -fondo / 2 + 1), Vector3.new(ancho + 0.4, 0.6, 2.8), M.Foil, oro, "Friso")
	C.puerta(modelo, cf * CFrame.new(0, 0.5, -fondo / 2 + 4.05), 5, 9, { color = Color3.fromRGB(120, 70, 36), colorMarco = oro, materialMarco = M.Foil })
	-- segundo cuerpo, tambor y cúpula dorada
	bloque(modelo, cf * CFrame.new(0, 21.5, 4), Vector3.new(30, 10, 24), M.Sandstone, variar(arena, 0.02), "Cuerpo2")
	C.columna(modelo, (cf * CFrame.new(0, 26.5, 4)).Position, 5, 19, M.Sandstone, arena, "Tambor")
	C.bola(modelo, (cf * CFrame.new(0, 31, 4)).Position, 20, M.Foil, oro, "Cupula")
	C.cono(modelo, (cf * CFrame.new(0, 40.4, 4)).Position, 1.6, 6, M.Foil, oro, "Aguja")
	-- minaretes
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local base = (cf * CFrame.new(sx * (ancho / 2 + 2), 0, sz * (fondo / 2 - 2))).Position
			C.columna(modelo, base - Vector3.new(0, 3, 0), 47, 4.2, M.Sandstone, variar(arena, 0.03), "Minarete")
			C.columna(modelo, base + Vector3.new(0, 34, 0), 1, 6.4, M.Sandstone, arena, "Balcon")
			C.columna(modelo, base + Vector3.new(0, 35, 0), 1.2, 6.6, M.Foil, oro, "Baranda")
			C.bola(modelo, base + Vector3.new(0, 44.5, 0), 4.6, M.Foil, oro, "CupulaMinarete")
			C.cono(modelo, base + Vector3.new(0, 46.4, 0), 0.8, 3.5, M.Foil, oro, "Aguja")
		end
	end
	-- estandartes turquesa
	for _, sx in { -1, 1 } do
		local tela = cf * CFrame.new(sx * 18, 9, -fondo / 2 - 0.4)
		bloque(modelo, tela, Vector3.new(3.6, 12, 0.15), M.Fabric, cultura.bandera, "Estandarte").CanCollide = false
		bloque(modelo, tela * CFrame.new(0, 1.5, -0.1) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(1.6, 1.6, 0.05), M.Fabric, cultura.detalle, "Emblema").CanCollide = false
	end
	modelo.Parent = padre
	return modelo, 34
end

-- Torre del Nigromante: torre negra escalonada con un orbe morado flotando encima
function Principales.Brujos(padre, cf, cultura)
	local modelo = Instance.new("Model")
	modelo.Name = "TorreDelNigromante"
	local piedra = Color3.fromRGB(54, 50, 58)
	cimientos(modelo, cf, 24, 24, Color3.fromRGB(44, 40, 46), M.Basalt)
	bloque(modelo, cf * CFrame.new(0, 5.5, 0), Vector3.new(24, 10, 24), M.Basalt, piedra, "Base")
	almenas(modelo, cf, 24, 24, 10.5, M.Basalt, piedra)
	local y = 10.5
	local tramos = { { 15, 22 }, { 12, 18 }, { 9, 14 } }
	for i, tramo in tramos do
		local diametro, alto = tramo[1], tramo[2]
		local base = (cf * CFrame.Angles(0, math.rad(i * 17), 0) * CFrame.new(0, y, 0)).Position
		C.columna(modelo, base, alto, diametro, M.Basalt, variar(piedra, 0.02), "Torre")
		C.columna(modelo, base + Vector3.new(0, alto - 0.6, 0), 1.2, diametro + 2.4, M.Basalt, Color3.fromRGB(40, 36, 44), "Cornisa")
		for k = 1, 4 do
			local angulo = k * math.pi / 2 + i
			C.ventana(modelo, CFrame.new(base + Vector3.new(0, alto * 0.5, 0)) * CFrame.Angles(0, angulo, 0) * CFrame.new(0, 0, -diametro / 2 - 0.05), 1.4, 3.4, { cruz = false, luz = cultura.detalle, transparencia = 0.2, colorMarco = Color3.fromRGB(30, 26, 32) })
		end
		y += alto
	end
	local cima = (cf * CFrame.new(0, y, 0)).Position
	C.cono(modelo, cima, 11, 18, M.Slate, Color3.fromRGB(38, 32, 46), "Aguja")
	-- orbe flotante
	local orbe = C.bola(modelo, cima + Vector3.new(0, 24, 0), 4.5, M.Neon, cultura.detalle, "Orbe")
	orbe.CanCollide = false
	orbe.CastShadow = false
	C.luz(orbe, cultura.detalle, 3, 40)
	local chispas = Instance.new("ParticleEmitter")
	chispas.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	chispas.Rate = 8
	chispas.Lifetime = NumberRange.new(2, 3)
	chispas.Speed = NumberRange.new(1, 3)
	chispas.SpreadAngle = Vector2.new(180, 180)
	chispas.LightEmission = 1
	chispas.Size = NumberSequence.new(0.5, 0)
	chispas.Color = ColorSequence.new(cultura.detalle)
	chispas.Parent = orbe
	-- cristales morados alrededor de la base
	for k = 1, 8 do
		local angulo = k / 8 * math.pi * 2
		local p = cf * CFrame.new(math.cos(angulo) * 17, 0, math.sin(angulo) * 17)
		local alto = n(3, 7)
		local cristal = C.parte({
			Name = "Cristal",
			CFrame = p * CFrame.new(0, alto / 2 - 0.5, 0) * CFrame.Angles(n(-0.3, 0.3), n(0, 6), n(-0.3, 0.3)),
			Size = Vector3.new(n(1, 1.8), alto, n(1, 1.8)),
			Material = M.Glass,
			Color = cultura.detalle,
			Transparency = 0.25,
			Parent = modelo,
		}, "WedgePart")
		if k % 2 == 0 then
			C.luz(cristal, cultura.detalle, 1, 10)
		end
	end
	C.puerta(modelo, cf * CFrame.new(0, 0.5, -12.05), 4.4, 8, { color = Color3.fromRGB(34, 26, 30), colorMarco = Color3.fromRGB(30, 26, 32), materialMarco = M.Basalt })
	modelo.Parent = padre
	return modelo, 20
end

-- Gran salón del norte con su gran forja al lado
function Principales.Norte(padre, cf, cultura)
	local modelo = Instance.new("Model")
	modelo.Name = "GranSalon"
	local salon = Casas.Norte(modelo, cf, { ancho = 46, fondo = 20, altoMuro = 11, inclinacion = 0.95, nombre = "Salon" })
	local _ = salon
	-- braseros en la entrada
	for _, sx in { -1, 1 } do
		local p = (cf * CFrame.new(sx * 6, 0, -14)).Position
		C.columna(modelo, p, 3, 1.4, M.Metal, Color3.fromRGB(40, 38, 36), "PieBrasero")
		C.columna(modelo, p + Vector3.new(0, 3, 0), 0.8, 2.6, M.Metal, Color3.fromRGB(40, 38, 36), "Brasero")
		C.fuego(modelo, p + Vector3.new(0, 4.2, 0), 3)
	end
	-- estandartes azules
	for _, sx in { -1, 1 } do
		C.estandarte(modelo, (cf * CFrame.new(sx * 12, 0, -13)).Position, 12, cultura.bandera, cultura.detalle, (cf.LookVector))
	end
	-- La gran forja (a un lado): fragua de piedra, chimenea alta, yunque y brasas
	local forja = cf * CFrame.new(36, 0, 4)
	cimientos(modelo, forja, 16, 14, Color3.fromRGB(96, 96, 100), M.Slate)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			C.columna(modelo, (forja * CFrame.new(sx * 7, 0.5, sz * 6)).Position, 9, 1.4, M.Wood, Color3.fromRGB(90, 66, 44), "Poste")
		end
	end
	C.tejado(modelo, forja * CFrame.new(0, 9.5, 0), 16, 14, 0.7, { material = M.WoodPlanks, color = Color3.fromRGB(64, 48, 36), nieve = true, colorFronton = Color3.fromRGB(90, 66, 44), materialFronton = M.WoodPlanks })
	bloque(modelo, forja * CFrame.new(0, 2, 3), Vector3.new(7, 3, 5), M.Slate, Color3.fromRGB(86, 84, 86), "Fragua")
	bloque(modelo, forja * CFrame.new(0, 3.6, 3), Vector3.new(5, 0.3, 3.4), M.Neon, Color3.fromRGB(255, 110, 30), "Brasas").CanCollide = false
	C.fuego(modelo, (forja * CFrame.new(0, 4.2, 3)).Position, 3.5)
	bloque(modelo, forja * CFrame.new(0, 10, 5.2), Vector3.new(3, 17, 3), M.Slate, Color3.fromRGB(80, 80, 84), "Chimenea")
	C.humo(modelo, (forja * CFrame.new(0, 19, 5.2)).Position, Color3.fromRGB(80, 78, 76))
	-- yunque
	local yunque = forja * CFrame.new(-3, 0.5, -2)
	bloque(modelo, yunque * CFrame.new(0, 0.9, 0), Vector3.new(1.6, 1.8, 1.6), M.Wood, Color3.fromRGB(90, 64, 40), "Tocon")
	bloque(modelo, yunque * CFrame.new(0, 2.2, 0), Vector3.new(2.6, 0.9, 1.1), M.Metal, Color3.fromRGB(46, 46, 50), "Yunque")
	modelo.Parent = padre
	return modelo, 34
end

-- ===================================================================
-- ===== PLAZAS: el centro de cada pueblo =====
-- ===================================================================

local SUELO_PLAZA = {
	Reino = { M.Cobblestone, Color3.fromRGB(150, 146, 138) },
	Sol = { M.Pavement, Color3.fromRGB(214, 194, 160) },
	Brujos = { M.Slate, Color3.fromRGB(64, 60, 68) },
	Norte = { M.Cobblestone, Color3.fromRGB(132, 132, 136) },
}

-- Lámina de agua cuya cara de arriba queda a la altura "alto" sobre el centro
local function agua(modelo, centro, diametro, alto)
	local p = C.disco(modelo, centro + Vector3.new(0, alto - 0.4, 0), diametro, M.Glass, Color3.fromRGB(70, 130, 150), "Agua")
	p.Transparency = 0.25
	p.CanCollide = false
	return p
end

local Centros = {}

function Centros.Reino(modelo, centro, grande, cultura)
	-- fuente de piedra con chorro de agua
	local d = if grande then 13 else 8
	C.columna(modelo, centro, 1.8, d, M.Cobblestone, Color3.fromRGB(170, 164, 152), "Fuente")
	agua(modelo, centro, d - 1.4, 1.85)
	C.columna(modelo, centro, 4.5, 1.6, M.Cobblestone, Color3.fromRGB(170, 164, 152), "Pilar")
	C.columna(modelo, centro + Vector3.new(0, 4.5, 0), 0.8, 4, M.Cobblestone, Color3.fromRGB(170, 164, 152), "Taza")
	local chorro = C.parte({ Name = "Chorro", CFrame = CFrame.new(centro + Vector3.new(0, 5.4, 0)), Size = Vector3.one, Transparency = 1, CanCollide = false, Parent = modelo })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Rate = 30
	e.Lifetime = NumberRange.new(0.8, 1.2)
	e.Speed = NumberRange.new(4, 6)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(0, -16, 0)
	e.Size = NumberSequence.new(0.4, 0.8)
	e.Transparency = NumberSequence.new(0.4, 1)
	e.Color = ColorSequence.new(Color3.fromRGB(220, 236, 245))
	e.Parent = chorro
	if grande then
		for k = 1, 4 do
			local angulo = k / 4 * math.pi * 2 + math.pi / 4
			C.estandarte(modelo, centro + Vector3.new(math.cos(angulo) * 15, 0, math.sin(angulo) * 15), 10, cultura.bandera, cultura.detalle, Vector3.new(-math.cos(angulo), 0, -math.sin(angulo)))
		end
	end
end

function Centros.Sol(modelo, centro, grande, _cultura)
	-- estanque de mármol con palmeras en las esquinas
	local lado = if grande then 14 else 9
	bloque(modelo, CFrame.new(centro + Vector3.new(0, 0.8, 0)), Vector3.new(lado, 1.6, lado), M.Marble, Color3.fromRGB(240, 234, 222), "Estanque")
	local superficie = bloque(modelo, CFrame.new(centro + Vector3.new(0, 1.62, 0)), Vector3.new(lado - 1.4, 0.2, lado - 1.4), M.Glass, Color3.fromRGB(60, 140, 160), "Agua")
	superficie.Transparency = 0.25
	superficie.CanCollide = false
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Vegetacion.Palmera(centro + Vector3.new(sx * (lado / 2 + 2.5), -0.5, sz * (lado / 2 + 2.5)), modelo)
		end
	end
end

function Centros.Brujos(modelo, centro, grande, cultura)
	-- círculo ritual que brilla y un caldero burbujeante en medio
	local radio = if grande then 9 else 6
	local piezas = if grande then 24 else 16
	for k = 1, piezas do
		local angulo = k / piezas * math.pi * 2
		local p = centro + Vector3.new(math.cos(angulo) * radio, 0.42, math.sin(angulo) * radio)
		local runa = bloque(modelo, CFrame.lookAt(p, centro + Vector3.new(0, 0.42, 0)), Vector3.new(radio * 2 * math.pi / piezas * 0.8, 0.1, 0.4), M.Neon, cultura.detalle, "Runa")
		runa.CanCollide = false
	end
	C.columna(modelo, centro, 2.4, 4.4, M.Metal, Color3.fromRGB(30, 30, 34), "Caldero")
	local liquido = C.columna(modelo, centro + Vector3.new(0, 2.2, 0), 0.3, 3.8, M.Neon, Color3.fromRGB(110, 255, 140), "Pocion")
	liquido.CanCollide = false
	C.luz(liquido, Color3.fromRGB(110, 255, 140), 1.5, 16)
	local vapor = Instance.new("ParticleEmitter")
	vapor.Texture = "rbxasset://textures/particles/smoke_main.dds"
	vapor.Rate = 6
	vapor.Lifetime = NumberRange.new(2, 3)
	vapor.Speed = NumberRange.new(1, 2)
	vapor.LightEmission = 0.6
	vapor.Size = NumberSequence.new(1, 3)
	vapor.Transparency = NumberSequence.new(0.5, 1)
	vapor.Color = ColorSequence.new(Color3.fromRGB(120, 255, 150))
	vapor.Parent = liquido
	-- tumbas alrededor
	if grande then
		for k = 1, 6 do
			local angulo = k / 6 * math.pi * 2 + 0.3
			local p = centro + Vector3.new(math.cos(angulo) * 14, 0, math.sin(angulo) * 14)
			bloque(modelo, CFrame.lookAt(p + Vector3.new(0, 1.2, 0), centro + Vector3.new(0, 1.2, 0)) * CFrame.Angles(math.rad(n(-6, 6)), 0, math.rad(n(-6, 6))), Vector3.new(2, 2.8, 0.5), M.Slate, Color3.fromRGB(96, 94, 100), "Lapida")
		end
	end
end

function Centros.Norte(modelo, centro, grande, _cultura)
	-- gran hoguera rodeada de piedras y una piedra rúnica
	local radio = if grande then 4 else 3
	for k = 1, 10 do
		local angulo = k / 10 * math.pi * 2
		bloque(modelo, CFrame.new(centro + Vector3.new(math.cos(angulo) * radio, 0.6, math.sin(angulo) * radio)) * CFrame.Angles(0, -angulo, 0), Vector3.new(1.6, 1.2, 1.2), M.Slate, Color3.fromRGB(96, 96, 100), "Piedra")
	end
	for k = 1, 4 do
		C.liston(modelo, centro + Vector3.new(math.cos(k) * 1.4, 0.4, math.sin(k) * 1.4), centro + Vector3.new(0, 3, 0), 0.6, M.Wood, Color3.fromRGB(70, 50, 34), "Lena")
	end
	C.fuego(modelo, centro + Vector3.new(0, 1.5, 0), if grande then 6 else 4)
	local runa = bloque(modelo, CFrame.new(centro + Vector3.new(radio + 5, 3.5, 0)), Vector3.new(1.4, 7, 3), M.Slate, Color3.fromRGB(110, 110, 116), "PiedraRunica")
	for k = 0, 3 do
		bloque(modelo, runa.CFrame * CFrame.new(-0.72, 2 - k * 1.4, n(-0.6, 0.6)), Vector3.new(0.05, 0.9, 0.25), M.Neon, Color3.fromRGB(120, 200, 255), "Runa").CanCollide = false
	end
end

-- ===================================================================
-- ===== TIENDAS: fachada propia + mostrador + objetos expuestos =====
-- ===================================================================

local COLOR_TEXTO = {
	Reino = Color3.fromRGB(240, 214, 150),
	Sol = Color3.fromRGB(255, 226, 150),
	Brujos = Color3.fromRGB(200, 160, 255),
	Norte = Color3.fromRGB(210, 230, 245),
}

-- Objetos expuestos en el mostrador según la tienda
local function expositor(modelo, cf, tipo, cultura)
	local arriba = cf * CFrame.new(0, 3.3, 0)
	if tipo == "Armas" then
		for k = -1, 1 do
			-- espadas apoyadas
			local p = arriba * CFrame.new(k * 1.6, 0.9, 0.3) * CFrame.Angles(math.rad(-12), 0, 0)
			bloque(modelo, p, Vector3.new(0.25, 2.6, 0.1), M.Metal, Color3.fromRGB(190, 194, 200), "Hoja")
			bloque(modelo, p * CFrame.new(0, -1.3, 0), Vector3.new(1, 0.2, 0.2), M.Metal, Color3.fromRGB(150, 120, 60), "Guarda")
		end
	elseif tipo == "Armaduras" then
		-- maniquí con peto y casco
		bloque(modelo, arriba * CFrame.new(0, 1.2, 0.2), Vector3.new(1.8, 2.2, 1), M.Metal, Color3.fromRGB(150, 152, 158), "Peto")
		C.bola(modelo, (arriba * CFrame.new(0, 2.8, 0.2)).Position, 1.2, M.Metal, Color3.fromRGB(140, 142, 148), "Casco")
	elseif tipo == "Pociones" then
		local colores = { Color3.fromRGB(220, 40, 50), Color3.fromRGB(60, 110, 255), Color3.fromRGB(80, 220, 90), Color3.fromRGB(240, 200, 60) }
		for k = 1, 6 do
			local frasco = C.bola(modelo, (arriba * CFrame.new(-2.4 + k * 0.7, 0.45, n(-0.2, 0.3))).Position, 0.7, M.Neon, colores[(k - 1) % 4 + 1], "Frasco")
			frasco.Transparency = 0.15
			frasco.CanCollide = false
		end
		C.luz(modelo:FindFirstChild("Frasco") or modelo, Color3.fromRGB(180, 140, 255), 0.8, 8)
	elseif tipo == "Herrero" then
		bloque(modelo, arriba * CFrame.new(1.2, 0.4, 0), Vector3.new(2.2, 0.8, 0.9), M.Metal, Color3.fromRGB(46, 46, 50), "Yunque")
		bloque(modelo, arriba * CFrame.new(-1.4, 0.2, 0), Vector3.new(0.4, 0.4, 2), M.Wood, Color3.fromRGB(100, 70, 44), "Martillo")
		bloque(modelo, arriba * CFrame.new(-1.4, 0.3, -0.9), Vector3.new(0.8, 0.6, 0.6), M.Metal, Color3.fromRGB(60, 60, 64), "CabezaMartillo")
	elseif tipo == "Establo" then
		-- balas de heno
		for k = -1, 1, 2 do
			bloque(modelo, arriba * CFrame.new(k * 1.4, 0.6, 0), Vector3.new(2, 1.2, 1.4), M.Grass, Color3.fromRGB(200, 176, 90), "Heno")
		end
	end
	local _ = cultura
end

-- Construye una tienda: devuelve el punto donde se pone el tendero (mirando hacia "plaza")
local function tienda(padre, cf, tipo, culturaId, cultura)
	local datos = TiendasConfig.TIPOS[tipo]
	local modelo, radio, alero = Casas[culturaId](padre, cf, {
		nombre = "Tienda_" .. tipo,
		pisos = if culturaId == "Brujos" then 2 else 1,
		ancho = if culturaId == "Norte" then 18 else 14,
		fondo = if culturaId == "Norte" then 11 else 11,
	})
	local fondo = 11
	-- cartel con el nombre encima de la puerta
	C.cartel(modelo, cf * CFrame.new(0, alero + 1.4, -fondo / 2 - 0.7), datos.nombre, {
		ancho = 8,
		alto = 1.8,
		colorTexto = COLOR_TEXTO[culturaId],
		color = if culturaId == "Brujos" then Color3.fromRGB(40, 30, 34) else Color3.fromRGB(96, 66, 42),
	})
	-- mostrador delante de la tienda
	local mostrador = cf * CFrame.new(0, 0, -fondo / 2 - 6.5)
	bloque(modelo, mostrador * CFrame.new(0, 1.6, 0), Vector3.new(6.5, 3.2, 1.8),
		if culturaId == "Sol" then M.Sandstone elseif culturaId == "Brujos" then M.WoodPlanks else M.WoodPlanks,
		if culturaId == "Sol" then Color3.fromRGB(214, 184, 140) elseif culturaId == "Brujos" then Color3.fromRGB(46, 36, 34) else Color3.fromRGB(116, 82, 52), "Mostrador")
	expositor(modelo, mostrador, tipo, cultura)
	-- toldo sobre el mostrador
	local telas = {
		Reino = { cultura.bandera, Color3.fromRGB(236, 226, 206) },
		Sol = { cultura.bandera, cultura.detalle },
		Brujos = { Color3.fromRGB(60, 30, 80), Color3.fromRGB(30, 20, 36) },
		Norte = { cultura.bandera, Color3.fromRGB(200, 204, 210) },
	}
	for _, sx in { -1, 1 } do
		C.columna(modelo, (mostrador * CFrame.new(sx * 3.4, 0, -1.6)).Position, 7.4, 0.4, M.Wood, Color3.fromRGB(70, 50, 34), "Poste")
		C.columna(modelo, (mostrador * CFrame.new(sx * 3.4, 0, 2.6)).Position, 8.4, 0.4, M.Wood, Color3.fromRGB(70, 50, 34), "Poste")
	end
	C.toldo(modelo, mostrador * CFrame.new(0, 8.4, 2.6), 7.4, 4.6, telas[culturaId][1], telas[culturaId][2])
	-- el tendero va entre la tienda y el mostrador, mirando hacia fuera
	local tendero = cf * CFrame.new(0, 0, -fondo / 2 - 4.2)
	return tendero, radio + 6
end

-- ===================================================================
-- ===== MURALLAS (solo capitales) =====
-- ===================================================================

local function muralla(padre, centro, radio, entrada, culturaId, cultura)
	local modelo = Instance.new("Model")
	modelo.Name = "Muralla"
	local estilos = {
		Reino = { M.Cobblestone, Color3.fromRGB(164, 158, 146), 14 },
		Sol = { M.Sandstone, Color3.fromRGB(222, 194, 150), 12 },
		Brujos = { M.WoodPlanks, Color3.fromRGB(40, 32, 30), 11 },
		Norte = { M.Slate, Color3.fromRGB(112, 112, 116), 12 },
	}
	local material, color, alto = estilos[culturaId][1], estilos[culturaId][2], estilos[culturaId][3]
	local anguloEntrada = math.atan2(entrada.Y, entrada.X)
	local tramos = 36
	local hueco = math.rad(9) -- media apertura de la puerta
	for i = 0, tramos - 1 do
		local a0 = i / tramos * math.pi * 2
		local a1 = (i + 1) / tramos * math.pi * 2
		local medio = (a0 + a1) / 2
		local diferencia = math.abs((medio - anguloEntrada + math.pi) % (math.pi * 2) - math.pi)
		if diferencia > hueco then
			local p0 = centro + Vector3.new(math.cos(a0) * radio, 0, math.sin(a0) * radio)
			local p1 = centro + Vector3.new(math.cos(a1) * radio, 0, math.sin(a1) * radio)
			local largo = (p1 - p0).Magnitude + 1.5
			local medioP = (p0 + p1) / 2
			local suelo = sueloEn(medioP.X, medioP.Z, centro.Y)
			local cfTramo = CFrame.lookAt(Vector3.new(medioP.X, suelo + alto / 2 - 3, medioP.Z), Vector3.new(centro.X, suelo + alto / 2 - 3, centro.Z))
			bloque(modelo, cfTramo, Vector3.new(largo, alto + 6, 3), material, variar(color, 0.02), "Muro")
			if culturaId == "Brujos" then
				-- empalizada: puntas afiladas
				for t = -largo / 2 + 0.8, largo / 2 - 0.8, 2.2 do
					C.cono(modelo, (cfTramo * CFrame.new(t, alto / 2 + 3, 0)).Position, 1.4, 2.4, M.Wood, Color3.fromRGB(34, 28, 26), "Punta")
				end
			else
				for t = -largo / 2 + 1, largo / 2 - 1, 2.6 do
					bloque(modelo, cfTramo * CFrame.new(t, alto / 2 + 3.9, 0.9), Vector3.new(1.3, 1.8, 1.2), material, color, "Almena")
				end
			end
			-- torre cada 6 tramos
			if i % 6 == 0 then
				local base = Vector3.new(p0.X, suelo - 3, p0.Z)
				C.columna(modelo, base, alto + 11, 8, material, variar(color, 0.03), "Torre")
				if culturaId == "Reino" then
					C.cono(modelo, base + Vector3.new(0, alto + 11, 0), 9.6, 8, M.Slate, Color3.fromRGB(70, 86, 116), "TejadoTorre")
				elseif culturaId == "Norte" then
					C.cono(modelo, base + Vector3.new(0, alto + 11, 0), 10, 6, M.WoodPlanks, Color3.fromRGB(70, 52, 38), "TejadoTorre")
					C.cono(modelo, base + Vector3.new(0, alto + 12.5, 0), 7, 4.4, M.Snow, Color3.fromRGB(236, 240, 246), "Nieve")
				elseif culturaId == "Sol" then
					C.bola(modelo, base + Vector3.new(0, alto + 11, 0), 6, M.Foil, cultura.detalle, "Cupulita")
				else
					C.cono(modelo, base + Vector3.new(0, alto + 11, 0), 9, 9, M.Slate, Color3.fromRGB(38, 32, 46), "TejadoTorre")
				end
			end
		end
	end
	-- puerta: dos torres a los lados y un arco por encima
	local direccion = Vector3.new(entrada.X, 0, entrada.Y)
	local lado = Vector3.new(-entrada.Y, 0, entrada.X)
	local puertaP = centro + direccion * radio
	local suelo = sueloEn(puertaP.X, puertaP.Z, centro.Y)
	for _, s in { -1, 1 } do
		local base = Vector3.new(puertaP.X, suelo - 3, puertaP.Z) + lado * s * 9.5
		C.columna(modelo, base, alto + 13, 9, material, color, "TorrePuerta")
		if culturaId == "Reino" or culturaId == "Brujos" then
			C.cono(modelo, base + Vector3.new(0, alto + 13, 0), 10.6, 9, M.Slate, if culturaId == "Reino" then Color3.fromRGB(70, 86, 116) else Color3.fromRGB(38, 32, 46), "TejadoTorre")
		elseif culturaId == "Sol" then
			C.bola(modelo, base + Vector3.new(0, alto + 13, 0), 7, M.Foil, cultura.detalle, "Cupulita")
		end
		C.estandarte(modelo, Vector3.new(puertaP.X, suelo, puertaP.Z) + lado * s * 6 + direccion * 3, 11, cultura.bandera, cultura.detalle, direccion)
	end
	bloque(modelo, CFrame.lookAt(Vector3.new(puertaP.X, suelo + alto + 1, puertaP.Z), Vector3.new(puertaP.X, suelo + alto + 1, puertaP.Z) + lado), Vector3.new(3, 6, 19), material, color, "Arco")
	modelo.Parent = padre
	return puertaP, suelo
end

-- Valla de madera (aldeas). Deja huecos para entrar.
local function valla(padre, centro, radio, entrada, culturaId)
	local modelo = Instance.new("Model")
	modelo.Name = "Valla"
	local colores = { Reino = Color3.fromRGB(110, 80, 52), Sol = Color3.fromRGB(214, 184, 140), Brujos = Color3.fromRGB(40, 32, 30), Norte = Color3.fromRGB(96, 70, 46) }
	local color = colores[culturaId]
	local anguloEntrada = math.atan2(entrada.Y, entrada.X)
	local tramos = 28
	for i = 0, tramos - 1 do
		local a0, a1 = i / tramos * math.pi * 2, (i + 1) / tramos * math.pi * 2
		local medio = (a0 + a1) / 2
		local diferencia = math.abs((medio - anguloEntrada + math.pi) % (math.pi * 2) - math.pi)
		-- huecos: la entrada, el lado contrario y algún tramo al azar (vallas viejas)
		if diferencia > 0.3 and math.abs(diferencia - math.pi) > 0.25 and rng:NextNumber() > 0.12 then
			local p0 = centro + Vector3.new(math.cos(a0) * radio, 0, math.sin(a0) * radio)
			local p1 = centro + Vector3.new(math.cos(a1) * radio, 0, math.sin(a1) * radio)
			local y0 = sueloEn(p0.X, p0.Z, centro.Y)
			local y1 = sueloEn(p1.X, p1.Z, centro.Y)
			if culturaId == "Sol" then
				-- muro bajo de adobe
				local m = (p0 + p1) / 2
				bloque(modelo, CFrame.lookAt(Vector3.new(m.X, (y0 + y1) / 2 + 0.6, m.Z), Vector3.new(p1.X, (y0 + y1) / 2 + 0.6, p1.Z)), Vector3.new(1.2, 3.6, (p1 - p0).Magnitude + 0.6), M.Sandstone, variar(color, 0.03), "Adobe")
			else
				C.columna(modelo, Vector3.new(p0.X, y0 - 1, p0.Z), 4.8, 0.5, M.Wood, color, "Poste")
				for _, h in { 1.4, 2.8 } do
					C.liston(modelo, Vector3.new(p0.X, y0 + h, p0.Z), Vector3.new(p1.X, y1 + h, p1.Z), 0.3, M.Wood, variar(color, 0.04), "Travesano")
				end
			end
		end
	end
	modelo.Parent = padre
end

-- Faroles a lo largo de una calle y alrededor de la plaza
local COLOR_FAROL = {
	Reino = Color3.fromRGB(255, 190, 110),
	Sol = Color3.fromRGB(255, 200, 120),
	Brujos = Color3.fromRGB(160, 90, 255),
	Norte = Color3.fromRGB(255, 170, 90),
}

-- ===================================================================
-- ===== CONSTRUIR UN PUEBLO =====
-- ===================================================================

local function construirPueblo(padre, pueblo, sitio)
	local cultura = PueblosConfig.CULTURAS[pueblo.cultura]
	local culturaId = pueblo.cultura
	local esCapital = pueblo.tipo == "Capital"
	local modelo = Instance.new("Model")
	modelo.Name = pueblo.id

	local y = sueloEn(sitio.centro.X, sitio.centro.Y, sitio.altura)
	local centro = Vector3.new(sitio.centro.X, y, sitio.centro.Y)
	local entrada = sitio.entrada or Vector2.new(0, 1)
	local haciaEntrada = Vector3.new(entrada.X, 0, entrada.Y)
	local lateral = Vector3.new(-entrada.Y, 0, entrada.X)
	local radio = sitio.radio

	modelo:SetAttribute("Nombre", pueblo.nombre)
	modelo:SetAttribute("Titulo", pueblo.titulo)
	modelo:SetAttribute("Tipo", pueblo.tipo)
	modelo:SetAttribute("Cultura", culturaId)
	modelo:SetAttribute("Centro", centro)
	modelo:SetAttribute("Radio", radio)

	local ocupados = {} -- { posicion, radio } para que nada se pise
	local function libre(p, r)
		for _, o in ocupados do
			if (Vector3.new(p.X, 0, p.Z) - Vector3.new(o[1].X, 0, o[1].Z)).Magnitude < r + o[2] then
				return false
			end
		end
		-- la calle principal (de la plaza a la puerta) queda libre
		local relativo = p - centro
		local alLado = math.abs(relativo:Dot(lateral))
		local adelante = relativo:Dot(haciaEntrada)
		if adelante > 0 and alLado < r + 6 then
			return false
		end
		return true
	end
	local function ocupar(p, r)
		table.insert(ocupados, { p, r })
	end

	-- 1) Plaza central
	local plaza = centro + haciaEntrada * radio * (if esCapital then 0.12 else 0)
	local radioPlaza = if esCapital then 22 else 13
	local suelo = SUELO_PLAZA[culturaId]
	C.disco(modelo, plaza, radioPlaza * 2, suelo[1], suelo[2])
	Centros[culturaId](modelo, plaza, esCapital, cultura)
	ocupar(plaza, radioPlaza)

	-- 2) Edificio principal (detrás de la plaza)
	if esCapital then
		local p = centro - haciaEntrada * radio * 0.55
		local cf = mirandoA(Vector3.new(p.X, sueloEn(p.X, p.Z, y), p.Z), plaza)
		local _, r = Principales[culturaId](modelo, cf, cultura)
		ocupar(p, r)
	end

	-- 3) Tiendas alrededor de la plaza, mirando a la fuente
	local npcs = {}
	local tiendas = pueblo.tiendas
	local distanciaTienda = radioPlaza + 15
	for i, tipo in tiendas do
		-- repartidas por los lados de la plaza (sin tapar la calle de la entrada)
		local total = #tiendas
		local abanico = if esCapital then math.rad(250) else math.rad(150)
		local base = math.atan2(-entrada.Y, -entrada.X) -- hacia el fondo
		local angulo = base + (if total == 1 then 0 else (i - 1) / (total - 1) - 0.5) * abanico
		local p = plaza + Vector3.new(math.cos(angulo), 0, math.sin(angulo)) * distanciaTienda
		local cf = mirandoA(Vector3.new(p.X, sueloEn(p.X, p.Z, y), p.Z), plaza)
		local tendero, r = tienda(modelo, cf, tipo, culturaId, cultura)
		ocupar(p, r - 4)
		table.insert(npcs, { oficio = tipo, cf = tendero, tienda = tipo })
	end

	-- 4) Casas en anillos alrededor
	local casas = if esCapital then 26 else rng:NextInteger(5, 7)
	local intentos = 0
	local puestas = 0
	while puestas < casas and intentos < casas * 30 do
		intentos += 1
		local angulo = n(0, math.pi * 2)
		local distancia = n(radioPlaza + 18, radio * (if esCapital then 0.82 else 0.85))
		local p = plaza + Vector3.new(math.cos(angulo), 0, math.sin(angulo)) * distancia
		if (p - centro).Magnitude < radio * 0.86 then
			local estimado = if culturaId == "Norte" then 15 else 10.5
			if libre(p, estimado) then
				local yy = sueloEn(p.X, p.Z, y)
				-- las casas miran hacia la plaza, con un poco de desorden
				local cf = mirandoA(Vector3.new(p.X, yy, p.Z), plaza) * CFrame.Angles(0, math.rad(n(-14, 14)), 0)
				local _, r = Casas[culturaId](modelo, cf)
				ocupar(p, r)
				puestas += 1
				-- detalles junto a la casa
				local junto = (cf * CFrame.new(n(-5, 5), 0, -r - 1.5)).Position
				if rng:NextNumber() < 0.5 then
					C.barril(modelo, Vector3.new(junto.X, sueloEn(junto.X, junto.Z, yy), junto.Z))
				elseif rng:NextNumber() < 0.5 then
					C.caja(modelo, Vector3.new(junto.X, sueloEn(junto.X, junto.Z, yy), junto.Z))
				end
			end
		end
	end

	-- 5) Faroles: alrededor de la plaza y por la calle de la entrada
	local colorFarol = COLOR_FAROL[culturaId]
	local cuantosFaroles = if esCapital then 8 else 4
	for k = 1, cuantosFaroles do
		local angulo = k / cuantosFaroles * math.pi * 2 + 0.2
		local p = plaza + Vector3.new(math.cos(angulo), 0, math.sin(angulo)) * (radioPlaza + 1.5)
		C.farol(modelo, Vector3.new(p.X, sueloEn(p.X, p.Z, y), p.Z), colorFarol)
	end
	for t = radioPlaza + 10, radio * 0.9, 18 do
		for _, s in { -1, 1 } do
			local p = plaza + haciaEntrada * t + lateral * s * 5.5
			C.farol(modelo, Vector3.new(p.X, sueloEn(p.X, p.Z, y), p.Z), colorFarol)
		end
	end

	-- 6) Murallas (capitales) o vallas (aldeas)
	local puertaP = nil
	if esCapital then
		local puerta, sueloPuerta = muralla(modelo, centro, radio * 0.95, entrada, culturaId, cultura)
		puertaP = Vector3.new(puerta.X, sueloPuerta, puerta.Z)
	else
		valla(modelo, centro, radio * 0.92, entrada, culturaId)
	end

	-- 7) Un poco de vegetación del lugar dentro del pueblo
	local plantas = { Reino = "HayaJoven", Sol = nil, Brujos = "Helecho", Norte = nil }
	if plantas[culturaId] then
		for _ = 1, (if esCapital then 6 else 3) do
			local angulo = n(0, math.pi * 2)
			local p = plaza + Vector3.new(math.cos(angulo), 0, math.sin(angulo)) * n(radioPlaza + 4, radio * 0.8)
			if libre(p, 3) then
				Vegetacion.Plantar(plantas[culturaId], p, modelo)
				ocupar(p, 3)
			end
		end
	elseif culturaId == "Sol" then
		for _ = 1, (if esCapital then 8 else 4) do
			local angulo = n(0, math.pi * 2)
			local p = plaza + Vector3.new(math.cos(angulo), 0, math.sin(angulo)) * n(radioPlaza + 4, radio * 0.8)
			if libre(p, 3) then
				Vegetacion.Palmera(Vector3.new(p.X, sueloEn(p.X, p.Z, y) - 0.5, p.Z), modelo)
				ocupar(p, 3)
			end
		end
	end

	-- 8) NPC: tenderos, guardias en la puerta y aldeanos en la plaza
	if puertaP then
		for _, s in { -1, 1 } do
			local p = puertaP + lateral * s * 4 + haciaEntrada * 2
			table.insert(npcs, { oficio = "Guardia", cf = mirandoA(Vector3.new(p.X, sueloEn(p.X, p.Z, y), p.Z), p + haciaEntrada * 10) })
		end
	end
	local aldeanos = if esCapital then 3 else 2
	for k = 1, aldeanos do
		local angulo = k / aldeanos * math.pi * 2 + n(-0.4, 0.4)
		local p = plaza + Vector3.new(math.cos(angulo), 0, math.sin(angulo)) * (radioPlaza * 0.7)
		table.insert(npcs, { oficio = "Aldeano", cf = mirandoA(Vector3.new(p.X, sueloEn(p.X, p.Z, y), p.Z), plaza + Vector3.new(n(-8, 8), 0, n(-8, 8))) })
	end
	local carpetaNPC = Instance.new("Folder")
	carpetaNPC.Name = "NPC"
	carpetaNPC.Parent = modelo
	local nombresUsados = {}
	for _, datos in npcs do
		local lista = PueblosConfig.NOMBRES[culturaId]
		local nombre = lista[rng:NextInteger(1, #lista)]
		local intentosNombre = 0
		while nombresUsados[nombre] and intentosNombre < 20 do
			nombre = lista[rng:NextInteger(1, #lista)]
			intentosNombre += 1
		end
		nombresUsados[nombre] = true
		NPCs.Crear(carpetaNPC, {
			nombre = nombre,
			oficio = datos.oficio,
			tienda = datos.tienda,
			cultura = culturaId,
			pueblo = pueblo,
			cf = datos.cf,
		})
	end

	modelo.Parent = padre
	return modelo
end

function Pueblos.Generar(mundo)
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Pueblos"
	carpeta.Parent = mundo
	local sitios = Terreno.SitiosPueblos()
	for _, pueblo in PueblosConfig.PUEBLOS do
		local sitio = sitios[pueblo.id]
		if sitio then
			local ok, err = pcall(construirPueblo, carpeta, pueblo, sitio)
			if ok then
				print(string.format("[MUNDO] Pueblo %s (%s) en %d, %d", pueblo.nombre, pueblo.tipo, sitio.centro.X, sitio.centro.Y))
			else
				warn("[MUNDO] Error construyendo", pueblo.nombre, err)
			end
			task.wait()
		end
	end
	return carpeta
end

return Pueblos

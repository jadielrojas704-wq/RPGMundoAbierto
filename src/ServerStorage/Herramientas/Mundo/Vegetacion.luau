-- Vegetación y rocas de cada región, construidas con piezas.
-- Ruta en Studio: ServerStorage/Herramientas/Mundo/Vegetacion
-- Lo usa ServerStorage/Herramientas/GenerarMundo. No se ejecuta solo.
--
-- Cada árbol/arbusto lleva la etiqueta "Vegetacion" y el atributo "Balanceo"
-- (grados) para que el script del cliente VientoVegetacion lo mueva con el viento.
-- Los árboles con hojas llevan un emisor de hojas que caen y vuelan con el viento.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Regiones = require(ReplicatedStorage.Config.RegionesConfig)
local Terreno = require(script.Parent.Terreno)

local Vegetacion = {}

local M = Enum.Material
local NIVEL_AGUA = Regiones.NIVEL_AGUA
local INICIO = Regiones.INICIO
local ALTAR = Regiones.ALTAR
local LIMITE = Regiones.MITAD - 150

local ID_HOJA = 13151745108 -- imagen de una hoja blanca (se tiñe de cualquier color)
local TEXTURA_RESERVA = "rbxasset://textures/particles/smoke_main.dds"

local rng = Random.new(Terreno.SEMILLA)
local texturaHoja = TEXTURA_RESERVA

-- ===== SUELO REAL =====
-- El terreno de Roblox está hecho de bloques de 4 x 4, así que su superficie real
-- no coincide exactamente con la altura calculada. Por eso medimos con un rayo.
local parametrosSuelo = RaycastParams.new()
parametrosSuelo.FilterType = Enum.RaycastFilterType.Include
parametrosSuelo.FilterDescendantsInstances = { Workspace.Terrain }
parametrosSuelo.IgnoreWater = false

-- Altura exacta del suelo en (x, z); nil si hay agua o nada
local function sueloReal(x, z)
	local resultado = Workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), parametrosSuelo)
	if not resultado or resultado.Material == Enum.Material.Water then
		return nil
	end
	return resultado.Position.Y
end

-- El punto más bajo del suelo alrededor de (x, z): así nada queda en el aire en las cuestas
local function sueloMinimo(x, z, radio)
	local minimo = sueloReal(x, z)
	if not minimo then
		return nil
	end
	for i = 1, 6 do
		local angulo = i / 6 * math.pi * 2
		local y = sueloReal(x + math.cos(angulo) * radio, z + math.sin(angulo) * radio)
		if y then
			minimo = math.min(minimo, y)
		end
	end
	return minimo
end

-- ===== AYUDANTES =====

local function n(a, b)
	return rng:NextNumber(a, b)
end

local function variarColor(color, cantidad)
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(
		(h + n(-cantidad, cantidad) * 0.15) % 1,
		math.clamp(s + n(-cantidad, cantidad), 0, 1),
		math.clamp(v + n(-cantidad, cantidad), 0, 1)
	)
end

local function aclarar(color, cantidad)
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, math.clamp(s - cantidad * 0.3, 0, 1), math.clamp(v + cantidad, 0, 1))
end

local function parte(propiedades)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	for nombre, valor in propiedades do
		if nombre ~= "Parent" then
			p[nombre] = valor
		end
	end
	p.Parent = propiedades.Parent
	return p
end

local function ponerMaterial(p, material, alternativo)
	if not pcall(function()
		p.Material = material
	end) then
		p.Material = alternativo
	end
end

-- Cilindro entre dos puntos (los cilindros de Roblox van a lo largo del eje X)
local function cilindro(desde, hasta, grosor, color, padre)
	local largo = (hasta - desde).Magnitude
	if largo < 0.05 then
		return nil
	end
	return parte({
		Name = "Madera",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(largo + grosor * 0.3, grosor, grosor),
		CFrame = CFrame.lookAt((desde + hasta) / 2, hasta) * CFrame.Angles(0, math.pi / 2, 0),
		Material = M.Wood,
		Color = color,
		CanCollide = grosor > 0.8,
		Parent = padre,
	})
end

-- Elipsoide (bola estirada): parte cuadrada + malla de esfera
local function elipsoide(tamano, cframe, color, material, padre)
	local p = parte({
		Name = "Hojas",
		Size = tamano,
		CFrame = cframe,
		Color = color,
		CanCollide = false,
		CastShadow = true,
		Parent = padre,
	})
	ponerMaterial(p, material or M.LeafyGrass, M.Grass)
	local malla = Instance.new("SpecialMesh")
	malla.MeshType = Enum.MeshType.Sphere
	malla.Parent = p
	return p
end

-- Cono (malla de cono de Roblox). La malla mide 2 de ancho y 1 de alto,
-- por eso la escala es: ancho / 2, alto / 1
local MALLA_CONO = "rbxassetid://1033714"
local function cono(tamano, cframe, color, padre)
	local p = parte({
		Name = "Ramas",
		Size = tamano,
		CFrame = cframe,
		Color = color,
		Material = M.Grass, -- sin brillo de plástico
		CanCollide = false,
		CastShadow = true,
		Parent = padre,
	})
	local malla = Instance.new("SpecialMesh")
	malla.MeshType = Enum.MeshType.FileMesh
	malla.MeshId = MALLA_CONO
	malla.Scale = Vector3.new(tamano.X / 2, tamano.Y, tamano.Z / 2)
	malla.Parent = p
	return p
end

-- Hojas que caen desde la copa y vuelan con el viento
local function hojasQueCaen(copa, color, tasa)
	local emisor = Instance.new("ParticleEmitter")
	emisor.Name = "HojasCayendo"
	emisor.Texture = texturaHoja
	emisor.Color = ColorSequence.new(color, aclarar(color, 0.08))
	emisor.LightInfluence = 1
	emisor.Rate = tasa
	emisor.Lifetime = NumberRange.new(7, 11)
	emisor.Speed = NumberRange.new(0.2, 0.8)
	emisor.SpreadAngle = Vector2.new(180, 180)
	emisor.Acceleration = Vector3.new(0, -1.1, 0)
	emisor.Drag = 0.8
	emisor.WindAffectsDrag = true -- el viento las empuja
	emisor.Rotation = NumberRange.new(0, 360)
	emisor.RotSpeed = NumberRange.new(-120, 120)
	emisor.Size = NumberSequence.new(0.35)
	emisor.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.05, 0),
		NumberSequenceKeypoint.new(0.85, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emisor.Parent = copa
end

-- Prepara el modelo para el viento y lo guarda
local function terminarModelo(modelo, base, balanceo, carpeta)
	modelo.WorldPivot = CFrame.new(base)
	modelo:SetAttribute("Balanceo", balanceo)
	CollectionService:AddTag(modelo, "Vegetacion")
	modelo.Parent = carpeta
	return modelo
end

-- Tronco formado por varios tramos que se van afinando y curvando
local function tronco(base, alto, grosor, curva, color, padre)
	local puntos = { base - Vector3.new(0, 1.5, 0) }
	local direccion = Vector3.new(n(-curva, curva), 1, n(-curva, curva)).Unit
	local tramos = 4
	for _ = 1, tramos do
		direccion = (direccion + Vector3.new(n(-curva, curva), 0, n(-curva, curva))).Unit
		table.insert(puntos, puntos[#puntos] + direccion * (alto / tramos))
	end
	for i = 1, tramos do
		local afinado = 1 - (i - 1) / tramos * 0.55
		cilindro(puntos[i], puntos[i + 1], grosor * afinado, variarColor(color, 0.03), padre)
	end
	-- Raíces: base un poco más ancha
	cilindro(base - Vector3.new(0, 1.5, 0), base + Vector3.new(0, 1.2, 0), grosor * 1.35, color, padre)
	return puntos
end

-- ===== ÁRBOLES =====

-- Árbol de hojas (roble, abedul, roble oscuro, árbol dorado)
local function arbolHojas(base, carpeta, opciones)
	local modelo = Instance.new("Model")
	modelo.Name = opciones.nombre
	local escala = n(0.8, 1.25) * (opciones.escala or 1)
	local alto = n(opciones.alto[1], opciones.alto[2]) * escala
	local grosor = n(opciones.grosor[1], opciones.grosor[2]) * escala

	local puntos = tronco(base, alto, grosor, opciones.curva or 0.12, opciones.colorTronco, modelo)
	local cima = puntos[#puntos]

	-- Ramas principales que salen de la parte alta del tronco
	local puntas = { cima + Vector3.new(0, 1.5 * escala, 0) }
	local numeroRamas = rng:NextInteger(opciones.ramas[1], opciones.ramas[2])
	for r = 1, numeroRamas do
		local tramo = rng:NextInteger(#puntos - 2, #puntos - 1)
		local inicio = puntos[tramo]:Lerp(puntos[tramo + 1], n(0.2, 0.9))
		local angulo = (r / numeroRamas) * math.pi * 2 + n(-0.5, 0.5)
		local fuera = Vector3.new(math.cos(angulo), n(0.35, 0.8), math.sin(angulo)).Unit
		local fin = inicio + fuera * alto * n(0.28, 0.42)
		cilindro(inicio, fin, grosor * 0.45, variarColor(opciones.colorTronco, 0.03), modelo)
		table.insert(puntas, fin)
	end

	-- Grupos de hojas en la punta de cada rama: más claros arriba (les da el sol)
	local colorBase = opciones.colores[rng:NextInteger(1, #opciones.colores)]
	local copaCentral
	for indice, punta in puntas do
		for k = 1, rng:NextInteger(2, 3) do
			local ancho = n(opciones.hoja[1], opciones.hoja[2]) * escala
			local tamano = Vector3.new(ancho, ancho * n(0.6, 0.8) * (opciones.alargado or 1), ancho * n(0.85, 1.1))
			local desplazamiento = Vector3.new(n(-2, 2), n(-1, 2), n(-2, 2)) * escala
			local arriba = k == 1 and indice == 1
			local color = variarColor(colorBase, 0.05)
			if arriba then
				color = aclarar(color, 0.06)
			elseif desplazamiento.Y < 0 then
				color = aclarar(color, -0.05) -- sombra debajo
			end
			local hojas = elipsoide(
				tamano,
				CFrame.new(punta + desplazamiento) * CFrame.Angles(n(-0.3, 0.3), n(0, 6.28), n(-0.3, 0.3)),
				color,
				opciones.material,
				modelo
			)
			if indice == 1 and k == 1 then
				copaCentral = hojas
			end
		end
	end

	if copaCentral and opciones.hojasCaen then
		hojasQueCaen(copaCentral, colorBase, opciones.hojasCaen)
	end
	return terminarModelo(modelo, base, opciones.balanceo or 1.2, carpeta)
end

local ROBLE = {
	nombre = "Roble",
	alto = { 12, 19 },
	grosor = { 1.6, 2.4 },
	ramas = { 3, 5 },
	hoja = { 7, 11 },
	colorTronco = Color3.fromRGB(78, 60, 45),
	colores = {
		Color3.fromRGB(78, 104, 46),
		Color3.fromRGB(92, 112, 50),
		Color3.fromRGB(104, 118, 54),
		Color3.fromRGB(170, 140, 60), -- algunos dorados de otoño
	},
	hojasCaen = 0.35,
	balanceo = 1.1,
}

local ABEDUL = {
	nombre = "Abedul",
	alto = { 16, 24 },
	grosor = { 0.9, 1.3 },
	ramas = { 3, 4 },
	hoja = { 5, 8 },
	alargado = 1.4,
	curva = 0.08,
	colorTronco = Color3.fromRGB(214, 208, 196),
	colores = { Color3.fromRGB(128, 150, 62), Color3.fromRGB(150, 160, 70), Color3.fromRGB(196, 168, 70) },
	hojasCaen = 0.4,
	balanceo = 1.6,
}

local ROBLE_OSCURO = {
	nombre = "RobleOscuro",
	alto = { 14, 22 },
	grosor = { 1.8, 2.6 },
	ramas = { 3, 5 },
	hoja = { 7, 11 },
	curva = 0.2,
	colorTronco = Color3.fromRGB(46, 40, 36),
	colores = { Color3.fromRGB(38, 50, 36), Color3.fromRGB(46, 54, 38), Color3.fromRGB(60, 52, 40) },
	hojasCaen = 0.25,
	balanceo = 0.9,
}

local ARBOL_DORADO = {
	nombre = "ArbolDorado",
	alto = { 16, 22 },
	grosor = { 1.8, 2.4 },
	ramas = { 4, 6 },
	hoja = { 8, 12 },
	colorTronco = Color3.fromRGB(96, 80, 62),
	colores = { Color3.fromRGB(214, 172, 74), Color3.fromRGB(230, 190, 90) },
	hojasCaen = 0.6,
	balanceo = 1.3,
}

-- Abeto: tronco recto y "pisos" de ramas cada vez más pequeños
local function abeto(base, carpeta, oscuro)
	local modelo = Instance.new("Model")
	modelo.Name = "Abeto"
	local alto = n(24, 40) * (if oscuro then 1.15 else 0.9)
	local grosor = n(0.9, 1.4)
	local colorTronco = if oscuro then Color3.fromRGB(44, 36, 32) else Color3.fromRGB(70, 54, 42)
	cilindro(base - Vector3.new(0, 1.5, 0), base + Vector3.new(0, alto, 0), grosor, colorTronco, modelo)

	-- Copa: conos apilados que se solapan (la silueta real de un abeto)
	local colorBase = if oscuro then Color3.fromRGB(26, 40, 32) else Color3.fromRGB(40, 62, 42)
	local pisos = rng:NextInteger(5, 6)
	local anchoBase = alto * n(0.38, 0.46)
	for k = 1, pisos do
		local avance = (k - 1) / (pisos - 1)
		local altoPiso = alto * 0.36 * (1 - avance * 0.35)
		local ancho = anchoBase * (1 - avance * 0.8) + 1.2
		local yBase = alto * (0.14 + 0.66 * avance)
		cono(
			Vector3.new(ancho, altoPiso, ancho),
			CFrame.new(base + Vector3.new(n(-0.3, 0.3), yBase + altoPiso / 2, n(-0.3, 0.3)))
				* CFrame.Angles(n(-0.06, 0.06), n(0, 6.28), n(-0.06, 0.06)),
			variarColor(if k == pisos then aclarar(colorBase, 0.04) else colorBase, 0.035),
			modelo
		)
	end
	return terminarModelo(modelo, base, 0.7, carpeta)
end

-- Árbol muerto y retorcido
local function arbolMuerto(base, carpeta, color)
	local modelo = Instance.new("Model")
	modelo.Name = "ArbolMuerto"
	local alto = n(10, 18)
	local grosor = n(1.1, 1.8)
	local puntos = tronco(base, alto, grosor, 0.35, color, modelo)

	for r = 1, rng:NextInteger(4, 7) do
		local tramo = rng:NextInteger(2, #puntos - 1)
		local inicio = puntos[tramo]:Lerp(puntos[tramo + 1], n(0, 1))
		local angulo = r * 2.4 + n(-0.4, 0.4)
		local fuera = Vector3.new(math.cos(angulo), n(0.1, 0.7), math.sin(angulo)).Unit
		local fin = inicio + fuera * alto * n(0.2, 0.4)
		cilindro(inicio, fin, grosor * 0.35, variarColor(color, 0.03), modelo)
		-- Ramitas
		for _ = 1, rng:NextInteger(1, 2) do
			local fuera2 = (fuera + Vector3.new(n(-0.7, 0.7), n(0, 0.6), n(-0.7, 0.7))).Unit
			cilindro(fin, fin + fuera2 * n(2, 4), grosor * 0.18, color, modelo)
		end
	end
	return terminarModelo(modelo, base, 0.5, carpeta)
end

-- Cactus tipo saguaro
local function cactus(base, carpeta)
	local modelo = Instance.new("Model")
	modelo.Name = "Cactus"
	local alto = n(7, 15)
	local grosor = n(1.6, 2.2)
	local color = variarColor(Color3.fromRGB(78, 106, 62), 0.04)

	local function columna(desde, hasta, ancho)
		local c = cilindro(desde, hasta, ancho, color, modelo)
		if c then
			c.Name = "Cactus"
			c.Material = M.Grass
		end
		parte({
			Name = "Punta",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * ancho,
			CFrame = CFrame.new(hasta),
			Material = M.Grass,
			Color = color,
			Parent = modelo,
		})
	end

	columna(base - Vector3.new(0, 1, 0), base + Vector3.new(0, alto, 0), grosor)
	for _ = 1, rng:NextInteger(0, 3) do
		local angulo = n(0, 6.28)
		local lado = Vector3.new(math.cos(angulo), 0, math.sin(angulo))
		local inicio = base + Vector3.new(0, alto * n(0.35, 0.6), 0)
		local codo = inicio + lado * n(2.2, 3.2)
		local fin = codo + Vector3.new(0, n(2.5, 5), 0)
		columna(inicio, codo, grosor * 0.7)
		columna(codo, fin, grosor * 0.7)
	end
	modelo.WorldPivot = CFrame.new(base)
	modelo.Parent = carpeta -- los cactus no se mueven con el viento
	return modelo
end

-- Palmera del oasis
local function palmera(base, carpeta)
	local modelo = Instance.new("Model")
	modelo.Name = "Palmera"
	local alto = n(16, 24)
	local inclinacion = Vector3.new(n(-1, 1), 0, n(-1, 1)).Unit * 0.35
	local puntos = { base - Vector3.new(0, 1, 0) }
	for i = 1, 5 do
		local direccion = (Vector3.yAxis + inclinacion * (i / 5)).Unit
		table.insert(puntos, puntos[#puntos] + direccion * (alto / 5))
	end
	for i = 1, 5 do
		cilindro(puntos[i], puntos[i + 1], 1.3 - i * 0.12, Color3.fromRGB(122, 98, 68), modelo)
	end
	local cima = puntos[#puntos]
	local colorHoja = Color3.fromRGB(88, 118, 50)
	for k = 1, 9 do
		local angulo = k / 9 * math.pi * 2
		local fuera = Vector3.new(math.cos(angulo), 0, math.sin(angulo))
		-- Cada hoja: dos tramos, el segundo cae hacia abajo
		local medio = cima + fuera * 4.5 + Vector3.new(0, 0.8, 0)
		local punta = medio + fuera * 4 - Vector3.new(0, 2.6, 0)
		for _, tramo in { { cima, medio }, { medio, punta } } do
			local largo = (tramo[2] - tramo[1]).Magnitude
			local hoja = parte({
				Name = "Hoja",
				Size = Vector3.new(1.6, 0.25, largo + 0.6),
				CFrame = CFrame.lookAt((tramo[1] + tramo[2]) / 2, tramo[2]),
				Color = variarColor(colorHoja, 0.05),
				CanCollide = false,
				Parent = modelo,
			})
			ponerMaterial(hoja, M.LeafyGrass, M.Grass)
		end
	end
	return terminarModelo(modelo, base, 2.2, carpeta)
end

-- Arbusto de hojas
local function arbusto(base, carpeta, colores)
	local modelo = Instance.new("Model")
	modelo.Name = "Arbusto"
	local color = colores[rng:NextInteger(1, #colores)]
	for _ = 1, rng:NextInteger(2, 4) do
		local ancho = n(2.5, 5)
		elipsoide(
			Vector3.new(ancho, ancho * n(0.6, 0.8), ancho),
			CFrame.new(base + Vector3.new(n(-1.8, 1.8), ancho * 0.2, n(-1.8, 1.8))),
			variarColor(color, 0.06),
			M.LeafyGrass,
			modelo
		)
	end
	return terminarModelo(modelo, base, 2.5, carpeta)
end

-- Matorral seco del desierto
local function matorralSeco(base, carpeta)
	local modelo = Instance.new("Model")
	modelo.Name = "MatorralSeco"
	local color = variarColor(Color3.fromRGB(128, 104, 72), 0.05)
	for _ = 1, rng:NextInteger(6, 10) do
		local direccion = Vector3.new(n(-1, 1), n(0.2, 1), n(-1, 1)).Unit
		cilindro(base, base + direccion * n(1.5, 3), 0.15, color, modelo)
	end
	return terminarModelo(modelo, base, 2, carpeta)
end

-- Flores pequeñas en grupos
local COLORES_FLOR = {
	Color3.fromRGB(240, 236, 220),
	Color3.fromRGB(230, 200, 80),
	Color3.fromRGB(170, 130, 200),
	Color3.fromRGB(210, 90, 80),
}
local function flores(base, carpeta)
	local color = COLORES_FLOR[rng:NextInteger(1, #COLORES_FLOR)]
	for _ = 1, rng:NextInteger(4, 8) do
		parte({
			Name = "Flor",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * n(0.35, 0.55),
			CFrame = CFrame.new(base + Vector3.new(n(-2.5, 2.5), n(0.3, 0.7), n(-2.5, 2.5))),
			Color = variarColor(color, 0.05),
			Material = M.SmoothPlastic,
			CanCollide = false,
			CastShadow = false,
			Parent = carpeta,
		})
	end
end

-- Hongos del bosque oscuro (algunos brillan)
local hongosConLuz = 0
local function hongos(base, carpeta)
	local modelo = Instance.new("Model")
	modelo.Name = "Hongos"
	local brillan = hongosConLuz < 45 and rng:NextNumber() < 0.35
	local colorSombrero = if brillan
		then Color3.fromRGB(120, 205, 225)
		else ({ Color3.fromRGB(120, 80, 60), Color3.fromRGB(150, 60, 50), Color3.fromRGB(170, 150, 120) })[rng:NextInteger(1, 3)]
	for _ = 1, rng:NextInteger(2, 5) do
		local alto = n(0.8, 2.4)
		local posicion = base + Vector3.new(n(-1.5, 1.5), 0, n(-1.5, 1.5))
		cilindro(posicion - Vector3.new(0, 0.3, 0), posicion + Vector3.new(0, alto, 0), alto * 0.22, Color3.fromRGB(200, 192, 176), modelo)
		local ancho = alto * n(1, 1.5)
		local sombrero = elipsoide(
			Vector3.new(ancho, ancho * 0.4, ancho),
			CFrame.new(posicion + Vector3.new(0, alto, 0)),
			variarColor(colorSombrero, 0.04),
			M.SmoothPlastic,
			modelo
		)
		sombrero.Name = "Sombrero"
		if brillan then
			sombrero.Material = M.Neon
			sombrero.Transparency = 0.25
		end
	end
	if brillan then
		hongosConLuz += 1
		local luz = Instance.new("PointLight")
		luz.Color = Color3.fromRGB(110, 210, 255)
		luz.Brightness = 0.7
		luz.Range = 10
		luz.Parent = modelo:FindFirstChild("Sombrero")
	end
	modelo.Parent = carpeta
end

-- Rocas: grupos de bloques superpuestos para que no parezcan cajas
local function roca(base, carpeta, material, color, escala)
	local modelo = Instance.new("Model")
	modelo.Name = "Roca"
	local tamanoBase = n(3, 10) * (escala or 1)
	for i = 1, rng:NextInteger(2, 4) do
		local tamano = Vector3.new(n(0.6, 1.2), n(0.5, 0.9), n(0.6, 1.2)) * tamanoBase * (if i == 1 then 1 else n(0.5, 0.8))
		local separacion = if i == 1 then 0 else tamanoBase * 0.5
		-- Medio enterradas y giradas al azar
		local desplazamiento = Vector3.new(n(-1, 1) * separacion, -tamano.Y * 0.25, n(-1, 1) * separacion)
		parte({
			Name = "Piedra",
			Size = tamano,
			CFrame = CFrame.new(base + desplazamiento) * CFrame.Angles(n(-0.5, 0.5), n(0, 6.28), n(-0.5, 0.5)),
			Material = material,
			Color = variarColor(color, 0.04),
			Parent = modelo,
		})
	end
	modelo.Parent = carpeta
end

-- ===== COLOCAR TODO =====

-- Busca puntos al azar que cumplan una condición y llama a crear() en cada uno
local function sembrar(cantidad, intentosMaximos, condicion, crear)
	local hechos, intentos = 0, 0
	while hechos < cantidad and intentos < intentosMaximos do
		intentos += 1
		local x, z = n(-LIMITE, LIMITE), n(-LIMITE, LIMITE)
		local d = Terreno.muestrear(x, z)
		if d.altura > NIVEL_AGUA + 2 and d.camino < 0.15 and d.inicio < 0.3 and d.altar < 0.3 then
			local pendiente = Terreno.pendienteEn(x, z)
			local y = if condicion(d, pendiente, x, z) then sueloReal(x, z) else nil
			if y and y > NIVEL_AGUA + 1 then
				crear(Vector3.new(x, y, z), d)
				hechos += 1
			end
		end
		if intentos % 150 == 0 then
			task.wait()
		end
	end
	return hechos
end

local function esBosque(d)
	return d.bosque + d.borde > 0.55 and d.rio < 0.3
end
local function esOscuro(d)
	return d.oscuro + d.borde > 0.55
end
local function esDesierto(d)
	return d.desierto + d.borde > 0.55
end

-- ===== MODELOS 3D REALISTAS (de la tienda de Roblox) =====
-- Revisados uno a uno: son mallas 3D con texturas y NO traen scripts.
-- Aun así, al cargarlos se borra cualquier script por seguridad (Catalogo.Limpiar).
-- alto = altura final en studs (un personaje mide unos 5 studs)
local MODELOS = {
	Haya = { id = 8549269563, alto = { 34, 48 }, balanceo = 0.7, hojasCaen = Color3.fromRGB(120, 130, 60) },
	HayaGrande = { id = 7974633518, alto = { 48, 66 }, balanceo = 0.5, hojasCaen = Color3.fromRGB(120, 130, 60) },
	HayaJoven = { id = 9559507124, alto = { 10, 16 }, balanceo = 1.6, hojasCaen = Color3.fromRGB(120, 130, 60) },
	HojaAncha = { id = 8311837663, alto = { 30, 44 }, balanceo = 0.7, hojasCaen = Color3.fromRGB(150, 130, 55) },
	Cornejo = { id = 8311847129, alto = { 16, 24 }, balanceo = 1.1, hojasCaen = Color3.fromRGB(190, 120, 90) },
	Secuoya = { id = 6738079386, alto = { 75, 110 }, balanceo = 0.3 },
	Pantano = { id = 8549274603, alto = { 30, 46 }, balanceo = 0.5, hojasCaen = Color3.fromRGB(70, 70, 45) },
	Helecho = { id = 8311863188, alto = { 2.5, 4.5 }, balanceo = 4 },
	Arbusto = { id = 7974743121, alto = { 4, 8 }, balanceo = 2.5 },
	Roca = { id = 11902901882, alto = { 6, 20 }, balanceo = nil },
	-- Desierto (plantilla oficial de carreras de Roblox)
	Cactus = { id = 16176167405, alto = { 8, 16 }, balanceo = nil },
	Agave = { id = 16176165366, alto = { 2.5, 4.5 }, balanceo = 1 },
	Rodadora = { id = 16176163654, alto = { 2.5, 4 }, balanceo = 3 },
}

local Catalogo = require(script.Parent.Parent.Catalogo)
local plantillas = {}

-- Carga un modelo de la tienda y lo deja listo para copiarlo muchas veces
local function prepararPlantilla(nombre, datos)
	local modelo, informe = Catalogo.Cargar(datos.id)
	if not modelo then
		warn("[MUNDO] No pude cargar", nombre, datos.id, informe)
		return
	end
	local piezas, mallas = 0, 0
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") then
			piezas += 1
			if p:IsA("MeshPart") then
				mallas += 1
			end
			p.Anchored = true
			p.CanCollide = false -- las hojas no deben bloquear; el tronco tiene su propio colisionador
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	-- Seguridad y rendimiento: solo modelos de mallas y con pocas piezas
	if mallas == 0 or piezas > 60 then
		warn("[MUNDO] Descarto", nombre, "(", piezas, "piezas,", mallas, "mallas )")
		modelo:Destroy()
		return
	end
	-- Algunos árboles de la tienda traen un "disco" de tierra bajo el tronco (pieza Soil).
	-- Sobre la hierba parece una maceta, así que lo quitamos y apuntamos a qué altura
	-- estaba su parte de arriba: ahí debe quedar el suelo para que las raíces queden enterradas.
	local techoTierra = nil
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") then
			local nombrePieza = string.lower(p.Name)
			if nombrePieza:find("soil") or nombrePieza:find("dirt") or nombrePieza:find("mound") then
				local arriba = p.Position.Y + p.Size.Y / 2
				techoTierra = math.max(techoTierra or -math.huge, arriba)
				p:Destroy()
			end
		end
	end
	if techoTierra then
		local caja, tamano = modelo:GetBoundingBox()
		local fondo = caja.Position.Y - tamano.Y / 2
		modelo:SetAttribute("Enterrar", math.clamp((techoTierra - fondo) / tamano.Y, 0, 0.3))
		print(string.format("[MUNDO]    %s: quitado el disco de tierra (enterrar %.0f%%)", nombre, modelo:GetAttribute("Enterrar") * 100))
	end
	print("[MUNDO] Modelo listo:", nombre, informe)
	plantillas[nombre] = modelo
end

-- La pieza con más superficie horizontal suele ser la copa (para soltar hojas)
local function buscarCopa(modelo)
	local mejor, area = nil, 0
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") and p.Size.X * p.Size.Z > area then
			mejor, area = p, p.Size.X * p.Size.Z
		end
	end
	return mejor
end

-- Coloca una copia de un modelo realista en el suelo
local function colocarModelo(nombre, base, carpeta, escalaExtra)
	local plantilla = plantillas[nombre]
	if not plantilla then
		return nil
	end
	local datos = MODELOS[nombre]
	local copia = plantilla:Clone()

	-- Tamaño al azar dentro del rango, y giro al azar
	local _, tamano = copia:GetBoundingBox()
	local altoFinal = n(datos.alto[1], datos.alto[2]) * (escalaExtra or 1)
	pcall(function()
		copia:ScaleTo(copia:GetScale() * altoFinal / math.max(tamano.Y, 0.1))
	end)
	-- Giro alrededor del eje vertical del mundo, sin cambiar cómo viene orientado el modelo
	local pivote = copia:GetPivot()
	copia:PivotTo(CFrame.new(pivote.Position) * CFrame.Angles(0, n(0, math.pi * 2), 0) * pivote.Rotation)

	-- Apoyarlo en el punto más bajo del suelo real bajo su base, y hundirlo un poco:
	-- los árboles traen un montículo de raíces en la base que debe quedar enterrado
	local caja, tamanoFinal = copia:GetBoundingBox()
	local fondo = caja.Position.Y - tamanoFinal.Y / 2
	local radioBase = math.clamp(tamanoFinal.Y * 0.04, 0.6, 3)
	local suelo = sueloMinimo(base.X, base.Z, radioBase) or base.Y
	local hundir
	if not datos.balanceo then
		hundir = tamanoFinal.Y * 0.25 -- rocas y cactus: bien asentados
	elseif tamanoFinal.Y > 12 then
		-- árboles: las raíces bajo tierra (y si traía disco de tierra, hasta donde llegaba)
		hundir = math.max(tamanoFinal.Y * 0.04 + 0.6, tamanoFinal.Y * (plantilla:GetAttribute("Enterrar") or 0) + 0.4)
	else
		hundir = tamanoFinal.Y * 0.1 + 0.2 -- plantas pequeñas
	end
	copia:PivotTo(copia:GetPivot() + Vector3.new(base.X - caja.Position.X, suelo - hundir - fondo, base.Z - caja.Position.Z))
	base = Vector3.new(base.X, suelo, base.Z)

	-- Colisionador invisible en el tronco para no atravesar los árboles
	if datos.balanceo and tamanoFinal.Y > 12 then
		local grosor = math.clamp(tamanoFinal.Y * 0.035, 1.2, 4)
		parte({
			Name = "Colision",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(tamanoFinal.Y * 0.4, grosor, grosor),
			CFrame = CFrame.new(base + Vector3.new(0, tamanoFinal.Y * 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Transparency = 1,
			CanCollide = true,
			CanQuery = false,
			Parent = copia,
		})
	elseif not datos.balanceo then
		-- Las rocas sí son sólidas
		for _, p in copia:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanCollide = true
			end
		end
	end

	if datos.hojasCaen then
		local copa = buscarCopa(copia)
		if copa then
			hojasQueCaen(copa, datos.hojasCaen, 0.4)
		end
	end

	if datos.balanceo then
		copia.Name = nombre
		return terminarModelo(copia, base, datos.balanceo, carpeta)
	end
	copia.Parent = carpeta
	return copia
end

-- Pone un modelo realista; si no se pudo cargar, usa el de piezas como plan B
local function plantar(nombre, base, carpeta, planB, escalaExtra)
	if not colocarModelo(nombre, base, carpeta, escalaExtra) and planB then
		planB(base, carpeta)
	end
end

function Vegetacion.Generar(mundo)
	-- Textura de hoja: la imagen está dentro de un decal de la tienda
	local ok, objetos = pcall(function()
		return game:GetObjects("rbxassetid://" .. ID_HOJA)
	end)
	if ok and objetos[1] and objetos[1]:IsA("Decal") then
		texturaHoja = objetos[1].Texture
	else
		warn("[MUNDO] No pude cargar la textura de hoja; uso una de reserva")
	end

	print("[MUNDO] Cargando modelos 3D realistas...")
	for nombre, datos in MODELOS do
		prepararPlantilla(nombre, datos)
		task.wait()
	end

	local function carpeta(nombre)
		local c = Instance.new("Folder")
		c.Name = nombre
		c.Parent = mundo
		return c
	end
	local cBosque = carpeta("BosqueNormal")
	local cOscuro = carpeta("BosqueOscuro")
	local cDesierto = carpeta("Desierto")
	local cMontana = carpeta("Montanas")

	local cuenta = {}
	local function robleB(pos, c)
		arbolHojas(pos, c, ROBLE)
	end
	local function abedulB(pos, c)
		arbolHojas(pos, c, ABEDUL)
	end
	local function abetoOscuroB(pos, c)
		abeto(pos, c, true)
	end
	local function abetoB(pos, c)
		abeto(pos, c, false)
	end
	local function arbustoVerdeB(pos, c)
		arbusto(pos, c, { Color3.fromRGB(80, 108, 48), Color3.fromRGB(96, 116, 52) })
	end
	local function arbustoOscuroB(pos, c)
		arbusto(pos, c, { Color3.fromRGB(36, 48, 34), Color3.fromRGB(46, 52, 36) })
	end
	local function rocaB(pos, c)
		roca(pos, c, M.Rock, Color3.fromRGB(116, 110, 102))
	end

	-- ===== Bosque normal =====
	print("[MUNDO] Plantando el bosque normal...")
	cuenta.hayas = sembrar(130, 9000, function(d, p)
		return esBosque(d) and p < 0.5 and d.manchas < 0.25
	end, function(pos)
		plantar(if rng:NextNumber() < 0.22 then "HayaGrande" else "Haya", pos, cBosque, robleB)
	end)
	cuenta.hojaAncha = sembrar(70, 6000, function(d, p)
		return esBosque(d) and p < 0.5
	end, function(pos)
		plantar("HojaAncha", pos, cBosque, robleB)
	end)
	sembrar(50, 5000, function(d, p)
		return esBosque(d) and p < 0.5
	end, function(pos)
		plantar("Cornejo", pos, cBosque, abedulB)
	end)
	sembrar(70, 5000, function(d, p)
		return esBosque(d) and p < 0.55
	end, function(pos)
		plantar("HayaJoven", pos, cBosque, arbustoVerdeB)
	end)
	sembrar(170, 6000, function(d, p)
		return esBosque(d) and p < 0.6
	end, function(pos)
		plantar("Arbusto", pos, cBosque, arbustoVerdeB)
	end)
	sembrar(220, 6000, function(d, p)
		return esBosque(d) and p < 0.5 and d.manchas < 0.15
	end, function(pos)
		plantar("Helecho", pos, cBosque, nil)
	end)
	sembrar(70, 4000, function(d, p)
		return esBosque(d) and (p > 0.4 or rng:NextNumber() < 0.2)
	end, function(pos)
		plantar("Roca", pos, cBosque, rocaB)
	end)

	-- ===== Bosque oscuro: secuoyas enormes y árboles de pantano =====
	print("[MUNDO] Plantando el bosque oscuro...")
	cuenta.secuoyas = sembrar(170, 9000, function(d, p)
		return esOscuro(d) and p < 0.7 and d.pantano < 0.2
	end, function(pos)
		plantar("Secuoya", pos, cOscuro, abetoOscuroB)
	end)
	cuenta.pantano = sembrar(95, 6000, function(d, p)
		return esOscuro(d) and p < 0.7
	end, function(pos)
		plantar("Pantano", pos, cOscuro, function(posicion, c)
			arbolMuerto(posicion, c, Color3.fromRGB(58, 54, 50))
		end)
	end)
	sembrar(70, 4000, function(d, p)
		return esOscuro(d) and p < 0.5
	end, function(pos)
		hongos(pos, cOscuro)
	end)
	sembrar(170, 5000, function(d, p)
		return esOscuro(d) and p < 0.6
	end, function(pos)
		plantar("Helecho", pos, cOscuro, nil, 1.3)
	end)
	sembrar(60, 3000, function(d, p)
		return esOscuro(d) and p < 0.6
	end, function(pos)
		plantar("Arbusto", pos, cOscuro, arbustoOscuroB)
	end)
	sembrar(70, 4000, function(d, p)
		return esOscuro(d) and (p > 0.4 or rng:NextNumber() < 0.25)
	end, function(pos)
		plantar("Roca", pos, cOscuro, function(posicion, c)
			roca(posicion, c, M.Basalt, Color3.fromRGB(58, 56, 56))
		end)
	end)

	-- ===== Desierto (cactus, palmeras y matorrales hechos a mano) =====
	print("[MUNDO] Llenando el desierto...")
	cuenta.cactus = sembrar(120, 6000, function(d, p)
		return esDesierto(d) and p < 0.45 and d.meseta < 0.3
	end, function(pos)
		plantar("Cactus", pos, cDesierto, cactus)
	end)
	sembrar(110, 5000, function(d, p)
		return esDesierto(d) and p < 0.5
	end, function(pos)
		plantar("Agave", pos, cDesierto, matorralSeco)
	end)
	sembrar(60, 4000, function(d, p)
		return esDesierto(d) and p < 0.4
	end, function(pos)
		plantar("Rodadora", pos, cDesierto, matorralSeco)
	end)
	sembrar(110, 5000, function(d, p)
		return esDesierto(d) and (p > 0.35 or rng:NextNumber() < 0.3)
	end, function(pos)
		plantar("Roca", pos, cDesierto, function(posicion, c)
			roca(posicion, c, M.Sandstone, Color3.fromRGB(168, 100, 64), 1.3)
		end, 1.2)
	end)
	local oasis = Terreno.OASIS
	for i = 1, 9 do
		local angulo = i / 9 * math.pi * 2 + n(-0.2, 0.2)
		local distancia = n(62, 80)
		local x, z = oasis.X + math.cos(angulo) * distancia, oasis.Y + math.sin(angulo) * distancia
		local y = sueloMinimo(x, z, 1.5)
		if y and y > NIVEL_AGUA + 0.5 then
			palmera(Vector3.new(x, y - 0.5, z), cDesierto)
		end
	end

	-- ===== Montañas =====
	print("[MUNDO] Montañas...")
	sembrar(60, 4000, function(d, p)
		return d.montana > 0.5 and d.altura < 150 and p < 0.7
	end, function(pos)
		plantar("Secuoya", pos, cMontana, abetoB, 0.6)
	end)
	sembrar(70, 4000, function(d, p)
		return d.montana > 0.5 and p > 0.3
	end, function(pos)
		plantar("Roca", pos, cMontana, function(posicion, c)
			roca(posicion, c, M.Slate, Color3.fromRGB(96, 94, 90), 1.4)
		end, 1.4)
	end)

	for _, plantilla in plantillas do
		plantilla:Destroy()
	end

	print(
		string.format(
			"[MUNDO] %d hayas, %d de hoja ancha, %d secuoyas, %d de pantano, %d cactus",
			cuenta.hayas,
			cuenta.hojaAncha,
			cuenta.secuoyas,
			cuenta.pantano,
			cuenta.cactus
		)
	)
end

-- Árboles dorados para la isla (los usa Estructuras)
function Vegetacion.ArbolDorado(base, carpeta)
	return arbolHojas(base, carpeta, ARBOL_DORADO)
end

function Vegetacion.Roca(base, carpeta, material, color, escala)
	return roca(base, carpeta, material, color, escala)
end

return Vegetacion

-- Vegetación y rocas de cada región, construidas con piezas.
-- Ruta en Studio: ServerStorage/Herramientas/Mundo/Vegetacion
-- Lo usa ServerStorage/Herramientas/GenerarMundo. No se ejecuta solo.
--
-- Cada árbol/arbusto lleva la etiqueta "Vegetacion" y el atributo "Balanceo"
-- (grados) para que el script del cliente VientoVegetacion lo mueva con el viento.
-- Los árboles con hojas llevan un emisor de hojas que caen y vuelan con el viento.

local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
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
			if condicion(d, pendiente, x, z) then
				crear(Vector3.new(x, d.altura, z), d)
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

function Vegetacion.Generar(mundo)
	-- Textura de hoja: se busca la imagen dentro del decal de la tienda
	local ok, resultado = pcall(function()
		local modelo = InsertService:LoadAsset(ID_HOJA)
		local decal = modelo:FindFirstChildWhichIsA("Decal", true)
		local textura = decal and decal.Texture
		modelo:Destroy()
		return textura
	end)
	if ok and resultado then
		texturaHoja = resultado
	else
		local ok2, objetos = pcall(function()
			return game:GetObjects("rbxassetid://" .. ID_HOJA)
		end)
		if ok2 and objetos[1] and objetos[1]:IsA("Decal") then
			texturaHoja = objetos[1].Texture
		else
			warn("[MUNDO] No pude cargar la textura de hoja; uso una de reserva")
		end
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

	-- Bosque normal
	print("[MUNDO] Plantando el bosque normal...")
	cuenta.robles = sembrar(230, 9000, function(d, p)
		return esBosque(d) and p < 0.55 and d.manchas < 0.25
	end, function(pos)
		arbolHojas(pos, cBosque, ROBLE)
	end)
	cuenta.abedules = sembrar(80, 5000, function(d, p)
		return esBosque(d) and p < 0.5
	end, function(pos)
		arbolHojas(pos, cBosque, ABEDUL)
	end)
	sembrar(160, 5000, function(d, p)
		return esBosque(d) and p < 0.6
	end, function(pos)
		arbusto(pos, cBosque, { Color3.fromRGB(80, 108, 48), Color3.fromRGB(96, 116, 52) })
	end)
	sembrar(80, 4000, function(d, p)
		return esBosque(d) and p < 0.3 and d.manchas < 0.1
	end, function(pos)
		flores(pos, cBosque)
	end)
	sembrar(90, 4000, function(d, p)
		return esBosque(d) and (p > 0.4 or rng:NextNumber() < 0.2)
	end, function(pos)
		roca(pos, cBosque, M.Rock, Color3.fromRGB(116, 110, 102))
	end)

	-- Bosque oscuro: denso
	print("[MUNDO] Plantando el bosque oscuro...")
	cuenta.abetos = sembrar(260, 9000, function(d, p)
		return esOscuro(d) and p < 0.7
	end, function(pos)
		abeto(pos, cOscuro, true)
	end)
	cuenta.muertos = sembrar(110, 5000, function(d, p)
		return esOscuro(d) and p < 0.8
	end, function(pos)
		arbolMuerto(pos, cOscuro, Color3.fromRGB(58, 54, 50))
	end)
	sembrar(40, 3000, function(d, p)
		return esOscuro(d) and p < 0.5
	end, function(pos)
		arbolHojas(pos, cOscuro, ROBLE_OSCURO)
	end)
	sembrar(70, 4000, function(d, p)
		return esOscuro(d) and p < 0.5
	end, function(pos)
		hongos(pos, cOscuro)
	end)
	sembrar(80, 3000, function(d, p)
		return esOscuro(d) and p < 0.6
	end, function(pos)
		arbusto(pos, cOscuro, { Color3.fromRGB(36, 48, 34), Color3.fromRGB(46, 52, 36) })
	end)
	sembrar(90, 4000, function(d, p)
		return esOscuro(d) and (p > 0.4 or rng:NextNumber() < 0.25)
	end, function(pos)
		roca(pos, cOscuro, M.Basalt, Color3.fromRGB(58, 56, 56))
	end)

	-- Desierto
	print("[MUNDO] Llenando el desierto...")
	cuenta.cactus = sembrar(110, 6000, function(d, p)
		return esDesierto(d) and p < 0.45 and d.meseta < 0.3
	end, function(pos)
		cactus(pos, cDesierto)
	end)
	sembrar(90, 4000, function(d, p)
		return esDesierto(d) and p < 0.5
	end, function(pos)
		matorralSeco(pos, cDesierto)
	end)
	sembrar(30, 3000, function(d, p)
		return esDesierto(d) and p < 0.5
	end, function(pos)
		arbolMuerto(pos, cDesierto, Color3.fromRGB(150, 132, 108))
	end)
	sembrar(110, 5000, function(d, p)
		return esDesierto(d) and (p > 0.35 or rng:NextNumber() < 0.3)
	end, function(pos)
		roca(pos, cDesierto, M.Sandstone, Color3.fromRGB(168, 100, 64), 1.3)
	end)

	-- Palmeras alrededor del oasis
	local oasis = Terreno.OASIS
	for i = 1, 9 do
		local angulo = i / 9 * math.pi * 2 + n(-0.2, 0.2)
		local distancia = n(62, 80)
		local x, z = oasis.X + math.cos(angulo) * distancia, oasis.Y + math.sin(angulo) * distancia
		local d = Terreno.muestrear(x, z)
		if d.altura > NIVEL_AGUA + 0.5 then
			palmera(Vector3.new(x, d.altura, z), cDesierto)
		end
	end

	-- Montañas: abetos en las laderas bajas y rocas
	print("[MUNDO] Montañas...")
	sembrar(70, 4000, function(d, p)
		return d.montana > 0.5 and d.altura < 150 and p < 0.7
	end, function(pos)
		abeto(pos, cMontana, false)
	end)
	sembrar(80, 4000, function(d, p)
		return d.montana > 0.5 and p > 0.3
	end, function(pos)
		roca(pos, cMontana, M.Slate, Color3.fromRGB(96, 94, 90), 1.4)
	end)

	print(
		string.format(
			"[MUNDO] %d robles, %d abedules, %d abetos, %d árboles muertos, %d cactus",
			cuenta.robles,
			cuenta.abedules,
			cuenta.abetos,
			cuenta.muertos,
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

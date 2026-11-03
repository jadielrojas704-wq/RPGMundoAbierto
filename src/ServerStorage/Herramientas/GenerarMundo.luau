-- Generador del mundo abierto (terreno, agua, árboles, rocas, iluminación).
-- Ruta en Studio: ServerStorage/Herramientas/GenerarMundo
--
-- NO se ejecuta solo al jugar. Se usa UNA vez desde la barra de comandos de Studio
-- (en modo edición, sin darle a Play):
--
--     require(game.ServerStorage.Herramientas.GenerarMundo).Generar()
--
-- Después hay que GUARDAR el lugar (File > Save to File) para que el mundo se quede.
-- Si lo vuelves a ejecutar, borra el mundo anterior y crea uno nuevo.
--
-- Mapa de 1024 x 1024 studs:
--   Norte -> montañas con nieve      Este  -> mesetas rojas (estilo desierto del oeste)
--   Oeste -> lago con playa          Centro -> colinas de hierba, río y la zona de inicio

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local GenerarMundo = {}

-- ===== AJUSTES =====
local TAMANO = 1024 -- lado del mapa en studs
local RES = 4 -- tamaño de cada bloque de terreno (siempre 4)
local ALTURA_MAX = 240
local NIVEL_AGUA = 20
local SEMILLA = 7 -- cambia este número para obtener otro mundo distinto

local INICIO = Vector2.new(160, 140) -- dónde aparecen los jugadores (X, Z)
local LAGO = Vector2.new(-330, 150)

local M = Enum.Material

-- ===== RUIDO (para que el terreno parezca natural) =====

local function suave(a, b, x)
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

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

local function rioX(z)
	return -60 + math.sin(z / 170) * 90 + ruido(0, z, 2, 200, SEMILLA + 4) * 80
end
local function caminoEsteZ(x)
	return INICIO.Y + math.sin(x / 120) * 35
end
local function caminoNorteX(z)
	return INICIO.X + math.sin(z / 90) * 28
end

-- Calcula la altura y las "zonas" de un punto del mapa
local function muestrear(x, z)
	local d = {}

	-- Colinas suaves + detalles
	local h = 38 + ruido(x, z, 4, 320, SEMILLA) * 80 + ruido(x, z, 3, 60, SEMILLA + 9) * 6

	-- Montañas al norte (crestas)
	d.norte = suave(-120, -380, z)
	local cresta = math.clamp(1 - math.abs(ruido(x, z, 4, 240, SEMILLA + 2) * 2.2), 0, 1) ^ 2
	h += d.norte * cresta * 190

	-- Mesetas al este: cimas planas con paredes empinadas
	d.este = suave(160, 340, x)
	d.meseta = suave(0, 0.06, ruido(x, z, 3, 170, SEMILLA + 3)) * d.este
	h += d.meseta * 75

	-- Montañas en los bordes para cerrar el mapa
	local borde = suave(400, 505, math.max(math.abs(x), math.abs(z)))
	h += borde * (90 + cresta * 80)

	-- Río
	local anchoRio = 16 + ruido(z, 0, 2, 150, SEMILLA + 5) * 10
	d.rio = 1 - suave(anchoRio, anchoRio + 45, math.abs(x - rioX(z)))
	h += ((NIVEL_AGUA - 7) - h) * d.rio

	-- Lago
	local distanciaLago = (Vector2.new(x, z) - LAGO).Magnitude + ruido(x, z, 2, 80, SEMILLA + 6) * 40
	d.lago = 1 - suave(70, 160, distanciaLago)
	h += ((NIVEL_AGUA - 12) - h) * d.lago

	-- Caminos de tierra
	d.camino = 0
	if x > INICIO.X then
		d.camino = math.max(d.camino, 1 - suave(3, 7, math.abs(z - caminoEsteZ(x))))
	end
	if z < INICIO.Y then
		d.camino = math.max(d.camino, 1 - suave(3, 7, math.abs(x - caminoNorteX(z))))
	end

	-- Zona de inicio llana
	d.inicio = 1 - suave(30, 80, (Vector2.new(x, z) - INICIO).Magnitude)
	h += (36 - h) * d.inicio

	d.altura = math.clamp(h, 6, ALTURA_MAX - 6)
	d.manchas = ruido(x, z, 2, 70, SEMILLA + 8)
	return d
end

local function pendienteEn(x, z)
	local a = muestrear(x + RES, z).altura - muestrear(x - RES, z).altura
	local b = muestrear(x, z + RES).altura - muestrear(x, z - RES).altura
	return math.max(math.abs(a), math.abs(b)) / (2 * RES)
end

-- Elige el material de la superficie según la altura, la pendiente y la zona
local function elegirMaterial(d, pendiente, x, z)
	local h = d.altura
	if h < NIVEL_AGUA + 2.5 then
		if d.lago > 0.3 then
			return M.Sand
		end
		return if ruido(x, z, 1, 30, SEMILLA + 7) > 0 then M.Mud else M.Ground
	end
	if h > 185 and pendiente < 1.3 then
		return M.Snow
	end
	if h > 150 then
		return if pendiente > 0.9 then M.Rock else M.Slate
	end
	if d.meseta > 0.2 and pendiente > 0.6 then
		return M.Sandstone -- paredes rojas de las mesetas
	end
	if pendiente > 1.1 then
		return if d.norte > 0.3 then M.Basalt else M.Rock
	end
	if d.camino > 0.5 or pendiente > 0.65 then
		return M.Ground
	end
	if d.este > 0.5 and d.manchas > -0.1 then
		return M.Ground -- el este es más seco
	end
	if d.manchas > 0.18 then
		return M.Ground
	end
	if d.manchas < -0.12 then
		return M.LeafyGrass
	end
	return M.Grass
end

-- ===== TERRENO =====

local function crearTerreno()
	local terreno = Workspace.Terrain
	terreno:Clear()

	local columnas = TAMANO / RES -- 256
	local capas = ALTURA_MAX / RES -- 60
	local mitad = TAMANO / 2

	-- 1) Alturas de todo el mapa (con un borde extra para calcular pendientes)
	print("[MUNDO] Calculando alturas...")
	local datos = {}
	for i = 0, columnas + 1 do
		datos[i] = {}
		for j = 0, columnas + 1 do
			local x = -mitad + (i - 0.5) * RES
			local z = -mitad + (j - 0.5) * RES
			datos[i][j] = muestrear(x, z)
		end
		if i % 32 == 0 then
			task.wait()
		end
	end

	-- 2) Escribir el terreno por trozos de 64 x 64 columnas
	local TROZO = 64
	local total = (columnas / TROZO) ^ 2
	local hecho = 0
	for ci = 0, columnas / TROZO - 1 do
		for cj = 0, columnas / TROZO - 1 do
			local materiales, ocupacion = {}, {}
			for a = 1, TROZO do
				local i = ci * TROZO + a
				materiales[a], ocupacion[a] = {}, {}
				for k = 1, capas do
					materiales[a][k], ocupacion[a][k] = {}, {}
				end
				for b = 1, TROZO do
					local j = cj * TROZO + b
					local d = datos[i][j]
					local h = d.altura
					local pendiente = math.max(
						math.abs(datos[i + 1][j].altura - datos[i - 1][j].altura),
						math.abs(datos[i][j + 1].altura - datos[i][j - 1].altura)
					) / (2 * RES)
					local x = -mitad + (i - 0.5) * RES
					local z = -mitad + (j - 0.5) * RES
					local superficie = elegirMaterial(d, pendiente, x, z)

					for k = 1, capas do
						local fondo = (k - 1) * RES
						local lleno = math.clamp((h - fondo) / RES, 0, 1)
						ocupacion[a][k][b] = lleno
						if lleno > 0 then
							materiales[a][k][b] = if h - fondo > 10 then M.Rock else superficie
						else
							materiales[a][k][b] = M.Air
						end
					end
				end
			end

			local x0 = -mitad + ci * TROZO * RES
			local z0 = -mitad + cj * TROZO * RES
			local region = Region3.new(
				Vector3.new(x0, 0, z0),
				Vector3.new(x0 + TROZO * RES, ALTURA_MAX, z0 + TROZO * RES)
			)
			terreno:WriteVoxels(region, RES, materiales, ocupacion)

			hecho += 1
			print(string.format("[MUNDO] Terreno %d / %d", hecho, total))
			task.wait()
		end
	end

	-- 3) Llenar de agua todo lo que quedó por debajo del nivel del agua
	local regionAgua = Region3.new(Vector3.new(-mitad, 0, -mitad), Vector3.new(mitad, NIVEL_AGUA, mitad))
	terreno:ReplaceMaterial(regionAgua, RES, M.Air, M.Water)

	-- 4) Colores de los materiales (paleta cálida y apagada)
	local colores = {
		[M.Grass] = Color3.fromRGB(112, 118, 62),
		[M.LeafyGrass] = Color3.fromRGB(94, 108, 54),
		[M.Ground] = Color3.fromRGB(122, 100, 72),
		[M.Sandstone] = Color3.fromRGB(172, 94, 58),
		[M.Rock] = Color3.fromRGB(112, 105, 96),
		[M.Slate] = Color3.fromRGB(96, 93, 88),
		[M.Basalt] = Color3.fromRGB(62, 60, 58),
		[M.Sand] = Color3.fromRGB(192, 172, 130),
		[M.Mud] = Color3.fromRGB(80, 64, 48),
	}
	for material, color in colores do
		terreno:SetMaterialColor(material, color)
	end

	-- 5) Agua y hierba que se mueve con el viento
	terreno.WaterColor = Color3.fromRGB(58, 84, 78)
	terreno.WaterTransparency = 0.65
	terreno.WaterReflectance = 0.4
	terreno.WaterWaveSize = 0.1
	terreno.WaterWaveSpeed = 6
	pcall(function()
		terreno.Decoration = true
	end)
end

-- ===== OBJETOS (árboles, arbustos, rocas, fogata) =====

local rng = Random.new(SEMILLA)

local function nuevaParte(propiedades)
	local parte = Instance.new("Part")
	parte.Anchored = true
	parte.TopSurface = Enum.SurfaceType.Smooth
	parte.BottomSurface = Enum.SurfaceType.Smooth
	for nombre, valor in propiedades do
		parte[nombre] = valor
	end
	return parte
end

local function ponerMaterial(parte, material, alternativo)
	local ok = pcall(function()
		parte.Material = material
	end)
	if not ok then
		parte.Material = alternativo
	end
end

local function variarColor(color, cantidad)
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, math.clamp(s + rng:NextNumber(-cantidad, cantidad), 0, 1), math.clamp(v + rng:NextNumber(-cantidad, cantidad), 0, 1))
end

local COPAS = {
	Color3.fromRGB(86, 104, 50), -- verde
	Color3.fromRGB(110, 112, 56), -- oliva
	Color3.fromRGB(178, 142, 62), -- dorado
	Color3.fromRGB(152, 110, 52), -- ocre
}

local function crearArbol(posicion, carpeta)
	local modelo = Instance.new("Model")
	local muerto = rng:NextNumber() < 0.15
	modelo.Name = if muerto then "ArbolSeco" else "Arbol"

	local alto = rng:NextNumber(14, 24)
	local grosor = rng:NextNumber(1.4, 2.4)
	local base = CFrame.new(posicion)
		* CFrame.Angles(rng:NextNumber(-0.08, 0.08), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.08, 0.08))
	local colorMadera = if muerto then Color3.fromRGB(92, 84, 76) else Color3.fromRGB(80, 62, 46)

	-- Tronco (los cilindros de Roblox van a lo largo del eje X, por eso se giran)
	nuevaParte({
		Name = "Tronco",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(alto, grosor, grosor),
		CFrame = base * CFrame.new(0, alto / 2 - 1, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Material = M.Wood,
		Color = variarColor(colorMadera, 0.05),
		Parent = modelo,
	})

	-- Ramas
	local numeroRamas = if muerto then 4 else rng:NextInteger(2, 3)
	for r = 1, numeroRamas do
		local largo = alto * rng:NextNumber(0.3, 0.45)
		local alturaRama = alto * rng:NextNumber(0.55, 0.85)
		local angulo = (r / numeroRamas) * math.pi * 2 + rng:NextNumber(-0.5, 0.5)
		nuevaParte({
			Name = "Rama",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(largo, grosor * 0.45, grosor * 0.45),
			CFrame = base
				* CFrame.new(0, alturaRama, 0)
				* CFrame.Angles(0, angulo, 0)
				* CFrame.Angles(0, 0, math.rad(rng:NextNumber(25, 50)))
				* CFrame.new(largo / 2, 0, 0),
			Material = M.Wood,
			Color = variarColor(colorMadera, 0.05),
			CanCollide = false,
			Parent = modelo,
		})
	end

	-- Copa de hojas
	if not muerto then
		local colorCopa = COPAS[rng:NextInteger(1, #COPAS)]
		for _ = 1, rng:NextInteger(4, 6) do
			local tamano = rng:NextNumber(7, 13)
			local hoja = nuevaParte({
				Name = "Hojas",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * tamano,
				CFrame = base * CFrame.new(rng:NextNumber(-5, 5), alto + rng:NextNumber(-3, 3), rng:NextNumber(-5, 5)),
				Color = variarColor(colorCopa, 0.06),
				CanCollide = false,
				Parent = modelo,
			})
			ponerMaterial(hoja, M.LeafyGrass, M.Grass)
		end
	end

	modelo.Parent = carpeta
end

local function crearArbusto(posicion, carpeta)
	local color = COPAS[rng:NextInteger(1, 2)]
	for _ = 1, rng:NextInteger(2, 3) do
		local tamano = rng:NextNumber(3, 6)
		local hoja = nuevaParte({
			Name = "Arbusto",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * tamano,
			CFrame = CFrame.new(posicion + Vector3.new(rng:NextNumber(-2, 2), tamano * 0.25, rng:NextNumber(-2, 2))),
			Color = variarColor(color, 0.07),
			CanCollide = false,
			Parent = carpeta,
		})
		ponerMaterial(hoja, M.LeafyGrass, M.Grass)
	end
end

local function crearRoca(posicion, d, carpeta)
	local tamano = Vector3.new(rng:NextNumber(3, 12), rng:NextNumber(2.5, 9), rng:NextNumber(3, 12))
	local material, color
	if d.este > 0.5 then
		material, color = M.Sandstone, Color3.fromRGB(160, 92, 60)
	elseif d.norte > 0.3 then
		material, color = M.Slate, Color3.fromRGB(90, 88, 84)
	else
		material, color = M.Rock, Color3.fromRGB(112, 106, 98)
	end
	nuevaParte({
		Name = "Roca",
		Size = tamano,
		-- Medio enterrada y girada al azar para que parezca natural
		CFrame = CFrame.new(posicion - Vector3.new(0, tamano.Y * 0.3, 0))
			* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.4, 0.4)),
		Material = material,
		Color = variarColor(color, 0.05),
		Parent = carpeta,
	})
end

local function crearFogata(posicion, carpeta)
	local modelo = Instance.new("Model")
	modelo.Name = "Fogata"

	-- Anillo de piedras
	for i = 1, 9 do
		local angulo = (i / 9) * math.pi * 2
		nuevaParte({
			Name = "Piedra",
			Size = Vector3.new(1.2, 0.8, 1),
			CFrame = CFrame.new(posicion + Vector3.new(math.cos(angulo) * 2.4, 0.3, math.sin(angulo) * 2.4))
				* CFrame.Angles(0, -angulo + rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.2, 0.2)),
			Material = M.Slate,
			Color = variarColor(Color3.fromRGB(95, 92, 88), 0.05),
			Parent = modelo,
		})
	end

	-- Troncos cruzados
	for i = 1, 3 do
		nuevaParte({
			Name = "Lena",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.4, 0.6, 0.6),
			CFrame = CFrame.new(posicion + Vector3.new(0, 0.45, 0))
				* CFrame.Angles(0, i * math.pi / 3, math.rad(12)),
			Material = M.Wood,
			Color = Color3.fromRGB(60, 45, 34),
			CanCollide = false,
			Parent = modelo,
		})
	end

	-- Fuego, chispas y luz
	local centro = nuevaParte({
		Name = "Fuego",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(posicion + Vector3.new(0, 1, 0)),
		Transparency = 1,
		CanCollide = false,
		Parent = modelo,
	})
	local fuego = Instance.new("Fire")
	fuego.Size = 4
	fuego.Heat = 8
	fuego.Color = Color3.fromRGB(255, 140, 50)
	fuego.SecondaryColor = Color3.fromRGB(255, 70, 20)
	fuego.Parent = centro

	local chispas = Instance.new("ParticleEmitter")
	chispas.Name = "Chispas"
	chispas.Rate = 6
	chispas.Lifetime = NumberRange.new(1, 2)
	chispas.Speed = NumberRange.new(3, 6)
	chispas.SpreadAngle = Vector2.new(20, 20)
	chispas.Acceleration = Vector3.new(0, 2, 0)
	chispas.Size = NumberSequence.new(0.12, 0)
	chispas.LightEmission = 1
	chispas.Color = ColorSequence.new(Color3.fromRGB(255, 170, 60))
	chispas.Parent = centro

	local luz = Instance.new("PointLight")
	luz.Color = Color3.fromRGB(255, 150, 70)
	luz.Brightness = 2
	luz.Range = 22
	luz.Shadows = true
	luz.Parent = centro

	modelo.Parent = carpeta
end

local function crearObjetos()
	local anterior = Workspace:FindFirstChild("Mundo")
	if anterior then
		anterior:Destroy()
	end
	local mundo = Instance.new("Folder")
	mundo.Name = "Mundo"
	local carpetaArboles = Instance.new("Folder")
	carpetaArboles.Name = "Arboles"
	carpetaArboles.Parent = mundo
	local carpetaArbustos = Instance.new("Folder")
	carpetaArbustos.Name = "Arbustos"
	carpetaArbustos.Parent = mundo
	local carpetaRocas = Instance.new("Folder")
	carpetaRocas.Name = "Rocas"
	carpetaRocas.Parent = mundo

	local limite = TAMANO / 2 - 40

	-- Árboles y arbustos: solo en hierba, sin pendiente fuerte, lejos del agua y de los caminos
	print("[MUNDO] Plantando árboles...")
	local arboles, arbustos, intentos = 0, 0, 0
	while (arboles < 220 or arbustos < 140) and intentos < 6000 do
		intentos += 1
		local x, z = rng:NextNumber(-limite, limite), rng:NextNumber(-limite, limite)
		local d = muestrear(x, z)
		local pendiente = pendienteEn(x, z)
		local lejosDelInicio = (Vector2.new(x, z) - INICIO).Magnitude > 28
		local apto = d.altura > NIVEL_AGUA + 4
			and d.altura < 150
			and pendiente < 0.55
			and d.camino < 0.2
			and d.meseta < 0.2
			and lejosDelInicio
			and d.manchas < 0.2
		if apto then
			local posicion = Vector3.new(x, d.altura, z)
			if arboles < 220 and rng:NextNumber() < 0.6 then
				crearArbol(posicion, carpetaArboles)
				arboles += 1
			elseif arbustos < 140 then
				crearArbusto(posicion, carpetaArbustos)
				arbustos += 1
			end
		end
		if intentos % 200 == 0 then
			task.wait()
		end
	end

	-- Rocas: más en laderas, algunas sueltas en el llano
	print("[MUNDO] Colocando rocas...")
	local rocas = 0
	intentos = 0
	while rocas < 180 and intentos < 4000 do
		intentos += 1
		local x, z = rng:NextNumber(-limite, limite), rng:NextNumber(-limite, limite)
		local d = muestrear(x, z)
		local pendiente = pendienteEn(x, z)
		local apto = d.altura > NIVEL_AGUA + 1
			and d.camino < 0.2
			and (Vector2.new(x, z) - INICIO).Magnitude > 22
			and (pendiente > 0.4 or rng:NextNumber() < 0.25)
		if apto then
			crearRoca(Vector3.new(x, d.altura, z), d, carpetaRocas)
			rocas += 1
		end
		if intentos % 200 == 0 then
			task.wait()
		end
	end

	-- Fogata en la zona de inicio
	local alturaInicio = muestrear(INICIO.X, INICIO.Y).altura
	crearFogata(Vector3.new(INICIO.X + 10, alturaInicio, INICIO.Y), mundo)

	mundo.Parent = Workspace
	print(string.format("[MUNDO] %d árboles, %d arbustos, %d rocas", arboles, arbustos, rocas))
end

-- ===== PUNTO DE INICIO =====

local function colocarInicio()
	local placa = Workspace:FindFirstChild("Baseplate")
	if placa then
		placa:Destroy()
	end

	local inicio = Workspace:FindFirstChildOfClass("SpawnLocation")
	if not inicio then
		inicio = Instance.new("SpawnLocation")
		inicio.Parent = Workspace
	end
	local altura = muestrear(INICIO.X, INICIO.Y).altura
	inicio.Anchored = true
	inicio.Size = Vector3.new(8, 1, 8)
	inicio.CFrame = CFrame.new(INICIO.X, altura + 0.1, INICIO.Y)
	-- Que parezca una losa de piedra, no un bloque de Roblox
	inicio.Material = M.Slate
	inicio.Color = Color3.fromRGB(100, 96, 90)
	for _, hijo in inicio:GetChildren() do
		if hijo:IsA("Decal") then
			hijo:Destroy()
		end
	end
end

-- ===== ILUMINACIÓN (atardecer dorado con neblina) =====

local function crearIluminacion()
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	Lighting.ClockTime = 16.6
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.6
	Lighting.ExposureCompensation = 0.1
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.Ambient = Color3.fromRGB(70, 62, 55)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 125, 105)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 225, 180)

	for _, hijo in Lighting:GetChildren() do
		if hijo:IsA("Atmosphere") or hijo:IsA("PostEffect") then
			hijo:Destroy()
		end
	end

	local atmosfera = Instance.new("Atmosphere")
	atmosfera.Density = 0.38
	atmosfera.Offset = 0.2
	atmosfera.Color = Color3.fromRGB(205, 180, 145)
	atmosfera.Decay = Color3.fromRGB(120, 95, 70)
	atmosfera.Glare = 0.5
	atmosfera.Haze = 1.6
	atmosfera.Parent = Lighting

	local brillo = Instance.new("BloomEffect")
	brillo.Intensity = 0.55
	brillo.Size = 28
	brillo.Threshold = 1.4
	brillo.Parent = Lighting

	local rayos = Instance.new("SunRaysEffect")
	rayos.Intensity = 0.07
	rayos.Spread = 0.55
	rayos.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Brightness = 0.02
	color.Contrast = 0.12
	color.Saturation = -0.08
	color.TintColor = Color3.fromRGB(255, 244, 228)
	color.Parent = Lighting

	local profundidad = Instance.new("DepthOfFieldEffect")
	profundidad.FarIntensity = 0.15
	profundidad.FocusDistance = 120
	profundidad.InFocusRadius = 120
	profundidad.NearIntensity = 0
	profundidad.Parent = Lighting

	local terreno = Workspace.Terrain
	local nubes = terreno:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	nubes.Cover = 0.55
	nubes.Density = 0.55
	nubes.Color = Color3.fromRGB(255, 240, 220)
	nubes.Parent = terreno
end

-- ===== TODO JUNTO =====

function GenerarMundo.Generar()
	local inicio = os.clock()
	print("[MUNDO] Generando mundo... (puede tardar un minuto, no toques nada)")
	crearTerreno()
	crearObjetos()
	colocarInicio()
	crearIluminacion()
	print(string.format("[MUNDO] ¡Listo en %.0f segundos! Ahora guarda: File > Save to File", os.clock() - inicio))
end

return GenerarMundo

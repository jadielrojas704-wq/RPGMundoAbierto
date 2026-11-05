-- Construye en el mundo los SANTUARIOS de los Guardianes y la GRIETA DEL SELLO del Eclipse.
-- SOLO servidor. Ruta en Studio: ServerScriptService/Historia/RuinasServicio
-- Se construyen al arrancar el servidor (no hace falta regenerar el mundo), en
-- Workspace/Historia. Cada santuario tiene:
--   * plataforma de piedra rota, columnas caídas y la estatua del Guardián
--   * una ESTELA con runas que brillan del color del Guardián (se lee con G)
--   * una TABLILLA pequeña con otro texto
-- Los textos están en ReplicatedStorage/Config/HistoriaConfig.TEXTOS.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HistoriaConfig = require(ReplicatedStorage.Config.HistoriaConfig)

local RuinasServicio = {}

local carpeta = nil
local alLeer = nil -- función(jugador, idTexto) que pone MisionesServicio

local PIEDRA = Color3.fromRGB(128, 124, 116)
local PIEDRA_OSCURA = Color3.fromRGB(70, 68, 66)
local MARMOL = Color3.fromRGB(214, 208, 196)
local aleatorio = Random.new(777)

local function pieza(padre, propiedades)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Slate
	p.Color = PIEDRA
	for k, v in propiedades do
		p[k] = v
	end
	p.Parent = padre
	return p
end

-- Altura del terreno en (x, z); nil si es agua
local function suelo(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local rayo = Workspace:Raycast(Vector3.new(x, 1200, z), Vector3.new(0, -1400, 0), params)
	if not rayo then
		return nil
	end
	if rayo.Material == Enum.Material.Water then
		return nil, rayo.Position.Y
	end
	return rayo.Position.Y
end

-- Busca un sitio seco cerca de (x, z) y devuelve el centro y la altura mínima y máxima
local function buscarSitio(x, z, radio)
	for vuelta = 0, 8 do
		for intento = 0, (if vuelta == 0 then 0 else 7) do
			local angulo = intento * math.pi / 4
			local cx, cz = x + math.cos(angulo) * vuelta * 30, z + math.sin(angulo) * vuelta * 30
			local minimo, maximo, seco = math.huge, -math.huge, true
			for i = 0, 8 do
				local a = i * math.pi / 4
				local r = if i == 8 then 0 else radio
				local h = suelo(cx + math.cos(a) * r, cz + math.sin(a) * r)
				if not h then
					seco = false
					break
				end
				minimo = math.min(minimo, h)
				maximo = math.max(maximo, h)
			end
			if seco and maximo - minimo < 14 then
				return Vector3.new(cx, maximo, cz), minimo, maximo
			end
		end
	end
	local h = suelo(x, z) or 30
	return Vector3.new(x, h, z), h, h
end

-- Quita árboles, rocas y plantas del generador que caigan encima de las ruinas
local CARPETAS_VEGETACION = { "BosqueNormal", "BosqueOscuro", "Desierto", "Montanas" }
local function despejar(centro, radio)
	local mundo = Workspace:FindFirstChild("Mundo")
	if not mundo then
		return
	end
	for _, nombre in CARPETAS_VEGETACION do
		local carpetaVegetacion = mundo:FindFirstChild(nombre)
		if carpetaVegetacion then
			for _, cosa in carpetaVegetacion:GetChildren() do
				local posicion = if cosa:IsA("Model")
					then cosa:GetPivot().Position
					elseif cosa:IsA("BasePart") then cosa.Position
					else nil
				if
					posicion
					and (Vector2.new(posicion.X, posicion.Z) - Vector2.new(centro.X, centro.Z)).Magnitude < radio
				then
					cosa:Destroy()
				end
			end
		end
	end
end

-- Texto que se puede leer con G
local function legible(parte, idTexto, accion)
	local datos = HistoriaConfig.TEXTOS[idTexto]
	parte:SetAttribute("Texto", idTexto)
	local boton = Instance.new("ProximityPrompt")
	boton.Name = "Leer"
	boton.ActionText = accion or "Leer"
	boton.ObjectText = datos and datos.titulo or "Texto antiguo"
	boton.KeyboardKeyCode = Enum.KeyCode.G
	boton.MaxActivationDistance = 11
	boton.RequiresLineOfSight = false
	boton.HoldDuration = 0
	boton.Parent = parte
	boton.Triggered:Connect(function(jugador)
		if alLeer then
			alLeer(jugador, idTexto)
		end
	end)
end

-- Motas de luz que suben
local function motas(parte, color, tasa)
	local emisor = Instance.new("ParticleEmitter")
	emisor.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emisor.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	emisor.LightEmission = 1
	emisor.Size = NumberSequence.new(0.25, 0)
	emisor.Lifetime = NumberRange.new(2, 4)
	emisor.Speed = NumberRange.new(0.6, 1.6)
	emisor.Acceleration = Vector3.new(0, 1, 0)
	emisor.SpreadAngle = Vector2.new(25, 25)
	emisor.Rate = tasa or 6
	emisor.Parent = parte
	return emisor
end

local function luz(parte, color, alcance, brillo)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = alcance or 16
	l.Brightness = brillo or 1.5
	l.Shadows = false
	l.Parent = parte
	return l
end

-- ===== Santuario de un Guardián =====
local function construirSantuario(datos)
	local guardian = HistoriaConfig.GUARDIANES[datos.guardian]
	local color = guardian.color
	local centro, minimo, maximo = buscarSitio(datos.posicion.X, datos.posicion.Y, 18)
	despejar(centro, 30)
	local modelo = Instance.new("Model")
	modelo.Name = datos.nombre
	modelo:SetAttribute("Santuario", datos.id)
	modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- llega entero al jugador
	modelo:SetAttribute("Guardian", guardian.nombre)
	modelo.Parent = carpeta

	local alto = (maximo - minimo) + 3
	local arriba = centro.Y + 0.8
	local base = CFrame.new(centro.X, arriba, centro.Z) * CFrame.Angles(0, aleatorio:NextNumber(0, math.pi * 2), 0)

	-- plataforma con escalón (llega hasta el suelo más bajo)
	pieza(modelo, {
		Name = "Plataforma",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(alto, 34, 34),
		CFrame = base * CFrame.new(0, -alto / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
	})
	pieza(modelo, {
		Name = "Escalon",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(alto - 0.8, 39, 39),
		CFrame = base * CFrame.new(0, -alto / 2 - 0.4, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Material = Enum.Material.Cobblestone,
		Color = PIEDRA_OSCURA,
	})
	-- círculo de runas en el suelo
	local circulo = pieza(modelo, {
		Name = "CirculoRunas",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, 15, 15),
		CFrame = base * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.82,
		CanCollide = false,
	})
	for i = 1, 12 do
		local a = i * math.pi / 6
		pieza(modelo, {
			Name = "Runa",
			Size = Vector3.new(0.5, 0.12, 1.4),
			CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.08, -8.6),
			Material = Enum.Material.Neon,
			Color = color,
			CanCollide = false,
		})
	end
	motas(circulo, color, 5)

	-- columnas (algunas rotas, dos caídas)
	for i = 1, 8 do
		local a = i * math.pi / 4 + math.pi / 8
		local cfColumna = base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -13.5)
		if i == 3 or i == 6 then
			-- columna caída en el suelo
			pieza(modelo, {
				Name = "ColumnaCaida",
				Size = Vector3.new(2.4, 2.4, 11),
				CFrame = cfColumna
					* CFrame.new(3, 1.2, -2)
					* CFrame.Angles(0, math.rad(aleatorio:NextNumber(20, 70)), math.rad(aleatorio:NextNumber(-8, 8))),
			})
			pieza(
				modelo,
				{ Name = "Base", Size = Vector3.new(3.2, 1.2, 3.2), CFrame = cfColumna * CFrame.new(0, 0.6, 0) }
			)
		else
			local h = if i % 2 == 0 then aleatorio:NextNumber(10, 14) else aleatorio:NextNumber(4, 8)
			pieza(
				modelo,
				{ Name = "Base", Size = Vector3.new(3.2, 1.2, 3.2), CFrame = cfColumna * CFrame.new(0, 0.6, 0) }
			)
			pieza(modelo, {
				Name = "Columna",
				Size = Vector3.new(2.4, h, 2.4),
				CFrame = cfColumna
					* CFrame.new(0, 1.2 + h / 2, 0)
					* CFrame.Angles(0, math.rad(45), math.rad(aleatorio:NextNumber(-3, 3))),
				Color = PIEDRA:Lerp(Color3.fromRGB(90, 110, 80), aleatorio:NextNumber(0, 0.35)),
			})
			if h > 10 then
				pieza(modelo, {
					Name = "Capitel",
					Size = Vector3.new(3.4, 1, 3.4),
					CFrame = cfColumna * CFrame.new(0, 1.2 + h + 0.5, 0),
				})
			end
		end
	end

	-- estatua del Guardián (rota) detrás de la estela
	local cfEstatua = base * CFrame.new(0, 0, 8)
	pieza(modelo, {
		Name = "Pedestal",
		Size = Vector3.new(5, 3, 5),
		CFrame = cfEstatua * CFrame.new(0, 1.5, 0),
		Material = Enum.Material.Marble,
		Color = MARMOL,
	})
	pieza(modelo, {
		Name = "Tunica",
		Size = Vector3.new(3.4, 7, 2.2),
		CFrame = cfEstatua * CFrame.new(0, 6.5, 0),
		Material = Enum.Material.Marble,
		Color = MARMOL,
	})
	pieza(modelo, {
		Name = "Hombros",
		Size = Vector3.new(4.6, 1.4, 2.4),
		CFrame = cfEstatua * CFrame.new(0, 10.4, 0),
		Material = Enum.Material.Marble,
		Color = MARMOL,
	})
	pieza(modelo, {
		Name = "Brazo",
		Size = Vector3.new(1.2, 5, 1.2),
		CFrame = cfEstatua * CFrame.new(-2.6, 9.6, -1) * CFrame.Angles(math.rad(35), 0, math.rad(-10)),
		Material = Enum.Material.Marble,
		Color = MARMOL,
	})
	pieza(modelo, {
		Name = "CabezaCaida",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2.2,
		CFrame = cfEstatua * CFrame.new(3.6, 1.1, -3.4),
		Material = Enum.Material.Marble,
		Color = MARMOL,
	})
	local orbe = pieza(modelo, {
		Name = "Orbe",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.4,
		CFrame = cfEstatua * CFrame.new(-3.4, 12.6, -2.4),
		Material = Enum.Material.Neon,
		Color = color,
		CanCollide = false,
	})
	luz(orbe, color, 14, 1.2)

	-- estela con runas
	local cfEstela = base * CFrame.new(0, 0, 2)
	local estela = pieza(modelo, {
		Name = "Estela",
		Size = Vector3.new(5, 9, 1.4),
		CFrame = cfEstela * CFrame.new(0, 4.5, 0),
		Material = Enum.Material.Basalt,
		Color = Color3.fromRGB(46, 46, 52),
	})
	for linea = 1, 5 do
		local ancho = aleatorio:NextNumber(2.4, 3.8)
		pieza(modelo, {
			Name = "RunaEstela",
			Size = Vector3.new(ancho, 0.22, 0.1),
			CFrame = cfEstela * CFrame.new(0, 2.2 + linea * 1.1, -0.72),
			Material = Enum.Material.Neon,
			Color = color,
			CanCollide = false,
		})
	end
	local gema = pieza(modelo, {
		Name = "Gema",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1,
		CFrame = cfEstela * CFrame.new(0, 9.4, 0),
		Material = Enum.Material.Neon,
		Color = color,
		CanCollide = false,
	})
	luz(gema, color, 20, 2)
	motas(gema, color, 4)
	legible(estela, datos.estela, "Leer inscripción")

	-- tablilla apoyada en una columna
	local cfTablilla = base * CFrame.Angles(0, math.rad(200), 0) * CFrame.new(0, 0, -10)
	local tablilla = pieza(modelo, {
		Name = "Tablilla",
		Size = Vector3.new(2.6, 3.2, 0.5),
		CFrame = cfTablilla * CFrame.new(0, 1.5, 0) * CFrame.Angles(math.rad(-18), 0, 0),
		Material = Enum.Material.Limestone,
		Color = Color3.fromRGB(176, 164, 140),
	})
	pieza(modelo, {
		Name = "RunaTablilla",
		Size = Vector3.new(1.8, 0.14, 0.06),
		CFrame = tablilla.CFrame * CFrame.new(0, 0.4, -0.28),
		Material = Enum.Material.Neon,
		Color = color,
		CanCollide = false,
	})
	legible(tablilla, datos.tablilla, "Leer")

	modelo.PrimaryPart = estela
	modelo:SetAttribute("Centro", centro)
	return modelo
end

-- ===== Grieta del sello del Eclipse (junto al Altar del Ascenso) =====
local function construirSello()
	local datos = HistoriaConfig.SELLO
	local color = HistoriaConfig.COLOR_ECLIPSE
	local centro, minimo, maximo = buscarSitio(datos.posicion.X, datos.posicion.Y, 11)
	despejar(centro, 22)
	local modelo = Instance.new("Model")
	modelo.Name = "Grieta del Sello"
	modelo:SetAttribute("Sello", true)
	modelo.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- el haz morado se ve desde todo el mapa
	modelo.Parent = carpeta
	local alto = (maximo - minimo) + 2
	local base = CFrame.new(centro.X, centro.Y + 0.6, centro.Z)

	-- disco del sello partido en cuatro trozos levantados
	pieza(modelo, {
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(alto, 24, 24),
		CFrame = base * CFrame.new(0, -alto / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = PIEDRA_OSCURA,
		Material = Enum.Material.Basalt,
	})
	for i = 1, 4 do
		local a = i * math.pi / 2 + 0.3
		pieza(modelo, {
			Name = "Trozo",
			Size = Vector3.new(9, 1.2, 9),
			CFrame = base
				* CFrame.Angles(0, a, 0)
				* CFrame.new(5.2, 0.6 + i * 0.25, 5.2)
				* CFrame.Angles(math.rad(aleatorio:NextNumber(-12, 12)), 0, math.rad(aleatorio:NextNumber(-12, 12))),
			Material = Enum.Material.Basalt,
			Color = Color3.fromRGB(40, 36, 48),
		})
	end
	-- grietas de luz morada entre los trozos
	for i = 1, 4 do
		local a = i * math.pi / 2 + 0.3 + math.pi / 4
		for tramo = 0, 2 do
			pieza(modelo, {
				Name = "Grieta",
				Size = Vector3.new(0.35, 0.2, 3.6),
				CFrame = base
					* CFrame.Angles(0, a + math.rad(aleatorio:NextNumber(-18, 18)), 0)
					* CFrame.new(0, 0.3, -2 - tramo * 3.4),
				Material = Enum.Material.Neon,
				Color = color,
				CanCollide = false,
			})
		end
	end
	-- haz de luz que sube del centro
	local haz = pieza(modelo, {
		Name = "Haz",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(60, 1.6, 1.6),
		CFrame = base * CFrame.new(0, 30, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.55,
		CanCollide = false,
	})
	luz(haz, color, 40, 3)
	local nucleo = pieza(modelo, {
		Name = "Nucleo",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 3,
		CFrame = base * CFrame.new(0, 1.5, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(30, 0, 50),
		CanCollide = false,
	})
	local humo = motas(nucleo, color, 14)
	humo.Speed = NumberRange.new(3, 6)
	humo.Size = NumberSequence.new(0.5, 0)
	-- estela con el texto
	local estela = pieza(modelo, {
		Name = "Estela",
		Size = Vector3.new(4.4, 7, 1.2),
		CFrame = base * CFrame.new(0, 3.5, 13),
		Material = Enum.Material.Basalt,
		Color = Color3.fromRGB(36, 34, 40),
	})
	for linea = 1, 4 do
		pieza(modelo, {
			Name = "RunaEstela",
			Size = Vector3.new(aleatorio:NextNumber(2, 3.4), 0.2, 0.1),
			CFrame = estela.CFrame * CFrame.new(0, -2.6 + linea * 1.2, -0.62),
			Material = Enum.Material.Neon,
			Color = color,
			CanCollide = false,
		})
	end
	legible(estela, datos.texto, "Examinar la grieta")
	modelo.PrimaryPart = estela
	modelo:SetAttribute("Centro", centro)
	return modelo
end

-- Posición de la pieza que tiene un texto (para guiar al jugador)
function RuinasServicio.PosicionTexto(idTexto)
	if not carpeta then
		return nil
	end
	for _, parte in carpeta:GetDescendants() do
		if parte:IsA("BasePart") and parte:GetAttribute("Texto") == idTexto then
			return parte.Position
		end
	end
	return nil
end

function RuinasServicio.Iniciar(funcionLeer)
	alLeer = funcionLeer
	carpeta = Workspace:FindFirstChild("Historia")
	if carpeta then
		carpeta:Destroy()
	end
	carpeta = Instance.new("Folder")
	carpeta.Name = "Historia"
	carpeta.Parent = Workspace
	for _, datos in HistoriaConfig.SANTUARIOS do
		local ok, err = pcall(construirSantuario, datos)
		if not ok then
			warn("[HISTORIA] No pude construir", datos.nombre, err)
		end
	end
	local ok, err = pcall(construirSello)
	if not ok then
		warn("[HISTORIA] No pude construir la grieta del sello", err)
	end
	print("[HISTORIA] Santuarios de los Guardianes y grieta del sello listos")
end

return RuinasServicio

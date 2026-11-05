-- Construye en el mundo los SANTUARIOS de los Guardianes y la GRIETA DEL SELLO del Eclipse.
-- SOLO servidor. Ruta en Studio: ServerScriptService/Historia/RuinasServicio
-- Se construyen al arrancar el servidor (no hace falta regenerar el mundo), en
-- Workspace/Historia. Cada santuario tiene su propia arquitectura:
--   * Sylvaris (Vida): arboleda sagrada con arcos de musgo, estanque y flores
--   * Ignar (Fuego): templo escalonado de arenisca, obeliscos, braseros y grietas de lava
--   * Morvak (Muerte): cementerio gótico con lápidas, velas moradas y niebla
--   * Lunaria (Luz): templo redondo de mármol, cristales y un haz de luz del cielo
-- y todos: la ESTATUA del Guardián (cuerpo humano real en piedra, con su pose y su objeto),
-- una ESTELA con runas (se lee con G) y una TABLILLA con otro texto.
-- Los textos están en ReplicatedStorage/Config/HistoriaConfig.TEXTOS.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HistoriaConfig = require(ReplicatedStorage.Config.HistoriaConfig)
local Escultor = require(script.Parent.Escultor)

local RuinasServicio = {}

local carpeta = nil
local alLeer = nil -- función(jugador, idTexto) que pone MisionesServicio

local PIEDRA = Color3.fromRGB(128, 124, 116)
local PIEDRA_OSCURA = Color3.fromRGB(70, 68, 66)
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

-- ===== RUNAS: glifos de verdad hechos con trazos de luz (como las runas antiguas) =====
-- Cada runa es una lista de trazos entre puntos (x de -0.3 a 0.3, y de -0.5 a 0.5).
local GLIFOS = {
	{ { 0, -0.5, 0, 0.5 }, { 0, 0.5, 0.3, 0.25 }, { 0, 0.2, 0.3, -0.05 } }, -- fehu
	{ { -0.2, -0.5, -0.2, 0.5 }, { -0.2, 0.5, 0.24, 0.2 }, { 0.24, 0.2, 0.24, -0.5 } }, -- uruz
	{ { 0, -0.5, 0, 0.5 }, { 0, 0.25, 0.26, 0 }, { 0.26, 0, 0, -0.25 } }, -- thurisaz
	{ { 0, -0.5, 0, 0.5 }, { 0, 0.5, 0.26, 0.3 }, { 0.26, 0.3, 0, 0.1 }, { 0, 0.1, 0.28, -0.5 } }, -- raido
	{ { 0.22, 0.5, -0.16, 0.05 }, { -0.16, 0.05, 0.22, -0.4 } }, -- kenaz
	{ { -0.26, 0.42, 0.26, -0.42 }, { 0.26, 0.42, -0.26, -0.42 } }, -- gebo
	{ { 0, -0.5, 0, 0.5 }, { -0.22, 0.16, 0.22, -0.16 } }, -- naudiz
	{ { 0, -0.5, 0, 0.5 }, { 0, 0.5, -0.26, 0.2 }, { 0, 0.5, 0.26, 0.2 } }, -- tiwaz
	{ { 0, -0.5, 0, 0.5 }, { 0, 0.05, -0.26, 0.42 }, { 0, 0.05, 0.26, 0.42 } }, -- algiz
	{ { -0.2, 0.5, 0.2, 0.15 }, { 0.2, 0.15, -0.2, -0.15 }, { -0.2, -0.15, 0.2, -0.5 } }, -- sowilo
	{ { 0, 0.5, 0.25, 0.15 }, { 0.25, 0.15, 0, -0.2 }, { 0, -0.2, -0.25, 0.15 }, { -0.25, 0.15, 0, 0.5 }, { 0, -0.2, -0.26, -0.5 }, { 0, -0.2, 0.26, -0.5 } }, -- othala
	{ { -0.22, -0.5, -0.22, 0.5 }, { 0.22, -0.5, 0.22, 0.5 }, { -0.22, 0.3, 0.22, -0.3 } }, -- hagalaz
	{ { 0, 0.5, 0.24, 0 }, { 0.24, 0, 0, -0.5 }, { 0, -0.5, -0.24, 0 }, { -0.24, 0, 0, 0.5 } }, -- ingwaz
	{ { 0, -0.5, 0, 0.5 } }, -- isa
}

-- Una runa de alto "tam" en cf (cf mirando hacia fuera de la piedra: -Z = hacia el que la lee)
local function runa(modelo, cf, tam, color, indice, nombre)
	local glifo = GLIFOS[indice or aleatorio:NextInteger(1, #GLIFOS)]
	local grosor = math.max(tam * 0.09, 0.06)
	for _, t in glifo do
		local a = Vector3.new(t[1] * tam, t[2] * tam, 0)
		local b = Vector3.new(t[3] * tam, t[4] * tam, 0)
		local largo = (b - a).Magnitude
		local centro = (a + b) / 2
		local angulo = math.atan2(b.Y - a.Y, b.X - a.X)
		pieza(modelo, {
			Name = nombre or "Runa",
			Size = Vector3.new(largo + grosor * 0.8, grosor, 0.05),
			CFrame = cf * CFrame.new(centro) * CFrame.Angles(0, 0, angulo),
			Material = Enum.Material.Neon,
			Color = color,
			CanCollide = false,
			CastShadow = false,
		})
	end
end

-- Una línea de runas de "ancho" studs (cf = centro de la línea)
local function lineaRunas(modelo, cf, ancho, tam, color, nombre)
	local cuantas = math.max(1, math.floor(ancho / (tam * 0.78)))
	local paso = ancho / cuantas
	for k = 1, cuantas do
		runa(modelo, cf * CFrame.new(-ancho / 2 + (k - 0.5) * paso, 0, 0), tam, color, nil, nombre)
	end
end

-- Una columna de runas de "alto" studs (cf = centro de la columna)
local function columnaRunas(modelo, cf, alto, tam, color, nombre)
	local cuantas = math.max(1, math.floor(alto / (tam * 1.25)))
	local paso = alto / cuantas
	for k = 1, cuantas do
		runa(modelo, cf * CFrame.new(0, alto / 2 - (k - 0.5) * paso, 0), tam, color, nil, nombre)
	end
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

-- ===== Santuarios de los Guardianes =====
-- Cada uno con arquitectura propia y la estatua de su Guardián (cuerpo humano real
-- convertido en piedra por ServerScriptService/Historia/Escultor).

local function g(x, y, z)
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

-- Rocas sueltas y escombros alrededor (dan realismo)
local function escombros(modelo, base, radio, cantidad, color, material)
	for _ = 1, cantidad do
		local a = aleatorio:NextNumber(0, math.pi * 2)
		local r = aleatorio:NextNumber(radio * 0.6, radio)
		local t = aleatorio:NextNumber(0.6, 2.2)
		pieza(modelo, {
			Name = "Escombro",
			Size = Vector3.new(t * aleatorio:NextNumber(0.8, 1.6), t * 0.7, t),
			CFrame = base
				* CFrame.new(math.cos(a) * r, t * 0.25, math.sin(a) * r)
				* g(aleatorio:NextNumber(-25, 25), aleatorio:NextNumber(0, 360), aleatorio:NextNumber(-25, 25)),
			Material = material or Enum.Material.Rock,
			Color = (color or PIEDRA):Lerp(Color3.new(0, 0, 0), aleatorio:NextNumber(0, 0.2)),
		})
	end
end

-- Musgo encima de una pieza
local function musgo(modelo, parte, cantidad)
	for _ = 1, cantidad or 2 do
		local x = aleatorio:NextNumber(-0.4, 0.4) * parte.Size.X
		local z = aleatorio:NextNumber(-0.4, 0.4) * parte.Size.Z
		pieza(modelo, {
			Name = "Musgo",
			Size = Vector3.new(aleatorio:NextNumber(1, 2.4), 0.12, aleatorio:NextNumber(1, 2.4)),
			CFrame = parte.CFrame * CFrame.new(x, parte.Size.Y / 2 + 0.04, z) * g(0, aleatorio:NextNumber(0, 360), 0),
			Material = Enum.Material.Grass,
			Color = Color3.fromRGB(78, 104, 56),
			CanCollide = false,
		})
	end
end

-- Columna de varios tambores (más realista que un bloque): base, fuste, capitel
local function columna(modelo, cf, alto, grosor, material, color, rota)
	pieza(
		modelo,
		{
			Name = "BaseColumna",
			Size = Vector3.new(grosor * 1.4, 0.8, grosor * 1.4),
			CFrame = cf * CFrame.new(0, 0.4, 0),
			Material = material,
			Color = color,
		}
	)
	local tambores = math.max(1, math.floor(alto / 3))
	local altoTambor = alto / tambores
	local ultimo = tambores
	if rota then
		ultimo = math.max(1, tambores - aleatorio:NextInteger(1, math.max(1, tambores - 1)))
	end
	for i = 1, ultimo do
		pieza(modelo, {
			Name = "Fuste",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(altoTambor - 0.05, grosor, grosor),
			CFrame = cf
				* CFrame.new(aleatorio:NextNumber(-0.05, 0.05), 0.8 + (i - 0.5) * altoTambor, 0)
				* g(0, aleatorio:NextNumber(0, 360), 90),
			Material = material,
			Color = color:Lerp(Color3.new(0, 0, 0), aleatorio:NextNumber(0, 0.12)),
		})
	end
	if ultimo == tambores then
		pieza(
			modelo,
			{
				Name = "Capitel",
				Size = Vector3.new(grosor * 1.5, 0.9, grosor * 1.5),
				CFrame = cf * CFrame.new(0, 0.8 + alto + 0.45, 0),
				Material = material,
				Color = color,
			}
		)
	else
		-- el trozo que se cayó, en el suelo
		pieza(modelo, {
			Name = "TamborCaido",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(altoTambor, grosor, grosor),
			CFrame = cf
				* CFrame.new(aleatorio:NextNumber(2, 4), grosor / 2, aleatorio:NextNumber(-2, 2))
				* g(0, aleatorio:NextNumber(0, 360), 0),
			Material = material,
			Color = color,
		})
	end
end

local function brasero(modelo, cf, color)
	pieza(
		modelo,
		{
			Name = "PieBrasero",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.2, 0.9, 0.9),
			CFrame = cf * CFrame.new(0, 1.6, 0) * g(0, 0, 90),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(60, 50, 42),
		}
	)
	local cuenco = pieza(
		modelo,
		{
			Name = "Brasero",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.9, 2.6, 2.6),
			CFrame = cf * CFrame.new(0, 3.5, 0) * g(0, 0, 90),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(70, 56, 44),
		}
	)
	local brasas = pieza(
		modelo,
		{
			Name = "Brasas",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 2.1, 2.1),
			CFrame = cf * CFrame.new(0, 3.95, 0) * g(0, 0, 90),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 120, 40),
			CanCollide = false,
		}
	)
	local fuego = Instance.new("Fire")
	fuego.Size = 6
	fuego.Heat = 9
	fuego.Color = color or Color3.fromRGB(255, 140, 50)
	fuego.SecondaryColor = Color3.fromRGB(255, 60, 20)
	fuego.Parent = brasas
	luz(brasas, Color3.fromRGB(255, 150, 70), 22, 2)
	return cuenco
end

local function estela(modelo, cf, color, idTexto, material, piedraColor)
	local e = pieza(
		modelo,
		{
			Name = "Estela",
			Size = Vector3.new(5, 8.5, 1.3),
			CFrame = cf * CFrame.new(0, 4.25, 0),
			Material = material or Enum.Material.Basalt,
			Color = piedraColor or Color3.fromRGB(46, 46, 52),
		}
	)
	pieza(
		modelo,
		{
			Name = "Remate",
			Size = Vector3.new(5.6, 0.8, 1.7),
			CFrame = cf * CFrame.new(0, 8.9, 0),
			Material = material or Enum.Material.Basalt,
			Color = piedraColor or Color3.fromRGB(46, 46, 52),
		}
	)
	for linea = 1, 5 do
		lineaRunas(modelo, cf * CFrame.new(0, 2 + linea * 1.1, -0.68), aleatorio:NextNumber(2.6, 3.6), 0.78, color, "RunaEstela")
	end
	local gema = pieza(
		modelo,
		{
			Name = "Gema",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one,
			CFrame = cf * CFrame.new(0, 9.8, 0),
			Material = Enum.Material.Neon,
			Color = color,
			CanCollide = false,
		}
	)
	luz(gema, color, 18, 1.6)
	motas(gema, color, 3)
	legible(e, idTexto, "Leer inscripción")
	return e
end

local function tablilla(modelo, cf, color, idTexto)
	local t = pieza(
		modelo,
		{
			Name = "Tablilla",
			Size = Vector3.new(2.6, 3.2, 0.5),
			CFrame = cf * CFrame.new(0, 1.5, 0) * g(-18, 0, 0),
			Material = Enum.Material.Limestone,
			Color = Color3.fromRGB(176, 164, 140),
		}
	)
	lineaRunas(modelo, t.CFrame * CFrame.new(0, 0.6, -0.28), 1.9, 0.5, color, "RunaTablilla")
	lineaRunas(modelo, t.CFrame * CFrame.new(0, -0.1, -0.28), 1.5, 0.5, color, "RunaTablilla")
	legible(t, idTexto, "Leer")
	return t
end

-- Plataforma que llega hasta el suelo más bajo (para que no flote en pendientes)
local function plataforma(modelo, base, alto, ancho, forma, material, color)
	if forma == "Cuadrada" then
		return pieza(
			modelo,
			{
				Name = "Plataforma",
				Size = Vector3.new(ancho, alto, ancho),
				CFrame = base * CFrame.new(0, -alto / 2, 0),
				Material = material,
				Color = color,
			}
		)
	end
	return pieza(
		modelo,
		{
			Name = "Plataforma",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(alto, ancho, ancho),
			CFrame = base * CFrame.new(0, -alto / 2, 0) * g(0, 0, 90),
			Material = material,
			Color = color,
		}
	)
end

-- ===== Poses de las estatuas (mismo convenio que las animaciones de combate) =====
local POSES = {
	-- Ignar: guerrero con la espada de fuego en alto
	Ignar = {
		RightShoulder = g(165, 0, 8),
		RightElbow = g(12),
		LeftShoulder = g(35, 0, -25),
		LeftElbow = g(75),
		Waist = g(-4, 12, 0),
		Neck = g(12, -10, 0),
		LeftHip = g(22, 0, -6),
		LeftKnee = g(-22),
		RightHip = g(-12, 0, 6),
	},
	-- Lunaria: alza un orbe de luz hacia el cielo con las dos manos
	Lunaria = {
		RightShoulder = g(155, 0, 18),
		LeftShoulder = g(155, 0, -18),
		RightElbow = g(28),
		LeftElbow = g(28),
		Neck = g(24, 0, 0),
		Waist = g(6, 0, 0),
	},
	-- Morvak: encapuchado, cabeza baja, apoyado en su guadaña
	Morvak = {
		RightShoulder = g(42, 0, 12),
		RightElbow = g(72),
		LeftShoulder = g(8, 0, -6),
		LeftElbow = g(10),
		Neck = g(-18, 0, 0),
		Waist = g(-6, -8, 0),
	},
	-- Sylvaris: brazos abiertos, acogiendo la vida
	Sylvaris = {
		RightShoulder = g(30, 0, 62),
		LeftShoulder = g(30, 0, -62),
		RightElbow = g(18),
		LeftElbow = g(18),
		Neck = g(10, 0, 0),
		LeftHip = g(8, 0, -3),
	},
}

local ESTATUAS = {
	Ignar = {
		apariencia = { Genero = "Hombre", Cara = 8, Pelo = 4, Barba = 1, Ropa = "CaballeroOro" },
		material = Enum.Material.Sandstone,
		color = Color3.fromRGB(214, 176, 128),
	},
	Lunaria = {
		apariencia = { Genero = "Mujer", Cara = 17, Pelo = 18, Ropa = "Reina" },
		material = Enum.Material.Marble,
		color = Color3.fromRGB(242, 240, 234),
	},
	Morvak = {
		apariencia = { Genero = "Hombre", Cara = 13, Pelo = 0, Barba = 0, Ropa = "Encapuchado" },
		material = Enum.Material.Basalt,
		color = Color3.fromRGB(66, 62, 74),
	},
	Sylvaris = {
		apariencia = { Genero = "Mujer", Cara = 16, Pelo = 22, Ropa = "Dama" },
		material = Enum.Material.Marble,
		color = Color3.fromRGB(196, 210, 188),
	},
}

-- Estatua del Guardián sobre un pedestal
local function estatuaGuardian(modelo, id, cf, colorGuardian)
	local datos = ESTATUAS[id]
	local material, color = datos.material, datos.color
	pieza(
		modelo,
		{
			Name = "Pedestal",
			Size = Vector3.new(8, 3.6, 8),
			CFrame = cf * CFrame.new(0, 1.8, 0),
			Material = material,
			Color = color:Lerp(Color3.new(0, 0, 0), 0.15),
		}
	)
	pieza(
		modelo,
		{
			Name = "Moldura",
			Size = Vector3.new(9, 0.8, 9),
			CFrame = cf * CFrame.new(0, 0.4, 0),
			Material = material,
			Color = color:Lerp(Color3.new(0, 0, 0), 0.25),
		}
	)
	pieza(
		modelo,
		{
			Name = "Inscripcion",
			Size = Vector3.new(4.5, 0.4, 0.08),
			CFrame = cf * CFrame.new(0, 2.2, -4.02),
			Material = Enum.Material.Neon,
			Color = colorGuardian,
			CanCollide = false,
		}
	)
	local estatua, enMano = Escultor.Estatua({
		nombre = "Estatua de " .. id,
		apariencia = datos.apariencia,
		pose = POSES[id],
		escala = 2.5,
		material = material,
		color = color,
	}, modelo, cf * CFrame.new(0, 3.6, 0))
	return estatua, enMano
end

-- ---------- Sylvaris (Vida): arboleda sagrada con estanque ----------
local function santuarioSylvaris(modelo, base, alto, datos, color)
	local piedra = Color3.fromRGB(150, 150, 136)
	plataforma(modelo, base, alto, 40, "Redonda", Enum.Material.Cobblestone, Color3.fromRGB(110, 112, 96))
	pieza(
		modelo,
		{
			Name = "Suelo",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 34, 34),
			CFrame = base * CFrame.new(0, 0.15, 0) * g(0, 0, 90),
			Material = Enum.Material.Grass,
			Color = Color3.fromRGB(86, 120, 60),
		}
	)
	-- estanque con agua clara
	pieza(
		modelo,
		{
			Name = "BordeEstanque",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 13, 13),
			CFrame = base * CFrame.new(0, 0.5, -3) * g(0, 0, 90),
			Material = Enum.Material.Limestone,
			Color = piedra,
		}
	)
	local agua = pieza(
		modelo,
		{
			Name = "Agua",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 11.5, 11.5),
			CFrame = base * CFrame.new(0, 0.95, -3) * g(0, 0, 90),
			Material = Enum.Material.Glass,
			Color = Color3.fromRGB(90, 170, 160),
			Transparency = 0.35,
			Reflectance = 0.25,
			CanCollide = false,
		}
	)
	motas(agua, color, 4)
	-- círculo de arcos cubiertos de musgo
	for i = 1, 6 do
		local a = i * math.pi / 3
		local cf = base * g(0, math.deg(a), 0) * CFrame.new(0, 0, -15)
		columna(modelo, cf * CFrame.new(-2.6, 0, 0), 9, 1.6, Enum.Material.Limestone, piedra, i == 4)
		columna(modelo, cf * CFrame.new(2.6, 0, 0), 9, 1.6, Enum.Material.Limestone, piedra, false)
		if i ~= 4 then
			local dintel = pieza(
				modelo,
				{
					Name = "Dintel",
					Size = Vector3.new(7.4, 1.2, 2),
					CFrame = cf * CFrame.new(0, 10.8, 0),
					Material = Enum.Material.Limestone,
					Color = piedra,
				}
			)
			musgo(modelo, dintel, 2)
			-- enredaderas colgando
			for _ = 1, 3 do
				pieza(
					modelo,
					{
						Name = "Enredadera",
						Size = Vector3.new(0.2, aleatorio:NextNumber(2, 5), 0.2),
						CFrame = dintel.CFrame * CFrame.new(aleatorio:NextNumber(-3, 3), -2, -1.05),
						Material = Enum.Material.Grass,
						Color = Color3.fromRGB(70, 110, 50),
						CanCollide = false,
					}
				)
			end
		end
	end
	-- flores de colores
	for _ = 1, 26 do
		local a, r = aleatorio:NextNumber(0, math.pi * 2), aleatorio:NextNumber(7, 16)
		pieza(
			modelo,
			{
				Name = "Flor",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * aleatorio:NextNumber(0.4, 0.7),
				CFrame = base * CFrame.new(math.cos(a) * r, 0.5, math.sin(a) * r),
				Material = Enum.Material.SmoothPlastic,
				Color = ({
					Color3.fromRGB(255, 190, 220),
					Color3.fromRGB(255, 240, 150),
					Color3.fromRGB(200, 170, 255),
					Color3.new(1, 1, 1),
				})[aleatorio:NextInteger(1, 4)],
				CanCollide = false,
			}
		)
	end
	local _, enMano = estatuaGuardian(modelo, "Sylvaris", base * CFrame.new(0, 0, 9), color)
	-- brotes de luz en sus manos
	for _, mano in { "LeftHand", "RightHand" } do
		enMano(mano, function(cf)
			local brote = pieza(
				modelo,
				{
					Name = "Brote",
					Shape = Enum.PartType.Ball,
					Size = Vector3.one * 1.3,
					CFrame = cf * CFrame.new(0, -1, 0),
					Material = Enum.Material.Neon,
					Color = color,
					CanCollide = false,
				}
			)
			luz(brote, color, 12, 1.2)
			motas(brote, color, 4)
		end)
	end
	estela(
		modelo,
		base * CFrame.new(0, 0, 3) * g(0, 180, 0),
		color,
		datos.estela,
		Enum.Material.Limestone,
		Color3.fromRGB(120, 124, 110)
	)
	tablilla(modelo, base * g(0, 210, 0) * CFrame.new(0, 0, -11), color, datos.tablilla)
	escombros(modelo, base, 22, 10, piedra)
end

-- ---------- Ignar (Fuego): templo escalonado de arenisca con braseros ----------
local function santuarioIgnar(modelo, base, alto, datos, color)
	local arena = Color3.fromRGB(206, 160, 110)
	plataforma(modelo, base, alto, 40, "Cuadrada", Enum.Material.Sandstone, arena:Lerp(Color3.new(0, 0, 0), 0.15))
	pieza(
		modelo,
		{
			Name = "Grada1",
			Size = Vector3.new(32, 1.4, 32),
			CFrame = base * CFrame.new(0, 0.7, 0),
			Material = Enum.Material.Sandstone,
			Color = arena,
		}
	)
	pieza(
		modelo,
		{
			Name = "Grada2",
			Size = Vector3.new(22, 1.4, 22),
			CFrame = base * CFrame.new(0, 2.1, 0),
			Material = Enum.Material.Sandstone,
			Color = arena:Lerp(Color3.new(1, 1, 1), 0.05),
		}
	)
	local arriba = base * CFrame.new(0, 2.8, 0)
	-- grietas de lava en el suelo
	for i = 1, 8 do
		pieza(
			modelo,
			{
				Name = "Lava",
				Size = Vector3.new(0.35, 0.1, aleatorio:NextNumber(4, 9)),
				CFrame = base * g(0, i * 45 + aleatorio:NextNumber(-15, 15), 0) * CFrame.new(0, 1.42, -10),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(255, 110, 30),
				CanCollide = false,
			}
		)
	end
	-- obeliscos en las esquinas y braseros
	for i = 1, 4 do
		local cf = base * g(0, i * 90 + 45, 0) * CFrame.new(0, 1.4, -19)
		local ob = pieza(
			modelo,
			{
				Name = "Obelisco",
				Size = Vector3.new(2.6, 14, 2.6),
				CFrame = cf * CFrame.new(0, 7, 0) * g(0, 0, aleatorio:NextNumber(-3, 3)),
				Material = Enum.Material.Sandstone,
				Color = arena:Lerp(Color3.new(0, 0, 0), 0.1),
			}
		)
		pieza(
			modelo,
			{
				Name = "Punta",
				Size = Vector3.new(1.8, 2, 1.8),
				CFrame = ob.CFrame * CFrame.new(0, 8, 0) * g(0, 45, 0),
				Material = Enum.Material.Metal,
				Color = Color3.fromRGB(200, 150, 70),
			}
		)
		columnaRunas(modelo, ob.CFrame * CFrame.new(0, 0, -1.33), 9, 0.85, color, "RunaObelisco")
		brasero(modelo, base * g(0, i * 90, 0) * CFrame.new(0, 2.8, -9))
	end
	local _, enMano = estatuaGuardian(modelo, "Ignar", arriba * CFrame.new(0, 0, 5), color)
	-- espada de fuego en alto
	enMano("RightHand", function(cf, escala)
		local hoja = pieza(
			modelo,
			{
				Name = "EspadaIgnar",
				Size = Vector3.new(0.35 * escala, 4.2 * escala, 0.12 * escala),
				CFrame = cf * CFrame.new(0, -2.4 * escala, 0),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(255, 140, 50),
				CanCollide = false,
			}
		)
		local fuego = Instance.new("Fire")
		fuego.Size = 5
		fuego.Heat = 12
		fuego.Color = Color3.fromRGB(255, 160, 60)
		fuego.SecondaryColor = Color3.fromRGB(255, 70, 20)
		fuego.Parent = hoja
		luz(hoja, Color3.fromRGB(255, 140, 60), 26, 2.5)
		pieza(
			modelo,
			{
				Name = "Guarda",
				Size = Vector3.new(1.4 * escala, 0.2 * escala, 0.3 * escala),
				CFrame = cf * CFrame.new(0, -0.3 * escala, 0),
				Material = Enum.Material.Metal,
				Color = Color3.fromRGB(140, 110, 60),
				CanCollide = false,
			}
		)
	end)
	estela(
		modelo,
		arriba * CFrame.new(0, 0, -3) * g(0, 180, 0),
		color,
		datos.estela,
		Enum.Material.Sandstone,
		Color3.fromRGB(150, 110, 76)
	)
	tablilla(modelo, base * g(0, 30, 0) * CFrame.new(0, 1.4, -13), color, datos.tablilla)
	escombros(modelo, base, 24, 12, arena, Enum.Material.Sandstone)
end

-- ---------- Morvak (Muerte): cementerio gótico con niebla y velas ----------
local function santuarioMorvak(modelo, base, alto, datos, color)
	local piedra = Color3.fromRGB(62, 60, 68)
	plataforma(modelo, base, alto, 40, "Redonda", Enum.Material.Basalt, Color3.fromRGB(44, 42, 48))
	pieza(
		modelo,
		{
			Name = "Losas",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 34, 34),
			CFrame = base * CFrame.new(0, 0.15, 0) * g(0, 0, 90),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(70, 68, 74),
		}
	)
	-- arco gótico roto detrás de la estatua
	local cfArco = base * CFrame.new(0, 0, 14)
	columna(modelo, cfArco * CFrame.new(-5, 0, 0), 14, 2, Enum.Material.Basalt, piedra, false)
	columna(modelo, cfArco * CFrame.new(5, 0, 0), 9, 2, Enum.Material.Basalt, piedra, true)
	pieza(
		modelo,
		{
			Name = "ArcoIzq",
			Size = Vector3.new(6, 1.6, 2),
			CFrame = cfArco * CFrame.new(-2.4, 16.2, 0) * g(0, 0, -28),
			Material = Enum.Material.Basalt,
			Color = piedra,
		}
	)
	-- lápidas
	for i = 1, 12 do
		local a = (i / 12) * math.pi * 2 + aleatorio:NextNumber(-0.15, 0.15)
		local cf = base * g(0, math.deg(a), 0) * CFrame.new(0, 0, -aleatorio:NextNumber(10, 16))
		local lapida = pieza(
			modelo,
			{
				Name = "Lapida",
				Size = Vector3.new(2.2, aleatorio:NextNumber(2.6, 4), 0.6),
				CFrame = cf
					* CFrame.new(0, 1.4, 0)
					* g(aleatorio:NextNumber(-12, 12), 0, aleatorio:NextNumber(-10, 10)),
				Material = Enum.Material.Slate,
				Color = piedra:Lerp(Color3.fromRGB(120, 120, 120), aleatorio:NextNumber(0, 0.3)),
			}
		)
		if i % 3 == 0 then
			-- vela encima
			local vela = pieza(
				modelo,
				{
					Name = "Vela",
					Size = Vector3.new(0.25, 0.6, 0.25),
					CFrame = lapida.CFrame * CFrame.new(0, lapida.Size.Y / 2 + 0.3, 0),
					Material = Enum.Material.SmoothPlastic,
					Color = Color3.fromRGB(230, 220, 200),
					CanCollide = false,
				}
			)
			local llama = pieza(
				modelo,
				{
					Name = "Llama",
					Shape = Enum.PartType.Ball,
					Size = Vector3.one * 0.25,
					CFrame = vela.CFrame * CFrame.new(0, 0.42, 0),
					Material = Enum.Material.Neon,
					Color = Color3.fromRGB(190, 140, 255),
					CanCollide = false,
				}
			)
			luz(llama, Color3.fromRGB(170, 120, 255), 9, 1)
		end
	end
	-- niebla que se arrastra por el suelo
	local niebla = pieza(
		modelo,
		{
			Name = "Niebla",
			Size = Vector3.new(30, 0.5, 30),
			CFrame = base * CFrame.new(0, 0.6, 0),
			Transparency = 1,
			CanCollide = false,
		}
	)
	local humo = Instance.new("ParticleEmitter")
	humo.Texture = "rbxasset://textures/particles/smoke_main.dds"
	humo.Color = ColorSequence.new(Color3.fromRGB(150, 130, 190))
	humo.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 7) })
	humo.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	humo.Lifetime = NumberRange.new(5, 8)
	humo.Speed = NumberRange.new(0.3, 1)
	humo.SpreadAngle = Vector2.new(80, 10)
	humo.Rate = 6
	humo.Parent = niebla
	local _, enMano = estatuaGuardian(modelo, "Morvak", base * CFrame.new(0, 0, 7), color)
	-- guadaña
	enMano("RightHand", function(cf, escala)
		local asta = pieza(
			modelo,
			{
				Name = "Asta",
				Size = Vector3.new(0.3 * escala, 7.5 * escala, 0.3 * escala),
				CFrame = CFrame.new(cf.Position) * CFrame.new(0, 1.2 * escala, 0),
				Material = Enum.Material.Wood,
				Color = Color3.fromRGB(40, 32, 30),
				CanCollide = false,
			}
		)
		local hoja = pieza(
			modelo,
			{
				Name = "HojaGuadana",
				Size = Vector3.new(0.12 * escala, 0.7 * escala, 3.6 * escala),
				CFrame = asta.CFrame * CFrame.new(0, 3.5 * escala, -1.6 * escala) * g(18, 0, 0),
				Material = Enum.Material.Metal,
				Color = Color3.fromRGB(150, 140, 170),
				CanCollide = false,
			}
		)
		luz(hoja, color, 14, 1.4)
	end)
	estela(modelo, base * CFrame.new(0, 0, 1) * g(0, 180, 0), color, datos.estela)
	tablilla(modelo, base * g(0, 160, 0) * CFrame.new(0, 0, -9), color, datos.tablilla)
	escombros(modelo, base, 22, 10, piedra, Enum.Material.Basalt)
end

-- ---------- Lunaria (Luz): templo de mármol abierto con cristales ----------
local function santuarioLunaria(modelo, base, alto, datos, color)
	local marmol = Color3.fromRGB(236, 234, 228)
	plataforma(modelo, base, alto, 38, "Redonda", Enum.Material.Marble, Color3.fromRGB(200, 198, 194))
	pieza(
		modelo,
		{
			Name = "Suelo",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 32, 32),
			CFrame = base * CFrame.new(0, 0.2, 0) * g(0, 0, 90),
			Material = Enum.Material.Marble,
			Color = marmol,
		}
	)
	pieza(
		modelo,
		{
			Name = "Sol",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, 12, 12),
			CFrame = base * CFrame.new(0, 0.42, 0) * g(0, 0, 90),
			Material = Enum.Material.Neon,
			Color = color,
			Transparency = 0.6,
			CanCollide = false,
		}
	)
	-- peristilo: 10 columnas finas y un anillo encima (tholos)
	for i = 1, 10 do
		local a = i * 36
		columna(modelo, base * g(0, a, 0) * CFrame.new(0, 0.4, -13), 13, 1.5, Enum.Material.Marble, marmol, i == 7)
	end
	for i = 1, 20 do
		if i < 13 or i > 15 then -- un trozo del anillo se cayó
			local a = i * 18
			pieza(
				modelo,
				{
					Name = "Anillo",
					Size = Vector3.new(4.3, 1.2, 2.2),
					CFrame = base * g(0, a, 0) * CFrame.new(0, 15.9, -13),
					Material = Enum.Material.Marble,
					Color = marmol,
				}
			)
		end
	end
	-- cristales de luz
	for _ = 1, 7 do
		local a = aleatorio:NextNumber(0, math.pi * 2)
		local r = aleatorio:NextNumber(15, 19)
		local cristal = pieza(
			modelo,
			{
				Name = "Cristal",
				Size = Vector3.new(1.2, aleatorio:NextNumber(3, 6), 1.2),
				CFrame = base
					* CFrame.new(math.cos(a) * r, 1.5, math.sin(a) * r)
					* g(aleatorio:NextNumber(-20, 20), aleatorio:NextNumber(0, 90), aleatorio:NextNumber(-20, 20)),
				Material = Enum.Material.Glass,
				Color = Color3.fromRGB(255, 245, 210),
				Transparency = 0.2,
				Reflectance = 0.3,
			}
		)
		luz(cristal, color, 10, 0.8)
	end
	-- haz de luz que baja del cielo
	pieza(
		modelo,
		{
			Name = "HazDeLuz",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(50, 6, 6),
			CFrame = base * CFrame.new(0, 25, 0) * g(0, 0, 90),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 245, 210),
			Transparency = 0.85,
			CanCollide = false,
		}
	)
	local _, enMano = estatuaGuardian(modelo, "Lunaria", base * CFrame.new(0, 0, 4), color)
	enMano("RightHand", function(cf, escala)
		local orbe = pieza(
			modelo,
			{
				Name = "OrbeLunaria",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 1.6 * escala,
				CFrame = CFrame.new(cf.Position) * CFrame.new(-0.7 * escala, 1.2 * escala, 0),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(255, 250, 220),
				CanCollide = false,
			}
		)
		luz(orbe, color, 30, 3)
		motas(orbe, color, 8)
	end)
	estela(
		modelo,
		base * CFrame.new(0, 0, -4) * g(0, 180, 0),
		color,
		datos.estela,
		Enum.Material.Marble,
		Color3.fromRGB(190, 188, 182)
	)
	tablilla(modelo, base * g(0, 120, 0) * CFrame.new(0, 0, -9), color, datos.tablilla)
	escombros(modelo, base, 20, 8, marmol, Enum.Material.Marble)
end

local CONSTRUCTORES =
	{ Sylvaris = santuarioSylvaris, Ignar = santuarioIgnar, Morvak = santuarioMorvak, Lunaria = santuarioLunaria }

local function construirSantuario(datos)
	local guardian = HistoriaConfig.GUARDIANES[datos.guardian]
	local color = guardian.color
	local centro, minimo, maximo = buscarSitio(datos.posicion.X, datos.posicion.Y, 20)
	despejar(centro, 32)
	local modelo = Instance.new("Model")
	modelo.Name = datos.nombre
	modelo:SetAttribute("Santuario", datos.id)
	modelo:SetAttribute("Guardian", guardian.nombre)
	modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- llega entero al jugador
	modelo.Parent = carpeta
	local alto = (maximo - minimo) + 3
	local base = CFrame.new(centro.X, centro.Y + 0.8, centro.Z) * g(0, aleatorio:NextNumber(0, 360), 0)
	local constructor = CONSTRUCTORES[datos.id]
	if constructor then
		constructor(modelo, base, alto, datos, color)
	end
	modelo.PrimaryPart = modelo:FindFirstChild("Estela")
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
	-- piedraTexto con el texto
	local piedraTexto = pieza(modelo, {
		Name = "Estela",
		Size = Vector3.new(4.4, 7, 1.2),
		CFrame = base * CFrame.new(0, 3.5, 13),
		Material = Enum.Material.Basalt,
		Color = Color3.fromRGB(36, 34, 40),
	})
	for linea = 1, 4 do
		lineaRunas(modelo, piedraTexto.CFrame * CFrame.new(0, -2.6 + linea * 1.2, -0.62), aleatorio:NextNumber(2.4, 3.4), 0.8, color, "RunaEstela")
	end
	-- explanada de piedra más ancha donde van grabadas las runas
	pieza(modelo, {
		Name = "Explanada",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(alto + 4, 32, 32),
		CFrame = base * CFrame.new(0, -(alto + 4) / 2 - 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(58, 54, 64),
		Material = Enum.Material.Slate,
	})
	-- círculo de runas grabadas en el suelo alrededor del sello (brillan como la grieta)
	for k = 1, 18 do
		local a = k / 18 * math.pi * 2
		local cfRuna = base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.12, -13.2) * CFrame.Angles(-math.pi / 2, 0, 0)
		runa(modelo, cfRuna, 1.5, color, (k % #GLIFOS) + 1, "RunaSello")
	end
	-- y un anillo fino que las une
	for k = 1, 36 do
		local a = k / 36 * math.pi * 2
		pieza(modelo, {
			Name = "AnilloSello",
			Size = Vector3.new(2.5, 0.08, 0.16),
			CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.1, -14.6),
			Material = Enum.Material.Neon,
			Color = color,
			Transparency = 0.25,
			CanCollide = false,
			CastShadow = false,
		})
	end
	legible(piedraTexto, datos.texto, "Examinar la grieta")
	modelo.PrimaryPart = piedraTexto
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
	local ok, err = pcall(construirSello)
	if not ok then
		warn("[HISTORIA] No pude construir la grieta del sello", err)
	end
	-- las estatuas tardan un poco (cargan ropa y pelo del catálogo): en segundo plano
	task.spawn(function()
		for _, datos in HistoriaConfig.SANTUARIOS do
			local bien, error_ = pcall(construirSantuario, datos)
			if not bien then
				warn("[HISTORIA] No pude construir", datos.nombre, error_)
			end
		end
		print("[HISTORIA] Santuarios de los Guardianes y grieta del sello listos")
	end)
end

return RuinasServicio

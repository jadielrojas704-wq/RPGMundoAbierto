-- Efectos visuales que dependen del suelo que pisas (polvo, piedritas, salpicaduras...).
-- Ruta en Studio: ReplicatedStorage/Efectos/EfectosSuelo
-- Solo se usa en el CLIENTE. Todo lo que crea es visual y se borra solo.
--
-- Cómo funciona: lanzamos un rayo hacia abajo desde el personaje para saber
-- qué hay debajo (material y color), y con eso elegimos el tipo de efecto.

local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local EfectosSuelo = {}

-- Textura de humo suave que viene dentro de Roblox
local TEXTURA_HUMO = "rbxasset://textures/particles/smoke_main.dds"

-- ===== PERFILES POR MATERIAL =====
-- polvo: cuánto polvo levanta (1 = normal)
-- trozos: qué sale disparado ("piedras", "hierba", "barro", "astillas", "nieve" o nil)
-- dura: cuánto tarda el polvo en desaparecer (1 = normal)
-- agua: true para salpicaduras en vez de polvo
local M = Enum.Material
local PERFILES = {
	[M.Grass] = { polvo = 0.5, trozos = "hierba", dura = 0.8 },
	[M.LeafyGrass] = { polvo = 0.4, trozos = "hierba", dura = 0.8 },
	[M.Sand] = { polvo = 1.7, trozos = nil, dura = 1.4 },
	[M.Snow] = { polvo = 1.5, trozos = "nieve", dura = 1.2, color = Color3.fromRGB(240, 244, 250) },
	[M.Glacier] = { polvo = 0.5, trozos = "nieve", dura = 0.8, color = Color3.fromRGB(220, 235, 245) },
	[M.Ice] = { polvo = 0.3, trozos = nil, dura = 0.6, color = Color3.fromRGB(220, 235, 245) },
	[M.Mud] = { polvo = 0.3, trozos = "barro", dura = 0.6 },
	[M.Ground] = { polvo = 1.2, trozos = "piedras", dura = 1 },
	[M.Rock] = { polvo = 0.8, trozos = "piedras", dura = 0.9 },
	[M.Slate] = { polvo = 0.8, trozos = "piedras", dura = 0.9 },
	[M.Basalt] = { polvo = 0.8, trozos = "piedras", dura = 0.9 },
	[M.Sandstone] = { polvo = 1.2, trozos = "piedras", dura = 1.1 },
	[M.Limestone] = { polvo = 1.0, trozos = "piedras", dura = 1 },
	[M.Cobblestone] = { polvo = 0.8, trozos = "piedras", dura = 0.9 },
	[M.Pavement] = { polvo = 0.7, trozos = nil, dura = 0.8 },
	[M.Asphalt] = { polvo = 0.6, trozos = nil, dura = 0.8 },
	[M.Concrete] = { polvo = 0.7, trozos = nil, dura = 0.8 },
	[M.Wood] = { polvo = 0.5, trozos = "astillas", dura = 0.7 },
	[M.WoodPlanks] = { polvo = 0.5, trozos = "astillas", dura = 0.7 },
	[M.Water] = { polvo = 0, trozos = nil, dura = 1, agua = true },
}
local PERFIL_NORMAL = { polvo = 0.8, trozos = nil, dura = 0.9 }

-- ===== LEER EL SUELO =====

-- Devuelve información del suelo bajo el personaje, o nil si está en el aire
function EfectosSuelo.LeerSuelo(personaje)
	local raiz = personaje:FindFirstChild("HumanoidRootPart")
	if not raiz then
		return nil
	end
	local parametros = RaycastParams.new()
	parametros.FilterType = Enum.RaycastFilterType.Exclude
	parametros.FilterDescendantsInstances = { personaje }
	parametros.IgnoreWater = false

	local resultado = Workspace:Raycast(raiz.Position, Vector3.new(0, -8, 0), parametros)
	if not resultado then
		return nil
	end

	local material = resultado.Material
	local colorSuelo
	if resultado.Instance:IsA("Terrain") then
		local ok, color = pcall(function()
			return Workspace.Terrain:GetMaterialColor(material)
		end)
		colorSuelo = if ok then color else Color3.fromRGB(150, 140, 125)
	else
		colorSuelo = resultado.Instance.Color
	end

	local perfil = PERFILES[material] or PERFIL_NORMAL
	-- El polvo es el color del suelo, más claro y apagado (como tierra seca)
	local colorPolvo = perfil.color or colorSuelo:Lerp(Color3.fromRGB(190, 182, 168), 0.55)

	return {
		posicion = resultado.Position,
		normal = resultado.Normal,
		material = material,
		perfil = perfil,
		colorSuelo = colorSuelo,
		colorPolvo = colorPolvo,
	}
end

-- ===== PIEZAS BÁSICAS =====

-- Un punto invisible en el suelo donde colgar las partículas
local function anclaEnSuelo(suelo, vidaSegundos)
	local ancla = Instance.new("Attachment")
	ancla.Parent = Workspace.Terrain
	ancla.WorldPosition = suelo.posicion + suelo.normal * 0.15
	Debris:AddItem(ancla, vidaSegundos)
	return ancla
end

local function crearPolvo(padre, suelo, opciones)
	local perfil = suelo.perfil
	local p = Instance.new("ParticleEmitter")
	p.Texture = TEXTURA_HUMO
	p.Enabled = false
	p.Color = ColorSequence.new(suelo.colorPolvo)
	p.LightInfluence = 1 -- se ilumina como el resto del mundo
	p.LightEmission = 0
	p.Lifetime = NumberRange.new(0.6 * perfil.dura, 1.1 * perfil.dura)
	p.Speed = opciones.velocidad or NumberRange.new(2, 5)
	p.SpreadAngle = opciones.apertura or Vector2.new(70, 70)
	p.Drag = 3.5
	p.Acceleration = Vector3.new(0, 0.8, 0) -- el polvo sube un poco
	p.Rotation = NumberRange.new(0, 360)
	p.RotSpeed = NumberRange.new(-40, 40)
	p.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, opciones.tamano or 0.8),
		NumberSequenceKeypoint.new(1, (opciones.tamano or 0.8) * 3),
	})
	p.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, opciones.opacidad or 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	p.Parent = padre
	return p
end

-- ===== EFECTOS =====

-- Nube de polvo en el punto de apoyo
function EfectosSuelo.Polvo(personaje, intensidad)
	local suelo = EfectosSuelo.LeerSuelo(personaje)
	if not suelo then
		return
	end
	if suelo.perfil.agua then
		EfectosSuelo.Salpicadura(personaje, intensidad)
		return
	end
	local cantidad = math.floor(8 * intensidad * suelo.perfil.polvo + 0.5)
	if cantidad <= 0 then
		return
	end
	local ancla = anclaEnSuelo(suelo, 2.5)
	local polvo = crearPolvo(ancla, suelo, {})
	polvo:Emit(cantidad)
end

-- Onda de polvo que se abre en círculo al aterrizar
function EfectosSuelo.Onda(personaje, intensidad)
	local suelo = EfectosSuelo.LeerSuelo(personaje)
	if not suelo then
		return
	end
	if suelo.perfil.agua then
		EfectosSuelo.Salpicadura(personaje, intensidad * 1.5)
		return
	end
	local porDireccion = math.max(1, math.floor(2 * intensidad * suelo.perfil.polvo + 0.5))
	local DIRECCIONES = 10
	for i = 1, DIRECCIONES do
		local angulo = (i / DIRECCIONES) * math.pi * 2
		local ancla = anclaEnSuelo(suelo, 2.5)
		-- Giramos el punto para que su "arriba" apunte hacia fuera, casi pegado al suelo
		ancla.WorldCFrame = CFrame.new(ancla.WorldPosition)
			* CFrame.Angles(0, angulo, 0)
			* CFrame.Angles(math.rad(-78), 0, 0)
		local polvo = crearPolvo(ancla, suelo, {
			velocidad = NumberRange.new(7, 11),
			apertura = Vector2.new(12, 12),
			tamano = 0.6,
			opacidad = 0.55,
		})
		polvo:Emit(porDireccion)
	end
end

-- Rastro de polvo que sigue al personaje mientras rueda.
-- Devuelve una función para apagarlo.
function EfectosSuelo.Rastro(personaje, intensidad)
	local raiz = personaje:FindFirstChild("HumanoidRootPart")
	local suelo = EfectosSuelo.LeerSuelo(personaje)
	if not raiz or not suelo or suelo.perfil.agua or suelo.perfil.polvo <= 0 then
		return function() end
	end
	local ancla = Instance.new("Attachment")
	ancla.Position = Vector3.new(0, -2.6, 0)
	ancla.Parent = raiz

	local polvo = crearPolvo(ancla, suelo, {
		velocidad = NumberRange.new(0.5, 2),
		apertura = Vector2.new(60, 60),
		tamano = 0.7,
		opacidad = 0.7,
	})
	polvo.Rate = 45 * intensidad * suelo.perfil.polvo
	polvo.Enabled = true

	return function()
		polvo.Enabled = false
		Debris:AddItem(ancla, 2)
	end
end

-- Trocitos que salen disparados (piedritas, hierba, barro, astillas, nieve)
local TROZOS = {
	piedras = { material = Enum.Material.Slate, oscurecer = 0.25, tamano = { 0.12, 0.3 }, forma = "bloque" },
	barro = { material = Enum.Material.Mud, oscurecer = 0.35, tamano = { 0.15, 0.3 }, forma = "bola" },
	astillas = { material = Enum.Material.Wood, oscurecer = 0.1, tamano = { 0.05, 0.35 }, forma = "astilla" },
	nieve = { material = Enum.Material.Snow, oscurecer = 0, tamano = { 0.12, 0.25 }, forma = "bola" },
	hierba = { material = Enum.Material.Grass, oscurecer = 0.1, tamano = { 0.04, 0.4 }, forma = "brizna" },
}

function EfectosSuelo.Trozos(personaje, cantidad, direccion)
	local suelo = EfectosSuelo.LeerSuelo(personaje)
	if not suelo or not suelo.perfil.trozos then
		return
	end
	local datos = TROZOS[suelo.perfil.trozos]
	local direccionPlana = if direccion then Vector3.new(direccion.X, 0, direccion.Z) else Vector3.zero

	for _ = 1, cantidad do
		local trozo = Instance.new("Part")
		local a, b = datos.tamano[1], datos.tamano[2]
		local lado = a + math.random() * (b - a)
		if datos.forma == "astilla" then
			trozo.Size = Vector3.new(0.06, 0.06, lado)
		elseif datos.forma == "brizna" then
			trozo.Size = Vector3.new(0.04, lado, 0.08)
		else
			trozo.Size = Vector3.one * lado
			if datos.forma == "bola" then
				trozo.Shape = Enum.PartType.Ball
			end
		end
		trozo.Material = datos.material
		trozo.Color = suelo.colorSuelo:Lerp(Color3.new(0, 0, 0), datos.oscurecer)
		trozo.CanCollide = true
		trozo.CanTouch = false
		trozo.CanQuery = false
		trozo.Massless = true
		trozo.CastShadow = false
		trozo.CFrame = CFrame.new(suelo.posicion + Vector3.new(math.random() - 0.5, 0.3, math.random() - 0.5))
			* CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		trozo.Parent = Workspace

		-- Salen hacia arriba y un poco en la dirección del movimiento
		local alAzar = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 10
		trozo.AssemblyLinearVelocity = alAzar + direccionPlana * 8 + Vector3.new(0, 10 + math.random() * 8, 0)
		trozo.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 30

		Debris:AddItem(trozo, 1.4 + math.random() * 0.4)
	end
end

-- Salpicadura de agua
function EfectosSuelo.Salpicadura(personaje, intensidad)
	local suelo = EfectosSuelo.LeerSuelo(personaje)
	if not suelo then
		return
	end
	local ancla = anclaEnSuelo(suelo, 2)
	local gotas = Instance.new("ParticleEmitter")
	gotas.Enabled = false
	gotas.Color = ColorSequence.new(Color3.fromRGB(210, 230, 245))
	gotas.LightInfluence = 1
	gotas.Lifetime = NumberRange.new(0.4, 0.8)
	gotas.Speed = NumberRange.new(8, 14)
	gotas.SpreadAngle = Vector2.new(35, 35)
	gotas.Acceleration = Vector3.new(0, -40, 0)
	gotas.Size = NumberSequence.new(0.15, 0.05)
	gotas.Transparency = NumberSequence.new(0.2, 1)
	gotas.Parent = ancla
	gotas:Emit(math.floor(25 * intensidad))

	local espuma = crearPolvo(ancla, suelo, { velocidad = NumberRange.new(3, 6), tamano = 0.7, opacidad = 0.5 })
	espuma.Color = ColorSequence.new(Color3.fromRGB(235, 245, 250))
	espuma:Emit(math.floor(8 * intensidad))
end

return EfectosSuelo

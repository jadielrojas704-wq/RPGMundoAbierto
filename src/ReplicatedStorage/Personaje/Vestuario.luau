-- VESTUARIO: viste a un personaje (jugador o NPC) con el aspecto "limpio" del juego:
-- cuerpo de bloques, ropa clásica 2D teñida del color elegido, cara de anime, peinado del
-- catálogo (con su color) y piezas de color encima del cuerpo (cinturón, botas y capa).
-- Ruta en Studio: ReplicatedStorage/Personaje/Vestuario (ModuleScript)
--
-- Lo usan el SERVIDOR (jugadores: ServerScriptService/Progresion/AparienciaServicio) y las
-- herramientas que generan el mundo (NPC: ServerStorage/Herramientas/Mundo/NPCs).
--
--   local descripcion = Vestuario.Descripcion(apariencia, raza, semilla)
--   humanoide:ApplyDescription(descripcion)        (o Players:CreateHumanoidModelFromDescription)
--   Vestuario.Vestir(modelo, apariencia)            -- después: ropa, cara, color del pelo y piezas
--
-- "apariencia" es la tabla de AparienciaConfig.PorDefecto() (campos Rostro, Peinado, Camisa...).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local AparienciaConfig = require(Config:WaitForChild("AparienciaConfig"))
local RazasConfig = require(Config:WaitForChild("RazasConfig"))
local TexturasConfig = require(Config:WaitForChild("TexturasConfig"))

local Vestuario = {}

local PARTES_PIEL = { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" }
local ORO = Color3.fromRGB(214, 172, 84)

local function color(hex, porDefecto)
	if type(hex) == "string" and string.match(hex, "^#%x%x%x%x%x%x$") then
		return Color3.fromHex(hex)
	end
	return porDefecto or Color3.new(1, 1, 1)
end
Vestuario.Color = color

local function textura(nombre)
	local id = TexturasConfig[nombre]
	return if id then "rbxassetid://" .. tostring(id) else ""
end

local function anadir(descripcion, propiedad, id)
	if not id then
		return
	end
	local actual = descripcion[propiedad]
	descripcion[propiedad] = if actual == "" or actual == nil then tostring(id) else actual .. "," .. tostring(id)
end

-- ===== 1) HumanoidDescription: cuerpo, piel, peinado, tocado, raza y animaciones =====
-- extra (opcional): { casco = id, sinRasgosCabeza = true, escala = {alto, ancho} }
function Vestuario.Descripcion(apariencia, raza, semilla, extra)
	local a = apariencia or AparienciaConfig.PorDefecto()
	extra = extra or {}
	local d = Instance.new("HumanoidDescription")
	-- cuerpo de bloques: las partes del cuerpo se quedan en 0
	local piel = AparienciaConfig.PIELES[a.Piel] or AparienciaConfig.PIELES[3]
	for _, parte in PARTES_PIEL do
		d[parte] = piel
	end
	d.HeightScale = math.clamp(a.Altura or 1, 0.92, 1.08)
	d.WidthScale = 1
	d.DepthScale = 1
	d.HeadScale = 1
	if extra.escala then
		d.HeightScale *= extra.escala[1] or 1
		d.WidthScale *= extra.escala[2] or 1
	end

	-- peinado (y segundo peinado)
	for _, campo in { "Peinado", "Peinado2" } do
		local p = AparienciaConfig.PEINADOS[a[campo]]
		if p then
			anadir(d, "HairAccessory", p.id)
		end
	end
	-- barba (solo hombres)
	local barba = AparienciaConfig.BARBAS[a.Barba]
	if barba and a.Genero ~= "Mujer" then
		anadir(d, "FaceAccessory", barba)
	end
	-- tocado (o casco de guardia)
	if extra.casco then
		anadir(d, "HatAccessory", extra.casco)
	else
		local t = AparienciaConfig.TOCADOS[a.Tocado]
		if t then
			anadir(d, if t.tipo == "Face" then "FaceAccessory" else "HatAccessory", t.id)
		end
	end

	-- físico de la raza (orejas, cola, alas, cuernos, altura...)
	local rasgos = RazasConfig.Rasgos(raza, semilla or 1)
	if not extra.sinRasgosCabeza then
		for _, id in rasgos.sombrero or {} do
			anadir(d, "HatAccessory", id)
		end
	end
	for _, id in rasgos.cara or {} do
		anadir(d, "FaceAccessory", id)
	end
	for _, id in rasgos.espalda or {} do
		anadir(d, "BackAccessory", id)
	end
	for _, id in rasgos.cintura or {} do
		anadir(d, "WaistAccessory", id)
	end
	if rasgos.altura then
		d.HeightScale *= rasgos.altura
	end
	if rasgos.ancho then
		d.WidthScale *= rasgos.ancho
		d.DepthScale *= rasgos.ancho
	end
	if rasgos.piel then
		for _, parte in PARTES_PIEL do
			d[parte] = rasgos.piel
		end
	end

	-- animaciones fluidas de movimiento y gestos de descanso (las mismas para todos)
	for propiedad, id in AparienciaConfig.ANIMACIONES do
		d[propiedad] = id
	end
	pcall(function()
		local emotes, puestos = {}, {}
		for nombre, id in AparienciaConfig.DESCANSO do
			emotes[nombre] = { id }
			table.insert(puestos, { Name = nombre, Slot = #puestos + 1 })
		end
		d:SetEmotes(emotes)
		d:SetEquippedEmotes(puestos)
	end)
	return d
end

-- ===== 2) Piezas de color encima del cuerpo =====
local function pieza(carpeta, parteCuerpo, nombre, tamano, offset, colorPieza, material)
	local p = Instance.new("Part")
	p.Name = nombre
	p.Size = tamano
	p.Color = colorPieza
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Anchored = false
	p.CFrame = parteCuerpo.CFrame * offset
	local soldadura = Instance.new("Weld")
	soldadura.Part0 = parteCuerpo
	soldadura.Part1 = p
	soldadura.C0 = offset
	soldadura.Parent = p
	p.Parent = carpeta
	return p
end

local function oscuro(c, f)
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

local function cinturon(carpeta, modelo, estilo, c)
	local cintura = modelo:FindFirstChild("LowerTorso")
	if not cintura then
		return
	end
	local s = cintura.Size
	local alto = if estilo == 2 then s.Y * 0.62 else s.Y * 0.38
	local y = s.Y / 2 - alto / 2 - s.Y * 0.04
	pieza(carpeta, cintura, "Cinturon", Vector3.new(s.X + 0.07, alto, s.Z + 0.07), CFrame.new(0, y, 0), c, Enum.Material.Leather)
	if estilo == 1 then
		-- hebilla dorada
		pieza(carpeta, cintura, "Hebilla", Vector3.new(0.34, alto * 1.05, 0.06), CFrame.new(0, y, -(s.Z / 2 + 0.06)), ORO, Enum.Material.Metal)
		pieza(carpeta, cintura, "HebillaCentro", Vector3.new(0.16, alto * 0.5, 0.07), CFrame.new(0, y, -(s.Z / 2 + 0.08)), oscuro(c, 0.6))
	elseif estilo == 2 then
		-- fajín con nudo que cuelga a un lado
		pieza(carpeta, cintura, "Nudo", Vector3.new(0.3, 0.3, 0.12), CFrame.new(s.X * 0.32, y, -(s.Z / 2 + 0.08)), oscuro(c, 0.85), Enum.Material.Fabric)
		pieza(carpeta, cintura, "Caida", Vector3.new(0.22, 0.8, 0.06), CFrame.new(s.X * 0.36, y - 0.5, -(s.Z / 2 + 0.07)) * CFrame.Angles(0, 0, math.rad(-8)), c, Enum.Material.Fabric)
	else
		-- correas cruzadas por el pecho + bolsa
		local torso = modelo:FindFirstChild("UpperTorso")
		if torso then
			local t = torso.Size
			local largo = math.sqrt(t.X ^ 2 + t.Y ^ 2) * 0.9
			local angulo = math.atan2(t.Y, t.X)
			for _, lado in { -1, 1 } do
				pieza(carpeta, torso, "Correa", Vector3.new(largo, 0.16, 0.05), CFrame.new(0, 0, lado * (t.Z / 2 + 0.03)) * CFrame.Angles(0, 0, angulo), c, Enum.Material.Leather)
			end
		end
		pieza(carpeta, cintura, "Bolsa", Vector3.new(0.42, 0.4, 0.26), CFrame.new(-s.X * 0.36, y - 0.18, -(s.Z / 2 + 0.12)), oscuro(c, 0.8), Enum.Material.Leather)
		pieza(carpeta, cintura, "Hebilla", Vector3.new(0.22, alto * 1.05, 0.06), CFrame.new(0, y, -(s.Z / 2 + 0.06)), ORO, Enum.Material.Metal)
	end
end

local function botas(carpeta, modelo, estilo, c)
	for _, lado in { "Left", "Right" } do
		local pie = modelo:FindFirstChild(lado .. "Foot")
		local pierna = modelo:FindFirstChild(lado .. "LowerLeg")
		if pie and pierna then
			local fs = pie.Size
			pieza(carpeta, pie, "Bota", Vector3.new(fs.X + 0.06, fs.Y + 0.05, fs.Z + 0.08), CFrame.new(0, 0.02, -0.02), c, Enum.Material.Leather)
			-- suela
			pieza(carpeta, pie, "Suela", Vector3.new(fs.X + 0.08, 0.08, fs.Z + 0.1), CFrame.new(0, -fs.Y / 2 + 0.03, -0.02), oscuro(c, 0.45))
			local ls = pierna.Size
			local cana = if estilo == 1 then 0.42 else 0.92
			local alto = ls.Y * cana
			local y = -ls.Y / 2 + alto / 2
			pieza(carpeta, pierna, "Cana", Vector3.new(ls.X + 0.06, alto, ls.Z + 0.06), CFrame.new(0, y, 0), c, Enum.Material.Leather)
			if estilo >= 2 then
				-- borde de arriba (más claro en las de montar, que van dobladas)
				local borde = if estilo == 3 then Color3.new(math.min(1, c.R * 1.35 + 0.08), math.min(1, c.G * 1.35 + 0.06), math.min(1, c.B * 1.35 + 0.04)) else oscuro(c, 0.7)
				local altoBorde = if estilo == 3 then 0.32 else 0.12
				pieza(carpeta, pierna, "Borde", Vector3.new(ls.X + 0.12, altoBorde, ls.Z + 0.12), CFrame.new(0, -ls.Y / 2 + alto - altoBorde / 2, 0), borde, Enum.Material.Leather)
			end
		end
	end
end

local function capa(carpeta, modelo, estilo, c)
	local torso = modelo:FindFirstChild("UpperTorso")
	if not torso then
		return
	end
	local t = torso.Size
	local largo = if estilo == 1 then 2.0 else 3.6
	local panel = Instance.new("Part")
	panel.Name = "Capa"
	panel.Size = Vector3.new(t.X + 0.18, largo, 0.08)
	panel.Color = c
	panel.Material = Enum.Material.Fabric
	panel.CanCollide = false
	panel.CanQuery = false
	panel.CanTouch = false
	panel.Massless = true
	panel.CastShadow = true
	-- articulación en el borde de arriba de la espalda: el cliente la balancea (PeloCliente)
	local motor = Instance.new("Motor6D")
	motor.Name = "CapaMotor"
	motor.Part0 = torso
	motor.Part1 = panel
	motor.C0 = CFrame.new(0, t.Y / 2 - 0.05, t.Z / 2 + 0.06)
	motor.C1 = CFrame.new(0, largo / 2, 0)
	motor.Parent = panel
	panel.CFrame = torso.CFrame * motor.C0 * motor.C1:Inverse()
	panel.Parent = carpeta
	CollectionService:AddTag(panel, "Capa")
	-- forro de un tono más oscuro (se ve por dentro al moverse)
	local forro = pieza(carpeta, panel, "Forro", Vector3.new(panel.Size.X - 0.04, largo - 0.04, 0.02), CFrame.new(0, 0, -0.05), oscuro(c, 0.6), Enum.Material.Fabric)
	forro.CastShadow = false
	-- cuello y broches dorados delante
	pieza(carpeta, torso, "CuelloCapa", Vector3.new(t.X + 0.22, 0.2, t.Z + 0.22), CFrame.new(0, t.Y / 2 - 0.1, 0), oscuro(c, 0.85), Enum.Material.Fabric)
	for _, lado in { -1, 1 } do
		pieza(carpeta, torso, "Broche", Vector3.new(0.2, 0.2, 0.06), CFrame.new(lado * t.X * 0.3, t.Y / 2 - 0.12, -(t.Z / 2 + 0.12)), ORO, Enum.Material.Metal)
	end
	if estilo == 3 then
		-- esclavina: capa corta sobre los hombros
		pieza(carpeta, torso, "Esclavina", Vector3.new(t.X + 0.5, 0.55, t.Z + 0.42), CFrame.new(0, t.Y / 2 - 0.3, 0.02), c, Enum.Material.Fabric)
		pieza(carpeta, torso, "BordeEsclavina", Vector3.new(t.X + 0.54, 0.08, t.Z + 0.46), CFrame.new(0, t.Y / 2 - 0.56, 0.02), ORO, Enum.Material.Fabric)
	end
end

-- ===== 3) La cara (decal "pegado" al frente de la cabeza) =====
local function ponerCara(modelo, nombreTextura)
	local cabeza = modelo:FindFirstChild("Head")
	if not cabeza then
		return
	end
	-- se quita la cara por defecto de Roblox (va pintada en la textura de la cabeza)
	if cabeza:IsA("MeshPart") then
		pcall(function()
			cabeza.TextureID = ""
		end)
	end
	for _, hijo in cabeza:GetChildren() do
		if hijo:IsA("Decal") or (hijo:IsA("SurfaceGui") and hijo.Name == "Cara") then
			hijo:Destroy()
		end
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Cara"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(256, 256)
	gui.LightInfluence = 1
	gui.Brightness = 1
	gui.MaxDistance = 140
	gui.ResetOnSpawn = false
	gui.ClipsDescendants = true
	local imagen = Instance.new("ImageLabel")
	imagen.Name = "Rostro"
	imagen.BackgroundTransparency = 1
	imagen.Size = UDim2.fromScale(1, 1)
	imagen.Image = textura(nombreTextura)
	imagen.Parent = gui
	gui.Adornee = cabeza
	gui.Parent = cabeza
end

-- ===== 4) Color del pelo =====
-- Con color: el peinado pierde su textura y queda de un color liso y limpio (estilo anime).
-- PeloColor = "" deja el color natural del accesorio.
local function colorearPelo(modelo, hex)
	if hex == nil or hex == "" then
		return
	end
	local c = color(hex)
	for _, accesorio in modelo:GetChildren() do
		if accesorio:IsA("Accessory") and accesorio.AccessoryType == Enum.AccessoryType.Hair then
			local asa = accesorio:FindFirstChild("Handle")
			if asa then
				local malla = asa:FindFirstChildOfClass("SpecialMesh")
				if malla then
					malla.TextureId = ""
				end
				for _, s in asa:GetChildren() do
					if s:IsA("SurfaceAppearance") then
						s:Destroy()
					end
				end
				if asa:IsA("MeshPart") then
					pcall(function()
						asa.TextureID = ""
					end)
				end
				asa.Color = c
				asa.Material = Enum.Material.SmoothPlastic
			end
		end
	end
end

-- ===== Vestir (después de aplicar la HumanoidDescription) =====
function Vestuario.Vestir(modelo, apariencia)
	local a = apariencia or AparienciaConfig.PorDefecto()
	-- ropa clásica 2D
	for _, hijo in modelo:GetChildren() do
		if hijo:IsA("Shirt") or hijo:IsA("Pants") or hijo:IsA("ShirtGraphic") then
			hijo:Destroy()
		end
	end
	local camisa = AparienciaConfig.CAMISAS[a.Camisa] or AparienciaConfig.CAMISAS[1]
	local pantalon = AparienciaConfig.PANTALONES[a.Pantalon] or AparienciaConfig.PANTALONES[1]
	local s = Instance.new("Shirt")
	s.Name = "Camisa"
	s.ShirtTemplate = textura(camisa.textura)
	s.Color3 = color(a.CamisaColor)
	s.Parent = modelo
	local p = Instance.new("Pants")
	p.Name = "Pantalon"
	p.PantsTemplate = textura(pantalon.textura)
	p.Color3 = color(a.PantalonColor)
	p.Parent = modelo

	local rostro = AparienciaConfig.ROSTROS[a.Rostro] or AparienciaConfig.ROSTROS[1]
	ponerCara(modelo, rostro.textura)
	colorearPelo(modelo, a.PeloColor)

	-- piezas de color
	local anterior = modelo:FindFirstChild("Vestuario")
	if anterior then
		anterior:Destroy()
	end
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Vestuario"
	carpeta.Parent = modelo
	if (a.Cinturon or 0) > 0 then
		cinturon(carpeta, modelo, a.Cinturon, color(a.CinturonColor))
	end
	if (a.Botas or 0) > 0 then
		botas(carpeta, modelo, a.Botas, color(a.BotasColor))
	end
	if (a.Capa or 0) > 0 then
		capa(carpeta, modelo, a.Capa, color(a.CapaColor))
	end
end

-- ===== Aspecto al azar (botón "Al azar" del editor y NPC) =====
-- rng: Random (opcional). Devuelve una apariencia completa.
function Vestuario.Aleatoria(rng, genero)
	rng = rng or Random.new()
	local function de(lista)
		return lista[rng:NextInteger(1, #lista)]
	end
	local a = AparienciaConfig.PorDefecto()
	a.Genero = genero or (if rng:NextNumber() < 0.5 then "Hombre" else "Mujer")
	local mujer = a.Genero == "Mujer"
	a.Piel = rng:NextInteger(1, 10)
	a.Rostro = if mujer then rng:NextInteger(9, 14) else rng:NextInteger(1, 8)
	local largos = {}
	for i, p in AparienciaConfig.PEINADOS do
		if (mujer and p.largo ~= "corto") or (not mujer and p.largo ~= "largo") then
			table.insert(largos, i)
		end
	end
	a.Peinado = de(largos)
	a.Peinado2 = 0
	a.PeloColor = de(AparienciaConfig.COLORES_PELO)
	a.Tocado = if rng:NextNumber() < 0.3 then rng:NextInteger(1, #AparienciaConfig.TOCADOS) else 0
	a.Barba = if not mujer and rng:NextNumber() < 0.3 then rng:NextInteger(1, #AparienciaConfig.BARBAS) else 0
	a.Camisa = rng:NextInteger(1, #AparienciaConfig.CAMISAS)
	a.CamisaColor = de(AparienciaConfig.COLORES_RAPIDOS)
	a.Pantalon = if mujer and rng:NextNumber() < 0.5 then 4 else de({ 1, 2, 3, 5, 6 })
	a.PantalonColor = de(AparienciaConfig.COLORES_RAPIDOS)
	a.Cinturon = rng:NextInteger(0, #AparienciaConfig.CINTURONES)
	a.CinturonColor = de({ "#3B2A20", "#1E1A1C", "#6B4A2E", "#7A1E22" })
	a.Botas = rng:NextInteger(0, #AparienciaConfig.BOTAS)
	a.BotasColor = de({ "#1E1A1C", "#3B2A20", "#6B4A2E" })
	a.Capa = if rng:NextNumber() < 0.35 then rng:NextInteger(1, #AparienciaConfig.CAPAS) else 0
	a.CapaColor = de(AparienciaConfig.COLORES_RAPIDOS)
	return a
end

return Vestuario

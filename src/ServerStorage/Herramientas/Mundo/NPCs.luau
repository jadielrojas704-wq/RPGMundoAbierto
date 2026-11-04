-- NPC de los pueblos: cuerpo, ropa según su cultura y oficio, nombre y botón para hablar.
-- Ruta en Studio: ServerStorage/Herramientas/Mundo/NPCs
-- Lo usa ServerStorage/Herramientas/Mundo/Pueblos. No se ejecuta solo.
--
-- Cada NPC lleva atributos que lee el cliente (StarterPlayerScripts/NPCCliente)
-- para mostrar el diálogo y la tienda: Nombre, Oficio, Titulo, Cultura, Pueblo, Tienda.
-- El servidor (ServerScriptService/Mundo/NPCServicio) les pone la animación de estar de pie.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PueblosConfig = require(ReplicatedStorage.Config.PueblosConfig)

local NPCs = {}

local M = Enum.Material
local rng = Random.new(4242)

local function elegir(lista)
	return lista[rng:NextInteger(1, #lista)]
end

local PIEL = {
	Reino = { Color3.fromRGB(234, 192, 160), Color3.fromRGB(214, 170, 136), Color3.fromRGB(190, 140, 110), Color3.fromRGB(150, 104, 76) },
	Sol = { Color3.fromRGB(196, 146, 104), Color3.fromRGB(168, 118, 82), Color3.fromRGB(140, 96, 66), Color3.fromRGB(110, 74, 52) },
	Brujos = { Color3.fromRGB(222, 212, 206), Color3.fromRGB(200, 188, 186), Color3.fromRGB(176, 164, 170) },
	Norte = { Color3.fromRGB(242, 212, 192), Color3.fromRGB(228, 192, 168), Color3.fromRGB(212, 176, 150) },
}

local PELO = {
	Color3.fromRGB(40, 30, 24),
	Color3.fromRGB(90, 60, 36),
	Color3.fromRGB(150, 110, 60),
	Color3.fromRGB(200, 170, 110),
	Color3.fromRGB(130, 50, 30),
	Color3.fromRGB(150, 150, 150),
}

-- Ropa: { camisa, pantalón } por cultura (se elige una al azar)
local ROPA = {
	Reino = {
		{ Color3.fromRGB(120, 40, 36), Color3.fromRGB(70, 56, 44) },
		{ Color3.fromRGB(60, 80, 110), Color3.fromRGB(80, 66, 50) },
		{ Color3.fromRGB(110, 100, 70), Color3.fromRGB(60, 52, 44) },
		{ Color3.fromRGB(80, 96, 60), Color3.fromRGB(70, 60, 48) },
	},
	Sol = {
		{ Color3.fromRGB(236, 226, 206), Color3.fromRGB(196, 170, 130) },
		{ Color3.fromRGB(36, 120, 132), Color3.fromRGB(226, 210, 176) },
		{ Color3.fromRGB(190, 64, 46), Color3.fromRGB(230, 214, 180) },
		{ Color3.fromRGB(226, 160, 50), Color3.fromRGB(120, 80, 50) },
	},
	Brujos = {
		{ Color3.fromRGB(46, 30, 60), Color3.fromRGB(30, 24, 30) },
		{ Color3.fromRGB(30, 30, 36), Color3.fromRGB(24, 20, 24) },
		{ Color3.fromRGB(70, 30, 70), Color3.fromRGB(36, 28, 34) },
		{ Color3.fromRGB(40, 56, 46), Color3.fromRGB(30, 28, 28) },
	},
	Norte = {
		{ Color3.fromRGB(40, 64, 98), Color3.fromRGB(90, 70, 50) },
		{ Color3.fromRGB(120, 96, 70), Color3.fromRGB(70, 60, 50) },
		{ Color3.fromRGB(110, 40, 36), Color3.fromRGB(80, 66, 52) },
		{ Color3.fromRGB(150, 150, 146), Color3.fromRGB(70, 60, 50) },
	},
}

-- Pieza decorativa pegada a una parte del cuerpo (se mueve con la animación)
local function adorno(cuerpo, offset, tamano, material, color, forma, nombre)
	local p = Instance.new("Part")
	p.Name = nombre or "Adorno"
	p.Size = tamano
	p.Material = material
	p.Color = color
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = cuerpo.CFrame * offset
	if forma == "Elipse" then
		local malla = Instance.new("SpecialMesh")
		malla.MeshType = Enum.MeshType.Sphere
		malla.Parent = p
	elseif forma == "Cono" then
		local malla = Instance.new("SpecialMesh")
		malla.MeshType = Enum.MeshType.FileMesh
		malla.MeshId = "rbxassetid://1033714"
		malla.Scale = Vector3.new(tamano.X / 2, tamano.Y, tamano.Z / 2)
		malla.Parent = p
	elseif forma == "Cilindro" then
		p.Shape = Enum.PartType.Cylinder
	end
	local soldadura = Instance.new("WeldConstraint")
	soldadura.Part0 = cuerpo
	soldadura.Part1 = p
	soldadura.Parent = p
	p.Parent = cuerpo.Parent
	return p
end

-- Ropa y accesorios según cultura y oficio
local function vestir(modelo, cultura, oficio, colores)
	local cabeza = modelo:FindFirstChild("Head")
	local torso = modelo:FindFirstChild("UpperTorso")
	local cintura = modelo:FindFirstChild("LowerTorso")
	if not (cabeza and torso and cintura) then
		return
	end
	local tc = torso.Size
	local hc = cabeza.Size
	local datosCultura = PueblosConfig.CULTURAS[cultura]
	local pelo = elegir(PELO)
	local cubierta = false -- si lleva algo en la cabeza

	-- Cinturón
	adorno(cintura, CFrame.new(0, cintura.Size.Y * 0.2, 0), Vector3.new(cintura.Size.X + 0.06, 0.25, cintura.Size.Z + 0.06), M.Leather, Color3.fromRGB(56, 40, 28), nil, "Cinturon")

	if oficio == "Guardia" then
		-- casco, peto y tabardo con los colores de la cultura
		cubierta = true
		if cultura == "Sol" then
			adorno(cabeza, CFrame.new(0, hc.Y * 0.32, 0), Vector3.new(hc.X * 1.12, hc.Y * 0.62, hc.Z * 1.12), M.Foil, datosCultura.detalle, "Elipse", "Casco")
			adorno(cabeza, CFrame.new(0, hc.Y * 0.75, 0), Vector3.new(0.3, 0.6, 0.3), M.Foil, datosCultura.detalle, "Cono", "Pincho")
		else
			adorno(cabeza, CFrame.new(0, hc.Y * 0.3, 0), Vector3.new(hc.X * 1.14, hc.Y * 0.7, hc.Z * 1.14), M.Metal, Color3.fromRGB(140, 142, 148), "Elipse", "Casco")
			adorno(cabeza, CFrame.new(0, hc.Y * 0.05, -hc.Z * 0.55), Vector3.new(0.18, hc.Y * 0.45, 0.1), M.Metal, Color3.fromRGB(130, 132, 138), nil, "Nasal")
		end
		adorno(torso, CFrame.new(0, 0, 0), Vector3.new(tc.X + 0.12, tc.Y + 0.05, tc.Z + 0.12), M.Metal, Color3.fromRGB(150, 152, 158), nil, "Peto")
		adorno(torso, CFrame.new(0, -tc.Y * 0.15, -tc.Z / 2 - 0.08), Vector3.new(tc.X * 0.6, tc.Y * 1.3, 0.06), M.Fabric, datosCultura.bandera, nil, "Tabardo")
	elseif oficio == "Herrero" then
		adorno(torso, CFrame.new(0, -tc.Y * 0.1, -tc.Z / 2 - 0.05), Vector3.new(tc.X * 0.85, tc.Y * 1.5, 0.08), M.Leather, Color3.fromRGB(86, 58, 36), nil, "Mandil")
		adorno(cabeza, CFrame.new(0, hc.Y * 0.32, 0), Vector3.new(hc.X * 1.06, hc.Y * 0.28, hc.Z * 1.06), M.Fabric, Color3.fromRGB(110, 40, 30), "Elipse", "Panuelo")
		cubierta = true
	elseif oficio == "Armaduras" then
		adorno(torso, CFrame.new(0, 0, 0), Vector3.new(tc.X + 0.1, tc.Y + 0.04, tc.Z + 0.1), M.DiamondPlate, Color3.fromRGB(120, 122, 126), nil, "CotaDeMalla")
	elseif oficio == "Pociones" then
		-- capucha o sombrero de alquimista
		cubierta = true
		if cultura == "Brujos" then
			adorno(cabeza, CFrame.new(0, hc.Y * 0.45, 0) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.12, hc.X * 2, hc.Z * 2), M.Fabric, Color3.fromRGB(36, 24, 46), "Cilindro", "Ala")
			adorno(cabeza, CFrame.new(0, hc.Y * 1.2, 0) * CFrame.Angles(0, 0, math.rad(8)), Vector3.new(hc.X * 1.1, hc.Y * 1.5, hc.Z * 1.1), M.Fabric, Color3.fromRGB(46, 30, 60), "Cono", "Sombrero")
		else
			adorno(cabeza, CFrame.new(0, hc.Y * 0.12, hc.Z * 0.08), Vector3.new(hc.X * 1.22, hc.Y * 1.1, hc.Z * 1.22), M.Fabric, colores[1], "Elipse", "Capucha")
		end
		adorno(torso, CFrame.new(0, -tc.Y * 0.9, 0), Vector3.new(tc.X + 0.2, tc.Y * 1.4, tc.Z + 0.2), M.Fabric, colores[1], nil, "Tunica")
	elseif oficio == "Establo" then
		cubierta = true
		if cultura == "Norte" or cultura == "Brujos" then
			adorno(cabeza, CFrame.new(0, hc.Y * 0.35, 0), Vector3.new(hc.X * 1.15, hc.Y * 0.5, hc.Z * 1.15), M.Fabric, Color3.fromRGB(110, 86, 60), "Elipse", "GorroPiel")
		else
			-- sombrero de paja (el cilindro va tumbado: su eje es X, lo giramos para que sea vertical)
			adorno(cabeza, CFrame.new(0, hc.Y * 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.15, hc.X * 2.2, hc.Z * 2.2), M.Fabric, Color3.fromRGB(210, 186, 110), "Cilindro", "AlaSombrero")
			adorno(cabeza, CFrame.new(0, hc.Y * 0.7, 0), Vector3.new(hc.X * 0.95, hc.Y * 0.45, hc.Z * 0.95), M.Fabric, Color3.fromRGB(200, 176, 100), "Elipse", "CopaSombrero")
		end
	end

	-- Detalles propios de cada cultura
	if cultura == "Sol" and not cubierta then
		-- turbante
		adorno(cabeza, CFrame.new(0, hc.Y * 0.38, 0), Vector3.new(hc.X * 1.2, hc.Y * 0.55, hc.Z * 1.2), M.Fabric, elegir({ Color3.fromRGB(240, 236, 226), Color3.fromRGB(36, 120, 132), Color3.fromRGB(190, 64, 46) }), "Elipse", "Turbante")
		cubierta = true
	elseif cultura == "Brujos" then
		-- capa oscura
		adorno(torso, CFrame.new(0, -tc.Y * 0.35, tc.Z / 2 + 0.08) * CFrame.Angles(math.rad(-6), 0, 0), Vector3.new(tc.X * 1.05, tc.Y * 2.3, 0.08), M.Fabric, Color3.fromRGB(30, 22, 36), nil, "Capa")
		if not cubierta and rng:NextNumber() < 0.6 then
			adorno(cabeza, CFrame.new(0, hc.Y * 0.12, hc.Z * 0.08), Vector3.new(hc.X * 1.22, hc.Y * 1.1, hc.Z * 1.22), M.Fabric, Color3.fromRGB(36, 26, 44), "Elipse", "Capucha")
			cubierta = true
		end
	elseif cultura == "Norte" then
		-- cuello de piel y barba (los hombres)
		adorno(torso, CFrame.new(0, tc.Y * 0.45, 0), Vector3.new(tc.X * 1.25, tc.Y * 0.35, tc.Z * 1.5), M.Fabric, Color3.fromRGB(120, 96, 70), "Elipse", "CuelloPiel")
		if rng:NextNumber() < 0.6 then
			adorno(cabeza, CFrame.new(0, -hc.Y * 0.38, -hc.Z * 0.4), Vector3.new(hc.X * 0.7, hc.Y * 0.55, hc.Z * 0.35), M.Fabric, pelo, "Elipse", "Barba")
		end
	elseif cultura == "Reino" and oficio == "Aldeano" and rng:NextNumber() < 0.4 then
		adorno(cabeza, CFrame.new(0, hc.Y * 0.4, 0), Vector3.new(hc.X * 1.1, hc.Y * 0.4, hc.Z * 1.1), M.Fabric, colores[1], "Elipse", "Gorro")
		cubierta = true
	end

	-- Pelo (si no lleva nada en la cabeza)
	if not cubierta then
		adorno(cabeza, CFrame.new(0, hc.Y * 0.22, hc.Z * 0.1), Vector3.new(hc.X * 1.1, hc.Y * 0.75, hc.Z * 1.12), M.Fabric, pelo, "Elipse", "Pelo")
	end
end

-- Cartel flotante con el nombre y el oficio
local function etiqueta(cabeza, nombre, titulo, cultura)
	local cartel = Instance.new("BillboardGui")
	cartel.Name = "Nombre"
	cartel.Size = UDim2.fromOffset(220, 44)
	cartel.StudsOffset = Vector3.new(0, 2.4, 0)
	cartel.MaxDistance = 40
	cartel.LightInfluence = 0
	cartel.Parent = cabeza
	local texto = Instance.new("TextLabel")
	texto.Size = UDim2.new(1, 0, 0.6, 0)
	texto.BackgroundTransparency = 1
	texto.Font = Enum.Font.Garamond
	texto.TextScaled = true
	texto.Text = nombre
	texto.TextColor3 = Color3.fromRGB(245, 232, 200)
	texto.TextStrokeTransparency = 0.4
	texto.Parent = cartel
	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.fromScale(0, 0.6)
	sub.Size = UDim2.new(1, 0, 0.4, 0)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.Garamond
	sub.TextScaled = true
	sub.Text = titulo
	sub.TextColor3 = PueblosConfig.CULTURAS[cultura].detalle
	sub.TextStrokeTransparency = 0.5
	sub.Parent = cartel
end

-- Crea un NPC. datos = { nombre, oficio, tienda?, cultura, pueblo, cf (en el suelo, mirando al frente) }
function NPCs.Crear(padre, datos)
	local cultura = datos.cultura
	local colores = elegir(ROPA[cultura])
	local piel = elegir(PIEL[cultura])

	local descripcion = Instance.new("HumanoidDescription")
	descripcion.HeadColor = piel
	descripcion.TorsoColor = colores[1]
	descripcion.LeftArmColor = colores[1]
	descripcion.RightArmColor = colores[1]
	descripcion.LeftLegColor = colores[2]
	descripcion.RightLegColor = colores[2]
	-- Proporciones más humanas que el muñeco normal: algo más alto y más delgado
	descripcion.HeightScale = rng:NextNumber(1, 1.1)
	descripcion.WidthScale = rng:NextNumber(0.82, 0.94)
	descripcion.DepthScale = rng:NextNumber(0.86, 0.95)
	descripcion.HeadScale = 0.92

	local ok, modelo = pcall(function()
		return Players:CreateHumanoidModelFromDescription(descripcion, Enum.HumanoidRigType.R15)
	end)
	if not ok or not modelo then
		warn("[MUNDO] No pude crear el NPC", datos.nombre, modelo)
		return nil
	end
	local oficio = PueblosConfig.OFICIOS[datos.oficio] or PueblosConfig.OFICIOS.Aldeano
	modelo.Name = datos.nombre

	-- Manos color piel y botas oscuras
	for _, nombreParte in { "LeftHand", "RightHand" } do
		local p = modelo:FindFirstChild(nombreParte)
		if p then
			p.Color = piel
		end
	end
	for _, nombreParte in { "LeftFoot", "RightFoot" } do
		local p = modelo:FindFirstChild(nombreParte)
		if p then
			p.Color = Color3.fromRGB(54, 40, 30)
		end
	end

	local humanoide = modelo:FindFirstChildOfClass("Humanoid")
	local raiz = modelo:FindFirstChild("HumanoidRootPart")
	humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoide.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	-- Quieto en su sitio: el cuerpo anclado, pero las animaciones sí se ven
	raiz.Anchored = true

	-- De pie en el suelo, mirando al frente
	local altura = humanoide.HipHeight + raiz.Size.Y / 2
	modelo:PivotTo(CFrame.new(datos.cf.Position + Vector3.new(0, altura, 0)) * datos.cf.Rotation)

	vestir(modelo, cultura, datos.oficio, colores)

	-- Datos para el cliente (diálogo y tienda)
	modelo:SetAttribute("NPC", true)
	modelo:SetAttribute("Nombre", datos.nombre)
	modelo:SetAttribute("Oficio", datos.oficio)
	modelo:SetAttribute("Titulo", oficio.titulo)
	modelo:SetAttribute("Cultura", cultura)
	modelo:SetAttribute("Pueblo", datos.pueblo.id)
	modelo:SetAttribute("PuebloNombre", datos.pueblo.nombre)
	if datos.tienda then
		modelo:SetAttribute("Tienda", datos.tienda)
	end
	CollectionService:AddTag(modelo, "NPC")

	-- Botón para hablar (tecla E, o tocar en el móvil)
	local boton = Instance.new("ProximityPrompt")
	boton.Name = "Hablar"
	boton.ActionText = if datos.tienda then "Hablar / Tienda" else "Hablar"
	boton.ObjectText = datos.nombre .. " · " .. oficio.titulo
	boton.KeyboardKeyCode = Enum.KeyCode.E
	boton.MaxActivationDistance = 10
	boton.HoldDuration = 0
	boton.RequiresLineOfSight = false
	boton.Parent = raiz

	etiqueta(modelo:FindFirstChild("Head"), datos.nombre, oficio.titulo, cultura)

	modelo.Parent = padre
	return modelo
end

return NPCs

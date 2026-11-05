-- Efectos visuales y de sonido del combate. Solo en el CLIENTE (no cambia nada del juego).
-- Ruta en Studio: ReplicatedStorage/Combate/EfectosCombate
--
--   EfectosCombate.Impacto(posicion, tipo, color, critico)   destello, onda y chispas
--   EfectosCombate.Numero(posicion, dano, critico)            número de daño que sube
--   EfectosCombate.Temblor(fuerza, duracion)                  temblor de cámara (moderado)
--   EfectosCombate.GolpeFOV(cantidad)                         "empujón" del campo de visión
--   EfectosCombate.Sonido(parte, nombre, volumen)             sonidos de Pro Sound Effects

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local EfectosCombate = {}

local function id(n)
	return "rbxassetid://" .. n
end

-- Sonidos (todos de Pro Sound Effects, con licencia de Roblox)
local SONIDOS = {
	Silbido = { id(9120704940), id(9120704709), id(9120704978) }, -- Whooshes Fast Wipes Quick Airy Slices
	SilbidoFuerte = { id(9120728815) }, -- Whoosh Heavy Punches
	Puno = { id(9113572282), id(9113575294), id(9113565905), id(9113520892) }, -- Boxing Hits / Rubber Glove
	Patada = { id(9113530386), id(9113530392) }, -- Body Kicks
	Pesado = { id(9117969717), id(9117972870), id(9113964289) }, -- Beefy Hit / Punch Thud / Cracky Punch
	Hueso = { id(9113510041) }, -- Body Hits Bone Impact (críticos)
	Pisada = { "rbxasset://sounds/action_jump_land.mp3" },
	Carga = { id(9125648149) }, -- Magic Zoom Up Sharp Tubular Whoosh
}

local VOLUMENES = {
	Silbido = 0.35,
	SilbidoFuerte = 0.5,
	Puno = 0.8,
	Patada = 0.85,
	Pesado = 1,
	Hueso = 0.5,
	Pisada = 0.3,
	Carga = 0.35,
}

function EfectosCombate.Sonido(parte, nombre, volumen)
	local lista = SONIDOS[nombre]
	if not (lista and parte and parte.Parent) then
		return
	end
	local sonido = Instance.new("Sound")
	sonido.SoundId = lista[math.random(1, #lista)]
	sonido.Volume = (volumen or 1) * (VOLUMENES[nombre] or 0.6)
	sonido.PlaybackSpeed = 0.94 + math.random() * 0.12
	sonido.RollOffMinDistance = 8
	sonido.RollOffMaxDistance = 90
	sonido.Parent = parte
	sonido:Play()
	Debris:AddItem(sonido, 3)
	return sonido
end

-- Carpeta donde viven los efectos (no chocan con nada)
local carpeta = nil
local function contenedor()
	if not carpeta or not carpeta.Parent then
		carpeta = Instance.new("Folder")
		carpeta.Name = "EfectosCombate"
		carpeta.Parent = Workspace
	end
	return carpeta
end

local function pieza(propiedades)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in propiedades do
		p[k] = v
	end
	p.Parent = contenedor()
	return p
end

-- Destello de impacto + onda + chispas
function EfectosCombate.Impacto(posicion, tipo, color, critico)
	color = color or Color3.fromRGB(150, 225, 255)
	local fuerte = tipo == "Pesado" or tipo == "Patada" or critico
	local camara = Workspace.CurrentCamera
	local mirando = if camara then CFrame.lookAt(posicion, camara.CFrame.Position) else CFrame.new(posicion)

	-- destello (bola que crece y se apaga muy rápido)
	local destello = pieza({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.6,
		CFrame = CFrame.new(posicion),
		Color = Color3.new(1, 1, 1),
		Transparency = 0,
	})
	local grande = if tipo == "Pesado" then 6 elseif fuerte then 4 else 2.6
	TweenService:Create(
		destello,
		TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * grande, Transparency = 1, Color = color }
	):Play()
	Debris:AddItem(destello, 0.2)

	-- onda (anillo mirando a la cámara)
	local onda = pieza({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.08, 1, 1),
		CFrame = mirando * CFrame.Angles(0, math.pi / 2, 0),
		Color = color,
		Transparency = 0.2,
	})
	local anillo = if tipo == "Pesado" then 14 elseif fuerte then 8 else 5
	TweenService:Create(
		onda,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.02, anillo, anillo), Transparency = 1 }
	):Play()
	Debris:AddItem(onda, 0.3)

	-- líneas de impacto (rayitas que salen disparadas, estilo anime)
	local rayas = if tipo == "Pesado" then 10 elseif fuerte then 7 else 4
	for _ = 1, rayas do
		local direccion = (mirando * CFrame.Angles(0, 0, math.random() * math.pi * 2)).RightVector
		local largo = 1.5 + math.random() * (if fuerte then 3 else 1.5)
		local raya = pieza({
			Size = Vector3.new(0.12, 0.12, largo),
			CFrame = CFrame.lookAt(posicion, posicion + direccion) * CFrame.new(0, 0, -largo / 2),
			Color = Color3.new(1, 1, 1),
			Transparency = 0,
		})
		TweenService:Create(raya, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.lookAt(posicion, posicion + direccion) * CFrame.new(0, 0, -largo * 1.6),
			Size = Vector3.new(0.02, 0.02, largo * 0.4),
			Transparency = 1,
		}):Play()
		Debris:AddItem(raya, 0.2)
	end

	-- chispas
	local emisor = pieza({ Size = Vector3.one * 0.1, CFrame = CFrame.new(posicion), Transparency = 1 })
	local chispas = Instance.new("ParticleEmitter")
	chispas.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	chispas.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	chispas.LightEmission = 1
	chispas.Lifetime = NumberRange.new(0.15, 0.35)
	chispas.Speed = NumberRange.new(12, if fuerte then 32 else 22)
	chispas.SpreadAngle = Vector2.new(180, 180)
	chispas.Size = NumberSequence.new(if fuerte then 0.5 else 0.35, 0)
	chispas.Drag = 6
	chispas.Rate = 0
	chispas.Parent = emisor
	chispas:Emit(if tipo == "Pesado" then 30 elseif fuerte then 18 else 10)
	Debris:AddItem(emisor, 0.6)

	-- en el golpe cargado, onda de choque en el suelo
	if tipo == "Pesado" then
		local suelo = pieza({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.15, 2, 2),
			CFrame = CFrame.new(posicion - Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = color,
			Transparency = 0.3,
		})
		TweenService:Create(
			suelo,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(0.05, 22, 22), Transparency = 1 }
		):Play()
		Debris:AddItem(suelo, 0.4)
	end
end

-- Número de daño flotante
function EfectosCombate.Numero(posicion, dano, critico)
	local ancla = pieza({
		Size = Vector3.one * 0.1,
		CFrame = CFrame.new(posicion + Vector3.new((math.random() - 0.5) * 2, 0.5, (math.random() - 0.5) * 2)),
		Transparency = 1,
	})
	local cartel = Instance.new("BillboardGui")
	cartel.Size = UDim2.fromOffset(160, 60)
	cartel.AlwaysOnTop = true
	cartel.LightInfluence = 0
	cartel.MaxDistance = 120
	cartel.Parent = ancla
	local texto = Instance.new("TextLabel")
	texto.BackgroundTransparency = 1
	texto.Size = UDim2.fromScale(1, 1)
	texto.Font = Enum.Font.GothamBlack
	texto.Text = tostring(math.floor(dano + 0.5)) .. (if critico then "!" else "")
	texto.TextScaled = true
	texto.TextColor3 = if critico then Color3.fromRGB(255, 205, 70) else Color3.fromRGB(255, 255, 255)
	texto.TextStrokeColor3 = if critico then Color3.fromRGB(120, 40, 0) else Color3.fromRGB(20, 20, 30)
	texto.TextStrokeTransparency = 0
	texto.Parent = cartel
	local degradado = Instance.new("UIGradient")
	degradado.Rotation = 90
	degradado.Color = if critico
		then ColorSequence.new(Color3.fromRGB(255, 245, 190), Color3.fromRGB(255, 170, 40))
		else ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(140, 215, 255))
	degradado.Parent = texto
	local escala = Instance.new("UIScale")
	escala.Scale = if critico then 1.5 else 0.6
	escala.Parent = texto
	TweenService:Create(
		escala,
		TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = if critico then 1.15 else 0.85 }
	):Play()
	TweenService:Create(
		ancla,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = ancla.CFrame + Vector3.new(0, 3.5, 0) }
	):Play()
	task.delay(0.45, function()
		TweenService:Create(texto, TweenInfo.new(0.35), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	Debris:AddItem(ancla, 0.9)
end

-- ===== Cámara =====

local temblorFuerza, temblorFin, temblorDuracion = 0, 0, 0.1
local fuerzaTemblorUsuario = 1 -- se puede bajar en Ajustes (futuro)

function EfectosCombate.Temblor(fuerza, duracion)
	duracion = duracion or 0.15
	if os.clock() + duracion > temblorFin or fuerza > temblorFuerza then
		temblorFuerza = math.max(fuerza, if os.clock() < temblorFin then temblorFuerza else 0)
		temblorFin = os.clock() + duracion
		temblorDuracion = duracion
	end
end

function EfectosCombate.GolpeFOV(cantidad)
	local camara = Workspace.CurrentCamera
	if not camara then
		return
	end
	local base = camara.FieldOfView
	TweenService:Create(
		camara,
		TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = base + cantidad }
	):Play()
	task.delay(0.08, function()
		TweenService
			:Create(
				camara,
				TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ FieldOfView = base }
			)
			:Play()
	end)
end

if RunService:IsClient() then
	RunService:BindToRenderStep("TemblorCombate", Enum.RenderPriority.Camera.Value + 2, function()
		local restante = temblorFin - os.clock()
		if restante <= 0 then
			return
		end
		local camara = Workspace.CurrentCamera
		if not camara then
			return
		end
		local t = restante / temblorDuracion
		local f = temblorFuerza * t * fuerzaTemblorUsuario
		local x = (math.noise(os.clock() * 40, 0.3) * 2) * f
		local y = (math.noise(os.clock() * 40, 7.1) * 2) * f
		camara.CFrame = camara.CFrame * CFrame.Angles(math.rad(y), math.rad(x), 0)
	end)
end

local _ = Players
return EfectosCombate

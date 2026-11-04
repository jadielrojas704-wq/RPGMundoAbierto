-- Cambia el ambiente según la región en la que estás y muestra su nombre.
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/AmbienteRegion
-- Solo efectos visuales del cliente: niebla, color, partículas en el aire y cartel.
-- Las regiones y sus ambientes están en ReplicatedStorage/Config/RegionesConfig.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Regiones = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("RegionesConfig"))
local ClimaConfig = require(ReplicatedStorage.Config:WaitForChild("ClimaConfig"))

local jugador = Players.LocalPlayer
local TEXTURA_HUMO = "rbxasset://textures/particles/smoke_main.dds"
local ESPERA_CARTEL = 25 -- segundos antes de volver a mostrar el nombre de la misma región

local regionActual = nil

local function mezcla(a, b, t)
	return a + (b - a) * t
end
local ultimoCartel = {}

-- ===== CARTEL CON EL NOMBRE DE LA REGIÓN =====

local pantalla = Instance.new("ScreenGui")
pantalla.Name = "CartelRegion"
pantalla.ResetOnSpawn = false
pantalla.IgnoreGuiInset = true
pantalla.DisplayOrder = 5
pantalla.Parent = jugador:WaitForChild("PlayerGui")

local texto = Instance.new("TextLabel")
texto.AnchorPoint = Vector2.new(0.5, 0.5)
texto.Position = UDim2.fromScale(0.5, 0.3)
texto.Size = UDim2.new(1, 0, 0, 60)
texto.BackgroundTransparency = 1
texto.Font = Enum.Font.Garamond
texto.TextSize = 48
texto.TextColor3 = Color3.fromRGB(240, 226, 192)
texto.TextStrokeColor3 = Color3.fromRGB(20, 16, 10)
texto.TextTransparency = 1
texto.TextStrokeTransparency = 1
texto.Parent = pantalla

local linea = Instance.new("Frame")
linea.AnchorPoint = Vector2.new(0.5, 0.5)
linea.Position = UDim2.new(0.5, 0, 0.3, 38)
linea.Size = UDim2.fromOffset(0, 1)
linea.BackgroundColor3 = Color3.fromRGB(220, 190, 120)
linea.BackgroundTransparency = 0.2
linea.BorderSizePixel = 0
linea.Parent = pantalla

local function mostrarCartel(nombre)
	texto.Text = nombre
	TweenService:Create(texto, TweenInfo.new(1.5), { TextTransparency = 0, TextStrokeTransparency = 0.5 }):Play()
	TweenService:Create(linea, TweenInfo.new(1.8, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(420, 1) }):Play()
	task.delay(4, function()
		if texto.Text == nombre then
			TweenService:Create(texto, TweenInfo.new(2), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			TweenService:Create(linea, TweenInfo.new(2), { Size = UDim2.fromOffset(0, 1) }):Play()
		end
	end)
end

-- ===== PARTÍCULAS EN EL AIRE (siguen al jugador) =====

local caja = Instance.new("Part")
caja.Name = "AmbienteParticulas"
caja.Anchored = true
caja.CanCollide = false
caja.CanQuery = false
caja.CanTouch = false
caja.Transparency = 1
caja.Size = Vector3.new(90, 26, 90)
caja.Parent = Workspace

local emisores = {}
local alturaEmisores = 0

local function crearEmisor(config)
	local emisor = Instance.new("ParticleEmitter")
	emisor.Name = config.nombre
	if config.humo then
		emisor.Texture = TEXTURA_HUMO
		emisor.Rotation = NumberRange.new(0, 360)
		emisor.RotSpeed = NumberRange.new(-5, 5)
	end
	emisor.Color = ColorSequence.new(config.color)
	emisor.LightEmission = config.brillo or 0
	emisor.LightInfluence = 1 - (config.brillo or 0)
	emisor.Rate = config.tasa
	emisor.Lifetime = NumberRange.new(config.vida * 0.7, config.vida)
	emisor.Speed = NumberRange.new(config.velocidad * 0.5, config.velocidad)
	emisor.SpreadAngle = Vector2.new(180, 180)
	emisor.Size = NumberSequence.new(config.tamano)
	emisor.Drag = 1
	emisor.WindAffectsDrag = config.conViento == true
	if config.caida then
		emisor.Acceleration = Vector3.new(0, -config.caida, 0)
	end
	local opaco = config.transparencia or 0
	if config.parpadeo then
		emisor.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, opaco),
			NumberSequenceKeypoint.new(0.35, 0.8),
			NumberSequenceKeypoint.new(0.5, opaco),
			NumberSequenceKeypoint.new(0.7, 0.8),
			NumberSequenceKeypoint.new(0.85, opaco),
			NumberSequenceKeypoint.new(1, 1),
		})
	else
		emisor.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, opaco),
			NumberSequenceKeypoint.new(0.8, opaco),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
	emisor.Parent = caja
	return emisor
end

local function cambiarParticulas(region)
	for _, emisor in emisores do
		emisor.Enabled = false
		task.delay(10, function()
			emisor:Destroy()
		end)
	end
	table.clear(emisores)
	alturaEmisores = 0
	for _, config in region.particulas or {} do
		table.insert(emisores, crearEmisor(config))
		if config.altura then
			alturaEmisores = config.altura
		end
	end
end

RunService.RenderStepped:Connect(function()
	local camara = Workspace.CurrentCamera
	if camara then
		caja.CFrame = CFrame.new(camara.CFrame.Position + Vector3.new(0, alturaEmisores, 0))
	end
end)

-- ===== CAMBIO DE REGIÓN =====

-- Ajusta el ambiente de la región según el clima (lluvia, niebla, tormenta de arena...)
local function ambienteConClima(region, nombreRegion)
	local clima = ClimaConfig.CLIMAS[Workspace:GetAttribute("Clima") or "Despejado"] or ClimaConfig.CLIMAS.Despejado
	local base = region.atmosfera
	local niebla = clima.niebla
	local oscuridad = clima.oscuridad
	local lluvia = clima.precipitacion

	-- Tormenta de arena: en el desierto, el viento fuerte llena el aire de polvo
	local arena = 0
	if nombreRegion == "Desierto" then
		arena = math.clamp((Workspace.GlobalWind.Magnitude - ClimaConfig.VIENTO_TORMENTA_ARENA * 0.6) / ClimaConfig.VIENTO_TORMENTA_ARENA, 0, 1)
		lluvia = 0
	end

	-- Hora del día: atardeceres rosados y noches moradas (toque de fantasía)
	local _, atardecer, noche = ClimaConfig.Momento(Lighting.ClockTime)

	local gris = Color3.fromRGB(150, 152, 156)
	-- Noche mágica: el horizonte brilla morado (más bruma de color lila)
	local densidad = math.clamp(base.Density + niebla * 0.35 + lluvia * 0.12 + arena * 0.3, 0, 0.9)
	local bruma = math.clamp(base.Haze + niebla * 3 + lluvia * 1.2 + arena * 3, 0, 10)
	local despejado = 1 - math.max(lluvia, niebla, oscuridad)
	local magia = noche * despejado
	local atmosfera = {
		Density = mezcla(densidad, math.max(densidad, 0.28), magia),
		Haze = mezcla(bruma, math.clamp(bruma, 1.2, 1.6), magia),
		Glare = (base.Glare + atardecer * 0.6) * (1 - math.max(oscuridad, arena)) * (1 - noche),
		Color = base.Color
			:Lerp(Color3.fromRGB(255, 196, 176), atardecer * 0.35)
			:Lerp(Color3.fromRGB(128, 96, 198), noche * 0.8)
			:Lerp(gris, math.max(lluvia, niebla) * 0.5)
			:Lerp(Color3.fromRGB(205, 170, 120), arena * 0.7),
		Decay = base.Decay
			:Lerp(Color3.fromRGB(236, 128, 140), atardecer * 0.45)
			:Lerp(Color3.fromRGB(78, 46, 140), noche * 0.85)
			:Lerp(Color3.fromRGB(70, 74, 80), oscuridad * 0.6),
	}
	local filtro = region.color
	local color = {
		TintColor = filtro.TintColor:Lerp(Color3.fromRGB(215, 225, 235), lluvia * 0.4),
		Saturation = filtro.Saturation - oscuridad * 0.25,
		Contrast = filtro.Contrast,
		Brightness = filtro.Brightness - oscuridad * 0.08,
	}
	return atmosfera, color
end

local function aplicarAmbiente(nombreRegion, mostrarNombre, duracion)
	local region = Regiones.REGIONES[nombreRegion]
	if not region then
		return
	end
	local transicion = TweenInfo.new(duracion or 4, Enum.EasingStyle.Sine)
	local objetivoAtmosfera, objetivoColor = ambienteConClima(region, nombreRegion)

	local atmosfera = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosfera then
		TweenService:Create(atmosfera, transicion, objetivoAtmosfera):Play()
	end
	local color = Lighting:FindFirstChild("ColorRegion")
	if color then
		TweenService:Create(color, transicion, objetivoColor):Play()
	end

	if not mostrarNombre then
		return
	end
	cambiarParticulas(region)
	local ahora = os.clock()
	if not ultimoCartel[nombreRegion] or ahora - ultimoCartel[nombreRegion] > ESPERA_CARTEL then
		ultimoCartel[nombreRegion] = ahora
		mostrarCartel(region.nombre)
	end
end

-- Cuando cambia el clima, el ambiente se ajusta poco a poco
Workspace:GetAttributeChangedSignal("Clima"):Connect(function()
	if regionActual then
		aplicarAmbiente(regionActual, false, ClimaConfig.TRANSICION)
	end
end)

-- La hora del día (y en el desierto, el viento) cambian el ambiente poco a poco:
-- lo recalculamos cada pocos segundos con una transición suave
task.spawn(function()
	while true do
		task.wait(6)
		if regionActual then
			aplicarAmbiente(regionActual, false, 6)
		end
	end
end)

while true do
	local personaje = jugador.Character
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if raiz then
		local nombreRegion = Regiones.RegionEn(raiz.Position)
		if nombreRegion ~= regionActual then
			regionActual = nombreRegion
			aplicarAmbiente(nombreRegion, true)
		end
	end
	task.wait(0.5)
end

-- Pantalla de CARGA: lo primero que ve el jugador al entrar, mientras el juego descarga.
-- Ruta en Studio: ReplicatedFirst/PantallaCarga
-- Al terminar se desvanece y deja paso a la pantalla de inicio (StarterPlayerScripts/InicioCliente).
-- Avisa con el atributo local "CargaLista" del jugador.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local jugador = Players.LocalPlayer
local guiJugador = jugador:WaitForChild("PlayerGui")

local ORO = Color3.fromRGB(228, 184, 96)
local KI = Color3.fromRGB(120, 210, 255)
local TEXTO = Color3.fromRGB(238, 228, 208)

local NOMBRE = "Reinos del Velo"
local CONSEJOS = { "Cargando el mundo..." }

local pantalla = Instance.new("ScreenGui")
pantalla.Name = "PantallaCarga"
pantalla.IgnoreGuiInset = true
pantalla.DisplayOrder = 100
pantalla.ResetOnSpawn = false
pantalla.Parent = guiJugador

local fondo = Instance.new("Frame")
fondo.Size = UDim2.fromScale(1, 1)
fondo.BackgroundColor3 = Color3.fromRGB(8, 9, 16)
fondo.BorderSizePixel = 0
fondo.Parent = pantalla
local degradado = Instance.new("UIGradient")
degradado.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 20, 40)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(8, 9, 16)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 8)),
})
degradado.Rotation = 90
degradado.Parent = fondo

-- Sello que gira en el centro (dos aros y unos rombos)
local centro = Instance.new("Frame")
centro.AnchorPoint = Vector2.new(0.5, 0.5)
centro.Position = UDim2.fromScale(0.5, 0.42)
centro.Size = UDim2.fromOffset(170, 170)
centro.BackgroundTransparency = 1
centro.Parent = fondo

local function aro(tamano, color, grosor, transparencia)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(tamano, tamano)
	f.BackgroundTransparency = 1
	f.Parent = centro
	local e = Instance.new("UICorner")
	e.CornerRadius = UDim.new(1, 0)
	e.Parent = f
	local b = Instance.new("UIStroke")
	b.Color = color
	b.Thickness = grosor
	b.Transparency = transparencia
	b.Parent = f
	return f
end
local aroExterior = aro(170, KI, 2, 0.35)
local aroInterior = aro(118, ORO, 1.5, 0.2)
local giratorio = Instance.new("Frame")
giratorio.AnchorPoint = Vector2.new(0.5, 0.5)
giratorio.Position = UDim2.fromScale(0.5, 0.5)
giratorio.Size = UDim2.fromOffset(170, 170)
giratorio.BackgroundTransparency = 1
giratorio.Parent = centro
for i = 1, 4 do
	local rombo = Instance.new("Frame")
	rombo.AnchorPoint = Vector2.new(0.5, 0.5)
	local angulo = (i - 1) * math.pi / 2
	rombo.Position = UDim2.new(0.5, math.cos(angulo) * 85, 0.5, math.sin(angulo) * 85)
	rombo.Size = UDim2.fromOffset(12, 12)
	rombo.Rotation = 45
	rombo.BackgroundColor3 = if i % 2 == 0 then ORO else KI
	rombo.BorderSizePixel = 0
	rombo.Parent = giratorio
end
aroExterior.Name = "AroExterior"

local titulo = Instance.new("TextLabel")
titulo.AnchorPoint = Vector2.new(0.5, 0)
titulo.Position = UDim2.new(0.5, 0, 0.42, 110)
titulo.Size = UDim2.fromOffset(700, 60)
titulo.BackgroundTransparency = 1
titulo.Font = Enum.Font.Garamond
titulo.TextSize = 52
titulo.TextColor3 = TEXTO
titulo.Text = NOMBRE
titulo.Parent = fondo
local gradTitulo = Instance.new("UIGradient")
gradTitulo.Color = ColorSequence.new(Color3.fromRGB(255, 240, 200), ORO)
gradTitulo.Rotation = 90
gradTitulo.Parent = titulo

-- Barra de progreso
local barra = Instance.new("Frame")
barra.AnchorPoint = Vector2.new(0.5, 0)
barra.Position = UDim2.new(0.5, 0, 0.42, 190)
barra.Size = UDim2.fromOffset(420, 4)
barra.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
barra.BorderSizePixel = 0
barra.Parent = fondo
local relleno = Instance.new("Frame")
relleno.Size = UDim2.fromScale(0, 1)
relleno.BackgroundColor3 = ORO
relleno.BorderSizePixel = 0
relleno.Parent = barra
local gradRelleno = Instance.new("UIGradient")
gradRelleno.Color = ColorSequence.new(KI, ORO)
gradRelleno.Parent = relleno

local estado = Instance.new("TextLabel")
estado.AnchorPoint = Vector2.new(0.5, 0)
estado.Position = UDim2.new(0.5, 0, 0.42, 202)
estado.Size = UDim2.fromOffset(420, 18)
estado.BackgroundTransparency = 1
estado.Font = Enum.Font.GothamMedium
estado.TextSize = 13
estado.TextColor3 = Color3.fromRGB(160, 150, 136)
estado.Text = "Cargando... 0 %"
estado.Parent = fondo

local consejo = Instance.new("TextLabel")
consejo.AnchorPoint = Vector2.new(0.5, 1)
consejo.Position = UDim2.new(0.5, 0, 1, -40)
consejo.Size = UDim2.new(0.8, 0, 0, 22)
consejo.BackgroundTransparency = 1
consejo.Font = Enum.Font.GothamMedium
consejo.TextSize = 15
consejo.TextColor3 = TEXTO
consejo.TextTransparency = 0.2
consejo.Text = ""
consejo.Parent = fondo

-- El nombre y los consejos están en ReplicatedStorage/Config/InicioConfig (si ya llegó)
task.spawn(function()
	local config = ReplicatedStorage:WaitForChild("Config", 8)
	local modulo = config and config:WaitForChild("InicioConfig", 8)
	if modulo then
		local ok, datos = pcall(require, modulo)
		if ok then
			NOMBRE = datos.NOMBRE_JUEGO or NOMBRE
			CONSEJOS = datos.CONSEJOS or CONSEJOS
			titulo.Text = NOMBRE
		end
	end
end)

-- Animación
local inicio = os.clock()
local progreso = 0
local conexion = RunService.RenderStepped:Connect(function(dt)
	giratorio.Rotation += dt * 40
	aroInterior.Rotation -= dt * 25
	local pulso = 0.5 + 0.5 * math.sin(os.clock() * 3)
	centro.Size = UDim2.fromOffset(170 + pulso * 6, 170 + pulso * 6)
	-- el progreso real: cosas que faltan por descargar + que el juego esté cargado
	local cola = ContentProvider.RequestQueueSize
	local objetivo = if game:IsLoaded()
		then (if cola == 0 then 1 else 0.9)
		else math.min(0.85, (os.clock() - inicio) / 6)
	progreso += (objetivo - progreso) * math.min(1, dt * 3)
	relleno.Size = UDim2.fromScale(progreso, 1)
	estado.Text = string.format("Cargando... %d %%", math.floor(progreso * 100))
end)

local indiceConsejo = 0
local function siguienteConsejo()
	indiceConsejo = indiceConsejo % #CONSEJOS + 1
	consejo.TextTransparency = 1
	consejo.Text = CONSEJOS[indiceConsejo]
	TweenService:Create(consejo, TweenInfo.new(0.5), { TextTransparency = 0.2 }):Play()
end
task.spawn(function()
	while pantalla.Parent do
		siguienteConsejo()
		task.wait(3.5)
	end
end)

-- Esperar a que todo esté listo (como mínimo 3 s para que se vea)
if not game:IsLoaded() then
	game.Loaded:Wait()
end
if not jugador.Character then
	jugador.CharacterAdded:Wait()
end
local limite = os.clock() + 20
while (ContentProvider.RequestQueueSize > 0 and os.clock() < limite) or os.clock() - inicio < 3 do
	task.wait(0.2)
end
progreso = 1
relleno.Size = UDim2.fromScale(1, 1)
estado.Text = "¡Listo!"
task.wait(0.4)

jugador:SetAttribute("CargaLista", true)
local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
TweenService:Create(fondo, info, { BackgroundTransparency = 1 }):Play()
for _, objeto in fondo:GetDescendants() do
	if objeto:IsA("TextLabel") then
		TweenService:Create(objeto, info, { TextTransparency = 1 }):Play()
	elseif objeto:IsA("Frame") then
		TweenService:Create(objeto, info, { BackgroundTransparency = 1 }):Play()
	elseif objeto:IsA("UIStroke") then
		TweenService:Create(objeto, info, { Transparency = 1 }):Play()
	end
end
task.wait(1)
conexion:Disconnect()
pantalla:Destroy()

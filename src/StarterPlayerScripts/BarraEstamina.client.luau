-- Dibuja la barra de estamina en pantalla.
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/BarraEstamina
-- Solo LEE el atributo "Estamina" que publica el servidor.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local jugador = Players.LocalPlayer

local COLOR_NORMAL = Color3.fromRGB(90, 200, 100)
local COLOR_BAJO = Color3.fromRGB(220, 170, 60)

local pantalla = Instance.new("ScreenGui")
pantalla.Name = "HUDEstamina"
pantalla.ResetOnSpawn = false
pantalla.Parent = jugador:WaitForChild("PlayerGui")

local fondo = Instance.new("Frame")
fondo.Name = "Fondo"
fondo.AnchorPoint = Vector2.new(0.5, 1)
fondo.Position = UDim2.new(0.5, 0, 1, -40)
fondo.Size = UDim2.fromOffset(300, 10)
fondo.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
fondo.BackgroundTransparency = 0.3
fondo.BorderSizePixel = 0
fondo.Parent = pantalla

local esquinasFondo = Instance.new("UICorner")
esquinasFondo.CornerRadius = UDim.new(0, 4)
esquinasFondo.Parent = fondo

local borde = Instance.new("UIStroke")
borde.Color = Color3.fromRGB(0, 0, 0)
borde.Thickness = 1.5
borde.Parent = fondo

local relleno = Instance.new("Frame")
relleno.Name = "Relleno"
relleno.Size = UDim2.fromScale(1, 1)
relleno.BackgroundColor3 = COLOR_NORMAL
relleno.BorderSizePixel = 0
relleno.Parent = fondo

local esquinasRelleno = Instance.new("UICorner")
esquinasRelleno.CornerRadius = UDim.new(0, 4)
esquinasRelleno.Parent = relleno

local function actualizar()
	local actual = jugador:GetAttribute("Estamina") or 0
	local maxima = jugador:GetAttribute("EstaminaMax") or 100
	local porcentaje = math.clamp(actual / maxima, 0, 1)

	TweenService:Create(relleno, TweenInfo.new(0.12), {
		Size = UDim2.fromScale(porcentaje, 1),
	}):Play()
	relleno.BackgroundColor3 = if porcentaje < 0.25 then COLOR_BAJO else COLOR_NORMAL
end

jugador:GetAttributeChangedSignal("Estamina"):Connect(actualizar)
jugador:GetAttributeChangedSignal("EstaminaMax"):Connect(actualizar)
actualizar()

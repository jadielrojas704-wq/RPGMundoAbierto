-- Generador del mundo abierto: 4 regiones + isla flotante.
-- Ruta en Studio: ServerStorage/Herramientas/GenerarMundo
--
-- NO se ejecuta solo al jugar. Se usa UNA vez desde la barra de comandos de Studio
-- (en modo edición, sin darle a Play), pulsando Ctrl+Enter:
--
--     require(game.ServerStorage.Herramientas.GenerarMundo).Generar()
--
-- Después hay que GUARDAR el lugar (File > Save) para que el mundo se quede.
-- Si lo vuelves a ejecutar, borra el mundo anterior y crea uno nuevo.
--
-- Las piezas están en ServerStorage/Herramientas/Mundo:
--   Terreno     -> alturas, materiales, agua e isla
--   Vegetacion  -> árboles, cactus, hongos, flores, rocas
--   Estructuras -> fogata, puentes, Altar del Ascenso, ruinas y nubes de la isla

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Regiones = require(ReplicatedStorage.Config.RegionesConfig)
local Mundo = script.Parent.Mundo
local Terreno = require(Mundo.Terreno)
local Vegetacion = require(Mundo.Vegetacion)
local Estructuras = require(Mundo.Estructuras)

local Materiales = require(script.Parent.Materiales)

local GenerarMundo = {}

-- Texturas realistas (PBR) para el terreno, sacadas de dos paquetes de la tienda:
--   10841357434 -> materiales oficiales de Roblox de su demo realista "Duvall Drive"
--   9408271791  -> paquete PBR (hierba, arena, pizarra)
-- escala = cada cuántos studs se repite la textura (más grande = menos repetición)
local MATERIALES_TERRENO = {
	{ id = 9408271791, nombre = "Grass_PBR", base = Enum.Material.Grass, escala = 10 },
	{ id = 9408271791, nombre = "Sand_PBR", base = Enum.Material.Sand, escala = 12 },
	{ id = 9408271791, nombre = "Slate_PBR", base = Enum.Material.Slate, escala = 14 },
	{ id = 9408271791, nombre = "Slate_PBR", base = Enum.Material.Rock, escala = 18 },
	{ id = 10841357434, nombre = "Mud MV", base = Enum.Material.Mud, escala = 10 },
	{ id = 10841357434, nombre = "Gravel MV", base = Enum.Material.Ground, escala = 10 },
}

local M = Enum.Material

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
	local punto = Regiones.INICIO
	local altura = Terreno.muestrear(punto.X, punto.Y).altura
	inicio.Anchored = true
	inicio.Size = Vector3.new(8, 1, 8)
	inicio.CFrame = CFrame.new(punto.X, altura + 0.1, punto.Y)
	inicio.Material = M.Slate
	inicio.Color = Color3.fromRGB(100, 96, 90)
	for _, hijo in inicio:GetChildren() do
		if hijo:IsA("Decal") then
			hijo:Destroy()
		end
	end
	return Vector3.new(punto.X, altura, punto.Y)
end

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

	-- Empieza con el ambiente del bosque; el cliente lo cambia al entrar en cada región
	local ambiente = Regiones.REGIONES.Bosque
	local atmosfera = Instance.new("Atmosphere")
	atmosfera.Offset = 0.2
	for propiedad, valor in ambiente.atmosfera do
		atmosfera[propiedad] = valor
	end
	atmosfera.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "ColorRegion"
	for propiedad, valor in ambiente.color do
		color[propiedad] = valor
	end
	color.Parent = Lighting

	local brillo = Instance.new("BloomEffect")
	brillo.Intensity = 0.55
	brillo.Size = 28
	brillo.Threshold = 1.4
	brillo.Parent = Lighting

	local rayos = Instance.new("SunRaysEffect")
	rayos.Intensity = 0.07
	rayos.Spread = 0.55
	rayos.Parent = Lighting

	local profundidad = Instance.new("DepthOfFieldEffect")
	profundidad.FarIntensity = 0.15
	profundidad.FocusDistance = 120
	profundidad.InFocusRadius = 120
	profundidad.NearIntensity = 0
	profundidad.Parent = Lighting

	local nubes = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	nubes.Cover = 0.6
	nubes.Density = 0.6
	nubes.Color = Color3.fromRGB(255, 240, 220)
	nubes.Parent = Workspace.Terrain

	-- Viento: mueve la hierba del terreno, las hojas que caen, el humo y la arena
	Workspace.GlobalWind = Vector3.new(9, 0, 4)
end

function GenerarMundo.Generar()
	local inicio = os.clock()
	print("[MUNDO] Generando el mundo... (tarda un par de minutos, no toques nada)")

	local anterior = Workspace:FindFirstChild("Mundo")
	if anterior then
		anterior:Destroy()
	end
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Mundo"

	print("[MUNDO] Terreno...")
	Terreno.Generar()
	print("[MUNDO] Isla flotante...")
	Terreno.GenerarIsla()

	Vegetacion.Generar(carpeta)

	print("[MUNDO] Estructuras...")
	local puntoInicio = colocarInicio()
	Estructuras.Fogata(puntoInicio + Vector3.new(10, 0, 0), carpeta)
	local puentes = Estructuras.Puentes(carpeta)
	Estructuras.Altar(carpeta)
	Estructuras.Isla(carpeta)

	carpeta.Parent = Workspace
	crearIluminacion()

	print("[MUNDO] Materiales realistas...")
	Materiales.Aplicar(MATERIALES_TERRENO)

	print(string.format("[MUNDO] %d puentes", puentes))
	print(string.format("[MUNDO] ¡Listo en %.0f segundos! Ahora guarda: File > Save", os.clock() - inicio))
end

return GenerarMundo

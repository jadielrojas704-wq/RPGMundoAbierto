-- Cielo de fantasía (cliente): colores de noche, luciérnagas, polvo de estrellas
-- y estrellas fugaces.
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/CieloCliente (LocalScript)
--
-- El SERVIDOR (ServerScriptService/Mundo/ClimaServicio) decide la hora y la luz
-- (sol, luna lavanda, nubes rosadas al atardecer y moradas de noche).
-- Este script solo añade efectos visuales en la pantalla de cada jugador:
--   * Filtro de color "ColorNoche": noche morada y mágica, atardecer cálido
--   * De noche: luciérnagas en los bosques y polvo de estrellas flotando
--   * De vez en cuando, una estrella fugaz cruza el cielo
-- Nada de esto afecta a la jugabilidad.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ClimaConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ClimaConfig"))
local Regiones = require(ReplicatedStorage.Config:WaitForChild("RegionesConfig"))

local jugador = Players.LocalPlayer
local rng = Random.new()
local TEXTURA_BRILLO = "rbxasset://textures/particles/sparkles_main.dds"

local function mezcla(a, b, t)
	return a + (b - a) * t
end

-- ===== FILTRO DE COLOR SEGÚN LA HORA =====
-- Va aparte del filtro de cada región (ColorRegion), así no se pisan.
local filtro = Lighting:FindFirstChild("ColorNoche") or Instance.new("ColorCorrectionEffect")
filtro.Name = "ColorNoche"
filtro.Parent = Lighting

local BLANCO = Color3.new(1, 1, 1)
local TINTE_ATARDECER = Color3.fromRGB(255, 228, 214)
local TINTE_NOCHE = Color3.fromRGB(215, 185, 255)

local function actualizarFiltro(dia, atardecer, noche, nublado)
	local tinte = BLANCO:Lerp(TINTE_ATARDECER, atardecer * 0.8):Lerp(TINTE_NOCHE, noche)
	filtro.TintColor = tinte:Lerp(BLANCO, nublado * 0.5)
	-- Colores algo más vivos de día y al atardecer; de noche, morados intensos
	filtro.Saturation = mezcla(0.04, mezcla(0.12, 0.16, noche), math.max(atardecer, noche)) * (1 - nublado * 0.6)
	filtro.Contrast = mezcla(0.02, 0.06, noche)
	-- un poco de brillo añadido: el negro del cielo se vuelve violeta muy oscuro
	filtro.Brightness = noche * 0.05 * (1 - dia)
end

-- ===== PARTÍCULAS DE NOCHE (alrededor de la cámara) =====
local caja = Instance.new("Part")
caja.Name = "CieloParticulas"
caja.Anchored = true
caja.CanCollide = false
caja.CanQuery = false
caja.CanTouch = false
caja.Transparency = 1
caja.Size = Vector3.new(110, 16, 110)
caja.Parent = Workspace

-- Luciérnagas: puntitos dorados-verdosos que parpadean cerca del suelo
local luciernagas = Instance.new("ParticleEmitter")
luciernagas.Name = "Luciernagas"
luciernagas.Texture = TEXTURA_BRILLO
luciernagas.Color = ColorSequence.new(Color3.fromRGB(214, 255, 140), Color3.fromRGB(255, 226, 120))
luciernagas.LightEmission = 1
luciernagas.LightInfluence = 0
luciernagas.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.15, 0.22),
	NumberSequenceKeypoint.new(0.5, 0.12),
	NumberSequenceKeypoint.new(0.85, 0.22),
	NumberSequenceKeypoint.new(1, 0),
})
luciernagas.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.2, 0),
	NumberSequenceKeypoint.new(0.4, 0.85),
	NumberSequenceKeypoint.new(0.6, 0),
	NumberSequenceKeypoint.new(0.8, 0.85),
	NumberSequenceKeypoint.new(1, 1),
})
luciernagas.Lifetime = NumberRange.new(6, 10)
luciernagas.Speed = NumberRange.new(0.5, 1.5)
luciernagas.SpreadAngle = Vector2.new(180, 180)
luciernagas.Drag = 1
luciernagas.Acceleration = Vector3.new(0, 0.15, 0)
luciernagas.Rate = 0
luciernagas.Parent = caja

-- Polvo de estrellas: motas lilas y blancas que flotan muy despacio (toque mágico)
local polvo = Instance.new("ParticleEmitter")
polvo.Name = "PolvoEstelar"
polvo.Texture = TEXTURA_BRILLO
polvo.Color = ColorSequence.new(Color3.fromRGB(220, 200, 255), Color3.fromRGB(170, 140, 255))
polvo.LightEmission = 1
polvo.LightInfluence = 0
polvo.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0.14),
	NumberSequenceKeypoint.new(1, 0),
})
polvo.Transparency = NumberSequence.new(0.35)
polvo.Lifetime = NumberRange.new(8, 14)
polvo.Speed = NumberRange.new(0.2, 0.6)
polvo.SpreadAngle = Vector2.new(180, 180)
polvo.Drag = 1
polvo.WindAffectsDrag = true
polvo.Acceleration = Vector3.new(0, 0.05, 0)
polvo.Rate = 0
polvo.Parent = caja

-- Cuántas luciérnagas hay en cada región (0 = ninguna)
local LUCIERNAGAS_REGION = { Bosque = 9, Oscuro = 14, Desierto = 0, Montana = 1, Isla = 6 }

-- ===== ESTRELLAS FUGACES =====
local function estrellaFugaz()
	local camara = Workspace.CurrentCamera
	if not camara then
		return
	end
	-- Aparece alto en el cielo, por delante de donde mira la cámara
	local mirada = camara.CFrame.LookVector * Vector3.new(1, 0, 1)
	if mirada.Magnitude < 0.1 then
		mirada = Vector3.new(0, 0, -1)
	end
	mirada = mirada.Unit
	local lado = mirada:Cross(Vector3.yAxis)
	local distancia = rng:NextNumber(380, 520)
	local inicio = camara.CFrame.Position
		+ mirada * distancia
		+ lado * rng:NextNumber(-260, 260)
		+ Vector3.new(0, rng:NextNumber(260, 380), 0)
	local direccion = (lado * (if rng:NextNumber() < 0.5 then 1 else -1) + Vector3.new(0, -0.35, 0)).Unit
	local largo = rng:NextNumber(160, 260)

	local punta = Instance.new("Part")
	punta.Name = "EstrellaFugaz"
	punta.Anchored = true
	punta.CanCollide = false
	punta.CanQuery = false
	punta.CanTouch = false
	punta.Transparency = 1
	punta.Size = Vector3.new(1, 1, 1)
	punta.CFrame = CFrame.new(inicio)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1.2, 0)
	a0.Parent = punta
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1.2, 0)
	a1.Parent = punta
	local estela = Instance.new("Trail")
	estela.Attachment0 = a0
	estela.Attachment1 = a1
	estela.FaceCamera = true
	estela.Lifetime = 0.45
	estela.LightEmission = 1
	estela.LightInfluence = 0
	estela.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 160, 255))
	estela.Transparency = NumberSequence.new(0, 1)
	estela.WidthScale = NumberSequence.new(1, 0)
	estela.Parent = punta
	punta.Parent = Workspace

	local duracion = rng:NextNumber(0.7, 1.1)
	local empiezo = os.clock()
	local conexion
	conexion = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - empiezo) / duracion
		if t >= 1 then
			conexion:Disconnect()
			task.delay(0.6, function()
				punta:Destroy()
			end)
			return
		end
		punta.CFrame = CFrame.new(inicio + direccion * largo * t)
	end)
end

-- ===== BUCLE =====
local regionActual = "Bosque"
local proximaFugaz = os.clock() + rng:NextNumber(15, 40)

RunService.RenderStepped:Connect(function()
	local camara = Workspace.CurrentCamera
	if camara then
		caja.CFrame = CFrame.new(camara.CFrame.Position + Vector3.new(0, 2, 0))
	end
end)

while true do
	local dia, atardecer, noche = ClimaConfig.Momento(Lighting.ClockTime)
	local clima = ClimaConfig.CLIMAS[Workspace:GetAttribute("Clima") or "Despejado"] or ClimaConfig.CLIMAS.Despejado
	local nublado = math.clamp(clima.oscuridad * 1.6 + clima.precipitacion * 0.5, 0, 1)
	actualizarFiltro(dia, atardecer, noche, nublado)

	local personaje = jugador.Character
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if raiz then
		regionActual = Regiones.RegionEn(raiz.Position)
	end

	-- Las luciérnagas y el polvo solo de noche, y menos con lluvia
	local despejado = 1 - math.clamp(clima.precipitacion * 1.5, 0, 1)
	luciernagas.Rate = (LUCIERNAGAS_REGION[regionActual] or 0) * noche * despejado
	polvo.Rate = 6 * noche * despejado

	-- Estrellas fugaces: solo de noche con el cielo despejado
	if os.clock() >= proximaFugaz then
		proximaFugaz = os.clock() + rng:NextNumber(20, 55)
		if noche > 0.8 and nublado < 0.3 then
			estrellaFugaz()
		end
	end

	task.wait(0.25)
end

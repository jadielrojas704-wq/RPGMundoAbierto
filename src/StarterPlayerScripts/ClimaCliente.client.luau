-- Dibuja el clima en tu pantalla: lluvia, nieve, tormenta de arena, relámpagos y sonidos.
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/ClimaCliente
-- El clima lo decide el servidor (ServerScriptService/Mundo/ClimaServicio); aquí solo
-- se leen el atributo "Clima" de Workspace y el viento (Workspace.GlobalWind).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ClimaConfig"))
local Regiones = require(ReplicatedStorage.Config:WaitForChild("RegionesConfig"))

local jugador = Players.LocalPlayer
local rng = Random.new()
local TEXTURA_HUMO = "rbxasset://textures/particles/smoke_main.dds"

-- Intensidad actual de cada efecto (sube y baja suavemente)
local precipitacion = 0
local regionActual = "Bosque"

-- ===== CAJA QUE SIGUE A LA CÁMARA (de aquí cae la lluvia) =====

local function cajaInvisible(nombre, tamano)
	local caja = Instance.new("Part")
	caja.Name = nombre
	caja.Anchored = true
	caja.CanCollide = false
	caja.CanQuery = false
	caja.CanTouch = false
	caja.Transparency = 1
	caja.Size = tamano
	caja.Parent = Workspace
	return caja
end

local cielo = cajaInvisible("ClimaCielo", Vector3.new(70, 2, 70)) -- encima de la cámara
local suelo = cajaInvisible("ClimaSuelo", Vector3.new(120, 14, 120)) -- a ras de suelo

-- Lluvia: partículas estiradas en la dirección en que caen.
-- Roblox limita cuántas partículas suelta un solo emisor, así que usamos varios.
local EMISORES_LLUVIA = 6
local GOTAS_POR_EMISOR = 360 -- por segundo con la lluvia al máximo
local emisoresLluvia = {}
for i = 1, EMISORES_LLUVIA do
	local lluvia = Instance.new("ParticleEmitter")
	lluvia.Name = "Lluvia" .. i
	lluvia.Color = ColorSequence.new(Color3.fromRGB(225, 232, 240))
	lluvia.LightInfluence = 0.6
	lluvia.LightEmission = 0.15
	lluvia.Transparency = NumberSequence.new(0.2)
	lluvia.Size = NumberSequence.new(0.18)
	lluvia.Squash = NumberSequence.new(-2.5) -- muy estirada: parece una gota cayendo
	lluvia.Orientation = Enum.ParticleOrientation.VelocityParallel
	lluvia.EmissionDirection = Enum.NormalId.Bottom
	lluvia.Speed = NumberRange.new(80, 95)
	lluvia.SpreadAngle = Vector2.new(3, 3)
	lluvia.Lifetime = NumberRange.new(0.75, 0.9)
	lluvia.Rate = 0
	lluvia.Parent = cielo
	table.insert(emisoresLluvia, lluvia)
end

-- Nieve en las montañas
local nieve = Instance.new("ParticleEmitter")
nieve.Name = "Nieve"
nieve.Color = ColorSequence.new(Color3.new(1, 1, 1))
nieve.LightInfluence = 1
nieve.Transparency = NumberSequence.new(0.15)
nieve.Size = NumberSequence.new(0.22)
nieve.EmissionDirection = Enum.NormalId.Bottom
nieve.Speed = NumberRange.new(5, 9)
nieve.SpreadAngle = Vector2.new(25, 25)
nieve.Lifetime = NumberRange.new(7, 9)
nieve.RotSpeed = NumberRange.new(-60, 60)
nieve.Drag = 0.6
nieve.WindAffectsDrag = true
nieve.Rate = 0
nieve.Parent = cielo

-- Tormenta de arena en el desierto
local arena = Instance.new("ParticleEmitter")
arena.Name = "TormentaArena"
arena.Texture = TEXTURA_HUMO
arena.Color = ColorSequence.new(Color3.fromRGB(212, 182, 132))
arena.LightInfluence = 1
arena.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.3, 0.7),
	NumberSequenceKeypoint.new(1, 1),
})
arena.Size = NumberSequence.new(6, 16)
arena.Speed = NumberRange.new(1, 3)
arena.Lifetime = NumberRange.new(3, 5)
arena.Rotation = NumberRange.new(0, 360)
arena.RotSpeed = NumberRange.new(-20, 20)
arena.Drag = 0.4
arena.WindAffectsDrag = true
arena.Rate = 0
arena.Parent = suelo

local granos = Instance.new("ParticleEmitter")
granos.Name = "GranosArena"
granos.Color = ColorSequence.new(Color3.fromRGB(205, 178, 128))
granos.LightInfluence = 1
granos.Size = NumberSequence.new(0.12)
granos.Squash = NumberSequence.new(-1.5)
granos.Orientation = Enum.ParticleOrientation.VelocityParallel
granos.Speed = NumberRange.new(1, 2)
granos.Lifetime = NumberRange.new(1.5, 2.5)
granos.Drag = 0.3
granos.WindAffectsDrag = true
granos.Rate = 0
granos.Parent = suelo

-- ===== SONIDOS DE AMBIENTE =====

local function sonidoBucle(id)
	local sonido = Instance.new("Sound")
	sonido.SoundId = id
	sonido.Looped = true
	sonido.Volume = 0
	sonido.Parent = SoundService
	sonido:Play()
	return sonido
end

local sonidoLluviaSuave = sonidoBucle(Config.SONIDOS.LLUVIA_SUAVE)
local sonidoLluviaFuerte = sonidoBucle(Config.SONIDOS.LLUVIA_FUERTE)

local function sonidoSuelto(id, volumen, velocidad)
	local sonido = Instance.new("Sound")
	sonido.SoundId = id
	sonido.Volume = volumen
	sonido.PlaybackSpeed = velocidad or 1
	sonido.Parent = SoundService
	sonido:Play()
	Debris:AddItem(sonido, 15)
end

local function elegir(lista)
	return lista[rng:NextInteger(1, #lista)]
end

-- ===== RELÁMPAGOS =====

local destello = Instance.new("ColorCorrectionEffect")
destello.Name = "Relampago"
destello.Parent = Lighting

local function rayo(posicion)
	-- Un rayo en zigzag de piezas brillantes que dura un instante
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Rayo"
	local punto = posicion + Vector3.new(0, 420, 0)
	local suelo2 = posicion
	local tramos = 9
	for i = 1, tramos do
		local siguiente = punto:Lerp(suelo2, 1 / (tramos - i + 1))
			+ Vector3.new(rng:NextNumber(-14, 14), 0, rng:NextNumber(-14, 14)) * (if i == tramos then 0 else 1)
		local largo = (siguiente - punto).Magnitude
		local tramo = Instance.new("Part")
		tramo.Anchored = true
		tramo.CanCollide = false
		tramo.CanQuery = false
		tramo.CanTouch = false
		tramo.CastShadow = false
		tramo.Material = Enum.Material.Neon
		tramo.Color = Color3.fromRGB(215, 225, 255)
		tramo.Size = Vector3.new(0.8, 0.8, largo)
		tramo.CFrame = CFrame.lookAt((punto + siguiente) / 2, siguiente)
		tramo.Parent = carpeta
		punto = siguiente
	end
	local luz = Instance.new("PointLight")
	luz.Brightness = 8
	luz.Range = 60
	luz.Color = Color3.fromRGB(200, 215, 255)
	luz.Parent = carpeta:FindFirstChildWhichIsA("BasePart")
	carpeta.Parent = Workspace
	Debris:AddItem(carpeta, 0.18)
end

local function relampago()
	local camara = Workspace.CurrentCamera
	if not camara then
		return
	end
	local distancia = rng:NextNumber(150, 900)
	local angulo = rng:NextNumber(0, math.pi * 2)
	local base = camara.CFrame.Position * Vector3.new(1, 0, 1)
	local posicion = base + Vector3.new(math.cos(angulo) * distancia, 0, math.sin(angulo) * distancia)

	-- Destello en pantalla (dos parpadeos, más fuerte si está cerca)
	local fuerza = math.clamp(1 - distancia / 1000, 0.15, 0.7)
	task.spawn(function()
		for _ = 1, rng:NextInteger(1, 2) do
			destello.Brightness = fuerza
			rayo(posicion)
			task.wait(0.07)
			destello.Brightness = 0
			task.wait(rng:NextNumber(0.05, 0.15))
		end
		TweenService:Create(destello, TweenInfo.new(0.3), { Brightness = 0 }):Play()
	end)

	-- El trueno llega después, como en la vida real (el sonido es más lento que la luz)
	task.delay(distancia / 900, function()
		if distancia < 380 then
			sonidoSuelto(elegir(Config.SONIDOS.TRUENO_CERCANO), 0.9, rng:NextNumber(0.9, 1.05))
		else
			sonidoSuelto(elegir(Config.SONIDOS.TRUENO_LEJANO), math.clamp(1.2 - distancia / 900, 0.3, 0.8), rng:NextNumber(0.85, 1))
		end
	end)
end

-- ===== CUÁNTO LLUEVE AHORA =====

local function datosClima(nombre)
	return Config.CLIMAS[nombre] or Config.CLIMAS.Despejado
end

-- Mezcla entre el clima anterior y el actual según el tiempo que pasó desde el cambio
local function estadoClima()
	local actual = datosClima(Workspace:GetAttribute("Clima"))
	local anterior = datosClima(Workspace:GetAttribute("ClimaAnterior"))
	local cambio = Workspace:GetAttribute("ClimaCambio") or 0
	local t = math.clamp((Workspace:GetServerTimeNow() - cambio) / Config.TRANSICION, 0, 1)
	local p = anterior.precipitacion + (actual.precipitacion - anterior.precipitacion) * t
	return p, actual
end

-- ===== BUCLE PRINCIPAL =====

local proximoRelampago = os.clock() + 8
local proximaRafaga = os.clock() + 6

RunService.RenderStepped:Connect(function(dt)
	local camara = Workspace.CurrentCamera
	if not camara then
		return
	end
	local posicion = camara.CFrame.Position
	local viento = Workspace.GlobalWind
	local fuerzaViento = viento.Magnitude

	-- La caja de lluvia va por delante de la cámara en la dirección del viento,
	-- para que las gotas inclinadas te caigan encima
	cielo.CFrame = CFrame.new(posicion + Vector3.new(0, 45, 0) - viento * 0.4)
	suelo.CFrame = CFrame.new(posicion + Vector3.new(0, -3, 0) - viento * 1.5)

	local objetivo, clima = estadoClima()
	-- Bajo techo o bajo el agua no llueve (rayo hacia arriba)
	local parametros = RaycastParams.new()
	parametros.FilterType = Enum.RaycastFilterType.Exclude
	parametros.FilterDescendantsInstances = { jugador.Character, cielo, suelo }
	local tapado = Workspace:Raycast(posicion, Vector3.new(0, 60, 0), parametros) ~= nil

	precipitacion += (objetivo - precipitacion) * math.min(1, dt * 0.5)

	local enMontana = regionActual == "Montana"
	local enDesierto = regionActual == "Desierto"
	local enIsla = regionActual == "Isla" -- la isla está por encima de las nubes

	local cantidadLluvia = if enMontana or enDesierto or enIsla or tapado then 0 else precipitacion
	local cantidadNieve = if enMontana and not tapado then math.max(precipitacion, 0.08) else 0
	local cantidadArena = 0
	if enDesierto then
		cantidadArena = math.clamp((fuerzaViento - Config.VIENTO_TORMENTA_ARENA * 0.6) / Config.VIENTO_TORMENTA_ARENA, 0, 1)
	end

	for _, lluvia in emisoresLluvia do
		lluvia.Rate = GOTAS_POR_EMISOR * cantidadLluvia
		lluvia.Acceleration = viento * 4 -- el viento inclina la lluvia
	end
	nieve.Rate = 220 * cantidadNieve
	arena.Rate = 22 * cantidadArena
	granos.Rate = 180 * cantidadArena
	granos.Acceleration = viento * 3

	-- Volumen de la lluvia (más bajo si estás a cubierto)
	local volumenLluvia = if enMontana or enDesierto or enIsla then 0 else precipitacion
	if tapado then
		volumenLluvia *= 0.4
	end
	sonidoLluviaSuave.Volume += (math.clamp(volumenLluvia * 1.6, 0, 0.55) - sonidoLluviaSuave.Volume) * math.min(1, dt)
	sonidoLluviaFuerte.Volume += (math.clamp((volumenLluvia - 0.5) * 1.6, 0, 0.7) - sonidoLluviaFuerte.Volume) * math.min(1, dt)

	local ahora = os.clock()
	-- Relámpagos durante las tormentas
	if clima.rayos and precipitacion > 0.5 and ahora >= proximoRelampago then
		relampago()
		proximoRelampago = ahora + rng:NextNumber(5, 18)
	end
	-- Ráfagas de viento que se oyen (más fuertes en montañas y desierto)
	if ahora >= proximaRafaga then
		proximaRafaga = ahora + rng:NextNumber(5, 14)
		local extra = if enMontana or enDesierto then 1.5 else 1
		local volumen = math.clamp((fuerzaViento - 5) / 20, 0, 0.6) * extra
		if volumen > 0.05 then
			sonidoSuelto(elegir(Config.SONIDOS.RAFAGA), volumen, rng:NextNumber(0.85, 1.1))
		end
	end
end)

-- La región la calculamos aquí también (cada medio segundo basta)
task.spawn(function()
	while true do
		local personaje = jugador.Character
		local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
		if raiz then
			regionActual = Regiones.RegionEn(raiz.Position)
		end
		task.wait(0.5)
	end
end)

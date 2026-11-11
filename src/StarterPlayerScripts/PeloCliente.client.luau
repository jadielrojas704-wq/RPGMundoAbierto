-- Física del pelo (cliente): el pelo de los NPC y de los jugadores se balancea de forma
-- natural al caminar, al girar la cabeza y con el viento.
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/PeloCliente (LocalScript)
--
-- Cómo funciona: el pelo es un accesorio pegado a la cabeza con una soldadura (Weld).
-- En cada fotograma giramos un poquito esa soldadura alrededor del punto donde el pelo
-- se une a la cabeza, como un muelle: se queda atrás cuando la cabeza acelera, rebota
-- suavemente y se inclina hacia donde sopla el viento. Solo es visual y solo en tu pantalla.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DISTANCIA = 60 -- solo se anima el pelo cercano (rendimiento)
local RIGIDEZ = 38 -- fuerza del muelle (más = vuelve antes a su sitio)
local AMORTIGUACION = 7 -- frena el rebote
local MAXIMO = 0.22 -- giro máximo en radianes (unos 12 grados)

-- pelos[weld] = { cabeza, c1Original, ax, az, vx, vz, posAnterior, velAnterior, fase, largo }
local pelos = {}

local function esPelo(accesorio)
	if accesorio.AccessoryType == Enum.AccessoryType.Hair then
		return true
	end
	local asa = accesorio:FindFirstChild("Handle")
	return asa ~= nil and asa:FindFirstChild("HairAttachment") ~= nil
end

local function registrar(accesorio)
	if not accesorio:IsA("Accessory") or not esPelo(accesorio) then
		return
	end
	local asa = accesorio:FindFirstChild("Handle")
	if not asa then
		return
	end
	local soldadura = asa:FindFirstChild("AccessoryWeld") or asa:FindFirstChildWhichIsA("Weld")
	if not soldadura or pelos[soldadura] then
		return
	end
	local cabeza = if soldadura.Part1 == asa then soldadura.Part0 else soldadura.Part1
	if not cabeza then
		return
	end
	pelos[soldadura] = {
		asa = asa,
		cabeza = cabeza,
		cabezaEsPart1 = soldadura.Part1 == cabeza,
		original = if soldadura.Part1 == cabeza then soldadura.C1 else soldadura.C0,
		ax = 0,
		az = 0,
		vx = 0,
		vz = 0,
		anterior = nil,
		velocidad = Vector3.zero,
		fase = math.random() * 100,
		-- el pelo largo se mueve más y más despacio que el corto
		largo = math.clamp(asa.Size.Y / 1.6, 0.6, 1.6),
	}
	soldadura.Destroying:Connect(function()
		pelos[soldadura] = nil
	end)
end

local function vigilarPersonaje(modelo)
	for _, hijo in modelo:GetChildren() do
		registrar(hijo)
	end
	modelo.ChildAdded:Connect(function(hijo)
		task.wait(0.1) -- la soldadura se crea un instante después
		registrar(hijo)
	end)
end

-- NPC de los pueblos
for _, npc in CollectionService:GetTagged("NPC") do
	vigilarPersonaje(npc)
end
CollectionService:GetInstanceAddedSignal("NPC"):Connect(vigilarPersonaje)

-- Jugadores
local function alJugador(jugador)
	if jugador.Character then
		vigilarPersonaje(jugador.Character)
	end
	jugador.CharacterAdded:Connect(vigilarPersonaje)
end
for _, jugador in Players:GetPlayers() do
	alJugador(jugador)
end
Players.PlayerAdded:Connect(alJugador)

RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 1 / 20)
	local camara = Workspace.CurrentCamera
	if not camara then
		return
	end
	local ojo = camara.CFrame.Position
	local viento = Workspace.GlobalWind
	local ahora = os.clock()
	for soldadura, p in pelos do
		local cabeza = p.cabeza
		if not cabeza.Parent or not soldadura.Parent then
			pelos[soldadura] = nil
			continue
		end
		local posicion = cabeza.Position
		if (posicion - ojo).Magnitude > DISTANCIA then
			p.anterior = nil
			continue
		end
		-- velocidad y aceleración de la cabeza (en el espacio de la cabeza)
		local velocidad = if p.anterior then (posicion - p.anterior) / dt else Vector3.zero
		p.anterior = posicion
		local aceleracion = (velocidad - p.velocidad) / dt
		p.velocidad = velocidad
		local local_ = cabeza.CFrame:VectorToObjectSpace(aceleracion)
		local vientoLocal = cabeza.CFrame:VectorToObjectSpace(viento)
		-- hacia dónde "quiere" ir el pelo: atrás al acelerar, a favor del viento, y un leve aleteo
		local aleteo = math.noise(ahora * 1.3, p.fase) * 0.04 * math.clamp(viento.Magnitude / 10, 0, 1.5)
		local objetivoX = math.clamp(-local_.Z * 0.004 + vientoLocal.Z * 0.006 + aleteo, -MAXIMO, MAXIMO) * p.largo
		local objetivoZ = math.clamp(local_.X * 0.004 - vientoLocal.X * 0.006 + aleteo * 0.6, -MAXIMO, MAXIMO) * p.largo
		-- muelle con amortiguación
		local rigidez = RIGIDEZ / p.largo
		p.vx += ((objetivoX - p.ax) * rigidez - p.vx * AMORTIGUACION) * dt
		p.vz += ((objetivoZ - p.az) * rigidez - p.vz * AMORTIGUACION) * dt
		p.ax = math.clamp(p.ax + p.vx * dt, -MAXIMO, MAXIMO)
		p.az = math.clamp(p.az + p.vz * dt, -MAXIMO, MAXIMO)
		-- girar alrededor del punto donde el pelo se une a la cabeza
		local giro = CFrame.Angles(p.ax, 0, p.az)
		if p.cabezaEsPart1 then
			soldadura.C1 = p.original * giro
		else
			soldadura.C0 = p.original * giro
		end
	end
end)

-- ===== CAPAS: se balancean hacia atrás al moverse y con el viento =====
-- La capa cuelga de una articulación (Motor6D "CapaMotor") en lo alto de la espalda;
-- aquí se gira su "Transform" en tu pantalla (no se envía al servidor).
local capas = {} -- [motor] = { raiz, angulo, velocidad, lado, fase }
local function registrarCapa(panel)
	local motor = panel:FindFirstChild("CapaMotor")
	if not motor or capas[motor] then
		return
	end
	local modelo = panel:FindFirstAncestorOfClass("Model")
	capas[motor] = {
		raiz = modelo and modelo:FindFirstChild("HumanoidRootPart"),
		torso = motor.Part0,
		angulo = 0.08,
		velocidad = 0,
		lado = 0,
		fase = math.random() * 100,
	}
	motor.Destroying:Connect(function()
		capas[motor] = nil
	end)
end
for _, panel in CollectionService:GetTagged("Capa") do
	registrarCapa(panel)
end
CollectionService:GetInstanceAddedSignal("Capa"):Connect(function(panel)
	task.defer(registrarCapa, panel)
end)

RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 1 / 20)
	local camara = Workspace.CurrentCamera
	if not camara then
		return
	end
	local ojo = camara.CFrame.Position
	local viento = Workspace.GlobalWind
	local ahora = os.clock()
	for motor, c in capas do
		local torso = c.torso
		if not motor.Parent or not torso or not torso.Parent then
			capas[motor] = nil
			continue
		end
		if (torso.Position - ojo).Magnitude > DISTANCIA then
			continue
		end
		-- velocidad del cuerpo vista desde el torso: al andar hacia delante, la capa se va atrás
		local vel = if c.raiz then c.raiz.AssemblyLinearVelocity else Vector3.zero
		local local_ = torso.CFrame:VectorToObjectSpace(vel + viento * 0.25)
		local adelante = -local_.Z -- positivo cuando avanza
		local objetivo = math.clamp(0.06 + adelante * 0.045 + math.max(0, -local_.Y) * 0.02, 0.02, 1.15)
		objetivo += math.noise(ahora * 1.6, c.fase) * 0.05 * (0.4 + math.clamp(adelante / 16, 0, 1))
		local objetivoLado = math.clamp(local_.X * 0.02, -0.3, 0.3)
		c.velocidad += ((objetivo - c.angulo) * 34 - c.velocidad * 6.5) * dt
		c.angulo = math.clamp(c.angulo + c.velocidad * dt, -0.1, 1.2)
		c.lado += (objetivoLado - c.lado) * math.min(1, dt * 6)
		-- gira hacia atrás (eje X) alrededor del borde de arriba
		motor.Transform = CFrame.Angles(-c.angulo, 0, c.lado)
	end
end)

-- ===== En primera persona no se ve tu propia cara flotando =====
RunService.RenderStepped:Connect(function()
	local personaje = Players.LocalPlayer.Character
	local cabeza = personaje and personaje:FindFirstChild("Head")
	local cara = cabeza and cabeza:FindFirstChild("Cara")
	if cara and cara:IsA("SurfaceGui") then
		local ver = cabeza.LocalTransparencyModifier < 0.5
		if cara.Enabled ~= ver then
			cara.Enabled = ver
		end
	end
end)

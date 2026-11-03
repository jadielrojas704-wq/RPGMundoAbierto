-- Lee la tecla de esquiva, decide el tipo de esquiva, mueve al personaje
-- y muestra la animación.
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/EsquivaCliente
-- Este script SOLO maneja input y efectos. La estamina y la invulnerabilidad
-- las decide el servidor (ServerScriptService/Combate/EsquivaServicio).
--
-- Tipos de esquiva (según hacia dónde caminas respecto a la cámara):
--   W o S + Q  -> Rodar (voltereta hacia donde caminas)
--   A o D + Q  -> Lateral (voltereta lateral acrobática, sigues mirando al frente)
--   Solo Q     -> PasoAtras (salto corto hacia atrás)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Config.CombateConfig).Esquiva
local EfectoRodar = require(ReplicatedStorage:WaitForChild("Efectos"):WaitForChild("EfectoRodar"))
local Remotos = ReplicatedStorage:WaitForChild("Remotes")
local RemotoEsquivar = Remotos:WaitForChild("Esquivar")
local RemotoEfecto = Remotos:WaitForChild("EfectoEsquiva")

local jugador = Players.LocalPlayer
local FOV_BASE = 70
local UMBRAL_LATERAL = 0.8 -- qué tan "de lado" tienes que moverte para la voltereta lateral

local ultimaEsquiva = 0
local esquivando = false

local function plano(vector)
	local v = Vector3.new(vector.X, 0, vector.Z)
	if v.Magnitude < 0.01 then
		return nil
	end
	return v.Unit
end

-- Pequeño "empujón" de la cámara, muy sutil
local function efectoCamara()
	local camara = Workspace.CurrentCamera
	if not camara then
		return
	end
	TweenService:Create(camara, TweenInfo.new(0.1), { FieldOfView = FOV_BASE + 3 }):Play()
	task.delay(0.15, function()
		TweenService:Create(camara, TweenInfo.new(0.3), { FieldOfView = FOV_BASE }):Play()
	end)
end

-- La cámara baja un poco con el cuerpo al rodar
local function bajarCamara(humanoide, duracion)
	TweenService:Create(humanoide, TweenInfo.new(duracion * 0.25, Enum.EasingStyle.Sine), {
		CameraOffset = Vector3.new(0, -0.7, 0),
	}):Play()
	task.delay(duracion * 0.6, function()
		TweenService:Create(humanoide, TweenInfo.new(duracion * 0.5, Enum.EasingStyle.Sine), {
			CameraOffset = Vector3.zero,
		}):Play()
	end)
end

-- Decide qué esquiva hacer y en qué dirección
local function elegirTipo(humanoide, raiz)
	local movimiento = plano(humanoide.MoveDirection)
	if not movimiento or humanoide.MoveDirection.Magnitude < 0.1 then
		return "PasoAtras", -raiz.CFrame.LookVector
	end
	local camara = Workspace.CurrentCamera
	local derechaCamara = camara and plano(camara.CFrame.RightVector)
	if derechaCamara and math.abs(movimiento:Dot(derechaCamara)) > UMBRAL_LATERAL then
		return "Lateral", movimiento
	end
	return "Rodar", movimiento
end

local function esquivar()
	if esquivando then
		return
	end
	if os.clock() - ultimaEsquiva < Config.ENFRIAMIENTO then
		return
	end
	-- Comprobación rápida en el cliente (el servidor vuelve a comprobarlo)
	if (jugador:GetAttribute("Estamina") or 0) < Config.COSTO_ESTAMINA then
		return
	end

	local personaje = jugador.Character
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if not humanoide or not raiz or humanoide.Health <= 0 then
		return
	end
	-- No se puede esquivar en el aire
	if humanoide.FloorMaterial == Enum.Material.Air then
		return
	end

	local tipo, direccion = elegirTipo(humanoide, raiz)
	local datos = Config.TIPOS[tipo]

	ultimaEsquiva = os.clock()
	esquivando = true

	-- En la lateral el personaje sigue mirando hacia donde mira la cámara
	local autoRotabaAntes = humanoide.AutoRotate
	if tipo == "Lateral" then
		local camara = Workspace.CurrentCamera
		local frente = camara and plano(camara.CFrame.LookVector)
		if frente then
			raiz.CFrame = CFrame.lookAt(raiz.Position, raiz.Position + frente)
		end
		humanoide.AutoRotate = false
	end

	RemotoEsquivar:FireServer(direccion, tipo)

	-- Impulso físico
	local adjunto = Instance.new("Attachment")
	adjunto.Parent = raiz

	local velocidad = Instance.new("LinearVelocity")
	velocidad.Attachment0 = adjunto
	velocidad.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	velocidad.LineDirection = direccion
	velocidad.LineVelocity = datos.VELOCIDAD
	velocidad.MaxForce = math.huge
	velocidad.RelativeTo = Enum.ActuatorRelativeTo.World
	velocidad.Parent = raiz

	EfectoRodar.Reproducir(personaje, direccion, tipo)
	efectoCamara()
	if tipo == "Rodar" then
		bajarCamara(humanoide, datos.DURACION)
	end

	-- Sale rápido y va frenando, como un cuerpo real
	local inicio = os.clock()
	local frenado
	frenado = RunService.Heartbeat:Connect(function()
		local t = math.clamp((os.clock() - inicio) / datos.DURACION, 0, 1)
		velocidad.LineVelocity = datos.VELOCIDAD * (1 - datos.FRENADO * t)
		if t >= 1 then
			frenado:Disconnect()
			velocidad:Destroy()
			adjunto:Destroy()
			if humanoide.Parent then
				humanoide.AutoRotate = autoRotabaAntes
			end
			esquivando = false
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, procesadoPorJuego)
	if procesadoPorJuego then
		return -- por ejemplo, si está escribiendo en el chat
	end
	if input.KeyCode == Config.TECLA or input.KeyCode == Config.BOTON_MANDO then
		esquivar()
	end
end)

-- Cuando OTRO jugador esquiva, el servidor nos avisa y vemos su animación
RemotoEfecto.OnClientEvent:Connect(function(personaje, direccion, tipo)
	if typeof(personaje) == "Instance" and typeof(direccion) == "Vector3" then
		EfectoRodar.Reproducir(personaje, direccion, tipo)
	end
end)

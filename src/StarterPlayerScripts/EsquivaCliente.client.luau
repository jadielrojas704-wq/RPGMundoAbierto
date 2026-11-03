-- Lee la tecla de esquiva, mueve al personaje y muestra la voltereta.
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/EsquivaCliente
-- Este script SOLO maneja input y efectos. La estamina y la invulnerabilidad
-- las decide el servidor (ServerScriptService/Combate/EsquivaServicio).

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

local ultimaEsquiva = 0
local esquivando = false

-- Pequeño "empujón" de la cámara para dar sensación de velocidad
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

	-- Dirección: hacia donde caminas, o voltereta hacia atrás si estás quieto
	local direccion = humanoide.MoveDirection
	if direccion.Magnitude < 0.1 then
		direccion = -raiz.CFrame.LookVector
	end
	direccion = Vector3.new(direccion.X, 0, direccion.Z).Unit

	ultimaEsquiva = os.clock()
	esquivando = true
	RemotoEsquivar:FireServer(direccion)

	-- Impulso físico durante la voltereta
	local adjunto = Instance.new("Attachment")
	adjunto.Parent = raiz

	local velocidad = Instance.new("LinearVelocity")
	velocidad.Attachment0 = adjunto
	velocidad.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	velocidad.LineDirection = direccion
	velocidad.LineVelocity = Config.VELOCIDAD
	velocidad.MaxForce = math.huge
	velocidad.RelativeTo = Enum.ActuatorRelativeTo.World
	velocidad.Parent = raiz

	EfectoRodar.Reproducir(personaje, direccion, Config.DURACION)
	efectoCamara()

	-- Sale rápido y va frenando, como un cuerpo real que rueda
	local inicio = os.clock()
	local frenado
	frenado = RunService.Heartbeat:Connect(function()
		local t = math.clamp((os.clock() - inicio) / Config.DURACION, 0, 1)
		velocidad.LineVelocity = Config.VELOCIDAD * (1 - Config.FRENADO * t)
		if t >= 1 then
			frenado:Disconnect()
			velocidad:Destroy()
			adjunto:Destroy()
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

-- Cuando OTRO jugador esquiva, el servidor nos avisa y vemos su voltereta
RemotoEfecto.OnClientEvent:Connect(function(personaje, direccion)
	if typeof(personaje) == "Instance" and typeof(direccion) == "Vector3" then
		EfectoRodar.Reproducir(personaje, direccion, Config.DURACION)
	end
end)

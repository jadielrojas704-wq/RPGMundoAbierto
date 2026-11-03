-- Lee la tecla de esquiva, mueve al personaje y muestra los efectos.
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/EsquivaCliente
-- Este script SOLO maneja input y efectos. La estamina y la invulnerabilidad
-- las decide el servidor (ServerScriptService/Combate/EsquivaServicio).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Config.CombateConfig).Esquiva
local RemotoEsquivar = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Esquivar")

local jugador = Players.LocalPlayer
local FOV_BASE = 70

local ultimaEsquiva = 0
local esquivando = false

-- Nube de polvo en los pies
local function efectoPolvo(raiz)
	local adjunto = Instance.new("Attachment")
	adjunto.Position = Vector3.new(0, -2.5, 0)
	adjunto.Parent = raiz

	local particulas = Instance.new("ParticleEmitter")
	particulas.Enabled = false
	particulas.Lifetime = NumberRange.new(0.3, 0.5)
	particulas.Speed = NumberRange.new(4, 8)
	particulas.SpreadAngle = Vector2.new(180, 20)
	particulas.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 2),
	})
	particulas.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	particulas.Color = ColorSequence.new(Color3.fromRGB(200, 190, 170))
	particulas.Parent = adjunto
	particulas:Emit(15)

	Debris:AddItem(adjunto, 1)
end

-- Pequeño "empujón" de la cámara para dar sensación de velocidad
local function efectoCamara()
	local camara = Workspace.CurrentCamera
	if not camara then
		return
	end
	TweenService:Create(camara, TweenInfo.new(0.1), { FieldOfView = FOV_BASE + 8 }):Play()
	task.delay(0.1, function()
		TweenService:Create(camara, TweenInfo.new(0.25), { FieldOfView = FOV_BASE }):Play()
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

	-- Dirección: hacia donde caminas, o paso atrás si estás quieto
	local direccion = humanoide.MoveDirection
	if direccion.Magnitude < 0.1 then
		direccion = -raiz.CFrame.LookVector
	end
	direccion = Vector3.new(direccion.X, 0, direccion.Z).Unit

	ultimaEsquiva = os.clock()
	esquivando = true
	RemotoEsquivar:FireServer()

	-- Impulso físico durante la esquiva
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

	efectoPolvo(raiz)
	efectoCamara()

	task.delay(Config.DURACION, function()
		velocidad:Destroy()
		adjunto:Destroy()
		esquivando = false
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

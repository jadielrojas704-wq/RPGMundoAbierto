-- Animación procedural de voltereta (hecha con código, sin archivos de animación).
-- Ruta en Studio: ReplicatedStorage/Efectos/EfectoRodar
-- Solo se usa en el CLIENTE: gira el cuerpo, encoge brazos y piernas,
-- y añade sonido, polvo y estela. No cambia nada del juego, solo lo visual.

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local EfectoRodar = {}

-- Sonidos que ya vienen dentro de Roblox
local SONIDO_GIRO = "rbxasset://sounds/swordlunge.wav"
local SONIDO_CAIDA = "rbxasset://sounds/action_jump_land.mp3"

local VUELTAS = 1 -- vueltas completas del cuerpo
local AGACHE = 1.3 -- cuánto baja el cuerpo en mitad del giro (studs)

-- Cuánto se doblan las articulaciones en el punto más encogido (solo R15)
local PLIEGUE = {
	LeftHip = CFrame.Angles(math.rad(80), 0, 0),
	RightHip = CFrame.Angles(math.rad(80), 0, 0),
	LeftKnee = CFrame.Angles(math.rad(-95), 0, 0),
	RightKnee = CFrame.Angles(math.rad(-95), 0, 0),
	LeftShoulder = CFrame.Angles(math.rad(60), 0, 0),
	RightShoulder = CFrame.Angles(math.rad(60), 0, 0),
}

local rodando = {} -- [personaje] = true mientras está rodando

-- Busca las articulaciones (Motor6D) del personaje, R15 o R6
local function buscarMotores(personaje)
	local motores = {}
	local torsoInferior = personaje:FindFirstChild("LowerTorso")
	if torsoInferior then
		motores.raiz = torsoInferior:FindFirstChild("Root")
		for nombre in PLIEGUE do
			local motor = personaje:FindFirstChild(nombre, true)
			if motor and motor:IsA("Motor6D") then
				motores[nombre] = motor
			end
		end
	else
		local raiz = personaje:FindFirstChild("HumanoidRootPart")
		motores.raiz = raiz and raiz:FindFirstChild("RootJoint")
	end
	return motores
end

local function reproducirSonido(parte, id, volumen)
	local sonido = Instance.new("Sound")
	sonido.SoundId = id
	sonido.Volume = volumen
	sonido.PlaybackSpeed = 0.95 + math.random() * 0.15
	sonido.RollOffMaxDistance = 80
	sonido.Parent = parte
	sonido:Play()
	Debris:AddItem(sonido, 2)
end

local function soltarPolvo(raiz, cantidad)
	local adjunto = Instance.new("Attachment")
	adjunto.Position = Vector3.new(0, -2.5, 0)
	adjunto.Parent = raiz

	local particulas = Instance.new("ParticleEmitter")
	particulas.Enabled = false
	particulas.Lifetime = NumberRange.new(0.35, 0.6)
	particulas.Speed = NumberRange.new(3, 7)
	particulas.SpreadAngle = Vector2.new(180, 15)
	particulas.Drag = 4
	particulas.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 2.2),
	})
	particulas.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	particulas.Color = ColorSequence.new(Color3.fromRGB(205, 195, 175))
	particulas.Parent = adjunto
	particulas:Emit(cantidad)

	Debris:AddItem(adjunto, 1)
end

-- Estela pegada al torso: como el torso gira, dibuja el arco de la voltereta
local function crearEstela(personaje, duracion)
	local torso = personaje:FindFirstChild("UpperTorso") or personaje:FindFirstChild("Torso")
	if not torso then
		return
	end
	local arriba = Instance.new("Attachment")
	arriba.Position = Vector3.new(0, 0.9, 0)
	arriba.Parent = torso
	local abajo = Instance.new("Attachment")
	abajo.Position = Vector3.new(0, -0.9, 0)
	abajo.Parent = torso

	local estela = Instance.new("Trail")
	estela.Attachment0 = arriba
	estela.Attachment1 = abajo
	estela.Lifetime = 0.18
	estela.LightEmission = 0.3
	estela.Color = ColorSequence.new(Color3.fromRGB(235, 235, 240))
	estela.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	estela.Parent = torso

	Debris:AddItem(estela, duracion + 0.3)
	Debris:AddItem(arriba, duracion + 0.3)
	Debris:AddItem(abajo, duracion + 0.3)
end

-- Reproduce la voltereta en cualquier personaje (el tuyo o el de otro jugador)
-- direccion: hacia dónde rueda, en coordenadas del mundo
function EfectoRodar.Reproducir(personaje, direccion, duracion)
	if rodando[personaje] then
		return
	end
	local raiz = personaje:FindFirstChild("HumanoidRootPart")
	if not raiz then
		return
	end
	local motores = buscarMotores(personaje)
	if not motores.raiz then
		return
	end
	rodando[personaje] = true

	-- Guardamos la posición original de cada articulación para restaurarla
	local originales = {}
	for nombre, motor in motores do
		originales[nombre] = motor.C0
	end

	-- Eje de giro: perpendicular a la dirección de la voltereta
	local direccionLocal = raiz.CFrame:VectorToObjectSpace(direccion)
	direccionLocal = Vector3.new(direccionLocal.X, 0, direccionLocal.Z)
	if direccionLocal.Magnitude < 0.01 then
		direccionLocal = Vector3.new(0, 0, -1)
	end
	local eje = Vector3.yAxis:Cross(direccionLocal.Unit)

	reproducirSonido(raiz, SONIDO_GIRO, 0.6)
	soltarPolvo(raiz, 12)
	crearEstela(personaje, duracion)

	local inicio = os.clock()
	local terminado = false
	local conexion

	local function terminar()
		if terminado then
			return
		end
		terminado = true
		conexion:Disconnect()
		for nombre, motor in motores do
			if motor.Parent then
				motor.C0 = originales[nombre]
			end
		end
		rodando[personaje] = nil
		if raiz.Parent then
			reproducirSonido(raiz, SONIDO_CAIDA, 0.5)
			soltarPolvo(raiz, 8)
		end
	end

	conexion = RunService.RenderStepped:Connect(function()
		if not personaje.Parent or not raiz.Parent then
			terminar()
			return
		end
		local t = math.clamp((os.clock() - inicio) / duracion, 0, 1)
		local suave = t * t * (3 - 2 * t) -- empieza y termina suave
		local angulo = suave * math.pi * 2 * VUELTAS
		local encogido = math.sin(t * math.pi) -- 0 -> 1 -> 0

		motores.raiz.C0 = CFrame.new(0, -AGACHE * encogido, 0)
			* CFrame.fromAxisAngle(eje, angulo)
			* originales.raiz

		for nombre, pliegue in PLIEGUE do
			local motor = motores[nombre]
			if motor then
				motor.C0 = originales[nombre] * CFrame.identity:Lerp(pliegue, encogido)
			end
		end

		if t >= 1 then
			terminar()
		end
	end)
end

return EfectoRodar

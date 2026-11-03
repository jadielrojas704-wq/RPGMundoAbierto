-- Animación procedural de voltereta estilo Elden Ring (hecha con código).
-- Ruta en Studio: ReplicatedStorage/Efectos/EfectoRodar
-- Solo se usa en el CLIENTE. No cambia nada del juego, solo lo visual.
--
-- Fases de la voltereta (t va de 0 a 1):
--   0.00 - 0.20  Lanzarse: el cuerpo baja y se encoge
--   0.08 - 0.72  Rodar: giro completo sobre un hombro, cuerpo pegado al suelo
--   0.70 - 1.00  Levantarse: se estira y recupera la postura
--
-- Funciona con los dos tipos de articulaciones de Roblox:
--   * Motor6D (personajes clásicos): se mueve su propiedad C0
--   * AnimationConstraint (personajes nuevos): se mueve su Attachment0

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sonidos = require(ReplicatedStorage.Config.SonidosConfig).Esquiva

local EfectoRodar = {}

local AGACHE = 1.6 -- cuánto baja el cuerpo al rodar (studs)
local INCLINACION_HOMBRO = math.rad(25) -- rodar sobre un hombro, no recto

-- Postura más encogida (solo personajes R15). Ángulos en grados.
local PLIEGUE = {
	LeftHip = CFrame.Angles(math.rad(100), 0, 0),
	RightHip = CFrame.Angles(math.rad(100), 0, 0),
	LeftKnee = CFrame.Angles(math.rad(-120), 0, 0),
	RightKnee = CFrame.Angles(math.rad(-120), 0, 0),
	LeftShoulder = CFrame.Angles(math.rad(70), 0, math.rad(-15)),
	RightShoulder = CFrame.Angles(math.rad(70), 0, math.rad(15)),
	LeftElbow = CFrame.Angles(math.rad(80), 0, 0),
	RightElbow = CFrame.Angles(math.rad(80), 0, 0),
	Waist = CFrame.Angles(math.rad(-30), 0, 0), -- espalda curvada
	Neck = CFrame.Angles(math.rad(-35), 0, 0), -- barbilla al pecho
}

local rodando = {} -- [personaje] = true mientras está rodando
local tipoAvisado = false

-- Transición suave de 0 a 1 entre los momentos a y b
local function suave(a, b, t)
	local x = math.clamp((t - a) / (b - a), 0, 1)
	return x * x * (3 - 2 * x)
end

-- Convierte una articulación (de cualquier tipo) en algo que podemos mover
local function prepararArticulacion(objeto)
	if not objeto then
		return nil
	end
	if objeto:IsA("Motor6D") then
		return {
			tipo = "Motor6D",
			original = objeto.C0,
			poner = function(cf)
				objeto.C0 = cf
			end,
		}
	elseif objeto:IsA("AnimationConstraint") and objeto.Attachment0 then
		local adjunto = objeto.Attachment0
		return {
			tipo = "AnimationConstraint",
			original = adjunto.CFrame,
			poner = function(cf)
				adjunto.CFrame = cf
			end,
		}
	end
	return nil
end

local function buscarArticulaciones(personaje)
	local articulaciones = {}
	local esR15 = personaje:FindFirstChild("LowerTorso") ~= nil
	local nombreRaiz = if esR15 then "Root" else "RootJoint"

	articulaciones.raiz = prepararArticulacion(personaje:FindFirstChild(nombreRaiz, true))
	if esR15 then
		for nombre in PLIEGUE do
			articulaciones[nombre] = prepararArticulacion(personaje:FindFirstChild(nombre, true))
		end
	end
	return articulaciones
end

local function elegir(lista)
	if typeof(lista) == "table" then
		return lista[math.random(1, #lista)]
	end
	return lista
end

local function reproducirSonido(parte, id, volumen)
	if not id then
		return
	end
	local sonido = Instance.new("Sound")
	sonido.SoundId = id
	sonido.Volume = volumen
	sonido.PlaybackSpeed = 0.95 + math.random() * 0.1
	sonido.RollOffMinDistance = 5
	sonido.RollOffMaxDistance = 60
	sonido.Parent = parte
	sonido:Play()
	Debris:AddItem(sonido, 3)
end

-- Polvo discreto pegado al suelo
local function soltarPolvo(raiz, cantidad)
	local adjunto = Instance.new("Attachment")
	adjunto.Position = Vector3.new(0, -2.8, 0)
	adjunto.Parent = raiz

	local particulas = Instance.new("ParticleEmitter")
	particulas.Enabled = false
	particulas.Lifetime = NumberRange.new(0.5, 0.9)
	particulas.Speed = NumberRange.new(1.5, 3.5)
	particulas.SpreadAngle = Vector2.new(180, 5)
	particulas.Acceleration = Vector3.new(0, 0.5, 0)
	particulas.Drag = 3
	particulas.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1.8),
	})
	particulas.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	particulas.Color = ColorSequence.new(Color3.fromRGB(150, 140, 125))
	particulas.Parent = adjunto
	particulas:Emit(cantidad)

	Debris:AddItem(adjunto, 1.2)
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
	local articulaciones = buscarArticulaciones(personaje)
	if not articulaciones.raiz then
		warn("[VOLTERETA] No encontré la articulación principal del personaje")
		return
	end
	if not tipoAvisado then
		tipoAvisado = true
		print("[VOLTERETA] Tipo de articulaciones:", articulaciones.raiz.tipo)
	end
	rodando[personaje] = true

	-- Dirección de la voltereta vista desde el propio personaje
	local direccionLocal = raiz.CFrame:VectorToObjectSpace(direccion)
	direccionLocal = Vector3.new(direccionLocal.X, 0, direccionLocal.Z)
	if direccionLocal.Magnitude < 0.01 then
		direccionLocal = Vector3.new(0, 0, -1)
	end
	direccionLocal = direccionLocal.Unit

	-- Eje de giro: de lado a lado, inclinado para rodar sobre un hombro
	local ejeRecto = Vector3.yAxis:Cross(direccionLocal)
	local lado = if math.random() < 0.5 then 1 else -1
	local eje = CFrame.fromAxisAngle(direccionLocal, INCLINACION_HOMBRO * lado):VectorToWorldSpace(ejeRecto)

	reproducirSonido(raiz, elegir(Sonidos.ROPA), Sonidos.VOLUMEN_ROPA)
	soltarPolvo(raiz, 5)

	local inicio = os.clock()
	local terminado = false
	local tocoSuelo = false
	local conexion

	local function terminar()
		if terminado then
			return
		end
		terminado = true
		conexion:Disconnect()
		for _, articulacion in articulaciones do
			pcall(articulacion.poner, articulacion.original)
		end
		rodando[personaje] = nil
		if raiz.Parent and math.random() < Sonidos.PROBABILIDAD_RESPIRACION then
			reproducirSonido(raiz, elegir(Sonidos.RESPIRACION), Sonidos.VOLUMEN_RESPIRACION)
		end
	end

	conexion = RunService.RenderStepped:Connect(function()
		if not personaje.Parent or not raiz.Parent then
			terminar()
			return
		end
		local t = math.clamp((os.clock() - inicio) / duracion, 0, 1)

		local giro = suave(0.08, 0.72, t) * math.pi * 2
		local bajada = AGACHE * (suave(0, 0.2, t) - suave(0.7, 1, t))
		local encogido = suave(0.05, 0.25, t) - suave(0.62, 0.9, t)

		-- Cuando la espalda vuelve a apoyarse: golpe sordo y algo de polvo
		if not tocoSuelo and t >= 0.66 then
			tocoSuelo = true
			reproducirSonido(raiz, Sonidos.CAIDA, Sonidos.VOLUMEN_CAIDA)
			soltarPolvo(raiz, 6)
		end

		local ok, err = pcall(function()
			local raizArt = articulaciones.raiz
			raizArt.poner(CFrame.new(0, -bajada, 0) * CFrame.fromAxisAngle(eje, giro) * raizArt.original)

			for nombre, pliegue in PLIEGUE do
				local articulacion = articulaciones[nombre]
				if articulacion then
					articulacion.poner(articulacion.original * CFrame.identity:Lerp(pliegue, encogido))
				end
			end
		end)
		if not ok then
			warn("[VOLTERETA] Error:", err)
			terminar()
			return
		end

		if t >= 1 then
			terminar()
		end
	end)
end

return EfectoRodar

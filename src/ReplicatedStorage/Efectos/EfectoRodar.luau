-- Animación procedural de voltereta (hecha con código, sin archivos de animación).
-- Ruta en Studio: ReplicatedStorage/Efectos/EfectoRodar
-- Solo se usa en el CLIENTE: gira el cuerpo, lo agacha, encoge brazos y piernas,
-- y añade voz, polvo y estela. No cambia nada del juego, solo lo visual.
--
-- Funciona con los dos tipos de articulaciones de Roblox:
--   * Motor6D (personajes clásicos): se mueve su propiedad C0
--   * AnimationConstraint (personajes nuevos): se mueve su Attachment0
-- En ambos casos, "C0" y "Attachment0" significan lo mismo: dónde se une la pieza.

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sonidos = require(ReplicatedStorage.Config.SonidosConfig).Esquiva

local EfectoRodar = {}

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
local tipoAvisado = false

-- Convierte una articulación (de cualquier tipo) en algo que podemos mover
local function prepararArticulacion(objeto)
	if not objeto then
		return nil
	end
	if objeto:IsA("Motor6D") then
		local original = objeto.C0
		return {
			tipo = "Motor6D",
			original = original,
			poner = function(cf)
				objeto.C0 = cf
			end,
		}
	elseif objeto:IsA("AnimationConstraint") and objeto.Attachment0 then
		local adjunto = objeto.Attachment0
		local original = adjunto.CFrame
		return {
			tipo = "AnimationConstraint",
			original = original,
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
	sonido.RollOffMaxDistance = 80
	sonido.Parent = parte
	sonido:Play()
	Debris:AddItem(sonido, 3)
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

	-- Eje de giro: perpendicular a la dirección de la voltereta
	local direccionLocal = raiz.CFrame:VectorToObjectSpace(direccion)
	direccionLocal = Vector3.new(direccionLocal.X, 0, direccionLocal.Z)
	if direccionLocal.Magnitude < 0.01 then
		direccionLocal = Vector3.new(0, 0, -1)
	end
	local eje = Vector3.yAxis:Cross(direccionLocal.Unit)

	reproducirSonido(raiz, elegir(Sonidos.IMPULSO), Sonidos.VOLUMEN_VOZ)
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
		-- Devolver cada articulación a su posición original
		for _, articulacion in articulaciones do
			pcall(articulacion.poner, articulacion.original)
		end
		rodando[personaje] = nil
		if raiz.Parent then
			reproducirSonido(raiz, Sonidos.CAIDA, Sonidos.VOLUMEN_CAIDA)
			reproducirSonido(raiz, elegir(Sonidos.ACOMODARSE), Sonidos.VOLUMEN_VOZ * 0.8)
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

		local ok, err = pcall(function()
			local raizArt = articulaciones.raiz
			raizArt.poner(CFrame.new(0, -AGACHE * encogido, 0) * CFrame.fromAxisAngle(eje, angulo) * raizArt.original)

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

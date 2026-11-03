-- Animaciones procedurales de esquiva estilo Elden Ring (hechas con código).
-- Ruta en Studio: ReplicatedStorage/Efectos/EfectoRodar
-- Solo se usa en el CLIENTE. No cambia nada del juego, solo lo visual.
--
-- Tres tipos de esquiva (t va de 0 a 1 durante la esquiva):
--   Rodar     -> manos al suelo, giro sobre un hombro, levantarse inclinado
--   Lateral   -> impulso, voltereta lateral en el aire en forma de estrella, aterrizaje
--   PasoAtras -> salto corto hacia atrás con el cuerpo inclinado hacia delante
--
-- Funciona con los dos tipos de articulaciones de Roblox:
--   * Motor6D (personajes clásicos): se mueve su propiedad C0
--   * AnimationConstraint (personajes nuevos): se mueve su Attachment0

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sonidos = require(ReplicatedStorage.Config.SonidosConfig).Esquiva
local Tipos = require(ReplicatedStorage.Config.CombateConfig).Esquiva.TIPOS

local EfectoRodar = {}

local INCLINACION_HOMBRO = math.rad(25) -- la voltereta va sobre un hombro, no recta

local function grados(x, y, z)
	return CFrame.Angles(math.rad(x), math.rad(y or 0), math.rad(z or 0))
end

-- ===== POSTURAS (cuánto gira cada articulación en su punto máximo) =====

-- Cuerpo hecho bolita para rodar
local ENCOGIDO = {
	LeftHip = grados(100),
	RightHip = grados(100),
	LeftKnee = grados(-120),
	RightKnee = grados(-120),
	LeftShoulder = grados(70, 0, -15),
	RightShoulder = grados(70, 0, 15),
	LeftElbow = grados(80),
	RightElbow = grados(80),
	Waist = grados(-30), -- espalda curvada
	Neck = grados(-35), -- barbilla al pecho
}

-- Brazos estirados hacia delante para apoyar las manos al empezar a rodar
local ALCANCE = {
	LeftShoulder = grados(120, 0, -10),
	RightShoulder = grados(120, 0, 10),
	LeftElbow = grados(15),
	RightElbow = grados(15),
}

-- Forma de estrella para la voltereta lateral
local ESTRELLA = {
	LeftShoulder = grados(0, 0, -110),
	RightShoulder = grados(0, 0, 110),
	LeftElbow = grados(10),
	RightElbow = grados(10),
	LeftHip = grados(0, 0, -35),
	RightHip = grados(0, 0, 35),
}

-- Piernas flexionadas para tomar impulso o amortiguar la caída
local FLEXION = {
	LeftHip = grados(50),
	RightHip = grados(50),
	LeftKnee = grados(-80),
	RightKnee = grados(-80),
	Waist = grados(-15),
}

-- Brazos adelantados para equilibrarse en el salto hacia atrás
local EQUILIBRIO = {
	LeftShoulder = grados(35),
	RightShoulder = grados(35),
	LeftElbow = grados(30),
	RightElbow = grados(30),
}

local NOMBRES_ARTICULACIONES = {
	"LeftHip", "RightHip", "LeftKnee", "RightKnee",
	"LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow",
	"Waist", "Neck",
}

-- ===== AYUDANTES =====

-- Transición suave de 0 a 1 entre los momentos a y b
local function suave(a, b, t)
	local x = math.clamp((t - a) / (b - a), 0, 1)
	return x * x * (3 - 2 * x)
end

-- Sube de 0 a 1 entre a y b, se mantiene, y baja a 0 entre c y d
local function curva(a, b, c, d, t)
	return suave(a, b, t) - suave(c, d, t)
end

-- Mezcla varias posturas con su peso: combinar({POSTURA, peso}, {POSTURA, peso}, ...)
local function combinar(...)
	local resultado = {}
	for _, par in { ... } do
		local postura, peso = par[1], par[2]
		if peso > 0 then
			for nombre, giro in postura do
				resultado[nombre] = (resultado[nombre] or CFrame.identity) * CFrame.identity:Lerp(giro, peso)
			end
		end
	end
	return resultado
end

-- ===== ANIMACIONES =====
-- Cada una recibe t (0 a 1) y devuelve: movimiento del cuerpo, giro de articulaciones

local Animaciones = {}

function Animaciones.Rodar(t, ejes)
	local alcance = curva(0, 0.1, 0.15, 0.3, t)
	local encogido = curva(0.05, 0.25, 0.62, 0.9, t)
	local bajada = 1.6 * curva(0, 0.2, 0.7, 1, t)
	-- Giro completo + al final se levanta un poco inclinado hacia delante
	local giro = suave(0.08, 0.72, t) * math.pi * 2 + math.rad(15) * curva(0.7, 0.82, 0.85, 1, t)

	local cuerpo = CFrame.new(0, -bajada, 0) * CFrame.fromAxisAngle(ejes.hombro, giro)
	return cuerpo, combinar({ ENCOGIDO, encogido }, { ALCANCE, alcance })
end

function Animaciones.Lateral(t, ejes)
	local impulso = curva(0, 0.12, 0.14, 0.26, t)
	local vuelo = curva(0.12, 0.4, 0.5, 0.8, t)
	local aterrizaje = curva(0.72, 0.82, 0.84, 1, t)
	local estrella = curva(0.15, 0.3, 0.62, 0.78, t)
	local giro = suave(0.14, 0.76, t) * math.pi * 2

	local altura = 1.5 * vuelo - 0.8 * impulso - 0.9 * aterrizaje
	local cuerpo = CFrame.new(0, altura, 0) * CFrame.fromAxisAngle(ejes.recto, giro)
	return cuerpo, combinar({ ESTRELLA, estrella }, { FLEXION, math.max(impulso, aterrizaje) })
end

function Animaciones.PasoAtras(t, ejes)
	local salto = math.sin(math.pi * suave(0.05, 0.75, t))
	local impulso = curva(0, 0.08, 0.1, 0.2, t)
	local aterrizaje = curva(0.7, 0.8, 0.82, 1, t)
	local inclinacion = math.rad(14) * curva(0, 0.15, 0.75, 1, t)

	local altura = 0.5 * salto - 0.6 * math.max(impulso, aterrizaje)
	-- Ángulo negativo: el cuerpo se inclina hacia delante mientras salta hacia atrás
	local cuerpo = CFrame.new(0, altura, 0) * CFrame.fromAxisAngle(ejes.recto, -inclinacion)
	return cuerpo, combinar({ EQUILIBRIO, salto }, { FLEXION, math.max(impulso, aterrizaje) * 0.8 })
end

-- Momentos en los que suena algo o sale polvo: { t, sonido, volumen relativo, polvo }
local EVENTOS = {
	Rodar = {
		{ 0, "ROPA", 1, 5 },
		{ 0.66, "CAIDA", 1, 6 },
	},
	Lateral = {
		{ 0.05, "ROPA", 0.6, 4 },
		{ 0.8, "CAIDA", 1.3, 7 },
	},
	PasoAtras = {
		{ 0, "ROPA", 0.5, 0 },
		{ 0.78, "CAIDA", 1.1, 4 },
	},
}

local RESPIRA_AL_FINAL = { Rodar = true, Lateral = true, PasoAtras = false }

-- ===== ARTICULACIONES =====

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
	local esR15 = personaje:FindFirstChild("LowerTorso") ~= nil
	local nombreRaiz = if esR15 then "Root" else "RootJoint"

	local raiz = prepararArticulacion(personaje:FindFirstChild(nombreRaiz, true))
	local resto = {}
	if esR15 then
		for _, nombre in NOMBRES_ARTICULACIONES do
			resto[nombre] = prepararArticulacion(personaje:FindFirstChild(nombre, true))
		end
	end
	return raiz, resto
end

-- ===== SONIDO Y POLVO =====

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

local function soltarPolvo(raiz, cantidad)
	if cantidad <= 0 then
		return
	end
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

local function volumenDe(nombreSonido)
	if nombreSonido == "ROPA" then
		return Sonidos.VOLUMEN_ROPA
	elseif nombreSonido == "CAIDA" then
		return Sonidos.VOLUMEN_CAIDA
	end
	return Sonidos.VOLUMEN_RESPIRACION
end

-- ===== REPRODUCIR =====

local rodando = {} -- [personaje] = true mientras está esquivando
local tipoAvisado = false

-- Reproduce la esquiva en cualquier personaje (el tuyo o el de otro jugador)
-- direccion: hacia dónde va, en coordenadas del mundo
-- tipo: "Rodar", "Lateral" o "PasoAtras"
function EfectoRodar.Reproducir(personaje, direccion, tipo)
	tipo = if Animaciones[tipo] then tipo else "Rodar"
	if rodando[personaje] then
		return
	end
	local raiz = personaje:FindFirstChild("HumanoidRootPart")
	if not raiz then
		return
	end
	local raizArt, articulaciones = buscarArticulaciones(personaje)
	if not raizArt then
		warn("[VOLTERETA] No encontré la articulación principal del personaje")
		return
	end
	if not tipoAvisado then
		tipoAvisado = true
		print("[VOLTERETA] Tipo de articulaciones:", raizArt.tipo)
	end
	rodando[personaje] = true

	local duracion = Tipos[tipo].DURACION
	local animar = Animaciones[tipo]
	local eventos = EVENTOS[tipo]

	-- Dirección vista desde el propio personaje
	local direccionLocal = raiz.CFrame:VectorToObjectSpace(direccion)
	direccionLocal = Vector3.new(direccionLocal.X, 0, direccionLocal.Z)
	if direccionLocal.Magnitude < 0.01 then
		direccionLocal = Vector3.new(0, 0, -1)
	end
	direccionLocal = direccionLocal.Unit

	-- Ejes de giro: "recto" gira hacia la dirección; "hombro" es igual pero inclinado
	local ejeRecto = Vector3.yAxis:Cross(direccionLocal)
	local lado = if math.random() < 0.5 then 1 else -1
	local ejes = {
		recto = ejeRecto,
		hombro = CFrame.fromAxisAngle(direccionLocal, INCLINACION_HOMBRO * lado):VectorToWorldSpace(ejeRecto),
	}

	local inicio = os.clock()
	local siguienteEvento = 1
	local terminado = false
	local conexion

	local function terminar()
		if terminado then
			return
		end
		terminado = true
		conexion:Disconnect()
		pcall(raizArt.poner, raizArt.original)
		for _, articulacion in articulaciones do
			pcall(articulacion.poner, articulacion.original)
		end
		rodando[personaje] = nil
		if raiz.Parent and RESPIRA_AL_FINAL[tipo] and math.random() < Sonidos.PROBABILIDAD_RESPIRACION then
			reproducirSonido(raiz, elegir(Sonidos.RESPIRACION), Sonidos.VOLUMEN_RESPIRACION)
		end
	end

	conexion = RunService.RenderStepped:Connect(function()
		if not personaje.Parent or not raiz.Parent then
			terminar()
			return
		end
		local t = math.clamp((os.clock() - inicio) / duracion, 0, 1)

		-- Sonidos y polvo en su momento
		while eventos[siguienteEvento] and t >= eventos[siguienteEvento][1] do
			local evento = eventos[siguienteEvento]
			reproducirSonido(raiz, elegir(Sonidos[evento[2]]), volumenDe(evento[2]) * evento[3])
			soltarPolvo(raiz, evento[4])
			siguienteEvento += 1
		end

		local ok, err = pcall(function()
			local cuerpo, giros = animar(t, ejes)
			raizArt.poner(cuerpo * raizArt.original)
			for nombre, articulacion in articulaciones do
				articulacion.poner(articulacion.original * (giros[nombre] or CFrame.identity))
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

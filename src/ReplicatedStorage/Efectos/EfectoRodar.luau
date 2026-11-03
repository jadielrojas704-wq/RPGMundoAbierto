-- Animaciones procedurales de esquiva estilo Elden Ring (hechas con código).
-- Ruta en Studio: ReplicatedStorage/Efectos/EfectoRodar
-- Solo se usa en el CLIENTE. No cambia nada del juego, solo lo visual.
--
-- Tres tipos de esquiva (t va de 0 a 1 durante la esquiva):
--   Rodar     -> manos al suelo, giro sobre un hombro con torsión, apoyo y rebote
--   Lateral   -> impulso, voltereta lateral con piernas recogidas, aterrizaje bajo con la mano al suelo
--   PasoAtras -> brazos atrás para impulsarse, salto hacia atrás, rodillas amortiguan
--
-- Trucos de animación para que se vea natural:
--   * Mientras esquiva, se apagan las animaciones de caminar/correr de Roblox
--   * Asimetría: un lado del cuerpo se adelanta al otro
--   * La cabeza va con un pequeño retraso
--   * Rebote al aterrizar: el peso cae sobre las rodillas y se recupera
--
-- Funciona con los dos tipos de articulaciones de Roblox:
--   * Motor6D (personajes clásicos): se mueve su propiedad C0
--   * AnimationConstraint (personajes nuevos): se mueve su Attachment0

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sonidos = require(ReplicatedStorage.Config.SonidosConfig).Esquiva
local Tipos = require(ReplicatedStorage.Config.CombateConfig).Esquiva.TIPOS
local EfectosSuelo = require(script.Parent.EfectosSuelo)

local EfectoRodar = {}

local INCLINACION_HOMBRO = math.rad(25) -- la voltereta va sobre un hombro, no recta
local DESFASE_LADOS = 0.045 -- cuánto se retrasa un lado del cuerpo respecto al otro
local RETRASO_CABEZA = 0.05

local function grados(x, y, z)
	return CFrame.Angles(math.rad(x), math.rad(y or 0), math.rad(z or 0))
end

-- ===== POSTURAS (cuánto gira cada articulación en su punto máximo) =====

-- Cuerpo hecho bolita para rodar
local ENCOGIDO = {
	LeftHip = grados(100),
	RightHip = grados(105),
	LeftKnee = grados(-120),
	RightKnee = grados(-115),
	LeftShoulder = grados(70, 0, -15),
	RightShoulder = grados(65, 0, 18),
	LeftElbow = grados(80),
	RightElbow = grados(85),
	Waist = grados(-30), -- espalda curvada
}

local CABEZA_ENCOGIDA = { Neck = grados(-35) } -- barbilla al pecho

-- Brazos estirados hacia delante para apoyar las manos al empezar a rodar
local ALCANCE = {
	LeftShoulder = grados(120, 0, -10),
	RightShoulder = grados(120, 0, 10),
	LeftElbow = grados(15),
	RightElbow = grados(15),
	Waist = grados(-10),
}

-- Al terminar de rodar: una rodilla adelantada, brazos para equilibrarse
local APOYO = {
	LeftHip = grados(70),
	RightHip = grados(30),
	LeftKnee = grados(-95),
	RightKnee = grados(-55),
	LeftShoulder = grados(40, 0, -20),
	RightShoulder = grados(25, 0, 25),
	LeftElbow = grados(35),
	RightElbow = grados(25),
	Waist = grados(-18),
	Neck = grados(8), -- levanta la mirada
}

-- Piernas flexionadas para tomar impulso o amortiguar
local FLEXION = {
	LeftHip = grados(50),
	RightHip = grados(50),
	LeftKnee = grados(-80),
	RightKnee = grados(-80),
	Waist = grados(-15),
}

-- ===== Voltereta lateral (con un toque "arácnido", sin exagerar) =====
-- "Líder" = el lado hacia el que saltas. Cada postura tiene versión derecha e izquierda.

-- En el aire: piernas recogidas (una más que la otra)
local PIERNAS_AIRE_DERECHA = {
	RightHip = grados(75, 0, 15),
	RightKnee = grados(-105),
	LeftHip = grados(62, 0, -12),
	LeftKnee = grados(-90),
	Waist = grados(-12),
}
local PIERNAS_AIRE_IZQUIERDA = {
	LeftHip = grados(75, 0, -15),
	LeftKnee = grados(-105),
	RightHip = grados(62, 0, 12),
	RightKnee = grados(-90),
	Waist = grados(-12),
}

-- En el aire: brazo líder abierto, el otro recogido cerca del pecho
local BRAZOS_AIRE_DERECHA = {
	RightShoulder = grados(0, 0, 125),
	RightElbow = grados(15),
	LeftShoulder = grados(35, 0, -55),
	LeftElbow = grados(75),
}
local BRAZOS_AIRE_IZQUIERDA = {
	LeftShoulder = grados(0, 0, -125),
	LeftElbow = grados(15),
	RightShoulder = grados(35, 0, 55),
	RightElbow = grados(75),
}

-- Aterrizaje bajo: mano líder hacia el suelo, el otro brazo atrás, cabeza arriba
local ATERRIZAJE_DERECHA = {
	RightShoulder = grados(30, 0, 25),
	RightElbow = grados(10),
	LeftShoulder = grados(-25, 0, -50),
	LeftElbow = grados(25),
	RightHip = grados(60, 0, 20),
	RightKnee = grados(-95),
	LeftHip = grados(78, 0, -25),
	LeftKnee = grados(-112),
	Waist = grados(-20),
	Neck = grados(18),
}
local ATERRIZAJE_IZQUIERDA = {
	LeftShoulder = grados(30, 0, -25),
	LeftElbow = grados(10),
	RightShoulder = grados(-25, 0, 50),
	RightElbow = grados(25),
	LeftHip = grados(60, 0, -20),
	LeftKnee = grados(-95),
	RightHip = grados(78, 0, 25),
	RightKnee = grados(-112),
	Waist = grados(-20),
	Neck = grados(18),
}

-- Paso atrás: primero los brazos van hacia atrás, luego adelante para equilibrar
local BRAZOS_ATRAS = {
	LeftShoulder = grados(-35, 0, -10),
	RightShoulder = grados(-35, 0, 10),
	LeftElbow = grados(15),
	RightElbow = grados(15),
}
local EQUILIBRIO = {
	LeftShoulder = grados(45, 0, -15),
	RightShoulder = grados(40, 0, 15),
	LeftElbow = grados(40),
	RightElbow = grados(35),
	Neck = grados(-10),
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

-- Un "bache" de 0 -> 1 -> 0 entre a y b (para rebotes)
local function bache(a, b, t)
	return math.sin(math.pi * suave(a, b, t))
end

-- El peso puede ser un número (igual para todo) o { L = izq, R = der, C = centro }
local function pesoPara(peso, nombre)
	if type(peso) == "number" then
		return peso
	end
	if string.sub(nombre, 1, 4) == "Left" then
		return peso.L or 0
	elseif string.sub(nombre, 1, 5) == "Right" then
		return peso.R or 0
	end
	return peso.C or 0
end

-- Mezcla varias posturas con su peso: combinar({POSTURA, peso}, {POSTURA, peso}, ...)
local function combinar(...)
	local resultado = {}
	for _, par in { ... } do
		local postura, peso = par[1], par[2]
		for nombre, giro in postura do
			local p = pesoPara(peso, nombre)
			if p > 0 then
				resultado[nombre] = (resultado[nombre] or CFrame.identity) * CFrame.identity:Lerp(giro, p)
			end
		end
	end
	return resultado
end

-- Calcula un peso para cada lado del cuerpo, con el lado líder adelantado
local function porLados(funcion, t, liderIzquierda)
	local adelantado = funcion(t)
	local retrasado = funcion(t - DESFASE_LADOS)
	local centro = funcion(t - DESFASE_LADOS * 0.5)
	if liderIzquierda then
		return { L = adelantado, R = retrasado, C = centro }
	end
	return { L = retrasado, R = adelantado, C = centro }
end

-- ===== ANIMACIONES =====
-- Cada una recibe t (0 a 1) y el contexto, y devuelve:
-- movimiento del cuerpo entero, giro de cada articulación

local Animaciones = {}

function Animaciones.Rodar(t, ctx)
	local izq = ctx.liderIzquierda
	local alcance = porLados(function(x)
		return curva(0, 0.1, 0.15, 0.3, x)
	end, t, izq)
	local encogido = porLados(function(x)
		return curva(0.05, 0.25, 0.6, 0.82, x)
	end, t, izq)
	local apoyo = porLados(function(x)
		return curva(0.7, 0.82, 0.9, 1, x)
	end, t, izq)
	local cabeza = curva(0.05, 0.25, 0.6, 0.82, t - RETRASO_CABEZA)

	-- Bajar para rodar + pequeño rebote al apoyarse al final
	local bajada = 1.6 * curva(0, 0.2, 0.7, 0.95, t) + 0.35 * bache(0.8, 1, t)
	-- Giro completo + al final se levanta un poco inclinado hacia delante
	local giro = suave(0.08, 0.72, t) * math.pi * 2 + math.rad(15) * curva(0.7, 0.82, 0.86, 1, t)
	-- Torsión del cuerpo a mitad del giro (hacia el hombro sobre el que rueda)
	local torsion = math.rad(14) * ctx.lado * curva(0.1, 0.35, 0.5, 0.75, t)

	local cuerpo = CFrame.new(0, -bajada, 0)
		* CFrame.fromAxisAngle(ctx.ejeHombro, giro)
		* CFrame.Angles(0, torsion, 0)
	return cuerpo, combinar({ ENCOGIDO, encogido }, { CABEZA_ENCOGIDA, cabeza }, { ALCANCE, alcance }, { APOYO, apoyo })
end

function Animaciones.Lateral(t, ctx)
	local izq = ctx.liderIzquierda

	-- Fases: impulso -> vuelo con piernas recogidas -> aterrizaje bajo (se mantiene) -> levantarse
	local impulso = curva(0, 0.1, 0.12, 0.22, t)
	local vuelo = curva(0.1, 0.35, 0.48, 0.72, t)
	local piernasAire = porLados(function(x)
		return curva(0.12, 0.28, 0.55, 0.72, x)
	end, t, izq)
	local brazosAire = porLados(function(x)
		return curva(0.1, 0.25, 0.55, 0.7, x)
	end, t, izq)
	local aterrizaje = porLados(function(x)
		return curva(0.64, 0.75, 0.86, 1, x)
	end, t, izq)
	local pesoAterrizaje = aterrizaje.C

	local giro = suave(0.12, 0.7, t) * math.pi * 2

	-- Altura: baja para impulsarse, sube en el aire, aterriza muy bajo y rebota al final
	local altura = 1.5 * vuelo - 0.8 * impulso - 1.3 * pesoAterrizaje - 0.2 * bache(0.86, 1, t)
	-- Inclinación hacia delante: un poco en el aire y más en el aterrizaje
	local inclinacion = math.rad(20) * curva(0.2, 0.4, 0.5, 0.65, t) + math.rad(25) * pesoAterrizaje
	-- Al despegar el cuerpo se gira un poco hacia donde va
	local torsion = math.rad(12) * ctx.lado * curva(0.05, 0.2, 0.7, 0.9, t)

	local piernas = if izq then PIERNAS_AIRE_IZQUIERDA else PIERNAS_AIRE_DERECHA
	local brazos = if izq then BRAZOS_AIRE_IZQUIERDA else BRAZOS_AIRE_DERECHA
	local postura = if izq then ATERRIZAJE_IZQUIERDA else ATERRIZAJE_DERECHA

	local cuerpo = CFrame.new(0, altura, 0)
		* CFrame.Angles(-inclinacion, 0, 0)
		* CFrame.fromAxisAngle(ctx.ejeRecto, giro)
		* CFrame.Angles(0, torsion, 0)
	return cuerpo,
		combinar(
			{ piernas, piernasAire },
			{ brazos, brazosAire },
			{ postura, aterrizaje },
			{ FLEXION, impulso }
		)
end

function Animaciones.PasoAtras(t, ctx)
	local izq = ctx.liderIzquierda
	local impulso = curva(0, 0.08, 0.1, 0.2, t)
	local salto = bache(0.05, 0.75, t)
	local aterrizaje = curva(0.7, 0.8, 0.82, 1, t)
	local brazosAtras = porLados(function(x)
		return curva(0, 0.08, 0.12, 0.25, x)
	end, t, izq)
	local equilibrio = porLados(function(x)
		return curva(0.15, 0.35, 0.75, 1, x)
	end, t, izq)
	local inclinacion = math.rad(14) * curva(0, 0.15, 0.75, 1, t)

	local altura = 0.5 * salto - 0.6 * math.max(impulso, aterrizaje) - 0.2 * bache(0.82, 1, t)
	-- Ángulo negativo: el cuerpo se inclina hacia delante mientras salta hacia atrás
	local cuerpo = CFrame.new(0, altura, 0) * CFrame.fromAxisAngle(ctx.ejeRecto, -inclinacion)
	return cuerpo,
		combinar(
			{ BRAZOS_ATRAS, brazosAtras },
			{ EQUILIBRIO, equilibrio },
			{ FLEXION, math.max(impulso, aterrizaje) * 0.8 }
		)
end

-- Momentos clave de cada esquiva: { t, sonido, volumen relativo, efectos visuales }
-- Efectos: polvo = nube, onda = anillo de polvo, trozos = piedritas/hierba..., sacudida = cámara
local EVENTOS = {
	Rodar = {
		{ 0, "ROPA", 1, { polvo = 0.6 } },
		{ 0.62, "CAIDA", 1, { polvo = 1, trozos = 3 } },
		{ 0.84, "CAIDA", 0.5, { polvo = 0.4 } }, -- el pie se apoya al levantarse
	},
	Lateral = {
		{ 0.05, "ROPA", 0.6, { polvo = 0.7, trozos = 2 } }, -- impulso
		{ 0.68, "CAIDA", 1.3, { polvo = 1.2, onda = 1, trozos = 5, sacudida = 1 } }, -- los pies tocan el suelo
		{ 0.74, "CAIDA", 0.35, { polvo = 0.4 } }, -- la mano se apoya
	},
	PasoAtras = {
		{ 0, "ROPA", 0.5, { polvo = 0.4 } },
		{ 0.78, "CAIDA", 1.1, { polvo = 0.8, onda = 0.5, trozos = 2 } },
	},
}

-- Ventanas en las que el cuerpo arrastra polvo por el suelo: { desde, hasta, intensidad }
local RASTROS = {
	Rodar = { 0.12, 0.72, 1 },
	Lateral = { 0.68, 0.82, 0.6 }, -- pequeño derrape al aterrizar
	PasoAtras = { 0.78, 0.9, 0.5 },
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

-- Baja casi a cero las animaciones normales (caminar, correr...) mientras esquiva.
-- Devuelve una función que las restaura al terminar.
local function silenciarAnimaciones(personaje)
	local humanoide = personaje:FindFirstChildOfClass("Humanoid")
	local animador = humanoide and humanoide:FindFirstChildOfClass("Animator")
	if not animador then
		return function() end
	end

	local pistas = {} -- [pista] = peso que tenía antes
	local function silenciar(pista, tiempo)
		if pistas[pista] == nil then
			pistas[pista] = if pista.WeightTarget > 0.01 then pista.WeightTarget else 1
		end
		pista:AdjustWeight(0.001, tiempo)
	end

	for _, pista in animador:GetPlayingAnimationTracks() do
		silenciar(pista, 0.08)
	end
	-- Si Roblox arranca otra animación durante la esquiva, también la silenciamos
	local conexion = animador.AnimationPlayed:Connect(function(pista)
		silenciar(pista, 0)
	end)

	return function()
		conexion:Disconnect()
		for pista, pesoAnterior in pistas do
			if pista.IsPlaying then
				pista:AdjustWeight(pesoAnterior, 0.2)
			end
		end
	end
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

-- Sacudida muy leve de la cámara (solo para el propio jugador)
local function sacudirCamara(intensidad)
	local nombre = "SacudidaEsquiva"
	local inicio = os.clock()
	local DURACION = 0.15
	pcall(function()
		RunService:UnbindFromRenderStep(nombre)
	end)
	RunService:BindToRenderStep(nombre, Enum.RenderPriority.Camera.Value + 1, function()
		local t = (os.clock() - inicio) / DURACION
		local camara = Workspace.CurrentCamera
		if t >= 1 or not camara then
			RunService:UnbindFromRenderStep(nombre)
			return
		end
		local fuerza = math.rad(0.35) * intensidad * (1 - t)
		camara.CFrame = camara.CFrame
			* CFrame.Angles((math.random() - 0.5) * fuerza, (math.random() - 0.5) * fuerza, 0)
	end)
end

local function lanzarEfectos(personaje, efectos, direccion)
	if efectos.polvo then
		EfectosSuelo.Polvo(personaje, efectos.polvo)
	end
	if efectos.onda then
		EfectosSuelo.Onda(personaje, efectos.onda)
	end
	if efectos.trozos then
		EfectosSuelo.Trozos(personaje, efectos.trozos, direccion)
	end
	if efectos.sacudida and Players.LocalPlayer.Character == personaje then
		sacudirCamara(efectos.sacudida)
	end
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

	-- Contexto de la animación
	local ejeRecto = Vector3.yAxis:Cross(direccionLocal)
	local lado
	if tipo == "Lateral" then
		lado = if direccionLocal.X > 0 then 1 else -1 -- lado hacia el que salta
	else
		lado = if math.random() < 0.5 then 1 else -1 -- hombro sobre el que rueda
	end
	local ctx = {
		lado = lado,
		liderIzquierda = lado < 0,
		ejeRecto = ejeRecto,
		ejeHombro = CFrame.fromAxisAngle(direccionLocal, INCLINACION_HOMBRO * lado):VectorToWorldSpace(ejeRecto),
	}

	local restaurarAnimaciones = silenciarAnimaciones(personaje)

	local inicio = os.clock()
	local siguienteEvento = 1
	local terminado = false
	local conexion
	local rastro = RASTROS[tipo]
	local apagarRastro = nil
	local rastroHecho = false

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
		pcall(restaurarAnimaciones)
		if apagarRastro then
			apagarRastro()
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
			pcall(lanzarEfectos, personaje, evento[4], direccion)
			siguienteEvento += 1
		end

		-- Rastro de polvo mientras el cuerpo va pegado al suelo
		if not apagarRastro and not rastroHecho and t >= rastro[1] then
			apagarRastro = EfectosSuelo.Rastro(personaje, rastro[3])
		end
		if apagarRastro and t >= rastro[2] then
			apagarRastro()
			apagarRastro = nil
			rastroHecho = true
		end

		local ok, err = pcall(function()
			local cuerpo, giros = animar(t, ctx)
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

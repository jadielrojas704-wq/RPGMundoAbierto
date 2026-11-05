-- Motor de animación propio (hecho con código). Solo en el CLIENTE.
-- Ruta en Studio: ReplicatedStorage/Combate/Animador
--
-- Mueve las articulaciones del personaje (Motor6D o AnimationConstraint) encima de las
-- animaciones normales de Roblox, con dos capas:
--   * POSTURA: una pose que se mantiene (por ejemplo, la guardia de combate).
--   * ACCIÓN: una animación por poses clave (un golpe, una reacción...), que tapa a la postura.
-- Las poses son tablas { NombreArticulacion = CFrame de giro }, con "Root" para mover el cuerpo
-- entero (bajar, inclinarse, girar). Cada pose clave tiene su tiempo y su curva de suavizado.
--
--   local anim = Animador.De(personaje)
--   anim:Postura(Poses.GUARDIA, 0.25)              -- entra en guardia en 0.25 s
--   anim:Reproducir(Animaciones.Jab, { velocidad = 1.1, alEvento = function(nombre) end })
--   anim:Congelar(0.07)                            -- congelado de impacto (hitstop)
--   anim:Locomocion(true)                          -- capa de movimiento (solo tu personaje):
--       el cuerpo se inclina al correr y al girar, y la cabeza mira hacia donde apunta la cámara
--
-- Mientras te mueves, la postura deja libres las PIERNAS (las mueve la animación de andar o
-- correr) y solo mantiene el tronco y los brazos en guardia: así se ve el paso y no "patina".

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Animador = {}
Animador.__index = Animador

local ARTICULACIONES = {
	"Root",
	"Waist",
	"Neck",
	"LeftShoulder",
	"RightShoulder",
	"LeftElbow",
	"RightElbow",
	"LeftWrist",
	"RightWrist",
	"LeftHip",
	"RightHip",
	"LeftKnee",
	"RightKnee",
	"LeftAnkle",
	"RightAnkle",
}

local instancias = {} -- [personaje] = Animador

-- Articulaciones de las piernas: al moverse, la postura se aparta de ellas
local PIERNAS = {
	Root = 0.75,
	LeftHip = 1,
	RightHip = 1,
	LeftKnee = 1,
	RightKnee = 1,
	LeftAnkle = 1,
	RightAnkle = 1,
	Waist = 0.35,
}

-- ===== Curvas de suavizado =====
local CURVAS = {
	lineal = function(x)
		return x
	end,
	suave = function(x) -- entra y sale suave
		return x * x * (3 - 2 * x)
	end,
	salida = function(x) -- arranca rápido y frena (golpes)
		return 1 - (1 - x) ^ 3
	end,
	latigo = function(x) -- muy explosivo al principio (impactos)
		return 1 - (1 - x) ^ 5
	end,
	entrada = function(x) -- empieza lento y acelera (cargar)
		return x * x * x
	end,
	rebote = function(x) -- pasa un poco del objetivo y vuelve (golpes con "chasquido")
		local c1 = 1.1
		local c3 = c1 + 1
		return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
	end,
}

-- Suavizado tipo muelle de cada articulación: cuanto más alto, más rápido sigue a la pose.
-- El pecho, el cuello y las muñecas van un poco por detrás de los brazos: eso da la
-- sensación de peso y de que el golpe "arrastra" el cuerpo (acción superpuesta).
local RIGIDEZ = {
	Root = 26,
	Waist = 19,
	Neck = 13,
	LeftShoulder = 36,
	RightShoulder = 36,
	LeftElbow = 32,
	RightElbow = 32,
	LeftWrist = 20,
	RightWrist = 20,
	LeftHip = 30,
	RightHip = 30,
	LeftKnee = 30,
	RightKnee = 30,
	LeftAnkle = 22,
	RightAnkle = 22,
}

-- Convierte una articulación (de cualquier tipo) en algo que podemos mover
local function prepararArticulacion(objeto)
	if not objeto then
		return nil
	end
	if objeto:IsA("Motor6D") then
		return {
			original = objeto.C0,
			poner = function(cf)
				objeto.C0 = cf
			end,
		}
	elseif objeto:IsA("AnimationConstraint") and objeto.Attachment0 then
		local adjunto = objeto.Attachment0
		return {
			original = adjunto.CFrame,
			poner = function(cf)
				adjunto.CFrame = cf
			end,
		}
	end
	return nil
end

function Animador.De(personaje)
	local existente = instancias[personaje]
	if existente then
		return existente
	end
	if not personaje:FindFirstChild("LowerTorso") then
		return nil -- solo personajes R15
	end
	local self = setmetatable({}, Animador)
	self.personaje = personaje
	self.articulaciones = {}
	for _, nombre in ARTICULACIONES do
		local objeto = personaje:FindFirstChild(nombre, true)
		if objeto and (objeto:IsA("Motor6D") or objeto:IsA("AnimationConstraint")) then
			self.articulaciones[nombre] = prepararArticulacion(objeto)
		end
	end
	self.postura = nil -- pose de la capa de postura
	self.pesoPostura = 0
	self.objetivoPostura = 0
	self.velocidadPostura = 4
	self.accion = nil
	self.congeladoHasta = 0
	self.temblor = 0 -- temblor del cuerpo (para cargar golpes)
	self.tocado = false
	self.suave = {} -- última pose aplicada de cada articulación (para el muelle)
	self.movimiento = 0 -- 0 quieto, 1 corriendo (suavizado)
	self.locomocion = false
	self.inclinacion = 0 -- hacia delante (radianes)
	self.ladeo = 0 -- hacia los lados al girar
	self.mirada = CFrame.identity -- giro de la cabeza
	self.ultimoGiro = nil
	instancias[personaje] = self
	return self
end

-- Pone (o quita, con pose = nil) la postura de fondo, con una transición en segundos
function Animador:Postura(pose, transicion)
	transicion = transicion or 0.25
	if pose then
		self.postura = pose
		self.objetivoPostura = 1
	else
		self.objetivoPostura = 0
	end
	self.velocidadPostura = 1 / math.max(transicion, 0.01)
end

-- anim = { duracion = s, claves = { { t = s, pose = {...}, curva = "salida" }, ... },
--          eventos = { { t = s, nombre = "golpe" }, ... }, bucle = false, mezcla = s }
function Animador:Reproducir(anim, opciones)
	opciones = opciones or {}
	self.accion = {
		anim = anim,
		t = 0,
		velocidad = opciones.velocidad or 1,
		alEvento = opciones.alEvento,
		alTerminar = opciones.alTerminar,
		hechos = {},
		mezcla = anim.mezcla or opciones.mezcla or 0.05,
		salida = anim.salida or opciones.salida or 0.12,
		peso = 0,
	}
	return self.accion
end

function Animador:Detener()
	if self.accion then
		self.accion.terminando = true
	end
end

function Animador:Ocupado()
	return self.accion ~= nil and not self.accion.terminando
end

function Animador:Locomocion(activa)
	self.locomocion = activa == true
end

function Animador:Congelar(segundos)
	self.congeladoHasta = math.max(self.congeladoHasta, os.clock() + segundos)
end

function Animador:Temblar(intensidad)
	self.temblor = intensidad or 0
end

-- Pose de una animación en el tiempo t (interpola entre poses clave)
local function poseEn(anim, t)
	local claves = anim.claves
	if t <= claves[1].t then
		return claves[1].pose, nil, 0
	end
	for i = 1, #claves - 1 do
		local a, b = claves[i], claves[i + 1]
		if t <= b.t then
			local x = (t - a.t) / math.max(b.t - a.t, 1e-3)
			local curva = CURVAS[b.curva or "suave"] or CURVAS.suave
			return a.pose, b.pose, curva(math.clamp(x, 0, 1))
		end
	end
	return claves[#claves].pose, nil, 0
end

local function giro(pose, nombre)
	return pose and pose[nombre] or CFrame.identity
end

function Animador:_actualizar(dt)
	local personaje = self.personaje
	-- Mientras otra animación con código (la esquiva) mueve el cuerpo, no tocamos nada
	if personaje:GetAttribute("AnimacionExterna") then
		self.tocado = true
		return
	end
	local congelado = os.clock() < self.congeladoHasta
	local paso = if congelado then 0 else dt

	-- Capa de postura
	if self.pesoPostura ~= self.objetivoPostura then
		local cambio = self.velocidadPostura * paso
		if self.pesoPostura < self.objetivoPostura then
			self.pesoPostura = math.min(self.objetivoPostura, self.pesoPostura + cambio)
		else
			self.pesoPostura = math.max(self.objetivoPostura, self.pesoPostura - cambio)
		end
	end

	-- Capa de acción
	local accion = self.accion
	local poseA, poseB, x = nil, nil, 0
	if accion then
		local anim = accion.anim
		accion.t += paso * accion.velocidad
		if anim.bucle and accion.t > anim.duracion and not accion.terminando then
			accion.t = (anim.repetirDesde or 0) + (accion.t - anim.duracion)
		end
		-- eventos (golpe, sonido, efecto...)
		if anim.eventos then
			for i, evento in anim.eventos do
				if not accion.hechos[i] and accion.t >= evento.t then
					accion.hechos[i] = true
					if accion.alEvento then
						task.spawn(accion.alEvento, evento.nombre, evento)
					end
				end
			end
		end
		local fin = accion.t >= anim.duracion and not anim.bucle
		if fin or accion.terminando then
			accion.peso = math.max(0, accion.peso - paso / accion.salida)
			if accion.peso <= 0 then
				self.accion = nil
				if accion.alTerminar then
					task.spawn(accion.alTerminar)
				end
				accion = nil
			end
		else
			accion.peso = math.min(1, accion.peso + paso / accion.mezcla)
		end
		if accion then
			poseA, poseB, x = poseEn(anim, math.min(accion.t, anim.duracion))
		end
	end

	local pesoAccion = accion and accion.peso or 0

	-- ===== Capa de movimiento: cuánto te mueves, inclinación y mirada =====
	local raiz = personaje:FindFirstChild("HumanoidRootPart")
	local humanoide = personaje:FindFirstChildOfClass("Humanoid")
	local mover = 0
	local inclinacionObjetivo, ladeoObjetivo, miradaObjetivo = 0, 0, CFrame.identity
	if raiz and humanoide then
		local v = raiz.AssemblyLinearVelocity
		local plano = Vector3.new(v.X, 0, v.Z)
		local rapidez = plano.Magnitude
		mover = math.clamp((rapidez - 2) / 12, 0, 1)
		if self.locomocion and humanoide.FloorMaterial ~= Enum.Material.Air then
			local adelante = raiz.CFrame.LookVector:Dot(plano)
			-- al correr de verdad (más de 18) el cuerpo se echa hacia delante
			inclinacionObjetivo = math.clamp((adelante - 10) / 16, 0, 1) * math.rad(10)
			-- al girar, el cuerpo se ladea hacia el lado del giro (como al correr de verdad)
			local _, giroY = raiz.CFrame:ToEulerAnglesYXZ()
			if self.ultimoGiro and dt > 0 then
				local cambio = math.atan2(math.sin(giroY - self.ultimoGiro), math.cos(giroY - self.ultimoGiro))
				ladeoObjetivo = math.clamp(cambio / dt * 0.05 * mover, -math.rad(9), math.rad(9))
			end
			self.ultimoGiro = giroY
		end
		-- la cabeza mira hacia donde apunta la cámara (sin pasarse)
		if self.locomocion and not accion and personaje == Players.LocalPlayer.Character then
			local camara = workspace.CurrentCamera
			local local_ = raiz.CFrame:VectorToObjectSpace(camara.CFrame.LookVector)
			local yaw = math.clamp(math.atan2(-local_.X, -local_.Z), -math.rad(55), math.rad(55))
			local pitch = math.clamp(math.asin(math.clamp(local_.Y, -1, 1)), -math.rad(25), math.rad(30))
			miradaObjetivo = CFrame.Angles(pitch * 0.6, yaw * 0.7, 0)
		end
	end
	local k = 1 - math.exp(-8 * dt)
	self.movimiento += (mover - self.movimiento) * k
	self.inclinacion += (inclinacionObjetivo - self.inclinacion) * k
	self.ladeo += (ladeoObjetivo - self.ladeo) * (1 - math.exp(-5 * dt))
	self.mirada = self.mirada:Lerp(miradaObjetivo, 1 - math.exp(-6 * dt))
	local capaMovimiento = self.locomocion
		and (math.abs(self.inclinacion) > 0.002 or math.abs(self.ladeo) > 0.002 or self.mirada ~= CFrame.identity)

	if self.pesoPostura <= 0.001 and pesoAccion <= 0.001 and self.temblor <= 0 and not capaMovimiento then
		if self.tocado then
			-- todo en reposo: dejamos las articulaciones como estaban
			for _, articulacion in self.articulaciones do
				articulacion.poner(articulacion.original)
			end
			self.tocado = false
			table.clear(self.suave)
		end
		return
	end
	self.tocado = true

	local temblor = nil
	if self.temblor > 0 and not congelado then
		local a = self.temblor
		temblor = CFrame.new(math.noise(os.clock() * 30, 1) * 0.08 * a, math.noise(os.clock() * 30, 2) * 0.05 * a, 0)
	end

	for nombre, articulacion in self.articulaciones do
		-- al moverse, las piernas quedan libres para la animación de andar/correr
		local libre = (PIERNAS[nombre] or 0) * self.movimiento * 0.9
		local base = CFrame.identity:Lerp(giro(self.postura, nombre), self.pesoPostura * (1 - libre))
		local final = base
		if accion then
			local g = giro(poseA, nombre)
			if poseB then
				g = g:Lerp(giro(poseB, nombre), x)
			end
			final = base:Lerp(g, pesoAccion)
		end
		-- muelle: sigue a la pose con un poco de inercia (en el congelado, se queda quieto)
		local previo = self.suave[nombre]
		if previo then
			if congelado then
				final = previo
			else
				final = previo:Lerp(final, 1 - math.exp(-(RIGIDEZ[nombre] or 30) * dt))
			end
		end
		self.suave[nombre] = final
		if temblor and nombre == "Root" then
			final = final * temblor
		end
		-- capa de movimiento (va encima de todo, sin muelle: ya va suavizada)
		if capaMovimiento then
			if nombre == "Root" then
				final = final * CFrame.Angles(-self.inclinacion, 0, self.ladeo)
			elseif nombre == "Neck" then
				final = final * self.mirada
			elseif nombre == "Waist" then
				final = final * CFrame.Angles(self.inclinacion * 0.3, 0, -self.ladeo * 0.4)
			end
		end
		articulacion.poner(articulacion.original * final)
	end
end

-- Devuelve las articulaciones a su sitio (antes de que otra animación con código, como
-- la esquiva, tome el control del cuerpo)
function Animador.Soltar(personaje)
	local self = instancias[personaje]
	if self then
		for _, articulacion in self.articulaciones do
			articulacion.poner(articulacion.original)
		end
		self.tocado = false
		table.clear(self.suave)
	end
end

-- Un solo bucle para todos los personajes animados
if RunService:IsClient() then
	RunService.RenderStepped:Connect(function(dt)
		for personaje, animador in instancias do
			if not personaje.Parent then
				instancias[personaje] = nil
			else
				local ok, err = pcall(animador._actualizar, animador, dt)
				if not ok then
					warn("[Animador]", err)
					instancias[personaje] = nil
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(jugador)
		if jugador.Character then
			instancias[jugador.Character] = nil
		end
	end)
end

return Animador

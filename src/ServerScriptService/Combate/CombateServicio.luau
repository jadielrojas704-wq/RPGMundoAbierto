-- Combate cuerpo a cuerpo en el SERVIDOR: comprueba cada ataque, mide los golpes y
-- aplica el daño, la postura y los empujones. El cliente solo pide y anima.
-- Ruta en Studio: ServerScriptService/Combate/CombateServicio
--
-- Mensajes que llegan por el RemoteEvent "Combate" (del cliente):
--   "Ligero"           -> siguiente golpe del combo (el servidor decide cuál)
--   "Cargar"           -> empieza a cargar el golpe pesado
--   "Pesado"           -> suelta el golpe cargado (el servidor mide cuánto se cargó)
-- Mensajes que salen por "EfectoCombate" (a los jugadores cercanos):
--   "Accion", personaje, arma, idAnimacion          -> para que los demás vean el golpe
--   "Golpe", atacante, objetivo, datos               -> impacto: daño, crítico, reacción...
--
-- Por ahora solo se puede golpear a lo que tenga la etiqueta "Enemigo" (muñecos de
-- entrenamiento y, más adelante, monstruos). El PvP se decidirá más adelante.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArmasConfig = require(ReplicatedStorage.Config.ArmasConfig)
local Formulas = require(ReplicatedStorage.Progresion.Formulas)
local EstaminaServicio = require(script.Parent.EstaminaServicio)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RemoteCombate = Remotes:WaitForChild("Combate")
local RemoteEfecto = Remotes:WaitForChild("EfectoCombate")

local CombateServicio = {}

local DISTANCIA_EFECTOS = 160
local MENSAJES_POR_SEGUNDO = 14
local TOLERANCIA = 0.12 -- margen por el retraso de internet al encadenar golpes

local DatosServicio, PersonajeServicio -- se cargan al iniciar (evita dependencias circulares)

-- estado[jugador] = { indice, finGolpe, cargandoDesde, mensajes, ventana, enCombateHasta }
local estado = {}

local function vivo(jugador)
	local personaje = jugador.Character
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if humanoide and raiz and humanoide.Health > 0 then
		return personaje, humanoide, raiz
	end
	return nil
end

-- Envía un efecto a todos los jugadores cerca de una posición (menos a "excepto")
local function avisarCerca(posicion, excepto, ...)
	for _, otro in Players:GetPlayers() do
		if otro ~= excepto then
			local raiz = otro.Character and otro.Character:FindFirstChild("HumanoidRootPart")
			if raiz and (raiz.Position - posicion).Magnitude < DISTANCIA_EFECTOS then
				RemoteEfecto:FireClient(otro, ...)
			end
		end
	end
end

local function marcarEnCombate(jugador, personaje, hasta)
	local e = estado[jugador]
	e.enCombateHasta = os.clock() + ArmasConfig.TIEMPO_EN_COMBATE
	personaje:SetAttribute("EnCombate", true)
	-- "Atacando" frena al personaje mientras dura el golpe (lo usa CorrerServicio)
	personaje:SetAttribute("Atacando", true)
	local marca = os.clock()
	e.marcaAtaque = marca
	task.delay(hasta, function()
		if estado[jugador] and estado[jugador].marcaAtaque == marca and personaje.Parent then
			personaje:SetAttribute("Atacando", false)
		end
	end)
end

-- ===== Medir el golpe y aplicar el daño =====

local parametros = OverlapParams.new()
parametros.FilterType = Enum.RaycastFilterType.Include

local function modeloDe(parte)
	local modelo = parte:FindFirstAncestorOfClass("Model")
	while modelo and not modelo:FindFirstChildOfClass("Humanoid") do
		modelo = modelo.Parent and modelo.Parent:FindFirstAncestorOfClass("Model")
	end
	return modelo
end

local function golpear(jugador, golpe, multiplicador)
	local personaje, _, raiz = vivo(jugador)
	if not personaje then
		return
	end
	local enemigos = CollectionService:GetTagged("Enemigo")
	if #enemigos == 0 then
		return
	end
	parametros.FilterDescendantsInstances = enemigos
	local caja = raiz.CFrame * CFrame.new(0, 0, -golpe.Alcance / 2 + 0.5)
	local partes = Workspace:GetPartBoundsInBox(caja, Vector3.new(golpe.Ancho, golpe.Alto, golpe.Alcance), parametros)

	local datos = DatosServicio.Obtener(jugador)
	local atributos = datos and datos.Atributos or {}
	local yaGolpeados = {}
	for _, parte in partes do
		local objetivo = modeloDe(parte)
		if objetivo and not yaGolpeados[objetivo] and objetivo ~= personaje then
			yaGolpeados[objetivo] = true
			local humanoide = objetivo:FindFirstChildOfClass("Humanoid")
			local raizObjetivo = objetivo:FindFirstChild("HumanoidRootPart")
			if humanoide and raizObjetivo and humanoide.Health > 0 then
				-- daño = base × golpe cargado × atributos × crítico × defensa del enemigo
				local critico = math.random() < (jugador:GetAttribute("Critico") or 0.05)
				local dano = golpe.Dano * multiplicador * Formulas.EscaladoArma("SinArmas", atributos)
				if critico then
					dano *= 1.5
				end
				dano *= 1 - math.clamp(objetivo:GetAttribute("ReduccionDano") or 0, 0, 0.9)
				dano = math.max(1, math.floor(dano + 0.5))
				humanoide:TakeDamage(dano)

				-- postura: si se llena, se tambalea
				local tambalea = false
				local posturaMax = objetivo:GetAttribute("PosturaMax")
				if posturaMax and not objetivo:GetAttribute("Tambaleando") then
					local postura = (objetivo:GetAttribute("Postura") or 0) + golpe.Postura * multiplicador
					if postura >= posturaMax then
						postura = 0
						tambalea = true
						objetivo:SetAttribute("Tambaleando", true)
						task.delay(2.2, function()
							if objetivo.Parent then
								objetivo:SetAttribute("Tambaleando", false)
							end
						end)
					end
					objetivo:SetAttribute("Postura", postura)
				end
				objetivo:SetAttribute("UltimoGolpe", os.clock())

				-- empujón (si no está anclado)
				if not raizObjetivo.Anchored then
					local direccion = raizObjetivo.Position - raiz.Position
					direccion = Vector3.new(direccion.X, 0, direccion.Z)
					direccion = if direccion.Magnitude > 0.1 then direccion.Unit else raiz.CFrame.LookVector
					local empuje = golpe.Empuje * math.min(multiplicador, 2)
					local adjunto = Instance.new("Attachment")
					adjunto.Parent = raizObjetivo
					local fuerza = Instance.new("LinearVelocity")
					fuerza.Attachment0 = adjunto
					fuerza.MaxForce = 1e6
					fuerza.VectorVelocity = direccion * empuje + Vector3.new(0, golpe.Elevar or 0, 0)
					fuerza.RelativeTo = Enum.ActuatorRelativeTo.World
					fuerza.Parent = raizObjetivo
					task.delay(if (golpe.Elevar or 0) > 20 then 0.18 else 0.12, function()
						fuerza:Destroy()
						adjunto:Destroy()
					end)
				end

				local datosGolpe = {
					dano = dano,
					critico = critico,
					reaccion = golpe.Reaccion,
					tipo = golpe.Tipo,
					tambalea = tambalea,
					posicion = raizObjetivo.Position + Vector3.new(0, 1, 0),
				}
				RemoteEfecto:FireClient(jugador, "Golpe", personaje, objetivo, datosGolpe)
				avisarCerca(raizObjetivo.Position, jugador, "Golpe", personaje, objetivo, datosGolpe)

				-- usar el arma sube su maestría
				if PersonajeServicio then
					PersonajeServicio.DarExpOficio(jugador, "Maestrias", "SinArmas", if golpe.Tipo == "Pesado" then 4 else 2)
				end
			end
		end
	end
end

-- ===== Peticiones del cliente =====

local function puedeActuar(jugador, personaje)
	if personaje:GetAttribute("Invulnerable") then
		return false -- está esquivando
	end
	local e = estado[jugador]
	return os.clock() >= e.finGolpe - TOLERANCIA
end

local function alLigero(jugador)
	local personaje, _, raiz = vivo(jugador)
	if not personaje or not puedeActuar(jugador, personaje) then
		return
	end
	local e = estado[jugador]
	local arma = ArmasConfig.SinArmas
	local ahora = os.clock()
	-- ¿sigue el combo o empieza de nuevo?
	if ahora <= e.finGolpe + arma.VentanaCombo and e.indice < #arma.Combo then
		e.indice += 1
	else
		e.indice = 1
	end
	local golpe = arma.Combo[e.indice]
	if not EstaminaServicio.Gastar(jugador, golpe.Estamina) then
		e.indice = 0
		return
	end
	local velocidad = jugador:GetAttribute("VelocidadAtaque") or 1
	local duracion = golpe.Duracion / velocidad
	e.finGolpe = ahora + duracion
	e.cargandoDesde = nil
	marcarEnCombate(jugador, personaje, duracion)
	avisarCerca(raiz.Position, jugador, "Accion", personaje, "SinArmas", golpe.Id)
	task.delay(golpe.Activo / velocidad, golpear, jugador, golpe, 1)
	if e.indice >= #arma.Combo then
		e.indice = 0 -- tras el remate, el combo vuelve a empezar
	end
end

local function alCargar(jugador)
	local personaje, _, raiz = vivo(jugador)
	if not personaje or not puedeActuar(jugador, personaje) then
		return
	end
	local e = estado[jugador]
	e.cargandoDesde = os.clock()
	e.finGolpe = os.clock() + 0.1
	marcarEnCombate(jugador, personaje, ArmasConfig.SinArmas.Pesado.CargaMaxima + 1)
	avisarCerca(raiz.Position, jugador, "Accion", personaje, "SinArmas", "Carga")
end

local function alPesado(jugador)
	local personaje, _, raiz = vivo(jugador)
	local e = estado[jugador]
	if not personaje or not e.cargandoDesde then
		return
	end
	local golpe = ArmasConfig.SinArmas.Pesado
	local carga = math.clamp(os.clock() - e.cargandoDesde, 0, golpe.CargaMaxima)
	e.cargandoDesde = nil
	if carga < golpe.CargaMinima * 0.7 then
		return -- no llegó a cargar: no cuenta
	end
	if not EstaminaServicio.Gastar(jugador, golpe.Estamina) then
		personaje:SetAttribute("Atacando", false)
		return
	end
	local multiplicador = 1 + (carga / golpe.CargaMaxima) * golpe.Multiplicador
	local duracion = golpe.Duracion
	e.finGolpe = os.clock() + duracion
	e.indice = 0
	marcarEnCombate(jugador, personaje, duracion)
	avisarCerca(raiz.Position, jugador, "Accion", personaje, "SinArmas", golpe.Id)
	task.delay(golpe.Activo, golpear, jugador, golpe, multiplicador)
end

local ACCIONES = { Ligero = alLigero, Cargar = alCargar, Pesado = alPesado }

function CombateServicio.Iniciar()
	DatosServicio = require(script.Parent.Parent.Progresion.DatosServicio)
	PersonajeServicio = require(script.Parent.Parent.Progresion.PersonajeServicio)

	local function alEntrar(jugador)
		estado[jugador] = { indice = 0, finGolpe = 0, cargandoDesde = nil, mensajes = 0, ventana = os.clock(), enCombateHasta = 0 }
	end
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		alEntrar(jugador)
	end
	Players.PlayerRemoving:Connect(function(jugador)
		estado[jugador] = nil
	end)

	RemoteCombate.OnServerEvent:Connect(function(jugador, accion)
		local e = estado[jugador]
		if not e or type(accion) ~= "string" then
			return
		end
		-- límite de mensajes por segundo (contra trampas y spam)
		local ahora = os.clock()
		if ahora - e.ventana > 1 then
			e.ventana, e.mensajes = ahora, 0
		end
		e.mensajes += 1
		if e.mensajes > MENSAJES_POR_SEGUNDO then
			return
		end
		local funcion = ACCIONES[accion]
		if funcion then
			funcion(jugador)
		end
	end)

	-- Se sale del modo combate (guardia) tras unos segundos sin pelear
	task.spawn(function()
		while true do
			task.wait(1)
			local ahora = os.clock()
			for jugador, e in estado do
				local personaje = jugador.Character
				if personaje and personaje:GetAttribute("EnCombate") and ahora > e.enCombateHasta then
					personaje:SetAttribute("EnCombate", false)
				end
			end
		end
	end)
end

return CombateServicio

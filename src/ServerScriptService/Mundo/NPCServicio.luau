-- Vida de los NPC (servidor): rutinas, conversaciones y escenas.
-- Ruta en Studio: ServerScriptService/Mundo/NPCServicio
--
-- Los NPC los crea el generador del mundo (ServerStorage/Herramientas/Mundo/NPCs) con
-- la etiqueta "NPC" y el atributo Rol:
--   Tendero  -> se queda en su tienda (no camina)
--   Guardia  -> vigila la puerta (no camina)
--   Paseante -> camina por el pueblo (plaza, tiendas, calles, casas); de noche vuelve
--               a su casa, entra y sale por la mañana
-- Cuando un jugador habla con un NPC, este se para y lo mira (HablarNPC).
-- De vez en cuando pasan escenas: un noble se lleva a un plebeyo a un callejón sin salida
-- y lo humilla, dos vecinos cotillean...
-- Cada NPC "reserva" el sitio al que va: nadie elige un sitio a menos de SEPARACION
-- studs de otro NPC, así nunca se forman corrillos ni montones.
-- Los globos de texto se envían a los clientes con BurbujaNPC.
-- Para ahorrar, solo se mueven los pueblos que tienen algún jugador cerca.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ClimaConfig = require(ReplicatedStorage.Config.ClimaConfig)
local PueblosConfig = require(ReplicatedStorage.Config.PueblosConfig)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RemoteHablar = Remotes:WaitForChild("HablarNPC")
local RemoteBurbuja = Remotes:WaitForChild("BurbujaNPC")

local NPCServicio = {}

local ANIMACIONES = {
	Quieto = "rbxassetid://507766388",
	Andar = "rbxassetid://507777826",
	Senalar = "rbxassetid://507770453",
	Reir = "rbxassetid://507770818",
	Saludar = "rbxassetid://507770239",
}
local DISTANCIA_ACTIVO = 260 -- un pueblo "despierta" si hay un jugador a esta distancia de su borde
local DISTANCIA_HABLAR = 14
local SEPARACION = 6 -- distancia mínima entre NPC parados (para que nunca se amontonen)
local rng = Random.new()

-- estado[npc] = { rol, ocupado, pistas = {}, pueblo, puesto, original, ... }
local estado = {}
local dormitorio = Instance.new("Folder") -- aquí "duermen" los NPC por la noche (no se ven)
dormitorio.Name = "NPCDurmiendo"
dormitorio.Parent = ServerStorage

-- ===== Utilidades =====

local function raizDe(npc)
	return npc:FindFirstChild("HumanoidRootPart")
end

local function humanoideDe(npc)
	return npc:FindFirstChildOfClass("Humanoid")
end

local function cargarAnimaciones(npc)
	local humanoide = humanoideDe(npc)
	if not humanoide then
		return {}
	end
	local animador = humanoide:FindFirstChildOfClass("Animator")
	if not animador then
		animador = Instance.new("Animator")
		animador.Parent = humanoide
	end
	local pistas = {}
	for nombre, id in ANIMACIONES do
		local animacion = Instance.new("Animation")
		animacion.AnimationId = id
		local ok, pista = pcall(function()
			return animador:LoadAnimation(animacion)
		end)
		if ok then
			pistas[nombre] = pista
		end
	end
	if pistas.Quieto then
		pistas.Quieto.Looped = true
		pistas.Quieto.Priority = Enum.AnimationPriority.Idle
	end
	if pistas.Andar then
		pistas.Andar.Looped = true
		pistas.Andar.Priority = Enum.AnimationPriority.Movement
	end
	return pistas
end

local function anim(datos, nombre, velocidad)
	local pista = datos.pistas[nombre]
	if pista then
		pista:Play(0.25, 1, velocidad or 1)
	end
	return pista
end

local function pararAnim(datos, nombre)
	local pista = datos.pistas[nombre]
	if pista and pista.IsPlaying then
		pista:Stop(0.3)
	end
end

-- Globo de texto sobre la cabeza (lo dibujan los clientes cercanos)
local function decir(npc, texto, duracion)
	RemoteBurbuja:FireAllClients(npc, texto, duracion or 4)
end

local function mirarA(npc, objetivo)
	local raiz = raizDe(npc)
	if not raiz then
		return
	end
	local desde = raiz.Position
	local hacia = Vector3.new(objetivo.X, desde.Y, objetivo.Z)
	if (hacia - desde).Magnitude > 0.3 then
		npc:PivotTo(CFrame.lookAt(desde, hacia))
	end
end

local function anclar(npc, valor)
	local raiz = raizDe(npc)
	if raiz then
		raiz.Anchored = valor
		if not valor then
			pcall(function()
				raiz:SetNetworkOwner(nil) -- el servidor manda (nunca el cliente)
			end)
		end
	end
end

-- ¿Hay algún jugador cerca de esta posición?
local function jugadorCerca(posicion, distancia)
	for _, jugador in Players:GetPlayers() do
		local personaje = jugador.Character
		local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
		if raiz and (raiz.Position - posicion).Magnitude < distancia then
			return jugador, raiz
		end
	end
	return nil
end

local function esDeNoche()
	local _, _, noche = ClimaConfig.Momento(Lighting.ClockTime)
	return noche > 0.55
end

-- ===== Caminar con búsqueda de camino =====

-- forzado = true: camina aunque esté "ocupado" (lo usan las escenas)
local function caminarA(npc, datos, destino, forzado)
	local raiz = raizDe(npc)
	local humanoide = humanoideDe(npc)
	if not (raiz and humanoide) then
		return false
	end
	local camino = PathfindingService:CreatePath({
		AgentRadius = 1.6,
		AgentHeight = 5.5,
		AgentCanJump = false,
		WaypointSpacing = 5,
	})
	local ok = pcall(function()
		camino:ComputeAsync(raiz.Position, destino)
	end)
	if not ok or camino.Status ~= Enum.PathStatus.Success then
		return false
	end
	anclar(npc, false)
	pararAnim(datos, "Quieto")
	anim(datos, "Andar", humanoide.WalkSpeed / 7)
	datos.caminando = true
	local llegado = true
	for _, paso in camino:GetWaypoints() do
		if (datos.ocupado and not forzado) or not npc.Parent then
			llegado = false
			break
		end
		humanoide:MoveTo(paso.Position)
		local termino = false
		local conexion = humanoide.MoveToFinished:Connect(function()
			termino = true
		end)
		local limite = os.clock() + 5
		while not termino and os.clock() < limite and (forzado or not datos.ocupado) do
			task.wait(0.1)
		end
		conexion:Disconnect()
		if not termino and (forzado or not datos.ocupado) then
			llegado = false -- se atascó: lo dejamos y buscará otro sitio
			break
		end
	end
	humanoide:MoveTo(raiz.Position)
	datos.caminando = false
	pararAnim(datos, "Andar")
	anim(datos, "Quieto", rng:NextNumber(0.85, 1.1))
	task.wait(0.2)
	anclar(npc, true)
	return llegado
end

-- ===== Rutina de los paseantes =====

local function elegirTipo(datos)
	local tirada = rng:NextNumber()
	if datos.clase == "Noble" then
		return if tirada < 0.6 then "Plaza" elseif tirada < 0.85 then "Calle" else "Tienda"
	end
	if tirada < 0.4 then
		return "Plaza"
	elseif tirada < 0.65 then
		return "Tienda"
	elseif tirada < 0.8 then
		return "Puerta"
	elseif tirada < 0.9 then
		return "Rasgo"
	end
	return "Calle"
end

-- ¿Está este sitio lejos de los demás NPC del pueblo (de donde están y de adonde van)?
local function sitioLibre(propio, p)
	for npc, otro in estado do
		if otro ~= propio and otro.pueblo == propio.pueblo and not otro.durmiendo then
			local r = otro.reserva
			if r and Vector3.new(r.X - p.X, 0, r.Z - p.Z).Magnitude < SEPARACION then
				return false
			end
			local raiz = raizDe(npc)
			if raiz and Vector3.new(raiz.Position.X - p.X, 0, raiz.Position.Z - p.Z).Magnitude < SEPARACION - 1 then
				return false
			end
		end
	end
	return true
end

local function puntoAlAzar(datos)
	local puntos = datos.puntos
	if #puntos == 0 then
		return nil
	end
	-- más a la plaza y a las tiendas que a las casas; nunca a un sitio ya ocupado
	for _ = 1, 14 do
		local tipo = elegirTipo(datos)
		local candidatos = {}
		for _, p in puntos do
			if p.Name == tipo then
				table.insert(candidatos, p.Value)
			end
		end
		if #candidatos == 0 then
			for _, p in puntos do
				if p.Name ~= "Callejon" then
					table.insert(candidatos, p.Value)
				end
			end
		end
		if #candidatos > 0 then
			local base = candidatos[rng:NextInteger(1, #candidatos)]
			local angulo = rng:NextNumber(0, math.pi * 2)
			local destino = base + Vector3.new(math.cos(angulo), 0, math.sin(angulo)) * rng:NextNumber(0, 3)
			if sitioLibre(datos, destino) then
				return destino
			end
		end
	end
	return nil -- todo lleno: se queda donde está
end

local function irseADormir(npc, datos)
	local casa = npc:GetAttribute("Casa")
	if casa then
		caminarA(npc, datos, casa)
	end
	datos.durmiendo = true
	datos.reserva = nil
	datos.padre = npc.Parent
	npc.Parent = dormitorio
end

local function despertar(npc, datos)
	local casa = npc:GetAttribute("Casa")
	if casa then
		local raiz = raizDe(npc)
		local humanoide = humanoideDe(npc)
		local altura = (humanoide and humanoide.HipHeight or 2) + (raiz and raiz.Size.Y / 2 or 1)
		npc:PivotTo(CFrame.new(casa + Vector3.new(0, altura, 0)))
		datos.reserva = casa
	end
	npc.Parent = datos.padre
	datos.durmiendo = false
end

local function rutinaPaseante(npc, datos)
	task.wait(rng:NextNumber(0, 8))
	while estado[npc] do
		if datos.ocupado then
			task.wait(0.5)
		elseif esDeNoche() then
			if not datos.durmiendo and datos.pueblo:GetAttribute("Activo") then
				irseADormir(npc, datos)
			elseif not datos.durmiendo then
				datos.padre = npc.Parent
				datos.durmiendo = true
				datos.reserva = nil
				npc.Parent = dormitorio
			end
			task.wait(5)
		elseif datos.durmiendo then
			despertar(npc, datos)
			task.wait(1)
		elseif not datos.pueblo:GetAttribute("Activo") then
			task.wait(3)
		else
			local destino = puntoAlAzar(datos)
			if destino then
				datos.reserva = destino -- este sitio ya es suyo: nadie más irá aquí
				if caminarA(npc, datos, destino) then
					datos.fallos = 0
				else
					local raiz = raizDe(npc)
					datos.reserva = raiz and raiz.Position or destino
					-- si se queda atascado varias veces seguidas, reaparece en una calle
					datos.fallos = (datos.fallos or 0) + 1
					if datos.fallos >= 3 and raiz then
						datos.fallos = 0
						local humanoide = humanoideDe(npc)
						local altura = (humanoide and humanoide.HipHeight or 2) + raiz.Size.Y / 2
						npc:PivotTo(CFrame.new(destino + Vector3.new(0, altura, 0)))
						datos.reserva = destino
					end
				end
			end
			-- se queda un rato y, si pasa un jugador, a veces le dice algo
			local espera = os.clock() + rng:NextNumber(6, 16)
			while os.clock() < espera and not datos.ocupado do
				local raiz = raizDe(npc)
				if raiz and rng:NextNumber() < 0.06 then
					local jugador, raizJugador = jugadorCerca(raiz.Position, 18)
					if jugador and (not datos.ultimoSaludo or os.clock() - datos.ultimoSaludo > 40) then
						datos.ultimoSaludo = os.clock()
						mirarA(npc, raizJugador.Position)
						local saludos = PueblosConfig.SALUDOS[datos.cultura]
						local lista = saludos and saludos[datos.clase]
						if lista then
							decir(npc, lista[rng:NextInteger(1, #lista)], 3)
							if datos.clase == "Plebeyo" and rng:NextNumber() < 0.5 then
								anim(datos, "Saludar")
							end
						end
					end
				end
				task.wait(1)
			end
		end
	end
end

-- ===== Escenas =====

local function libresDe(puebloModelo, rol, clase)
	local lista = {}
	for npc, datos in estado do
		if datos.pueblo == puebloModelo and datos.rol == rol and (clase == nil or datos.clase == clase) and not datos.ocupado and not datos.durmiendo and npc.Parent then
			table.insert(lista, npc)
		end
	end
	return lista
end

local function sacar(lista)
	if #lista == 0 then
		return nil
	end
	return table.remove(lista, rng:NextInteger(1, #lista))
end

local function esperarCaminando(npc)
	local limite = os.clock() + 2
	while estado[npc] and estado[npc].caminando and os.clock() < limite do
		task.wait(0.1)
	end
end

local function masCercano(lista, posicion, maximo)
	local mejor, distancia = nil, maximo or math.huge
	for _, npc in lista do
		local raiz = raizDe(npc)
		if raiz then
			local d = (raiz.Position - posicion).Magnitude
			if d < distancia then
				mejor, distancia = npc, d
			end
		end
	end
	return mejor
end

-- Callejones sin salida del pueblo (puntos "Callejon": el valor es el fondo, "Boca" la salida)
local callejonesEnUso = {}
local function elegirCallejon(puebloModelo, cerca)
	local carpeta = puebloModelo:FindFirstChild("Puntos")
	if not carpeta then
		return nil
	end
	local mejor, distancia = nil, 170
	for _, v in carpeta:GetChildren() do
		if v.Name == "Callejon" and not callejonesEnUso[v] then
			local d = (v.Value - cerca).Magnitude
			if d < distancia then
				mejor, distancia = v, d
			end
		end
	end
	return mejor
end

local function vivos(...)
	for _, npc in { ... } do
		if not (npc.Parent and raizDe(npc)) then
			return false
		end
	end
	return true
end

-- Camina en línea recta (para el último tramo dentro de un callejón, que es un pasillo recto)
local function andarRecto(npc, datos, destino)
	local raiz = raizDe(npc)
	local humanoide = humanoideDe(npc)
	if not (raiz and humanoide) then
		return
	end
	anclar(npc, false)
	pararAnim(datos, "Quieto")
	anim(datos, "Andar", humanoide.WalkSpeed / 7)
	datos.caminando = true
	humanoide:MoveTo(destino)
	local limite = os.clock() + 6
	while os.clock() < limite and Vector3.new(raiz.Position.X - destino.X, 0, raiz.Position.Z - destino.Z).Magnitude > 1.2 do
		task.wait(0.1)
	end
	humanoide:MoveTo(raiz.Position)
	datos.caminando = false
	pararAnim(datos, "Andar")
	anim(datos, "Quieto", 1)
	task.wait(0.2)
	anclar(npc, true)
end

-- Entra en el callejón: primero busca camino hasta la boca y luego sigue recto hasta el sitio
local function entrarCallejon(npc, datos, boca, destino)
	local ok = caminarA(npc, datos, boca, true)
	andarRecto(npc, datos, destino)
	return ok
end

-- Mensajes de prueba: workspace:SetAttribute("DepurarNPC", true)
local function depurar(...)
	if Workspace:GetAttribute("DepurarNPC") then
		print("[NPC]", ...)
	end
end

-- Un noble se lleva a un plebeyo a un callejón sin salida y allí lo humilla:
-- lo insulta, lo señala, lo empuja contra la pared y se ríe. Un testigo murmura.
local function escenaAbuso(puebloModelo, cultura)
	local textos = PueblosConfig.ESCENAS[cultura] and PueblosConfig.ESCENAS[cultura].Abuso
	if not textos then
		return false
	end
	local victima = sacar(libresDe(puebloModelo, "Paseante", "Plebeyo"))
	if not victima then
		return false
	end
	local rv = raizDe(victima)
	local callejon = rv and elegirCallejon(puebloModelo, rv.Position)
	local noble = callejon and masCercano(libresDe(puebloModelo, "Paseante", "Noble"), rv.Position)
	if not (callejon and noble) then
		return false
	end
	local dn, dv = estado[noble], estado[victima]
	dn.ocupado, dv.ocupado = "escena", "escena"
	callejonesEnUso[callejon] = true
	depurar(noble:GetAttribute("Nombre"), "se lleva a", victima:GetAttribute("Nombre"), "al callejón", callejon.Value)
	local function terminar()
		dn.ocupado, dv.ocupado = false, false
		callejonesEnUso[callejon] = nil
	end
	esperarCaminando(noble)
	esperarCaminando(victima)

	-- 1) el noble va a por el plebeyo y le ordena que lo siga
	local rn = raizDe(noble)
	caminarA(noble, dn, rv.Position + (rn.Position - rv.Position).Unit * 3.5, true)
	if not vivos(noble, victima) then
		terminar()
		return false
	end
	mirarA(noble, rv.Position)
	mirarA(victima, raizDe(noble).Position)
	decir(noble, textos.llevar or "Tú. Sígueme.", 3)
	anim(dn, "Senalar")
	task.wait(2.8)
	decir(victima, "¿Y-yo...?", 2)
	task.wait(1.6)

	-- 2) los dos van al fondo del callejón: el plebeyo delante y el noble
	--    detrás, tapándole la única salida
	local fondo = callejon.Value
	local boca = callejon:GetAttribute("Boca") or fondo
	local haciaBoca = Vector3.new(boca.X - fondo.X, 0, boca.Z - fondo.Z)
	haciaBoca = if haciaBoca.Magnitude > 0.1 then haciaBoca.Unit else Vector3.xAxis
	local sitioNoble = fondo + haciaBoca * 3.4
	dv.reserva, dn.reserva = fondo, sitioNoble
	local llego = false
	task.spawn(function()
		local ok = entrarCallejon(victima, dv, boca, fondo)
		depurar("plebeyo llegó a la boca:", ok)
		llego = true
	end)
	task.wait(2)
	local okNoble = entrarCallejon(noble, dn, boca + haciaBoca * 1.5, sitioNoble)
	depurar("noble llegó a la boca:", okNoble)
	local limite = os.clock() + 25
	while not llego and os.clock() < limite do
		task.wait(0.2)
	end
	if not vivos(noble, victima) then
		terminar()
		return false
	end
	rv = raizDe(victima)
	mirarA(victima, raizDe(noble).Position)
	mirarA(noble, rv.Position)

	-- 3) la humillación, sin testigos... casi
	decir(noble, textos.noble[1], 3.5)
	anim(dn, "Senalar")
	task.wait(3.2)
	decir(victima, textos.plebeyo[1], 3)
	task.wait(3)
	decir(noble, textos.noble[2], 3.5)
	task.wait(1.2)
	-- empujón: el plebeyo retrocede contra la pared del fondo
	local atras = rv.CFrame * CFrame.new(0, 0, 1.2) * CFrame.Angles(math.rad(-8), 0, 0)
	TweenService:Create(rv, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = atras }):Play()
	task.wait(0.6)
	TweenService:Create(rv, TweenInfo.new(0.5), { CFrame = rv.CFrame * CFrame.Angles(math.rad(8), 0, 0) }):Play()
	task.wait(1.6)
	decir(noble, textos.noble[3], 3.5)
	anim(dn, "Reir")
	task.wait(3)
	decir(victima, textos.plebeyo[3], 2.5)
	victima:SetAttribute("Humillado", os.time())
	-- alguien que pasaba cerca de la boca del callejón lo ha visto
	local testigo = masCercano(libresDe(puebloModelo, "Paseante", "Plebeyo"), boca, 45) or masCercano(libresDe(puebloModelo, "Tendero", nil), boca, 45)
	if testigo and textos.testigo then
		task.wait(2)
		decir(testigo, textos.testigo, 4)
	end
	-- el noble se va primero; el plebeyo se queda un momento antes de salir
	task.wait(2)
	andarRecto(noble, dn, boca + haciaBoca * 2)
	dn.ocupado = false
	task.wait(4)
	andarRecto(victima, dv, boca + haciaBoca * 2)
	terminar()
	depurar("escena del callejón terminada")
	return true
end

-- Dos vecinos se encuentran y cotillean
local function escenaChisme(puebloModelo, cultura)
	local a = sacar(libresDe(puebloModelo, "Paseante", "Plebeyo"))
	local b = sacar(libresDe(puebloModelo, "Paseante", "Plebeyo"))
	local chismes = PueblosConfig.ESCENAS[cultura] and PueblosConfig.ESCENAS[cultura].Chisme
	if not (a and b and chismes) then
		return false
	end
	local da, db = estado[a], estado[b]
	da.ocupado, db.ocupado = "escena", "escena"
	esperarCaminando(a)
	esperarCaminando(b)
	local rb = raizDe(b)
	local sitio = rb.Position + (raizDe(a).Position - rb.Position).Unit * 3
	da.reserva = sitio
	caminarA(a, da, sitio, true)
	if not (a.Parent and b.Parent) then
		da.ocupado, db.ocupado = false, false
		return false
	end
	mirarA(a, rb.Position)
	mirarA(b, raizDe(a).Position)
	local dialogo = chismes[rng:NextInteger(1, #chismes)]
	decir(a, dialogo[1], 4.5)
	task.wait(4.5)
	decir(b, dialogo[2], 4.5)
	task.wait(5)
	da.ocupado, db.ocupado = false, false
	return true
end

-- Para probar en Studio: workspace:SetAttribute("ForzarEscena", "Valdoria") lanza ya
-- la escena del callejón en ese pueblo.
local function bucleEscenas(puebloModelo)
	local cultura = puebloModelo:GetAttribute("Cultura")
	local centro = puebloModelo:GetAttribute("Centro")
	local siguiente = os.clock() + rng:NextNumber(20, 40)
	while puebloModelo.Parent do
		local forzada = Workspace:GetAttribute("ForzarEscena") == puebloModelo.Name
		if forzada then
			Workspace:SetAttribute("ForzarEscena", nil)
		end
		local toca = os.clock() >= siguiente and centro and not esDeNoche() and jugadorCerca(centro, (puebloModelo:GetAttribute("Radio") or 60) + 40)
		if forzada or toca then
			local ok, err = pcall(function()
				if forzada or rng:NextNumber() < 0.55 then
					if not escenaAbuso(puebloModelo, cultura) then
						if forzada then
							warn("[NPC] No se pudo montar la escena del callejón en", puebloModelo.Name)
						end
						escenaChisme(puebloModelo, cultura)
					end
				else
					escenaChisme(puebloModelo, cultura)
				end
			end)
			if not ok then
				warn("[NPC] Escena interrumpida:", err)
				-- si algo falla, liberamos a todos para que sigan con su vida
				for _, datos in estado do
					if datos.pueblo == puebloModelo and datos.ocupado == "escena" then
						datos.ocupado = false
					end
				end
			end
			siguiente = os.clock() + rng:NextNumber(50, 100)
		end
		task.wait(2)
	end
end

-- ===== Conversación con un jugador =====

local function soltar(npc)
	local datos = estado[npc]
	if not datos or datos.ocupado ~= "hablando" then
		return
	end
	datos.ocupado = false
	datos.hablandoCon = nil
	-- los que trabajan en un sitio vuelven a mirar hacia donde miraban
	if datos.rol ~= "Paseante" and datos.original then
		npc:PivotTo(datos.original)
	end
end

RemoteHablar.OnServerEvent:Connect(function(jugador, npc, empezar)
	if typeof(npc) ~= "Instance" or not estado[npc] then
		return
	end
	local datos = estado[npc]
	if not empezar then
		if datos.hablandoCon == jugador then
			soltar(npc)
		end
		return
	end
	local personaje = jugador.Character
	local raizJugador = personaje and personaje:FindFirstChild("HumanoidRootPart")
	local raiz = raizDe(npc)
	if not (raizJugador and raiz) or (raizJugador.Position - raiz.Position).Magnitude > DISTANCIA_HABLAR then
		return
	end
	if datos.ocupado == "escena" then
		return -- está en mitad de una escena
	end
	datos.ocupado = "hablando"
	datos.hablandoCon = jugador
	local limite = os.clock() + 6
	while datos.caminando and os.clock() < limite do
		task.wait(0.1)
	end
	mirarA(npc, raizJugador.Position)
	-- si el jugador se va o no cierra el diálogo, el NPC sigue con lo suyo
	task.delay(40, function()
		if datos.hablandoCon == jugador then
			soltar(npc)
		end
	end)
end)

-- ===== Arranque =====

local function registrar(npc)
	if estado[npc] or not npc:IsDescendantOf(Workspace) then
		return
	end
	-- el modelo del pueblo es el abuelo (Pueblo > carpeta NPC > personaje)
	local puebloModelo = npc.Parent and npc.Parent.Parent
	if not puebloModelo then
		return
	end
	local puntos = {}
	local carpetaPuntos = puebloModelo:FindFirstChild("Puntos")
	if carpetaPuntos then
		puntos = carpetaPuntos:GetChildren()
	end
	local datos = {
		rol = npc:GetAttribute("Rol") or "Tendero",
		clase = npc:GetAttribute("Clase") or "Plebeyo",
		cultura = npc:GetAttribute("Cultura"),
		pueblo = puebloModelo,
		puntos = puntos,
		original = npc:GetPivot(),
		ocupado = false,
		reserva = npc:GetPivot().Position, -- el sitio que ocupa (o al que va)
	}
	datos.pistas = cargarAnimaciones(npc)
	-- Hablar con G (la E queda para las habilidades). Cada jugador puede cambiarla en su menú.
	for _, boton in npc:GetDescendants() do
		if boton:IsA("ProximityPrompt") then
			boton.KeyboardKeyCode = Enum.KeyCode.G
		end
	end
	estado[npc] = datos
	anim(datos, "Quieto", rng:NextNumber(0.85, 1.1))
	if datos.pistas.Quieto then
		task.defer(function()
			if datos.pistas.Quieto.Length > 0 then
				datos.pistas.Quieto.TimePosition = rng:NextNumber(0, datos.pistas.Quieto.Length)
			end
		end)
	end
	if datos.rol == "Paseante" then
		task.spawn(rutinaPaseante, npc, datos)
	end
end

function NPCServicio.Iniciar()
	for _, npc in CollectionService:GetTagged("NPC") do
		registrar(npc)
	end
	-- Pueblos "despiertos" (con jugadores cerca) y sus escenas
	local mundo = Workspace:FindFirstChild("Mundo")
	local pueblos = mundo and mundo:FindFirstChild("Pueblos")
	if pueblos then
		for _, puebloModelo in pueblos:GetChildren() do
			task.spawn(bucleEscenas, puebloModelo)
		end
		task.spawn(function()
			while true do
				for _, puebloModelo in pueblos:GetChildren() do
					local centro = puebloModelo:GetAttribute("Centro")
					local radio = puebloModelo:GetAttribute("Radio") or 60
					puebloModelo:SetAttribute("Activo", centro ~= nil and jugadorCerca(centro, radio + DISTANCIA_ACTIVO) ~= nil)
				end
				task.wait(2)
			end
		end)
	end
	print("[SERVIDOR] NPC listos:", #CollectionService:GetTagged("NPC"))
end

return NPCServicio

-- Misiones de la HISTORIA (Acto I) y el Custodio Eldren. SOLO servidor.
-- Ruta en Studio: ServerScriptService/Historia/MisionesServicio
--
-- El progreso vive en CharacterData.Historia:
--   Mision      número de la misión actual (ReplicatedStorage/Config/HistoriaConfig.MISIONES)
--   Progreso    contador del objetivo (p. ej. golpes dados)
--   Textos      { [idTexto] = true } textos antiguos que ya leyó (sus "Crónicas")
--   PrologoVisto  si ya vio la cinemática del principio
-- Otros servicios avisan con MisionesServicio.Evento(jugador, tipo, dato):
--   "Golpe" (CombateServicio), "Leer" (RuinasServicio), "Hablar" (el Custodio).
-- Al cliente le llegan mensajes por Remotes/Historia:
--   "Mision"     estado de la misión actual (para el rastreador y el menú)
--   "Completada" misión terminada con su recompensa
--   "Dialogo"    lo que dice un personaje (nombre, lineas)
--   "Texto"      abre un texto antiguo
--
-- Pruebas en Studio (vista Server): game.Players:GetPlayers()[1]:SetAttribute("PruebaMision", 3)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HistoriaConfig = require(ReplicatedStorage.Config.HistoriaConfig)
local ProgresionConfig = require(ReplicatedStorage.Config.ProgresionConfig)
local RegionesConfig = require(ReplicatedStorage.Config.RegionesConfig)
local DatosServicio = require(script.Parent.Parent.Progresion.DatosServicio)
local PersonajeServicio = require(script.Parent.Parent.Progresion.PersonajeServicio)
local AparienciaServicio = require(script.Parent.Parent.Progresion.AparienciaServicio)
local RuinasServicio = require(script.Parent.RuinasServicio)

local Remoto = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Historia")

local MisionesServicio = {}

local custodio = nil -- modelo del Custodio
local cachePueblos = {}

local function historia(datos)
	return datos.Historia
end

local function centroPueblo(nombre)
	local guardado = cachePueblos[nombre]
	if guardado then
		return guardado.centro, guardado.radio
	end
	for _, objeto in Workspace:GetDescendants() do
		if objeto:IsA("Model") and objeto:GetAttribute("Nombre") == nombre then
			local centro = objeto:GetAttribute("Centro")
			if typeof(centro) == "Vector3" then
				cachePueblos[nombre] = { centro = centro, radio = objeto:GetAttribute("Radio") or 120 }
				return centro, cachePueblos[nombre].radio
			end
		end
	end
	return nil
end

-- ¿Ya cumplió el objetivo de la misión?
local function cumplido(h, mision)
	local o = mision.objetivo
	if o.tipo == "Leer" then
		for _, id in o.textos do
			if not h.Textos[id] then
				return false
			end
		end
		return true
	elseif o.tipo == "Golpes" then
		return h.Progreso >= o.cantidad
	end
	return false -- Hablar y Visitar se cumplen con su evento
end

-- Dónde está el objetivo (para la marca en pantalla)
local function destino(h, mision)
	local o = mision.objetivo
	if o.tipo == "Hablar" then
		local raiz = custodio and custodio:FindFirstChild("HumanoidRootPart")
		return raiz and raiz.Position
	elseif o.tipo == "Golpes" then
		local muneco = Workspace:FindFirstChild("Entrenamiento")
		local primero = muneco and muneco:FindFirstChildWhichIsA("Model")
		return primero and primero:GetPivot().Position
	elseif o.tipo == "Leer" then
		for _, id in o.textos do
			if not h.Textos[id] then
				return RuinasServicio.PosicionTexto(id)
			end
		end
	elseif o.tipo == "Visitar" then
		return (centroPueblo(o.pueblo))
	end
	return nil
end

-- Estado de la misión para el cliente
local function estado(datos)
	local h = historia(datos)
	local mision = HistoriaConfig.Mision(h.Mision)
	if not mision then
		return {
			acto = HistoriaConfig.ACTO,
			fin = true,
			titulo = "Fin del Acto I",
			objetivo = "La historia continúa pronto.",
		}
	end
	local o = mision.objetivo
	local hechos, total = 0, 0
	if o.tipo == "Leer" then
		total = #o.textos
		for _, id in o.textos do
			if h.Textos[id] then
				hechos += 1
			end
		end
	elseif o.tipo == "Golpes" then
		total = o.cantidad
		hechos = math.min(h.Progreso, o.cantidad)
	end
	return {
		acto = HistoriaConfig.ACTO,
		numero = h.Mision,
		titulo = mision.titulo,
		descripcion = mision.descripcion,
		objetivo = o.texto,
		hechos = hechos,
		total = total,
		destino = destino(h, mision),
	}
end

local function enviarEstado(jugador)
	local datos = DatosServicio.Obtener(jugador)
	if datos then
		Remoto:FireClient(jugador, "Mision", estado(datos))
	end
end

local function decir(jugador, lineas)
	Remoto:FireClient(
		jugador,
		"Dialogo",
		HistoriaConfig.CUSTODIO.nombre .. " · " .. HistoriaConfig.CUSTODIO.titulo,
		lineas
	)
end

-- Termina la misión actual, da la recompensa y pasa a la siguiente
local function completar(jugador)
	local datos = DatosServicio.Obtener(jugador)
	if not datos then
		return
	end
	local h = historia(datos)
	local mision = HistoriaConfig.Mision(h.Mision)
	if not mision then
		return
	end
	local r = mision.recompensa or {}
	DatosServicio.Modificar(jugador, function(d)
		d.Historia.Mision += 1
		d.Historia.Progreso = 0
		d.Giros.Raza += r.GirosRaza or 0
		d.Giros.Afinidad += r.GirosAfinidad or 0
	end)
	if r.Exp then
		PersonajeServicio.DarExperiencia(jugador, r.Exp)
	end
	if r.Oro then
		PersonajeServicio.DarOro(jugador, r.Oro)
	end
	Remoto:FireClient(jugador, "Completada", { titulo = mision.titulo, recompensa = r })
	if mision.dialogo then
		decir(jugador, mision.dialogo)
	end
	-- la siguiente puede estar cumplida ya (por ejemplo, textos leídos antes)
	local siguiente = HistoriaConfig.Mision(datos.Historia.Mision)
	if siguiente and cumplido(datos.Historia, siguiente) then
		task.delay(1, completar, jugador)
	elseif not siguiente then
		task.delay(2, decir, jugador, HistoriaConfig.FIN_DEL_ACTO)
	end
	enviarEstado(jugador)
end

-- Aviso de otros servicios
function MisionesServicio.Evento(jugador, tipo, dato)
	local datos = DatosServicio.Obtener(jugador)
	if not datos or jugador:GetAttribute("EnMenu") then
		return
	end
	local h = historia(datos)
	local mision = HistoriaConfig.Mision(h.Mision)
	if tipo == "Leer" then
		local nuevo = not h.Textos[dato]
		DatosServicio.Modificar(jugador, function(d)
			d.Historia.Textos[dato] = true
		end, true)
		Remoto:FireClient(jugador, "Texto", dato, nuevo)
	end
	if not mision then
		return
	end
	local o = mision.objetivo
	if tipo == "Hablar" and o.tipo == "Hablar" and o.objetivo == dato then
		completar(jugador)
	elseif tipo == "Golpe" and o.tipo == "Golpes" then
		DatosServicio.Modificar(jugador, function(d)
			d.Historia.Progreso += 1
		end, true)
		if cumplido(h, mision) then
			completar(jugador)
		elseif h.Progreso % 3 == 0 then
			enviarEstado(jugador)
		end
	elseif tipo == "Leer" and o.tipo == "Leer" then
		if cumplido(h, mision) then
			completar(jugador)
		else
			enviarEstado(jugador)
		end
	elseif tipo == "Visitar" and o.tipo == "Visitar" and o.pueblo == dato then
		completar(jugador)
	end
end

-- ===== El Custodio Eldren =====
local function suelo(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local rayo = Workspace:Raycast(Vector3.new(x, 800, z), Vector3.new(0, -1000, 0), params)
	return rayo and rayo.Position.Y or 40
end

local function crearCustodio()
	local inicio = ProgresionConfig.APARICION_INICIAL
		or Vector3.new(RegionesConfig.INICIO.X, 60, RegionesConfig.INICIO.Y)
	local d = HistoriaConfig.CUSTODIO.desplazamiento
	local x, z = inicio.X + d.X, inicio.Z + d.Z
	local descripcion = AparienciaServicio.Descripcion({
		Genero = "Hombre",
		Piel = 2,
		Cara = 3,
		Pelo = 15,
		Barba = 3,
		Ropa = "Encapuchado",
		Altura = 1.02,
	})
	local ok, modelo = pcall(function()
		return Players:CreateHumanoidModelFromDescription(descripcion, Enum.HumanoidRigType.R15)
	end)
	descripcion:Destroy()
	if not ok or not modelo then
		warn("[HISTORIA] No pude crear al Custodio", modelo)
		return
	end
	modelo.Name = "Custodio " .. HistoriaConfig.CUSTODIO.nombre
	modelo:SetAttribute("Historia", "Custodio")
	local humanoide = modelo:FindFirstChildOfClass("Humanoid")
	humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local raiz = modelo:WaitForChild("HumanoidRootPart")
	raiz.Anchored = true
	local y = suelo(x, z) + humanoide.HipHeight + raiz.Size.Y / 2
	modelo:PivotTo(CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(inicio.X, y, inicio.Z)))
	modelo.Parent = Workspace:FindFirstChild("Historia") or Workspace

	-- cartel con el nombre
	local cartel = Instance.new("BillboardGui")
	cartel.Size = UDim2.fromOffset(260, 46)
	cartel.StudsOffset = Vector3.new(0, 3.4, 0)
	cartel.MaxDistance = 70
	cartel.Adornee = modelo:FindFirstChild("Head")
	cartel.Parent = modelo
	local nombre = Instance.new("TextLabel")
	nombre.BackgroundTransparency = 1
	nombre.Size = UDim2.new(1, 0, 0, 26)
	nombre.Font = Enum.Font.Garamond
	nombre.TextSize = 24
	nombre.TextColor3 = Color3.fromRGB(228, 184, 96)
	nombre.TextStrokeTransparency = 0.4
	nombre.Text = HistoriaConfig.CUSTODIO.nombre
	nombre.Parent = cartel
	local titulo = Instance.new("TextLabel")
	titulo.BackgroundTransparency = 1
	titulo.Position = UDim2.fromOffset(0, 24)
	titulo.Size = UDim2.new(1, 0, 0, 18)
	titulo.Font = Enum.Font.GothamMedium
	titulo.TextSize = 13
	titulo.TextColor3 = Color3.fromRGB(200, 170, 255)
	titulo.TextStrokeTransparency = 0.5
	titulo.Text = HistoriaConfig.CUSTODIO.titulo
	titulo.Parent = cartel

	-- un poco de luz mágica alrededor
	local adjunto = Instance.new("Attachment")
	adjunto.Parent = raiz
	local motas = Instance.new("ParticleEmitter")
	motas.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motas.Color = ColorSequence.new(HistoriaConfig.COLOR_ECLIPSE)
	motas.LightEmission = 1
	motas.Size = NumberSequence.new(0.18, 0)
	motas.Lifetime = NumberRange.new(1.5, 2.5)
	motas.Speed = NumberRange.new(0.3, 0.8)
	motas.SpreadAngle = Vector2.new(180, 180)
	motas.Rate = 4
	motas.Parent = adjunto

	local boton = Instance.new("ProximityPrompt")
	boton.Name = "Hablar"
	boton.ActionText = "Hablar"
	boton.ObjectText = HistoriaConfig.CUSTODIO.nombre
	boton.KeyboardKeyCode = Enum.KeyCode.G
	boton.MaxActivationDistance = 12
	boton.RequiresLineOfSight = false
	boton.Parent = raiz
	boton.Triggered:Connect(function(jugador)
		local datos = DatosServicio.Obtener(jugador)
		if not datos then
			return
		end
		local mision = HistoriaConfig.Mision(datos.Historia.Mision)
		if mision and mision.objetivo.tipo == "Hablar" then
			MisionesServicio.Evento(jugador, "Hablar", "Custodio")
		elseif mision then
			decir(jugador, { "Ahora tu tarea es esta: " .. mision.objetivo.texto .. ".", mision.descripcion })
		else
			decir(jugador, HistoriaConfig.FIN_DEL_ACTO)
		end
	end)
	custodio = modelo
end

-- ===== Arranque =====
function MisionesServicio.Iniciar()
	RuinasServicio.Iniciar(function(jugador, idTexto)
		MisionesServicio.Evento(jugador, "Leer", idTexto)
	end)
	task.spawn(crearCustodio)

	Remoto.OnServerEvent:Connect(function(jugador, accion)
		if accion == "Pedir" then
			enviarEstado(jugador)
		elseif accion == "PrologoVisto" then
			DatosServicio.Modificar(jugador, function(d)
				d.Historia.PrologoVisto = true
			end)
			enviarEstado(jugador)
		end
	end)

	DatosServicio.Cargado.Event:Connect(enviarEstado)
	Players.PlayerAdded:Connect(function(jugador)
		jugador:GetAttributeChangedSignal("EnMenu"):Connect(function()
			if jugador:GetAttribute("EnMenu") == false then
				enviarEstado(jugador)
			end
		end)
		if RunService:IsStudio() then
			jugador:GetAttributeChangedSignal("PruebaMision"):Connect(function()
				local numero = jugador:GetAttribute("PruebaMision")
				if type(numero) == "number" then
					DatosServicio.Modificar(jugador, function(d)
						d.Historia.Mision = numero
						d.Historia.Progreso = 0
					end)
					enviarEstado(jugador)
				end
			end)
		end
	end)

	-- Visitar pueblos y refrescar la marca del objetivo
	task.spawn(function()
		while true do
			task.wait(2)
			for _, jugador in Players:GetPlayers() do
				local datos = DatosServicio.Obtener(jugador)
				local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart")
				local mision = datos and HistoriaConfig.Mision(datos.Historia.Mision)
				if mision and raiz and mision.objetivo.tipo == "Visitar" then
					local centro, radio = centroPueblo(mision.objetivo.pueblo)
					if
						centro
						and (Vector3.new(raiz.Position.X, centro.Y, raiz.Position.Z) - centro).Magnitude < radio
					then
						MisionesServicio.Evento(jugador, "Visitar", mision.objetivo.pueblo)
					end
				end
			end
		end
	end)
end

return MisionesServicio

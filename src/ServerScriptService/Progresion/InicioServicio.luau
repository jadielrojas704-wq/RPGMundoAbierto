-- Pantalla de inicio en el SERVIDOR: Jugar, Personalizar (aspecto y nombre), giros de raza
-- y de afinidad mágica, y códigos. El cliente solo PIDE; aquí se comprueba todo.
-- Ruta en Studio: ServerScriptService/Progresion/InicioServicio
--
-- Mientras el jugador está en el menú (atributo "EnMenu"):
--   * su personaje está quieto (anclado) donde aparece
--   * no puede atacar ni esquivar (los servicios de combate lo comprueban)
-- Remoto: ReplicatedStorage/Remotes/MenuInicio (RemoteFunction)
--   ("Estado")                    -> lo que el menú necesita enseñar
--   ("Jugar")                     -> entra al juego
--   ("Apariencia", campo, valor)  -> cambia una parte del aspecto
--   ("Nombre", texto)             -> pone el nombre del personaje (filtrado por Roblox)
--   ("Girar", "Raza"/"Afinidad")  -> gasta un giro y devuelve lo que ha salido
--   ("Codigo", texto)             -> canjea un código

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local AparienciaConfig = require(ReplicatedStorage.Config.AparienciaConfig)
local RazasConfig = require(ReplicatedStorage.Config.RazasConfig)
local DatosServicio = require(script.Parent.DatosServicio)
local PersonajeServicio = require(script.Parent.PersonajeServicio)
local AparienciaServicio = require(script.Parent.AparienciaServicio)
local Codigos = require(script.Parent.CodigosConfig)

local Remoto = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MenuInicio")

local InicioServicio = {}

local aleatorio = Random.new()
local ultimo = {} -- [jugador] = { [accion] = tiempo } (límite de peticiones)

local ESPERA = { Apariencia = 0.12, Nombre = 1.5, Girar = 1.2, Codigo = 1.5, Estado = 0.3, Jugar = 1 }

local function demasiadoRapido(jugador, accion)
	local t = ultimo[jugador]
	if not t then
		t = {}
		ultimo[jugador] = t
	end
	local ahora = os.clock()
	if t[accion] and ahora - t[accion] < (ESPERA[accion] or 0.5) then
		return true
	end
	t[accion] = ahora
	return false
end

-- Ancla o suelta el personaje (quieto mientras está en el menú)
local function anclar(jugador, quieto)
	local personaje = jugador.Character
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if raiz then
		raiz.Anchored = quieto
	end
end

local function estado(jugador)
	local d = DatosServicio.Obtener(jugador)
	if not d then
		return { cargando = true }
	end
	return {
		Nombre = d.Nombre,
		Raza = d.Raza,
		AfinidadMagica = d.AfinidadMagica,
		Giros = table.clone(d.Giros),
		Apariencia = table.clone(d.Apariencia),
		Creado = d.Creado,
		PrologoVisto = d.Historia and d.Historia.PrologoVisto,
		Mision = d.Historia and d.Historia.Mision,
	}
end

-- La primera vez, la raza y la afinidad salen gratis
local function primeraTirada(jugador)
	DatosServicio.Modificar(jugador, function(d)
		if not RazasConfig.RAZA_POR_ID[d.Raza] then
			d.Raza = RazasConfig.Tirar(RazasConfig.RAZAS, aleatorio).id
		end
		if not RazasConfig.AFINIDAD_POR_ID[d.AfinidadMagica] then
			d.AfinidadMagica = RazasConfig.Tirar(RazasConfig.AFINIDADES, aleatorio).id
		end
	end)
	PersonajeServicio.Aplicar(jugador)
end

-- ===== Acciones =====
local ACCIONES = {}

function ACCIONES.Estado(jugador)
	return estado(jugador)
end

function ACCIONES.Jugar(jugador)
	if not DatosServicio.Obtener(jugador) then
		return { ok = false, mensaje = "Tus datos todavía se están cargando..." }
	end
	DatosServicio.Modificar(jugador, function(d)
		d.Creado = true
		if d.Nombre == "" then
			d.Nombre = jugador.DisplayName
		end
	end)
	jugador:SetAttribute("EnMenu", false)
	anclar(jugador, false)
	return { ok = true }
end

function ACCIONES.Apariencia(jugador, campo, valor)
	if type(campo) ~= "string" or not AparienciaConfig.EsValido(campo, valor) then
		return { ok = false }
	end
	DatosServicio.Modificar(jugador, function(d)
		d.Apariencia[campo] = valor
		-- un conjunto que es solo de un género cambia el cuerpo a ese género
		if campo == "Ropa" then
			local ropa = AparienciaConfig.ROPA_POR_ID[valor]
			if ropa.genero then
				d.Apariencia.Genero = ropa.genero
			end
		end
	end, true)
	AparienciaServicio.Aplicar(jugador)
	return { ok = true, Apariencia = table.clone(DatosServicio.Obtener(jugador).Apariencia) }
end

function ACCIONES.Nombre(jugador, texto)
	if type(texto) ~= "string" then
		return { ok = false, mensaje = "Nombre no válido." }
	end
	texto = texto:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
	local largo = utf8.len(texto) or #texto
	if largo < 3 or largo > 20 then
		return { ok = false, mensaje = "El nombre debe tener entre 3 y 20 letras." }
	end
	if not texto:match("^[%wáéíóúÁÉÍÓÚñÑüÜ ]+$") then
		return { ok = false, mensaje = "Solo letras, números y espacios." }
	end
	-- filtro de Roblox (obligatorio para texto que ven otros jugadores)
	local ok, filtrado = pcall(function()
		local resultado = TextService:FilterStringAsync(texto, jugador.UserId)
		return resultado:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		return { ok = false, mensaje = "No se pudo comprobar el nombre. Prueba otra vez." }
	end
	if filtrado ~= texto then
		return { ok = false, mensaje = "Ese nombre no está permitido." }
	end
	DatosServicio.Modificar(jugador, function(d)
		d.Nombre = texto
	end)
	return { ok = true, Nombre = texto }
end

function ACCIONES.Girar(jugador, tipo)
	if tipo ~= "Raza" and tipo ~= "Afinidad" then
		return { ok = false }
	end
	local d = DatosServicio.Obtener(jugador)
	if not d then
		return { ok = false, mensaje = "Cargando..." }
	end
	if (d.Giros[tipo] or 0) <= 0 then
		return { ok = false, mensaje = "No te quedan giros. Consigue más con códigos." }
	end
	local lista = if tipo == "Raza" then RazasConfig.RAZAS else RazasConfig.AFINIDADES
	local salida = RazasConfig.Tirar(lista, aleatorio)
	DatosServicio.Modificar(jugador, function(datos)
		datos.Giros[tipo] -= 1
		if tipo == "Raza" then
			datos.Raza = salida.id
		else
			datos.AfinidadMagica = salida.id
		end
	end)
	PersonajeServicio.Aplicar(jugador)
	return { ok = true, id = salida.id, Giros = table.clone(d.Giros) }
end

function ACCIONES.Codigo(jugador, texto)
	if type(texto) ~= "string" or #texto > 40 then
		return { ok = false, mensaje = "Código no válido." }
	end
	local codigo = texto:upper():gsub("%s", "")
	local premio = Codigos[codigo]
	if not premio or not premio.activo then
		return { ok = false, mensaje = "Ese código no existe o ha caducado." }
	end
	local d = DatosServicio.Obtener(jugador)
	if not d then
		return { ok = false, mensaje = "Cargando..." }
	end
	if d.CodigosUsados[codigo] then
		return { ok = false, mensaje = "Ya usaste este código." }
	end
	DatosServicio.Modificar(jugador, function(datos)
		datos.CodigosUsados[codigo] = true
		datos.Giros.Raza += premio.GirosRaza or 0
		datos.Giros.Afinidad += premio.GirosAfinidad or 0
	end)
	if premio.Oro then
		PersonajeServicio.DarOro(jugador, premio.Oro)
	end
	local partes = {}
	if premio.GirosRaza then
		table.insert(partes, "+" .. premio.GirosRaza .. " giros de raza")
	end
	if premio.GirosAfinidad then
		table.insert(partes, "+" .. premio.GirosAfinidad .. " giros de afinidad")
	end
	if premio.Oro then
		table.insert(partes, "+" .. premio.Oro .. " de oro")
	end
	return { ok = true, mensaje = "¡Código canjeado! " .. table.concat(partes, ", "), Giros = table.clone(d.Giros) }
end

-- ===== Arranque =====

function InicioServicio.Iniciar()
	Remoto.OnServerInvoke = function(jugador, accion, a, b)
		local funcion = ACCIONES[accion]
		if type(accion) ~= "string" or not funcion then
			return { ok = false }
		end
		if demasiadoRapido(jugador, accion) then
			return { ok = false, mensaje = "Espera un momento..." }
		end
		local ok, resultado = pcall(funcion, jugador, a, b)
		if not ok then
			warn("[INICIO]", accion, resultado)
			return { ok = false, mensaje = "Algo falló. Prueba otra vez." }
		end
		return resultado
	end

	local function alEntrar(jugador)
		jugador:SetAttribute("EnMenu", true)
		jugador.CharacterAdded:Connect(function(personaje)
			local raiz = personaje:WaitForChild("HumanoidRootPart", 10)
			if raiz and jugador:GetAttribute("EnMenu") then
				task.wait(0.4) -- deja que PersonajeServicio lo coloque primero
				anclar(jugador, jugador:GetAttribute("EnMenu") == true)
			end
		end)
		if jugador.Character then
			anclar(jugador, true)
		end
	end
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		alEntrar(jugador)
	end
	DatosServicio.Cargado.Event:Connect(primeraTirada)
	Players.PlayerRemoving:Connect(function(jugador)
		ultimo[jugador] = nil
	end)

	-- En Studio: workspace:SetAttribute("SaltarMenu", true) entra directo al juego
	if RunService:IsStudio() then
		task.spawn(function()
			while true do
				task.wait(1)
				if workspace:GetAttribute("SaltarMenu") then
					for _, jugador in Players:GetPlayers() do
						if jugador:GetAttribute("EnMenu") then
							ACCIONES.Jugar(jugador)
						end
					end
				end
			end
		end)
	end
end

return InicioServicio

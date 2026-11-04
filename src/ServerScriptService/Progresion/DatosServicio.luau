-- Guarda y carga el CharacterData de cada jugador con DataStore. SOLO en el servidor.
-- Ruta en Studio: ServerScriptService/Progresion/DatosServicio
--
-- Seguridad:
--   * Bloqueo de sesión: mientras un servidor tiene abierto a un jugador, ningún otro
--     servidor puede guardar encima (así no se duplican objetos al cambiar de servidor).
--   * Siempre con UpdateAsync y reintentos si Roblox falla.
--   * Autoguardado cada ProgresionConfig.AUTOGUARDADO segundos, al salir y al cerrar el servidor.
--   * El cliente NUNCA escribe aquí: solo recibe una copia para dibujar la interfaz.
--
-- En Studio sin "Acceso a servicios de API" (o sin publicar el juego) el DataStore no
-- funciona: entonces los datos viven solo en memoria y se avisa en la consola.
--
-- Uso desde otros servicios del servidor:
--   local datos = DatosServicio.Obtener(jugador)       -- nil si aún no ha cargado
--   DatosServicio.Modificar(jugador, function(datos) datos.Oro += 10 end)
--   DatosServicio.Cargado.Event:Connect(function(jugador, datos) ... end)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProgresionConfig = require(ReplicatedStorage.Config.ProgresionConfig)
local Plantilla = require(ReplicatedStorage.Progresion.PlantillaPersonaje)

local RemoteDatos = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DatosPersonaje")

local DatosServicio = {}

-- Aviso para los demás servicios cuando los datos de un jugador están listos
DatosServicio.Cargado = Instance.new("BindableEvent")

local NOMBRE_ALMACEN = if RunService:IsStudio() then "PersonajesStudio_v1" else "Personajes_v1"
local BLOQUEO_CADUCA = 600 -- segundos: un bloqueo más viejo es de un servidor que se cayó
local REINTENTOS = 5

local almacen = nil
local soloMemoria = false
local sesiones = {} -- [jugador] = { datos = tabla, sucio = bool, enviar = bool }

local function avisarMemoria(motivo)
	if not soloMemoria then
		soloMemoria = true
		warn("[DATOS] El DataStore no está disponible (" .. tostring(motivo) .. ").")
		warn("[DATOS] Los datos se guardan SOLO en memoria: se pierden al cerrar. Para guardar de verdad:")
		warn("[DATOS]   publica el juego y activa Game Settings > Security > Enable Studio Access to API Services.")
	end
end

local function clave(jugador)
	return "Jugador_" .. jugador.UserId
end

-- Repite una llamada al DataStore si falla (Roblox a veces da errores temporales)
local function conReintentos(funcion)
	local ultimoError
	for intento = 1, REINTENTOS do
		local ok, resultado = pcall(funcion)
		if ok then
			return true, resultado
		end
		ultimoError = resultado
		local texto = tostring(resultado)
		if texto:find("403") or texto:find("Studio") or texto:find("publish") or texto:find("API") then
			break -- no es un fallo temporal: el DataStore no está permitido aquí
		end
		task.wait(intento * 1.5)
	end
	return false, ultimoError
end

-- Cambios de formato entre versiones (vacío por ahora: estamos en la versión 1)
local function migrar(datos)
	datos.Version = datos.Version or 1
	-- if datos.Version < 2 then ... datos.Version = 2 end
	return datos
end

-- ===== Copia para el cliente =====

local function enviar(jugador)
	local sesion = sesiones[jugador]
	if sesion then
		sesion.enviar = true
	end
end

-- Atributos públicos (los ven todos los jugadores, p. ej. para el nombre sobre la cabeza)
local function publicar(jugador, datos)
	jugador:SetAttribute("NombrePersonaje", datos.Nombre)
	jugador:SetAttribute("Nivel", datos.Nivel)
	jugador:SetAttribute("Clase", datos.Clase)
	jugador:SetAttribute("Subclase", datos.Subclase)
	jugador:SetAttribute("Raza", datos.Raza)
end

-- ===== Cargar =====

local function cargar(jugador)
	local datosGuardados = nil
	local bloqueadoPorOtro = false

	if almacen and not soloMemoria then
		for espera = 1, 4 do
			bloqueadoPorOtro = false
			local robar = espera == 4 -- tras ~20 s, el otro servidor ya debería haber soltado
			local ok, resultado = conReintentos(function()
				return almacen:UpdateAsync(clave(jugador), function(viejo)
					viejo = viejo or {}
					local bloqueo = viejo.Bloqueo
					if bloqueo and bloqueo.Sesion ~= game.JobId and os.time() - (bloqueo.Tiempo or 0) < BLOQUEO_CADUCA and not robar then
						bloqueadoPorOtro = true
						return nil -- no tocamos nada: otro servidor lo tiene abierto
					end
					viejo.Bloqueo = { Sesion = game.JobId, Tiempo = os.time() }
					return viejo
				end)
			end)
			if not ok then
				avisarMemoria(resultado)
				break
			end
			if not bloqueadoPorOtro then
				datosGuardados = resultado and resultado.Datos
				break
			end
			task.wait(6)
		end
	end

	if not jugador.Parent then
		return -- se fue mientras cargaba
	end

	local datos = if datosGuardados then migrar(datosGuardados) else Plantilla.Nueva()
	Plantilla.Completar(datos)
	if datos.Nombre == "" then
		datos.Nombre = jugador.DisplayName
	end
	datos.Registro.UltimaConexion = os.time()

	sesiones[jugador] = { datos = datos, sucio = datosGuardados == nil, enviar = true, entrada = os.clock() }
	publicar(jugador, datos)
	print(string.format("[DATOS] %s cargado (nivel %d, %s)", jugador.Name, datos.Nivel, if datosGuardados then "guardado" elseif soloMemoria then "nuevo, solo memoria" else "nuevo"))
	DatosServicio.Cargado:Fire(jugador, datos)
end

-- ===== Guardar =====

-- soltar = true al salir: libera el bloqueo para que otro servidor pueda abrirlo
local function guardar(jugador, soltar)
	local sesion = sesiones[jugador]
	if not sesion then
		return
	end
	local datos = sesion.datos
	datos.Registro.TiempoJugado += math.floor(os.clock() - sesion.entrada)
	sesion.entrada = os.clock()
	if soloMemoria or not almacen then
		sesion.sucio = false
		return
	end
	local robado = false
	local ok, err = conReintentos(function()
		return almacen:UpdateAsync(clave(jugador), function(viejo)
			viejo = viejo or {}
			local bloqueo = viejo.Bloqueo
			if bloqueo and bloqueo.Sesion ~= game.JobId then
				robado = true
				return nil -- otro servidor tomó el personaje: no escribimos encima
			end
			viejo.Datos = datos
			viejo.Bloqueo = if soltar then nil else { Sesion = game.JobId, Tiempo = os.time() }
			return viejo
		end)
	end)
	if not ok then
		warn("[DATOS] No se pudo guardar a " .. jugador.Name .. ": " .. tostring(err))
	elseif robado then
		warn("[DATOS] " .. jugador.Name .. " está abierto en otro servidor; no se guardó aquí.")
	else
		sesion.sucio = false
	end
end

-- ===== API para otros servicios =====

function DatosServicio.Obtener(jugador)
	local sesion = sesiones[jugador]
	return sesion and sesion.datos
end

-- Espera a que los datos estén cargados (como mucho "limite" segundos)
function DatosServicio.Esperar(jugador, limite)
	local fin = os.clock() + (limite or 30)
	while not sesiones[jugador] and jugador.Parent and os.clock() < fin do
		task.wait(0.1)
	end
	return DatosServicio.Obtener(jugador)
end

-- Cambia los datos de un jugador. Marca que hay que guardar y avisa al cliente.
-- silencioso = true: guarda, pero no le manda la copia al cliente (p. ej. la ubicación)
function DatosServicio.Modificar(jugador, funcion, silencioso)
	local sesion = sesiones[jugador]
	if not sesion then
		return nil
	end
	local resultado = funcion(sesion.datos)
	sesion.sucio = true
	if not silencioso then
		enviar(jugador)
		publicar(jugador, sesion.datos)
	end
	return resultado
end

function DatosServicio.SoloMemoria()
	return soloMemoria
end

-- ===== Arranque =====

function DatosServicio.Iniciar()
	local ok, resultado = pcall(function()
		return DataStoreService:GetDataStore(NOMBRE_ALMACEN)
	end)
	if ok then
		almacen = resultado
	else
		avisarMemoria(resultado)
	end

	Players.PlayerAdded:Connect(function(jugador)
		cargar(jugador)
	end)
	for _, jugador in Players:GetPlayers() do
		task.spawn(cargar, jugador)
	end
	Players.PlayerRemoving:Connect(function(jugador)
		guardar(jugador, true)
		sesiones[jugador] = nil
	end)

	-- Al cerrar el servidor, se guarda a todos a la vez
	game:BindToClose(function()
		local pendientes = 0
		for jugador in sesiones do
			pendientes += 1
			task.spawn(function()
				guardar(jugador, true)
				pendientes -= 1
			end)
		end
		local limite = os.clock() + 25
		while pendientes > 0 and os.clock() < limite do
			task.wait(0.2)
		end
	end)

	-- El cliente puede pedir su copia (por si se perdió el primer envío)
	RemoteDatos.OnServerEvent:Connect(function(jugador)
		enviar(jugador)
	end)

	-- Envía las copias pendientes (como mucho 4 veces por segundo por jugador)
	task.spawn(function()
		while true do
			task.wait(0.25)
			for jugador, sesion in sesiones do
				if sesion.enviar then
					sesion.enviar = false
					RemoteDatos:FireClient(jugador, sesion.datos)
				end
			end
		end
	end)

	-- Autoguardado (también renueva el bloqueo de sesión aunque no haya cambios)
	task.spawn(function()
		while true do
			task.wait(ProgresionConfig.AUTOGUARDADO)
			for jugador in sesiones do
				task.spawn(guardar, jugador, false)
			end
		end
	end)
end

return DatosServicio

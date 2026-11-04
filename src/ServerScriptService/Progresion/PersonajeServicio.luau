-- Lleva a la práctica el CharacterData: atributos con efecto real, experiencia y niveles,
-- oro, maná, maestrías, afinidades, profesiones y la ubicación guardada. SOLO servidor.
-- Ruta en Studio: ServerScriptService/Progresion/PersonajeServicio
--
-- Qué hace cada atributo (fórmulas en ReplicatedStorage/Progresion/Formulas):
--   VIT -> vida máxima, estamina máxima y defensa      STR -> daño de armas de fuerza
--   DEX -> daño de armas de destreza y velocidad de golpe   INT -> daño mágico y maná
--   LUK -> crítico, objetos raros y oro                SPD -> velocidad, estamina y su recuperación
-- Los valores calculados se publican como atributos del jugador (VidaMax, ManaMax,
-- Mana, Defensa, ReduccionDano, Critico, MultVelocidad, VelocidadAtaque...) para que
-- el combate y la interfaz los usen.
--
-- Pruebas en Studio (vista Server, barra de comandos):
--   game.Players:GetPlayers()[1]:SetAttribute("PruebaExp", 5000)   -- da 5000 de EXP
--   game.Players:GetPlayers()[1]:SetAttribute("PruebaOro", 250)    -- da 250 de oro

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constantes = require(ReplicatedStorage.Config.Constantes)
local ProgresionConfig = require(ReplicatedStorage.Config.ProgresionConfig)
local RegionesConfig = require(ReplicatedStorage.Config.RegionesConfig)
local Formulas = require(ReplicatedStorage.Progresion.Formulas)
local DatosServicio = require(script.Parent.DatosServicio)
local EstaminaServicio = require(script.Parent.Parent.Combate.EstaminaServicio)

local RemoteRepartir = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RepartirPuntos")

local PersonajeServicio = {}

local esAtributo = {}
for _, nombre in Constantes.ATRIBUTOS do
	esAtributo[nombre] = true
end

local yaColocado = {} -- [jugador] = true cuando ya apareció en su ubicación guardada
local ultimoReparto = {} -- [jugador] = tiempo (límite de peticiones)

-- ===== Atributos con efecto real =====

function PersonajeServicio.Aplicar(jugador)
	local datos = DatosServicio.Obtener(jugador)
	if not datos then
		return
	end
	local v = Formulas.Calcular(datos.Atributos)
	jugador:SetAttribute("VidaMax", v.VidaMax)
	jugador:SetAttribute("ManaMax", v.ManaMax)
	jugador:SetAttribute("RegenMana", v.RegenMana)
	jugador:SetAttribute("Mana", math.min(jugador:GetAttribute("Mana") or v.ManaMax, v.ManaMax))
	jugador:SetAttribute("Defensa", v.Defensa)
	jugador:SetAttribute("ReduccionDano", v.ReduccionDano)
	jugador:SetAttribute("Critico", v.Critico)
	jugador:SetAttribute("BonoBotin", v.BonoBotin)
	jugador:SetAttribute("VelocidadAtaque", v.VelocidadAtaque)
	jugador:SetAttribute("MultVelocidad", v.MultVelocidad) -- CorrerServicio lo usa para la velocidad
	EstaminaServicio.FijarMaxima(jugador, v.EstaminaMax, v.RegenEstamina)

	local personaje = jugador.Character
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	if humanoide and humanoide.Health > 0 then
		local proporcion = humanoide.Health / math.max(humanoide.MaxHealth, 1)
		humanoide.MaxHealth = v.VidaMax
		humanoide.Health = math.clamp(proporcion, 0, 1) * v.VidaMax
	end
end

-- ===== Experiencia y niveles =====

function PersonajeServicio.DarExperiencia(jugador, cantidad)
	if type(cantidad) ~= "number" or cantidad ~= cantidad or cantidad <= 0 then
		return 0
	end
	local subidos = DatosServicio.Modificar(jugador, function(d)
		local maximo = ProgresionConfig.NIVEL_MAXIMO
		if d.Nivel >= maximo then
			d.Experiencia = 0
			return 0
		end
		d.Experiencia += math.floor(cantidad)
		local n = 0
		while d.Nivel < maximo and d.Experiencia >= ProgresionConfig.ExpParaSubir(d.Nivel) do
			d.Experiencia -= ProgresionConfig.ExpParaSubir(d.Nivel)
			d.Nivel += 1
			d.PuntosLibres += ProgresionConfig.PUNTOS_POR_NIVEL
			n += 1
		end
		if d.Nivel >= maximo then
			d.Experiencia = 0
		end
		return n
	end) or 0
	if subidos > 0 then
		local datos = DatosServicio.Obtener(jugador)
		print(string.format("[PERSONAJE] %s sube al nivel %d (+%d puntos)", jugador.Name, datos.Nivel, subidos * ProgresionConfig.PUNTOS_POR_NIVEL))
	end
	return subidos
end

-- ===== Oro =====

function PersonajeServicio.DarOro(jugador, cantidad)
	if type(cantidad) ~= "number" or cantidad ~= cantidad or cantidad <= 0 then
		return
	end
	DatosServicio.Modificar(jugador, function(d)
		d.Oro += math.floor(cantidad)
	end)
end

-- Devuelve true si tenía suficiente oro y lo gastó
function PersonajeServicio.GastarOro(jugador, cantidad)
	if type(cantidad) ~= "number" or cantidad ~= cantidad or cantidad < 0 then
		return false
	end
	return DatosServicio.Modificar(jugador, function(d)
		if d.Oro < cantidad then
			return false
		end
		d.Oro -= math.floor(cantidad)
		return true
	end) == true
end

-- ===== Maestrías, afinidades, dominio de clase y profesiones =====
-- Todas funcionan igual: { Nivel, Exp } que sube con ProgresionConfig.ExpParaSubirOficio.

local function subirOficio(registro, cantidad, maximo)
	registro.Exp += math.floor(cantidad)
	local subidos = 0
	while registro.Nivel < maximo and registro.Exp >= ProgresionConfig.ExpParaSubirOficio(registro.Nivel) do
		registro.Exp -= ProgresionConfig.ExpParaSubirOficio(registro.Nivel)
		registro.Nivel += 1
		subidos += 1
	end
	if registro.Nivel >= maximo then
		registro.Exp = 0
	end
	return subidos
end

-- grupo = "Maestrias" | "Afinidades" | "Profesiones" | "DominioClase"
local MAXIMOS = {
	Maestrias = ProgresionConfig.MAESTRIA_MAXIMA,
	Afinidades = ProgresionConfig.AFINIDAD_MAXIMA,
	Profesiones = ProgresionConfig.PROFESION_MAXIMA,
	DominioClase = ProgresionConfig.DOMINIO_MAXIMO,
}

function PersonajeServicio.DarExpOficio(jugador, grupo, nombre, cantidad)
	if not MAXIMOS[grupo] or type(nombre) ~= "string" or type(cantidad) ~= "number" or cantidad <= 0 then
		return 0
	end
	return DatosServicio.Modificar(jugador, function(d)
		local registro = d[grupo][nombre]
		if not registro then
			if grupo ~= "DominioClase" then
				return 0 -- no existe esa arma, elemento o profesión
			end
			registro = { Nivel = 0, Exp = 0 }
			d[grupo][nombre] = registro
		end
		return subirOficio(registro, cantidad, MAXIMOS[grupo])
	end) or 0
end

-- ===== Maná (regenera solo; las habilidades lo gastarán) =====

function PersonajeServicio.GastarMana(jugador, cantidad)
	local actual = jugador:GetAttribute("Mana") or 0
	if type(cantidad) ~= "number" or actual < cantidad then
		return false
	end
	jugador:SetAttribute("Mana", actual - cantidad)
	return true
end

-- ===== Repartir puntos (lo pide el cliente; el servidor lo comprueba todo) =====

local function alRepartir(jugador, reparto)
	local ahora = os.clock()
	if ahora - (ultimoReparto[jugador] or 0) < 0.3 then
		return
	end
	ultimoReparto[jugador] = ahora
	if type(reparto) ~= "table" then
		return
	end
	local total = 0
	local limpio = {}
	for nombre, cantidad in reparto do
		if not esAtributo[nombre] or type(cantidad) ~= "number" or cantidad ~= math.floor(cantidad) or cantidad < 0 or cantidad > 2000 then
			return -- algo raro: se ignora todo
		end
		limpio[nombre] = cantidad
		total += cantidad
	end
	if total <= 0 then
		return
	end
	local ok = DatosServicio.Modificar(jugador, function(d)
		if total > d.PuntosLibres then
			return false
		end
		for nombre, cantidad in limpio do
			d.Atributos[nombre] += cantidad
		end
		d.PuntosLibres -= total
		return true
	end)
	if ok then
		PersonajeServicio.Aplicar(jugador)
	end
end

-- ===== Ubicación guardada =====

local function posicionValida(p)
	return math.abs(p.X) < RegionesConfig.MITAD - 10 and math.abs(p.Z) < RegionesConfig.MITAD - 10 and p.Y > RegionesConfig.NIVEL_AGUA - 5 and p.Y < 1300
end

local function apuntarUbicacion(jugador)
	local personaje = jugador.Character
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if not (humanoide and raiz) or humanoide.Health <= 0 then
		return
	end
	-- solo posiciones "seguras": pisando suelo, no en el aire ni en el agua
	local suelo = humanoide.FloorMaterial
	if suelo == Enum.Material.Air or suelo == Enum.Material.Water then
		return
	end
	local p = raiz.Position
	if not posicionValida(p) then
		return
	end
	DatosServicio.Modificar(jugador, function(d)
		d.Ubicacion = {
			X = math.floor(p.X * 10) / 10,
			Y = math.floor(p.Y * 10) / 10,
			Z = math.floor(p.Z * 10) / 10,
			Region = RegionesConfig.RegionEn(p),
		}
	end, true)
end

local function colocarEnUbicacion(jugador, personaje)
	if yaColocado[jugador] then
		return
	end
	local datos = DatosServicio.Obtener(jugador)
	if not datos then
		return
	end
	yaColocado[jugador] = true
	local u = datos.Ubicacion
	if not (u and u.X and u.Y and u.Z) then
		return -- personaje nuevo: aparece en el punto de inicio normal
	end
	local destino = Vector3.new(u.X, u.Y, u.Z)
	if not posicionValida(destino) then
		return
	end
	local raiz = personaje:WaitForChild("HumanoidRootPart", 10)
	if raiz then
		task.wait(0.2)
		personaje:PivotTo(CFrame.new(destino + Vector3.new(0, 3, 0)))
	end
end

-- ===== Arranque =====

local function prepararPersonaje(jugador, personaje)
	local humanoide = personaje:WaitForChild("Humanoid", 10)
	if not humanoide then
		return
	end
	PersonajeServicio.Aplicar(jugador)
	humanoide.Health = humanoide.MaxHealth
	colocarEnUbicacion(jugador, personaje)
end

function PersonajeServicio.Iniciar()
	DatosServicio.Cargado.Event:Connect(function(jugador)
		jugador:SetAttribute("Mana", nil)
		PersonajeServicio.Aplicar(jugador)
		local personaje = jugador.Character
		if personaje then
			task.spawn(prepararPersonaje, jugador, personaje)
		end
	end)

	local function alEntrar(jugador)
		jugador.CharacterAdded:Connect(function(personaje)
			if DatosServicio.Obtener(jugador) then
				prepararPersonaje(jugador, personaje)
			end
		end)
		if RunService:IsStudio() then
			jugador:GetAttributeChangedSignal("PruebaExp"):Connect(function()
				PersonajeServicio.DarExperiencia(jugador, jugador:GetAttribute("PruebaExp") or 0)
			end)
			jugador:GetAttributeChangedSignal("PruebaOro"):Connect(function()
				PersonajeServicio.DarOro(jugador, jugador:GetAttribute("PruebaOro") or 0)
			end)
		end
	end
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		alEntrar(jugador)
	end
	Players.PlayerRemoving:Connect(function(jugador)
		yaColocado[jugador] = nil
		ultimoReparto[jugador] = nil
	end)

	RemoteRepartir.OnServerEvent:Connect(alRepartir)

	-- Un solo bucle: regenera el maná de todos y apunta la ubicación cada cierto tiempo
	task.spawn(function()
		local siguienteUbicacion = os.clock() + ProgresionConfig.GUARDAR_UBICACION
		while true do
			local dt = task.wait(0.5)
			for _, jugador in Players:GetPlayers() do
				local maximo = jugador:GetAttribute("ManaMax")
				local actual = jugador:GetAttribute("Mana")
				if maximo and actual and actual < maximo then
					jugador:SetAttribute("Mana", math.min(maximo, actual + (jugador:GetAttribute("RegenMana") or 5) * dt))
				end
			end
			if os.clock() >= siguienteUbicacion then
				siguienteUbicacion = os.clock() + ProgresionConfig.GUARDAR_UBICACION
				for _, jugador in Players:GetPlayers() do
					apuntarUbicacion(jugador)
				end
			end
		end
	end)
end

return PersonajeServicio

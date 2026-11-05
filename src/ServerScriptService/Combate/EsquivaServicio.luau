-- Valida las esquivas en el servidor y da la invulnerabilidad.
-- Ruta en Studio: ServerScriptService/Combate/EsquivaServicio
-- El cliente mueve al personaje (para que se sienta instantáneo),
-- pero el SERVIDOR decide si la esquiva es válida, cobra la estamina,
-- marca al personaje como invulnerable y avisa a los demás jugadores
-- para que también vean la animación de la esquiva.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Config.CombateConfig).Esquiva
local EstaminaServicio = require(script.Parent.EstaminaServicio)

local RemotoEsquivar = ReplicatedStorage.Remotes.Esquivar
local RemotoEfecto = ReplicatedStorage.Remotes.EfectoEsquiva

local EsquivaServicio = {}

local ultimaEsquiva = {} -- [jugador] = tiempo de la última esquiva aceptada

local function obtenerPersonajeVivo(jugador)
	local personaje = jugador.Character
	if not personaje then
		return nil
	end
	local humanoide = personaje:FindFirstChildOfClass("Humanoid")
	if not humanoide or humanoide.Health <= 0 then
		return nil
	end
	return personaje
end

-- Nunca confiamos en lo que manda el cliente: comprobamos la dirección
local function limpiarDireccion(direccion)
	if typeof(direccion) ~= "Vector3" then
		return nil
	end
	local plana = Vector3.new(direccion.X, 0, direccion.Z)
	local largo = plana.Magnitude
	if largo ~= largo or largo < 0.01 or largo > 10 then -- largo ~= largo detecta NaN
		return nil
	end
	return plana / largo
end

local TIPOS_VALIDOS = { Rodar = true, Lateral = true, PasoAtras = true }

local function alPedirEsquiva(jugador, direccion, tipo)
	-- El tipo solo cambia la animación; si llega algo raro usamos "Rodar"
	if typeof(tipo) ~= "string" or not TIPOS_VALIDOS[tipo] then
		tipo = "Rodar"
	end

	local personaje = obtenerPersonajeVivo(jugador)
	if not personaje then
		return
	end

	-- Enfriamiento (con un pequeño margen por el retraso de internet)
	local ahora = os.clock()
	if ahora - (ultimaEsquiva[jugador] or 0) < Config.ENFRIAMIENTO * 0.8 then
		return
	end

	if not EstaminaServicio.Gastar(jugador, Config.COSTO_ESTAMINA) then
		return
	end

	ultimaEsquiva[jugador] = ahora
	personaje:SetAttribute("Invulnerable", true)
	print("[ESQUIVA]", jugador.Name, tipo, "- invulnerable. Estamina:", EstaminaServicio.Obtener(jugador))

	-- Avisar a los DEMÁS jugadores para que vean la voltereta
	local raiz = personaje:FindFirstChild("HumanoidRootPart")
	local direccionFinal = limpiarDireccion(direccion) or (raiz and -raiz.CFrame.LookVector) or Vector3.new(0, 0, -1)
	for _, otro in Players:GetPlayers() do
		if otro ~= jugador then
			RemotoEfecto:FireClient(otro, personaje, direccionFinal, tipo)
		end
	end

	task.delay(Config.INVULNERABILIDAD, function()
		-- Solo la quitamos si no hubo otra esquiva después
		if personaje.Parent and ultimaEsquiva[jugador] == ahora then
			personaje:SetAttribute("Invulnerable", false)
			print("[ESQUIVA]", jugador.Name, "ya puede recibir daño")
		end
	end)
end

-- Para el futuro sistema de daño: ¿este personaje está esquivando?
function EsquivaServicio.EsInvulnerable(personaje)
	return personaje:GetAttribute("Invulnerable") == true
end

function EsquivaServicio.Iniciar()
	RemotoEsquivar.OnServerEvent:Connect(function(jugador, ...)
		if jugador:GetAttribute("EnMenu") then
			return -- todavía en la pantalla de inicio
		end
		alPedirEsquiva(jugador, ...)
	end)
	Players.PlayerRemoving:Connect(function(jugador)
		ultimaEsquiva[jugador] = nil
	end)
end

return EsquivaServicio

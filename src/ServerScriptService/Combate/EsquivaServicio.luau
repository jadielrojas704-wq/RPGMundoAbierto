-- Valida las esquivas en el servidor y da la invulnerabilidad.
-- Ruta en Studio: ServerScriptService/Combate/EsquivaServicio
-- El cliente mueve al personaje (para que se sienta instantáneo),
-- pero el SERVIDOR decide si la esquiva es válida, cobra la estamina
-- y es el único que marca al personaje como invulnerable.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Config.CombateConfig).Esquiva
local EstaminaServicio = require(script.Parent.EstaminaServicio)

local RemotoEsquivar = ReplicatedStorage.Remotes.Esquivar

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

local function alPedirEsquiva(jugador)
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
	print("[ESQUIVA]", jugador.Name, "es invulnerable. Estamina:", EstaminaServicio.Obtener(jugador))

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
	RemotoEsquivar.OnServerEvent:Connect(alPedirEsquiva)
	game:GetService("Players").PlayerRemoving:Connect(function(jugador)
		ultimaEsquiva[jugador] = nil
	end)
end

return EsquivaServicio

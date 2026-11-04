-- Controla quién está corriendo. El SERVIDOR decide la velocidad y cobra la estamina.
-- Ruta en Studio: ServerScriptService/Combate/CorrerServicio
-- El cliente solo avisa "quiero correr" / "ya no quiero correr" (RemoteEvent Correr).
-- Aquí se comprueba la estamina, se gasta mientras te mueves y se cambia
-- la velocidad del Humanoid. Si te quedas sin estamina, dejas de correr
-- y vuelves a correr solo cuando recuperes un poco (MINIMO_PARA_REANUDAR).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Config.CombateConfig).Correr
local EstaminaServicio = require(script.Parent.EstaminaServicio)

local RemotoCorrer = ReplicatedStorage.Remotes.Correr

local CorrerServicio = {}

-- estado[jugador] = { quiere = bool, corriendo = bool, agotado = bool }
local estado = {}

local function humanoideVivo(jugador)
	local personaje = jugador.Character
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	if humanoide and humanoide.Health > 0 then
		return humanoide, personaje
	end
	return nil
end

local function aplicar(jugador, corriendo)
	local e = estado[jugador]
	if not e then
		return
	end
	e.corriendo = corriendo
	local humanoide, personaje = humanoideVivo(jugador)
	if humanoide then
		humanoide.WalkSpeed = corriendo and Config.VELOCIDAD_CORRER or Config.VELOCIDAD_CAMINAR
		personaje:SetAttribute("Corriendo", corriendo)
	end
end

local function alPedir(jugador, quiere)
	local e = estado[jugador]
	if not e or typeof(quiere) ~= "boolean" then
		return -- nunca confiamos en datos raros del cliente
	end
	e.quiere = quiere
	if not quiere then
		e.agotado = false
		aplicar(jugador, false)
	end
end

function CorrerServicio.Iniciar()
	local function alEntrar(jugador)
		estado[jugador] = { quiere = false, corriendo = false, agotado = false }
		jugador.CharacterAdded:Connect(function()
			local e = estado[jugador]
			if e then
				e.quiere, e.agotado = false, false
				task.defer(aplicar, jugador, false)
			end
		end)
	end
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		alEntrar(jugador)
	end
	Players.PlayerRemoving:Connect(function(jugador)
		estado[jugador] = nil
	end)

	RemotoCorrer.OnServerEvent:Connect(alPedir)

	-- Un solo bucle para todos los jugadores
	task.spawn(function()
		while true do
			local dt = task.wait(0.1)
			for jugador, e in estado do
				if not e.quiere then
					continue
				end
				local humanoide = humanoideVivo(jugador)
				if not humanoide then
					continue
				end

				if e.agotado then
					-- Esperamos a recuperar algo de estamina para volver a correr
					if EstaminaServicio.Obtener(jugador) >= Config.MINIMO_PARA_REANUDAR then
						e.agotado = false
					else
						continue
					end
				end

				local moviendose = humanoide.MoveDirection.Magnitude > 0.1
				if moviendose then
					if EstaminaServicio.Gastar(jugador, Config.COSTO_POR_SEGUNDO * dt) then
						if not e.corriendo then
							aplicar(jugador, true)
						end
					else
						e.agotado = true
						aplicar(jugador, false)
					end
				elseif not e.corriendo then
					aplicar(jugador, true) -- quieto con Ctrl pulsado: listo para salir corriendo
				end
			end
		end
	end)
end

return CorrerServicio

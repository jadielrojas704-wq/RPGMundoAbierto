-- Controla la estamina de cada jugador. SOLO el servidor la modifica.
-- Ruta en Studio: ServerScriptService/Combate/EstaminaServicio
-- El valor se publica como atributo del jugador ("Estamina" / "EstaminaMax")
-- para que el cliente pueda dibujar la barra, pero el cliente nunca lo cambia.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Config.CombateConfig).Estamina

local EstaminaServicio = {}

-- datos[jugador] = { actual = número, ultimoGasto = tiempo, maxima = número, regen = multiplicador }
-- La máxima y la recuperación dependen de los atributos (VIT y SPD): las fija
-- ServerScriptService/Progresion/PersonajeServicio con EstaminaServicio.FijarMaxima.
local datos = {}

local function publicar(jugador, d)
	jugador:SetAttribute("Estamina", math.floor(d.actual + 0.5))
end

local function rellenar(jugador)
	local d = datos[jugador]
	if not d then
		return
	end
	d.actual = d.maxima
	publicar(jugador, d)
end

local function alEntrar(jugador)
	datos[jugador] = { actual = Config.MAXIMA, ultimoGasto = 0, maxima = Config.MAXIMA, regen = 1 }
	jugador:SetAttribute("EstaminaMax", Config.MAXIMA)
	publicar(jugador, datos[jugador])

	-- Al reaparecer, la estamina vuelve a estar llena
	jugador.CharacterAdded:Connect(function()
		rellenar(jugador)
	end)
end

-- Devuelve la estamina actual del jugador
function EstaminaServicio.Obtener(jugador)
	local d = datos[jugador]
	return d and d.actual or 0
end

-- Cambia la estamina máxima y la velocidad de recuperación de un jugador
function EstaminaServicio.FijarMaxima(jugador, maxima, regen)
	local d = datos[jugador]
	if not d then
		return
	end
	d.maxima = math.max(1, maxima)
	d.regen = regen or 1
	d.actual = math.min(d.actual, d.maxima)
	jugador:SetAttribute("EstaminaMax", d.maxima)
	publicar(jugador, d)
end

-- Intenta gastar estamina. Devuelve true si había suficiente.
function EstaminaServicio.Gastar(jugador, cantidad)
	local d = datos[jugador]
	if not d or d.actual < cantidad then
		return false
	end
	d.actual -= cantidad
	d.ultimoGasto = os.clock()
	publicar(jugador, d)
	return true
end

function EstaminaServicio.Iniciar()
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		alEntrar(jugador)
	end
	Players.PlayerRemoving:Connect(function(jugador)
		datos[jugador] = nil
	end)

	-- Un solo bucle para todos los jugadores (eficiente para 20 jugadores)
	task.spawn(function()
		while true do
			local dt = task.wait(Config.FRECUENCIA_ACTUALIZACION)
			local ahora = os.clock()
			for jugador, d in datos do
				local puedeRecuperar = ahora - d.ultimoGasto >= Config.RETRASO_REGEN
				if d.actual < d.maxima and puedeRecuperar then
					d.actual = math.min(d.maxima, d.actual + Config.REGEN_POR_SEGUNDO * d.regen * dt)
					publicar(jugador, d)
				end
			end
		end
	end)
end

return EstaminaServicio

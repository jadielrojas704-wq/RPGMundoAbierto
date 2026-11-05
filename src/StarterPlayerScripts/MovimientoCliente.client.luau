-- MOVIMIENTO FLUIDO (solo CLIENTE): todo lo que hace que moverse se vea bien.
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/MovimientoCliente (LocalScript)
--
--   * Animaciones de reposo, caminar, correr, saltar y caer: un paquete con captura de
--     movimiento (las pone el servidor: ReplicatedStorage/Config/AparienciaConfig.ANIMACIONES).
--   * Capa de movimiento del Animador: el cuerpo se inclina al correr y se ladea en las
--     curvas, la cabeza mira hacia donde apunta la cámara, y en guardia las piernas andan.
--   * Caminar tranquilo: tecla Z de fábrica (se cambia en M > Ajustes).
--   * Al caer de un salto, las rodillas amortiguan el golpe.
--   * DESCANSO: si te quedas quieto un rato (fuera de combate), el personaje suspira,
--     cambia de postura o se estira.
-- Nada de esto decide nada del juego: el servidor manda en la velocidad (CorrerServicio).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Animador = require(ReplicatedStorage:WaitForChild("Combate"):WaitForChild("Animador"))
local Controles = require(ReplicatedStorage.Combate:WaitForChild("Controles"))
local AparienciaConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("AparienciaConfig"))
local RemotoCorrer = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Correr")

local jugador = Players.LocalPlayer

local QUIETO_PARA_DESCANSAR = 14 -- segundos quieto hasta el primer gesto de descanso
local ENTRE_DESCANSOS = { 16, 26 }

-- Amortiguar la caída: rodillas dobladas y cuerpo abajo un instante
local ATERRIZAJE = {
	duracion = 0.42,
	mezcla = 0.03,
	salida = 0.16,
	claves = {
		{
			t = 0,
			pose = {
				Root = CFrame.new(0, -0.55, 0) * CFrame.Angles(math.rad(-8), 0, 0),
				LeftHip = CFrame.Angles(math.rad(22), 0, 0),
				RightHip = CFrame.Angles(math.rad(22), 0, 0),
				LeftKnee = CFrame.Angles(math.rad(-34), 0, 0),
				RightKnee = CFrame.Angles(math.rad(-34), 0, 0),
				LeftShoulder = CFrame.Angles(math.rad(-10), 0, math.rad(-12)),
				RightShoulder = CFrame.Angles(math.rad(-10), 0, math.rad(12)),
			},
		},
		{ t = 0.42, pose = {}, curva = "suave" },
	},
}

local caminando = false
local rng = Random.new()

local function prepararPersonaje(personaje)
	local humanoide = personaje:WaitForChild("Humanoid", 10)
	if not humanoide then
		return
	end
	personaje:WaitForChild("LowerTorso", 10)
	local animador = Animador.De(personaje)
	if animador then
		animador:Locomocion(true)
	end
	if caminando then
		RemotoCorrer:FireServer("Caminar", true)
	end

	-- caída: cuanto más alta, más se doblan las rodillas
	local alturaInicio = nil
	humanoide.StateChanged:Connect(function(_, nuevo)
		local raiz = personaje:FindFirstChild("HumanoidRootPart")
		if not raiz then
			return
		end
		if nuevo == Enum.HumanoidStateType.Freefall then
			alturaInicio = raiz.Position.Y
		elseif nuevo == Enum.HumanoidStateType.Landed and alturaInicio then
			local caida = alturaInicio - raiz.Position.Y
			alturaInicio = nil
			if caida > 3 and animador and not animador:Ocupado() and not personaje:GetAttribute("AnimacionExterna") then
				animador:Reproducir(ATERRIZAJE, { velocidad = math.clamp(1.25 - caida / 60, 0.8, 1.2) })
			end
		end
	end)

	-- descanso: si llevas un rato quieto, fuera de combate
	task.spawn(function()
		local quieto = 0
		local siguiente = QUIETO_PARA_DESCANSAR
		while personaje.Parent and humanoide.Health > 0 do
			local dt = task.wait(0.5)
			local raiz = personaje:FindFirstChild("HumanoidRootPart")
			local enCombate = personaje:GetAttribute("EnCombate") or personaje:GetAttribute("Atacando")
			local ocupado = jugador:GetAttribute("EnMenu")
				or jugador:GetAttribute("EnCinematica")
				or (raiz and raiz.Anchored)
				or enCombate
				or (animador and animador:Ocupado())
			local moviendose = humanoide.MoveDirection.Magnitude > 0.05
				or humanoide.FloorMaterial == Enum.Material.Air
			if ocupado or moviendose then
				quieto = 0
				siguiente = QUIETO_PARA_DESCANSAR
			else
				quieto += dt
				if quieto >= siguiente then
					local gestos = {}
					for nombre in AparienciaConfig.DESCANSO do
						table.insert(gestos, nombre)
					end
					table.sort(gestos)
					local gesto = gestos[rng:NextInteger(1, #gestos)]
					pcall(function()
						humanoide:PlayEmote(gesto)
					end)
					siguiente = quieto + rng:NextNumber(ENTRE_DESCANSOS[1], ENTRE_DESCANSOS[2])
				end
			end
		end
	end)
end

jugador.CharacterAdded:Connect(prepararPersonaje)
if jugador.Character then
	task.spawn(prepararPersonaje, jugador.Character)
end

-- Caminar tranquilo (cambia al pulsar)
UserInputService.InputBegan:Connect(function(entrada, procesado)
	if procesado or jugador:GetAttribute("EnMenu") or jugador:GetAttribute("EnCinematica") then
		return
	end
	if Controles.Es("Caminar", entrada) then
		caminando = not caminando
		RemotoCorrer:FireServer("Caminar", caminando)
	end
end)

-- Los demás jugadores también se inclinan al correr (solo se ve en tu pantalla)
RunService.Heartbeat:Connect(function()
	for _, otro in Players:GetPlayers() do
		local personaje = otro.Character
		if otro ~= jugador and personaje and personaje:FindFirstChild("LowerTorso") then
			local animador = Animador.De(personaje)
			if animador and not animador.locomocion then
				animador:Locomocion(true)
			end
		end
	end
end)

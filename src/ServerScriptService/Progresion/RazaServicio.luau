-- Efectos de las razas que cambian con el mundo. SOLO servidor.
-- Ruta en Studio: ServerScriptService/Progresion/RazaServicio
--
-- VAMPIRO (historia: los primeros humanos tocados por el Eclipse):
--   * De día, si le da el sol (nada encima que lo tape), se quema: pierde vida poco a poco
--     (nunca por debajo del 20 %), hace menos daño y le sale humo.
--   * A la sombra o bajo techo, de día, está normal.
--   * De noche hace más daño y se regenera.
-- Publica en el jugador:
--   EstadoVampiro = "Sol" / "Sombra" / "Noche"   (la interfaz lo enseña)
--   MultDanoRaza  = multiplicador de daño          (lo usa CombateServicio)
-- Valores en ReplicatedStorage/Config/RazasConfig.VAMPIRO

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RazasConfig = require(ReplicatedStorage.Config.RazasConfig)
local DatosServicio = require(script.Parent.DatosServicio)

local V = RazasConfig.VAMPIRO

local RazaServicio = {}

local function esDeDia()
	local hora = Lighting.ClockTime
	return hora >= V.DIA_DESDE and hora < V.DIA_HASTA
end

-- ¿Le da el sol? Rayo hacia el sol: si choca con algo (techo, árbol, montaña), está a la sombra
local function alSol(personaje, cabeza)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { personaje }
	params.IgnoreWater = true
	local direccion = Lighting:GetSunDirection()
	if direccion.Y <= 0.05 then
		return false -- sol muy bajo: no quema
	end
	local rayo = Workspace:Raycast(cabeza.Position, direccion * 400, params)
	if rayo and rayo.Instance and rayo.Instance.Transparency > 0.6 and not rayo.Instance:IsA("Terrain") then
		return true -- cristal o cosas casi invisibles no tapan
	end
	return rayo == nil
end

-- Humo que sale del vampiro al sol (lo ven todos)
local function humo(personaje, encendido)
	local torso = personaje:FindFirstChild("UpperTorso") or personaje:FindFirstChild("Torso")
	if not torso then
		return
	end
	local emisor = torso:FindFirstChild("HumoSol")
	if not emisor and encendido then
		emisor = Instance.new("ParticleEmitter")
		emisor.Name = "HumoSol"
		emisor.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emisor.Color = ColorSequence.new(Color3.fromRGB(255, 200, 150), Color3.fromRGB(80, 70, 70))
		emisor.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.4) })
		emisor.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
		emisor.Lifetime = NumberRange.new(0.8, 1.4)
		emisor.Speed = NumberRange.new(2, 4)
		emisor.Acceleration = Vector3.new(0, 4, 0)
		emisor.SpreadAngle = Vector2.new(30, 30)
		emisor.Rate = 14
		emisor.Parent = torso
		local brasas = Instance.new("ParticleEmitter")
		brasas.Name = "BrasasSol"
		brasas.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		brasas.Color = ColorSequence.new(Color3.fromRGB(255, 170, 80))
		brasas.LightEmission = 1
		brasas.Size = NumberSequence.new(0.15, 0)
		brasas.Lifetime = NumberRange.new(0.4, 0.8)
		brasas.Speed = NumberRange.new(1, 3)
		brasas.SpreadAngle = Vector2.new(180, 180)
		brasas.Rate = 10
		brasas.Parent = emisor
	end
	if emisor then
		emisor.Enabled = encendido
		local brasas = emisor:FindFirstChild("BrasasSol")
		if brasas then
			brasas.Enabled = encendido
		end
	end
end

local function actualizar(jugador)
	local datos = DatosServicio.Obtener(jugador)
	local personaje = jugador.Character
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	local cabeza = personaje and personaje:FindFirstChild("Head")
	if not (datos and humanoide and cabeza) or humanoide.Health <= 0 then
		return
	end
	if datos.Raza ~= "Vampiro" or jugador:GetAttribute("EnMenu") then
		if jugador:GetAttribute("EstadoVampiro") then
			jugador:SetAttribute("EstadoVampiro", nil)
			jugador:SetAttribute("MultDanoRaza", nil)
			humo(personaje, false)
		end
		return
	end
	local estado
	if not esDeDia() then
		estado = "Noche"
	elseif alSol(personaje, cabeza) then
		estado = "Sol"
	else
		estado = "Sombra"
	end
	jugador:SetAttribute("EstadoVampiro", estado)
	local vidaMax = humanoide.MaxHealth
	if estado == "Sol" then
		jugador:SetAttribute("MultDanoRaza", V.DANO_AL_SOL)
		local minimo = vidaMax * V.VIDA_MINIMA
		if humanoide.Health > minimo then
			humanoide.Health = math.max(minimo, humanoide.Health - vidaMax * V.QUEMA_POR_SEGUNDO)
		end
		humo(personaje, true)
	elseif estado == "Noche" then
		jugador:SetAttribute("MultDanoRaza", V.DANO_DE_NOCHE)
		humanoide.Health = math.min(vidaMax, humanoide.Health + vidaMax * V.REGENERA_DE_NOCHE)
		humo(personaje, false)
	else
		jugador:SetAttribute("MultDanoRaza", 1)
		humo(personaje, false)
	end
end

function RazaServicio.Iniciar()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, jugador in Players:GetPlayers() do
				local ok, err = pcall(actualizar, jugador)
				if not ok then
					warn("[RAZA]", err)
				end
			end
		end
	end)
end

return RazaServicio

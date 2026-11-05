-- EL DRAGÓN OCULTO de las montañas (solo CLIENTE, solo ambiente).
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/RugidoDragon (LocalScript)
--
-- Mientras el jugador camina por las Montañas, de vez en cuando un rugido
-- gigantesco retumba entre los picos:
--   * el sonido llega desde lejos (de una dirección concreta) con eco de montaña
--   * la cámara tiembla, cae nieve y piedrecitas, y los pájaros huyen
--   * a veces se ve su silueta cruzando el cielo entre la niebla (y su sombra en el suelo)
-- Nadie lo ha visto de cerca... todavía. No hace daño: es ambientación (y una pista).
--
-- PRUEBA en Studio: en la barra de comandos (pestaña Cliente)
--   workspace:SetAttribute("PruebaRugido", os.clock())
-- hace rugir al dragón al momento, estés donde estés.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Regiones = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("RegionesConfig"))
local SonidosConfig = require(ReplicatedStorage.Config:WaitForChild("SonidosConfig"))

local jugador = Players.LocalPlayer
local rng = Random.new()

-- ===== AJUSTES =====
local PRIMER_RUGIDO = { 20, 45 } -- segundos en la montaña hasta el primer rugido
local ENTRE_RUGIDOS = { 100, 220 } -- segundos entre un rugido y el siguiente
local DISTANCIA = 650 -- a qué distancia "está" el dragón
local PROBABILIDAD_SILUETA = 0.45 -- veces que se deja ver cruzando el cielo
local TEXTO_PRIMERA_VEZ = "Un rugido estremece las cumbres... algo enorme duerme entre los picos."

local function tween(objeto, tiempo, metas, estilo, direccion)
	local t = TweenService:Create(
		objeto,
		TweenInfo.new(tiempo, estilo or Enum.EasingStyle.Quad, direccion or Enum.EasingDirection.Out),
		metas
	)
	t:Play()
	return t
end

local function raiz()
	local personaje = jugador.Character
	return personaje and personaje:FindFirstChild("HumanoidRootPart")
end

local function parte(nombre, tamano, cframe, padre)
	local p = Instance.new("Part")
	p.Name = nombre
	p.Size = tamano
	p.CFrame = cframe
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = padre
	return p
end

-- ===== 1. EL SONIDO: rugido en capas con eco de montaña =====
local function capaDeSonido(emisor, id, volumen, velocidad, retraso, efectos)
	task.delay(retraso or 0, function()
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = volumen
		s.PlaybackSpeed = velocidad
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = DISTANCIA * 0.8 -- llega fuerte aunque esté lejos
		s.RollOffMaxDistance = DISTANCIA * 4
		if efectos then
			local eco = Instance.new("EchoSoundEffect")
			eco.Delay = 0.55
			eco.Feedback = 0.4
			eco.WetLevel = -4
			eco.DryLevel = 0
			eco.Parent = s
			local reverb = Instance.new("ReverbSoundEffect")
			reverb.DecayTime = 6
			reverb.Density = 1
			reverb.Diffusion = 1
			reverb.WetLevel = -2
			reverb.Parent = s
			local graves = Instance.new("EqualizerSoundEffect")
			graves.LowGain = 8 -- más graves: suena más grande
			graves.MidGain = 0
			graves.HighGain = -10 -- sin agudos: viene de muy lejos
			graves.Parent = s
		end
		s.Parent = emisor
		s:Play()
		Debris:AddItem(s, 25)
	end)
end

local function rugir(posicion)
	local emisor = parte("RugidoDragon", Vector3.one, CFrame.new(posicion), Workspace.CurrentCamera)
	emisor.Transparency = 1
	Debris:AddItem(emisor, 26)
	local rugidos = SonidosConfig.DRAGON.Rugidos
	local principal = rugidos[rng:NextInteger(1, #rugidos)]
	local segundo = rugidos[rng:NextInteger(1, #rugidos)]
	-- el retumbar de la montaña llega primero, luego la voz, luego el eco grave
	capaDeSonido(emisor, SonidosConfig.DRAGON.Trueno, 1.2, 0.5, 0, false)
	capaDeSonido(emisor, principal, 1.8, rng:NextNumber(0.5, 0.6), 0.25, true)
	capaDeSonido(emisor, segundo, 1.2, rng:NextNumber(0.62, 0.72), 0.45, true)
	capaDeSonido(emisor, SonidosConfig.DRAGON.Grunido, 0.9, 0.55, 3.2, true)
end

-- ===== 2. LA TIERRA TIEMBLA =====
local function temblar(duracion, fuerza)
	local inicio = os.clock()
	local nombre = "TemblorDragon" .. tostring(inicio)
	RunService:BindToRenderStep(nombre, Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - inicio
		if t > duracion then
			RunService:UnbindFromRenderStep(nombre)
			return
		end
		-- sube rápido y se apaga despacio
		local envolvente = math.min(t / 0.6, 1) * (1 - t / duracion) ^ 1.5
		local f = fuerza * envolvente
		local camara = Workspace.CurrentCamera
		camara.CFrame *= CFrame.Angles(
			math.rad(math.noise(t * 22, 3.1) * f),
			math.rad(math.noise(t * 22, 7.7) * f),
			math.rad(math.noise(t * 14, 9.3) * f * 0.6)
		)
	end)
end

-- ===== 3. CAE NIEVE Y PIEDRECITAS DE LAS ROCAS =====
local function derrumbe(centro)
	local techo = parte("NieveCayendo", Vector3.new(90, 1, 90), CFrame.new(centro + Vector3.new(0, 40, 0)), Workspace.CurrentCamera)
	techo.Transparency = 1
	local nieve = Instance.new("ParticleEmitter")
	nieve.Texture = "rbxasset://textures/particles/smoke_main.dds"
	nieve.Color = ColorSequence.new(Color3.fromRGB(240, 240, 250))
	nieve.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) })
	nieve.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	nieve.Lifetime = NumberRange.new(3, 5)
	nieve.Speed = NumberRange.new(4, 10)
	nieve.EmissionDirection = Enum.NormalId.Bottom
	nieve.Acceleration = Vector3.new(0, -12, 0)
	nieve.SpreadAngle = Vector2.new(20, 20)
	nieve.Rate = 0
	nieve.Parent = techo
	local piedras = Instance.new("ParticleEmitter")
	piedras.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	piedras.Color = ColorSequence.new(Color3.fromRGB(110, 104, 100))
	piedras.Size = NumberSequence.new(0.35)
	piedras.LightEmission = 0
	piedras.Lifetime = NumberRange.new(2, 3)
	piedras.Speed = NumberRange.new(10, 20)
	piedras.EmissionDirection = Enum.NormalId.Bottom
	piedras.Acceleration = Vector3.new(0, -60, 0)
	piedras.RotSpeed = NumberRange.new(-200, 200)
	piedras.Rate = 0
	piedras.Parent = techo
	nieve.Rate = 70
	piedras.Rate = 25
	task.delay(3.5, function()
		nieve.Rate = 0
		piedras.Rate = 0
	end)
	Debris:AddItem(techo, 10)
end

-- ===== 4. LOS PÁJAROS HUYEN =====
local function pajaros(centro, huida)
	local lateral = huida:Cross(Vector3.yAxis).Unit
	for _ = 1, rng:NextInteger(7, 12) do
		local modelo = Instance.new("Model")
		modelo.Name = "Pajaro"
		local inicio = centro + lateral * rng:NextNumber(-60, 60) + huida * rng:NextNumber(-40, 10)
			+ Vector3.new(0, rng:NextNumber(18, 40), 0)
		local cuerpo = parte("Cuerpo", Vector3.new(0.5, 0.5, 1.4), CFrame.new(inicio), modelo)
		cuerpo.Color = Color3.fromRGB(30, 28, 34)
		local alas = {}
		for lado = -1, 1, 2 do
			local ala = parte("Ala", Vector3.new(1.8, 0.1, 0.8), CFrame.new(), modelo)
			ala.Color = cuerpo.Color
			table.insert(alas, { ala, lado })
		end
		modelo.Parent = Workspace.CurrentCamera
		local direccion = (huida + lateral * rng:NextNumber(-0.4, 0.4) + Vector3.new(0, rng:NextNumber(0.25, 0.6), 0)).Unit
		local velocidad = rng:NextNumber(28, 40)
		local fase = rng:NextNumber(0, math.pi * 2)
		local nacido = os.clock()
		local conexion
		conexion = RunService.RenderStepped:Connect(function(dt)
			local t = os.clock() - nacido
			if t > 9 or not modelo.Parent then
				conexion:Disconnect()
				modelo:Destroy()
				return
			end
			local cf = CFrame.lookAt(cuerpo.Position, cuerpo.Position + direccion) + direccion * velocidad * dt
			cuerpo.CFrame = cf
			local aleteo = math.sin(t * 22 + fase) * 0.9
			for _, a in alas do
				local ala, lado = a[1], a[2]
				ala.CFrame = cf * CFrame.new(lado * 0.4, 0, 0) * CFrame.Angles(0, 0, lado * aleteo) * CFrame.new(lado * 0.9, 0, 0)
			end
		end)
	end
end

-- ===== 5. LA SILUETA: cruza el cielo entre la niebla =====
local function silueta(centro, desde)
	local modelo = Instance.new("Model")
	modelo.Name = "SiluetaDragon"
	local NEGRO = Color3.fromRGB(14, 10, 20)
	local piezas = {}
	local function pieza(nombre, tamano, desplazamiento)
		local p = parte(nombre, tamano, CFrame.new(), modelo)
		p.Color = NEGRO
		p.Material = Enum.Material.SmoothPlastic
		p.CastShadow = true -- su sombra pasa por encima del jugador
		table.insert(piezas, { p, desplazamiento })
		return p
	end
	-- cuerpo, cuello, cabeza y cola (vistos desde abajo parecen una sola sombra)
	pieza("Cuerpo", Vector3.new(12, 9, 34), CFrame.new())
	pieza("Cuello", Vector3.new(6, 6, 18), CFrame.new(0, 2, -24) * CFrame.Angles(math.rad(12), 0, 0))
	pieza("Cabeza", Vector3.new(7, 5, 11), CFrame.new(0, 4, -36))
	pieza("Cola1", Vector3.new(6, 5, 22), CFrame.new(0, 0, 27))
	pieza("Cola2", Vector3.new(3, 3, 24), CFrame.new(0, -1, 49) * CFrame.Angles(math.rad(-6), 0, 0))
	local alas = {}
	for lado = -1, 1, 2 do
		local ala = parte("Ala", Vector3.new(58, 1.2, 30), CFrame.new(), modelo)
		ala.Color = NEGRO
		ala.Material = Enum.Material.SmoothPlastic
		ala.CastShadow = true
		local punta = parte("Punta", Vector3.new(40, 1, 16), CFrame.new(), modelo)
		punta.Color = NEGRO
		punta.Material = Enum.Material.SmoothPlastic
		punta.CastShadow = true
		table.insert(alas, { ala, punta, lado })
	end
	modelo.Parent = Workspace.CurrentCamera

	-- trayectoria: de un lado del cielo al otro, pasando por encima del jugador
	local lateral = desde:Cross(Vector3.yAxis).Unit
	local altura = rng:NextNumber(230, 320)
	local a = centro + desde * 900 + lateral * rng:NextNumber(-250, 250) + Vector3.new(0, altura, 0)
	local b = centro - desde * 900 + lateral * rng:NextNumber(-250, 250) + Vector3.new(0, altura + 60, 0)
	local duracion = rng:NextNumber(7, 9)
	local nacido = os.clock()
	local conexion
	conexion = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - nacido) / duracion
		if t >= 1 then
			conexion:Disconnect()
			modelo:Destroy()
			return
		end
		local pos = a:Lerp(b, t) + Vector3.new(0, math.sin(t * math.pi * 3) * 12, 0)
		local base = CFrame.lookAt(pos, b) * CFrame.Angles(0, 0, math.sin(t * math.pi * 2) * 0.15)
		for _, p in piezas do
			p[1].CFrame = base * p[2]
		end
		-- aleteo lento y pesado
		local aleteo = math.sin((os.clock() - nacido) * 2.6) * 0.55
		for _, w in alas do
			local ala, punta, lado = w[1], w[2], w[3]
			local hombro = base * CFrame.new(lado * 5, 3, -4) * CFrame.Angles(0, 0, lado * aleteo)
			ala.CFrame = hombro * CFrame.new(lado * 29, 0, 4)
			local codo = hombro * CFrame.new(lado * 56, 0, 4) * CFrame.Angles(0, 0, lado * aleteo * 0.7)
			punta.CFrame = codo * CFrame.new(lado * 18, 0, 6)
		end
		-- aparece y desaparece entre la niebla
		local opacidad = math.clamp(math.min(t / 0.15, (1 - t) / 0.15), 0, 1)
		local transparencia = 1 - opacidad * 0.85
		for _, p in modelo:GetChildren() do
			p.Transparency = transparencia
		end
	end)
end

-- ===== 6. TEXTO la primera vez =====
local avisado = false
local function aviso()
	if avisado then
		return
	end
	avisado = true
	local pantalla = Instance.new("ScreenGui")
	pantalla.Name = "AvisoDragon"
	pantalla.ResetOnSpawn = false
	pantalla.DisplayOrder = 20
	pantalla.Parent = jugador:WaitForChild("PlayerGui")
	local texto = Instance.new("TextLabel")
	texto.AnchorPoint = Vector2.new(0.5, 1)
	texto.Position = UDim2.new(0.5, 0, 1, -150)
	texto.Size = UDim2.new(0.7, 0, 0, 34)
	texto.BackgroundTransparency = 1
	texto.Font = Enum.Font.Garamond
	texto.TextSize = 26
	texto.TextColor3 = Color3.fromRGB(236, 226, 206)
	texto.TextStrokeTransparency = 0.5
	texto.TextTransparency = 1
	texto.Text = TEXTO_PRIMERA_VEZ
	texto.Parent = pantalla
	task.wait(2.5)
	tween(texto, 1.5, { TextTransparency = 0 })
	task.wait(6)
	tween(texto, 2, { TextTransparency = 1 }).Completed:Wait()
	pantalla:Destroy()
end

-- ===== EL RUGIDO COMPLETO =====
local function evento()
	local r = raiz()
	if not r then
		return
	end
	local centro = r.Position
	local angulo = rng:NextNumber(0, math.pi * 2)
	local hacia = Vector3.new(math.cos(angulo), 0, math.sin(angulo)) -- de dónde viene el rugido
	rugir(centro + hacia * DISTANCIA + Vector3.new(0, 220, 0))
	task.delay(0.5, temblar, 4.5, 1.3)
	task.delay(0.8, derrumbe, centro)
	task.delay(0.6, pajaros, centro, -hacia)
	if rng:NextNumber() < PROBABILIDAD_SILUETA then
		task.delay(rng:NextNumber(2.5, 4), silueta, centro, hacia)
	end
	task.spawn(aviso)
end

-- ===== RELOJ: solo ruge mientras estás en las montañas =====
local function nuevaEspera(rango)
	return rng:NextNumber(rango[1], rango[2])
end

local espera = nuevaEspera(PRIMER_RUGIDO)
local primero = true

Workspace:GetAttributeChangedSignal("PruebaRugido"):Connect(evento)

while true do
	task.wait(1)
	local r = raiz()
	local ocupado = jugador:GetAttribute("EnMenu") or jugador:GetAttribute("EnCinematica")
	if r and not ocupado and Regiones.RegionEn(r.Position) == "Montana" then
		espera -= 1
		if espera <= 0 then
			evento()
			primero = false
			espera = nuevaEspera(ENTRE_RUGIDOS)
		end
	elseif primero then
		espera = math.max(espera, nuevaEspera(PRIMER_RUGIDO) * 0.5)
	end
end

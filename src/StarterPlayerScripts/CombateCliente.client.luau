-- Combate en el CLIENTE: lee las teclas, anima al instante y pinta los efectos.
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/CombateCliente
-- Lo importante (si el golpe vale, el daño, la postura) lo decide el SERVIDOR
-- (ServerScriptService/Combate/CombateServicio). Aquí solo se pide y se dibuja.
--
-- Sin armas (primera arma):
--   Clic izquierdo             -> combo de 5: jab, directo, gancho, patada circular y uppercut
--   Mantener clic izquierdo    -> carga un puñetazo enorme; al soltar, golpe cargado
--   Rueda del ratón            -> fijar objetivo (la cámara sigue al enemigo)
-- (Las teclas se pueden cambiar en Menú M > Ajustes.)

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Combate = ReplicatedStorage:WaitForChild("Combate")
local Animador = require(Combate:WaitForChild("Animador"))
local Anims = require(Combate:WaitForChild("Animaciones"):WaitForChild("SinArmas"))
local Efectos = require(Combate:WaitForChild("EfectosCombate"))
local Controles = require(Combate:WaitForChild("Controles"))
local ArmasConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ArmasConfig"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RemoteCombate = Remotes:WaitForChild("Combate")
local RemoteEfecto = Remotes:WaitForChild("EfectoCombate")

local jugador = Players.LocalPlayer
local ARMA = ArmasConfig.SinArmas
local COLOR_AURA = Color3.fromRGB(150, 225, 255) -- celeste: el Ki de Sin armas

-- ===== Estado local =====
local miAnimador = nil
local indice = 0
local finGolpe = 0 -- cuándo termina el golpe actual
local pendiente = nil -- clic guardado para encadenar el combo (búfer)
local pulsadoDesde = nil
local cargando = false
local cargaDesde = 0
local enCombateHasta = 0
local objetivo = nil -- enemigo fijado

local function vivo()
	local personaje = jugador.Character
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if humanoide and raiz and humanoide.Health > 0 then
		return personaje, humanoide, raiz
	end
	return nil
end

-- ===== Silenciar las animaciones de Roblox mientras golpeas =====
local silenciados = {} -- [personaje] = { hasta, pistas }

local function silenciar(personaje, duracion)
	local humanoide = personaje:FindFirstChildOfClass("Humanoid")
	local animator = humanoide and humanoide:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local s = silenciados[personaje]
	if not s then
		s = { hasta = 0, pistas = {}, animator = animator }
		silenciados[personaje] = s
	end
	s.hasta = math.max(s.hasta, os.clock() + duracion)
end

local function actualizarSilencios()
	local ahora = os.clock()
	for personaje, s in silenciados do
		if not personaje.Parent or ahora > s.hasta then
			for pista, peso in s.pistas do
				if pista.IsPlaying then
					pista:AdjustWeight(peso, 0.15)
				end
			end
			silenciados[personaje] = nil
		else
			for _, pista in s.animator:GetPlayingAnimationTracks() do
				if s.pistas[pista] == nil then
					s.pistas[pista] = if pista.WeightTarget > 0.01 then pista.WeightTarget else 1
					pista:AdjustWeight(0.001, 0.06)
				end
			end
		end
	end
end

-- ===== Aura de Ki (al cargar) =====
local auras = {} -- [personaje] = { adjunto, emisores }

local function aura(personaje, encendida, intensidad)
	local actual = auras[personaje]
	if not encendida then
		if actual then
			for _, emisor in actual.emisores do
				emisor.Enabled = false
			end
			task.delay(0.6, function()
				actual.adjunto:Destroy()
			end)
			auras[personaje] = nil
		end
		return
	end
	local raiz = personaje:FindFirstChild("HumanoidRootPart")
	if not raiz then
		return
	end
	if not actual then
		local adjunto = Instance.new("Attachment")
		adjunto.Name = "AuraKi"
		adjunto.Position = Vector3.new(0, -0.5, 0)
		adjunto.Parent = raiz
		local llamas = Instance.new("ParticleEmitter")
		llamas.Texture = "rbxasset://textures/particles/fire_main.dds"
		llamas.Color = ColorSequence.new(Color3.new(1, 1, 1), COLOR_AURA)
		llamas.LightEmission = 1
		llamas.Lifetime = NumberRange.new(0.3, 0.55)
		llamas.Speed = NumberRange.new(4, 7)
		llamas.Acceleration = Vector3.new(0, 10, 0)
		llamas.SpreadAngle = Vector2.new(10, 10)
		llamas.EmissionDirection = Enum.NormalId.Top
		llamas.Shape = Enum.ParticleEmitterShape.Cylinder
		llamas.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		llamas.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
		llamas.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		llamas.Rate = 40
		llamas.Parent = adjunto
		local chispas = Instance.new("ParticleEmitter")
		chispas.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		chispas.Color = ColorSequence.new(COLOR_AURA)
		chispas.LightEmission = 1
		chispas.Lifetime = NumberRange.new(0.4, 0.8)
		chispas.Speed = NumberRange.new(2, 6)
		chispas.SpreadAngle = Vector2.new(180, 180)
		chispas.Size = NumberSequence.new(0.25, 0)
		chispas.Rate = 15
		chispas.Parent = adjunto
		local luz = Instance.new("PointLight")
		luz.Color = COLOR_AURA
		luz.Range = 10
		luz.Brightness = 1
		luz.Parent = adjunto
		actual = { adjunto = adjunto, emisores = { llamas, chispas }, llamas = llamas, luz = luz }
		auras[personaje] = actual
	end
	intensidad = intensidad or 0.5
	actual.llamas.Rate = 25 + 70 * intensidad
	actual.luz.Brightness = 0.5 + 2.5 * intensidad
end

-- ===== Fijar objetivo =====
local marcaObjetivo = nil

local function soltarObjetivo()
	objetivo = nil
	if marcaObjetivo then
		marcaObjetivo:Destroy()
		marcaObjetivo = nil
	end
	local camara = Workspace.CurrentCamera
	if camara then
		camara.CameraType = Enum.CameraType.Custom
	end
	local _, humanoide = vivo()
	if humanoide then
		humanoide.AutoRotate = true
	end
end

local function buscarObjetivo()
	local _, _, raiz = vivo()
	local camara = Workspace.CurrentCamera
	if not (raiz and camara) then
		return nil
	end
	local mejor, puntos = nil, -math.huge
	for _, enemigo in CollectionService:GetTagged("Enemigo") do
		local r = enemigo:FindFirstChild("HumanoidRootPart")
		local h = enemigo:FindFirstChildOfClass("Humanoid")
		if r and h and h.Health > 0 then
			local hacia = r.Position - raiz.Position
			local distancia = hacia.Magnitude
			if distancia < 70 and distancia > 0.1 then
				local frente = camara.CFrame.LookVector:Dot(hacia.Unit)
				local p = frente * 2 - distancia / 70
				if frente > 0.3 and p > puntos then
					mejor, puntos = enemigo, p
				end
			end
		end
	end
	return mejor
end

local function fijar()
	if objetivo then
		soltarObjetivo()
		return
	end
	local enemigo = buscarObjetivo()
	if not enemigo then
		return
	end
	objetivo = enemigo
	local raizEnemigo = enemigo:FindFirstChild("HumanoidRootPart")
	marcaObjetivo = Instance.new("BillboardGui")
	marcaObjetivo.Size = UDim2.fromOffset(34, 34)
	marcaObjetivo.AlwaysOnTop = true
	marcaObjetivo.Adornee = raizEnemigo
	marcaObjetivo.Parent = jugador:WaitForChild("PlayerGui")
	local rombo = Instance.new("Frame")
	rombo.AnchorPoint = Vector2.new(0.5, 0.5)
	rombo.Position = UDim2.fromScale(0.5, 0.5)
	rombo.Size = UDim2.fromOffset(16, 16)
	rombo.Rotation = 45
	rombo.BackgroundColor3 = Color3.fromRGB(255, 70, 60)
	rombo.BackgroundTransparency = 0.15
	rombo.Parent = marcaObjetivo
	local borde = Instance.new("UIStroke")
	borde.Color = Color3.new(1, 1, 1)
	borde.Thickness = 2
	borde.Parent = rombo
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	enCombateHasta = os.clock() + ArmasConfig.TIEMPO_EN_COMBATE
end

local function actualizarCamaraFijada(dt)
	if not objetivo then
		return
	end
	local _, humanoide, raiz = vivo()
	local raizEnemigo = objetivo.Parent and objetivo:FindFirstChild("HumanoidRootPart")
	local h = objetivo:FindFirstChildOfClass("Humanoid")
	if not (raiz and raizEnemigo and h and h.Health > 0) or (raizEnemigo.Position - raiz.Position).Magnitude > 95 then
		soltarObjetivo()
		return
	end
	enCombateHasta = math.max(enCombateHasta, os.clock() + 1)
	local hacia = raizEnemigo.Position - raiz.Position
	local plano = Vector3.new(hacia.X, 0, hacia.Z)
	if plano.Magnitude > 0.5 then
		plano = plano.Unit
		-- el personaje mira al enemigo (salvo al esquivar, que lo controla la esquiva)
		if not jugador.Character:GetAttribute("AnimacionExterna") then
			humanoide.AutoRotate = false
			raiz.CFrame = raiz.CFrame:Lerp(CFrame.lookAt(raiz.Position, raiz.Position + plano), math.min(1, dt * 14))
		end
		local derecha = plano:Cross(Vector3.yAxis)
		local camara = Workspace.CurrentCamera
		local deseada = CFrame.lookAt(raiz.Position - plano * 13 + Vector3.new(0, 5, 0) + derecha * 2.5, raizEnemigo.Position + Vector3.new(0, 1, 0))
		camara.CFrame = camara.CFrame:Lerp(deseada, math.min(1, dt * 10))
	end
end

-- ===== Guardia (postura de combate) =====
local function entrarCombate()
	enCombateHasta = os.clock() + ArmasConfig.TIEMPO_EN_COMBATE
	if miAnimador then
		miAnimador:Postura(Anims.GUARDIA, 0.18)
	end
end

-- ===== Golpes =====

-- Hacia dónde golpear: al enemigo fijado; si no hay, al enemigo cercano que tengas
-- más o menos delante (ayuda suave al apuntar); si no, hacia donde mira la cámara.
local function mirarAlFrente(raiz)
	local direccion
	if objetivo and objetivo:FindFirstChild("HumanoidRootPart") then
		direccion = objetivo.HumanoidRootPart.Position - raiz.Position
	else
		local camara = Workspace.CurrentCamera.CFrame.LookVector
		local frente = Vector3.new(camara.X, 0, camara.Z)
		frente = if frente.Magnitude > 0.01 then frente.Unit else raiz.CFrame.LookVector
		direccion = frente
		local mejor = 10
		for _, enemigo in CollectionService:GetTagged("Enemigo") do
			local r = enemigo:FindFirstChild("HumanoidRootPart")
			if r then
				local hacia = Vector3.new(r.Position.X - raiz.Position.X, 0, r.Position.Z - raiz.Position.Z)
				local distancia = hacia.Magnitude
				if distancia < mejor and distancia > 0.1 and frente:Dot(hacia.Unit) > 0.35 then
					mejor = distancia
					direccion = hacia
				end
			end
		end
	end
	direccion = Vector3.new(direccion.X, 0, direccion.Z)
	if direccion.Magnitude > 0.1 then
		raiz.CFrame = CFrame.lookAt(raiz.Position, raiz.Position + direccion.Unit)
	end
end

-- Distancia al enemigo más cercano que tengo delante (o nil)
local function enemigoDelante(raiz, alcance)
	local mejor = nil
	for _, enemigo in CollectionService:GetTagged("Enemigo") do
		local r = enemigo:FindFirstChild("HumanoidRootPart")
		if r then
			local hacia = r.Position - raiz.Position
			local plano = Vector3.new(hacia.X, 0, hacia.Z)
			local distancia = plano.Magnitude
			if distancia < alcance and distancia > 0.1 and raiz.CFrame.LookVector:Dot(plano.Unit) > 0.5 then
				if not mejor or distancia < mejor then
					mejor = distancia
				end
			end
		end
	end
	return mejor
end

-- Avanza con el golpe, pero sin atravesar al enemigo: se para a distancia de golpe
local function avanzar(raiz, studs, tiempo)
	local distancia = enemigoDelante(raiz, 14)
	if distancia then
		studs = math.min(studs, math.max(0, distancia - 3.4))
	else
		studs *= 0.6
	end
	if studs <= 0.2 then
		return
	end
	local adjunto = Instance.new("Attachment")
	adjunto.Parent = raiz
	local fuerza = Instance.new("LinearVelocity")
	fuerza.Attachment0 = adjunto
	fuerza.MaxForce = 1e5
	fuerza.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	fuerza.PrimaryTangentAxis = Vector3.xAxis
	fuerza.SecondaryTangentAxis = Vector3.zAxis
	local frente = raiz.CFrame.LookVector
	fuerza.PlaneVelocity = Vector2.new(frente.X, frente.Z) * (studs / tiempo)
	fuerza.RelativeTo = Enum.ActuatorRelativeTo.World
	fuerza.Parent = raiz
	task.delay(tiempo, function()
		fuerza:Destroy()
		adjunto:Destroy()
	end)
end

-- Reproduce un golpe en cualquier personaje (el mío o el de otro jugador)
local function animarGolpe(personaje, idAnim, velocidad)
	local animador = Animador.De(personaje)
	local anim = Anims[idAnim]
	if not (animador and anim) then
		return
	end
	local raiz = personaje:FindFirstChild("HumanoidRootPart")
	animador:Reproducir(anim, {
		velocidad = velocidad or 1,
		alEvento = function(nombre, evento)
			if nombre == "silbido" then
				Efectos.Sonido(raiz, if evento.fuerte then "SilbidoFuerte" else "Silbido")
			elseif nombre == "pisada" then
				Efectos.Sonido(raiz, "Pisada")
			end
		end,
	})
	silenciar(personaje, anim.duracion / (velocidad or 1) + 0.05)
end

local function golpeLigero()
	local personaje, _, raiz = vivo()
	if not (personaje and miAnimador) or cargando then
		return
	end
	if personaje:GetAttribute("AnimacionExterna") then
		return -- esquivando
	end
	local ahora = os.clock()
	local siguiente = if ahora <= finGolpe + ARMA.VentanaCombo and indice < #ARMA.Combo then indice + 1 else 1
	local golpe = ARMA.Combo[siguiente]
	if (jugador:GetAttribute("Estamina") or 0) < golpe.Estamina then
		return
	end
	indice = siguiente
	local velocidad = jugador:GetAttribute("VelocidadAtaque") or 1
	finGolpe = ahora + golpe.Duracion / velocidad
	RemoteCombate:FireServer("Ligero")
	mirarAlFrente(raiz)
	entrarCombate()
	animarGolpe(personaje, golpe.Id, velocidad)
	task.delay(0.02, avanzar, raiz, golpe.Avance, 0.12)
	if indice >= #ARMA.Combo then
		indice = 0
	end
end

local function pedirGolpe()
	if os.clock() < finGolpe - 0.12 then
		pendiente = os.clock() -- se lanza en cuanto termine el golpe actual
	else
		golpeLigero()
	end
end

local function empezarCarga()
	local personaje, _, raiz = vivo()
	if not (personaje and miAnimador) or cargando or os.clock() < finGolpe - 0.05 then
		return false
	end
	if personaje:GetAttribute("AnimacionExterna") then
		return false
	end
	if (jugador:GetAttribute("Estamina") or 0) < ARMA.Pesado.Estamina then
		return false
	end
	cargando = true
	cargaDesde = os.clock()
	pendiente = nil
	RemoteCombate:FireServer("Cargar")
	mirarAlFrente(raiz)
	entrarCombate()
	miAnimador:Reproducir(Anims.Carga)
	silenciar(personaje, ARMA.Pesado.CargaMaxima + 2)
	Efectos.Sonido(raiz, "Carga")
	aura(personaje, true, 0.2)
	return true
end

local function soltarCarga()
	local personaje, _, raiz = vivo()
	cargando = false
	if not personaje then
		return
	end
	miAnimador:Temblar(0)
	aura(personaje, false)
	RemoteCombate:FireServer("Pesado")
	local golpe = ARMA.Pesado
	finGolpe = os.clock() + golpe.Duracion
	indice = 0
	mirarAlFrente(raiz)
	animarGolpe(personaje, golpe.Id, 1)
	task.delay(0.02, avanzar, raiz, golpe.Avance, 0.14)
	Efectos.GolpeFOV(6)
end

-- ===== Teclas =====

local function alPulsarAtaque()
	pulsadoDesde = os.clock()
	local marca = pulsadoDesde
	task.delay(ARMA.Pesado.CargaMinima, function()
		if pulsadoDesde == marca and not cargando then
			-- sigue pulsado: intenta cargar (si está ocupado, lo reintenta un momento)
			for _ = 1, 10 do
				if pulsadoDesde ~= marca then
					return
				end
				if empezarCarga() then
					return
				end
				task.wait(0.05)
			end
		end
	end)
end

local function alSoltarAtaque()
	if cargando then
		soltarCarga()
	elseif pulsadoDesde then
		pedirGolpe()
	end
	pulsadoDesde = nil
end

-- ¿El clic cayó sobre un botón de la interfaz? (los carteles de nombre y vida NO cuentan)
local function clicEnBoton(entrada)
	local guiJugador = jugador:FindFirstChildOfClass("PlayerGui")
	if not guiJugador then
		return false
	end
	local posicion = entrada.Position
	for _, objeto in guiJugador:GetGuiObjectsAtPosition(posicion.X, posicion.Y) do
		if (objeto:IsA("GuiButton") or objeto:IsA("TextBox")) and objeto.Visible then
			return true
		end
	end
	return false
end

UserInputService.InputBegan:Connect(function(entrada, procesado)
	if procesado then
		local raton = entrada.UserInputType == Enum.UserInputType.MouseButton1
			or entrada.UserInputType == Enum.UserInputType.MouseButton2
			or entrada.UserInputType == Enum.UserInputType.MouseButton3
		-- Roblox marca como "procesado" un clic sobre un cartel 3D (el nombre de un muñeco);
		-- solo lo ignoramos si de verdad hay un botón debajo
		if not raton or clicEnBoton(entrada) or UserInputService:GetFocusedTextBox() then
			return
		end
	end
	if Controles.Es("Ataque", entrada) then
		alPulsarAtaque()
	elseif Controles.Es("FijarObjetivo", entrada) then
		fijar()
	end
end)

UserInputService.InputEnded:Connect(function(entrada)
	if Controles.Es("Ataque", entrada) then
		alSoltarAtaque()
	end
end)

-- Botón táctil en móvil (solo aparece en pantallas táctiles)
ContextActionService:BindAction("AtaqueMovil", function(_, estadoEntrada)
	if estadoEntrada == Enum.UserInputState.Begin then
		alPulsarAtaque()
	elseif estadoEntrada == Enum.UserInputState.End then
		alSoltarAtaque()
	end
	return Enum.ContextActionResult.Sink
end, true)
ContextActionService:SetTitle("AtaqueMovil", "Golpe")
ContextActionService:SetPosition("AtaqueMovil", UDim2.new(1, -170, 1, -150))

-- ===== Mensajes del servidor =====

local HIGHLIGHT_COLOR = Color3.new(1, 1, 1)

local function destello(modelo)
	local resaltado = Instance.new("Highlight")
	resaltado.FillColor = HIGHLIGHT_COLOR
	resaltado.OutlineTransparency = 1
	resaltado.FillTransparency = 0.25
	resaltado.DepthMode = Enum.HighlightDepthMode.Occluded
	resaltado.Parent = modelo
	TweenService:Create(resaltado, TweenInfo.new(0.16), { FillTransparency = 1 }):Play()
	task.delay(0.2, function()
		resaltado:Destroy()
	end)
end

RemoteEfecto.OnClientEvent:Connect(function(tipo, a, b, c)
	if tipo == "Accion" then
		-- otro jugador ataca: lo vemos animarse
		local personaje, idAnim = a, c
		if typeof(personaje) ~= "Instance" or personaje == jugador.Character then
			return
		end
		if idAnim == "Carga" then
			local animador = Animador.De(personaje)
			if animador then
				animador:Reproducir(Anims.Carga)
				silenciar(personaje, ARMA.Pesado.CargaMaxima + 1)
				aura(personaje, true, 0.6)
				task.delay(ARMA.Pesado.CargaMaxima + 1, function()
					aura(personaje, false)
				end)
			end
		else
			aura(personaje, false)
			animarGolpe(personaje, idAnim, 1)
		end
	elseif tipo == "Golpe" then
		local atacante, objetivoGolpe, datos = a, b, c
		if typeof(objetivoGolpe) ~= "Instance" or type(datos) ~= "table" then
			return
		end
		local raizObjetivo = objetivoGolpe:FindFirstChild("HumanoidRootPart")
		local congelado = ArmasConfig.HITSTOP[if datos.tipo == "Pesado" then "Pesado" else datos.reaccion] or 0.05
		Efectos.Impacto(datos.posicion, datos.tipo, COLOR_AURA, datos.critico)
		Efectos.Numero(datos.posicion, datos.dano, datos.critico)
		Efectos.Sonido(raizObjetivo, if datos.tipo == "Patada" then "Patada" elseif datos.tipo == "Pesado" then "Pesado" else "Puno")
		if datos.critico then
			Efectos.Sonido(raizObjetivo, "Hueso")
		end
		destello(objetivoGolpe)
		-- reacción del que recibe
		local animObjetivo = Animador.De(objetivoGolpe)
		if animObjetivo then
			local reaccion = if datos.tambalea then "Tambaleo" else "Reaccion" .. tostring(datos.reaccion)
			if Anims[reaccion] then
				animObjetivo:Reproducir(Anims[reaccion])
				silenciar(objetivoGolpe, Anims[reaccion].duracion)
			end
			animObjetivo:Congelar(congelado)
		end
		-- congelado de impacto en el atacante y temblor de cámara si soy yo
		if typeof(atacante) == "Instance" then
			local animAtacante = Animador.De(atacante)
			if animAtacante then
				animAtacante:Congelar(congelado)
			end
			if atacante == jugador.Character then
				local fuerza = if datos.tipo == "Pesado" then 1.6 elseif datos.reaccion == "Leve" then 0.45 else 0.9
				Efectos.Temblor(fuerza * (if datos.critico then 1.4 else 1), 0.14 + congelado)
			end
		end
	end
end)

-- ===== Bucle =====

local function prepararPersonaje(personaje)
	miAnimador = nil
	indice, finGolpe, pendiente, cargando = 0, 0, nil, false
	soltarObjetivo()
	personaje:WaitForChild("Humanoid")
	personaje:WaitForChild("LowerTorso", 10)
	task.wait(0.2)
	miAnimador = Animador.De(personaje)
end

if jugador.Character then
	task.spawn(prepararPersonaje, jugador.Character)
end
jugador.CharacterAdded:Connect(prepararPersonaje)

-- Pruebas en Studio (barra de comandos, vista Client):
--   game.Players.LocalPlayer:SetAttribute("PruebaGolpe", os.clock())   -> un golpe del combo
--   game.Players.LocalPlayer:SetAttribute("PruebaCarga", 1)            -> golpe cargado de 1 s
if RunService:IsStudio() then
	jugador:GetAttributeChangedSignal("PruebaGolpe"):Connect(function()
		golpeLigero()
	end)
	jugador:GetAttributeChangedSignal("PruebaCarga"):Connect(function()
		if empezarCarga() then
			task.wait(jugador:GetAttribute("PruebaCarga") or 1)
			soltarCarga()
		end
	end)
end

local siguienteRevision = 0
RunService.RenderStepped:Connect(function(dt)
	actualizarSilencios()
	actualizarCamaraFijada(dt)
	local ahora = os.clock()

	-- búfer: el clic guardado sale en cuanto se pueda
	if pendiente and ahora >= finGolpe - 0.12 then
		if ahora - pendiente < 0.45 then
			golpeLigero()
		end
		pendiente = nil
	end

	-- temblor y aura mientras cargas
	if cargando and miAnimador then
		local carga = math.clamp((ahora - cargaDesde) / ARMA.Pesado.CargaMaxima, 0, 1)
		miAnimador:Temblar(carga)
		local personaje = jugador.Character
		if personaje then
			aura(personaje, true, carga)
		end
		if carga >= 1 then
			Efectos.Temblor(0.12, 0.05)
		end
	end

	-- guardia: en combate sí, corriendo o tranquilo no
	if miAnimador and ahora >= siguienteRevision then
		siguienteRevision = ahora + 0.2
		local personaje = jugador.Character
		local enCombate = ahora < enCombateHasta and not (personaje and personaje:GetAttribute("Corriendo"))
		if enCombate then
			miAnimador:Postura(Anims.GUARDIA, 0.2)
		else
			miAnimador:Postura(nil, 0.4)
		end
		-- los demás jugadores en combate también se ven en guardia
		for _, otro in Players:GetPlayers() do
			local otroPersonaje = otro.Character
			if otro ~= jugador and otroPersonaje and otroPersonaje:FindFirstChild("HumanoidRootPart") then
				local animOtro = Animador.De(otroPersonaje)
				if animOtro then
					if otroPersonaje:GetAttribute("EnCombate") and not otroPersonaje:GetAttribute("Corriendo") then
						animOtro:Postura(Anims.GUARDIA, 0.2)
					else
						animOtro:Postura(nil, 0.4)
					end
				end
			end
		end
	end
end)

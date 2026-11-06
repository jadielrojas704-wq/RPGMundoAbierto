-- Motor de CINEMÁTICAS (solo CLIENTE): cámara por tomas, franjas negras de cine,
-- subtítulos, fundidos y botón para saltar. Lo usan el prólogo y, más adelante,
-- las presentaciones de los jefes.
-- Ruta en Studio: ReplicatedStorage/Interfaz/Cinematica
--
--   Cinematica.Reproducir({
--       { desde = CFrame, hasta = CFrame, duracion = 6, texto = "...", fov = 60, efecto = "Temblor",
--         preparar = function() end },  -- preparar: se llama justo antes de la toma (con la pantalla negra)
--       ...
--   }, { titulo = "EL ECLIPSE ETERNO", subtitulo = "...", musica = SonidosConfig.MUSICA.Prologo })
-- (espera hasta que acaba). Mientras dura, el personaje no se puede mover.
-- Efectos de cada toma: "Temblor" (la tierra tiembla), "Eclipse" (rugido y luz violeta),
-- "Destello" (relámpago blanco). Cada cinemática lleva su música, un coro de fondo,
-- ráfagas de viento en los cortes, brasas doradas flotando y un golpe épico en el título.
-- Más opciones:
--   opciones.narrador = Voz.PERFILES.Narrador  -> una voz lee el texto de cada toma
--     (cada toma dura lo que haga falta para que se oiga entera); toma.voz = texto distinto al subtítulo
--     toma.perfil = otra voz para esa toma (p. ej. Voz.PERFILES.Eldren)
--   opciones.sinBrasas / opciones.sinCoro / opciones.volumen
--   opciones.alTerminar = function() end  -> se llama con la pantalla en negro, antes de devolver el control
--   toma.camino = function(x, t) return CFrame end   -> movimiento de cámara propio (x de 0 a 1)
--   toma.alEmpezar = function() end                 -> se llama al empezar la toma (mover personajes...)
--   efecto "Dragon": rugido lejano del dragón de las montañas durante unos segundos

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local SonidosConfig = require(ReplicatedStorage.Config.SonidosConfig)
local Voz = require(script.Parent.Voz)
local Idioma = require(ReplicatedStorage.Config.Idioma)

local Cinematica = {}

local ORO = Color3.fromRGB(228, 184, 96)

local function tween(objeto, tiempo, metas, estilo, direccion)
	local t = TweenService:Create(
		objeto,
		TweenInfo.new(tiempo, estilo or Enum.EasingStyle.Quad, direccion or Enum.EasingDirection.InOut),
		metas
	)
	t:Play()
	return t
end

local function suave(x)
	return x * x * (3 - 2 * x)
end

local TECLAS_BLOQUEADAS = {
	Enum.KeyCode.W,
	Enum.KeyCode.A,
	Enum.KeyCode.S,
	Enum.KeyCode.D,
	Enum.KeyCode.Space,
	Enum.KeyCode.Up,
	Enum.KeyCode.Down,
	Enum.KeyCode.Left,
	Enum.KeyCode.Right,
	Enum.KeyCode.LeftShift,
	Enum.KeyCode.Thumbstick1,
}

local reproduciendo = false

-- ===== SONIDO =====
-- Sonido de pantalla (no sale de ningún sitio concreto): se borra solo al acabar
local function sonar(id, volumen, velocidad, duracionMax)
	if not id then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volumen or 0.5
	s.PlaybackSpeed = velocidad or 1
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, duracionMax or 30)
	return s
end

-- Pista larga que entra y sale con fundido
local function pista(id, volumen, bucle)
	if not id then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = "MusicaCinematica"
	s.SoundId = id
	s.Volume = 0
	s.Looped = bucle == true
	s.Parent = SoundService
	s:Play()
	tween(s, 2.5, { Volume = volumen })
	return s
end

local function apagar(s, tiempo)
	if s and s.Parent then
		tween(s, tiempo, { Volume = 0 })
		Debris:AddItem(s, tiempo + 0.2)
	end
end

-- Baja los sonidos del mundo (ambiente, lluvia...) mientras dura la escena
local function bajarMundo(activo)
	pcall(function()
		local grupo = SoundService:FindFirstChild("Mundo") or Instance.new("SoundGroup")
		grupo.Name = "Mundo"
		grupo.Parent = SoundService
		tween(grupo, 1.5, { Volume = if activo then 0.25 else 1 })
	end)
end

-- ===== BRASAS DORADAS que suben flotando por la pantalla =====
local function brasas(pantalla)
	local capa = Instance.new("Frame")
	capa.Name = "Brasas"
	capa.Size = UDim2.fromScale(1, 1)
	capa.BackgroundTransparency = 1
	capa.ZIndex = 3
	capa.Parent = pantalla
	local rng = Random.new()
	local vivo = true
	task.spawn(function()
		while vivo and capa.Parent do
			local b = Instance.new("Frame")
			local tam = rng:NextInteger(2, 6)
			b.Size = UDim2.fromOffset(tam, tam)
			b.AnchorPoint = Vector2.new(0.5, 0.5)
			b.Position = UDim2.fromScale(rng:NextNumber(0, 1), rng:NextNumber(0.85, 1.05))
			b.BackgroundColor3 = if rng:NextNumber() < 0.75
				then Color3.fromRGB(255, rng:NextInteger(150, 205), 90)
				else Color3.fromRGB(205, 160, 255)
			b.BackgroundTransparency = 1
			b.BorderSizePixel = 0
			b.ZIndex = 3
			local r = Instance.new("UICorner")
			r.CornerRadius = UDim.new(1, 0)
			r.Parent = b
			b.Parent = capa
			local vida = rng:NextNumber(4, 8)
			local x = b.Position.X.Scale + rng:NextNumber(-0.08, 0.08)
			tween(b, 0.8, { BackgroundTransparency = rng:NextNumber(0.1, 0.5) })
			tween(b, vida, { Position = UDim2.fromScale(x, rng:NextNumber(0.25, 0.6)) }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			task.delay(vida - 1.2, function()
				if b.Parent then
					tween(b, 1.2, { BackgroundTransparency = 1 })
				end
			end)
			Debris:AddItem(b, vida + 0.2)
			task.wait(rng:NextNumber(0.12, 0.3))
		end
	end)
	return function()
		vivo = false
		Debris:AddItem(capa, 1.5)
	end
end

-- Esconde (o vuelve a enseñar) el chat y la lista de jugadores de Roblox
local function interfazRoblox(visible)
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, visible)
	end)
	pcall(function()
		local chat = game:GetService("TextChatService")
		local ventana = chat:FindFirstChildOfClass("ChatWindowConfiguration")
		local barra = chat:FindFirstChildOfClass("ChatInputBarConfiguration")
		if ventana then
			ventana.Enabled = visible
		end
		if barra then
			barra.Enabled = visible
		end
	end)
end

function Cinematica.Reproduciendo()
	return reproduciendo
end

function Cinematica.Reproducir(tomas, opciones)
	if reproduciendo then
		return
	end
	opciones = opciones or {}
	reproduciendo = true
	local jugador = Players.LocalPlayer
	jugador:SetAttribute("EnCinematica", true)
	interfazRoblox(false)
	-- los carteles flotantes del mundo (nombres de muñecos, NPC...) no salen en la escena
	local carteles = {}
	for _, b in Workspace:GetDescendants() do
		if b:IsA("BillboardGui") and b.Enabled then
			b.Enabled = false
			table.insert(carteles, b)
		end
	end
	local camara = Workspace.CurrentCamera
	local fovAntes = camara.FieldOfView

	-- no moverse durante la escena
	ContextActionService:BindActionAtPriority("BloqueoCinematica", function()
		return Enum.ContextActionResult.Sink
	end, false, 3000, table.unpack(TECLAS_BLOQUEADAS))

	-- ===== interfaz =====
	local pantalla = Instance.new("ScreenGui")
	pantalla.Name = "Cinematica"
	pantalla.IgnoreGuiInset = true
	pantalla.DisplayOrder = 60
	pantalla.ResetOnSpawn = false
	pantalla.Parent = jugador:WaitForChild("PlayerGui")

	local function franja(arriba)
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0, if arriba then 1 else 0)
		f.Position = UDim2.fromScale(0, if arriba then 0 else 1)
		f.Size = UDim2.fromScale(1, 0.12)
		f.ZIndex = 2
		f.Parent = pantalla
		return f
	end
	local arriba, abajo = franja(true), franja(false)
	tween(arriba, 0.8, { AnchorPoint = Vector2.new(0, 0) })
	tween(abajo, 0.8, { AnchorPoint = Vector2.new(0, 1) })

	local negro = Instance.new("Frame")
	negro.Size = UDim2.fromScale(1, 1)
	negro.BackgroundColor3 = Color3.new(0, 0, 0)
	negro.BackgroundTransparency = 0 -- empieza en negro mientras se preparan las voces
	negro.BorderSizePixel = 0
	negro.ZIndex = 5
	negro.Parent = pantalla

	-- destello (relámpago / flash del título)
	local destello = Instance.new("Frame")
	destello.Size = UDim2.fromScale(1, 1)
	destello.BackgroundColor3 = Color3.new(1, 1, 1)
	destello.BackgroundTransparency = 1
	destello.BorderSizePixel = 0
	destello.ZIndex = 9
	destello.Parent = pantalla
	local function flash(color, fuerza, tiempo)
		destello.BackgroundColor3 = color or Color3.new(1, 1, 1)
		destello.BackgroundTransparency = 1 - (fuerza or 0.7)
		tween(destello, tiempo or 0.9, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end

	-- viñeta: bordes oscuros que centran la mirada
	local vineta = Instance.new("Frame")
	vineta.Size = UDim2.fromScale(1, 1)
	vineta.BackgroundColor3 = Color3.new(0, 0, 0)
	vineta.BorderSizePixel = 0
	vineta.ZIndex = 1
	vineta.Parent = pantalla
	local degradadoVineta = Instance.new("UIGradient")
	degradadoVineta.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.22, 1),
		NumberSequenceKeypoint.new(0.78, 1),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	degradadoVineta.Parent = vineta

	local subtitulo = Instance.new("TextLabel")
	subtitulo.AnchorPoint = Vector2.new(0.5, 1)
	subtitulo.Position = UDim2.new(0.5, 0, 1, -14)
	subtitulo.Size = UDim2.new(0.86, 0, 0.115, -6)
	subtitulo.BackgroundTransparency = 1
	subtitulo.Font = Enum.Font.SourceSansSemibold -- letra clara para leer rápido
	subtitulo.TextScaled = true
	subtitulo.TextColor3 = Color3.fromRGB(240, 232, 214)
	subtitulo.TextStrokeTransparency = 0.35
	subtitulo.TextTransparency = 1
	subtitulo.RichText = true
	subtitulo.Text = ""
	subtitulo.ZIndex = 6
	subtitulo.Parent = pantalla
	local limite = Instance.new("UITextSizeConstraint")
	limite.MaxTextSize = 34
	limite.MinTextSize = 16
	limite.Parent = subtitulo

	local saltar = Instance.new("TextButton")
	saltar.AnchorPoint = Vector2.new(1, 0)
	saltar.Position = UDim2.new(1, -24, 0, 18)
	saltar.Size = UDim2.fromOffset(130, 34)
	saltar.BackgroundColor3 = Color3.fromRGB(16, 14, 20)
	saltar.BackgroundTransparency = 0.3
	saltar.BorderSizePixel = 0
	saltar.Font = Enum.Font.GothamBold
	saltar.TextSize = 14
	saltar.TextColor3 = ORO
	saltar.Text = "SALTAR  ▸"
	saltar.ZIndex = 7
	saltar.Parent = pantalla
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, 5)
	esquina.Parent = saltar

	local saltado = false
	saltar.MouseButton1Click:Connect(function()
		saltado = true
	end)
	local conexionTecla = UserInputService.InputBegan:Connect(function(entrada)
		if entrada.KeyCode == Enum.KeyCode.Return or entrada.KeyCode == Enum.KeyCode.Escape then
			saltado = true
		end
	end)

	local correccion = Instance.new("ColorCorrectionEffect")
	correccion.Name = "CinematicaColor"
	correccion.Contrast = 0.08
	correccion.Saturation = -0.1
	correccion.Parent = Lighting
	local brillo = Instance.new("BloomEffect")
	brillo.Name = "CinematicaBrillo"
	brillo.Intensity = 0.55
	brillo.Size = 32
	brillo.Threshold = 1.4
	brillo.Parent = Lighting

	-- ===== música y ambiente =====
	bajarMundo(true)
	local volumenMusica = opciones.volumen or 0.4
	local musica = pista(opciones.musica or SonidosConfig.MUSICA.Prologo, volumenMusica, true)
	local coro = if opciones.sinCoro then nil else pista(SonidosConfig.CINE.Coro, 0.13, true)
	sonar(SonidosConfig.CINE.Zumbido, 0.25, 0.8, 12)
	local pararBrasas = if opciones.sinBrasas then function() end else brasas(pantalla)

	-- ===== voces: se generan todas antes de empezar (mientras entran las franjas) =====
	-- (Roblox solo deja generar una voz cada segundo más o menos: se generan en orden, en
	-- segundo plano, mientras las tomas avanzan; se espera a tener al menos la primera)
	local voces = {}
	local conVoz = {}
	do
		for i, toma in tomas do
			local texto = toma.voz or (if opciones.narrador or toma.perfil then toma.texto else nil)
			if texto and texto ~= "" then
				conVoz[i] = true
				task.spawn(function()
					voces[i] = Voz.Preparar(texto, toma.perfil or opciones.narrador)
				end)
			end
		end
		local primera = nil
		for i = 1, #tomas do
			if conVoz[i] then
				primera = i
				break
			end
		end
		local espera = os.clock()
		while primera and not voces[primera] and os.clock() - espera < 6 and not saltado do
			task.wait(0.05)
		end
	end
	-- la música baja mientras alguien habla
	local function bajarMusica(hablando)
		if musica and musica.Parent then
			tween(musica, 0.6, { Volume = if hablando then volumenMusica * 0.45 else volumenMusica })
		end
	end

	-- ===== tomas =====
	camara.CameraType = Enum.CameraType.Scriptable
	for i, toma in tomas do
		if saltado then
			break
		end
		if toma.preparar then
			pcall(toma.preparar) -- p. ej. cargar esa zona del mapa antes de enseñarla
		end
		camara.FieldOfView = toma.fov or 60
		camara.CFrame = if toma.camino then toma.camino(0, 0) else toma.desde
		if i == 1 then
			tween(negro, 0.9, { BackgroundTransparency = 1 })
		else
			tween(negro, 0.45, { BackgroundTransparency = 1 })
			sonar(SonidosConfig.CINE.Corte, 0.18, 1, 8) -- ráfaga de viento en el corte
		end
		-- texto
		-- subtítulo en el idioma del jugador (y el nombre de quien habla, en dorado)
		local textoToma = Idioma.T(toma.texto or "")
		if toma.quien and textoToma ~= "" then
			textoToma = string.format('<font color="#E4B860"><b>%s</b></font>   %s', toma.quien, textoToma)
		end
		subtitulo.Text = textoToma
		subtitulo.TextTransparency = 1
		tween(subtitulo, 0.8, { TextTransparency = 0 })
		if toma.alEmpezar then
			pcall(toma.alEmpezar)
		end
		local inicio = os.clock()
		local duracion = toma.duracion or 5
		-- si la voz de esta toma aún se está generando, se espera un momento
		local esperaVoz = os.clock()
		while conVoz[i] and not voces[i] and os.clock() - esperaVoz < 2.5 and not saltado do
			task.wait(0.05)
		end
		local voz = voces[i]
		if voz and voz.duracion > 0 then
			-- la toma dura al menos lo que tarda la voz, más un respiro
			duracion = math.max(duracion, voz.duracion + 1.3)
			task.delay(0.35, function()
				if not saltado then
					bajarMusica(true)
					voz:Reproducir()
					task.delay(voz.duracion, bajarMusica, false)
				end
			end)
		end
		local temblando = toma.efecto == "Temblor" or toma.efecto == "Dragon"
		if toma.efecto == "Eclipse" or temblando then
			correccion.TintColor = Color3.fromRGB(220, 190, 255)
			tween(correccion, duracion, { TintColor = Color3.new(1, 1, 1) })
		end
		if toma.efecto == "Eclipse" then
			sonar(SonidosConfig.CINE.Eclipse, 0.42, 0.85, 15)
			flash(Color3.fromRGB(190, 120, 255), 0.55, 1.6)
			brillo.Intensity = 1.4
			tween(brillo, duracion, { Intensity = 0.55 })
		elseif toma.efecto == "Dragon" then
			-- el dragón oculto ruge entre los picos unos segundos (lejano, con eco)
			task.delay(0.9, function()
				if saltado then
					return
				end
				local rugido = sonar(SonidosConfig.DRAGON.Rugidos[1], 0.5, 0.55, 12)
				local eco = Instance.new("EchoSoundEffect")
				eco.Delay = 0.5
				eco.Feedback = 0.35
				eco.WetLevel = -6
				eco.Parent = rugido
				local graves = Instance.new("EqualizerSoundEffect")
				graves.LowGain = 6
				graves.HighGain = -8
				graves.Parent = rugido
				sonar(SonidosConfig.DRAGON.Trueno, 0.35, 0.5, 10)
				task.delay(3.6, function()
					if rugido.Parent then
						tween(rugido, 1.2, { Volume = 0 })
					end
				end)
			end)
		elseif temblando then
			sonar(SonidosConfig.CINE.Golpe, 0.32, 0.7, 12)
		elseif toma.efecto == "Destello" then
			sonar(SonidosConfig.CINE.Golpe, 0.42, 1, 12)
			flash(Color3.new(1, 1, 1), 0.85, 0.7)
		end
		if toma.sonido then
			sonar(toma.sonido, toma.volumenSonido or 0.4, 1, 20)
		end
		while os.clock() - inicio < duracion and not saltado do
			local x = suave(math.clamp((os.clock() - inicio) / duracion, 0, 1))
			local cf = if toma.camino then toma.camino(x, os.clock() - inicio) else toma.desde:Lerp(toma.hasta, x)
			if temblando then
				local f = 0.25 * (1 - x * 0.5)
				cf *= CFrame.Angles(
					math.rad(math.noise(os.clock() * 18, 1) * f * 4),
					math.rad(math.noise(os.clock() * 18, 2) * f * 4),
					0
				)
			end
			camara.CFrame = cf
			if toma.fovFinal then
				camara.FieldOfView = (toma.fov or 60) + ((toma.fovFinal - (toma.fov or 60)) * x)
			end
			-- el texto se va un poco antes del corte
			if duracion - (os.clock() - inicio) < 0.7 and subtitulo.TextTransparency == 0 then
				tween(subtitulo, 0.6, { TextTransparency = 1 })
			end
			RunService.RenderStepped:Wait()
		end
		if voz then
			voz:Parar(0.3)
		end
		if i < #tomas and not saltado then
			tween(negro, 0.4, { BackgroundTransparency = 0 }).Completed:Wait()
		end
	end

	-- ===== cartel final =====
	if opciones.titulo and not saltado then
		tween(negro, 0.8, { BackgroundTransparency = 0 }).Completed:Wait()
		local titulo = Instance.new("TextLabel")
		titulo.AnchorPoint = Vector2.new(0.5, 0.5)
		titulo.Position = UDim2.fromScale(0.5, 0.46)
		titulo.Size = UDim2.new(0.9, 0, 0, 90)
		titulo.BackgroundTransparency = 1
		titulo.Font = Enum.Font.Garamond
		titulo.TextSize = 72
		titulo.TextColor3 = Color3.new(1, 1, 1)
		titulo.TextTransparency = 1
		titulo.Text = opciones.titulo
		titulo.ZIndex = 8
		titulo.Parent = pantalla
		local degradado = Instance.new("UIGradient")
		degradado.Rotation = 90
		degradado.Color = ColorSequence.new(Color3.fromRGB(255, 244, 214), ORO)
		degradado.Parent = titulo
		local sub = titulo:Clone()
		sub.Position = UDim2.fromScale(0.5, 0.56)
		sub.Size = UDim2.new(0.9, 0, 0, 30)
		sub.TextSize = 22
		sub.Text = Idioma.T(opciones.subtitulo or "")
		sub.Parent = pantalla
		sonar(SonidosConfig.CINE.Golpe, 0.55, 0.85, 12) -- golpe épico del título
		flash(Color3.fromRGB(255, 236, 200), 0.9, 1.4)
		tween(titulo, 1.4, { TextTransparency = 0 })
		tween(sub, 1.8, { TextTransparency = 0.2 })
		local espera = os.clock()
		while os.clock() - espera < 3.6 and not saltado do
			RunService.RenderStepped:Wait()
		end
		tween(titulo, 0.8, { TextTransparency = 1 })
		tween(sub, 0.8, { TextTransparency = 1 }).Completed:Wait()
	else
		tween(negro, 0.5, { BackgroundTransparency = 0 }).Completed:Wait()
	end

	-- con la pantalla en negro: quien llamó a la cinemática recoge sus cosas (actores, posición...)
	if opciones.alTerminar then
		pcall(opciones.alTerminar)
	end

	-- ===== volver al juego =====
	conexionTecla:Disconnect()
	ContextActionService:UnbindAction("BloqueoCinematica")
	pararBrasas()
	for _, voz in voces do
		voz:Destruir()
	end
	-- las que aún se estuvieran generando se borran al acabar
	task.delay(12, function()
		for _, voz in voces do
			voz:Destruir()
		end
	end)
	apagar(musica, 2)
	apagar(coro, 2)
	bajarMundo(false)
	correccion:Destroy()
	brillo:Destroy()
	camara.CameraType = Enum.CameraType.Custom
	camara.FieldOfView = fovAntes
	local personaje = jugador.Character
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	if humanoide then
		camara.CameraSubject = humanoide
	end
	subtitulo.Visible = false
	saltar.Visible = false
	tween(arriba, 0.6, { AnchorPoint = Vector2.new(0, 1) })
	tween(abajo, 0.6, { AnchorPoint = Vector2.new(0, 0) })
	tween(negro, 0.9, { BackgroundTransparency = 1 }).Completed:Wait()
	pantalla:Destroy()
	for _, b in carteles do
		if b.Parent then
			b.Enabled = true
		end
	end
	jugador:SetAttribute("EnCinematica", nil)
	interfazRoblox(true)
	reproduciendo = false
end

return Cinematica

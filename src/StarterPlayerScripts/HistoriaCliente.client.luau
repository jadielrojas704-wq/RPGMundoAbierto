-- La HISTORIA en el cliente: rastreador de la misión, marca del objetivo, diálogos,
-- avisos de misión, textos antiguos, estado del vampiro y el Eclipse en el cielo.
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/HistoriaCliente
-- Solo dibuja: lo que pasa de verdad lo decide ServerScriptService/Historia/MisionesServicio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Estilo = require(ReplicatedStorage:WaitForChild("Interfaz"):WaitForChild("Estilo"))
local Pergamino = require(ReplicatedStorage.Interfaz:WaitForChild("Pergamino"))
local Voz = require(ReplicatedStorage.Interfaz:WaitForChild("Voz"))
local HistoriaConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("HistoriaConfig"))
local Remoto = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Historia")

local jugador = Players.LocalPlayer
local C = Estilo.COLORES
local MORADO = HistoriaConfig.COLOR_ECLIPSE

local function tween(objeto, tiempo, metas, estilo)
	local t = TweenService:Create(
		objeto,
		TweenInfo.new(tiempo, estilo or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		metas
	)
	t:Play()
	return t
end

local function sonido(id, volumen)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volumen or 0.5
	s.Parent = Workspace
	s:Play()
	task.delay(4, function()
		s:Destroy()
	end)
end

local pantalla = Instance.new("ScreenGui")
pantalla.Name = "Historia"
pantalla.ResetOnSpawn = false
pantalla.DisplayOrder = 8
pantalla.Parent = jugador:WaitForChild("PlayerGui")
local escala = Instance.new("UIScale")
escala.Parent = pantalla
local function ajustarEscala()
	local camara = Workspace.CurrentCamera
	escala.Scale = math.clamp((camara and camara.ViewportSize.Y or 900) / 900, 0.7, 1.2)
end
ajustarEscala()
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajustarEscala)

local function visible()
	pantalla.Enabled = jugador:GetAttribute("EnMenu") ~= true and not jugador:GetAttribute("EnCinematica")
end
visible()
jugador:GetAttributeChangedSignal("EnMenu"):Connect(visible)
jugador:GetAttributeChangedSignal("EnCinematica"):Connect(visible)

-- ===== Rastreador de la misión (arriba a la derecha) =====
local rastreador = Estilo.Marco(pantalla, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -18, 0, 384), -- debajo del minimapa
	Size = UDim2.fromOffset(300, 92),
	BackgroundTransparency = 1,
})
local textoActo = Estilo.Texto(rastreador, {
	Size = UDim2.new(1, 0, 0, 14),
	TextXAlignment = Enum.TextXAlignment.Right,
	TextSize = 11,
	Font = Estilo.FUERTE,
	TextColor3 = Color3.fromRGB(190, 150, 255),
	TextStrokeTransparency = 0.6,
	Text = "",
})
local textoTitulo = Estilo.Texto(rastreador, {
	Position = UDim2.fromOffset(0, 15),
	Size = UDim2.new(1, 0, 0, 24),
	TextXAlignment = Enum.TextXAlignment.Right,
	Font = Estilo.TITULO,
	TextSize = 24,
	TextColor3 = C.oro,
	TextStrokeTransparency = 0.5,
	Text = "",
})
local rombo = Estilo.Marco(rastreador, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 46),
	Size = UDim2.fromOffset(8, 8),
	Rotation = 45,
	BackgroundColor3 = C.oro,
})
local textoObjetivo = Estilo.Texto(rastreador, {
	Position = UDim2.fromOffset(0, 40),
	Size = UDim2.new(1, -16, 0, 34),
	TextXAlignment = Enum.TextXAlignment.Right,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = true,
	TextSize = 14,
	TextStrokeTransparency = 0.5,
	Text = "",
})
local textoDistancia = Estilo.Texto(rastreador, {
	Position = UDim2.fromOffset(0, 74),
	Size = UDim2.new(1, -16, 0, 16),
	TextXAlignment = Enum.TextXAlignment.Right,
	TextSize = 12,
	TextColor3 = C.textoSuave,
	TextStrokeTransparency = 0.6,
	Text = "",
})
rastreador.Visible = false

-- ===== Marca del objetivo en el mundo =====
local ancla = Instance.new("Part")
ancla.Name = "MarcaObjetivo"
ancla.Anchored = true
ancla.CanCollide = false
ancla.CanQuery = false
ancla.CanTouch = false
ancla.Transparency = 1
ancla.Size = Vector3.one * 0.2
ancla.Parent = Workspace
local marca = Instance.new("BillboardGui")
marca.Size = UDim2.fromOffset(120, 60)
marca.AlwaysOnTop = true
marca.LightInfluence = 0
marca.Adornee = ancla
marca.Enabled = false
marca.Parent = pantalla
local romboMarca = Estilo.Marco(marca, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 4),
	Size = UDim2.fromOffset(18, 18),
	Rotation = 45,
	BackgroundColor3 = C.oro,
})
Estilo.Borde(romboMarca, Color3.new(0, 0, 0), 1.5, 0.3)
local distanciaMarca = Estilo.Texto(marca, {
	Position = UDim2.fromOffset(0, 30),
	Size = UDim2.new(1, 0, 0, 18),
	TextXAlignment = Enum.TextXAlignment.Center,
	Font = Estilo.FUERTE,
	TextSize = 14,
	TextColor3 = C.oro,
	TextStrokeTransparency = 0.3,
	Text = "",
})

local estadoMision = nil

-- ===== Rastrear la misión (tecla T de fábrica): marca en el mundo y en el minimapa =====
local Controles = require(ReplicatedStorage:WaitForChild("Combate"):WaitForChild("Controles"))
local rastreando = true
jugador:SetAttribute("Rastreando", true)
UserInputService.InputBegan:Connect(function(entrada, procesado)
	if procesado or jugador:GetAttribute("EnMenu") or jugador:GetAttribute("EnCinematica") then
		return
	end
	if Controles.Es("Rastrear", entrada) then
		rastreando = not rastreando
		jugador:SetAttribute("Rastreando", rastreando)
		sonido("rbxasset://sounds/electronicpingshort.wav", 0.35)
	end
end)

local function mostrarMision(info)
	estadoMision = info
	if not info then
		rastreador.Visible = false
		marca.Enabled = false
		return
	end
	rastreador.Visible = true
	textoActo.Text = string.upper(info.acto or "")
	textoTitulo.Text = info.titulo or ""
	local progreso = if info.total and info.total > 1
		then string.format("  (%d/%d)", info.hechos or 0, info.total)
		else ""
	textoObjetivo.Text = (info.objetivo or "") .. progreso
	rombo.Visible = not info.fin
	if info.destino then
		ancla.Position = info.destino + Vector3.new(0, 7, 0)
	end
	-- el minimapa lee aquí dónde está el objetivo
	jugador:SetAttribute("DestinoMision", if info.fin then nil else info.destino)
end

-- ===== Avisos de misión (arriba en el centro) =====
local libreDesde = 0 -- los avisos salen uno detrás de otro
local function aviso(cabecera, titulo, detalle, color)
	local espera = math.max(0, libreDesde - os.clock())
	libreDesde = os.clock() + espera + 4.8
	if espera > 0 then
		task.wait(espera)
	end
	local caja = Estilo.Marco(pantalla, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -120),
		Size = UDim2.fromOffset(520, 96),
		BackgroundColor3 = C.fondo,
		BackgroundTransparency = 0.12,
	})
	Estilo.Esquinas(caja, 8)
	Estilo.Borde(caja, color or C.oro, 1.5)
	local degradado = Instance.new("UIGradient")
	degradado.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 0.6),
	})
	degradado.Parent = caja
	Estilo.Texto(caja, {
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Estilo.FUERTE,
		TextSize = 13,
		TextColor3 = color or C.oro,
		Text = cabecera,
	})
	Estilo.Texto(caja, {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Estilo.TITULO,
		TextSize = 32,
		Text = titulo,
	})
	Estilo.Texto(caja, {
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 14,
		TextColor3 = C.textoSuave,
		Text = detalle or "",
	})
	sonido("rbxasset://sounds/electronicpingshort.wav", 0.6)
	tween(caja, 0.5, { Position = UDim2.new(0.5, 0, 0, 92) }, Enum.EasingStyle.Back)
	task.delay(4.2, function()
		tween(caja, 0.4, { Position = UDim2.new(0.5, 0, 0, -120) }).Completed:Wait()
		caja:Destroy()
	end)
end

local function textoRecompensa(r)
	local partes = {}
	if r.Exp then
		table.insert(partes, "+" .. r.Exp .. " EXP")
	end
	if r.Oro then
		table.insert(partes, "+" .. r.Oro .. " de oro")
	end
	if r.GirosRaza then
		table.insert(partes, "+" .. r.GirosRaza .. " giro de raza")
	end
	if r.GirosAfinidad then
		table.insert(partes, "+" .. r.GirosAfinidad .. " giro de afinidad")
	end
	return table.concat(partes, "   ·   ")
end

-- ===== Diálogos (abajo en el centro) =====
local caja = Estilo.Marco(pantalla, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -96),
	Size = UDim2.fromOffset(640, 118),
	BackgroundColor3 = C.fondo,
	BackgroundTransparency = 0.08,
	Visible = false,
})
Estilo.Esquinas(caja, 8)
Estilo.Borde(caja, MORADO, 1.5, 0.2)
local nombreHablante = Estilo.Texto(caja, {
	Position = UDim2.fromOffset(20, 10),
	Size = UDim2.new(1, -40, 0, 22),
	Font = Estilo.TITULO,
	TextSize = 22,
	TextColor3 = C.oro,
	Text = "",
})
local textoDialogo = Estilo.Texto(caja, {
	Position = UDim2.fromOffset(20, 36),
	Size = UDim2.new(1, -40, 0, 56),
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextSize = 17,
	Text = "",
})
Estilo.Texto(caja, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, -8),
	Size = UDim2.fromOffset(300, 16),
	TextXAlignment = Enum.TextXAlignment.Right,
	TextSize = 12,
	TextColor3 = C.textoSuave,
	Text = "Clic o Enter para seguir",
})
local botonDialogo = Instance.new("TextButton")
botonDialogo.BackgroundTransparency = 1
botonDialogo.Text = ""
botonDialogo.Size = UDim2.fromScale(1, 1)
botonDialogo.Parent = caja

local cola = {} -- { nombre, lineas }
local lineaActual, lineasActuales = 0, nil
local escribiendo = false

local function mostrarLinea()
	local linea = lineasActuales and lineasActuales[lineaActual]
	if not linea then
		Voz.Callar("dialogo")
		caja.Visible = false
		lineasActuales = nil
		if #cola > 0 then
			local siguiente = table.remove(cola, 1)
			nombreHablante.Text = siguiente.nombre
			lineasActuales, lineaActual = siguiente.lineas, 1
			caja.Visible = true
			mostrarLinea()
		end
		return
	end
	textoDialogo.Text = linea
	textoDialogo.MaxVisibleGraphemes = 0
	escribiendo = true
	-- cada personaje con su voz (el Custodio, de momento, es el que habla por el amuleto)
	task.spawn(Voz.Decir, linea, Voz.PERFILES.Eldren, "dialogo")
	sonido("rbxasset://sounds/clickfast.wav", 0.15)
	task.spawn(function()
		local inicio = os.clock()
		local total = utf8.len(linea) or #linea
		while
			escribiendo
			and textoDialogo.Text == linea
			and textoDialogo.MaxVisibleGraphemes ~= -1
			and textoDialogo.MaxVisibleGraphemes < total
		do
			textoDialogo.MaxVisibleGraphemes = math.floor((os.clock() - inicio) * 45)
			RunService.RenderStepped:Wait()
		end
		textoDialogo.MaxVisibleGraphemes = -1
		escribiendo = false
	end)
end

local function avanzar()
	if not lineasActuales then
		return
	end
	if escribiendo then
		escribiendo = false
		textoDialogo.MaxVisibleGraphemes = -1
		return
	end
	lineaActual += 1
	mostrarLinea()
end
botonDialogo.MouseButton1Click:Connect(avanzar)
UserInputService.InputBegan:Connect(function(entrada, procesado)
	if not procesado and caja.Visible and entrada.KeyCode == Enum.KeyCode.Return then
		avanzar()
	end
end)

local function decir(nombre, lineas)
	table.insert(cola, { nombre = nombre, lineas = lineas })
	if not lineasActuales then
		local siguiente = table.remove(cola, 1)
		nombreHablante.Text = siguiente.nombre
		lineasActuales, lineaActual = siguiente.lineas, 1
		caja.Visible = true
		mostrarLinea()
	end
end

-- ===== Mensajes del servidor =====
Remoto.OnClientEvent:Connect(function(tipo, a, b)
	if tipo == "Mision" then
		local anterior = estadoMision
		mostrarMision(a)
		if a and not a.fin and (not anterior or anterior.numero ~= a.numero) and anterior then
			task.spawn(aviso, "NUEVA MISIÓN", a.titulo, a.objetivo)
		end
	elseif tipo == "Completada" then
		task.spawn(
			aviso,
			"MISIÓN COMPLETADA",
			a.titulo,
			textoRecompensa(a.recompensa or {}),
			Color3.fromRGB(150, 230, 150)
		)
		sonido("rbxasset://sounds/electronicpingshort.wav", 0.8)
	elseif tipo == "Dialogo" then
		decir(a, b)
	elseif tipo == "Texto" then
		Pergamino.Abrir(a, b)
	end
end)

-- ===== Estado del vampiro (sol / noche) =====
local textoVampiro = Estilo.Texto(pantalla, {
	Position = UDim2.new(0, 18, 1, -124),
	Size = UDim2.fromOffset(330, 18),
	Font = Estilo.FUERTE,
	TextSize = 13,
	TextStrokeTransparency = 0.4,
	Text = "",
})
local function refrescarVampiro()
	local estado = jugador:GetAttribute("EstadoVampiro")
	if estado == "Sol" then
		textoVampiro.Text = "☀  EL SOL TE QUEMA  ·  busca sombra"
		textoVampiro.TextColor3 = Color3.fromRGB(255, 140, 90)
	elseif estado == "Noche" then
		textoVampiro.Text = "☾  NOCHE  ·  más daño y regeneración"
		textoVampiro.TextColor3 = Color3.fromRGB(200, 150, 255)
	elseif estado == "Sombra" then
		textoVampiro.Text = "◐  A la sombra"
		textoVampiro.TextColor3 = C.textoSuave
	else
		textoVampiro.Text = ""
	end
end
jugador:GetAttributeChangedSignal("EstadoVampiro"):Connect(refrescarVampiro)
refrescarVampiro()

-- ===== El Eclipse en el cielo =====
-- Un disco negro con corona morada, muy lejos en la dirección del norte. Siempre está ahí:
-- el sello se rompe y el Eclipse despierta. Cuanto más avanza la historia, más grande.
-- Está a 450 studs: más lejos, la bruma del cielo lo borraría. Como sigue a la cámara,
-- se ve siempre igual de lejos, como el sol o la luna.
local DISTANCIA_ECLIPSE = 450
local cielo = Instance.new("Part")
cielo.Name = "EclipseCielo"
cielo.Anchored = true
cielo.CanCollide = false
cielo.CanQuery = false
cielo.CanTouch = false
cielo.CastShadow = false
cielo.Transparency = 1
cielo.Size = Vector3.one * 0.2
cielo.Parent = Workspace
local disco = Instance.new("BillboardGui")
disco.Name = "Eclipse"
disco.Adornee = cielo
disco.LightInfluence = 0
disco.Size = UDim2.fromScale(48, 48) -- en studs
disco.Parent = cielo
local partesEclipse = {}
local function circulo(tamano, color, transparencia, borde, grosor)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(tamano, tamano)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparencia
	f.BorderSizePixel = 0
	f.Parent = disco
	local e = Instance.new("UICorner")
	e.CornerRadius = UDim.new(1, 0)
	e.Parent = f
	if borde then
		local s = Instance.new("UIStroke")
		s.Color = borde
		s.Thickness = grosor or 4
		s.Transparency = 0.2
		s.Parent = f
	end
	table.insert(partesEclipse, { marco = f, base = transparencia })
	return f
end
circulo(1, MORADO, 0.8)
circulo(0.78, Color3.fromRGB(255, 150, 90), 0.72)
circulo(0.6, Color3.fromRGB(230, 200, 255), 0.35, Color3.fromRGB(255, 230, 255), 5)
local nucleo = circulo(0.54, Color3.fromRGB(4, 0, 8), 0)
local corona = Instance.new("Frame")
corona.AnchorPoint = Vector2.new(0.5, 0.5)
corona.Position = UDim2.fromScale(0.5, 0.5)
corona.Size = UDim2.fromScale(1, 1)
corona.BackgroundTransparency = 1
corona.Parent = disco
for i = 1, 10 do
	local rayo = Instance.new("Frame")
	rayo.AnchorPoint = Vector2.new(0.5, 0.5)
	rayo.Position = UDim2.fromScale(0.5, 0.5)
	rayo.Size = UDim2.fromScale(0.012, 0.95 + (i % 3) * 0.08)
	rayo.Rotation = i * 18
	rayo.BackgroundColor3 = Color3.fromRGB(220, 160, 255)
	rayo.BackgroundTransparency = 0.75
	rayo.BorderSizePixel = 0
	rayo.ZIndex = 0
	rayo.Parent = corona
end
nucleo.ZIndex = 2

RunService.RenderStepped:Connect(function(dt)
	local camara = Workspace.CurrentCamera
	if not camara then
		return
	end
	cielo.Position = camara.CFrame.Position + HistoriaConfig.ECLIPSE_DIRECCION * DISTANCIA_ECLIPSE
	corona.Rotation += dt * 2
	-- de día se ve más débil, de noche más intenso; late despacio
	local hora = game:GetService("Lighting").ClockTime
	local dia = hora > 7 and hora < 17.5
	local pulso = 0.5 + 0.5 * math.sin(os.clock() * 0.8)
	for _, p in partesEclipse do
		if p.marco ~= nucleo then
			p.marco.BackgroundTransparency = math.clamp(p.base + (if dia then 0.06 else -0.04) - pulso * 0.04, 0, 1)
		end
	end
	nucleo.BackgroundTransparency = if dia then 0.25 else 0.05
	local avance = (estadoMision and estadoMision.numero) or 1
	local tamano = 78 + math.min(avance, 8) * 4
	disco.Size = UDim2.fromScale(tamano, tamano)

	-- marca del objetivo y distancia
	local personaje = jugador.Character
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if estadoMision and estadoMision.destino and raiz and not estadoMision.fin then
		local distancia = (estadoMision.destino - raiz.Position).Magnitude
		marca.Enabled = distancia > 14 and rastreando and not jugador:GetAttribute("EnCinematica")
		distanciaMarca.Text = string.format("%d m", math.floor(distancia / 3.57))
		textoDistancia.Text = if rastreando
			then string.format("a %d m", math.floor(distancia / 3.57))
			else Controles.Nombre("Rastrear") .. ": rastrear"
		romboMarca.Rotation = 45 + math.sin(os.clock() * 3) * 10
	else
		marca.Enabled = false
		textoDistancia.Text = ""
	end
end)

-- pide el estado de la historia al empezar
task.spawn(function()
	task.wait(2)
	Remoto:FireServer("Pedir")
end)

-- Pantalla de INICIO: Jugar, Personalizar y Códigos. Solo CLIENTE (dibuja y pide).
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/InicioCliente
-- Todo lo importante (aspecto, nombre, giros, códigos) lo comprueba el servidor:
-- ServerScriptService/Progresion/InicioServicio, por el remoto Remotes/MenuInicio.
--
-- Personalizar tiene 5 pestañas: Cuerpo (nombre, género, piel, altura), Cara (y barba),
-- Pelo, Ropa (por estamento: plebeyo, noble, realeza, caballero, hechicero) y
-- Raza y magia (los giros). Lo que cambias se ve en tu personaje al momento.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local Estilo = require(ReplicatedStorage:WaitForChild("Interfaz"):WaitForChild("Estilo"))
local AparienciaConfig = require(Config:WaitForChild("AparienciaConfig"))
local RazasConfig = require(Config:WaitForChild("RazasConfig"))
local InicioConfig = require(Config:WaitForChild("InicioConfig"))
local Remoto = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MenuInicio")

local jugador = Players.LocalPlayer
local C = Estilo.COLORES
local KI = Color3.fromRGB(120, 210, 255)

-- Espera a que el servidor diga si estamos en el menú
local espera = os.clock() + 10
while jugador:GetAttribute("EnMenu") == nil and os.clock() < espera do
	task.wait(0.1)
end
if jugador:GetAttribute("EnMenu") ~= true then
	return -- ya está jugando (por ejemplo, en Studio con SaltarMenu)
end

-- En el menú no se ven el chat ni la lista de jugadores (tapan los botones)
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local function interfazRoblox(visible)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, visible)
	end)
	pcall(function()
		local ventana = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
		if ventana then
			ventana.Enabled = visible
		end
		local barra = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
		if barra then
			barra.Enabled = visible
		end
	end)
end
interfazRoblox(false)

local function pedir(...)
	local ok, respuesta = pcall(Remoto.InvokeServer, Remoto, ...)
	if ok and type(respuesta) == "table" then
		return respuesta
	end
	return { ok = false, mensaje = "Sin conexión con el servidor." }
end

local function tween(objeto, tiempo, metas, estilo, direccion)
	local t = TweenService:Create(
		objeto,
		TweenInfo.new(tiempo, estilo or Enum.EasingStyle.Quad, direccion or Enum.EasingDirection.Out),
		metas
	)
	t:Play()
	return t
end

local function sonido(id, volumen)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volumen or 0.4
	s.Parent = Workspace
	s:Play()
	task.delay(3, function()
		s:Destroy()
	end)
end
local SONIDO_CLIC = "rbxasset://sounds/clickfast.wav"
local SONIDO_ELEGIR = "rbxasset://sounds/electronicpingshort.wav"

-- ===== Pantalla =====
local pantalla = Instance.new("ScreenGui")
pantalla.Name = "Inicio"
pantalla.IgnoreGuiInset = true
pantalla.ResetOnSpawn = false
pantalla.DisplayOrder = 20
pantalla.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pantalla.Parent = jugador:WaitForChild("PlayerGui")

local escala = Instance.new("UIScale")
escala.Parent = pantalla
local function ajustarEscala()
	local camara = Workspace.CurrentCamera
	local alto = camara and camara.ViewportSize.Y or 900
	escala.Scale = math.clamp(alto / 900, 0.62, 1.25)
end
ajustarEscala()
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajustarEscala)

-- Fundido a negro (para las transiciones)
local negro = Estilo.Marco(
	pantalla,
	{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, ZIndex = 50 }
)

-- Velo oscuro a la izquierda (para que se lean los textos sobre la ciudad)
local velo = Estilo.Marco(
	pantalla,
	{ Size = UDim2.fromScale(0.62, 1), BackgroundColor3 = Color3.fromRGB(6, 6, 12), BackgroundTransparency = 0 }
)
local degradadoVelo = Instance.new("UIGradient")
degradadoVelo.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.1),
	NumberSequenceKeypoint.new(0.55, 0.45),
	NumberSequenceKeypoint.new(1, 1),
})
degradadoVelo.Parent = velo
local vinetaAbajo = Estilo.Marco(pantalla, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 160),
	BackgroundColor3 = Color3.new(0, 0, 0),
})
local degradadoAbajo = Instance.new("UIGradient")
degradadoAbajo.Rotation = 90
degradadoAbajo.Transparency = NumberSequence.new(1, 0.25)
degradadoAbajo.Parent = vinetaAbajo

-- ===== Chispas de luz que suben (ambiente) =====
local chispas = {}
local capaChispas = Estilo.Marco(pantalla, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
for _ = 1, 26 do
	local tamano = math.random(2, 5)
	local f = Estilo.Marco(capaChispas, {
		Size = UDim2.fromOffset(tamano, tamano),
		Position = UDim2.fromScale(math.random(), math.random()),
		BackgroundColor3 = if math.random() < 0.6 then KI else C.oro,
		BackgroundTransparency = 0.3,
	})
	Estilo.Esquinas(f, tamano)
	table.insert(chispas, { marco = f, velocidad = 0.015 + math.random() * 0.03, fase = math.random() * 10 })
end

-- ===== PANTALLA DE TÍTULO =====
local titulo = Estilo.Marco(pantalla, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })

local bloque = Estilo.Marco(
	titulo,
	{ Position = UDim2.new(0, 90, 0.2, 0), Size = UDim2.fromOffset(640, 230), BackgroundTransparency = 1 }
)
local textoTitulo = Estilo.Texto(bloque, {
	Size = UDim2.new(1, 0, 0, 96),
	Font = Estilo.TITULO,
	TextSize = 86,
	Text = InicioConfig.NOMBRE_JUEGO,
	TextColor3 = Color3.new(1, 1, 1),
})
local gradTitulo = Instance.new("UIGradient")
gradTitulo.Rotation = 90
gradTitulo.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 244, 214)),
	ColorSequenceKeypoint.new(0.6, C.oro),
	ColorSequenceKeypoint.new(1, C.oroOscuro),
})
gradTitulo.Parent = textoTitulo
local bordeTitulo = Instance.new("UIStroke")
bordeTitulo.Color = Color3.fromRGB(30, 18, 6)
bordeTitulo.Thickness = 2
bordeTitulo.Transparency = 0.3
bordeTitulo.Parent = textoTitulo

-- adorno: línea - rombo - línea
local adorno = Estilo.Marco(
	bloque,
	{ Position = UDim2.fromOffset(4, 104), Size = UDim2.fromOffset(420, 12), BackgroundTransparency = 1 }
)
Estilo.Marco(adorno, { Position = UDim2.fromOffset(0, 5), Size = UDim2.fromOffset(190, 1), BackgroundColor3 = C.oro })
local rombo = Estilo.Marco(
	adorno,
	{ Position = UDim2.fromOffset(198, 1), Size = UDim2.fromOffset(10, 10), Rotation = 45, BackgroundColor3 = KI }
)
Estilo.Marco(adorno, { Position = UDim2.fromOffset(216, 5), Size = UDim2.fromOffset(190, 1), BackgroundColor3 = C.oro })
Estilo.Texto(bloque, {
	Position = UDim2.fromOffset(4, 126),
	Size = UDim2.new(1, 0, 0, 24),
	TextSize = 18,
	TextColor3 = C.texto,
	TextTransparency = 0.15,
	Text = InicioConfig.SUBTITULO,
})

local botones = Estilo.Marco(
	titulo,
	{ Position = UDim2.new(0, 90, 0.2, 260), Size = UDim2.fromOffset(380, 260), BackgroundTransparency = 1 }
)
Estilo.Lista(botones, 14)

local function botonMenu(texto, principal, orden)
	local alto = if principal then 66 else 56
	local b = Instance.new("TextButton")
	b.LayoutOrder = orden
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(if principal then 360 else 330, alto)
	b.BackgroundColor3 = C.fondo
	b.BackgroundTransparency = 0.35
	b.BorderSizePixel = 0
	b.Text = ""
	b.Parent = botones
	Estilo.Esquinas(b, 4)
	local borde = Estilo.Borde(b, if principal then C.oro else C.borde, 1, 0.2)
	local relleno = Estilo.Marco(
		b,
		{ Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = if principal then C.oro else KI, ZIndex = 1 }
	)
	Estilo.Esquinas(relleno, 4)
	local gradRelleno = Instance.new("UIGradient")
	gradRelleno.Transparency = NumberSequence.new(0.1, 0.85)
	gradRelleno.Parent = relleno
	local etiqueta = Estilo.Texto(b, {
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.new(1, -40, 1, 0),
		Font = Estilo.FUERTE,
		TextSize = if principal then 24 else 19,
		TextColor3 = if principal then C.oro else C.texto,
		Text = texto,
		ZIndex = 2,
	})
	b.MouseEnter:Connect(function()
		sonido(SONIDO_CLIC, 0.15)
		tween(relleno, 0.22, { Size = UDim2.new(1, 0, 1, 0) })
		tween(etiqueta, 0.18, { Position = UDim2.fromOffset(38, 0), TextColor3 = Color3.new(1, 1, 1) })
		tween(borde, 0.18, { Transparency = 0 })
	end)
	b.MouseLeave:Connect(function()
		tween(relleno, 0.22, { Size = UDim2.new(0, 4, 1, 0) })
		tween(etiqueta, 0.18, { Position = UDim2.fromOffset(28, 0), TextColor3 = if principal then C.oro else C.texto })
		tween(borde, 0.18, { Transparency = 0.2 })
	end)
	return b
end

local botonJugar = botonMenu("JUGAR", true, 1)
local botonPersonalizar = botonMenu("PERSONALIZAR", false, 2)
local botonCodigos = botonMenu("CÓDIGOS", false, 3)

local textoAviso = Estilo.Texto(titulo, {
	Position = UDim2.new(0, 92, 0.2, 470),
	Size = UDim2.fromOffset(500, 22),
	TextSize = 14,
	TextColor3 = C.rojo,
	Text = "",
})

-- abajo: tu personaje y tus giros
local resumen = Estilo.Texto(titulo, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -36, 1, -30),
	Size = UDim2.fromOffset(520, 46),
	TextXAlignment = Enum.TextXAlignment.Right,
	TextYAlignment = Enum.TextYAlignment.Bottom,
	TextSize = 15,
	RichText = true,
	TextColor3 = C.texto,
	Text = "Cargando tus datos...",
})
Estilo.Texto(titulo, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 36, 1, -28),
	Size = UDim2.fromOffset(300, 18),
	TextSize = 12,
	TextColor3 = C.textoSuave,
	Text = InicioConfig.VERSION,
})

-- ===== Estado (lo que dice el servidor) =====
local estado = { cargando = true }

local function colorRareza(rareza)
	return Estilo.RAREZAS[rareza] or C.texto
end

local function nombreRareza(rareza)
	return RazasConfig.NOMBRES_RAREZA[rareza] or rareza
end

local function hex(color)
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255),
		math.floor(color.G * 255),
		math.floor(color.B * 255)
	)
end

local function refrescarResumen()
	if estado.cargando then
		resumen.Text = "Cargando tus datos..."
		return
	end
	local raza = RazasConfig.RAZA_POR_ID[estado.Raza]
	local afinidad = RazasConfig.AFINIDAD_POR_ID[estado.AfinidadMagica]
	local nombre = if estado.Nombre ~= "" then estado.Nombre else jugador.DisplayName
	resumen.Text = string.format(
		'<font face="Garamond" size="22">%s</font>\n%s  ·  %s     <font color="#A0968A">Giros: raza %d · afinidad %d</font>',
		nombre,
		if raza
			then string.format('<font color="%s">%s</font>', hex(colorRareza(raza.rareza)), raza.nombre)
			else "Sin raza",
		if afinidad
			then string.format('<font color="%s">%s</font>', hex(afinidad.color), afinidad.nombre)
			else "Sin afinidad",
		estado.Giros and estado.Giros.Raza or 0,
		estado.Giros and estado.Giros.Afinidad or 0
	)
end

local function cargarEstado()
	for _ = 1, 60 do
		local r = pedir("Estado")
		if r and not r.cargando and r.Apariencia then
			estado = r
			refrescarResumen()
			return
		end
		task.wait(0.5)
	end
end

-- ===== CÁMARA =====
local modoCamara = "ciudad" -- "ciudad" | "personaje" | nil
local anguloCiudad = 0
local anguloPersonaje = 0
local centroCiudad = nil

local function buscarCiudad()
	for _, objeto in Workspace:GetDescendants() do
		if objeto:IsA("Model") and objeto:GetAttribute("Nombre") == InicioConfig.CIUDAD_FONDO then
			local centro = objeto:GetAttribute("Centro")
			if typeof(centro) == "Vector3" then
				return centro
			end
		end
	end
	return nil
end
task.spawn(function()
	for _ = 1, 20 do
		centroCiudad = buscarCiudad()
		if centroCiudad then
			return
		end
		task.wait(1)
	end
end)

RunService:BindToRenderStep("CamaraInicio", Enum.RenderPriority.Camera.Value + 3, function(dt)
	-- chispas
	for _, c in chispas do
		local p = c.marco.Position
		local y = p.Y.Scale - c.velocidad * dt
		local x = p.X.Scale + math.sin(os.clock() * 0.6 + c.fase) * 0.0004
		if y < -0.02 then
			y = 1.02
			x = math.random()
		end
		c.marco.Position = UDim2.fromScale(x, y)
		c.marco.BackgroundTransparency = 0.25 + 0.5 * (0.5 + 0.5 * math.sin(os.clock() * 2 + c.fase))
	end
	rombo.Rotation = 45 + math.sin(os.clock() * 1.5) * 8

	if not modoCamara then
		return
	end
	local camara = Workspace.CurrentCamera
	camara.CameraType = Enum.CameraType.Scriptable
	local personaje = jugador.Character
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if modoCamara == "ciudad" then
		anguloCiudad += dt * 0.035
		local centro = centroCiudad or (raiz and raiz.Position) or Vector3.zero
		local posicion = centro + Vector3.new(math.cos(anguloCiudad) * 250, 115, math.sin(anguloCiudad) * 250)
		local deseada = CFrame.lookAt(posicion, centro + Vector3.new(0, 20, 0))
		camara.CFrame = camara.CFrame:Lerp(deseada, math.min(1, dt * 1.5))
		camara.FieldOfView = 60
	elseif modoCamara == "personaje" and raiz then
		local frente = (CFrame.Angles(0, anguloPersonaje, 0) * raiz.CFrame.LookVector)
		frente = Vector3.new(frente.X, 0, frente.Z).Unit
		local posicion = raiz.Position + frente * 9.5 + Vector3.new(0, 1.1, 0)
		local hacia = (raiz.Position - posicion).Unit
		local derecha = hacia:Cross(Vector3.yAxis).Unit
		-- el personaje queda a la derecha de la pantalla (el panel está a la izquierda)
		local mirar = raiz.Position + Vector3.new(0, 0.4, 0) - derecha * 2.6
		local deseada = CFrame.lookAt(posicion, mirar)
		camara.CFrame = camara.CFrame:Lerp(deseada, math.min(1, dt * 5))
		camara.FieldOfView = 50
	end
end)

-- ===== PERSONALIZAR =====
local panel = Estilo.Marco(pantalla, {
	Position = UDim2.fromOffset(28, 70), -- por debajo de los botones de Roblox (arriba a la izquierda)
	Size = UDim2.new(0, 480, 1, -96),
	BackgroundColor3 = C.fondo,
	BackgroundTransparency = 0.08,
	Visible = false,
})
Estilo.Esquinas(panel, 8)
Estilo.Borde(panel, C.borde, 1)
Estilo.Texto(panel, {
	Position = UDim2.fromOffset(24, 16),
	Size = UDim2.fromOffset(300, 40),
	Font = Estilo.TITULO,
	TextSize = 36,
	TextColor3 = C.oro,
	Text = "Personalizar",
})
Estilo.Texto(panel, {
	Position = UDim2.fromOffset(26, 54),
	Size = UDim2.fromOffset(420, 18),
	TextSize = 13,
	TextColor3 = C.textoSuave,
	Text = "Los cambios se ven en tu personaje al momento.",
})

local pestanas = Estilo.Marco(
	panel,
	{ Position = UDim2.fromOffset(16, 84), Size = UDim2.new(1, -32, 0, 34), BackgroundTransparency = 1 }
)
local disposicionPestanas = Instance.new("UIListLayout")
disposicionPestanas.FillDirection = Enum.FillDirection.Horizontal
disposicionPestanas.Padding = UDim.new(0, 6)
disposicionPestanas.SortOrder = Enum.SortOrder.LayoutOrder
disposicionPestanas.Parent = pestanas

local contenido = Instance.new("ScrollingFrame")
contenido.Position = UDim2.fromOffset(16, 130)
contenido.Size = UDim2.new(1, -32, 1, -200)
contenido.BackgroundTransparency = 1
contenido.BorderSizePixel = 0
contenido.ScrollBarThickness = 5
contenido.ScrollBarImageColor3 = C.oroOscuro
contenido.CanvasSize = UDim2.new()
contenido.AutomaticCanvasSize = Enum.AutomaticSize.Y
contenido.Parent = panel
Estilo.Lista(contenido, 10)
local margen = Instance.new("UIPadding")
margen.PaddingRight = UDim.new(0, 10)
margen.PaddingBottom = UDim.new(0, 12)
margen.Parent = contenido

local pie = Estilo.Marco(panel, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -14),
	Size = UDim2.new(1, -32, 0, 46),
	BackgroundTransparency = 1,
})
local botonVolver = Estilo.Boton(pie, { Size = UDim2.new(0.5, -6, 1, 0), Text = "VOLVER" })
local botonJugar2 = Estilo.Boton(pie, {
	Position = UDim2.new(0.5, 6, 0, 0),
	Size = UDim2.new(0.5, -6, 1, 0),
	Text = "JUGAR",
	BackgroundColor3 = C.oroOscuro,
})

-- girar al personaje para verlo
local giro = Estilo.Marco(pantalla, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.68, 0, 1, -34),
	Size = UDim2.fromOffset(150, 44),
	BackgroundTransparency = 1,
	Visible = false,
})
local girarIzq =
	Estilo.Boton(giro, { Size = UDim2.fromOffset(60, 44), Text = "◀", TextSize = 20, BackgroundTransparency = 0.25 })
local girarDer = Estilo.Boton(giro, {
	Position = UDim2.fromOffset(90, 0),
	Size = UDim2.fromOffset(60, 44),
	Text = "▶",
	TextSize = 20,
	BackgroundTransparency = 0.25,
})
girarIzq.MouseButton1Click:Connect(function()
	anguloPersonaje -= math.rad(45)
end)
girarDer.MouseButton1Click:Connect(function()
	anguloPersonaje += math.rad(45)
end)

local function limpiar()
	for _, hijo in contenido:GetChildren() do
		if not hijo:IsA("UIListLayout") and not hijo:IsA("UIPadding") then
			hijo:Destroy()
		end
	end
end

local orden = 0
local function siguiente()
	orden += 1
	return orden
end

local function seccion(texto)
	Estilo.Texto(contenido, {
		LayoutOrder = siguiente(),
		Size = UDim2.new(1, 0, 0, 26),
		Font = Estilo.TITULO,
		TextSize = 22,
		TextColor3 = C.oro,
		Text = texto,
	})
end

local function nota(texto, color)
	return Estilo.Texto(contenido, {
		LayoutOrder = siguiente(),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = 13,
		TextColor3 = color or C.textoSuave,
		Text = texto,
	})
end

local function rejilla(celda)
	local r = Estilo.Marco(contenido, {
		LayoutOrder = siguiente(),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	})
	local g = Instance.new("UIGridLayout")
	g.CellSize = celda or UDim2.fromOffset(98, 116)
	g.CellPadding = UDim2.fromOffset(8, 8)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = r
	return r
end

local pestanaActual = "Cuerpo"
local mostrarPestana -- se define abajo

-- Cambia una parte del aspecto (se ve al momento: el servidor viste al personaje)
local function aplicar(campo, valor)
	if estado.cargando then
		return
	end
	estado.Apariencia[campo] = valor
	sonido(SONIDO_ELEGIR, 0.25)
	mostrarPestana(pestanaActual, true)
	task.spawn(function()
		local r = pedir("Apariencia", campo, valor)
		if r.ok and r.Apariencia then
			local cambioGenero = r.Apariencia.Genero ~= estado.Apariencia.Genero
			estado.Apariencia = r.Apariencia
			if cambioGenero then
				mostrarPestana(pestanaActual, true)
			end
		end
	end)
end

-- Casilla con miniatura del catálogo
local function opcion(padre, imagen, texto, elegida, alPulsar, colorFondo)
	local b = Instance.new("ImageButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = colorFondo or C.panelClaro
	b.BorderSizePixel = 0
	b.Image = ""
	b.Parent = padre
	Estilo.Esquinas(b, 6)
	Estilo.Borde(b, if elegida then C.oro else C.borde, if elegida then 2 else 1, if elegida then 0 else 0.4)
	if imagen then
		local foto = Instance.new("ImageLabel")
		foto.BackgroundTransparency = 1
		foto.Position = UDim2.fromOffset(6, 6)
		foto.Size = UDim2.new(1, -12, 1, -34)
		foto.ScaleType = Enum.ScaleType.Fit
		foto.Image = imagen
		foto.Parent = b
	end
	Estilo.Texto(b, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 4, 1, -4),
		Size = UDim2.new(1, -8, 0, 24),
		TextSize = 11,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = if elegida then C.oro else C.texto,
		Text = texto or "",
	})
	if elegida then
		Estilo.Marco(b, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -5, 0, 5),
			Size = UDim2.fromOffset(10, 10),
			Rotation = 45,
			BackgroundColor3 = C.oro,
		})
	end
	b.MouseButton1Click:Connect(alPulsar)
	return b
end

local function fila(alto)
	local f = Estilo.Marco(
		contenido,
		{ LayoutOrder = siguiente(), Size = UDim2.new(1, 0, 0, alto or 40), BackgroundTransparency = 1 }
	)
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 8)
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Parent = f
	return f
end

local function boton(padre, texto, elegido, ancho, alPulsar)
	local b = Estilo.Boton(padre, {
		Size = UDim2.fromOffset(ancho or 120, 36),
		Text = texto,
		TextSize = 14,
		BackgroundColor3 = if elegido then C.oroOscuro else C.panelClaro,
		TextColor3 = if elegido then Color3.new(1, 1, 1) else C.texto,
	})
	b.MouseButton1Click:Connect(alPulsar)
	return b
end

-- ===== Pestañas =====
local CONSTRUIR = {}

function CONSTRUIR.Cuerpo()
	local a = estado.Apariencia
	seccion("Nombre")
	local filaNombre = fila(40)
	local cajaNombre = Instance.new("TextBox")
	cajaNombre.Size = UDim2.fromOffset(250, 38)
	cajaNombre.BackgroundColor3 = C.panelClaro
	cajaNombre.BorderSizePixel = 0
	cajaNombre.Font = Estilo.NORMAL
	cajaNombre.TextSize = 16
	cajaNombre.TextColor3 = C.texto
	cajaNombre.PlaceholderText = "Escribe tu nombre"
	cajaNombre.PlaceholderColor3 = C.textoSuave
	cajaNombre.ClearTextOnFocus = false
	cajaNombre.Text = estado.Nombre or ""
	cajaNombre.Parent = filaNombre
	Estilo.Esquinas(cajaNombre, 5)
	Estilo.Borde(cajaNombre, C.borde, 1)
	local mensaje = nota("Entre 3 y 20 letras. Roblox lo revisa para que sea apropiado.")
	boton(filaNombre, "Guardar", false, 110, function()
		mensaje.Text = "Comprobando..."
		mensaje.TextColor3 = C.textoSuave
		local r = pedir("Nombre", cajaNombre.Text)
		if r.ok then
			estado.Nombre = r.Nombre
			mensaje.Text = "Nombre guardado: " .. r.Nombre
			mensaje.TextColor3 = C.verde
			refrescarResumen()
		else
			mensaje.Text = r.mensaje or "No se pudo guardar."
			mensaje.TextColor3 = C.rojo
		end
	end)

	seccion("Cuerpo")
	local filaGenero = fila(40)
	for _, genero in AparienciaConfig.GENEROS do
		boton(filaGenero, genero, a.Genero == genero, 130, function()
			aplicar("Genero", genero)
		end)
	end

	seccion("Tono de piel")
	local pieles = rejilla(UDim2.fromOffset(44, 44))
	for i, color in AparienciaConfig.PIELES do
		local b = Instance.new("TextButton")
		b.Text = ""
		b.LayoutOrder = i
		b.BackgroundColor3 = color
		b.BorderSizePixel = 0
		b.Parent = pieles
		Estilo.Esquinas(b, 22)
		Estilo.Borde(
			b,
			if a.Piel == i then C.oro else Color3.new(0, 0, 0),
			if a.Piel == i then 3 else 1,
			if a.Piel == i then 0 else 0.5
		)
		b.MouseButton1Click:Connect(function()
			aplicar("Piel", i)
		end)
	end

	seccion("Altura")
	local filaAltura = fila(40)
	local altura = a.Altura or 1
	boton(filaAltura, "−", false, 50, function()
		aplicar("Altura", math.max(0.92, math.floor((altura - 0.04) * 100 + 0.5) / 100))
	end)
	Estilo.Texto(filaAltura, {
		Size = UDim2.fromOffset(120, 36),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Estilo.FUERTE,
		Text = string.format("%d %%", math.floor(altura * 100 + 0.5)),
	})
	boton(filaAltura, "+", false, 50, function()
		aplicar("Altura", math.min(1.08, math.floor((altura + 0.04) * 100 + 0.5) / 100))
	end)
end

function CONSTRUIR.Cara()
	local a = estado.Apariencia
	seccion("Cara")
	nota("Caras realistas que gesticulan.")
	local caras = rejilla()
	for i, cara in AparienciaConfig.CARAS do
		local b = opcion(caras, AparienciaConfig.Miniatura(cara.cabeza), cara.nombre, a.Cara == i, function()
			aplicar("Cara", i)
		end)
		b.LayoutOrder = i
	end
	if a.Genero == "Hombre" then
		seccion("Barba")
		local barbas = rejilla()
		opcion(barbas, nil, "Sin barba", a.Barba == 0, function()
			aplicar("Barba", 0)
		end).LayoutOrder = 0
		for i, id in AparienciaConfig.BARBAS do
			local b = opcion(barbas, AparienciaConfig.Miniatura(id), "Barba " .. i, a.Barba == i, function()
				aplicar("Barba", i)
			end)
			b.LayoutOrder = i
		end
	end
end

function CONSTRUIR.Pelo()
	local a = estado.Apariencia
	seccion("Pelo")
	nota("Realistas, de punta, despeinados, largos, trenzas y coletas.")
	local pelos = rejilla()
	opcion(pelos, nil, "Sin pelo", a.Pelo == 0, function()
		aplicar("Pelo", 0)
	end).LayoutOrder = 0
	for i, pelo in AparienciaConfig.PELOS do
		local b = opcion(pelos, AparienciaConfig.Miniatura(pelo.id), "Pelo " .. i, a.Pelo == i, function()
			aplicar("Pelo", i)
		end)
		b.LayoutOrder = i
	end
end

local estamentoActual = "Plebeyo"
function CONSTRUIR.Ropa()
	local a = estado.Apariencia
	seccion("Ropa de época")
	local filaEstamentos = rejilla(UDim2.fromOffset(84, 32))
	for i, estamento in AparienciaConfig.ESTAMENTOS do
		local b = Estilo.Boton(filaEstamentos, {
			LayoutOrder = i,
			Text = estamento,
			TextSize = 12,
			BackgroundColor3 = if estamento == estamentoActual then C.oroOscuro else C.panelClaro,
		})
		b.MouseButton1Click:Connect(function()
			estamentoActual = estamento
			sonido(SONIDO_CLIC, 0.2)
			mostrarPestana("Ropa", true)
		end)
	end
	nota(AparienciaConfig.TEXTO_ESTAMENTO[estamentoActual] or "")
	local ropas = rejilla(UDim2.fromOffset(98, 126))
	local n = 0
	for _, conjunto in AparienciaConfig.ROPA do
		if conjunto.estamento == estamentoActual then
			n += 1
			local etiqueta = conjunto.nombre
				.. (if conjunto.genero == "Mujer" then " ♀" elseif conjunto.genero == "Hombre" then " ♂" else "")
			local b = opcion(
				ropas,
				conjunto.icono and AparienciaConfig.Miniatura(conjunto.icono),
				etiqueta,
				a.Ropa == conjunto.id,
				function()
					aplicar("Ropa", conjunto.id)
				end
			)
			b.LayoutOrder = n
		end
	end
	nota("♂ y ♀: ese conjunto cambia el cuerpo a hombre o a mujer.")
end

-- ===== Raza y magia (giros) =====
local girando = false

local function textoBonos(bonos)
	local partes = {}
	for _, nombre in { "VIT", "STR", "DEX", "INT", "LUK", "SPD" } do
		if bonos[nombre] then
			table.insert(partes, "+" .. bonos[nombre] .. " " .. nombre)
		end
	end
	return table.concat(partes, "  ·  ")
end

-- Ruleta: tira de nombres que corre y frena en lo que ha salido
local function ruleta(tarjeta, lista, resultado, alTerminar)
	local ANCHO = 120
	local caja = Estilo.Marco(tarjeta, {
		Name = "Ruleta",
		Position = UDim2.new(0, 12, 0, 44),
		Size = UDim2.new(1, -24, 0, 64),
		BackgroundColor3 = Color3.fromRGB(8, 8, 12),
		ClipsDescendants = true,
		ZIndex = 5,
	})
	Estilo.Esquinas(caja, 6)
	Estilo.Borde(caja, C.oro, 1)
	local tira = Estilo.Marco(caja, { Size = UDim2.fromOffset(ANCHO * 40, 64), BackgroundTransparency = 1, ZIndex = 5 })
	local aleatorio = Random.new()
	local total = 0
	for _, e in lista do
		total += e.probabilidad
	end
	local function alAzar()
		local x = aleatorio:NextNumber() * total
		for _, e in lista do
			x -= e.probabilidad
			if x <= 0 then
				return e
			end
		end
		return lista[1]
	end
	local GANADOR = 34
	for i = 1, 40 do
		local e = if i == GANADOR then resultado else alAzar()
		local color = e.color or colorRareza(e.rareza)
		local celda = Estilo.Marco(tira, {
			Position = UDim2.fromOffset((i - 1) * ANCHO + 3, 6),
			Size = UDim2.fromOffset(ANCHO - 6, 52),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.72,
			ZIndex = 5,
		})
		Estilo.Esquinas(celda, 5)
		Estilo.Borde(celda, color, 1, 0.2)
		Estilo.Texto(celda, {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Estilo.FUERTE,
			TextSize = 14,
			TextWrapped = true,
			Text = e.nombre,
			ZIndex = 6,
		})
	end
	Estilo.Marco(caja, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 2, 1, 0),
		BackgroundColor3 = C.oro,
		ZIndex = 8,
	}) -- aguja
	local anchoCaja = caja.AbsoluteSize.X / math.max(escala.Scale, 0.01)
	local final = anchoCaja / 2 - ((GANADOR - 1) * ANCHO + ANCHO / 2) + aleatorio:NextNumber(-30, 30)
	local duracion = 3.4
	local t = tween(
		tira,
		duracion,
		{ Position = UDim2.fromOffset(final, 0) },
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	)
	-- "tic" cada vez que pasa una casilla por la aguja
	local ultimaCasilla = -1
	local conexion
	conexion = RunService.RenderStepped:Connect(function()
		local casilla = math.floor((anchoCaja / 2 - tira.Position.X.Offset) / ANCHO)
		if casilla ~= ultimaCasilla then
			ultimaCasilla = casilla
			sonido(SONIDO_CLIC, 0.18)
		end
	end)
	t.Completed:Wait()
	conexion:Disconnect()
	-- destello final
	local color = resultado.color or colorRareza(resultado.rareza)
	local flash = Estilo.Marco(
		caja,
		{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BackgroundTransparency = 0.1, ZIndex = 9 }
	)
	tween(flash, 0.6, { BackgroundTransparency = 1 })
	sonido(SONIDO_ELEGIR, 0.6)
	task.wait(0.9)
	caja:Destroy()
	alTerminar()
end

local function tarjetaGiro(tipo, tituloTarjeta, lista, actualId)
	local actual = if tipo == "Raza" then RazasConfig.RAZA_POR_ID[actualId] else RazasConfig.AFINIDAD_POR_ID[actualId]
	local tarjeta = Estilo.Marco(
		contenido,
		{ LayoutOrder = siguiente(), Size = UDim2.new(1, 0, 0, 190), BackgroundColor3 = C.panel }
	)
	Estilo.Esquinas(tarjeta, 8)
	local color = if actual then (actual.color or colorRareza(actual.rareza)) else C.borde
	Estilo.Borde(tarjeta, color, 1, 0.2)
	Estilo.Texto(tarjeta, {
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.fromOffset(300, 22),
		Font = Estilo.FUERTE,
		TextSize = 13,
		TextColor3 = C.textoSuave,
		Text = tituloTarjeta,
	})
	Estilo.Texto(tarjeta, {
		Position = UDim2.fromOffset(14, 34),
		Size = UDim2.new(1, -28, 0, 40),
		Font = Estilo.TITULO,
		TextSize = 34,
		TextColor3 = color,
		Text = if actual then actual.nombre else "—",
	})
	Estilo.Texto(tarjeta, {
		Position = UDim2.fromOffset(14, 76),
		Size = UDim2.new(1, -28, 0, 18),
		Font = Estilo.FUERTE,
		TextSize = 13,
		TextColor3 = colorRareza(actual and actual.rareza),
		Text = if actual then nombreRareza(actual.rareza) .. "  ·  " .. actual.probabilidad .. " %" else "",
	})
	Estilo.Texto(tarjeta, {
		Position = UDim2.fromOffset(14, 98),
		Size = UDim2.new(1, -28, 0, 36),
		TextSize = 13,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = C.texto,
		Text = if actual and actual.bonos
			then actual.texto .. "\n" .. textoBonos(actual.bonos)
			elseif actual then "Tu elemento principal de magia."
			else "",
	})
	local giros = estado.Giros and estado.Giros[tipo] or 0
	local b = Estilo.Boton(tarjeta, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.new(1, -24, 0, 40),
		Text = string.format("GIRAR  (%d %s)", giros, if giros == 1 then "giro" else "giros"),
		TextSize = 16,
		BackgroundColor3 = if giros > 0 then C.oroOscuro else C.panelClaro,
		TextColor3 = if giros > 0 then Color3.new(1, 1, 1) else C.textoSuave,
	})
	b.MouseButton1Click:Connect(function()
		if girando then
			return
		end
		if giros <= 0 then
			b.Text = "Sin giros: canjea códigos"
			return
		end
		girando = true
		b.Text = "Girando..."
		local r = pedir("Girar", tipo)
		if not r.ok then
			girando = false
			b.Text = r.mensaje or "No se pudo girar"
			return
		end
		estado.Giros = r.Giros
		local resultado = if tipo == "Raza" then RazasConfig.RAZA_POR_ID[r.id] else RazasConfig.AFINIDAD_POR_ID[r.id]
		ruleta(tarjeta, lista, resultado, function()
			if tipo == "Raza" then
				estado.Raza = r.id
			else
				estado.AfinidadMagica = r.id
			end
			girando = false
			refrescarResumen()
			mostrarPestana("Raza", true)
		end)
	end)
end

function CONSTRUIR.Raza()
	seccion("Raza y afinidad mágica")
	nota("Cada giro cambia tu raza o tu elemento al azar. Lo raro es muy raro: ¡suerte!")
	tarjetaGiro("Raza", "TU RAZA", RazasConfig.RAZAS, estado.Raza)
	tarjetaGiro("Afinidad", "TU AFINIDAD MÁGICA", RazasConfig.AFINIDADES, estado.AfinidadMagica)
	seccion("Probabilidades")
	for _, raza in RazasConfig.RAZAS do
		nota(
			string.format(
				"%s  —  %s  —  %s %%",
				raza.nombre,
				nombreRareza(raza.rareza),
				tostring(raza.probabilidad)
			),
			colorRareza(raza.rareza)
		)
	end
	for _, afinidad in RazasConfig.AFINIDADES do
		nota(
			string.format(
				"%s  —  %s  —  %s %%",
				afinidad.nombre,
				nombreRareza(afinidad.rareza),
				tostring(afinidad.probabilidad)
			),
			afinidad.color
		)
	end
end

local NOMBRES_PESTANAS =
	{ { "Cuerpo", "Cuerpo" }, { "Cara", "Cara" }, { "Pelo", "Pelo" }, { "Ropa", "Ropa" }, { "Raza", "Raza y magia" } }
local botonesPestana = {}
for i, datos in NOMBRES_PESTANAS do
	local b = Estilo.Boton(pestanas, {
		LayoutOrder = i,
		Size = UDim2.fromOffset(if datos[1] == "Raza" then 110 else 76, 34),
		Text = datos[2],
		TextSize = 13,
	})
	botonesPestana[datos[1]] = b
	b.MouseButton1Click:Connect(function()
		sonido(SONIDO_CLIC, 0.2)
		mostrarPestana(datos[1])
	end)
end

function mostrarPestana(nombre, mantenerScroll)
	if girando and not mantenerScroll then
		return
	end
	pestanaActual = nombre
	for id, b in botonesPestana do
		b.BackgroundColor3 = if id == nombre then C.oroOscuro else C.panelClaro
		b.TextColor3 = if id == nombre then Color3.new(1, 1, 1) else C.texto
	end
	local scroll = contenido.CanvasPosition
	limpiar()
	orden = 0
	if estado.cargando then
		nota("Cargando tus datos...")
		return
	end
	CONSTRUIR[nombre]()
	if mantenerScroll then
		contenido.CanvasPosition = scroll
	else
		contenido.CanvasPosition = Vector2.zero
	end
end

-- ===== CÓDIGOS (ventana) =====
local ventanaCodigos = Estilo.Marco(pantalla, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(460, 250),
	BackgroundColor3 = C.fondo,
	BackgroundTransparency = 0.04,
	Visible = false,
	ZIndex = 30,
})
Estilo.Esquinas(ventanaCodigos, 8)
Estilo.Borde(ventanaCodigos, C.oro, 1)
Estilo.Texto(ventanaCodigos, {
	Position = UDim2.fromOffset(24, 18),
	Size = UDim2.fromOffset(300, 40),
	Font = Estilo.TITULO,
	TextSize = 34,
	TextColor3 = C.oro,
	Text = "Códigos",
	ZIndex = 31,
})
Estilo.Texto(ventanaCodigos, {
	Position = UDim2.fromOffset(26, 58),
	Size = UDim2.new(1, -52, 0, 18),
	TextSize = 13,
	TextColor3 = C.textoSuave,
	Text = "Escribe un código para conseguir giros y premios.",
	ZIndex = 31,
})
local cajaCodigo = Instance.new("TextBox")
cajaCodigo.Position = UDim2.fromOffset(24, 92)
cajaCodigo.Size = UDim2.new(1, -48, 0, 44)
cajaCodigo.BackgroundColor3 = C.panelClaro
cajaCodigo.BorderSizePixel = 0
cajaCodigo.Font = Estilo.FUERTE
cajaCodigo.TextSize = 18
cajaCodigo.TextColor3 = C.texto
cajaCodigo.PlaceholderText = "CÓDIGO"
cajaCodigo.PlaceholderColor3 = C.textoSuave
cajaCodigo.ClearTextOnFocus = false
cajaCodigo.Text = ""
cajaCodigo.ZIndex = 31
cajaCodigo.Parent = ventanaCodigos
Estilo.Esquinas(cajaCodigo, 5)
Estilo.Borde(cajaCodigo, C.borde, 1)
local mensajeCodigo = Estilo.Texto(ventanaCodigos, {
	Position = UDim2.fromOffset(26, 142),
	Size = UDim2.new(1, -52, 0, 36),
	TextWrapped = true,
	TextSize = 14,
	TextColor3 = C.textoSuave,
	Text = "",
	ZIndex = 31,
})
local botonCanjear = Estilo.Boton(ventanaCodigos, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 24, 1, -18),
	Size = UDim2.new(0.5, -30, 0, 42),
	Text = "CANJEAR",
	BackgroundColor3 = C.oroOscuro,
	ZIndex = 31,
})
local botonCerrarCodigos = Estilo.Boton(ventanaCodigos, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -24, 1, -18),
	Size = UDim2.new(0.5, -30, 0, 42),
	Text = "CERRAR",
	ZIndex = 31,
})

botonCanjear.MouseButton1Click:Connect(function()
	if cajaCodigo.Text == "" then
		return
	end
	mensajeCodigo.Text = "Comprobando..."
	mensajeCodigo.TextColor3 = C.textoSuave
	local r = pedir("Codigo", cajaCodigo.Text)
	mensajeCodigo.Text = r.mensaje or ""
	mensajeCodigo.TextColor3 = if r.ok then C.verde else C.rojo
	if r.ok then
		sonido(SONIDO_ELEGIR, 0.6)
		estado.Giros = r.Giros or estado.Giros
		cajaCodigo.Text = ""
		refrescarResumen()
	end
end)

-- ===== Cambiar de vista =====
local function verTitulo()
	panel.Visible = false
	giro.Visible = false
	ventanaCodigos.Visible = false
	titulo.Visible = true
	velo.Visible = true
	modoCamara = "ciudad"
	tween(velo, 0.4, { Size = UDim2.fromScale(0.62, 1) })
end

local function verPersonalizar()
	titulo.Visible = false
	ventanaCodigos.Visible = false
	panel.Visible = true
	giro.Visible = true
	modoCamara = "personaje"
	anguloPersonaje = 0
	tween(velo, 0.4, { Size = UDim2.fromScale(0.45, 1) })
	mostrarPestana(pestanaActual)
end

local function jugar()
	textoAviso.Text = ""
	local r = pedir("Jugar")
	if not r.ok then
		textoAviso.Text = r.mensaje or "No se pudo entrar todavía."
		return
	end
	sonido(SONIDO_ELEGIR, 0.7)
	tween(negro, 0.6, { BackgroundTransparency = 0 }).Completed:Wait()
	modoCamara = nil
	RunService:UnbindFromRenderStep("CamaraInicio")
	local camara = Workspace.CurrentCamera
	camara.CameraType = Enum.CameraType.Custom
	camara.FieldOfView = 70
	local personaje = jugador.Character
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	if humanoide then
		camara.CameraSubject = humanoide
	end
	for _, hijo in pantalla:GetChildren() do
		if hijo ~= negro and hijo:IsA("GuiObject") then
			hijo.Visible = false
		end
	end
	interfazRoblox(true)
	task.wait(0.3)
	tween(negro, 1, { BackgroundTransparency = 1 }).Completed:Wait()
	pantalla:Destroy()
end

botonJugar.MouseButton1Click:Connect(jugar)
botonJugar2.MouseButton1Click:Connect(jugar)
botonPersonalizar.MouseButton1Click:Connect(verPersonalizar)
botonVolver.MouseButton1Click:Connect(function()
	if not girando then
		verTitulo()
	end
end)
botonCodigos.MouseButton1Click:Connect(function()
	ventanaCodigos.Visible = true
	mensajeCodigo.Text = ""
end)
botonCerrarCodigos.MouseButton1Click:Connect(function()
	ventanaCodigos.Visible = false
end)

-- ===== Arranque =====
-- espera a que termine la pantalla de carga
local limite = os.clock() + 25
while not jugador:GetAttribute("CargaLista") and os.clock() < limite do
	task.wait(0.1)
end
verTitulo()
-- entrada del título
bloque.Position = UDim2.new(0, 60, 0.2, 0)
textoTitulo.TextTransparency = 1
tween(negro, 1.2, { BackgroundTransparency = 1 })
tween(bloque, 1.2, { Position = UDim2.new(0, 90, 0.2, 0) }, Enum.EasingStyle.Quint)
tween(textoTitulo, 1.4, { TextTransparency = 0 })
task.spawn(cargarEstado)

-- En Studio: jugador:SetAttribute("PruebaInicio", "Personalizar" / "Titulo" / "Codigos") cambia de vista
if RunService:IsStudio() then
	jugador:GetAttributeChangedSignal("PruebaInicio"):Connect(function()
		local vista = jugador:GetAttribute("PruebaInicio")
		if vista == "Personalizar" then
			verPersonalizar()
		elseif vista == "Codigos" then
			verTitulo()
			ventanaCodigos.Visible = true
		elseif type(vista) == "string" and CONSTRUIR[vista] then
			verPersonalizar()
			mostrarPestana(vista)
		else
			verTitulo()
		end
	end)
end

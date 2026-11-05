-- Pueblos (cliente): cartel al entrar en un pueblo, diálogo con los NPC y ventana de tienda.
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/PueblosCliente (LocalScript)
--
-- Solo es interfaz: aquí no se compra nada todavía. Cuando llegue la compra con oro,
-- el botón "Comprar" pedirá al SERVIDOR que haga la compra (nunca se decide en el cliente).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local RunService = game:GetService("RunService")

local PueblosConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("PueblosConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RemoteHablar = Remotes:WaitForChild("HablarNPC")
local RemoteBurbuja = Remotes:WaitForChild("BurbujaNPC")
local TiendasConfig = require(ReplicatedStorage.Config:WaitForChild("TiendasConfig"))
local Voz = require(ReplicatedStorage:WaitForChild("Interfaz"):WaitForChild("Voz"))

local jugador = Players.LocalPlayer
local pantallaJugador = jugador:WaitForChild("PlayerGui")

-- ===== Estilo (como un libro antiguo: oscuro, con bordes dorados) =====
local FONDO = Color3.fromRGB(20, 17, 14)
local BORDE = Color3.fromRGB(176, 140, 72)
local TEXTO = Color3.fromRGB(236, 224, 196)
local TEXTO_SUAVE = Color3.fromRGB(170, 156, 130)
local ORO = Color3.fromRGB(232, 190, 90)
local FUENTE = Enum.Font.Garamond

local function crear(clase, propiedades, padre)
	local objeto = Instance.new(clase)
	for nombre, valor in propiedades do
		objeto[nombre] = valor
	end
	objeto.Parent = padre
	return objeto
end

local function marco(objeto, radio)
	crear("UICorner", { CornerRadius = UDim.new(0, radio or 6) }, objeto)
	crear("UIStroke", { Color = BORDE, Thickness = 1.5, Transparency = 0.15 }, objeto)
end

local pantalla = crear("ScreenGui", {
	Name = "Pueblos",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 10,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, pantallaJugador)

-- ===================================================================
-- ===== CARTEL AL ENTRAR EN UN PUEBLO =====
-- ===================================================================

local cartel = crear("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.2),
	Size = UDim2.fromOffset(600, 110),
	BackgroundTransparency = 1,
}, pantalla)
local cartelNombre = crear("TextLabel", {
	Size = UDim2.new(1, 0, 0.62, 0),
	BackgroundTransparency = 1,
	Font = FUENTE,
	TextScaled = true,
	Text = "",
	TextColor3 = TEXTO,
	TextStrokeColor3 = Color3.fromRGB(10, 8, 6),
	TextStrokeTransparency = 1,
	TextTransparency = 1,
}, cartel)
local cartelTitulo = crear("TextLabel", {
	Position = UDim2.fromScale(0, 0.64),
	Size = UDim2.new(1, 0, 0.3, 0),
	BackgroundTransparency = 1,
	Font = FUENTE,
	TextScaled = true,
	Text = "",
	TextColor3 = ORO,
	TextTransparency = 1,
	TextStrokeTransparency = 1,
}, cartel)

local function mostrarCartel(nombre, titulo)
	cartelNombre.Text = string.upper(nombre)
	cartelTitulo.Text = titulo
	local entrada = TweenInfo.new(1.4)
	TweenService:Create(cartelNombre, entrada, { TextTransparency = 0, TextStrokeTransparency = 0.5 }):Play()
	TweenService:Create(cartelTitulo, entrada, { TextTransparency = 0, TextStrokeTransparency = 0.6 }):Play()
	task.delay(4.5, function()
		if cartelNombre.Text == string.upper(nombre) then
			local salida = TweenInfo.new(2)
			TweenService:Create(cartelNombre, salida, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			TweenService:Create(cartelTitulo, salida, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

task.spawn(function()
	local mundo = Workspace:WaitForChild("Mundo", 60)
	local carpeta = mundo and mundo:WaitForChild("Pueblos", 60)
	if not carpeta then
		return
	end
	local dentroDe = nil
	local ultimaVez = {}
	while true do
		local personaje = jugador.Character
		local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
		if raiz then
			local ahora = nil
			for _, pueblo in carpeta:GetChildren() do
				local centro = pueblo:GetAttribute("Centro")
				local radio = pueblo:GetAttribute("Radio")
				if centro and radio then
					local plano = Vector3.new(raiz.Position.X - centro.X, 0, raiz.Position.Z - centro.Z)
					if plano.Magnitude < radio then
						ahora = pueblo
						break
					end
				end
			end
			if ahora ~= dentroDe then
				dentroDe = ahora
				if ahora and (not ultimaVez[ahora] or os.clock() - ultimaVez[ahora] > 60) then
					ultimaVez[ahora] = os.clock()
					mostrarCartel(ahora:GetAttribute("Nombre") or ahora.Name, ahora:GetAttribute("Titulo") or "")
				end
			end
		end
		task.wait(0.5)
	end
end)

-- ===================================================================
-- ===== DIÁLOGO CON LOS NPC =====
-- ===================================================================

local dialogo = crear("Frame", {
	Name = "Dialogo",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.new(0.62, 0, 0, 190),
	BackgroundColor3 = FONDO,
	BackgroundTransparency = 0.12,
	Visible = false,
}, pantalla)
marco(dialogo, 8)
crear("UISizeConstraint", { MaxSize = Vector2.new(820, 220), MinSize = Vector2.new(320, 170) }, dialogo)
crear("UIPadding", {
	PaddingLeft = UDim.new(0, 22),
	PaddingRight = UDim.new(0, 22),
	PaddingTop = UDim.new(0, 14),
	PaddingBottom = UDim.new(0, 14),
}, dialogo)

local dialogoNombre = crear("TextLabel", {
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundTransparency = 1,
	Font = FUENTE,
	TextSize = 28,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = ORO,
	Text = "",
}, dialogo)
local dialogoTitulo = crear("TextLabel", {
	Position = UDim2.fromOffset(0, 30),
	Size = UDim2.new(1, 0, 0, 18),
	BackgroundTransparency = 1,
	Font = FUENTE,
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = TEXTO_SUAVE,
	Text = "",
}, dialogo)
local dialogoTexto = crear("TextLabel", {
	Position = UDim2.fromOffset(0, 56),
	Size = UDim2.new(1, 0, 1, -104),
	BackgroundTransparency = 1,
	Font = FUENTE,
	TextSize = 22,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = TEXTO,
	Text = "",
}, dialogo)
local botones = crear("Frame", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.fromScale(1, 1),
	Size = UDim2.new(1, 0, 0, 38),
	BackgroundTransparency = 1,
}, dialogo)
crear("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, botones)

local function boton(texto, orden, padre)
	local b = crear("TextButton", {
		Size = UDim2.fromOffset(150, 36),
		BackgroundColor3 = Color3.fromRGB(46, 38, 28),
		AutoButtonColor = true,
		Font = FUENTE,
		TextSize = 20,
		TextColor3 = TEXTO,
		Text = texto,
		LayoutOrder = orden,
	}, padre)
	marco(b, 5)
	return b
end
local botonSeguir = boton("Seguir hablando", 1, botones)
local botonTienda = boton("Ver tienda", 2, botones)
local botonAdios = boton("Adiós", 3, botones)

-- ===================================================================
-- ===== VENTANA DE TIENDA =====
-- ===================================================================

local tiendaVentana = crear("Frame", {
	Name = "Tienda",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.5, 0.7),
	BackgroundColor3 = FONDO,
	BackgroundTransparency = 0.06,
	Visible = false,
}, pantalla)
marco(tiendaVentana, 10)
crear("UISizeConstraint", { MaxSize = Vector2.new(640, 640), MinSize = Vector2.new(340, 360) }, tiendaVentana)

local tiendaTitulo = crear("TextLabel", {
	Position = UDim2.fromOffset(24, 14),
	Size = UDim2.new(1, -80, 0, 36),
	BackgroundTransparency = 1,
	Font = FUENTE,
	TextSize = 32,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = ORO,
	Text = "",
}, tiendaVentana)
local tiendaSub = crear("TextLabel", {
	Position = UDim2.fromOffset(24, 50),
	Size = UDim2.new(1, -48, 0, 20),
	BackgroundTransparency = 1,
	Font = FUENTE,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = TEXTO_SUAVE,
	Text = "",
}, tiendaVentana)
local cerrar = crear("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 14),
	Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = Color3.fromRGB(46, 38, 28),
	Font = FUENTE,
	TextSize = 24,
	TextColor3 = TEXTO,
	Text = "✕",
}, tiendaVentana)
marco(cerrar, 18)

local lista = crear("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 82),
	Size = UDim2.new(1, -32, 1, -128),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = BORDE,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
}, tiendaVentana)
crear("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, lista)

crear("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(1, -40, 0, 22),
	BackgroundTransparency = 1,
	Font = FUENTE,
	TextSize = 18,
	TextColor3 = TEXTO_SUAVE,
	Text = "Las compras con monedas de oro llegan muy pronto.",
}, tiendaVentana)

-- Tipo de objeto que se muestra junto al nombre
local NOMBRE_CATEGORIA = { Arma = "Arma", Armadura = "Armadura", Pocion = "Poción", Montura = "Montura", Servicio = "Servicio" }

local function llenarTienda(cultura, tipo, nombrePueblo)
	for _, hijo in lista:GetChildren() do
		if hijo:IsA("Frame") then
			hijo:Destroy()
		end
	end
	local datos = TiendasConfig.TIPOS[tipo]
	tiendaTitulo.Text = datos.nombre
	tiendaSub.Text = nombrePueblo .. " · " .. datos.descripcion
	for i, objeto in TiendasConfig.Objetos(cultura, tipo) do
		local fila = crear("Frame", {
			Size = UDim2.new(1, -8, 0, 74),
			BackgroundColor3 = Color3.fromRGB(36, 30, 24),
			BackgroundTransparency = 0.1,
			LayoutOrder = i,
		}, lista)
		marco(fila, 6)
		crear("TextLabel", {
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -200, 0, 26),
			BackgroundTransparency = 1,
			Font = FUENTE,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = TEXTO,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = objeto.nombre,
		}, fila)
		local detalle = (NOMBRE_CATEGORIA[objeto.categoria] or "") .. " · " .. objeto.descripcion
		if objeto.peso then
			detalle = "Armadura " .. string.lower(objeto.peso) .. " · " .. objeto.descripcion
		end
		crear("TextLabel", {
			Position = UDim2.fromOffset(14, 36),
			Size = UDim2.new(1, -200, 0, 32),
			BackgroundTransparency = 1,
			Font = FUENTE,
			TextSize = 17,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = TEXTO_SUAVE,
			Text = detalle,
		}, fila)
		crear("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 8),
			Size = UDim2.fromOffset(160, 26),
			BackgroundTransparency = 1,
			Font = FUENTE,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = ORO,
			Text = objeto.precio .. " oro",
		}, fila)
		local comprar = crear("TextButton", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -14, 1, -8),
			Size = UDim2.fromOffset(130, 28),
			BackgroundColor3 = Color3.fromRGB(56, 50, 44),
			AutoButtonColor = false,
			Font = FUENTE,
			TextSize = 18,
			TextColor3 = Color3.fromRGB(140, 130, 116),
			Text = "Próximamente",
		}, fila)
		marco(comprar, 5)
	end
end

-- ===================================================================
-- ===== CONVERSACIÓN =====
-- ===================================================================

local npcActual = nil
local frases = {}
local indiceFrase = 0
local escribiendo = 0

local function escribir(texto)
	-- efecto de máquina de escribir
	escribiendo += 1
	local mio = escribiendo
	dialogoTexto.Text = texto
	dialogoTexto.MaxVisibleGraphemes = 0
	-- el NPC lo dice en voz alta, con su propia voz
	if npcActual then
		task.spawn(Voz.Decir, texto, Voz.PerfilNPC(npcActual), "npc")
	end
	local total = utf8.len(texto) or #texto
	task.spawn(function()
		for k = 1, total do
			if escribiendo ~= mio then
				return
			end
			dialogoTexto.MaxVisibleGraphemes = k
			task.wait(0.018)
		end
		dialogoTexto.MaxVisibleGraphemes = -1
	end)
end

local function cerrarTodo()
	dialogo.Visible = false
	tiendaVentana.Visible = false
	escribiendo += 1
	Voz.Callar("npc")
	if npcActual then
		local boton = npcActual:FindFirstChild("Hablar", true)
		if boton then
			boton.Enabled = true
		end
		-- avisamos al servidor: el NPC puede seguir con lo suyo
		RemoteHablar:FireServer(npcActual, false)
	end
	npcActual = nil
end

local function frasesDe(npc)
	local cultura = npc:GetAttribute("Cultura")
	local oficio = npc:GetAttribute("Oficio")
	local pueblo = npc:GetAttribute("PuebloNombre") or ""
	local deCultura = PueblosConfig.FRASES[cultura] or {}
	local lista = deCultura[oficio] or deCultura.Aldeano or { "..." }
	-- si un noble acaba de humillarlo, te lo cuenta
	local humillado = npc:GetAttribute("Humillado")
	if humillado and os.time() - humillado < 240 and PueblosConfig.FRASES_HUMILLADO[cultura] then
		lista = PueblosConfig.FRASES_HUMILLADO[cultura]
	end
	local resultado = {}
	for _, frase in lista do
		table.insert(resultado, (string.gsub(frase, "{pueblo}", pueblo)))
	end
	return resultado
end

local function hablarCon(npc)
	if npcActual == npc then
		return
	end
	cerrarTodo()
	npcActual = npc
	frases = frasesDe(npc)
	indiceFrase = 1
	dialogoNombre.Text = npc:GetAttribute("Nombre") or npc.Name
	dialogoTitulo.Text = (npc:GetAttribute("Titulo") or "") .. " · " .. (npc:GetAttribute("PuebloNombre") or "")
	botonTienda.Visible = npc:GetAttribute("Tienda") ~= nil
	botonSeguir.Visible = #frases > 1
	escribir(frases[1])
	dialogo.Visible = true
	local boton = npc:FindFirstChild("Hablar", true)
	if boton then
		boton.Enabled = false
	end
	-- el servidor hace que el NPC se pare y te mire mientras habláis
	RemoteHablar:FireServer(npc, true)
end

botonSeguir.MouseButton1Click:Connect(function()
	if not npcActual then
		return
	end
	indiceFrase = indiceFrase % #frases + 1
	escribir(frases[indiceFrase])
end)

botonTienda.MouseButton1Click:Connect(function()
	if not npcActual then
		return
	end
	local tipo = npcActual:GetAttribute("Tienda")
	if tipo then
		llenarTienda(npcActual:GetAttribute("Cultura"), tipo, npcActual:GetAttribute("PuebloNombre") or "")
		dialogo.Visible = false
		tiendaVentana.Visible = true
	end
end)

botonAdios.MouseButton1Click:Connect(cerrarTodo)
cerrar.MouseButton1Click:Connect(cerrarTodo)

UserInputService.InputBegan:Connect(function(entrada, procesado)
	if procesado then
		return
	end
	if entrada.KeyCode == Enum.KeyCode.Escape or entrada.KeyCode == Enum.KeyCode.ButtonB then
		if npcActual then
			cerrarTodo()
		end
	end
end)

-- Los botones de hablar usan la tecla de "Interactuar" del jugador (de fábrica, G)
local Controles = require(ReplicatedStorage:WaitForChild("Combate"):WaitForChild("Controles"))
local function teclaHablar(boton)
	local nombre = Controles.TeclaDe("Interactuar")
	local ok, tecla = pcall(function()
		return Enum.KeyCode[nombre]
	end)
	if ok and tecla and boton.KeyboardKeyCode ~= tecla then
		boton.KeyboardKeyCode = tecla
	end
end
ProximityPromptService.PromptShown:Connect(teclaHablar)

ProximityPromptService.PromptTriggered:Connect(function(boton)
	local npc = boton:FindFirstAncestorWhichIsA("Model")
	if npc and npc:GetAttribute("NPC") then
		hablarCon(npc)
	end
end)

-- Si te alejas, la conversación se cierra sola
task.spawn(function()
	while true do
		task.wait(0.4)
		if npcActual then
			local personaje = jugador.Character
			local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
			if not raiz or not npcActual.Parent or (raiz.Position - npcActual:GetPivot().Position).Magnitude > 16 then
				cerrarTodo()
			end
		end
	end
end)

-- ===================================================================
-- ===== GLOBOS DE TEXTO (lo que dicen los NPC en voz alta) =====
-- ===================================================================

RemoteBurbuja.OnClientEvent:Connect(function(npc, texto, duracion)
	if typeof(npc) ~= "Instance" or typeof(texto) ~= "string" then
		return
	end
	local cabeza = npc:FindFirstChild("Head")
	local camara = Workspace.CurrentCamera
	if not cabeza or not camara or (cabeza.Position - camara.CFrame.Position).Magnitude > 70 then
		return
	end
	-- si está cerca y no estás hablando con otro, se le oye (más bajo cuanto más lejos)
	local distancia = (cabeza.Position - camara.CFrame.Position).Magnitude
	if distancia < 34 and not npcActual then
		task.spawn(Voz.Decir, texto, Voz.PerfilNPC(npc), "burbuja", math.clamp(1.1 - distancia / 40, 0.25, 1))
	end
	local anterior = cabeza:FindFirstChild("Burbuja")
	if anterior then
		anterior:Destroy()
	end
	local globo = crear("BillboardGui", {
		Name = "Burbuja",
		Size = UDim2.fromOffset(260, 70),
		StudsOffset = Vector3.new(0, 4.3, 0),
		MaxDistance = 70,
		LightInfluence = 0,
		AlwaysOnTop = false,
	}, cabeza)
	local fondo = crear("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 1),
		AutomaticSize = Enum.AutomaticSize.None,
		BackgroundColor3 = Color3.fromRGB(245, 236, 214),
		BackgroundTransparency = 0.05,
	}, globo)
	crear("UICorner", { CornerRadius = UDim.new(0, 10) }, fondo)
	crear("UIStroke", { Color = Color3.fromRGB(90, 70, 46), Thickness = 1.5 }, fondo)
	crear("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, fondo)
	local etiqueta = crear("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = FUENTE,
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(40, 30, 22),
		Text = texto,
	}, fondo)
	crear("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 12 }, etiqueta)
	task.delay(duracion or 4, function()
		if globo.Parent then
			TweenService:Create(fondo, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(etiqueta, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			task.wait(0.6)
			globo:Destroy()
		end
	end)
end)

-- ===================================================================
-- ===== ASPAS DE MOLINO QUE GIRAN (solo en tu pantalla) =====
-- ===================================================================

task.spawn(function()
	local mundo = Workspace:WaitForChild("Mundo", 60)
	local carpeta = mundo and mundo:WaitForChild("Pueblos", 60)
	if not carpeta then
		return
	end
	local giratorios = {}
	local function buscar()
		table.clear(giratorios)
		for _, d in carpeta:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("Girar") then
				table.insert(giratorios, { modelo = d, base = d:GetPivot(), centro = d:GetAttribute("Centro"), eje = d:GetAttribute("Eje") })
			end
		end
	end
	buscar()
	carpeta.DescendantAdded:Connect(function(d)
		if d:IsA("Model") and d:GetAttribute("Girar") then
			task.wait()
			buscar()
		end
	end)
	local angulo = 0
	RunService.RenderStepped:Connect(function(dt)
		angulo += dt * (0.5 + Workspace.GlobalWind.Magnitude * 0.05)
		local camara = Workspace.CurrentCamera
		for _, g in giratorios do
			if g.centro and g.eje and camara and (g.centro - camara.CFrame.Position).Magnitude < 400 then
				local rotacion = CFrame.new(g.centro) * CFrame.fromAxisAngle(g.eje, angulo) * CFrame.new(-g.centro)
				g.modelo:PivotTo(rotacion * g.base)
			end
		end
	end)
end)

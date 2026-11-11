-- EDITOR DE ASPECTO (solo CLIENTE): dos paneles a los lados del personaje, como en los RPG
-- de Roblox modernos. A la izquierda "Pelo y piel", a la derecha "Cara y ropa". Cada fila
-- tiene flechas ‹ 3/12 › y, si se puede teñir, un botón de color que abre el selector
-- (cuadro de tono, barra de color y 16 colores rápidos).
-- Ruta en Studio: ReplicatedStorage/Interfaz/EditorAspecto (ModuleScript)
--
-- Lo usa StarterPlayerScripts/InicioCliente. El editor solo PIDE los cambios: el servidor
-- (ServerScriptService/Progresion/InicioServicio) los comprueba, los guarda y viste al personaje.
--
--   local editor = EditorAspecto.Crear(pantalla, { aplicar = function(campo, valor) end })
--   editor:Mostrar(apariencia)   editor:Actualizar(apariencia)   editor:Ocultar()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = ReplicatedStorage:WaitForChild("Config")
local AparienciaConfig = require(Config:WaitForChild("AparienciaConfig"))
local Estilo = require(script.Parent:WaitForChild("Estilo"))
local Idioma = require(Config:WaitForChild("Idioma"))

local C = Estilo.COLORES
local FONDO_PANEL = Color3.fromRGB(22, 19, 26)
local BORDE_PANEL = Color3.fromRGB(122, 98, 60)
local BOTON_ORO = Color3.fromRGB(196, 150, 70)

local EditorAspecto = {}
EditorAspecto.__index = EditorAspecto

local function T(es, en)
	return Idioma.Elegir(es, en)
end

-- ===== Filas que se pueden cambiar =====
-- { campo, título, lista (o número de opciones), conCero (opción "Ninguno"), campoColor }
local function filas(genero)
	local izquierda = {
		{ campo = "Peinado", titulo = T("Peinado", "Hair"), lista = AparienciaConfig.PEINADOS, cero = true, color = "PeloColor" },
		{ campo = "Peinado2", titulo = T("Segundo peinado", "Second hair"), lista = AparienciaConfig.PEINADOS, cero = true, color = "PeloColor" },
		{ campo = "Tocado", titulo = T("Tocado", "Headwear"), lista = AparienciaConfig.TOCADOS, cero = true },
		{ campo = "Piel", titulo = T("Tono de piel", "Skin tone"), lista = AparienciaConfig.PIELES, piel = true },
	}
	if genero ~= "Mujer" then
		table.insert(izquierda, 4, { campo = "Barba", titulo = T("Barba", "Beard"), lista = AparienciaConfig.BARBAS, cero = true })
	end
	local derecha = {
		{ campo = "Rostro", titulo = T("Cara", "Face"), lista = AparienciaConfig.ROSTROS },
		{ campo = "Camisa", titulo = T("Camisa", "Top"), lista = AparienciaConfig.CAMISAS, color = "CamisaColor" },
		{ campo = "Pantalon", titulo = T("Pantalón", "Bottom"), lista = AparienciaConfig.PANTALONES, color = "PantalonColor" },
		{ campo = "Cinturon", titulo = T("Cinturón", "Belt"), lista = AparienciaConfig.CINTURONES, cero = true, color = "CinturonColor" },
		{ campo = "Botas", titulo = T("Botas", "Boots"), lista = AparienciaConfig.BOTAS, cero = true, color = "BotasColor" },
		{ campo = "Capa", titulo = T("Capa", "Cape"), lista = AparienciaConfig.CAPAS, cero = true, color = "CapaColor" },
	}
	return izquierda, derecha
end

local function nombreOpcion(fila, valor)
	if valor == 0 then
		return T("Ninguno", "None")
	end
	local opcion = fila.lista[valor]
	if type(opcion) == "table" then
		return Idioma.T(opcion.nombre or "")
	elseif type(opcion) == "string" then
		return Idioma.T(opcion)
	end
	return tostring(valor)
end

-- ===== Piezas de interfaz =====
local function circuloBoton(padre, texto, x)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.Size = UDim2.fromOffset(26, 26)
	b.Position = UDim2.new(0, x, 0.5, 0)
	b.AnchorPoint = Vector2.new(0, 0.5)
	b.BackgroundColor3 = BOTON_ORO
	b.Font = Estilo.FUERTE
	b.TextSize = 16
	b.TextColor3 = Color3.fromRGB(40, 28, 16)
	b.Text = texto
	b.Parent = padre
	Estilo.Esquinas(b, 13)
	Estilo.Borde(b, Color3.fromRGB(255, 226, 160), 1, 0.4)
	return b
end

local function panelLateral(pantalla, titulo, lado)
	local p = Estilo.Marco(pantalla, {
		AnchorPoint = Vector2.new(if lado == "izq" then 0 else 1, 0.5),
		Position = if lado == "izq" then UDim2.new(0, 24, 0.5, -10) else UDim2.new(1, -24, 0.5, -10),
		Size = UDim2.fromOffset(330, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = FONDO_PANEL,
		BackgroundTransparency = 0.12,
		Visible = false,
	})
	Estilo.Esquinas(p, 10)
	Estilo.Borde(p, BORDE_PANEL, 1.5, 0.15)
	local relleno = Instance.new("UIPadding")
	relleno.PaddingTop = UDim.new(0, 12)
	relleno.PaddingBottom = UDim.new(0, 14)
	relleno.PaddingLeft = UDim.new(0, 14)
	relleno.PaddingRight = UDim.new(0, 14)
	relleno.Parent = p
	local lista = Instance.new("UIListLayout")
	lista.Padding = UDim.new(0, 6)
	lista.SortOrder = Enum.SortOrder.LayoutOrder
	lista.Parent = p
	local cabecera = Estilo.Texto(p, {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 22),
		Font = Estilo.FUERTE,
		TextSize = 12,
		TextColor3 = C.oro,
		Text = string.upper(titulo),
	})
	cabecera.TextXAlignment = Enum.TextXAlignment.Left
	local linea = Estilo.Marco(p, {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = BORDE_PANEL,
		BackgroundTransparency = 0.3,
	})
	linea.BorderSizePixel = 0
	return p
end

-- ===== Selector de color =====
local function crearSelector(pantalla)
	local s = {}
	local marco = Estilo.Marco(pantalla, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(392, 236),
		BackgroundColor3 = FONDO_PANEL,
		BackgroundTransparency = 0.04,
		Visible = false,
		ZIndex = 30,
	})
	Estilo.Esquinas(marco, 10)
	Estilo.Borde(marco, BORDE_PANEL, 1.5, 0.1)
	s.marco = marco
	s.titulo = Estilo.Texto(marco, {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -60, 0, 22),
		Font = Estilo.FUERTE,
		TextSize = 13,
		TextColor3 = C.oro,
		Text = "",
		ZIndex = 31,
	})
	local cerrar = Instance.new("TextButton")
	cerrar.Size = UDim2.fromOffset(26, 26)
	cerrar.Position = UDim2.new(1, -34, 0, 6)
	cerrar.BackgroundTransparency = 1
	cerrar.Text = "✕"
	cerrar.Font = Estilo.FUERTE
	cerrar.TextSize = 16
	cerrar.TextColor3 = C.textoSuave
	cerrar.ZIndex = 31
	cerrar.Parent = marco
	cerrar.MouseButton1Click:Connect(function()
		marco.Visible = false
	end)

	-- cuadro: saturación (horizontal) y brillo (vertical) del tono elegido
	local cuadro = Instance.new("ImageButton")
	cuadro.AutoButtonColor = false
	cuadro.Position = UDim2.fromOffset(14, 38)
	cuadro.Size = UDim2.fromOffset(150, 150)
	cuadro.BackgroundColor3 = Color3.new(1, 0, 0)
	cuadro.ZIndex = 31
	cuadro.Parent = marco
	Estilo.Esquinas(cuadro, 4)
	local blanco = Estilo.Marco(cuadro, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 31 })
	Estilo.Esquinas(blanco, 4)
	local g1 = Instance.new("UIGradient")
	g1.Transparency = NumberSequence.new(0, 1)
	g1.Parent = blanco
	local negroCapa = Estilo.Marco(cuadro, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 32 })
	Estilo.Esquinas(negroCapa, 4)
	local g2 = Instance.new("UIGradient")
	g2.Rotation = 90
	g2.Transparency = NumberSequence.new(1, 0)
	g2.Parent = negroCapa
	local punto = Estilo.Marco(cuadro, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		ZIndex = 34,
	})
	Estilo.Esquinas(punto, 5)
	Estilo.Borde(punto, Color3.new(1, 1, 1), 2, 0)

	-- barra de tono
	local barra = Instance.new("ImageButton")
	barra.AutoButtonColor = false
	barra.Position = UDim2.fromOffset(172, 38)
	barra.Size = UDim2.fromOffset(16, 150)
	barra.BackgroundColor3 = Color3.new(1, 1, 1)
	barra.ZIndex = 31
	barra.Parent = marco
	Estilo.Esquinas(barra, 4)
	local arcoiris = Instance.new("UIGradient")
	arcoiris.Rotation = 90
	local claves = {}
	for i = 0, 6 do
		table.insert(claves, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)))
	end
	arcoiris.Color = ColorSequence.new(claves)
	arcoiris.Parent = barra
	local marcaTono = Estilo.Marco(barra, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 6, 0, 4),
		Position = UDim2.fromScale(0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 33,
	})
	Estilo.Borde(marcaTono, Color3.new(0, 0, 0), 1, 0.3)

	-- muestra del color actual + colores rápidos
	local muestra = Estilo.Marco(marco, {
		Position = UDim2.fromOffset(198, 38),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 31,
	})
	Estilo.Esquinas(muestra, 6)
	Estilo.Borde(muestra, BORDE_PANEL, 1, 0.2)
	local ayuda = Estilo.Texto(marco, {
		Position = UDim2.fromOffset(246, 38),
		Size = UDim2.fromOffset(134, 40),
		TextSize = 11,
		TextWrapped = true,
		TextColor3 = C.textoSuave,
		Text = T("Arrastra en el cuadro o toca un color rápido.", "Drag in the box or tap a quick color."),
		ZIndex = 31,
	})
	ayuda.TextXAlignment = Enum.TextXAlignment.Left
	local rapidos = Estilo.Marco(marco, {
		Position = UDim2.fromOffset(198, 88),
		Size = UDim2.fromOffset(180, 92),
		BackgroundTransparency = 1,
		ZIndex = 31,
	})
	local rejilla = Instance.new("UIGridLayout")
	rejilla.CellSize = UDim2.fromOffset(19, 19)
	rejilla.CellPadding = UDim2.fromOffset(4, 4)
	rejilla.Parent = rapidos
	s.rapidos = rapidos
	s.natural = Estilo.Boton(marco, {
		Position = UDim2.fromOffset(14, 196),
		Size = UDim2.fromOffset(174, 28),
		Text = T("Color natural del pelo", "Natural hair color"),
		TextSize = 12,
		ZIndex = 31,
		Visible = false,
	})

	local h, sat, v = 0, 1, 1
	local alCambiar = nil
	local function pintar()
		cuadro.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		punto.Position = UDim2.fromScale(sat, 1 - v)
		marcaTono.Position = UDim2.fromScale(0.5, h)
		muestra.BackgroundColor3 = Color3.fromHSV(h, sat, v)
	end
	local function avisar(final)
		if alCambiar then
			alCambiar("#" .. Color3.fromHSV(h, sat, v):ToHex(), final)
		end
	end
	local arrastrando = nil
	local function mover(posicion)
		if arrastrando == cuadro then
			local rel = (posicion - cuadro.AbsolutePosition) / cuadro.AbsoluteSize
			sat = math.clamp(rel.X, 0, 1)
			v = 1 - math.clamp(rel.Y, 0, 1)
		elseif arrastrando == barra then
			h = math.clamp((posicion.Y - barra.AbsolutePosition.Y) / barra.AbsoluteSize.Y, 0, 0.999)
		end
		pintar()
		avisar(false)
	end
	for _, zona in { cuadro, barra } do
		zona.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				arrastrando = zona
				mover(Vector2.new(input.Position.X, input.Position.Y))
			end
		end)
	end
	UserInputService.InputChanged:Connect(function(input)
		if arrastrando and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			mover(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if arrastrando and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			arrastrando = nil
			avisar(true)
		end
	end)

	function s.Abrir(titulo, hex, colores, conNatural, funcion, lado)
		s.titulo.Text = titulo
		-- se abre al lado del panel que lo pidió (así no tapa la cara del personaje)
		if lado == "der" then
			marco.AnchorPoint = Vector2.new(1, 0.5)
			marco.Position = UDim2.new(1, -366, 0.5, -10)
		else
			marco.AnchorPoint = Vector2.new(0, 0.5)
			marco.Position = UDim2.new(0, 366, 0.5, -10)
		end
		alCambiar = funcion
		local c = if type(hex) == "string" and hex ~= "" then Color3.fromHex(hex) else Color3.fromRGB(120, 90, 60)
		h, sat, v = c:ToHSV()
		pintar()
		for _, hijo in rapidos:GetChildren() do
			if hijo:IsA("GuiButton") then
				hijo:Destroy()
			end
		end
		for i, hx in colores do
			local b = Instance.new("TextButton")
			b.Text = ""
			b.LayoutOrder = i
			b.AutoButtonColor = true
			b.BackgroundColor3 = Color3.fromHex(hx)
			b.ZIndex = 32
			b.Parent = rapidos
			Estilo.Esquinas(b, 4)
			Estilo.Borde(b, Color3.new(0, 0, 0), 1, 0.5)
			b.MouseButton1Click:Connect(function()
				h, sat, v = Color3.fromHex(hx):ToHSV()
				pintar()
				avisar(true)
			end)
		end
		s.natural.Visible = conNatural == true
		marco.Visible = true
	end
	s.natural.MouseButton1Click:Connect(function()
		if alCambiar then
			alCambiar("", true)
		end
		marco.Visible = false
	end)
	return s
end

-- ===== Crear el editor =====
function EditorAspecto.Crear(pantalla, opciones)
	local self = setmetatable({}, EditorAspecto)
	self.aplicar = opciones.aplicar
	self.apariencia = nil
	self.pantalla = pantalla
	self.izq = panelLateral(pantalla, T("Pelo y piel", "Hair & skin"), "izq")
	self.der = panelLateral(pantalla, T("Cara y ropa", "Face & clothing"), "der")
	self.selector = crearSelector(pantalla)
	self.filas = {}
	self.ultimoEnvio = {}
	return self
end

-- Envía un cambio (los colores mientras arrastras van como mucho cada 0.15 s)
function EditorAspecto:Enviar(campo, valor, final)
	self.apariencia[campo] = valor
	local ahora = os.clock()
	if not final and self.ultimoEnvio[campo] and ahora - self.ultimoEnvio[campo] < 0.15 then
		self.pendiente = self.pendiente or {}
		self.pendiente[campo] = valor
		task.delay(0.16, function()
			if self.pendiente and self.pendiente[campo] ~= nil then
				local v = self.pendiente[campo]
				self.pendiente[campo] = nil
				self.ultimoEnvio[campo] = os.clock()
				self.aplicar(campo, v)
			end
		end)
		return
	end
	if self.pendiente then
		self.pendiente[campo] = nil
	end
	self.ultimoEnvio[campo] = ahora
	self.aplicar(campo, valor)
end

function EditorAspecto:CrearFila(panel, fila, orden)
	local a = self.apariencia
	local caja = Estilo.Marco(panel, {
		LayoutOrder = orden,
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
	})
	caja.Name = fila.campo
	local titulo = Estilo.Texto(caja, {
		Size = UDim2.new(0.5, 0, 0, 16),
		TextSize = 12,
		Font = Estilo.FUERTE,
		TextColor3 = C.textoSuave,
		Text = fila.titulo,
	})
	titulo.TextXAlignment = Enum.TextXAlignment.Left
	local nombre = Estilo.Texto(caja, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0.55, 0, 0, 16),
		TextSize = 12,
		TextColor3 = C.texto,
		Text = "",
	})
	nombre.TextXAlignment = Enum.TextXAlignment.Right
	nombre.TextTruncate = Enum.TextTruncate.AtEnd
	local linea = Estilo.Marco(caja, {
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
	})
	-- ‹ 3 / 12 ›
	local menos = circuloBoton(linea, "‹", 0)
	local cuenta = Estilo.Marco(linea, {
		Position = UDim2.new(0, 30, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(72, 26),
		BackgroundColor3 = Color3.fromRGB(14, 12, 18),
		BackgroundTransparency = 0.1,
	})
	Estilo.Esquinas(cuenta, 13)
	Estilo.Borde(cuenta, BORDE_PANEL, 1, 0.4)
	local textoCuenta = Estilo.Texto(cuenta, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 13,
		Font = Estilo.FUERTE,
		TextColor3 = C.texto,
		Text = "",
	})
	textoCuenta.TextXAlignment = Enum.TextXAlignment.Center
	local mas = circuloBoton(linea, "›", 106)
	local total = #fila.lista
	local minimo = if fila.cero then 0 else 1
	local function cambiar(paso)
		local actual = a[fila.campo] or minimo
		local n = actual + paso
		if n > total then
			n = minimo
		elseif n < minimo then
			n = total
		end
		self:Enviar(fila.campo, n, true)
		self:RefrescarFila(fila)
	end
	menos.MouseButton1Click:Connect(function()
		cambiar(-1)
	end)
	mas.MouseButton1Click:Connect(function()
		cambiar(1)
	end)
	-- botón de color
	local botonColor = nil
	if fila.color or fila.piel then
		botonColor = Instance.new("TextButton")
		botonColor.AutoButtonColor = true
		botonColor.AnchorPoint = Vector2.new(0, 0.5)
		botonColor.Position = UDim2.new(0, 142, 0.5, 0)
		botonColor.Size = UDim2.fromOffset(78, 26)
		botonColor.BackgroundColor3 = Color3.fromRGB(14, 12, 18)
		botonColor.Text = ""
		botonColor.Parent = linea
		Estilo.Esquinas(botonColor, 13)
		Estilo.Borde(botonColor, BORDE_PANEL, 1, 0.4)
		local bola = Estilo.Marco(botonColor, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 5, 0.5, 0),
			Size = UDim2.fromOffset(18, 18),
		})
		bola.Name = "Bola"
		Estilo.Esquinas(bola, 9)
		Estilo.Borde(bola, Color3.new(1, 1, 1), 1, 0.4)
		local t = Estilo.Texto(botonColor, {
			Position = UDim2.fromOffset(28, 0),
			Size = UDim2.new(1, -30, 1, 0),
			TextSize = 12,
			TextColor3 = C.texto,
			Text = T("Color", "Color"),
		})
		t.TextXAlignment = Enum.TextXAlignment.Left
		if fila.piel then
			botonColor.Visible = false -- la piel se elige con las flechas (tonos fijos)
		else
			botonColor.MouseButton1Click:Connect(function()
				local campoColor = fila.color
				self.selector.Abrir(
					fila.titulo .. " · " .. T("color", "color"),
					a[campoColor],
					if campoColor == "PeloColor" then AparienciaConfig.COLORES_PELO else AparienciaConfig.COLORES_RAPIDOS,
					campoColor == "PeloColor",
					function(hex, final)
						self:Enviar(campoColor, hex, final)
						self:RefrescarColores()
					end,
					if panel == self.der then "der" else "izq"
				)
			end)
		end
	end
	self.filas[fila.campo] = { fila = fila, nombre = nombre, cuenta = textoCuenta, color = botonColor, total = total }
	self:RefrescarFila(fila)
end

function EditorAspecto:RefrescarFila(fila)
	local f = self.filas[fila.campo]
	if not f then
		return
	end
	local valor = self.apariencia[fila.campo] or 0
	f.cuenta.Text = string.format("%d / %d", valor, f.total)
	f.nombre.Text = nombreOpcion(fila, valor)
	if fila.piel then
		f.nombre.Text = ""
		f.nombre.TextColor3 = C.texto
	end
end

function EditorAspecto:RefrescarColores()
	for _, f in self.filas do
		if f.color and f.fila.color then
			local hex = self.apariencia[f.fila.color]
			local bola = f.color:FindFirstChild("Bola")
			if bola then
				if hex == "" then
					bola.BackgroundColor3 = Color3.fromRGB(110, 80, 50)
				elseif type(hex) == "string" and hex ~= "" then
					bola.BackgroundColor3 = Color3.fromHex(hex)
				end
			end
		end
	end
end

function EditorAspecto:Construir()
	for _, panel in { self.izq, self.der } do
		for _, hijo in panel:GetChildren() do
			if hijo:IsA("Frame") and hijo.LayoutOrder >= 10 then
				hijo:Destroy()
			end
		end
	end
	self.filas = {}
	local izquierda, derecha = filas(self.apariencia.Genero)
	for i, fila in izquierda do
		self:CrearFila(self.izq, fila, 10 + i)
	end
	for i, fila in derecha do
		self:CrearFila(self.der, fila, 10 + i)
	end
	self:RefrescarColores()
end

function EditorAspecto:Mostrar(apariencia)
	self.apariencia = table.clone(apariencia)
	self.generoConstruido = self.apariencia.Genero
	self:Construir()
	self.izq.Visible = true
	self.der.Visible = true
end

-- Cuando el servidor devuelve la apariencia guardada
function EditorAspecto:Actualizar(apariencia)
	if not self.apariencia then
		return
	end
	local pendientes = self.pendiente
	self.apariencia = table.clone(apariencia)
	if pendientes then
		for campo, valor in pendientes do
			self.apariencia[campo] = valor
		end
	end
	if self.apariencia.Genero ~= self.generoConstruido then
		self.generoConstruido = self.apariencia.Genero
		self:Construir()
		return
	end
	for _, f in self.filas do
		self:RefrescarFila(f.fila)
	end
	self:RefrescarColores()
end

function EditorAspecto:Ocultar()
	self.izq.Visible = false
	self.der.Visible = false
	self.selector.marco.Visible = false
end

return EditorAspecto

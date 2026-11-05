-- Menú principal del juego (tecla M). Solo CLIENTE: dibuja y pide cosas al servidor.
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/MenuM
--
-- Pestañas: Personaje, Estadísticas (repartir puntos), Mochila, Mapa, Habilidades,
-- Tienda, Misiones y Ajustes (cambiar teclas). Todo cambio real lo valida el servidor:
--   repartir puntos -> RemoteEvent RepartirPuntos
--   guardar teclas  -> RemoteEvent GuardarTeclas

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Estilo = require(ReplicatedStorage:WaitForChild("Interfaz"):WaitForChild("Estilo"))
local DatosLocal = require(ReplicatedStorage:WaitForChild("Progresion"):WaitForChild("DatosLocal"))
local Formulas = require(ReplicatedStorage:WaitForChild("Progresion"):WaitForChild("Formulas"))
local Controles = require(ReplicatedStorage:WaitForChild("Combate"):WaitForChild("Controles"))
local Config = ReplicatedStorage:WaitForChild("Config")
local ProgresionConfig = require(Config:WaitForChild("ProgresionConfig"))
local RazasConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("RazasConfig"))
local HistoriaConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("HistoriaConfig"))
local Pergamino = require(ReplicatedStorage:WaitForChild("Interfaz"):WaitForChild("Pergamino"))
local ControlesConfig = require(Config:WaitForChild("ControlesConfig"))
local RegionesConfig = require(Config:WaitForChild("RegionesConfig"))
local Constantes = require(Config:WaitForChild("Constantes"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RemoteRepartir = Remotes:WaitForChild("RepartirPuntos")
local RemoteTeclas = Remotes:WaitForChild("GuardarTeclas")

local jugador = Players.LocalPlayer
local C = Estilo.COLORES

-- ===== Ventana =====
local pantalla = Instance.new("ScreenGui")
pantalla.Name = "MenuM"
pantalla.ResetOnSpawn = false
pantalla.Enabled = false
pantalla.DisplayOrder = 10
pantalla.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pantalla.IgnoreGuiInset = true
pantalla.Parent = jugador:WaitForChild("PlayerGui")

-- Fondo oscuro (también libera el ratón aunque el Shift Lock esté puesto)
local velo = Instance.new("TextButton")
velo.Name = "Velo"
velo.Text = ""
velo.AutoButtonColor = false
velo.Modal = true
velo.Size = UDim2.fromScale(1, 1)
velo.BackgroundColor3 = Color3.new(0, 0, 0)
velo.BackgroundTransparency = 0.45
velo.BorderSizePixel = 0
velo.Parent = pantalla

local ventana = Estilo.Marco(pantalla, {
	Name = "Ventana",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(980, 610),
	BackgroundColor3 = C.fondo,
})
Estilo.Esquinas(ventana, 10)
Estilo.Borde(ventana, C.oroOscuro, 2)
local escala = Instance.new("UIScale")
escala.Parent = ventana
local function ajustarEscala()
	local vista = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	escala.Scale = math.min(1, (vista.X - 30) / 980, (vista.Y - 30) / 610)
end
ajustarEscala()
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajustarEscala)

-- Cabecera
local cabecera = Estilo.Marco(ventana, { Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1 })
local titulo = Estilo.Texto(cabecera, {
	Position = UDim2.fromOffset(22, 6),
	Size = UDim2.fromOffset(500, 44),
	Font = Estilo.TITULO,
	TextSize = 34,
	TextColor3 = C.oro,
	Text = "Menú",
})
local subtitulo = Estilo.Texto(cabecera, {
	Position = UDim2.fromOffset(240, 18),
	Size = UDim2.fromOffset(500, 22),
	TextColor3 = C.textoSuave,
	TextSize = 14,
	Text = "",
})
local cerrar = Estilo.Boton(cabecera, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 12),
	Size = UDim2.fromOffset(32, 32),
	Text = "X",
	TextColor3 = C.oro,
})
Estilo.Marco(
	ventana,
	{ Position = UDim2.fromOffset(18, 56), Size = UDim2.new(1, -36, 0, 1), BackgroundColor3 = C.borde }
)

-- Pestañas a la izquierda
local columna = Estilo.Marco(
	ventana,
	{ Position = UDim2.fromOffset(14, 68), Size = UDim2.new(0, 186, 1, -82), BackgroundTransparency = 1 }
)
Estilo.Lista(columna, 6)
local contenido = Estilo.Marco(ventana, {
	Name = "Contenido",
	Position = UDim2.fromOffset(212, 68),
	Size = UDim2.new(1, -226, 1, -82),
	BackgroundColor3 = C.panel,
})
Estilo.Esquinas(contenido, 8)
Estilo.Relleno(contenido, 14)

local PESTANAS = { "Personaje", "Estadísticas", "Mochila", "Mapa", "Habilidades", "Tienda", "Misiones", "Ajustes" }
local botonesPestana = {}
local pestanaActual = "Personaje"
local constructores = {}
local limpiezas = {} -- funciones a llamar al cambiar de pestaña

local function limpiar()
	for _, funcion in limpiezas do
		pcall(funcion)
	end
	limpiezas = {}
	for _, hijo in contenido:GetChildren() do
		if not hijo:IsA("UIPadding") and not hijo:IsA("UICorner") then
			hijo:Destroy()
		end
	end
end

local function mostrar(nombre)
	pestanaActual = nombre
	for n, boton in botonesPestana do
		local activa = n == nombre
		boton.BackgroundColor3 = if activa then C.oroOscuro else C.panel
		boton.TextColor3 = if activa then Color3.fromRGB(255, 245, 225) else C.texto
	end
	titulo.Text = nombre
	limpiar()
	local ok, err = pcall(constructores[nombre], contenido)
	if not ok then
		warn("[MENU] Error en la pestaña", nombre, err)
		Estilo.Texto(contenido, {
			Size = UDim2.fromScale(1, 1),
			Text = "Error al dibujar esta pestaña:\n" .. tostring(err),
			TextWrapped = true,
			TextColor3 = C.rojo,
		})
	end
end

for i, nombre in PESTANAS do
	local boton = Estilo.Boton(columna, {
		LayoutOrder = i,
		Size = UDim2.new(1, 0, 0, 52),
		Text = nombre,
		TextSize = 17,
		Font = Estilo.FUERTE,
		BackgroundColor3 = C.panel,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Estilo.Relleno(boton, 0).PaddingLeft = UDim.new(0, 16)
	Estilo.Borde(boton, C.borde, 1, 0.5)
	boton.MouseButton1Click:Connect(function()
		mostrar(nombre)
	end)
	botonesPestana[nombre] = boton
end

-- ===== Ayudantes =====
local function datos()
	return DatosLocal.Obtener()
end

local function seccion(padre, texto, orden)
	return Estilo.Texto(padre, {
		LayoutOrder = orden or 0,
		Size = UDim2.new(1, 0, 0, 26),
		Font = Estilo.TITULO,
		TextSize = 22,
		TextColor3 = C.oro,
		Text = texto,
	})
end

local function fila(padre, izquierda, derecha, orden)
	local f =
		Estilo.Marco(padre, { LayoutOrder = orden or 0, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1 })
	Estilo.Texto(f, { Size = UDim2.new(0.55, 0, 1, 0), TextColor3 = C.textoSuave, Text = izquierda })
	local valor = Estilo.Texto(f, {
		Position = UDim2.fromScale(0.55, 0),
		Size = UDim2.new(0.45, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Estilo.FUERTE,
		Text = derecha,
	})
	return f, valor
end

local function desplazable(padre, propiedades)
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 5
	s.ScrollBarImageColor3 = C.oroOscuro
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	for k, v in propiedades or {} do
		s[k] = v
	end
	s.Parent = padre
	return s
end

local function nivelBarra(padre, nombre, registro, maximo, orden)
	local f = Estilo.Marco(padre, { LayoutOrder = orden, Size = UDim2.new(1, -8, 0, 30), BackgroundTransparency = 1 })
	Estilo.Texto(f, { Size = UDim2.new(0.5, 0, 0, 16), Text = nombre, TextSize = 14 })
	Estilo.Texto(f, {
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0.5, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Estilo.FUERTE,
		TextColor3 = C.oro,
		TextSize = 14,
		Text = "Nv " .. registro.Nivel .. " / " .. maximo,
	})
	local _, relleno =
		Estilo.Barra(f, { Position = UDim2.fromOffset(0, 19), Size = UDim2.new(1, 0, 0, 6) }, C.oro, false)
	local necesaria = ProgresionConfig.ExpParaSubirOficio(registro.Nivel)
	relleno.Size =
		UDim2.fromScale(if registro.Nivel >= maximo then 1 else math.clamp(registro.Exp / necesaria, 0, 1), 1)
end

-- ===== PERSONAJE =====
constructores.Personaje = function(padre)
	local d = datos()
	if not d then
		Estilo.Texto(padre, { Size = UDim2.fromScale(1, 1), Text = "Cargando tu personaje..." })
		return
	end
	local izquierda = Estilo.Marco(padre, { Size = UDim2.new(0.46, 0, 1, 0), BackgroundTransparency = 1 })
	Estilo.Lista(izquierda, 4)
	Estilo.Texto(
		izquierda,
		{ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 40), Font = Estilo.TITULO, TextSize = 34, Text = d.Nombre }
	)
	Estilo.Texto(izquierda, {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = C.oro,
		Font = Estilo.FUERTE,
		Text = "Nivel " .. d.Nivel .. "   ·   Puntos libres: " .. d.PuntosLibres,
	})
	local necesaria = ProgresionConfig.ExpParaSubir(d.Nivel)
	local _, relleno, texto = Estilo.Barra(izquierda, { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 16) }, C.exp, true)
	relleno.Size = UDim2.fromScale(math.clamp(d.Experiencia / necesaria, 0, 1), 1)
	texto.Text = string.format("EXP  %d / %d", d.Experiencia, necesaria)
	Estilo.Marco(izquierda, { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 8), BackgroundTransparency = 1 })
	local function nada(valor)
		return if valor == "Ninguna" or valor == "" then "Sin elegir" else valor
	end
	fila(izquierda, "Clase", nada(d.Clase), 5)
	fila(izquierda, "Subclase", nada(d.Subclase), 6)
	local raza = RazasConfig.RAZA_POR_ID[d.Raza]
	local afinidad = RazasConfig.AFINIDAD_POR_ID[d.AfinidadMagica or ""]
	fila(izquierda, "Raza", if raza then raza.nombre else nada(d.Raza), 7)
	fila(izquierda, "Afinidad mágica", if afinidad then afinidad.nombre else "Sin elegir", 7)
	fila(izquierda, "Oro", tostring(d.Oro), 8)
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart")
	local region = raiz and RegionesConfig.RegionEn(raiz.Position)
	local datosRegion = region and RegionesConfig.REGIONES[region]
	fila(izquierda, "Ubicación", datosRegion and datosRegion.nombre or "—", 9)
	local minutos = math.floor((d.Registro and d.Registro.TiempoJugado or 0) / 60)
	fila(izquierda, "Tiempo jugado", string.format("%d h %02d min", minutos // 60, minutos % 60), 10)
	local equipo = d.Equipo or {}
	fila(izquierda, "Arma equipada", if (equipo.Arma1 or "") == "" then "Sin armas" else equipo.Arma1, 11)
	Estilo.Texto(izquierda, {
		LayoutOrder = 12,
		Size = UDim2.new(1, 0, 0, 44),
		TextWrapped = true,
		TextSize = 12,
		TextColor3 = C.textoSuave,
		Text = "La raza y la afinidad mágica se giran en Personalizar (pantalla de inicio). La clase y la subclase llegarán en un próximo paso.",
	})

	local derecha = desplazable(padre, { Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0.5, 0, 1, 0) })
	Estilo.Lista(derecha, 4)
	seccion(derecha, "Maestrías", 1)
	for i, arma in Constantes.ARMAS do
		local registro = d.Maestrias[arma]
		if registro then
			nivelBarra(derecha, Estilo.NOMBRES_ARMAS[arma] or arma, registro, ProgresionConfig.MAESTRIA_MAXIMA, 1 + i)
		end
	end
	seccion(derecha, "Afinidades", 30)
	for i, elemento in ProgresionConfig.ELEMENTOS do
		local registro = d.Afinidades[elemento]
		if registro then
			nivelBarra(derecha, elemento, registro, ProgresionConfig.AFINIDAD_MAXIMA, 30 + i)
		end
	end
	seccion(derecha, "Profesiones", 50)
	for i, profesion in ProgresionConfig.PROFESIONES do
		local registro = d.Profesiones[profesion]
		if registro then
			nivelBarra(
				derecha,
				Estilo.NOMBRES_PROFESIONES[profesion] or profesion,
				registro,
				ProgresionConfig.PROFESION_MAXIMA,
				50 + i
			)
		end
	end
	seccion(derecha, "Dominio de clase", 70)
	local hayDominio = false
	for clase, registro in d.DominioClase or {} do
		hayDominio = true
		nivelBarra(derecha, clase, registro, ProgresionConfig.DOMINIO_MAXIMO, 71)
	end
	if not hayDominio then
		Estilo.Texto(derecha, {
			LayoutOrder = 71,
			Size = UDim2.new(1, 0, 0, 20),
			TextSize = 13,
			TextColor3 = C.textoSuave,
			Text = "Aún no tienes clase.",
		})
	end
end

-- ===== ESTADÍSTICAS (repartir puntos) =====
local pendientes = {}
constructores["Estadísticas"] = function(padre)
	local d = datos()
	if not d then
		return
	end
	local gastados = 0
	for _, n in pendientes do
		gastados += n
	end
	if gastados > d.PuntosLibres then
		pendientes, gastados = {}, 0
	end
	local libres = d.PuntosLibres - gastados

	local izquierda = Estilo.Marco(padre, { Size = UDim2.new(0.58, 0, 1, 0), BackgroundTransparency = 1 })
	Estilo.Lista(izquierda, 8)
	Estilo.Texto(izquierda, {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 28),
		Font = Estilo.FUERTE,
		TextSize = 18,
		TextColor3 = if libres > 0 then C.verde else C.textoSuave,
		Text = "Puntos para repartir: " .. libres,
	})
	for i, atributo in Constantes.ATRIBUTOS do
		local info = Estilo.ATRIBUTOS[atributo]
		local f =
			Estilo.Marco(izquierda, { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = C.panelClaro })
		Estilo.Esquinas(f, 6)
		Estilo.Texto(f, {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.fromOffset(60, 26),
			Font = Estilo.TITULO,
			TextSize = 26,
			TextColor3 = C.oro,
			Text = atributo,
		})
		Estilo.Texto(f, {
			Position = UDim2.fromOffset(74, 7),
			Size = UDim2.fromOffset(200, 18),
			Font = Estilo.FUERTE,
			TextSize = 15,
			Text = info.nombre,
		})
		Estilo.Texto(f, {
			Position = UDim2.fromOffset(74, 27),
			Size = UDim2.new(1, -230, 0, 24),
			TextSize = 11,
			TextWrapped = true,
			TextColor3 = C.textoSuave,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = info.texto,
		})
		local extra = pendientes[atributo] or 0
		Estilo.Texto(f, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -86, 0, 14),
			Size = UDim2.fromOffset(70, 28),
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = Estilo.FUERTE,
			TextSize = 20,
			RichText = true,
			Text = tostring(d.Atributos[atributo])
				.. (if extra > 0 then " <font color='#78D278'>+" .. extra .. "</font>" else ""),
		})
		local menos = Estilo.Boton(f, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -46, 0.5, 0),
			Size = UDim2.fromOffset(32, 32),
			Text = "−",
			TextSize = 20,
		})
		local mas = Estilo.Boton(f, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(32, 32),
			Text = "+",
			TextSize = 20,
			BackgroundColor3 = if libres > 0 then C.oroOscuro else C.panelClaro,
		})
		menos.MouseButton1Click:Connect(function()
			if (pendientes[atributo] or 0) > 0 then
				pendientes[atributo] -= 1
				mostrar("Estadísticas")
			end
		end)
		mas.MouseButton1Click:Connect(function()
			if libres > 0 then
				pendientes[atributo] = (pendientes[atributo] or 0) + 1
				mostrar("Estadísticas")
			end
		end)
	end
	local botones =
		Estilo.Marco(izquierda, { LayoutOrder = 20, Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 })
	local confirmar = Estilo.Boton(botones, {
		Size = UDim2.new(0.5, -5, 1, 0),
		Text = "Confirmar",
		BackgroundColor3 = if gastados > 0 then Color3.fromRGB(70, 130, 70) else C.panelClaro,
	})
	local deshacer = Estilo.Boton(
		botones,
		{ Position = UDim2.new(0.5, 5, 0, 0), Size = UDim2.new(0.5, -5, 1, 0), Text = "Deshacer" }
	)
	confirmar.MouseButton1Click:Connect(function()
		if gastados > 0 then
			RemoteRepartir:FireServer(pendientes)
			pendientes = {}
			confirmar.Text = "Enviando..."
		end
	end)
	deshacer.MouseButton1Click:Connect(function()
		pendientes = {}
		mostrar("Estadísticas")
	end)

	-- valores calculados (actual -> con los puntos pendientes)
	local nuevos = table.clone(d.Atributos)
	for atributo, n in pendientes do
		nuevos[atributo] += n
	end
	local antes = Formulas.Calcular(d.Atributos)
	local despues = Formulas.Calcular(nuevos)
	local derecha = Estilo.Marco(
		padre,
		{ Position = UDim2.fromScale(0.62, 0), Size = UDim2.new(0.38, 0, 1, 0), BackgroundTransparency = 1 }
	)
	Estilo.Lista(derecha, 2)
	seccion(derecha, "Valores", 0)
	local function linea(nombre, a, b, formato, orden)
		local texto = string.format(formato, a)
		if math.abs(b - a) > 1e-6 then
			texto = texto .. "  →  " .. string.format(formato, b)
		end
		local _, valor = fila(derecha, nombre, texto, orden)
		if math.abs(b - a) > 1e-6 then
			valor.TextColor3 = C.verde
		end
	end
	linea("Vida máxima", antes.VidaMax, despues.VidaMax, "%d", 1)
	linea("Estamina máxima", antes.EstaminaMax, despues.EstaminaMax, "%d", 2)
	linea("Maná máximo", antes.ManaMax, despues.ManaMax, "%d", 3)
	linea("Defensa", antes.Defensa, despues.Defensa, "%d", 4)
	linea("Daño evitado", antes.ReduccionDano * 100, despues.ReduccionDano * 100, "%.1f %%", 5)
	linea("Crítico", antes.Critico * 100, despues.Critico * 100, "%.1f %%", 6)
	linea("Velocidad", antes.MultVelocidad * 100, despues.MultVelocidad * 100, "%.0f %%", 7)
	linea("Vel. de golpe", antes.VelocidadAtaque * 100, despues.VelocidadAtaque * 100, "%.0f %%", 8)
	linea(
		"Daño Sin armas",
		Formulas.EscaladoArma("SinArmas", d.Atributos) * 100,
		Formulas.EscaladoArma("SinArmas", nuevos) * 100,
		"%.0f %%",
		9
	)
	linea("Daño mágico", antes.DanoMagico * 100, despues.DanoMagico * 100, "%.0f %%", 10)
	Estilo.Texto(derecha, {
		LayoutOrder = 20,
		Size = UDim2.new(1, 0, 0, 60),
		TextWrapped = true,
		TextSize = 12,
		TextColor3 = C.textoSuave,
		Text = "Ganas "
			.. ProgresionConfig.PUNTOS_POR_NIVEL
			.. " puntos cada vez que subes de nivel. El servidor comprueba cada reparto.",
	})
end

-- ===== MOCHILA =====
local categoriaMochila = "Armas"
constructores.Mochila = function(padre)
	local d = datos()
	if not d then
		return
	end
	local barra = Estilo.Marco(padre, { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1 })
	local lista = Instance.new("UIListLayout")
	lista.FillDirection = Enum.FillDirection.Horizontal
	lista.Padding = UDim.new(0, 6)
	lista.Parent = barra
	for i, categoria in { "Armas", "Armaduras", "Materiales", "Consumibles", "Monturas" } do
		local b = Estilo.Boton(barra, {
			LayoutOrder = i,
			Size = UDim2.fromOffset(128, 34),
			Text = categoria,
			BackgroundColor3 = if categoria == categoriaMochila then C.oroOscuro else C.panelClaro,
		})
		b.MouseButton1Click:Connect(function()
			categoriaMochila = categoria
			mostrar("Mochila")
		end)
	end
	local rejilla = desplazable(padre, { Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 1, -46) })
	local disposicion = Instance.new("UIGridLayout")
	disposicion.CellSize = UDim2.fromOffset(112, 112)
	disposicion.CellPadding = UDim2.fromOffset(10, 10)
	disposicion.Parent = rejilla
	local objetos = d.Inventario[categoriaMochila] or {}
	local cuantos = 0
	local function casilla(nombre, detalle, color)
		cuantos += 1
		local c = Estilo.Marco(rejilla, { BackgroundColor3 = C.panelClaro })
		Estilo.Esquinas(c, 8)
		Estilo.Borde(c, color or C.borde, 2)
		Estilo.Texto(c, {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 0, 60),
			TextWrapped = true,
			Font = Estilo.FUERTE,
			TextSize = 13,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = nombre,
		})
		Estilo.Texto(c, {
			Position = UDim2.new(0, 8, 1, -24),
			Size = UDim2.new(1, -16, 0, 18),
			TextSize = 12,
			TextColor3 = color or C.textoSuave,
			Text = detalle,
		})
	end
	if #objetos > 0 then
		for _, objeto in objetos do
			casilla(
				objeto.Id or "?",
				(objeto.Rareza or "Comun") .. (if (objeto.Mejora or 0) > 0 then "  +" .. objeto.Mejora else ""),
				Estilo.RAREZAS[objeto.Rareza or "Comun"]
			)
		end
	else
		for id, cantidad in objetos do
			casilla(tostring(id), "x" .. tostring(cantidad), nil)
		end
	end
	if cuantos == 0 then
		Estilo.Texto(
			padre, -- fuera de la rejilla, para que no lo encoja a una casilla
			{
				Position = UDim2.fromOffset(4, 56),
				Size = UDim2.new(1, -8, 0, 60),
				TextYAlignment = Enum.TextYAlignment.Top,
				TextWrapped = true,
				TextColor3 = C.textoSuave,
				Text = "No tienes "
					.. string.lower(categoriaMochila)
					.. " todavía.\nLos conseguirás derrotando enemigos, en misiones y en las tiendas de los pueblos.",
			}
		)
	end
end

-- ===== MAPA =====
local COLORES_REGION = {
	Bosque = Color3.fromRGB(78, 120, 62),
	Desierto = Color3.fromRGB(196, 160, 104),
	Oscuro = Color3.fromRGB(44, 66, 62),
	Montana = Color3.fromRGB(150, 152, 160),
}
local AGUAS = { { Vector2.new(10, 830), 150 }, { Vector2.new(660, 240), 60 }, { Vector2.new(-680, 260), 110 } }

constructores.Mapa = function(padre)
	local LADO = 500
	local mapa = Estilo.Marco(
		padre,
		{ Size = UDim2.fromOffset(LADO, LADO), BackgroundColor3 = Color3.fromRGB(20, 30, 40), ClipsDescendants = true }
	)
	Estilo.Esquinas(mapa, 6)
	Estilo.Borde(mapa, C.oroOscuro, 2)
	local mitad = RegionesConfig.MITAD
	local function aMapa(x, z)
		return UDim2.fromOffset((x + mitad) / (2 * mitad) * LADO, (z + mitad) / (2 * mitad) * LADO)
	end
	-- regiones (cuadrícula coloreada)
	local celdas = 30
	local tam = LADO / celdas
	for i = 0, celdas - 1 do
		for j = 0, celdas - 1 do
			local x = -mitad + (i + 0.5) * (2 * mitad / celdas)
			local z = -mitad + (j + 0.5) * (2 * mitad / celdas)
			local region = RegionesConfig.RegionEn(Vector3.new(x, 0, z))
			local borde = math.max(math.abs(x), math.abs(z)) > mitad - 150
			local color = COLORES_REGION[region] or COLORES_REGION.Bosque
			if borde then
				color = color:Lerp(Color3.fromRGB(120, 120, 128), 0.6)
			end
			Estilo.Marco(mapa, {
				Position = UDim2.fromOffset(i * tam, j * tam),
				Size = UDim2.fromOffset(tam + 1, tam + 1),
				BackgroundColor3 = color,
			})
		end
	end
	for _, agua in AGUAS do
		local centro, radio = agua[1], agua[2]
		local diametro = radio * 2 / (2 * mitad) * LADO
		local a = Estilo.Marco(mapa, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = aMapa(centro.X, centro.Y),
			Size = UDim2.fromOffset(diametro, diametro * 0.75),
			BackgroundColor3 = Color3.fromRGB(60, 110, 150),
			BackgroundTransparency = 0.15,
		})
		Estilo.Esquinas(a, 100)
	end
	-- lugares importantes
	local function marca(posicion, texto, color, tamano)
		local m = Estilo.Marco(mapa, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = aMapa(posicion.X, posicion.Y),
			Size = UDim2.fromOffset(tamano, tamano),
			BackgroundColor3 = color,
			Rotation = 45,
			ZIndex = 3,
		})
		Estilo.Borde(m, Color3.new(0, 0, 0), 1)
		local t = Estilo.Texto(mapa, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = aMapa(posicion.X, posicion.Y) + UDim2.fromOffset(0, tamano * 0.7),
			Size = UDim2.fromOffset(140, 14),
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Estilo.FUERTE,
			TextSize = 11,
			TextStrokeTransparency = 0.2,
			Text = texto,
			ZIndex = 3,
		})
		return m, t
	end
	local mundo = Workspace:FindFirstChild("Mundo")
	local pueblos = mundo and mundo:FindFirstChild("Pueblos")
	if pueblos then
		for _, pueblo in pueblos:GetChildren() do
			local centro = pueblo:GetAttribute("Centro")
			if centro then
				local capital = pueblo:GetAttribute("Tipo") == "Capital"
				marca(
					Vector2.new(centro.X, centro.Z),
					pueblo:GetAttribute("Nombre") or pueblo.Name,
					if capital then C.oro else Color3.fromRGB(230, 220, 200),
					if capital then 12 else 8
				)
			end
		end
	end
	marca(RegionesConfig.INICIO, "Inicio", Color3.fromRGB(120, 200, 255), 8)
	marca(RegionesConfig.ALTAR, "Altar del Ascenso", Color3.fromRGB(200, 140, 255), 10)
	-- yo (flecha)
	local yo = Estilo.Marco(mapa, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.fromRGB(255, 70, 60),
		ZIndex = 5,
	})
	Estilo.Esquinas(yo, 3)
	Estilo.Borde(yo, Color3.new(1, 1, 1), 2)
	local punta = Estilo.Marco(yo, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(4, 9),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 5,
	})
	local _ = punta
	local conexion = RunService.RenderStepped:Connect(function()
		local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart")
		if raiz then
			yo.Position = aMapa(raiz.Position.X, raiz.Position.Z)
			local frente = raiz.CFrame.LookVector
			yo.Rotation = math.deg(math.atan2(frente.X, -frente.Z))
		end
	end)
	table.insert(limpiezas, function()
		conexion:Disconnect()
	end)
	-- leyenda
	local leyenda = Estilo.Marco(
		padre,
		{ Position = UDim2.fromOffset(LADO + 18, 0), Size = UDim2.new(1, -LADO - 18, 1, 0), BackgroundTransparency = 1 }
	)
	Estilo.Lista(leyenda, 6)
	seccion(leyenda, "Regiones", 0)
	for i, id in { "Bosque", "Desierto", "Oscuro", "Montana" } do
		local f = Estilo.Marco(leyenda, { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1 })
		Estilo.Esquinas(
			Estilo.Marco(f, {
				Size = UDim2.fromOffset(16, 16),
				Position = UDim2.fromOffset(0, 3),
				BackgroundColor3 = COLORES_REGION[id],
			}),
			3
		)
		Estilo.Texto(f, {
			Position = UDim2.fromOffset(24, 0),
			Size = UDim2.new(1, -24, 1, 0),
			TextSize = 13,
			Text = RegionesConfig.REGIONES[id].nombre,
		})
	end
	Estilo.Texto(leyenda, {
		LayoutOrder = 10,
		Size = UDim2.new(1, 0, 0, 120),
		TextWrapped = true,
		TextSize = 12,
		TextColor3 = C.textoSuave,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "Rombos dorados: capitales.\nRombos claros: aldeas.\nRojo: tú.\n\nPróximamente: niebla en las zonas sin descubrir, misiones, jefes y eventos.",
	})
end

-- ===== HABILIDADES =====
constructores.Habilidades = function(padre)
	local d = datos()
	local maestria = d and d.Maestrias.SinArmas and d.Maestrias.SinArmas.Nivel or 0
	local lista = desplazable(padre, { Size = UDim2.fromScale(1, 1) })
	Estilo.Lista(lista, 8)
	seccion(lista, "Sin armas  ·  Maestría " .. maestria, 0)
	local tecnicas = {
		{ "Combo de artes marciales", "Clic: jab, directo, gancho, patada circular y uppercut.", 0, true },
		{ "Golpe cargado", "Mantén el clic para cargar Ki y suelta un puñetazo enorme.", 0, true },
		{ "Técnica Q", "Se construye en el paso 2.8 (aura y técnicas).", 1, false },
		{ "Técnica E", "Se construye en el paso 2.8.", 5, false },
		{ "Técnica R", "Se construye en el paso 2.8.", 10, false },
		{ "Técnica F", "Se construye en el paso 2.8.", 20, false },
		{ "Ultimate", "Se construye en el paso 2.8.", 30, false },
	}
	for i, t in tecnicas do
		local disponible = t[4]
		local f =
			Estilo.Marco(lista, { LayoutOrder = i, Size = UDim2.new(1, -8, 0, 54), BackgroundColor3 = C.panelClaro })
		Estilo.Esquinas(f, 6)
		Estilo.Borde(f, if disponible then C.oro else C.borde, 1, if disponible then 0 else 0.5)
		Estilo.Texto(f, {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -150, 0, 20),
			Font = Estilo.FUERTE,
			TextColor3 = if disponible then C.texto else C.textoSuave,
			Text = t[1],
		})
		Estilo.Texto(f, {
			Position = UDim2.fromOffset(12, 28),
			Size = UDim2.new(1, -150, 0, 18),
			TextSize = 12,
			TextColor3 = C.textoSuave,
			Text = t[2],
		})
		Estilo.Texto(f, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(130, 20),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextSize = 12,
			TextColor3 = if disponible then C.verde else C.textoSuave,
			Text = if disponible then "Disponible" else "Maestría " .. t[3],
		})
	end
	seccion(lista, "Talentos", 20)
	Estilo.Texto(lista, {
		LayoutOrder = 21,
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 13,
		TextColor3 = C.textoSuave,
		Text = "Puntos de talento: " .. (d and d.Talentos.Puntos or 0) .. "  ·  El árbol general llega en el paso 4.",
	})
end

-- ===== TIENDA =====
constructores.Tienda = function(padre)
	Estilo.Texto(padre, {
		Size = UDim2.fromScale(1, 1),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "Las tiendas están en los pueblos: acércate a un tendero y pulsa "
			.. Controles.Nombre("Interactuar")
			.. " para ver lo que vende.\n\nLa compra con oro (guardada en tu mochila) llega en un próximo paso.",
	})
end

-- ===== MISIONES =====
constructores.Misiones = function(padre)
	local d = datos()
	local h = d and d.Historia or { Mision = 1, Textos = {} }
	local lista = desplazable(padre, { Size = UDim2.fromScale(1, 1) })
	Estilo.Lista(lista, 8)
	local orden = 0
	local function n()
		orden += 1
		return orden
	end
	local function parrafo(texto, color, tamano)
		return Estilo.Texto(lista, {
			LayoutOrder = n(),
			Size = UDim2.new(1, -10, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = tamano or 14,
			TextColor3 = color or C.texto,
			Text = texto,
		})
	end

	-- misión actual
	seccion(lista, HistoriaConfig.ACTO, n())
	local mision = HistoriaConfig.Mision(h.Mision)
	local tarjeta = Estilo.Marco(
		lista,
		{
			LayoutOrder = n(),
			Size = UDim2.new(1, -10, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = C.panelClaro,
		}
	)
	Estilo.Esquinas(tarjeta, 8)
	Estilo.Borde(tarjeta, C.oro, 1, 0.3)
	Estilo.Relleno(tarjeta, 12)
	Estilo.Lista(tarjeta, 4)
	if mision then
		Estilo.Texto(
			tarjeta,
			{
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 14),
				TextSize = 11,
				Font = Estilo.FUERTE,
				TextColor3 = Color3.fromRGB(190, 150, 255),
				Text = "MISIÓN " .. h.Mision .. " DE " .. #HistoriaConfig.MISIONES,
			}
		)
		Estilo.Texto(
			tarjeta,
			{
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 28),
				Font = Estilo.TITULO,
				TextSize = 26,
				TextColor3 = C.oro,
				Text = mision.titulo,
			}
		)
		Estilo.Texto(
			tarjeta,
			{
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextWrapped = true,
				TextSize = 14,
				TextColor3 = C.textoSuave,
				Text = mision.descripcion,
			}
		)
		local progreso = if mision.objetivo.tipo == "Golpes"
			then string.format(
				" (%d/%d)",
				math.min(h.Progreso or 0, mision.objetivo.cantidad),
				mision.objetivo.cantidad
			)
			else ""
		Estilo.Texto(
			tarjeta,
			{
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 20),
				Font = Estilo.FUERTE,
				TextSize = 14,
				Text = "◆  " .. mision.objetivo.texto .. progreso,
			}
		)
	else
		Estilo.Texto(
			tarjeta,
			{
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 28),
				Font = Estilo.TITULO,
				TextSize = 26,
				TextColor3 = C.oro,
				Text = "Fin del Acto I",
			}
		)
		Estilo.Texto(
			tarjeta,
			{
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 20),
				TextSize = 14,
				TextColor3 = C.textoSuave,
				Text = "La historia continúa en las próximas actualizaciones.",
			}
		)
	end

	-- completadas
	if h.Mision > 1 then
		seccion(lista, "Completadas", n())
		for i = 1, math.min(h.Mision - 1, #HistoriaConfig.MISIONES) do
			parrafo("✓  " .. HistoriaConfig.MISIONES[i].titulo, C.verde)
		end
	end

	-- crónicas: los textos antiguos que ya has leído
	seccion(lista, "Crónicas", n())
	local leidos = 0
	for id, texto in HistoriaConfig.TEXTOS do
		if h.Textos and h.Textos[id] then
			leidos += 1
			local b = Estilo.Boton(
				lista,
				{ LayoutOrder = n(), Size = UDim2.new(1, -10, 0, 40), Text = "", BackgroundColor3 = C.panel }
			)
			Estilo.Borde(b, C.borde, 1)
			Estilo.Texto(
				b,
				{
					Position = UDim2.fromOffset(12, 3),
					Size = UDim2.new(1, -24, 0, 18),
					Font = Estilo.FUERTE,
					TextSize = 14,
					TextColor3 = C.oro,
					Text = texto.titulo,
				}
			)
			Estilo.Texto(
				b,
				{
					Position = UDim2.fromOffset(12, 21),
					Size = UDim2.new(1, -24, 0, 14),
					TextSize = 11,
					TextColor3 = C.textoSuave,
					Text = texto.subtitulo or "",
				}
			)
			b.MouseButton1Click:Connect(function()
				Pergamino.Abrir(id, false)
			end)
		end
	end
	local total = 0
	for _ in HistoriaConfig.TEXTOS do
		total += 1
	end
	parrafo(
		string.format(
			"Textos encontrados: %d de %d. Búscalos en los santuarios de los Guardianes y en el Altar del Ascenso.",
			leidos,
			total
		),
		C.textoSuave,
		12
	)
end

-- ===== AJUSTES (teclas) =====
local esperandoTecla = nil -- acción que espera una tecla nueva
constructores.Ajustes = function(padre)
	local lista = desplazable(padre, { Size = UDim2.new(1, 0, 1, -50) })
	Estilo.Lista(lista, 6)
	seccion(lista, "Controles", 0)
	for i, accion in ControlesConfig.ORDEN do
		local datosAccion = ControlesConfig.ACCIONES[accion]
		local f =
			Estilo.Marco(lista, { LayoutOrder = i, Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = C.panelClaro })
		Estilo.Esquinas(f, 6)
		Estilo.Texto(
			f,
			{ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -200, 1, 0), Text = datosAccion.nombre }
		)
		local boton = Estilo.Boton(f, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(170, 30),
			Text = if esperandoTecla == accion then "Pulsa una tecla..." else Controles.Nombre(accion),
			BackgroundColor3 = if esperandoTecla == accion then C.oroOscuro else C.panel,
		})
		Estilo.Borde(boton, C.borde, 1)
		boton.MouseButton1Click:Connect(function()
			task.defer(function()
				esperandoTecla = accion
				mostrar("Ajustes")
			end)
		end)
	end
	local pie = Estilo.Marco(
		padre,
		{ Position = UDim2.new(0, 0, 1, -40), Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 }
	)
	local restablecer = Estilo.Boton(pie, { Size = UDim2.fromOffset(220, 36), Text = "Restablecer teclas" })
	Estilo.Texto(pie, {
		Position = UDim2.fromOffset(236, 0),
		Size = UDim2.new(1, -236, 1, 0),
		TextWrapped = true,
		TextSize = 12,
		TextColor3 = C.textoSuave,
		Text = "Pulsa un botón y luego la tecla nueva. Si ya estaba usada, se intercambian. Se guarda en tu personaje.",
	})
	restablecer.MouseButton1Click:Connect(function()
		Controles.Restablecer()
		RemoteTeclas:FireServer({})
		mostrar("Ajustes")
	end)
end

local function capturarTecla(entrada)
	local accion = esperandoTecla
	local nombre = nil
	local tipo = entrada.UserInputType
	if tipo == Enum.UserInputType.Keyboard then
		if entrada.KeyCode == Enum.KeyCode.Escape then
			esperandoTecla = nil
			mostrar("Ajustes")
			return
		end
		nombre = entrada.KeyCode.Name
	elseif
		tipo == Enum.UserInputType.MouseButton1
		or tipo == Enum.UserInputType.MouseButton2
		or tipo == Enum.UserInputType.MouseButton3
	then
		nombre = tipo.Name
	else
		return
	end
	esperandoTecla = nil
	if Controles.Asignar(accion, nombre) then
		RemoteTeclas:FireServer(Controles.Personalizadas())
		mostrar("Ajustes")
	else
		mostrar("Ajustes")
		Estilo.Texto(contenido, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, 0, 1, -44),
			Size = UDim2.fromOffset(400, 20),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = C.rojo,
			Text = "Esa tecla no se puede usar para eso.",
		})
	end
end

-- ===== Abrir y cerrar =====
local abierto = false
local function abrir(si)
	abierto = si
	esperandoTecla = nil
	Players.LocalPlayer:SetAttribute("MenuAbierto", si) -- el Shift Lock se suspende con el menú
	if si then
		local d = datos()
		subtitulo.Text = if d then d.Nombre .. "  ·  Nivel " .. d.Nivel .. "  ·  " .. d.Oro .. " de oro" else ""
		pantalla.Enabled = true
		escala.Scale *= 0.94
		TweenService:Create(
			escala,
			TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = escala.Scale / 0.94 }
		):Play()
		mostrar(pestanaActual)
	else
		limpiar()
		pantalla.Enabled = false
		ajustarEscala()
	end
end

cerrar.MouseButton1Click:Connect(function()
	abrir(false)
end)

UserInputService.InputBegan:Connect(function(entrada, procesado)
	if game:GetService("Players").LocalPlayer:GetAttribute("EnMenu") then
		return -- en la pantalla de inicio no se juega
	end
	if abierto and esperandoTecla then
		capturarTecla(entrada)
		return
	end
	if abierto and entrada.KeyCode == Enum.KeyCode.Escape then
		abrir(false)
		return
	end
	if UserInputService:GetFocusedTextBox() then
		return -- escribiendo en el chat
	end
	if Controles.Es("Menu", entrada) and (not procesado or abierto) then
		abrir(not abierto)
	end
end)

-- Si cambian los datos con el menú abierto, se redibuja la pestaña
DatosLocal.Cambio:Connect(function(d)
	if abierto then
		subtitulo.Text = d.Nombre .. "  ·  Nivel " .. d.Nivel .. "  ·  " .. d.Oro .. " de oro"
		if pestanaActual ~= "Mapa" and not esperandoTecla then
			mostrar(pestanaActual)
		end
	end
end)

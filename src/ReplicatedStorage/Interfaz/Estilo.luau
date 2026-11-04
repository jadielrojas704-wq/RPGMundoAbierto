-- Estilo común de la interfaz (colores, fuentes y piezas reutilizables). Solo CLIENTE.
-- Ruta en Studio: ReplicatedStorage/Interfaz/Estilo
-- Lo usan StarterPlayerScripts/HUD y StarterPlayerScripts/MenuM.

local Estilo = {}

Estilo.COLORES = {
	fondo = Color3.fromRGB(16, 14, 20),
	panel = Color3.fromRGB(26, 23, 31),
	panelClaro = Color3.fromRGB(38, 34, 44),
	borde = Color3.fromRGB(92, 76, 52),
	oro = Color3.fromRGB(228, 184, 96),
	oroOscuro = Color3.fromRGB(150, 112, 50),
	texto = Color3.fromRGB(238, 228, 208),
	textoSuave = Color3.fromRGB(160, 150, 136),
	vida = Color3.fromRGB(205, 52, 48),
	mana = Color3.fromRGB(70, 120, 230),
	estamina = Color3.fromRGB(96, 196, 104),
	exp = Color3.fromRGB(228, 184, 96),
	verde = Color3.fromRGB(120, 210, 120),
	rojo = Color3.fromRGB(230, 90, 80),
}

Estilo.RAREZAS = {
	Comun = Color3.fromRGB(170, 170, 170),
	PocoComun = Color3.fromRGB(90, 200, 100),
	Raro = Color3.fromRGB(70, 140, 240),
	Epico = Color3.fromRGB(170, 90, 230),
	Legendario = Color3.fromRGB(240, 180, 60),
	Mitico = Color3.fromRGB(230, 60, 60),
}

Estilo.TITULO = Enum.Font.Garamond
Estilo.FUERTE = Enum.Font.GothamBold
Estilo.NORMAL = Enum.Font.GothamMedium

function Estilo.Esquinas(objeto, radio)
	local e = Instance.new("UICorner")
	e.CornerRadius = UDim.new(0, radio or 6)
	e.Parent = objeto
	return e
end

function Estilo.Borde(objeto, color, grosor, transparencia)
	local b = Instance.new("UIStroke")
	b.Color = color or Estilo.COLORES.borde
	b.Thickness = grosor or 1
	b.Transparency = transparencia or 0
	b.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	b.Parent = objeto
	return b
end

function Estilo.Marco(padre, propiedades)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Estilo.COLORES.panel
	for k, v in propiedades or {} do
		f[k] = v
	end
	f.Parent = padre
	return f
end

function Estilo.Texto(padre, propiedades)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Estilo.NORMAL
	t.TextColor3 = Estilo.COLORES.texto
	t.TextSize = 15
	t.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in propiedades or {} do
		t[k] = v
	end
	t.Parent = padre
	return t
end

function Estilo.Boton(padre, propiedades)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BorderSizePixel = 0
	b.BackgroundColor3 = Estilo.COLORES.panelClaro
	b.Font = Estilo.FUERTE
	b.TextColor3 = Estilo.COLORES.texto
	b.TextSize = 15
	for k, v in propiedades or {} do
		b[k] = v
	end
	b.Parent = padre
	Estilo.Esquinas(b, 5)
	return b
end

-- Barra con relleno. Devuelve (fondo, relleno, texto)
function Estilo.Barra(padre, propiedades, color, conTexto)
	local fondo = Estilo.Marco(padre, propiedades)
	fondo.BackgroundColor3 = Color3.fromRGB(12, 10, 14)
	Estilo.Esquinas(fondo, 4)
	Estilo.Borde(fondo, Color3.fromRGB(0, 0, 0), 1, 0.3)
	local relleno = Estilo.Marco(fondo, { Name = "Relleno", Size = UDim2.fromScale(1, 1), BackgroundColor3 = color })
	Estilo.Esquinas(relleno, 4)
	local degradado = Instance.new("UIGradient")
	degradado.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
	degradado.Rotation = 90
	degradado.Parent = relleno
	local texto = nil
	if conTexto then
		texto = Estilo.Texto(fondo, {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Estilo.FUERTE,
			TextSize = 12,
			TextStrokeTransparency = 0.4,
			ZIndex = 3,
		})
	end
	return fondo, relleno, texto
end

function Estilo.Lista(padre, separacion)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, separacion or 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = padre
	return l
end

function Estilo.Relleno(padre, px)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = padre
	return p
end

-- Nombres bonitos
Estilo.NOMBRES_ARMAS = {
	SinArmas = "Sin armas",
	DobleDagas = "Doble daga",
	DobleEspadas = "Doble espada",
	Katana = "Katana",
	EspadaYEscudo = "Espada y escudo",
	Arco = "Arco",
	BastonMagico = "Bastón mágico",
	Lanza = "Lanza",
	Guadana = "Guadaña",
	Guantes = "Guantes de pelea",
}
Estilo.NOMBRES_PROFESIONES = { Herreria = "Herrería", Alquimia = "Alquimia", Mineria = "Minería", Encantamiento = "Encantamiento" }
Estilo.ATRIBUTOS = {
	VIT = { nombre = "Vitalidad", texto = "Más vida, estamina y defensa." },
	STR = { nombre = "Fuerza", texto = "Más daño con guadaña, espada y escudo, guantes y lanza." },
	DEX = { nombre = "Destreza", texto = "Más daño con dagas, katana, arco y sin armas; golpes más rápidos." },
	INT = { nombre = "Inteligencia", texto = "Más daño mágico y más maná." },
	LUK = { nombre = "Suerte", texto = "Más críticos, objetos raros y oro." },
	SPD = { nombre = "Velocidad", texto = "Más velocidad, estamina y su recuperación." },
}

return Estilo

-- HUD: vida, maná, estamina, nivel, experiencia, oro y ranuras de habilidades.
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/HUD
-- Solo DIBUJA lo que manda el servidor (atributos del jugador y su CharacterData).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Estilo = require(ReplicatedStorage:WaitForChild("Interfaz"):WaitForChild("Estilo"))
local DatosLocal = require(ReplicatedStorage:WaitForChild("Progresion"):WaitForChild("DatosLocal"))
local Controles = require(ReplicatedStorage:WaitForChild("Combate"):WaitForChild("Controles"))
local ProgresionConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ProgresionConfig"))

local jugador = Players.LocalPlayer
local C = Estilo.COLORES

local pantalla = Instance.new("ScreenGui")
pantalla.Name = "HUD"
pantalla.ResetOnSpawn = false
pantalla.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pantalla.Parent = jugador:WaitForChild("PlayerGui")
-- el HUD no se ve en la pantalla de inicio
local function verHUD()
	pantalla.Enabled = jugador:GetAttribute("EnMenu") ~= true
end
verHUD()
jugador:GetAttributeChangedSignal("EnMenu"):Connect(verHUD)

-- ===== Panel de abajo a la izquierda: nivel + barras =====
local panel = Estilo.Marco(pantalla, {
	Name = "Estado",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 18, 1, -22),
	Size = UDim2.fromOffset(330, 78),
	BackgroundTransparency = 1,
})

local medalla = Estilo.Marco(
	panel,
	{ Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(0, 8), BackgroundColor3 = C.fondo }
)
Estilo.Esquinas(medalla, 32)
Estilo.Borde(medalla, C.oro, 2)
local textoNivel = Estilo.Texto(
	medalla,
	{
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 12),
		Font = Estilo.TITULO,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.oro,
		Text = "1",
	}
)
Estilo.Texto(
	medalla,
	{
		Size = UDim2.new(1, 0, 0, 12),
		Position = UDim2.fromOffset(0, 41),
		Font = Estilo.FUERTE,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.textoSuave,
		Text = "NIVEL",
	}
)

local nombre = Estilo.Texto(
	panel,
	{
		Position = UDim2.fromOffset(76, 4),
		Size = UDim2.fromOffset(250, 18),
		Font = Estilo.FUERTE,
		TextSize = 15,
		TextStrokeTransparency = 0.5,
		Text = jugador.DisplayName,
	}
)
local _, rellenoVida, textoVida =
	Estilo.Barra(panel, { Position = UDim2.fromOffset(76, 25), Size = UDim2.fromOffset(250, 16) }, C.vida, true)
local _, rellenoMana, textoMana =
	Estilo.Barra(panel, { Position = UDim2.fromOffset(76, 45), Size = UDim2.fromOffset(250, 11) }, C.mana, true)
local _, rellenoEstamina =
	Estilo.Barra(panel, { Position = UDim2.fromOffset(76, 60), Size = UDim2.fromOffset(220, 8) }, C.estamina, false)
textoMana.TextSize = 10

-- ===== Barra de experiencia (abajo del todo) =====
local fondoExp, rellenoExp = Estilo.Barra(
	pantalla,
	{ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -36, 0, 5) },
	C.exp,
	false
)
local textoExp = Estilo.Texto(
	pantalla,
	{
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -11),
		Size = UDim2.fromOffset(240, 14),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 11,
		TextColor3 = C.textoSuave,
		TextStrokeTransparency = 0.6,
		Text = "",
	}
)
local _ = fondoExp

-- ===== Oro (arriba a la derecha) =====
local cajaOro = Estilo.Marco(
	pantalla,
	{
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 12),
		Size = UDim2.fromOffset(150, 34),
		BackgroundColor3 = C.fondo,
		BackgroundTransparency = 0.25,
	}
)
Estilo.Esquinas(cajaOro, 17)
Estilo.Borde(cajaOro, C.oroOscuro, 1)
local moneda = Estilo.Marco(
	cajaOro,
	{ Position = UDim2.fromOffset(7, 7), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = C.oro }
)
Estilo.Esquinas(moneda, 10)
Estilo.Borde(moneda, Color3.fromRGB(255, 230, 150), 1)
local textoOro = Estilo.Texto(
	cajaOro,
	{
		Position = UDim2.fromOffset(34, 0),
		Size = UDim2.new(1, -42, 1, 0),
		Font = Estilo.FUERTE,
		TextSize = 17,
		TextColor3 = C.oro,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "0",
	}
)

-- ===== Ranuras de habilidades (abajo en el centro) =====
local barraHabilidades = Estilo.Marco(
	pantalla,
	{
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.fromOffset(5 * 56 + 4 * 8, 56),
		BackgroundTransparency = 1,
	}
)
local disposicion = Instance.new("UIListLayout")
disposicion.FillDirection = Enum.FillDirection.Horizontal
disposicion.Padding = UDim.new(0, 8)
disposicion.Parent = barraHabilidades
local ranuras = {}
for i, accion in { "HabilidadQ", "HabilidadE", "HabilidadR", "HabilidadF", "Ultimate" } do
	local ranura = Estilo.Marco(
		barraHabilidades,
		{ LayoutOrder = i, Size = UDim2.fromOffset(56, 56), BackgroundColor3 = C.fondo, BackgroundTransparency = 0.2 }
	)
	Estilo.Esquinas(ranura, 8)
	Estilo.Borde(ranura, if accion == "Ultimate" then C.oro else C.borde, if accion == "Ultimate" then 2 else 1)
	local tecla = Estilo.Texto(
		ranura,
		{
			Position = UDim2.fromOffset(5, 3),
			Size = UDim2.fromOffset(46, 14),
			Font = Estilo.FUERTE,
			TextSize = 12,
			TextColor3 = C.oro,
			Text = "",
		}
	)
	Estilo.Texto(
		ranura,
		{
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, 0, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 10,
			TextColor3 = C.textoSuave,
			TextWrapped = true,
			Text = "Bloqueada",
		}
	)
	ranuras[accion] = tecla
end

local ayuda = Estilo.Texto(
	pantalla,
	{
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 52),
		Size = UDim2.fromOffset(260, 16),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 12,
		TextColor3 = C.textoSuave,
		TextStrokeTransparency = 0.6,
		Text = "",
	}
)

local function refrescarTeclas()
	for accion, etiqueta in ranuras do
		etiqueta.Text = Controles.Nombre(accion)
	end
	ayuda.Text = Controles.Nombre("Menu")
		.. ": menú   ·   "
		.. Controles.Nombre("Esquiva")
		.. ": esquivar   ·   "
		.. Controles.Nombre("FijarObjetivo")
		.. ": fijar"
end
refrescarTeclas()
Controles.Cambio:Connect(refrescarTeclas)

-- ===== Actualizar =====
local function poner(relleno, proporcion)
	relleno.Size = UDim2.fromScale(math.clamp(proporcion, 0, 1), 1)
end

local function refrescarDatos(datos)
	if not datos then
		return
	end
	textoNivel.Text = tostring(datos.Nivel)
	nombre.Text = datos.Nombre ~= "" and datos.Nombre or jugador.DisplayName
	local necesaria = ProgresionConfig.ExpParaSubir(datos.Nivel)
	if datos.Nivel >= ProgresionConfig.NIVEL_MAXIMO then
		poner(rellenoExp, 1)
		textoExp.Text = "Nivel máximo"
	else
		TweenService:Create(
			rellenoExp,
			TweenInfo.new(0.4),
			{ Size = UDim2.fromScale(math.clamp(datos.Experiencia / necesaria, 0, 1), 1) }
		):Play()
		textoExp.Text = string.format("EXP %d / %d", datos.Experiencia, necesaria)
	end
	textoOro.Text = tostring(datos.Oro)
end
DatosLocal.Cambio:Connect(refrescarDatos)
refrescarDatos(DatosLocal.Obtener())

local acumulado = 0
RunService.Heartbeat:Connect(function(dt)
	acumulado += dt
	if acumulado < 0.05 then
		return
	end
	acumulado = 0
	local personaje = jugador.Character
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	if humanoide then
		poner(rellenoVida, humanoide.Health / math.max(humanoide.MaxHealth, 1))
		textoVida.Text = string.format("%d / %d", math.ceil(humanoide.Health), humanoide.MaxHealth)
	end
	local mana, manaMax = jugador:GetAttribute("Mana") or 0, jugador:GetAttribute("ManaMax") or 100
	poner(rellenoMana, mana / math.max(manaMax, 1))
	textoMana.Text = string.format("%d / %d", math.floor(mana), manaMax)
	local estamina, estaminaMax = jugador:GetAttribute("Estamina") or 0, jugador:GetAttribute("EstaminaMax") or 100
	poner(rellenoEstamina, estamina / math.max(estaminaMax, 1))
	rellenoEstamina.BackgroundColor3 = if estamina / math.max(estaminaMax, 1) < 0.25
		then Color3.fromRGB(220, 170, 60)
		else C.estamina
end)

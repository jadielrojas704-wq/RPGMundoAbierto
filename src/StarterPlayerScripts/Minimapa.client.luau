-- MINIMAPA (solo CLIENTE): arriba a la derecha.
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/Minimapa (LocalScript)
--
--   * El terreno de verdad visto desde arriba (lo fotografía el servidor: ServerScriptService/Mundo/MapaServicio)
--   * Norte arriba, con la brújula N / E / S / O alrededor
--   * Tu flecha (gira con tu cámara) y el cono de lo que estás mirando
--   * Pueblos, santuarios de los Guardianes, el Altar del Ascenso y la cabaña de Eldren
--   * Otros jugadores (puntos azules)
--   * El PING de la misión (rombo dorado que late) si la estás rastreando (tecla T).
--     Si está lejos, se queda en el borde señalando hacia dónde ir, con la distancia.
--   * Debajo: el nombre de la región en la que estás.

local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Estilo = require(ReplicatedStorage:WaitForChild("Interfaz"):WaitForChild("Estilo"))
local Regiones = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("RegionesConfig"))
local HistoriaConfig = require(ReplicatedStorage.Config:WaitForChild("HistoriaConfig"))

local jugador = Players.LocalPlayer
local RemotoMapa = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Mapa")

-- ===== Ajustes =====
local DIAMETRO = 186 -- tamaño en pantalla (píxeles)
local RADIO_STUDS = 230 -- cuánto mundo se ve desde el centro hasta el borde
local ORO = Color3.fromRGB(228, 184, 96)
local ORO_OSCURO = Color3.fromRGB(120, 92, 46)
local NOCHE = Color3.fromRGB(16, 14, 20)

local escala = (DIAMETRO / 2) / RADIO_STUDS -- píxeles de pantalla por stud

-- ===== Interfaz =====
local pantalla = Instance.new("ScreenGui")
pantalla.Name = "Minimapa"
pantalla.ResetOnSpawn = false
pantalla.DisplayOrder = 5
pantalla.Parent = jugador:WaitForChild("PlayerGui")

local raizUI = Instance.new("Frame")
raizUI.Name = "Raiz"
raizUI.AnchorPoint = Vector2.new(1, 0)
raizUI.Position = UDim2.new(1, -26, 0, 126)
raizUI.Size = UDim2.fromOffset(DIAMETRO, DIAMETRO + 22)
raizUI.BackgroundTransparency = 1
raizUI.Parent = pantalla

-- marco exterior dorado (anillo)
local anillo = Instance.new("Frame")
anillo.AnchorPoint = Vector2.new(0.5, 0.5)
anillo.Position = UDim2.fromOffset(DIAMETRO / 2, DIAMETRO / 2)
anillo.Size = UDim2.fromOffset(DIAMETRO + 14, DIAMETRO + 14)
anillo.BackgroundColor3 = NOCHE
anillo.BackgroundTransparency = 0.25
anillo.Parent = raizUI
Instance.new("UICorner", anillo).CornerRadius = UDim.new(1, 0)
local trazo = Instance.new("UIStroke")
trazo.Color = ORO
trazo.Thickness = 2
trazo.Transparency = 0.15
trazo.Parent = anillo
local anilloInterior = Instance.new("Frame")
anilloInterior.AnchorPoint = Vector2.new(0.5, 0.5)
anilloInterior.Position = UDim2.fromScale(0.5, 0.5)
anilloInterior.Size = UDim2.fromOffset(DIAMETRO + 2, DIAMETRO + 2)
anilloInterior.BackgroundTransparency = 1
anilloInterior.Parent = anillo
Instance.new("UICorner", anilloInterior).CornerRadius = UDim.new(1, 0)
local trazo2 = Instance.new("UIStroke")
trazo2.Color = ORO_OSCURO
trazo2.Thickness = 1
trazo2.Parent = anilloInterior

-- el círculo del mapa
local circulo = Instance.new("Frame")
circulo.Name = "Mapa"
circulo.AnchorPoint = Vector2.new(0.5, 0.5)
circulo.Position = UDim2.fromOffset(DIAMETRO / 2, DIAMETRO / 2)
circulo.Size = UDim2.fromOffset(DIAMETRO, DIAMETRO)
circulo.BackgroundColor3 = Color3.fromRGB(34, 38, 34)
circulo.Parent = raizUI
Instance.new("UICorner", circulo).CornerRadius = UDim.new(1, 0)

-- la imagen del mundo: solo se enseña el trozo de alrededor del jugador (ImageRect),
-- y el UICorner la deja redonda. Así nada se sale del círculo.
local terreno = Instance.new("ImageLabel")
terreno.Name = "Terreno"
terreno.BackgroundTransparency = 1
terreno.Size = UDim2.fromScale(1, 1)
terreno.ResampleMode = Enum.ResamplerMode.Default
terreno.Parent = circulo
Instance.new("UICorner", terreno).CornerRadius = UDim.new(1, 0)
local pixelesMapa = 256 -- se cambia al recibir la imagen
local pixelesPorStud = pixelesMapa / Regiones.TAMANO

-- capa de lugares: cada icono se coloca respecto al jugador y se oculta si cae fuera
local capaLugares = Instance.new("Frame")
capaLugares.BackgroundTransparency = 1
capaLugares.Size = UDim2.fromScale(1, 1)
capaLugares.ZIndex = 3
capaLugares.Parent = circulo

-- un velo color pergamino para que el mapa parezca antiguo
local velo = Instance.new("Frame")
velo.Size = UDim2.fromScale(1, 1)
velo.BackgroundColor3 = Color3.fromRGB(40, 30, 20)
velo.BackgroundTransparency = 0.88 -- tono de pergamino viejo
velo.ZIndex = 4
velo.Parent = circulo
Instance.new("UICorner", velo).CornerRadius = UDim.new(1, 0)

-- cono de visión y flecha del jugador (en el centro, encima de todo).
-- Van dentro de un marco centrado en ti que gira: así el cono sale siempre desde tu flecha.
local giro = Instance.new("Frame")
giro.AnchorPoint = Vector2.new(0.5, 0.5)
giro.Position = UDim2.fromScale(0.5, 0.5)
giro.Size = UDim2.fromOffset(120, 120)
giro.BackgroundTransparency = 1
giro.ZIndex = 5
giro.Parent = circulo
local conoRelleno = Instance.new("Frame")
conoRelleno.AnchorPoint = Vector2.new(0.5, 1)
conoRelleno.Position = UDim2.fromScale(0.5, 0.5)
conoRelleno.Size = UDim2.fromOffset(46, 54)
conoRelleno.BackgroundColor3 = Color3.fromRGB(255, 240, 200)
conoRelleno.BackgroundTransparency = 0.82
conoRelleno.BorderSizePixel = 0
conoRelleno.ZIndex = 5
conoRelleno.Parent = giro
local degradadoCono = Instance.new("UIGradient")
degradadoCono.Rotation = -90
degradadoCono.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.2),
	NumberSequenceKeypoint.new(1, 1),
})
degradadoCono.Parent = conoRelleno

local flecha = Instance.new("Frame")
flecha.AnchorPoint = Vector2.new(0.5, 0.5)
flecha.Position = UDim2.fromScale(0.5, 0.5)
flecha.Size = UDim2.fromOffset(18, 18)
flecha.BackgroundTransparency = 1
flecha.ZIndex = 7
flecha.Parent = giro
-- la flecha: un rombo dorado (la punta) con una cola clara detrás
local punta = Instance.new("Frame")
punta.AnchorPoint = Vector2.new(0.5, 0.5)
punta.Position = UDim2.new(0.5, 0, 0.5, -2)
punta.Size = UDim2.fromOffset(11, 11)
punta.Rotation = 45
punta.BackgroundColor3 = ORO
punta.BorderSizePixel = 0
punta.ZIndex = 7
punta.Parent = flecha
local puntaBorde = Instance.new("UIStroke")
puntaBorde.Color = Color3.new(0, 0, 0)
puntaBorde.Thickness = 1.5
puntaBorde.Parent = punta
local cola = Instance.new("Frame")
cola.AnchorPoint = Vector2.new(0.5, 0)
cola.Position = UDim2.new(0.5, 0, 0.5, 1)
cola.Size = UDim2.fromOffset(4, 8)
cola.BackgroundColor3 = Color3.fromRGB(255, 250, 235)
cola.BorderSizePixel = 0
cola.ZIndex = 6
cola.Parent = flecha

-- ===== Brújula: N, E, S, O alrededor del anillo =====
local function letra(texto, angulo, principal)
	local r = DIAMETRO / 2 + 1
	local et = Instance.new("TextLabel")
	et.AnchorPoint = Vector2.new(0.5, 0.5)
	et.Position = UDim2.fromOffset(DIAMETRO / 2 + math.sin(angulo) * r, DIAMETRO / 2 - math.cos(angulo) * r)
	et.Size = UDim2.fromOffset(22, 22)
	et.BackgroundColor3 = NOCHE
	et.BackgroundTransparency = if principal then 0 else 0.15
	et.Font = Enum.Font.Garamond
	et.TextSize = if principal then 19 else 15
	et.TextColor3 = if principal then ORO else Color3.fromRGB(232, 222, 200)
	et.Text = texto
	et.ZIndex = 8
	et.Parent = raizUI
	Instance.new("UICorner", et).CornerRadius = UDim.new(1, 0)
	local b = Instance.new("UIStroke")
	b.Color = if principal then ORO else ORO_OSCURO
	b.Thickness = if principal then 1.6 else 1
	b.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	b.Parent = et
	return et
end
letra("N", 0, true)
letra("E", math.pi / 2)
letra("S", math.pi)
letra("O", -math.pi / 2)
-- marcas pequeñas entre las letras
for k = 0, 7 do
	if k % 2 == 1 then
		local a = k * math.pi / 4
		local m = Instance.new("Frame")
		m.AnchorPoint = Vector2.new(0.5, 0.5)
		m.Position = UDim2.fromOffset(DIAMETRO / 2 + math.sin(a) * (DIAMETRO / 2 + 2), DIAMETRO / 2 - math.cos(a) * (DIAMETRO / 2 + 2))
		m.Size = UDim2.fromOffset(5, 5)
		m.Rotation = 45
		m.BackgroundColor3 = ORO
		m.BorderSizePixel = 0
		m.ZIndex = 8
		m.Parent = raizUI
	end
end

-- nombre de la región, debajo
local textoRegion = Estilo.Texto(raizUI, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, DIAMETRO + 12),
	Size = UDim2.new(1, 40, 0, 16),
	TextXAlignment = Enum.TextXAlignment.Center,
	Font = Enum.Font.Garamond,
	TextSize = 16,
	TextColor3 = Color3.fromRGB(236, 226, 204),
	TextStrokeTransparency = 0.4,
	Text = "",
})
local textoObjetivo = Estilo.Texto(raizUI, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, DIAMETRO + 28),
	Size = UDim2.new(1, 40, 0, 14),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextSize = 12,
	TextColor3 = ORO,
	TextStrokeTransparency = 0.4,
	Text = "",
})

-- ===== Iconos =====
local function icono(tipo, color)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BorderSizePixel = 0
	f.ZIndex = 3
	local borde = Instance.new("UIStroke")
	borde.Color = Color3.new(0, 0, 0)
	borde.Thickness = 1.2
	borde.Transparency = 0.2
	borde.Parent = f
	if tipo == "Capital" then
		f.Size = UDim2.fromOffset(11, 11)
		f.Rotation = 45
		f.BackgroundColor3 = ORO
	elseif tipo == "Aldea" then
		f.Size = UDim2.fromOffset(8, 8)
		f.BackgroundColor3 = Color3.fromRGB(226, 206, 160)
		Instance.new("UICorner", f).CornerRadius = UDim.new(0, 2)
	elseif tipo == "Santuario" then
		f.Size = UDim2.fromOffset(10, 10)
		f.BackgroundColor3 = color or Color3.fromRGB(200, 200, 255)
		Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
		borde.Color = Color3.fromRGB(255, 255, 255)
		borde.Thickness = 1.4
	elseif tipo == "Altar" then
		f.Size = UDim2.fromOffset(12, 12)
		f.BackgroundColor3 = HistoriaConfig.COLOR_ECLIPSE
		Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
		borde.Color = Color3.fromRGB(230, 200, 255)
	elseif tipo == "Cabana" then
		f.Size = UDim2.fromOffset(8, 8)
		f.BackgroundColor3 = Color3.fromRGB(255, 170, 90)
		Instance.new("UICorner", f).CornerRadius = UDim.new(0, 2)
	else -- jugador
		f.Size = UDim2.fromOffset(7, 7)
		f.BackgroundColor3 = Color3.fromRGB(110, 180, 255)
		Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
		borde.Color = Color3.fromRGB(255, 255, 255)
		f.ZIndex = 6
	end
	return f
end

local mitad = Regiones.MITAD
local function aPixel(x, z)
	return (x + mitad) * escala, (z + mitad) * escala
end

-- ping de la misión
local ping = Instance.new("Frame")
ping.AnchorPoint = Vector2.new(0.5, 0.5)
ping.Size = UDim2.fromOffset(13, 13)
ping.Rotation = 45
ping.BackgroundColor3 = ORO
ping.BorderSizePixel = 0
ping.ZIndex = 9
ping.Visible = false
ping.Parent = raizUI
local pingBorde = Instance.new("UIStroke")
pingBorde.Color = Color3.new(0, 0, 0)
pingBorde.Thickness = 1.6
pingBorde.Parent = ping
local onda = Instance.new("Frame")
onda.AnchorPoint = Vector2.new(0.5, 0.5)
onda.Position = UDim2.fromScale(0.5, 0.5)
onda.Size = UDim2.fromScale(1, 1)
onda.BackgroundTransparency = 1
onda.ZIndex = 9
onda.Parent = ping
local ondaTrazo = Instance.new("UIStroke")
ondaTrazo.Color = ORO
ondaTrazo.Thickness = 2
ondaTrazo.Parent = onda

-- ===== Cargar el mapa del servidor =====
local function pintar(datos)
	local tam = datos.tam
	pixelesMapa = tam
	pixelesPorStud = tam / (datos.mundo or Regiones.TAMANO)
	local ok, editable = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(tam, tam) })
	end)
	if not ok or not editable then
		warn("[MINIMAPA] No se puede crear la imagen del mapa:", editable)
		return false
	end
	local rgba = buffer.create(tam * tam * 4)
	for k = 0, tam * tam - 1 do
		buffer.writeu8(rgba, k * 4, buffer.readu8(datos.datos, k * 3))
		buffer.writeu8(rgba, k * 4 + 1, buffer.readu8(datos.datos, k * 3 + 1))
		buffer.writeu8(rgba, k * 4 + 2, buffer.readu8(datos.datos, k * 3 + 2))
		buffer.writeu8(rgba, k * 4 + 3, 255)
	end
	local escrito = pcall(function()
		editable:WritePixelsBuffer(Vector2.zero, Vector2.new(tam, tam), rgba)
		terreno.ImageContent = Content.fromObject(editable)
	end)
	return escrito
end

local function ponerLugares(lista)
	for _, hijo in capaLugares:GetChildren() do
		hijo:Destroy()
	end
	for _, l in lista do
		local color = nil
		if l.tipo == "Santuario" and l.guardian and HistoriaConfig.GUARDIANES[l.guardian] then
			color = HistoriaConfig.GUARDIANES[l.guardian].color
		end
		local f = icono(l.tipo, color)
		f:SetAttribute("X", l.x)
		f:SetAttribute("Z", l.z)
		f.Parent = capaLugares
	end
end

task.spawn(function()
	for _ = 1, 5 do
		local ok, datos = pcall(function()
			return RemotoMapa:InvokeServer("Imagen")
		end)
		if ok and datos and datos.datos then
			if not pintar(datos) then
				-- sin imagen: al menos un fondo con cuadrícula de pergamino
				circulo.BackgroundColor3 = Color3.fromRGB(70, 74, 56)
			end
			ponerLugares(datos.lugares or {})
			return
		end
		task.wait(4)
	end
end)

-- ===== Puntos de los otros jugadores =====
local puntosJugadores = {}
local function puntoDe(otro)
	local p = puntosJugadores[otro]
	if not p then
		p = icono("Jugador")
		p.Parent = capaLugares
		puntosJugadores[otro] = p
	end
	return p
end
Players.PlayerRemoving:Connect(function(otro)
	if puntosJugadores[otro] then
		puntosJugadores[otro]:Destroy()
		puntosJugadores[otro] = nil
	end
end)

-- ===== Actualizar cada fotograma =====
local ultimaRegion = nil
local acumulado = 0
RunService.RenderStepped:Connect(function(dt)
	local oculto = jugador:GetAttribute("EnMenu") or jugador:GetAttribute("EnCinematica")
	raizUI.Visible = not oculto
	if oculto then
		return
	end
	local personaje = jugador.Character
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
	local camara = Workspace.CurrentCamera
	if not raiz or not camara then
		return
	end
	local pos = raiz.Position

	-- el trozo de mapa de alrededor (tú en el centro)
	local lado = RADIO_STUDS * 2 * pixelesPorStud
	local cx = (pos.X + mitad) * pixelesPorStud
	local cz = (pos.Z + mitad) * pixelesPorStud
	terreno.ImageRectSize = Vector2.new(lado, lado)
	terreno.ImageRectOffset = Vector2.new(cx - lado / 2, cz - lado / 2)
	-- iconos: posición respecto a ti; fuera del círculo no se ven
	local function colocar(f, x, z)
		local dx, dz = (x - pos.X) * escala, (z - pos.Z) * escala
		local dentro = dx * dx + dz * dz < (DIAMETRO / 2 - 5) ^ 2
		f.Visible = dentro
		if dentro then
			f.Position = UDim2.fromOffset(DIAMETRO / 2 + dx, DIAMETRO / 2 + dz)
		end
	end
	for _, f in capaLugares:GetChildren() do
		local x, z = f:GetAttribute("X"), f:GetAttribute("Z")
		if x and z then
			colocar(f, x, z)
		end
	end

	-- flecha y cono: hacia donde miras (norte = arriba = -Z)
	local mira = camara.CFrame.LookVector
	local angulo = math.deg(math.atan2(mira.X, -mira.Z))
	giro.Rotation = angulo

	-- otros jugadores
	acumulado += dt
	if acumulado > 0.2 then
		acumulado = 0
		for _, otro in Players:GetPlayers() do
			if otro ~= jugador then
				local r = otro.Character and otro.Character:FindFirstChild("HumanoidRootPart")
				local p = puntoDe(otro)
				if r then
					p:SetAttribute("X", r.Position.X)
					p:SetAttribute("Z", r.Position.Z)
				else
					p:SetAttribute("X", 1e6)
					p:SetAttribute("Z", 1e6)
				end
			end
		end
		-- región
		local region = Regiones.RegionEn(pos)
		if region ~= ultimaRegion then
			ultimaRegion = region
			local datos = Regiones.REGIONES[region]
			textoRegion.Text = if datos then datos.nombre else ""
		end
	end

	-- ping de la misión
	local destino = jugador:GetAttribute("DestinoMision")
	if typeof(destino) == "Vector3" and jugador:GetAttribute("Rastreando") ~= false then
		local dx, dz = (destino.X - pos.X) * escala, (destino.Z - pos.Z) * escala
		local distancia = math.sqrt(dx * dx + dz * dz)
		local limite = DIAMETRO / 2 - 9
		local enBorde = distancia > limite
		if enBorde then
			dx, dz = dx / distancia * limite, dz / distancia * limite
		end
		ping.Visible = true
		ping.Position = UDim2.fromOffset(DIAMETRO / 2 + dx, DIAMETRO / 2 + dz)
		-- late: crece y se apaga, como un latido
		local latido = (os.clock() * 1.1) % 1
		onda.Size = UDim2.fromScale(1 + latido * 1.6, 1 + latido * 1.6)
		ondaTrazo.Transparency = latido
		ping.BackgroundTransparency = if enBorde then 0.1 else 0
		local metros = math.floor((destino - pos).Magnitude / 3.57)
		textoObjetivo.Text = string.format("Objetivo · %d m", metros)
	else
		ping.Visible = false
		textoObjetivo.Text = ""
	end
end)

-- NPC de los pueblos con el aspecto "limpio" del juego (el mismo que los jugadores):
-- cuerpo de bloques, ropa clásica 2D teñida con los colores de su cultura y su clase,
-- caras de anime, peinados del catálogo con color y piezas de color (cinturón, botas, capa).
-- Ruta en Studio: ServerStorage/Herramientas/Mundo/NPCs
-- Lo usa ServerStorage/Herramientas/Mundo/Pueblos. No se ejecuta solo.
--
-- El aspecto lo construye ReplicatedStorage/Personaje/Vestuario. El pelo y las capas se
-- mueven con física desde el cliente (StarterPlayerScripts/PeloCliente).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PueblosConfig = require(ReplicatedStorage.Config.PueblosConfig)
local RazasConfig = require(ReplicatedStorage.Config.RazasConfig)
local AparienciaConfig = require(ReplicatedStorage.Config.AparienciaConfig)
local Vestuario = require(ReplicatedStorage.Personaje.Vestuario)

local NPCs = {}

local M = Enum.Material
local rng = Random.new(4242)

-- Razas de la gente de cada cultura (pesos): cada uno con su físico (RazasConfig.RASGOS)
local RAZAS_CULTURA = {
	Reino = { Humano = 58, Elfo = 18, Enano = 8, Bestia = 9, Celestial = 4, Vampiro = 3 },
	Sol = { Humano = 52, Bestia = 24, Draconido = 10, Elfo = 6, Celestial = 5, Demonio = 3 },
	Brujos = { Humano = 44, Vampiro = 24, Demonio = 12, Elfo = 10, Bestia = 7, Celestial = 3 },
	Norte = { Humano = 48, Enano = 24, Draconido = 10, Bestia = 10, Elfo = 5, Celestial = 3 },
}

local function elegirRaza(cultura)
	local pesos = RAZAS_CULTURA[cultura] or { Humano = 1 }
	local total = 0
	for _, p in pesos do
		total += p
	end
	local tirada = rng:NextNumber(0, total)
	local nombres = {}
	for nombre in pesos do
		table.insert(nombres, nombre)
	end
	table.sort(nombres)
	for _, nombre in nombres do
		tirada -= pesos[nombre]
		if tirada <= 0 then
			return nombre
		end
	end
	return "Humano"
end

local function elegir(lista)
	return lista[rng:NextInteger(1, #lista)]
end

-- ===== ASPECTO POR CULTURA Y CLASE =====
local CASCO_GUARDIA = 2493590711

-- colores de la ropa (hex) de cada cultura
local PALETAS = {
	Reino = {
		plebeyo = { "#6B4A2E", "#4E6B2E", "#7A1E22", "#8A6A44", "#5C6670", "#A0764A", "#3E5A7A", "#D8C29A" },
		noble = { "#7A1E22", "#2E4A7A", "#4B3A78", "#1E3A2E", "#5A1430" },
		pantalon = { "#3B2A20", "#4A3A2A", "#2E2A26", "#5A4632", "#3A3E44" },
	},
	Sol = {
		plebeyo = { "#E8DCC0", "#D8C29A", "#C9A23A", "#B5462E", "#2E7A7A", "#F2EDE4", "#C8783A" },
		noble = { "#2E7A7A", "#C9A23A", "#F2EDE4", "#7A1E22", "#1E4A6A" },
		pantalon = { "#E8DCC0", "#D8C29A", "#8A6A44", "#F2EDE4" },
	},
	Brujos = {
		plebeyo = { "#3A3440", "#2E2A33", "#4B3A58", "#3E4A3A", "#5C5660", "#2A2E36" },
		noble = { "#2A1838", "#1E1A1C", "#46204E", "#14301E", "#3A0E1E" },
		pantalon = { "#1E1A1C", "#2A2630", "#34303A" },
	},
	Norte = {
		plebeyo = { "#5C6670", "#3E4A5A", "#6B4A2E", "#7A6A5A", "#4A5A4A", "#8A8A8A", "#2E3E5A" },
		noble = { "#2E3E6E", "#1E2A44", "#5A1E1E", "#3A4A3A", "#E8E8EC" },
		pantalon = { "#2E2A26", "#3B2A20", "#3A3E44", "#4A4038" },
	},
}
-- prendas que lleva cada cultura (índices de AparienciaConfig.CAMISAS / PANTALONES)
-- 1 Túnica, 2 Lino, 3 Gambesón, 4 Chaqueta, 5 Mago, 6 Corpiño, 7 Malla, 8 Pieles,
-- 9 Desierto, 10 Chaleco, 11 Sobreveste, 12 Harapos
local PRENDAS = {
	Reino = { Hombre = { 1, 2, 3, 4, 10 }, Mujer = { 6, 6, 2, 1 }, noble = { 4, 5 }, nobleMujer = { 6, 5 } },
	Sol = { Hombre = { 9, 9, 2, 10 }, Mujer = { 9, 6, 2 }, noble = { 9, 4 }, nobleMujer = { 9, 6 } },
	Brujos = { Hombre = { 5, 12, 10, 1 }, Mujer = { 6, 5, 12 }, noble = { 5, 4 }, nobleMujer = { 5, 6 } },
	Norte = { Hombre = { 8, 3, 1, 7 }, Mujer = { 6, 8, 3 }, noble = { 8, 4 }, nobleMujer = { 8, 6 } },
}
-- 1 Calzas, 2 Cuero, 3 Bombachos, 4 Falda, 5 Faldón, 6 Acolchado
local PANTALONES = {
	Reino = { Hombre = { 1, 2, 5 }, Mujer = { 4, 4, 1 } },
	Sol = { Hombre = { 3, 3, 1 }, Mujer = { 4, 3 } },
	Brujos = { Hombre = { 1, 2 }, Mujer = { 4, 4 } },
	Norte = { Hombre = { 6, 2, 1 }, Mujer = { 4, 6 } },
}
local PIEL = {
	Reino = { 2, 3, 4, 5, 6 },
	Sol = { 5, 6, 7, 8, 9 },
	Brujos = { 1, 11, 12, 3 },
	Norte = { 1, 2, 3 },
}
local PELO_MAYOR = { "#8C8C94", "#E8E8EC", "#B8B8BC" }

local function elegirIndice(lista)
	return lista[rng:NextInteger(1, #lista)]
end

-- Índices de peinados según el largo
local PEINADOS = { corto = {}, medio = {}, largo = {} }
local function prepararPeinados(AparienciaConfig)
	if #PEINADOS.corto > 0 then
		return
	end
	for i, p in AparienciaConfig.PEINADOS do
		table.insert(PEINADOS[p.largo], i)
	end
end

-- Crea la apariencia (misma tabla que la de los jugadores) de un NPC
local function aparienciaNPC(AparienciaConfig, cultura, clase, genero, esGuardia)
	prepararPeinados(AparienciaConfig)
	local paleta = PALETAS[cultura] or PALETAS.Reino
	local mujer = genero == "Mujer"
	local noble = clase == "Noble"
	local mayor = not esGuardia and rng:NextNumber() < 0.14
	local a = AparienciaConfig.PorDefecto()
	a.Genero = genero
	a.Piel = elegirIndice(PIEL[cultura] or PIEL.Reino)
	a.Altura = math.floor(rng:NextNumber(0.95, 1.06) * 100) / 100
	-- cara (las caras 1-8 son de hombre, 9-14 de mujer, 15-16 de los dos y 17-18 mayores)
	if mayor then
		a.Rostro = if mujer then 18 else 17
	elseif mujer then
		a.Rostro = elegirIndice({ 9, 10, 11, 12, 13, 14, 15, 4 })
	else
		a.Rostro = elegirIndice({ 1, 2, 3, 4, 5, 6, 7, 8, 15, 16 })
	end
	-- peinado
	local largos = if mujer then (if rng:NextNumber() < 0.8 then PEINADOS.largo else PEINADOS.medio)
		else (if rng:NextNumber() < 0.7 then PEINADOS.corto else PEINADOS.medio)
	a.Peinado = elegirIndice(largos)
	a.Peinado2 = 0
	a.PeloColor = if mayor then elegirIndice(PELO_MAYOR) else elegirIndice(AparienciaConfig.COLORES_PELO)
	a.Barba = if not mujer and (mayor or rng:NextNumber() < 0.4) then rng:NextInteger(1, #AparienciaConfig.BARBAS) else 0
	a.Tocado = 0
	if cultura == "Sol" and rng:NextNumber() < 0.45 then
		a.Tocado = elegirIndice({ 9, 10 }) -- pañuelos
	elseif cultura == "Brujos" and rng:NextNumber() < 0.35 then
		a.Tocado = elegirIndice({ 11, 12 }) -- capuchas
	elseif mujer and rng:NextNumber() < 0.3 then
		a.Tocado = elegirIndice(if noble then { 4, 5, 6, 7 } else { 1, 2, 3 })
	end
	-- ropa
	local prendas = PRENDAS[cultura] or PRENDAS.Reino
	if esGuardia then
		a.Camisa = 11 -- sobreveste sobre cota de malla
		a.CamisaColor = "#" .. (PueblosConfig.CULTURAS[cultura].bandera):ToHex()
		a.Pantalon = 6
		a.PantalonColor = "#3A3E44"
		a.Cinturon = 1
		a.CinturonColor = "#2A1E16"
		a.Botas = 2
		a.BotasColor = "#1E1A1C"
		a.Capa = if rng:NextNumber() < 0.5 then 1 else 0
		a.CapaColor = "#" .. (PueblosConfig.CULTURAS[cultura].bandera):ToHex()
		a.Tocado = 0
		return a
	end
	if noble then
		a.Camisa = elegirIndice(if mujer then prendas.nobleMujer else prendas.noble)
		a.CamisaColor = elegirIndice(paleta.noble)
		a.Capa = elegirIndice({ 2, 3, 3 })
		a.CapaColor = elegirIndice(paleta.noble)
		a.Cinturon = 1
		a.CinturonColor = "#1E1A1C"
		a.Botas = if cultura == "Sol" then 0 else elegirIndice({ 2, 3 })
	else
		a.Camisa = elegirIndice(if mujer then prendas.Mujer else prendas.Hombre)
		a.CamisaColor = elegirIndice(paleta.plebeyo)
		a.Capa = if rng:NextNumber() < 0.12 then 1 else 0
		a.CapaColor = elegirIndice(paleta.plebeyo)
		a.Cinturon = if a.Camisa == 9 then 2 else elegirIndice({ 0, 1, 1, 2, 3 })
		a.CinturonColor = elegirIndice({ "#3B2A20", "#2A1E16", "#6B4A2E", "#7A1E22" })
		a.Botas = if cultura == "Sol" then 0 elseif cultura == "Norte" then 2 else elegirIndice({ 0, 1, 1, 2 })
	end
	local pantalones = (PANTALONES[cultura] or PANTALONES.Reino)[genero]
	a.Pantalon = elegirIndice(pantalones)
	a.PantalonColor = if a.Pantalon == 4 then elegirIndice(paleta.plebeyo) else elegirIndice(paleta.pantalon)
	a.BotasColor = elegirIndice({ "#1E1A1C", "#2A1E16", "#3B2A20", "#4A3426" })
	if cultura == "Norte" and a.Capa == 0 and rng:NextNumber() < 0.3 then
		a.Capa = 1
		a.CapaColor = elegirIndice(paleta.plebeyo)
	end
	return a
end

-- Pieza decorativa pegada a una parte del cuerpo (se mueve con la animación)
local function adorno(cuerpo, offset, tamano, material, color, nombre)
	local p = Instance.new("Part")
	p.Name = nombre or "Adorno"
	p.Size = tamano
	p.Material = material
	p.Color = color
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.CFrame = cuerpo.CFrame * offset
	local soldadura = Instance.new("WeldConstraint")
	soldadura.Part0 = cuerpo
	soldadura.Part1 = p
	soldadura.Parent = p
	p.Parent = cuerpo.Parent
	return p
end

-- Detalles del oficio (encima de la ropa)
local function detallesOficio(modelo, oficio, clase, cultura)
	local torso = modelo:FindFirstChild("UpperTorso")
	local cabeza = modelo:FindFirstChild("Head")
	if not (torso and cabeza) then
		return
	end
	local tc = torso.Size
	if oficio == "Herrero" then
		adorno(torso, CFrame.new(0, -tc.Y * 0.15, -tc.Z / 2 - 0.12), Vector3.new(tc.X * 0.8, tc.Y * 1.6, 0.08), M.Leather, Color3.fromRGB(86, 58, 36), "Mandil")
	elseif clase == "Noble" then
		-- un detalle dorado (broche) que distingue a los nobles
		adorno(torso, CFrame.new(tc.X * 0.22, tc.Y * 0.3, -tc.Z / 2 - 0.15), Vector3.new(0.22, 0.22, 0.08), M.Foil, Color3.fromRGB(230, 180, 70), "Broche")
	end
end

-- Cartel flotante con el nombre y el oficio
local function etiqueta(cabeza, nombre, titulo, cultura)
	local cartel = Instance.new("BillboardGui")
	cartel.Name = "Nombre"
	cartel.Size = UDim2.fromOffset(220, 44)
	cartel.StudsOffset = Vector3.new(0, 2.6, 0)
	cartel.MaxDistance = 35
	cartel.LightInfluence = 0
	cartel.Parent = cabeza
	local texto = Instance.new("TextLabel")
	texto.Size = UDim2.new(1, 0, 0.6, 0)
	texto.BackgroundTransparency = 1
	texto.Font = Enum.Font.Garamond
	texto.TextScaled = true
	texto.Text = nombre
	texto.TextColor3 = Color3.fromRGB(245, 232, 200)
	texto.TextStrokeTransparency = 0.4
	texto.Parent = cartel
	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.fromScale(0, 0.6)
	sub.Size = UDim2.new(1, 0, 0.4, 0)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.Garamond
	sub.TextScaled = true
	sub.Text = titulo
	sub.TextColor3 = PueblosConfig.CULTURAS[cultura].detalle
	sub.TextStrokeTransparency = 0.5
	sub.Parent = cartel
end

-- Elige género, clase y nombre para un NPC. Devuelve una tabla con todo.
function NPCs.Identidad(cultura, oficio, clase, usados)
	local genero = if oficio == "Guardia" then "Hombre" elseif rng:NextNumber() < 0.5 then "Hombre" else "Mujer"
	local lista = PueblosConfig.NOMBRES[cultura][genero]
	local nombre = elegir(lista)
	local intentos = 0
	while usados[nombre] and intentos < 30 do
		nombre = elegir(lista)
		intentos += 1
	end
	usados[nombre] = true
	local titulo
	if clase == "Noble" then
		titulo = "Noble"
		nombre = PueblosConfig.TITULOS_NOBLES[cultura][genero] .. " " .. nombre
	elseif oficio == "Aldeano" then
		local trabajo = elegir(PueblosConfig.TRABAJOS[cultura])
		titulo = if genero == "Hombre" then trabajo[1] else trabajo[2]
	else
		titulo = (PueblosConfig.OFICIOS[oficio] or PueblosConfig.OFICIOS.Aldeano).titulo
	end
	return { genero = genero, nombre = nombre, titulo = titulo }
end

-- Crea un NPC.
-- datos = { nombre, titulo, genero, clase, rol, oficio, tienda?, cultura, pueblo, cf, casa? }
function NPCs.Crear(padre, datos)
	local cultura = datos.cultura
	local genero = datos.genero
	local clase = datos.clase or "Plebeyo"
	local esGuardia = datos.oficio == "Guardia"
	-- raza: cada una con su físico (orejas, cola, alas, cuernos, colmillos, tamaño...)
	local raza = datos.raza or elegirRaza(cultura)
	local semilla = rng:NextInteger(1, 1000)
	local apariencia = aparienciaNPC(AparienciaConfig, cultura, clase, genero, esGuardia)
	if RazasConfig.Rasgos(raza, semilla).barba and genero == "Hombre" and apariencia.Barba == 0 then
		apariencia.Barba = rng:NextInteger(1, #AparienciaConfig.BARBAS)
	end
	local descripcion = Vestuario.Descripcion(apariencia, raza, semilla, {
		casco = if esGuardia then CASCO_GUARDIA else nil,
		sinRasgosCabeza = esGuardia, -- los guardias llevan casco
		escala = { 1, rng:NextNumber(0.96, 1.04) },
	})

	local ok, modelo = pcall(function()
		return Players:CreateHumanoidModelFromDescription(descripcion, Enum.HumanoidRigType.R15)
	end)
	descripcion:Destroy()
	if not ok or not modelo then
		warn("[MUNDO] No pude crear el NPC", datos.nombre, modelo)
		return nil
	end
	modelo.Name = datos.nombre
	Vestuario.Vestir(modelo, apariencia)

	local humanoide = modelo:FindFirstChildOfClass("Humanoid")
	local raiz = modelo:FindFirstChild("HumanoidRootPart")
	humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoide.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoide.WalkSpeed = if clase == "Noble" then 5 else 6.5
	humanoide.BreakJointsOnDeath = false
	-- Quieto hasta que el servidor le diga que camine (NPCServicio)
	raiz.Anchored = true

	-- De pie en el suelo, mirando al frente
	local altura = humanoide.HipHeight + raiz.Size.Y / 2
	modelo:PivotTo(CFrame.new(datos.cf.Position + Vector3.new(0, altura, 0)) * datos.cf.Rotation)

	detallesOficio(modelo, datos.oficio, clase, cultura)

	-- Datos para el servidor (rutinas) y el cliente (diálogo y tienda)
	modelo:SetAttribute("NPC", true)
	modelo:SetAttribute("Nombre", datos.nombre)
	modelo:SetAttribute("Oficio", datos.oficio)
	modelo:SetAttribute("Titulo", datos.titulo)
	modelo:SetAttribute("Genero", genero)
	modelo:SetAttribute("Raza", raza)
	modelo:SetAttribute("Clase", clase)
	modelo:SetAttribute("Rol", datos.rol)
	modelo:SetAttribute("Cultura", cultura)
	modelo:SetAttribute("Pueblo", datos.pueblo.id)
	modelo:SetAttribute("PuebloNombre", datos.pueblo.nombre)
	modelo:SetAttribute("Puesto", datos.cf.Position) -- su sitio de trabajo (o donde aparece)
	if datos.casa then
		modelo:SetAttribute("Casa", datos.casa)
	end
	if datos.tienda then
		modelo:SetAttribute("Tienda", datos.tienda)
	end
	CollectionService:AddTag(modelo, "NPC")

	-- Botón para hablar (tecla E, o tocar en el móvil)
	local boton = Instance.new("ProximityPrompt")
	boton.Name = "Hablar"
	boton.ActionText = if datos.tienda then "Hablar / Tienda" else "Hablar"
	boton.ObjectText = datos.nombre .. " · " .. datos.titulo
	boton.KeyboardKeyCode = Enum.KeyCode.G -- la E es para las habilidades
	boton.MaxActivationDistance = 10
	boton.HoldDuration = 0
	boton.RequiresLineOfSight = false
	boton.Parent = raiz

	etiqueta(modelo:FindFirstChild("Head"), datos.nombre, datos.titulo, cultura)

	modelo.Parent = padre
	return modelo
end

return NPCs

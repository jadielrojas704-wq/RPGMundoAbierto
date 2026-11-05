-- NPC de los pueblos: cuerpo realista, pelo y ropa propios según su cultura, su clase
-- (noble o plebeyo) y su género, nombre y botón para hablar.
-- Ruta en Studio: ServerStorage/Herramientas/Mundo/NPCs
-- Lo usa ServerStorage/Herramientas/Mundo/Pueblos. No se ejecuta solo.
--
-- La apariencia usa objetos del catálogo de Roblox (los NPC de un juego pueden usar
-- cualquier objeto del catálogo sin comprarlo):
--   * Cuerpos "Man" y "Woman" de Roblox con cabeza realista que gesticula
--   * Pelos 3D modernos y realistas (nada de pelo de bloque)
--   * Ropa 3D por capas (camisa, pantalón, túnica, vestido, abrigo...)
--   * Guardias con la armadura "Knights of Redcliff: Paladin"
-- El pelo se balancea con física desde el cliente (StarterPlayerScripts/PeloCliente).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PueblosConfig = require(ReplicatedStorage.Config.PueblosConfig)

local NPCs = {}

local M = Enum.Material
local A = Enum.AccessoryType
local rng = Random.new(4242)

local function elegir(lista)
	return lista[rng:NextInteger(1, #lista)]
end

-- ===== CUERPOS =====
local CUERPO = {
	Hombre = { Torso = 86500008, RightArm = 86500036, LeftArm = 86500054, LeftLeg = 86500064, RightLeg = 86500078, Head = 10725826963, MoodAnimation = 10725833199 },
	Mujer = { Torso = 86499666, RightArm = 86499698, LeftArm = 86499716, LeftLeg = 86499753, RightLeg = 86499793, Head = 10725626210, MoodAnimation = 10725638029 },
	-- armadura completa de caballero para los guardias
	Guardia = { Torso = 2493586650, RightArm = 2493786076, LeftArm = 2493559059, LeftLeg = 2493559856, RightLeg = 2493776828, Head = 10725826963 },
}
local CASCO_GUARDIA = "2493590711"

-- ===== CARAS (cabezas realistas que gesticulan: humanas y de estilo anime) =====
-- { cabeza, gesto }. Más o menos 3 de cada 10 NPC tienen cara de anime.
local GESTO_ANIME = 14618207727
local CARAS = {
	Hombre = {
		{ 10725826963, 10725833199 },
		{ 11180212350, 11180270363 },
		{ 11163789916, 11163856931 },
		{ 12954264879, 12954268123 },
		{ 13692975981, 13692973305 },
		{ 128202565043011, 123330892729033 },
		{ 73697371296507, 102106667157830 },
		{ 75853796532602, 129306210206691 },
		{ 79029537488886, 129812951799208 },
		{ 74295716469720, 101654090668842 },
		{ 74785198633210, 112600527789051 },
		{ 96229607001945, 132110660061380 },
	},
	Mujer = {
		{ 10725626210, 10725638029 },
		{ 118329081640597, 78343337775421 },
		{ 133196692848803, 133285968979014 },
		{ 96894500746180, 117538893462160 },
		{ 79654074199621, 90050254054804 },
		{ 122186149619860, 73965504683643 },
	},
}
local CARAS_ANIME = {
	Hombre = { 16993075742, 137455697511260, 75581288616531, 118058361171785, 128807805327178, 120459846176613 },
	Mujer = { 86162594467821, 121439252875925, 119128441301162, 103850685216450, 75581288616531 },
}

local PIEL = {
	Reino = { Color3.fromRGB(234, 192, 160), Color3.fromRGB(214, 170, 136), Color3.fromRGB(196, 146, 112), Color3.fromRGB(150, 104, 76) },
	Sol = { Color3.fromRGB(198, 148, 106), Color3.fromRGB(172, 122, 84), Color3.fromRGB(144, 100, 68), Color3.fromRGB(112, 76, 52) },
	Brujos = { Color3.fromRGB(226, 214, 208), Color3.fromRGB(206, 192, 188), Color3.fromRGB(184, 170, 172) },
	Norte = { Color3.fromRGB(244, 214, 194), Color3.fromRGB(230, 194, 170), Color3.fromRGB(214, 178, 152) },
}

-- ===== PELO (accesorios 3D del catálogo) =====
local PELO = {
	Reino = {
		Hombre = { 376548738, 63690008, 4690479914, 15014232630, 107201292209451, 84355475848604 },
		Mujer = { 12519986, 2956239660, 376526888, 13745548, 13251161977, 18118234667, 107474706603976, 17718240769, 6005348300, 80569506402913, 15450082625 },
	},
	Sol = {
		Hombre = { 343584973, 5100703261, 5269153561, 7259123616, 100412216731005, 376548738 },
		Mujer = { 376527350, 4935029747, 107474706603976, 6005348300, 80569506402913 },
	},
	Brujos = {
		Hombre = { 12441766571, 7331264047, 94552462259427, 7259123616, 343584973 },
		Mujer = { 4935029747, 4071226828, 376527350, 2956239660, 80569506402913, 7331264047 },
	},
	Norte = {
		Hombre = { 107201292209451, 84355475848604, 15014232630, 63690008, 4690479914, 94552462259427 },
		Mujer = { 83017698423383, 13251161977, 376526888, 12519986, 17718240769, 15450082625 },
	},
}
local PELO_MAYOR = { 13703147645, 94552462259427 } -- canas para algunos mayores
local BARBA = {
	Reino = { 4995497755, 12051129773, 158066137, 96842327519524 },
	Sol = { 6351051364, 11134059762, 12051129773 },
	Brujos = { 461493477, 11134059762, 4995497755 },
	Norte = { 158066137, 96842327519524, 6351051364, 11134059762 },
}

-- ===== ROPA (por capas) =====
-- Cada conjunto: lista de { id, tipo } + sombrero/espalda opcionales
local CAMISA_BLANCA, CAMISA_CHALECO, CAMISA_BLANCA2, CAMISA_NEGRA, BLUSA_LINO = 92423894013708, 94991372254165, 77448423220956, 105904796157571, 15557266849
local PANTALON_MARRON, PANTALON_CUERO, PANTALON_ANTE, PANTALON_NEGRO, PANTALON_NOBLE = 140056195668204, 105372883243744, 77371329429487, 136388872034414, 82550697634263
local BOTAS = 12650394206
local TUNICA_CAMPESINA, TUNICA_ROJA, TUNICA_VERDE, CHALECO_CUERO = 91359280176800, 14133982829, 14134014096, 9039202434
local CHAQUETA_NOBLE, TUNICA_ROTA, TUNICA_VAMPIRO, TUNICA_MAGO = 18928625631, 16973688129, 137570039213236, 124344642287010
local ABRIGO_PIEL, ABRIGO_PIEL_LARGO = 101060387420980, 87557381317797
local FALDA_VERDE, FALDA_AZUL, VESTIDO_BLANCO, VESTIDO_PRINCESA, VESTIDO_BAILE = 14929785603, 14929796183, 112259769222057, 13691581282, 88076810907288
local CORPINO_ROJO, CORPINO_NEGRO, REINA_SOL = 91966496292930, 114294144196467, 134415657665616
local CAPA, PANUELO_BEIGE, KEFIYEH, KEFIYEH_NEGRO = "13254752315", "16219944268", "14230101896", "14230119361"

local function conjunto(capas, extra)
	extra = extra or {}
	return { capas = capas, sombrero = extra.sombrero, espalda = extra.espalda }
end

local ROPA = {
	Reino = {
		Plebeyo = {
			Hombre = {
				conjunto({ { CAMISA_BLANCA, A.Shirt }, { PANTALON_MARRON, A.Pants }, { BOTAS, A.Pants }, { TUNICA_CAMPESINA, A.Jacket } }),
				conjunto({ { CAMISA_CHALECO, A.Shirt }, { PANTALON_CUERO, A.Pants }, { BOTAS, A.Pants } }),
				conjunto({ { TUNICA_ROJA, A.Sweater }, { PANTALON_MARRON, A.Pants }, { BOTAS, A.Pants } }),
				conjunto({ { TUNICA_VERDE, A.Sweater }, { PANTALON_CUERO, A.Pants }, { BOTAS, A.Pants } }),
			},
			Mujer = {
				conjunto({ { BLUSA_LINO, A.Shirt }, { FALDA_VERDE, A.DressSkirt } }),
				conjunto({ { VESTIDO_BLANCO, A.DressSkirt }, { CORPINO_ROJO, A.Jacket } }),
				conjunto({ { BLUSA_LINO, A.Shirt }, { FALDA_AZUL, A.DressSkirt } }),
			},
		},
		Noble = {
			Hombre = { conjunto({ { CAMISA_BLANCA, A.Shirt }, { PANTALON_NOBLE, A.Pants }, { CHAQUETA_NOBLE, A.Jacket } }, { espalda = CAPA }) },
			Mujer = { conjunto({ { VESTIDO_PRINCESA, A.DressSkirt } }), conjunto({ { BLUSA_LINO, A.Shirt }, { VESTIDO_BAILE, A.DressSkirt } }) },
		},
	},
	Sol = {
		Plebeyo = {
			Hombre = {
				conjunto({ { CAMISA_BLANCA2, A.Shirt }, { PANTALON_ANTE, A.Pants } }, { sombrero = KEFIYEH }),
				conjunto({ { CAMISA_BLANCA, A.Shirt }, { PANTALON_MARRON, A.Pants } }, { sombrero = KEFIYEH_NEGRO }),
				conjunto({ { CAMISA_BLANCA2, A.Shirt }, { PANTALON_ANTE, A.Pants }, { CHALECO_CUERO, A.Jacket } }),
			},
			Mujer = {
				conjunto({ { VESTIDO_BLANCO, A.DressSkirt } }, { sombrero = PANUELO_BEIGE }),
				conjunto({ { VESTIDO_BLANCO, A.DressSkirt }, { CORPINO_ROJO, A.Jacket } }, { sombrero = PANUELO_BEIGE }),
			},
		},
		Noble = {
			Hombre = { conjunto({ { CAMISA_BLANCA2, A.Shirt }, { PANTALON_NOBLE, A.Pants }, { CHAQUETA_NOBLE, A.Jacket } }, { espalda = CAPA, sombrero = KEFIYEH }) },
			Mujer = { conjunto({ { VESTIDO_BLANCO, A.DressSkirt }, { REINA_SOL, A.Jacket } }) },
		},
	},
	Brujos = {
		Plebeyo = {
			Hombre = {
				conjunto({ { PANTALON_NEGRO, A.Pants }, { TUNICA_ROTA, A.Jacket } }),
				conjunto({ { CAMISA_NEGRA, A.Shirt }, { PANTALON_NEGRO, A.Pants }, { BOTAS, A.Pants } }),
			},
			Mujer = {
				conjunto({ { BLUSA_LINO, A.Shirt }, { FALDA_AZUL, A.DressSkirt }, { CORPINO_NEGRO, A.Jacket } }),
				conjunto({ { TUNICA_ROTA, A.Jacket } }),
			},
		},
		Noble = {
			Hombre = {
				conjunto({ { CAMISA_NEGRA, A.Shirt }, { PANTALON_NEGRO, A.Pants }, { TUNICA_VAMPIRO, A.Jacket } }),
				conjunto({ { CAMISA_NEGRA, A.Shirt }, { PANTALON_NEGRO, A.Pants }, { TUNICA_MAGO, A.Jacket } }),
			},
			Mujer = { conjunto({ { BLUSA_LINO, A.Shirt }, { FALDA_AZUL, A.DressSkirt }, { TUNICA_MAGO, A.Jacket } }, { espalda = CAPA }) },
		},
	},
	Norte = {
		Plebeyo = {
			Hombre = {
				conjunto({ { CAMISA_BLANCA, A.Shirt }, { PANTALON_CUERO, A.Pants }, { BOTAS, A.Pants }, { CHALECO_CUERO, A.Jacket } }),
				conjunto({ { CAMISA_BLANCA, A.Shirt }, { PANTALON_MARRON, A.Pants }, { BOTAS, A.Pants }, { ABRIGO_PIEL, A.Jacket } }),
			},
			Mujer = {
				conjunto({ { BLUSA_LINO, A.Shirt }, { FALDA_VERDE, A.DressSkirt }, { CHALECO_CUERO, A.Jacket } }),
				conjunto({ { BLUSA_LINO, A.Shirt }, { FALDA_VERDE, A.DressSkirt }, { ABRIGO_PIEL_LARGO, A.Jacket } }),
			},
		},
		Noble = {
			Hombre = { conjunto({ { CAMISA_CHALECO, A.Shirt }, { PANTALON_NEGRO, A.Pants }, { BOTAS, A.Pants }, { ABRIGO_PIEL_LARGO, A.Jacket } }, { espalda = CAPA }) },
			Mujer = { conjunto({ { BLUSA_LINO, A.Shirt }, { VESTIDO_BLANCO, A.DressSkirt }, { ABRIGO_PIEL_LARGO, A.Jacket } }) },
		},
	},
}

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
	elseif oficio == "Guardia" then
		local datos = PueblosConfig.CULTURAS[cultura]
		adorno(torso, CFrame.new(0, -tc.Y * 0.1, -tc.Z / 2 - 0.2), Vector3.new(tc.X * 0.55, tc.Y * 1.4, 0.06), M.Fabric, datos.bandera, "Tabardo")
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
	local piel = elegir(PIEL[cultura])

	local descripcion = Instance.new("HumanoidDescription")
	for propiedad, valor in (if esGuardia then CUERPO.Guardia else CUERPO[genero]) do
		descripcion[propiedad] = valor
	end
	for _, parte in { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" } do
		descripcion[parte] = piel
	end
	-- una cara distinta para cada NPC (humana o de anime)
	if not esGuardia then
		if rng:NextNumber() < 0.3 then
			descripcion.Head = elegir(CARAS_ANIME[genero])
			descripcion.MoodAnimation = GESTO_ANIME
		else
			local cara = elegir(CARAS[genero])
			descripcion.Head = cara[1]
			descripcion.MoodAnimation = cara[2]
		end
	end
	-- un poco de variedad de altura y complexión
	descripcion.HeightScale = rng:NextNumber(0.96, 1.06)
	descripcion.WidthScale = rng:NextNumber(0.94, 1.04)

	-- pelo (algunos hombres mayores con canas) y barba
	local pelo = elegir(PELO[cultura][genero])
	if genero == "Hombre" and rng:NextNumber() < 0.15 then
		pelo = elegir(PELO_MAYOR)
	end
	descripcion.HairAccessory = tostring(pelo)
	if genero == "Hombre" and rng:NextNumber() < 0.5 then
		descripcion.FaceAccessory = tostring(elegir(BARBA[cultura]))
	end

	-- ropa
	if esGuardia then
		descripcion.HatAccessory = CASCO_GUARDIA
	else
		local estilo = ROPA[cultura][clase][genero]
		local elegido = elegir(estilo)
		local capas = {}
		for orden, capa in elegido.capas do
			table.insert(capas, { AssetId = capa[1], AccessoryType = capa[2], IsLayered = true, Order = orden })
		end
		pcall(function()
			descripcion:SetAccessories(capas, false)
		end)
		if elegido.sombrero then
			descripcion.HatAccessory = elegido.sombrero
		end
		if elegido.espalda then
			descripcion.BackAccessory = elegido.espalda
		end
	end

	local ok, modelo = pcall(function()
		return Players:CreateHumanoidModelFromDescription(descripcion, Enum.HumanoidRigType.R15)
	end)
	if not ok or not modelo then
		warn("[MUNDO] No pude crear el NPC", datos.nombre, modelo)
		return nil
	end
	modelo.Name = datos.nombre

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

-- Opciones del editor de personaje (Personalizar). Las usan el SERVIDOR (para comprobar y
-- vestir al personaje) y el cliente (para enseñar las opciones con su miniatura).
-- Ruta en Studio: ReplicatedStorage/Config/AparienciaConfig
--
-- Todo son objetos del catálogo de Roblox. Un juego puede ponerle a sus personajes
-- cualquier objeto público del catálogo sin que el jugador lo compre.
-- Para añadir más: copia una línea y cambia el número (el id del catálogo).

local AparienciaConfig = {}

AparienciaConfig.GENEROS = { "Hombre", "Mujer" }

-- Los JUGADORES siempre tienen cuerpo blocky (decisión del usuario, 4 nov): sus partes del
-- cuerpo se quedan en 0. Estos cuerpos realistas son para los NPC, el Custodio y las estatuas.
AparienciaConfig.CUERPOS = {
	Hombre = { Torso = 86500008, RightArm = 86500036, LeftArm = 86500054, LeftLeg = 86500064, RightLeg = 86500078 },
	Mujer = { Torso = 86499666, RightArm = 86499698, LeftArm = 86499716, LeftLeg = 86499753, RightLeg = 86499793 },
	-- armadura completa de caballero ("Knights of Redcliff: Paladin")
	Caballero = {
		Torso = 2493586650,
		RightArm = 2493786076,
		LeftArm = 2493559059,
		LeftLeg = 2493559856,
		RightLeg = 2493776828,
	},
}

-- Tonos de piel
AparienciaConfig.PIELES = {
	Color3.fromRGB(255, 226, 206),
	Color3.fromRGB(244, 214, 194),
	Color3.fromRGB(234, 192, 160),
	Color3.fromRGB(214, 170, 136),
	Color3.fromRGB(198, 148, 106),
	Color3.fromRGB(172, 122, 84),
	Color3.fromRGB(144, 100, 68),
	Color3.fromRGB(112, 76, 52),
	Color3.fromRGB(84, 56, 40),
	Color3.fromRGB(60, 40, 30),
	Color3.fromRGB(206, 196, 202), -- pálido de la ciénaga
	Color3.fromRGB(170, 176, 190), -- ceniza
}

-- Caras: cabezas realistas de Roblox que gesticulan (cabeza + gesto)
AparienciaConfig.CARAS = {
	{ nombre = "Hombre", cabeza = 10725826963, gesto = 10725833199 },
	{ nombre = "Mujer", cabeza = 10725626210, gesto = 10725638029 },
	{ nombre = "Clásica", cabeza = 11180212350, gesto = 11180270363 },
	{ nombre = "Sonrisa ganadora", cabeza = 11163789916, gesto = 11163856931 },
	{ nombre = "Alegre", cabeza = 12954264879, gesto = 12954268123 },
	{ nombre = "Amable", cabeza = 13692975981, gesto = 13692973305 },
	{ nombre = "Confiado", cabeza = 128202565043011, gesto = 123330892729033 },
	{ nombre = "Orgulloso", cabeza = 73697371296507, gesto = 102106667157830 },
	{ nombre = "Astuto", cabeza = 75853796532602, gesto = 129306210206691 },
	{ nombre = "Decepcionado", cabeza = 79029537488886, gesto = 129812951799208 },
	{ nombre = "Feliz", cabeza = 122186149619860, gesto = 73965504683643 },
	{ nombre = "Eufórico", cabeza = 79654074199621, gesto = 90050254054804 },
	{ nombre = "Cicatriz", cabeza = 74295716469720, gesto = 101654090668842 },
	{ nombre = "Cicatriz roja", cabeza = 74785198633210, gesto = 112600527789051 },
	{ nombre = "Malas noticias", cabeza = 96229607001945, gesto = 132110660061380 },
	{ nombre = "Mejillas rosadas", cabeza = 118329081640597, gesto = 78343337775421 },
	{ nombre = "Reina de las nieves", cabeza = 133196692848803, gesto = 133285968979014 },
	{ nombre = "Enamorada", cabeza = 96894500746180, gesto = 117538893462160 },
	{ nombre = "Escarcha", cabeza = 120590400620706, gesto = 75052868714630 },
	-- estilo anime
	{ nombre = "Anime", cabeza = 16993075742, gesto = 14618207727, anime = true },
	{ nombre = "Anime 2", cabeza = 137455697511260, gesto = 14618207727, anime = true },
	{ nombre = "Anime 3", cabeza = 75581288616531, gesto = 14618207727, anime = true },
	{ nombre = "Anime 4", cabeza = 118058361171785, gesto = 14618207727, anime = true },
	{ nombre = "Chico anime", cabeza = 128807805327178, gesto = 14618207727, anime = true },
	{ nombre = "Manga", cabeza = 120459846176613, gesto = 14618207727, anime = true },
	{ nombre = "Chica anime", cabeza = 86162594467821, gesto = 14618207727, anime = true },
	{ nombre = "Chica anime 2", cabeza = 121439252875925, gesto = 14618207727, anime = true },
	{ nombre = "Chica anime 3", cabeza = 119128441301162, gesto = 14618207727, anime = true },
	{ nombre = "Mirada de amatista", cabeza = 103850685216450, gesto = 14618207727, anime = true },
}

-- Pelos. "tipo" es el hueco del accesorio en Roblox (Hair, Face o Hat).
local function p(id, tipo)
	return { id = id, tipo = tipo or "Hair" }
end
AparienciaConfig.PELOS = {
	-- realistas (los que llevan los NPC)
	p(376548738),
	p(63690008),
	p(4690479914),
	p(15014232630),
	p(107201292209451),
	p(84355475848604),
	p(343584973),
	p(5100703261),
	p(5269153561),
	p(7259123616),
	p(100412216731005),
	p(12441766571),
	p(7331264047),
	p(94552462259427),
	p(13703147645),
	p(12519986),
	p(2956239660),
	p(376526888),
	p(13745548),
	p(13251161977),
	p(18118234667),
	p(107474706603976),
	p(17718240769),
	p(6005348300),
	p(80569506402913),
	p(15450082625),
	p(376527350),
	p(4935029747),
	p(4071226828),
	p(83017698423383),
	-- de punta (estilo anime)
	p(13344398396, "Face"),
	p(13344419310, "Face"),
	p(13470543305, "Face"),
	p(13470517204, "Face"),
	p(13344416609, "Face"),
	p(13344410628, "Face"),
	p(13832965098, "Face"),
	-- despeinados
	p(15441234464, "Face"),
	p(14306744925, "Face"),
	p(16090053248, "Face"),
	p(16111378294, "Face"),
	p(15360981103, "Face"),
	p(14318728750, "Face"),
	-- largos, trenzas y coletas
	p(17573166569, "Hat"),
	p(74579099101014, "Hat"),
	p(14318307127, "Face"),
	p(15051659976, "Face"),
	p(16035727009, "Face"),
	p(16035736147, "Face"),
	p(14914159127, "Face"),
}

AparienciaConfig.BARBAS = { 4995497755, 12051129773, 158066137, 96842327519524, 6351051364, 11134059762, 461493477 }

-- ===== ROPA por estamento =====
-- capas = { { id, "Shirt" / "Pants" / "Jacket" / "Sweater" / "DressSkirt" } } (ropa 3D por capas)
local CAMISA_BLANCA, CAMISA_CHALECO, CAMISA_BLANCA2, CAMISA_NEGRA, BLUSA_LINO =
	92423894013708, 94991372254165, 77448423220956, 105904796157571, 15557266849
local PANTALON_MARRON, PANTALON_CUERO, PANTALON_ANTE, PANTALON_NEGRO, PANTALON_NOBLE =
	140056195668204, 105372883243744, 77371329429487, 136388872034414, 82550697634263
local BOTAS = 12650394206
local TUNICA_CAMPESINA, TUNICA_ROJA, TUNICA_VERDE, CHALECO_CUERO = 91359280176800, 14133982829, 14134014096, 9039202434
local CHAQUETA_NOBLE, TUNICA_ROTA, TUNICA_VAMPIRO, TUNICA_MAGO =
	18928625631, 16973688129, 137570039213236, 124344642287010
local ABRIGO_PIEL, ABRIGO_PIEL_LARGO = 101060387420980, 87557381317797
local FALDA_VERDE, FALDA_AZUL, VESTIDO_BLANCO, VESTIDO_PRINCESA, VESTIDO_BAILE =
	14929785603, 14929796183, 112259769222057, 13691581282, 88076810907288
local CORPINO_ROJO, CORPINO_NEGRO, REINA_SOL = 91966496292930, 114294144196467, 134415657665616
local TUNICA_REY, TUNICA_REY_ORO = 17721377902, 17766360848
local TUNICA_RITUAL, CAPA_NEGRA_CAPUCHA = 82268347801802, 18431909363
local CAPA, CAPA_REAL, CAPA_REAL2 = 13254752315, 7133208568, 96639818423994
local CORONA, CORONA2, TIARA = 85756272104549, 14292141065, 15170399438
local PANUELO_BEIGE, KEFIYEH, KEFIYEH_NEGRO, CASCO = 16219944268, 14230101896, 14230119361, 2493590711
-- armaduras 3D por capas (sirven en el cuerpo blocky)
local PLACAS_PLATA, PLACAS_NEGRAS, PLACAS_ORO, BRIGANTINA = 16100249133, 16034546959, 16077694176, 16034525842
local GREBAS, GREBAS2 = 96926656599960, 91650174963301

AparienciaConfig.ESTAMENTOS = { "Plebeyo", "Noble", "Realeza", "Caballero", "Hechicero" }
AparienciaConfig.TEXTO_ESTAMENTO = {
	Plebeyo = "Ropa de pueblo: campesinos, artesanos y viajeros.",
	Noble = "Señores y damas de las cuatro culturas.",
	Realeza = "Reyes y reinas, con corona y capa real.",
	Caballero = "Armaduras de placas y brigantinas.",
	Hechicero = "Túnicas de magos, brujos y nigromantes.",
}

-- La prenda que mejor representa el conjunto (para su miniatura): abrigo, vestido o camisa
local function prendaPrincipal(capas)
	for _, tipo in { "Jacket", "DressSkirt", "Sweater", "Shirt", "Pants" } do
		for _, capa in capas do
			if capa[2] == tipo and capa[1] ~= BOTAS then
				return capa[1]
			end
		end
	end
	return capas[1] and capas[1][1]
end

local function conjunto(id, nombre, estamento, genero, capas, extra)
	extra = extra or {}
	return {
		id = id,
		nombre = nombre,
		estamento = estamento,
		genero = genero, -- nil = sirve para los dos
		capas = capas,
		sombrero = extra.sombrero,
		espalda = extra.espalda,
		cuerpo = extra.cuerpo, -- "Caballero" cambia el cuerpo entero por la armadura
		icono = extra.icono or prendaPrincipal(capas) or extra.sombrero,
	}
end

AparienciaConfig.ROPA = {
	-- Plebeyos
	conjunto(
		"Campesino",
		"Campesino",
		"Plebeyo",
		"Hombre",
		{ { CAMISA_BLANCA, "Shirt" }, { PANTALON_MARRON, "Pants" }, { BOTAS, "Pants" }, { TUNICA_CAMPESINA, "Jacket" } }
	),
	conjunto(
		"Artesano",
		"Artesano",
		"Plebeyo",
		"Hombre",
		{ { CAMISA_CHALECO, "Shirt" }, { PANTALON_CUERO, "Pants" }, { BOTAS, "Pants" } }
	),
	conjunto(
		"TunicaRoja",
		"Túnica roja",
		"Plebeyo",
		"Hombre",
		{ { TUNICA_ROJA, "Sweater" }, { PANTALON_MARRON, "Pants" }, { BOTAS, "Pants" } }
	),
	conjunto(
		"TunicaVerde",
		"Túnica verde",
		"Plebeyo",
		"Hombre",
		{ { TUNICA_VERDE, "Sweater" }, { PANTALON_CUERO, "Pants" }, { BOTAS, "Pants" } }
	),
	conjunto(
		"Lenador",
		"Leñador del norte",
		"Plebeyo",
		"Hombre",
		{ { CAMISA_BLANCA, "Shirt" }, { PANTALON_CUERO, "Pants" }, { BOTAS, "Pants" }, { CHALECO_CUERO, "Jacket" } }
	),
	conjunto(
		"Cazador",
		"Cazador de pieles",
		"Plebeyo",
		"Hombre",
		{ { CAMISA_BLANCA, "Shirt" }, { PANTALON_MARRON, "Pants" }, { BOTAS, "Pants" }, { ABRIGO_PIEL, "Jacket" } }
	),
	conjunto(
		"Caravanero",
		"Caravanero",
		"Plebeyo",
		"Hombre",
		{ { CAMISA_BLANCA2, "Shirt" }, { PANTALON_ANTE, "Pants" } },
		{ sombrero = KEFIYEH }
	),
	conjunto("Mendigo", "Harapos", "Plebeyo", nil, { { PANTALON_NEGRO, "Pants" }, { TUNICA_ROTA, "Jacket" } }),
	conjunto("Aldeana", "Aldeana", "Plebeyo", "Mujer", { { BLUSA_LINO, "Shirt" }, { FALDA_VERDE, "DressSkirt" } }),
	conjunto(
		"AldeanaAzul",
		"Aldeana del río",
		"Plebeyo",
		"Mujer",
		{ { BLUSA_LINO, "Shirt" }, { FALDA_AZUL, "DressSkirt" } }
	),
	conjunto(
		"Tabernera",
		"Tabernera",
		"Plebeyo",
		"Mujer",
		{ { VESTIDO_BLANCO, "DressSkirt" }, { CORPINO_ROJO, "Jacket" } }
	),
	conjunto(
		"Curandera",
		"Curandera",
		"Plebeyo",
		"Mujer",
		{ { BLUSA_LINO, "Shirt" }, { FALDA_AZUL, "DressSkirt" }, { CORPINO_NEGRO, "Jacket" } }
	),
	conjunto(
		"Nordica",
		"Mujer del norte",
		"Plebeyo",
		"Mujer",
		{ { BLUSA_LINO, "Shirt" }, { FALDA_VERDE, "DressSkirt" }, { ABRIGO_PIEL_LARGO, "Jacket" } }
	),
	conjunto(
		"Viajera",
		"Viajera del desierto",
		"Plebeyo",
		"Mujer",
		{ { VESTIDO_BLANCO, "DressSkirt" } },
		{ sombrero = PANUELO_BEIGE }
	),
	-- Nobles
	conjunto(
		"Senor",
		"Señor del reino",
		"Noble",
		"Hombre",
		{ { CAMISA_BLANCA, "Shirt" }, { PANTALON_NOBLE, "Pants" }, { CHAQUETA_NOBLE, "Jacket" } },
		{ espalda = CAPA }
	),
	conjunto(
		"Emir",
		"Emir del sol",
		"Noble",
		"Hombre",
		{ { CAMISA_BLANCA2, "Shirt" }, { PANTALON_NOBLE, "Pants" }, { CHAQUETA_NOBLE, "Jacket" } },
		{ espalda = CAPA, sombrero = KEFIYEH_NEGRO }
	),
	conjunto(
		"Maestre",
		"Maestre oscuro",
		"Noble",
		"Hombre",
		{ { CAMISA_NEGRA, "Shirt" }, { PANTALON_NEGRO, "Pants" }, { TUNICA_VAMPIRO, "Jacket" } }
	),
	conjunto(
		"Jarl",
		"Jarl",
		"Noble",
		"Hombre",
		{ { CAMISA_CHALECO, "Shirt" }, { PANTALON_NEGRO, "Pants" }, { BOTAS, "Pants" }, { ABRIGO_PIEL_LARGO, "Jacket" } },
		{ espalda = CAPA }
	),
	conjunto("Dama", "Dama de la corte", "Noble", "Mujer", { { VESTIDO_PRINCESA, "DressSkirt" } }),
	conjunto(
		"DamaBaile",
		"Dama de baile",
		"Noble",
		"Mujer",
		{ { BLUSA_LINO, "Shirt" }, { VESTIDO_BAILE, "DressSkirt" } }
	),
	conjunto("Sayyida", "Sayyida", "Noble", "Mujer", { { VESTIDO_BLANCO, "DressSkirt" }, { REINA_SOL, "Jacket" } }),
	conjunto(
		"Jarlesa",
		"Jarlesa",
		"Noble",
		"Mujer",
		{ { BLUSA_LINO, "Shirt" }, { VESTIDO_BLANCO, "DressSkirt" }, { ABRIGO_PIEL_LARGO, "Jacket" } }
	),
	-- Realeza
	conjunto(
		"Rey",
		"Rey",
		"Realeza",
		"Hombre",
		{ { CAMISA_BLANCA, "Shirt" }, { PANTALON_NOBLE, "Pants" }, { TUNICA_REY, "Jacket" } },
		{ sombrero = CORONA, espalda = CAPA_REAL }
	),
	conjunto(
		"ReyNegro",
		"Rey de oro negro",
		"Realeza",
		"Hombre",
		{ { CAMISA_NEGRA, "Shirt" }, { PANTALON_NEGRO, "Pants" }, { TUNICA_REY_ORO, "Jacket" } },
		{ sombrero = CORONA2, espalda = CAPA_REAL2 }
	),
	conjunto(
		"Reina",
		"Reina",
		"Realeza",
		"Mujer",
		{ { VESTIDO_PRINCESA, "DressSkirt" } },
		{ sombrero = TIARA, espalda = CAPA_REAL2 }
	),
	conjunto(
		"ReinaSol",
		"Reina del sol",
		"Realeza",
		"Mujer",
		{ { VESTIDO_BLANCO, "DressSkirt" }, { REINA_SOL, "Jacket" } },
		{ sombrero = CORONA, espalda = CAPA_REAL }
	),
	-- Caballeros
	conjunto("Paladin", "Paladín", "Caballero", nil, { { CAMISA_BLANCA, "Shirt" }, { GREBAS, "Pants" }, { PLACAS_PLATA, "Jacket" } }, { sombrero = CASCO }),
	conjunto("CaballeroNegro", "Caballero negro", "Caballero", nil, { { CAMISA_NEGRA, "Shirt" }, { GREBAS2, "Pants" }, { PLACAS_NEGRAS, "Jacket" } }, { espalda = CAPA }),
	conjunto("CaballeroOro", "Caballero dorado", "Caballero", nil, { { CAMISA_BLANCA, "Shirt" }, { GREBAS, "Pants" }, { PLACAS_ORO, "Jacket" } }, { espalda = CAPA_REAL }),
	conjunto("Mercenario", "Mercenario", "Caballero", nil, { { CAMISA_CHALECO, "Shirt" }, { PANTALON_CUERO, "Pants" }, { BOTAS, "Pants" }, { BRIGANTINA, "Jacket" } }),
	-- Hechiceros
	conjunto(
		"Mago",
		"Mago",
		"Hechicero",
		nil,
		{ { CAMISA_NEGRA, "Shirt" }, { PANTALON_NEGRO, "Pants" }, { TUNICA_MAGO, "Jacket" } }
	),
	conjunto(
		"Ritualista",
		"Ritualista",
		"Hechicero",
		nil,
		{ { PANTALON_NEGRO, "Pants" }, { TUNICA_RITUAL, "Jacket" } }
	),
	conjunto(
		"Encapuchado",
		"Encapuchado",
		"Hechicero",
		nil,
		{ { PANTALON_NEGRO, "Pants" }, { CAPA_NEGRA_CAPUCHA, "Jacket" } }
	),
	conjunto(
		"Nigromante",
		"Nigromante",
		"Hechicero",
		"Hombre",
		{ { CAMISA_NEGRA, "Shirt" }, { PANTALON_NEGRO, "Pants" }, { TUNICA_VAMPIRO, "Jacket" } },
		{ espalda = CAPA }
	),
	conjunto(
		"Hechicera",
		"Hechicera",
		"Hechicero",
		"Mujer",
		{ { BLUSA_LINO, "Shirt" }, { FALDA_AZUL, "DressSkirt" }, { TUNICA_MAGO, "Jacket" } },
		{ espalda = CAPA }
	),
}

-- Búsqueda rápida por id
AparienciaConfig.ROPA_POR_ID = {}
for _, c in AparienciaConfig.ROPA do
	AparienciaConfig.ROPA_POR_ID[c.id] = c
end

-- =====================================================================================
-- EDITOR NUEVO (estilo "ropa pegada al cuerpo", 10 nov): cuerpo blocky, ropa clásica 2D que
-- se tiñe del color que elijas, caras de anime limpias y piezas de color (cinturón, botas,
-- capa). Lo usan los JUGADORES y los NPC (ReplicatedStorage/Personaje/Vestuario).
-- Las texturas las dibuja herramientas/texturas/generar.py; sus ids están en TexturasConfig.
-- (Los campos antiguos Cara/Pelo/Ropa de arriba solo los usan las estatuas de los santuarios.)
-- =====================================================================================

-- Caras (decal pegado a la cabeza): { nombre, textura }
AparienciaConfig.ROSTROS = {
	{ nombre = "Sereno", textura = "Cara_Sereno" },
	{ nombre = "Decidido", textura = "Cara_Decidido" },
	{ nombre = "Frío", textura = "Cara_Frio" },
	{ nombre = "Alegre", textura = "Cara_Alegre" },
	{ nombre = "Cicatriz", textura = "Cara_Cicatriz" },
	{ nombre = "Fiero", textura = "Cara_Fiero" },
	{ nombre = "Cansado", textura = "Cara_Cansado" },
	{ nombre = "Pícaro", textura = "Cara_Picaro" },
	{ nombre = "Dulce", textura = "Cara_Dulce" },
	{ nombre = "Seria", textura = "Cara_Seria" },
	{ nombre = "Kawaii", textura = "Cara_Kawaii" },
	{ nombre = "Altiva", textura = "Cara_Altiva" },
	{ nombre = "Tímida", textura = "Cara_Timida" },
	{ nombre = "Guerrera", textura = "Cara_Guerrera" },
	{ nombre = "Feliz", textura = "Cara_Feliz" },
	{ nombre = "Mirada intensa", textura = "Cara_Intensa" },
	{ nombre = "Anciano", textura = "Cara_Anciano" },
	{ nombre = "Anciana", textura = "Cara_Anciana" },
}

-- Peinados (accesorios de pelo del catálogo que quedan bien en la cabeza de bloque).
-- largo: "corto" / "medio" / "largo" (los NPC los eligen según su género y edad)
local function peinado(id, nombre, largo)
	return { id = id, nombre = nombre, largo = largo }
end
AparienciaConfig.PEINADOS = {
	peinado(376548738, "Encantador", "corto"),
	peinado(63690008, "Clásico", "corto"),
	peinado(15014232630, "Flequillo de lado", "corto"),
	peinado(7259123616, "De punta", "corto"),
	peinado(13703147645, "Revuelto plateado", "medio"),
	peinado(13344398396, "Puntas salvajes", "corto"),
	peinado(13344419310, "Puntas al viento", "corto"),
	peinado(13470543305, "Desgreñado", "medio"),
	peinado(13470517204, "Esponjoso", "medio"),
	peinado(13832965098, "Erizado", "corto"),
	peinado(16035727009, "Melena corta", "medio"),
	peinado(16035736147, "Melena de viajero", "medio"),
	peinado(115737585210553, "Revuelto con cinta", "medio"),
	peinado(71700007644840, "Despeinado", "corto"),
	peinado(103920542547489, "Corto suave", "corto"),
	peinado(89820590521613, "Rebelde", "corto"),
	peinado(121765361106908, "Nube", "medio"),
	peinado(96443323483601, "Revuelto oscuro", "corto"),
	peinado(118723832058600, "Lobo", "medio"),
	peinado(104843739858929, "Capas", "medio"),
	peinado(16843016178, "Capas cortas", "corto"),
	peinado(123854646485044, "Mechones", "corto"),
	peinado(117172360554785, "Corto liso", "corto"),
	peinado(129270793158942, "Tormenta", "medio"),
	peinado(94552462259427, "Canoso", "medio"),
	peinado(114281663326892, "Escarcha", "corto"),
	peinado(12519986, "Larga lisa", "largo"),
	peinado(376526888, "Recogido alto", "largo"),
	peinado(13251161977, "Trenza de lado", "largo"),
	peinado(107474706603976, "Ondas largas", "largo"),
	peinado(6005348300, "Melena suelta", "largo"),
	peinado(80569506402913, "Larga con raya", "largo"),
	peinado(376527350, "Coleta", "largo"),
	peinado(83017698423383, "Trenza nórdica", "largo"),
	peinado(14318307127, "Dos coletas", "largo"),
	peinado(16786816274, "Capas con cinta", "largo"),
	peinado(107401286109725, "Media melena con cinta", "medio"),
	peinado(15562726354, "Corta con cinta", "medio"),
	peinado(106622928023364, "Trenza larga", "largo"),
	peinado(123443007883823, "Cascada", "largo"),
	peinado(106224556552187, "Larga y lisa", "largo"),
	peinado(126238504554914, "Capas largas", "largo"),
	peinado(91475401630194, "Dos trenzas", "largo"),
	peinado(101813639772503, "Ondas suaves", "largo"),
	peinado(139223857317624, "Trenza sencilla", "largo"),
	peinado(119134757613825, "Lisa hasta la cintura", "largo"),
	peinado(17718240769, "Melena de fuego", "largo"),
	peinado(128062901974898, "Ondas de seda", "largo"),
}

-- Tocados: cintas, diademas, pañuelos y capuchas. tipo: "Face" (cara) o "Hat" (sombrero)
local function tocado(id, nombre, tipo)
	return { id = id, nombre = nombre, tipo = tipo or "Hat" }
end
AparienciaConfig.TOCADOS = {
	tocado(14928047806, "Cinta negra", "Face"),
	tocado(15152195582, "Cinta rosa", "Face"),
	tocado(14592583905, "Cinta crema", "Face"),
	tocado(14014090020, "Diadema enjoyada"),
	tocado(98114166297637, "Diadema de plata"),
	tocado(100571372227310, "Diadema de rubí"),
	tocado(104938188029156, "Diadema élfica"),
	tocado(83974006543009, "Diadema de acólito"),
	tocado(78102957630719, "Pañuelo de cuero"),
	tocado(109915361196257, "Pañuelo negro"),
	tocado(123519343539916, "Capucha negra"),
	tocado(112167366913866, "Capucha de viaje"),
	tocado(110038468772852, "Capucha azul"),
}

-- Ropa clásica 2D (se tiñe del color elegido). textura = nombre en TexturasConfig.
AparienciaConfig.CAMISAS = {
	{ nombre = "Túnica", textura = "Camisa_Tunica" },
	{ nombre = "Camisa de lino", textura = "Camisa_Lino" },
	{ nombre = "Gambesón", textura = "Camisa_Gambeson" },
	{ nombre = "Chaqueta de viaje", textura = "Camisa_Chaqueta" },
	{ nombre = "Túnica de mago", textura = "Camisa_Mago" },
	{ nombre = "Blusa y corpiño", textura = "Camisa_Corpino" },
	{ nombre = "Cota de malla", textura = "Camisa_Malla" },
	{ nombre = "Abrigo de pieles", textura = "Camisa_Pieles" },
	{ nombre = "Ropa del desierto", textura = "Camisa_Desierto" },
	{ nombre = "Chaleco", textura = "Camisa_Chaleco" },
	{ nombre = "Sobreveste", textura = "Camisa_Sobreveste" },
	{ nombre = "Harapos", textura = "Camisa_Harapos" },
}
AparienciaConfig.PANTALONES = {
	{ nombre = "Calzas", textura = "Pantalon_Calzas" },
	{ nombre = "Pantalón de cuero", textura = "Pantalon_Cuero" },
	{ nombre = "Bombachos", textura = "Pantalon_Bombacho" },
	{ nombre = "Falda larga", textura = "Pantalon_Falda" },
	{ nombre = "Faldón", textura = "Pantalon_Faldon" },
	{ nombre = "Acolchado", textura = "Pantalon_Acolchado" },
}
-- Piezas de color (se construyen con bloques encima del cuerpo). La 0 es "ninguno".
AparienciaConfig.CINTURONES = { "Cinturón de cuero", "Fajín", "Correas cruzadas" }
AparienciaConfig.BOTAS = { "Botas cortas", "Botas altas", "Botas de montar" }
AparienciaConfig.CAPAS = { "Capa corta", "Capa larga", "Capa con esclavina" }

-- 16 colores rápidos (como en el selector de color) y los del pelo natural
AparienciaConfig.COLORES_RAPIDOS = {
	"#1E1A1C", "#3B2A20", "#6B4A2E", "#A0764A", "#D8C29A", "#F2EDE4",
	"#7A1E22", "#B5462E", "#C9A23A", "#4E6B2E", "#2E5A4E", "#2E4A7A",
	"#4B3A78", "#7A3A6A", "#5C6670", "#A8B0B8",
}
AparienciaConfig.COLORES_PELO = {
	"#1A1614", "#3A2618", "#5C3A22", "#8A5A32", "#B88A4E", "#E3C78A",
	"#F1E6CC", "#A8402A", "#D06A2E", "#8C8C94", "#E8E8EC", "#2E3E6E",
}

-- Apariencia de un personaje nuevo
function AparienciaConfig.PorDefecto()
	return {
		Genero = "Hombre",
		Piel = 3,
		Altura = 1,
		-- editor nuevo
		Rostro = 1,
		Peinado = 1,
		Peinado2 = 0,
		PeloColor = "#3A2618",
		Tocado = 0,
		Barba = 0, -- 0 = sin barba
		Camisa = 1,
		CamisaColor = "#7A1E22",
		Pantalon = 1,
		PantalonColor = "#3B2A20",
		Cinturon = 1,
		CinturonColor = "#3B2A20",
		Botas = 1,
		BotasColor = "#1E1A1C",
		Capa = 0,
		CapaColor = "#2E4A7A",
		-- antiguos (solo estatuas)
		Cara = 1,
		Pelo = 1,
		Ropa = "Campesino",
	}
end

-- Completa una apariencia guardada con los campos que le falten (partidas antiguas)
function AparienciaConfig.Completar(apariencia)
	local base = AparienciaConfig.PorDefecto()
	if type(apariencia) ~= "table" then
		return base
	end
	for campo, valor in base do
		if apariencia[campo] == nil or not AparienciaConfig.EsValido(campo, apariencia[campo]) then
			apariencia[campo] = valor
		end
	end
	return apariencia
end

local function esColor(valor)
	return type(valor) == "string" and string.match(valor, "^#%x%x%x%x%x%x$") ~= nil
end

local function indice(lista, valor, conCero)
	return type(valor) == "number"
		and valor == math.floor(valor)
		and ((conCero and valor == 0) or (valor >= 1 and valor <= #lista))
end

-- ¿Es válido este valor para este campo? (lo usa el servidor antes de guardar)
function AparienciaConfig.EsValido(campo, valor)
	if campo == "Genero" then
		return valor == "Hombre" or valor == "Mujer"
	elseif campo == "Piel" then
		return indice(AparienciaConfig.PIELES, valor)
	elseif campo == "Altura" then
		return type(valor) == "number" and valor >= 0.92 and valor <= 1.08
	elseif campo == "Rostro" then
		return indice(AparienciaConfig.ROSTROS, valor)
	elseif campo == "Peinado" or campo == "Peinado2" then
		return indice(AparienciaConfig.PEINADOS, valor, true)
	elseif campo == "Tocado" then
		return indice(AparienciaConfig.TOCADOS, valor, true)
	elseif campo == "Barba" then
		return indice(AparienciaConfig.BARBAS, valor, true)
	elseif campo == "Camisa" then
		return indice(AparienciaConfig.CAMISAS, valor)
	elseif campo == "Pantalon" then
		return indice(AparienciaConfig.PANTALONES, valor)
	elseif campo == "Cinturon" then
		return indice(AparienciaConfig.CINTURONES, valor, true)
	elseif campo == "Botas" then
		return indice(AparienciaConfig.BOTAS, valor, true)
	elseif campo == "Capa" then
		return indice(AparienciaConfig.CAPAS, valor, true)
	elseif campo == "PeloColor" then
		return valor == "" or esColor(valor) -- "" = color natural del pelo
	elseif
		campo == "CamisaColor"
		or campo == "PantalonColor"
		or campo == "CinturonColor"
		or campo == "BotasColor"
		or campo == "CapaColor"
	then
		return esColor(valor)
	-- antiguos (estatuas)
	elseif campo == "Cara" then
		return indice(AparienciaConfig.CARAS, valor)
	elseif campo == "Pelo" then
		return indice(AparienciaConfig.PELOS, valor, true)
	elseif campo == "Ropa" then
		return type(valor) == "string" and AparienciaConfig.ROPA_POR_ID[valor] ~= nil
	end
	return false
end

-- Miniatura del catálogo para enseñar una opción
function AparienciaConfig.Miniatura(id)
	return "rbxthumb://type=Asset&id=" .. tostring(id) .. "&w=150&h=150"
end

-- ===== Animaciones de movimiento (para todos: jugadores y NPC) =====
-- Paquete "adidas Sports" del catálogo de Roblox: grabado con captura de movimiento,
-- es el más fluido y natural. Se ponen en la HumanoidDescription (AparienciaServicio).
-- Para probar otro paquete, cambia los números (ver los paquetes en el catálogo de Roblox).
AparienciaConfig.ANIMACIONES = {
	IdleAnimation = 18538150608, -- reposo (respira, cambia el peso de pierna)
	WalkAnimation = 18538146480, -- caminar
	RunAnimation = 18538133604, -- correr
	JumpAnimation = 18538153691, -- saltar
	FallAnimation = 18538164337, -- caer
	ClimbAnimation = 18538170170, -- trepar
	SwimAnimation = 18538158932, -- nadar
}
-- Otros paquetes de Roblox, por si los quieres comparar:
--   Rthro:  reposo 2510235063, caminar 2510242378, correr 2510238627, saltar 2510236649, caer 2510233257
--   Knight: reposo 734327140,  caminar 734326330,  correr 734325948,  saltar 734326930,  caer 734326679
--   Ninja:  reposo 658832408,  caminar 658831143,  correr 658830056,  saltar 658832070,  caer 658831500

-- Animación de DESCANSO: cuando el personaje lleva un rato quieto (fuera de combate)
-- se pone a descansar. Son gestos ("emotes") gratis de Roblox.
AparienciaConfig.DESCANSO = {
	Descanso = 5230661597, -- "Bored": suspira y cambia de postura
	Estirarse = 3360692915, -- "Tilt": se estira de lado
}

return AparienciaConfig

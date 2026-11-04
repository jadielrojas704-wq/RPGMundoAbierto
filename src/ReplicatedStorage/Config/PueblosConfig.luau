-- Ciudades, imperios y aldeas del mundo, con sus NPC.
-- Ruta en Studio: ReplicatedStorage/Config/PueblosConfig
--
-- ¡LOS NOMBRES SON PROVISIONALES! Cámbialos aquí cuando quieras (campo "nombre").
-- Si cambias un nombre, vuelve a generar el mundo para que salga en los carteles.
--
-- Cada región tiene su cultura, que decide la arquitectura, los colores y la ropa de los NPC:
--   Reino  -> Bosque normal: reino de caballeros (piedra clara, techos azules, estandartes rojos)
--   Sol    -> Desierto: imperio del sol (arenisca, cúpulas doradas, toldos de colores)
--   Brujos -> Bosque oscuro: ciudad de brujos y nigromantes (madera negra, faroles morados)
--   Norte  -> Montañas: fortaleza nórdica de herreros (piedra gris, troncos, forjas, nieve)
--
-- pista  = punto aproximado (X, Z). El generador busca cerca el sitio más llano y seco.
-- radio  = tamaño del pueblo en studs (un personaje mide unos 5)
-- tiendas = tipos de tienda (ver TiendasConfig): Herrero, Armaduras, Armas, Pociones, Establo

local PueblosConfig = {}

PueblosConfig.CULTURAS = {
	Reino = {
		nombre = "Reino de los caballeros",
		bandera = Color3.fromRGB(150, 28, 32), -- estandartes rojos con oro
		detalle = Color3.fromRGB(214, 170, 72),
	},
	Sol = {
		nombre = "Imperio del sol",
		bandera = Color3.fromRGB(36, 120, 132), -- turquesa y oro
		detalle = Color3.fromRGB(226, 172, 58),
	},
	Brujos = {
		nombre = "Ciudad de los brujos",
		bandera = Color3.fromRGB(70, 30, 96), -- morado y verde espectral
		detalle = Color3.fromRGB(150, 90, 255),
	},
	Norte = {
		nombre = "Fortaleza del norte",
		bandera = Color3.fromRGB(40, 64, 98), -- azul hielo y hierro
		detalle = Color3.fromRGB(190, 200, 210),
	},
}

PueblosConfig.PUEBLOS = {
	-- ===== BOSQUE NORMAL: Reino de los caballeros =====
	{
		id = "Valdoria",
		nombre = "Valdoria",
		titulo = "Capital del Reino",
		tipo = "Capital",
		cultura = "Reino",
		pista = Vector2.new(-150, 170),
		radio = 100,
		tiendas = { "Herrero", "Armaduras", "Armas", "Pociones", "Establo" },
	},
	{
		id = "Robledal",
		nombre = "Robledal",
		titulo = "Aldea del molino",
		tipo = "Aldea",
		cultura = "Reino",
		pista = Vector2.new(190, 640),
		radio = 52,
		tiendas = { "Pociones", "Establo" },
	},
	{
		id = "BrezoAlto",
		nombre = "Brezo Alto",
		titulo = "Aldea de leñadores",
		tipo = "Aldea",
		cultura = "Reino",
		pista = Vector2.new(170, -200),
		radio = 50,
		tiendas = { "Herrero" },
	},

	-- ===== DESIERTO: Imperio del sol =====
	{
		id = "Solkhar",
		nombre = "Solkhar",
		titulo = "Capital del Imperio del Sol",
		tipo = "Capital",
		cultura = "Sol",
		pista = Vector2.new(650, 40),
		radio = 100,
		tiendas = { "Herrero", "Armaduras", "Armas", "Pociones", "Establo" },
	},
	{
		id = "Zahra",
		nombre = "Zahra",
		titulo = "Aldea del oasis",
		tipo = "Aldea",
		cultura = "Sol",
		pista = Vector2.new(560, 430),
		radio = 50,
		tiendas = { "Pociones", "Establo" },
	},
	{
		id = "Qadim",
		nombre = "Qadim",
		titulo = "Aldea de las caravanas",
		tipo = "Aldea",
		cultura = "Sol",
		pista = Vector2.new(780, -330),
		radio = 50,
		tiendas = { "Armas" },
	},

	-- ===== BOSQUE OSCURO: Ciudad de los brujos =====
	{
		id = "Nocthar",
		nombre = "Nocthar",
		titulo = "Ciudad de los brujos",
		tipo = "Capital",
		cultura = "Brujos",
		pista = Vector2.new(-620, -60),
		radio = 100,
		tiendas = { "Herrero", "Armaduras", "Armas", "Pociones", "Establo" },
	},
	{
		id = "Velamuerta",
		nombre = "Velamuerta",
		titulo = "Aldea de las velas",
		tipo = "Aldea",
		cultura = "Brujos",
		pista = Vector2.new(-470, 430),
		radio = 50,
		tiendas = { "Pociones" },
	},
	{
		id = "CienagaGris",
		nombre = "Ciénaga Gris",
		titulo = "Aldea del pantano",
		tipo = "Aldea",
		cultura = "Brujos",
		pista = Vector2.new(-800, -320),
		radio = 50,
		tiendas = { "Establo", "Armaduras" },
	},

	-- ===== MONTAÑAS: Fortaleza del norte =====
	{
		id = "Kaldheim",
		nombre = "Kaldheim",
		titulo = "Fortaleza de los herreros",
		tipo = "Capital",
		cultura = "Norte",
		pista = Vector2.new(300, -700),
		radio = 95,
		tiendas = { "Herrero", "Armaduras", "Armas", "Pociones", "Establo" },
	},
	{
		id = "Skarvik",
		nombre = "Skarvik",
		titulo = "Aldea de cazadores",
		tipo = "Aldea",
		cultura = "Norte",
		pista = Vector2.new(-320, -660),
		radio = 48,
		tiendas = { "Establo" },
	},
	{
		id = "Hielofragua",
		nombre = "Hielofragua",
		titulo = "Aldea minera",
		tipo = "Aldea",
		cultura = "Norte",
		pista = Vector2.new(640, -580),
		radio = 48,
		tiendas = { "Herrero", "Pociones" },
	},
}

-- ===== NPC =====
-- Nombres y frases de los NPC según la cultura y su oficio (también provisionales).
-- El generador elige al azar un nombre de la lista para cada NPC.
PueblosConfig.NOMBRES = {
	Reino = { "Aldric", "Bertrand", "Edmund", "Gwendolyn", "Isolde", "Roderick", "Mathilde", "Osric", "Elena", "Godfrey" },
	Sol = { "Rashid", "Yasmin", "Karim", "Leila", "Tariq", "Samira", "Hakim", "Nadira", "Zafir", "Amara" },
	Brujos = { "Morwen", "Silas", "Vesper", "Ravenna", "Thorne", "Lilith", "Corvin", "Nyx", "Mortimer", "Hexa" },
	Norte = { "Bjorn", "Astrid", "Ragnar", "Sigrid", "Ulf", "Freya", "Gunnar", "Ingrid", "Halvar", "Solveig" },
}

PueblosConfig.OFICIOS = {
	Herrero = { titulo = "Herrero", tienda = "Herrero" },
	Armaduras = { titulo = "Armero", tienda = "Armaduras" },
	Armas = { titulo = "Mercader de armas", tienda = "Armas" },
	Pociones = { titulo = "Alquimista", tienda = "Pociones" },
	Establo = { titulo = "Mozo de establo", tienda = "Establo" },
	Guardia = { titulo = "Guardia" },
	Aldeano = { titulo = "Aldeano" },
}

-- Frases. {pueblo} se cambia por el nombre del pueblo.
PueblosConfig.FRASES = {
	Reino = {
		Guardia = {
			"Bienvenido a {pueblo}, viajero. Mantén la espada envainada dentro de las murallas.",
			"Los caminos no son seguros desde que algo se agita en el bosque oscuro. Ten cuidado.",
		},
		Aldeano = {
			"¡Buen día! El pan de {pueblo} es el mejor del valle.",
			"Dicen que al norte hay un altar antiguo con tres sellos apagados... cuentos de viejos, supongo.",
			"Mi abuelo juraba que vio una isla flotando entre las nubes.",
		},
		Herrero = { "El acero del reino no se dobla. ¿Necesitas que forje algo?" },
		Armaduras = { "Una buena armadura es la diferencia entre volver a casa o no volver." },
		Armas = { "Espadas de caballero, lanzas de la guardia, arcos largos... elige con cuidado." },
		Pociones = { "Hierbas del valle y agua del río. Mis pociones curan casi todo." },
		Establo = { "Nuestros caballos son fuertes y fieles. Llegarás a cualquier rincón del reino." },
	},
	Sol = {
		Guardia = {
			"Que el sol te guíe en {pueblo}. Aquí el agua vale más que el oro.",
			"Las tormentas de arena llegan sin avisar. Busca refugio cuando el viento sople fuerte.",
		},
		Aldeano = {
			"Las caravanas traen sedas y especias de muy lejos.",
			"De noche el desierto es frío y hermoso. Mira las estrellas, viajero.",
			"Bajo las dunas duermen ciudades antiguas, eso dicen los ancianos.",
		},
		Herrero = { "El fuego del desierto templa el mejor acero curvo." },
		Armaduras = { "Escamas doradas, ligeras como la seda y duras como la roca." },
		Armas = { "Cimitarras, dagas y lanzas del imperio. Lo mejor de {pueblo}." },
		Pociones = { "Elixires de cactus y miel de palmera. Te refrescan hasta el alma." },
		Establo = { "Un camello no se cansa nunca. Un caballo del desierto corre como el viento." },
	},
	Brujos = {
		Guardia = {
			"Entra en {pueblo} si te atreves. Aquí la muerte es solo el principio.",
			"No mires fijamente a los faroles morados... a veces miran de vuelta.",
		},
		Aldeano = {
			"Las velas no se apagan nunca en {pueblo}. Los muertos necesitan luz.",
			"Los nigromantes dicen que se puede hablar con los caídos... y algo más.",
			"Escucha el pantano por la noche. Susurra nombres.",
		},
		Herrero = { "Forjo con hierro negro y lágrimas de luna. No preguntes de dónde salen." },
		Armaduras = { "Túnicas de hechicero y capas de sombra. Te ocultan de ojos indeseados." },
		Armas = { "Bastones que canalizan el maná y dagas que beben la sangre." },
		Pociones = { "Burbujea, ¿lo ves? Esta poción está viva. Casi." },
		Establo = { "Mis lobos sombríos son leales... mientras los alimentes." },
	},
	Norte = {
		Guardia = {
			"¡Por las forjas de {pueblo}! Nadie cruza estas murallas sin permiso.",
			"El frío mata más que las espadas aquí arriba. Abrígate bien.",
		},
		Aldeano = {
			"Las montañas guardan hierro, plata... y bestias que es mejor no despertar.",
			"Cuando cae la nieve, cantamos junto al fuego del gran salón.",
			"Mi padre forjó la espada de un rey. Algún día yo forjaré la de un héroe.",
		},
		Herrero = { "Las mejores forjas del mundo están en {pueblo}. Mi martillo no descansa." },
		Armaduras = { "Pieles de oso y hierro rúnico. Nada te atravesará." },
		Armas = { "Espadas, escudos y lanzas norteñas, forjadas para aguantar el invierno." },
		Pociones = { "Hidromiel y raíces de montaña. Calientan el cuerpo y cierran heridas." },
		Establo = { "Los carneros de montaña trepan donde ningún caballo se atreve." },
	},
}

function PueblosConfig.PorId(id)
	for _, pueblo in PueblosConfig.PUEBLOS do
		if pueblo.id == id then
			return pueblo
		end
	end
	return nil
end

return PueblosConfig

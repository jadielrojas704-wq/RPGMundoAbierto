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
-- rasgo  = (aldeas) lo que hace única a la aldea: Molino, Aserradero, Bazar, Caravana,
--          Velas, Pilotes, Cazadores, Mina

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
		radio = 74,
		rasgo = "Molino",
		tiendas = { "Pociones", "Establo" },
	},
	{
		id = "BrezoAlto",
		nombre = "Brezo Alto",
		titulo = "Aldea de leñadores",
		tipo = "Aldea",
		cultura = "Reino",
		pista = Vector2.new(170, -200),
		radio = 74,
		rasgo = "Aserradero",
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
		radio = 74,
		rasgo = "Bazar",
		tiendas = { "Pociones", "Establo" },
	},
	{
		id = "Qadim",
		nombre = "Qadim",
		titulo = "Aldea de las caravanas",
		tipo = "Aldea",
		cultura = "Sol",
		pista = Vector2.new(780, -330),
		radio = 74,
		rasgo = "Caravana",
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
		radio = 74,
		rasgo = "Velas",
		tiendas = { "Pociones" },
	},
	{
		id = "CienagaGris",
		nombre = "Ciénaga Gris",
		titulo = "Aldea del pantano",
		tipo = "Aldea",
		cultura = "Brujos",
		pista = Vector2.new(-800, -320),
		radio = 74,
		rasgo = "Pilotes",
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
		radio = 68,
		rasgo = "Cazadores",
		tiendas = { "Establo" },
	},
	{
		id = "Hielofragua",
		nombre = "Hielofragua",
		titulo = "Aldea minera",
		tipo = "Aldea",
		cultura = "Norte",
		pista = Vector2.new(640, -580),
		radio = 68,
		rasgo = "Mina",
		tiendas = { "Herrero", "Pociones" },
	},
}

-- ===== NPC =====
-- Todo esto son PROPUESTAS (nombres, oficios y frases): cámbialas cuando quieras.
-- Cada NPC tiene: género (Hombre/Mujer), clase (Noble o Plebeyo) y un papel:
--   Tendero  -> se queda en su tienda
--   Guardia  -> vigila la puerta de la ciudad
--   Paseante -> camina por el pueblo, vive en una casa y de noche se va a dormir
PueblosConfig.NOMBRES = {
	Reino = {
		Hombre = { "Aldric", "Bertrand", "Edmund", "Roderick", "Osric", "Godfrey", "Tristan", "Cedric", "Alaric", "Benedict", "Percival", "Wilhelm" },
		Mujer = { "Gwendolyn", "Isolde", "Mathilde", "Elena", "Rowena", "Beatrix", "Agnes", "Cecily", "Eleanor", "Marian", "Odette", "Rosalind" },
	},
	Sol = {
		Hombre = { "Rashid", "Karim", "Tariq", "Hakim", "Zafir", "Omar", "Faris", "Jamal", "Nasir", "Idris", "Malik", "Samir" },
		Mujer = { "Yasmin", "Leila", "Samira", "Nadira", "Amara", "Zahira", "Farah", "Layla", "Soraya", "Rania", "Inaya", "Dalia" },
	},
	Brujos = {
		Hombre = { "Silas", "Thorne", "Corvin", "Mortimer", "Lucian", "Ambrose", "Cassius", "Dorian", "Ezra", "Malachai", "Severin", "Vale" },
		Mujer = { "Morwen", "Vesper", "Ravenna", "Lilith", "Nyx", "Hexa", "Selene", "Morgana", "Ophelia", "Circe", "Isadora", "Belladonna" },
	},
	Norte = {
		Hombre = { "Bjorn", "Ragnar", "Ulf", "Gunnar", "Halvar", "Leif", "Sven", "Torvald", "Erik", "Harald", "Sigurd", "Arne" },
		Mujer = { "Astrid", "Sigrid", "Freya", "Ingrid", "Solveig", "Helga", "Thyra", "Gudrun", "Ylva", "Runa", "Eira", "Hilde" },
	},
}

-- Título de los nobles (va delante del nombre)
PueblosConfig.TITULOS_NOBLES = {
	Reino = { Hombre = "Lord", Mujer = "Lady" },
	Sol = { Hombre = "Emir", Mujer = "Sayyida" },
	Brujos = { Hombre = "Maestre", Mujer = "Dama" },
	Norte = { Hombre = "Jarl", Mujer = "Jarlesa" },
}

-- Oficios de la gente común (plebeyos) que pasea por el pueblo: { hombre, mujer }
PueblosConfig.TRABAJOS = {
	Reino = { { "Campesino", "Campesina" }, { "Leñador", "Leñadora" }, { "Panadero", "Panadera" }, { "Molinero", "Molinera" }, { "Lavandero", "Lavandera" } },
	Sol = { { "Aguador", "Aguadora" }, { "Tejedor", "Tejedora" }, { "Vendedor de especias", "Vendedora de especias" }, { "Pastor", "Pastora" }, { "Alfarero", "Alfarera" } },
	Brujos = { { "Velero", "Velera" }, { "Herbolario", "Herbolaria" }, { "Sepulturero", "Sepulturera" }, { "Aprendiz de brujo", "Aprendiz de bruja" } },
	Norte = { { "Cazador", "Cazadora" }, { "Minero", "Minera" }, { "Pescador", "Pescadora" }, { "Leñador", "Leñadora" }, { "Curtidor", "Curtidora" } },
}

PueblosConfig.OFICIOS = {
	Herrero = { titulo = "Herrero", tienda = "Herrero" },
	Armaduras = { titulo = "Armero", tienda = "Armaduras" },
	Armas = { titulo = "Mercader de armas", tienda = "Armas" },
	Pociones = { titulo = "Alquimista", tienda = "Pociones" },
	Establo = { titulo = "Mozo de establo", tienda = "Establo" },
	Guardia = { titulo = "Guardia" },
	Aldeano = { titulo = "Aldeano" },
	Noble = { titulo = "Noble" },
}

-- Frases al hablar con ellos. {pueblo} se cambia por el nombre del pueblo.
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
			"Los nobles se quedan con la mitad de la cosecha. Y aún se quejan.",
		},
		Noble = {
			"¿Quién te ha dado permiso para dirigirte a mí? ...Bah, habla rápido.",
			"Mi familia lleva siete generaciones gobernando estas tierras. Muestra respeto.",
			"El rey confía en nosotros para mantener el orden. Y el orden tiene un precio.",
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
			"El emir bebe agua fresca mientras nosotros cargamos los cántaros al sol.",
		},
		Noble = {
			"El oro de {pueblo} pasa por mis manos antes que por las de nadie.",
			"Mis jardines tienen más agua que todo el barrio bajo. Así es el orden del sol.",
			"Habla, extranjero, pero no me hagas perder el tiempo.",
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
			"Los maestres nos usan para sus experimentos. Nadie se atreve a decir nada.",
		},
		Noble = {
			"Tu alma brilla poco, viajero. Qué decepción.",
			"La Torre decide quién vive y quién sirve. Tú pareces de los que sirven.",
			"Mis ancestros siguen conmigo. Literalmente.",
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
			"El jarl se queda con las mejores pieles. Nosotros, con el frío.",
		},
		Noble = {
			"En el norte manda el más fuerte. Y yo sigo aquí.",
			"Mis antepasados vinieron por el mar helado. Los tuyos, ¿de dónde?",
			"Si quieres honor, gánatelo con sangre. Si quieres pan, trabaja para mí.",
		},
		Herrero = { "Las mejores forjas del mundo están en {pueblo}. Mi martillo no descansa." },
		Armaduras = { "Pieles de oso y hierro rúnico. Nada te atravesará." },
		Armas = { "Espadas, escudos y lanzas norteñas, forjadas para aguantar el invierno." },
		Pociones = { "Hidromiel y raíces de montaña. Calientan el cuerpo y cierran heridas." },
		Establo = { "Los carneros de montaña trepan donde ningún caballo se atreve." },
	},
}

-- Lo que dice un plebeyo si le hablas justo después de que un noble lo humillara
PueblosConfig.FRASES_HUMILLADO = {
	Reino = { "¿Lo has visto? Ese noble se cree dueño de todo... y de todos.", "No digas nada, por favor. Si me quejo, me quitarán la casa." },
	Sol = { "Me ha tirado el cántaro... Un día los de abajo dejaremos de agachar la cabeza.", "Aquí el que tiene oro tiene razón. Así es {pueblo}." },
	Brujos = { "Me ha mirado con esos ojos... Todavía tiemblo.", "Los maestres hacen lo que quieren con nosotros. Nadie los detiene." },
	Norte = { "En el norte se respeta al fuerte... pero eso no fue fuerza, fue abuso.", "Tranquilo, me levanto. Los norteños no lloramos. Mucho." },
}

-- Frases cortas que dicen en voz alta al cruzarse contigo (globo sobre la cabeza)
PueblosConfig.SALUDOS = {
	Reino = {
		Plebeyo = { "¡Buen día!", "Que la cosecha sea buena.", "¿Otro forastero? Bienvenido.", "Cuidado con el barro." },
		Noble = { "Apártate.", "Hmph.", "¿Me conoces? Deberías.", "Qué olor a establo..." },
	},
	Sol = {
		Plebeyo = { "Que el sol te guíe.", "¿Agua fresca? ...No, no me queda.", "Bienvenido, viajero.", "Qué calor hoy..." },
		Noble = { "No me tapes el sol.", "Hmph.", "Extranjero...", "Mis sandalias valen más que tu vida." },
	},
	Brujos = {
		Plebeyo = { "No te quedes mucho...", "Las velas te protegen.", "Shhh. Escucha.", "Bienvenido... supongo." },
		Noble = { "Tu alma es aburrida.", "Hmph.", "Interesante...", "No me toques." },
	},
	Norte = {
		Plebeyo = { "¡Salud!", "Abrígate, forastero.", "Hace un frío de mil demonios.", "¡Por las forjas!" },
		Noble = { "Débil.", "Hmph.", "¿Sabes quién soy?", "Fuera de mi camino." },
	},
}

-- ===== ESCENAS: cosas que pasan solas en los pueblos cuando hay jugadores cerca =====
-- Abuso: un noble humilla a un plebeyo (lo empuja y se burla). Un testigo comenta.
-- Chisme: dos vecinos se cuentan rumores.
PueblosConfig.ESCENAS = {
	Reino = {
		Abuso = {
			noble = { "¡Apártate de mi camino, campesino!", "¿Me has manchado la capa? ¡Arrodíllate!", "Vuelve a tu pocilga, que es donde perteneces." },
			plebeyo = { "P-perdón, mi señor...", "No fue mi intención, mi señor...", "..." },
			testigo = "Siempre igual con los nobles...",
		},
		Chisme = {
			{ "¿Te has enterado? Dicen que alguien vio luz en el Altar del Ascenso.", "Bah, serán los cuervos. Ese altar lleva siglos muerto." },
			{ "Mi primo dice que en el bosque oscuro los muertos caminan.", "Tu primo dice muchas cosas cuando bebe." },
			{ "Otra vez subió el impuesto del trigo.", "Y el lord estrena caballo. Qué casualidad." },
		},
	},
	Sol = {
		Abuso = {
			noble = { "¡Fuera de mi sombra, aguador!", "¿Te atreves a mirarme a los ojos?", "Recoge eso del suelo. Con la boca, si hace falta." },
			plebeyo = { "Mil perdones, noble emir...", "Solo llevaba agua, señor...", "..." },
			testigo = "Que el sol nos dé paciencia...",
		},
		Chisme = {
			{ "Anoche una caravana entera desapareció en las dunas.", "La tormenta de arena se traga lo que quiere." },
			{ "El emir ha comprado otra esposa con oro del templo.", "Baja la voz, que aquí las paredes oyen." },
			{ "Dicen que bajo el palacio hay un río escondido.", "Por eso nunca les falta agua a ellos..." },
		},
	},
	Brujos = {
		Abuso = {
			noble = { "¿Respiras sin mi permiso, gusano?", "Podría convertirte en vela ahora mismo.", "Arrástrate. Me divierte." },
			plebeyo = { "N-no, maestre, perdone...", "Por favor, no me haga daño...", "..." },
			testigo = "Mejor no mirar... Mañana podríamos ser nosotros.",
		},
		Chisme = {
			{ "Se han llevado a otro vecino a la Torre.", "Ya no volverá. Nunca vuelven." },
			{ "Las velas del cementerio se encendieron solas.", "Eso es que alguien ha muerto... o que va a morir." },
			{ "Dicen que el orbe de la Torre mira a todo el pueblo.", "Pues sonríe, que te está mirando ahora." },
		},
	},
	Norte = {
		Abuso = {
			noble = { "¡Quita de en medio, rata de la mina!", "¿Tú? ¿Mirarme? Ja.", "Al suelo, que es donde duermen los débiles." },
			plebeyo = { "Perdón, jarl...", "Solo pasaba, señor...", "..." },
			testigo = "El frío endurece a todos... menos el corazón del jarl.",
		},
		Chisme = {
			{ "Han oído rugidos en la mina vieja.", "Será el viento en los túneles... espero." },
			{ "El herrero dice que el hierro rúnico canta cuando lo golpea.", "El herrero bebe más hidromiel que nadie." },
			{ "Este invierno será el más largo en cien años.", "Pues que el jarl comparta la leña, para variar." },
		},
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

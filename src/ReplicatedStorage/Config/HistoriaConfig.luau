-- Historia del juego: EL ECLIPSE ETERNO (decidida por el usuario, documento claude/diseno-historia.md).
-- Ruta en Studio: ReplicatedStorage/Config/HistoriaConfig
-- Aquí están los Guardianes, los textos antiguos que se leen en las ruinas, los santuarios,
-- las misiones del Acto 1, lo que dice el Custodio y el guion de la cinemática del prólogo.
-- Lo usan el servidor (ServerScriptService/Historia) y el cliente (HistoriaCliente).
--
-- Los NOMBRES de lugares y personajes nuevos (Custodio Eldren, textos, misiones) son
-- propuestas: se pueden cambiar aquí sin tocar el código.

local HistoriaConfig = {}

-- ===== Los seis Guardianes Primordiales =====
HistoriaConfig.GUARDIANES = {
	Ignar = { nombre = "Ignar", dominio = "Fuego", color = Color3.fromRGB(255, 120, 50) },
	Lunaria = { nombre = "Lunaria", dominio = "Luz", color = Color3.fromRGB(255, 240, 190) },
	Morvak = { nombre = "Morvak", dominio = "Muerte", color = Color3.fromRGB(150, 110, 220) },
	Sylvaris = { nombre = "Sylvaris", dominio = "Vida", color = Color3.fromRGB(110, 230, 140) },
	Tempus = { nombre = "Tempus", dominio = "Espacio", color = Color3.fromRGB(120, 170, 255) },
	Aetherion = { nombre = "Aetherion", dominio = "Tiempo", color = Color3.fromRGB(200, 60, 255), traidor = true },
}

HistoriaConfig.COLOR_ECLIPSE = Color3.fromRGB(170, 60, 255)
-- Dónde está el Eclipse en el cielo (dirección desde el jugador): al norte, sobre los Picos del Velo
HistoriaConfig.ECLIPSE_DIRECCION = Vector3.new(0.18, 0.4, -1).Unit

-- ===== Textos antiguos (se leen con G en las ruinas) =====
HistoriaConfig.TEXTOS = {
	SylvarisEstela = {
		titulo = "Inscripción de Sylvaris",
		subtitulo = "Santuario de la Vida · Valle de Aurelia",
		texto = "Éramos seis, y el mundo respiraba entre nuestras manos.\nIgnar daba el fuego, Lunaria la luz, Morvak guardaba a los muertos, Tempus sostenía el espacio y Aetherion medía el tiempo. Yo, Sylvaris, hacía brotar la vida.\n\nSi lees esto, el sello se debilita. Busca a mis hermanos. No confíes en las voces que prometen eternidad.",
	},
	SylvarisTablilla = {
		titulo = "Tablilla agrietada",
		subtitulo = "Santuario de la Vida",
		texto = "...las raíces de este valle beben de mi último aliento. Mientras crezcan árboles aquí, una parte de mí seguirá vigilando...",
	},
	IgnarEstela = {
		titulo = "Inscripción de Ignar",
		subtitulo = "Santuario del Fuego · Dunas de Kharsa",
		texto = "Mi fuego quemó montañas enteras en la Guerra de los Guardianes. No me arrepiento.\nAetherion era mi hermano, y aun así lo enfrenté. Lo que hablaba por su boca ya no era él.\n\nEl desierto que pisas fue un bosque antes de nuestra batalla.",
	},
	IgnarTablilla = {
		titulo = "Diario de un explorador",
		subtitulo = "Encontrado entre las ruinas",
		texto = 'Día 12. La arena aquí está caliente incluso de noche. Los guías del Imperio del Sol no quieren acercarse. Dicen que la piedra "recuerda" el fuego de un dios.',
	},
	MorvakEstela = {
		titulo = "Inscripción de Morvak",
		subtitulo = "Santuario de la Muerte · Bosque Sombrío de Morvane",
		texto = "Yo guardaba el paso entre la vida y la muerte. Por eso fui el primero en verlos: humanos que no morían.\nSu sangre había bebido del Eclipse. Se curaban de cualquier herida, pero el sol los quemaba como castigo.\n\nLos llamamos vampiros. Fueron los primeros en caer. No serán los últimos.",
	},
	MorvakTablilla = {
		titulo = "Lápida sin nombre",
		subtitulo = "Santuario de la Muerte",
		texto = '"Aquí descansa quien quiso vivir para siempre.\nNo cavéis. No está muerto."',
	},
	LunariaEstela = {
		titulo = "Inscripción de Lunaria",
		subtitulo = "Santuario de la Luz · Picos del Velo",
		texto = "Cuando el Eclipse tocó el mundo, el cielo se apagó durante cien días.\nAetherion nos dijo que era el precio de la paz: sin guerras, sin enfermedad, sin muerte. Sonaba tan sabio...\n\nNo quería destruirnos. Quería que fuéramos parte de él.",
	},
	LunariaTablilla = {
		titulo = "Oración tallada",
		subtitulo = "Santuario de la Luz",
		texto = "Que la luz del alba nunca se apague.\nQue ningún sello se rompa mientras quede un solo valiente.",
	},
	SelloGrieta = {
		titulo = "La grieta del sello",
		subtitulo = "Altar del Ascenso",
		texto = "Cinco dimos nuestra esencia para encerrarlo. Aetherion duerme bajo este altar, y con él una parte del Eclipse.\n\nTres sellos protegen la puerta del cielo. Uno por cada tierra que juramos proteger.\nSi la piedra sangra luz morada, el sello se está rompiendo.\n\nLa piedra sangra luz morada.",
	},
}

-- ===== Santuarios (los construye ServerScriptService/Historia/RuinasServicio) =====
-- posicion = (X, Z): el servidor busca el suelo debajo. Lejos de los pueblos.
HistoriaConfig.SANTUARIOS = {
	{
		id = "Sylvaris",
		guardian = "Sylvaris",
		nombre = "Santuario de Sylvaris",
		posicion = Vector2.new(60, 400),
		estela = "SylvarisEstela",
		tablilla = "SylvarisTablilla",
	},
	{
		id = "Ignar",
		guardian = "Ignar",
		nombre = "Santuario de Ignar",
		posicion = Vector2.new(850, 220),
		estela = "IgnarEstela",
		tablilla = "IgnarTablilla",
	},
	{
		id = "Morvak",
		guardian = "Morvak",
		nombre = "Santuario de Morvak",
		posicion = Vector2.new(-800, 200),
		estela = "MorvakEstela",
		tablilla = "MorvakTablilla",
	},
	{
		id = "Lunaria",
		guardian = "Lunaria",
		nombre = "Santuario de Lunaria",
		posicion = Vector2.new(-80, -800),
		estela = "LunariaEstela",
		tablilla = "LunariaTablilla",
	},
}
-- Tempus (Espacio) espera en la Isla Celestial: se añadirá cuando se pueda subir a ella.

-- La grieta del sello del Eclipse, junto al Altar del Ascenso
HistoriaConfig.SELLO = { posicion = Vector2.new(34, -404), texto = "SelloGrieta" }

-- ===== El Custodio (NPC de la historia, junto a la aparición) =====
HistoriaConfig.CUSTODIO = {
	nombre = "Eldren",
	titulo = "Custodio del Sello",
	desplazamiento = Vector3.new(16, 0, -10), -- desde el punto de aparición
}

-- ===== Misiones del Acto 1: "El sello se agrieta" =====
-- Tipos de objetivo:
--   Hablar   (con el Custodio)
--   Golpes   (cantidad de golpes a los muñecos o a enemigos)
--   Leer     (lista de textos)
--   Visitar  (un pueblo por su nombre)
-- recompensa = { Exp, Oro, GirosRaza, GirosAfinidad }
-- dialogo = lo que dice el Custodio AL COMPLETAR esa misión (por el amuleto, estés donde estés)
HistoriaConfig.ACTO = "Acto I · El sello se agrieta"
HistoriaConfig.MISIONES = {
	{
		id = "Despertar",
		titulo = "Dos días de sueño",
		descripcion = "Despiertas en una cabaña que no conoces. Un anciano vela junto al fuego.",
		objetivo = { tipo = "Despertar", texto = "Despierta" },
		recompensa = { Exp = 60 },
		-- lo que se dice aquí sale en la cinemática del despertar (DESPERTAR, más abajo)
	},
	{
		id = "Ritual",
		titulo = "El viejo ritual",
		descripcion = "Eldren quiere ver si aún sabes pelear antes de contarte nada más.",
		objetivo = { tipo = "Golpes", cantidad = 15, texto = "Golpea a los muñecos de paja frente a la cabaña" },
		recompensa = { Exp = 120, Oro = 25 },
		dialogo = {
			"Nada mal. Tus puños guardan una energía que no veía desde hace muchos años.",
			"Escucha bien. Hace miles de años, seis Guardianes protegían este mundo. Uno de ellos nos traicionó.",
			"Al noreste, siguiendo el arroyo, hay un santuario de Sylvaris, la Guardiana de la Vida. Lee lo que dejó escrito en la piedra.",
		},
	},
	{
		id = "EcosSylvaris",
		titulo = "Ecos de Sylvaris",
		descripcion = "El santuario de la Guardiana de la Vida guarda una inscripción.",
		objetivo = {
			tipo = "Leer",
			textos = { "SylvarisEstela" },
			texto = "Lee la inscripción del Santuario de Sylvaris",
		},
		recompensa = { Exp = 180, GirosAfinidad = 1 },
		dialogo = {
			"Así que es verdad... los Guardianes dejaron mensajes para quien supiera buscarlos.",
			"Si el sello se rompe, lo primero que notaremos serán los rumores. Ve al norte, a Valdoria, la capital, y escucha a su gente.",
		},
	},
	{
		id = "Rumores",
		titulo = "Rumores en la capital",
		descripcion = "En Valdoria se habla de luces extrañas en el norte.",
		objetivo = { tipo = "Visitar", pueblo = "Valdoria", texto = "Viaja a Valdoria, la capital" },
		recompensa = { Exp = 150, Oro = 40 },
		dialogo = {
			"Luz morada sobre el Altar del Ascenso... es justo lo que temía.",
			"El altar está más al norte, al pie de los Picos del Velo. Allí duerme el traidor. Ve y examina la piedra.",
		},
	},
	{
		id = "Grieta",
		titulo = "La grieta del norte",
		descripcion = "El Altar del Ascenso, al pie de los Picos del Velo, guarda el sello del Eclipse.",
		objetivo = {
			tipo = "Leer",
			textos = { "SelloGrieta" },
			texto = "Examina la grieta del sello en el Altar del Ascenso",
		},
		recompensa = { Exp = 300, GirosRaza = 1 },
		dialogo = {
			"Aetherion... el Guardián del Tiempo. El más sabio de todos. Y el que nos condenó.",
			"Los otros Guardianes dejaron santuarios en cada tierra: Ignar en las dunas del este, Morvak en el bosque sombrío del oeste y Lunaria en lo alto de los picos.",
			"Si alguien puede volver a cerrar el sello, será quien entienda lo que pasó.",
		},
	},
	{
		id = "Perdidos",
		titulo = "Los Guardianes perdidos",
		descripcion = "Ignar, Morvak y Lunaria dejaron su verdad escrita en piedra.",
		objetivo = {
			tipo = "Leer",
			textos = { "IgnarEstela", "MorvakEstela", "LunariaEstela" },
			texto = "Lee las inscripciones de Ignar, Morvak y Lunaria",
		},
		recompensa = { Exp = 600, Oro = 150, GirosRaza = 1, GirosAfinidad = 1 },
		dialogo = {
			"No quiere destruirnos... quiere fusionarse con el mundo. Que todo sea parte de él.",
			"Los tres sellos del altar siguen apagados. Para encenderlos habrá que enfrentarse a lo que el Eclipse ha despertado.",
			"Descansa. Lo que viene ahora será mucho más duro.",
		},
	},
}

-- ===== Cinemática del DESPERTAR (la primera vez, justo después del prólogo) =====
-- toma = qué enseña la cámara (la programa ReplicatedStorage/Interfaz/Despertar)
-- quien = "Eldren" (habla con su voz) o nil (sin voz)
HistoriaConfig.DESPERTAR = {
	lineas = {
		{ toma = "Ojos", duracion = 5.5 },
		{ toma = "Eldren", quien = "Eldren", texto = "Por fin abres los ojos. Tranquilo, estás a salvo." },
		{
			toma = "Fuego",
			quien = "Eldren",
			texto = "Te encontré inconsciente en el río, la noche en que el cielo tembló. Llevas dos días durmiendo en mi cabaña.",
		},
		{
			toma = "Ventana",
			quien = "Eldren",
			texto = "Me llamo Eldren. Mi familia custodia el sello del Eclipse desde hace mil generaciones.",
		},
		{
			toma = "Levantarse",
			quien = "Eldren",
			texto = "Cuando te saqué del agua, en tu piel brillaba una luz morada. Esa luz te ha elegido... y eso nunca ocurre por azar.",
		},
		{
			toma = "Amuleto",
			quien = "Eldren",
			texto = "Toma este amuleto. A través de él podré hablarte, estés donde estés.",
		},
		{
			toma = "Puerta",
			quien = "Eldren",
			texto = "Ahora sal. Ahí fuera hay unos muñecos de paja. Quiero ver si aún sabes pelear.",
		},
	},
}

-- Cuando se acaban las misiones del acto, el Custodio dice esto:
HistoriaConfig.FIN_DEL_ACTO = {
	"Los sellos siguen apagados. Pronto los monstruos del Eclipse saldrán de sus guaridas.",
	"(Fin del Acto I. La historia continúa en las próximas actualizaciones.)",
}

-- ===== Cinemática del prólogo (la primera vez que se pulsa Jugar) =====
-- lugar: dónde mira la cámara. "Cielo", "Altar", "Picos", "Capital", "Inicio".
HistoriaConfig.PROLOGO = {
	{
		lugar = "Cielo",
		duracion = 6.5,
		texto = "Hace miles de años, seis Guardianes Primordiales mantenían el equilibrio del mundo.",
	},
	{ lugar = "Cielo2", duracion = 6, texto = "Fuego. Luz. Muerte. Vida. Espacio. Tiempo." },
	{
		lugar = "Altar",
		duracion = 6.5,
		texto = "Pero más allá del mundo existía algo que incluso ellos temían.\nLos textos antiguos lo llamaban: El Eclipse.",
	},
	{
		lugar = "Eclipse",
		duracion = 7,
		texto = "Aetherion, el Guardián del Tiempo, el más sabio de todos, tocó su poder.\nCreyó que podría salvar a la humanidad. Se equivocaba.",
	},
	{
		lugar = "Picos",
		duracion = 6.5,
		texto = "La Guerra de los Guardianes partió montañas y cambió los océanos.\nCinco Guardianes dieron su esencia para sellarlo.",
	},
	{ lugar = "Capital", duracion = 6.5, texto = "Miles de años después, la historia se convirtió en leyenda..." },
	{ lugar = "Inicio", duracion = 6.5, texto = "...y el sello empieza a romperse.\nAquella noche, el cielo tembló sobre el Valle de Aurelia." },
}

-- Busca una misión por su número
function HistoriaConfig.Mision(numero)
	return HistoriaConfig.MISIONES[numero]
end

return HistoriaConfig

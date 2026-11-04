-- Tiendas: qué vende cada tipo de tienda en cada cultura y a qué precio (en monedas de oro).
-- Ruta en Studio: ReplicatedStorage/Config/TiendasConfig
--
-- ¡OJO! Por ahora las tiendas se pueden VER pero todavía no se puede comprar:
-- la compra (con oro e inventario guardado) llega en el siguiente paso.
-- Los objetos, nombres y precios son PROPUESTAS: cámbialos cuando quieras.
--
-- Cada cultura vende objetos con su propio estilo:
--   Reino  -> acero de caballero, cotas de malla, caballos
--   Sol    -> armas curvas, escamas doradas, camellos
--   Brujos -> bastones, túnicas, lobos sombríos
--   Norte  -> hierro rúnico, pieles, carneros de montaña

local TiendasConfig = {}

-- Datos generales de cada tipo de tienda
TiendasConfig.TIPOS = {
	Herrero = { nombre = "Herrería", descripcion = "Mejora y forja de armas" },
	Armaduras = { nombre = "Armería", descripcion = "Armaduras y ropas de viaje" },
	Armas = { nombre = "Tienda de armas", descripcion = "Armas para cada estilo de combate" },
	Pociones = { nombre = "Alquimista", descripcion = "Pociones de vida, maná y estamina" },
	Establo = { nombre = "Establo", descripcion = "Animales y monturas" },
}

-- arma = una de las armas del juego (ver Config/Constantes)
local function arma(nombre, tipo, precio, descripcion)
	return { nombre = nombre, categoria = "Arma", arma = tipo, precio = precio, descripcion = descripcion }
end
local function armadura(nombre, peso, precio, descripcion)
	return { nombre = nombre, categoria = "Armadura", peso = peso, precio = precio, descripcion = descripcion }
end
local function pocion(nombre, precio, descripcion)
	return { nombre = nombre, categoria = "Pocion", precio = precio, descripcion = descripcion }
end
local function montura(nombre, precio, descripcion)
	return { nombre = nombre, categoria = "Montura", precio = precio, descripcion = descripcion }
end
local function servicio(nombre, precio, descripcion)
	return { nombre = nombre, categoria = "Servicio", precio = precio, descripcion = descripcion }
end

TiendasConfig.CATALOGO = {
	Reino = {
		Herrero = {
			servicio("Afilar arma", 40, "Mejora el daño de tu arma un poco (+1)."),
			servicio("Forjar acero del reino", 250, "Mejora grande de un arma de acero."),
			servicio("Reparar escudo", 25, "Deja tu escudo como nuevo."),
		},
		Armaduras = {
			armadura("Cota de malla", "Media", 180, "Equilibrio entre defensa y movilidad."),
			armadura("Armadura de placas del caballero", "Pesada", 520, "Mucha defensa, esquivas más lentas."),
			armadura("Jubón acolchado", "Ligera", 70, "Ligero y cómodo para viajar."),
		},
		Armas = {
			arma("Espada y escudo de caballero", "EspadaYEscudo", 200, "Defensiva y paciente: bloqueo y empujón."),
			arma("Lanza de la guardia", "Lanza", 180, "Gran alcance y guardia que castiga."),
			arma("Arco largo del valle", "Arco", 160, "Tensa más para más daño."),
			arma("Doble espadas del duelista", "DobleEspadas", 240, "Cada golpe seguido es más rápido."),
		},
		Pociones = {
			pocion("Poción de vida pequeña", 15, "Recupera un poco de vida."),
			pocion("Poción de vida", 40, "Recupera bastante vida."),
			pocion("Tónico de estamina", 25, "Recupera estamina al instante."),
		},
		Establo = {
			montura("Caballo castaño", 300, "Fuerte y fiel, ideal para empezar."),
			montura("Corcel blanco del reino", 900, "Rápido y elegante, de la caballería real."),
		},
	},
	Sol = {
		Herrero = {
			servicio("Templar al fuego del desierto", 60, "Mejora el filo de un arma curva (+1)."),
			servicio("Incrustar oro solar", 320, "Mejora grande con adornos de oro."),
		},
		Armaduras = {
			armadura("Ropas del desierto", "Ligera", 60, "Frescas: aguantas mejor el calor."),
			armadura("Armadura de escamas doradas", "Media", 380, "Ligera como la seda, dura como la roca."),
			armadura("Coraza del guardia solar", "Pesada", 560, "La armadura de la guardia imperial."),
		},
		Armas = {
			arma("Katana del sol poniente", "Katana", 300, "Iaido: envaina, carga y corta al instante."),
			arma("Doble dagas de la arena", "DobleDagas", 190, "Rápidas: sangrado y puñalada por la espalda."),
			arma("Cimitarras gemelas", "DobleEspadas", 260, "Flujo y ritmo: cada golpe más rápido."),
			arma("Lanza del imperio", "Lanza", 200, "Alcance y control del espacio."),
		},
		Pociones = {
			pocion("Elixir de cactus", 20, "Recupera vida y quita la sed."),
			pocion("Miel de palmera", 30, "Recupera estamina poco a poco."),
			pocion("Agua de oasis encantada", 55, "Recupera maná."),
		},
		Establo = {
			montura("Camello de caravana", 280, "Lento pero incansable en las dunas."),
			montura("Caballo del desierto", 850, "Corre como el viento sobre la arena."),
		},
	},
	Brujos = {
		Herrero = {
			servicio("Forja de hierro negro", 70, "Mejora un arma con hierro maldito (+1)."),
			servicio("Grabar runas de sombra", 360, "Mejora grande para bastones y dagas."),
		},
		Armaduras = {
			armadura("Túnica del aprendiz", "Ligera", 80, "Más maná, poca defensa."),
			armadura("Capa de sombras", "Ligera", 300, "Te ocultas mejor en la oscuridad."),
			armadura("Armadura de hueso", "Media", 420, "Hecha con restos de criaturas antiguas."),
		},
		Armas = {
			arma("Bastón de roble muerto", "BastonMagico", 180, "Hechizos con maná que se combinan."),
			arma("Bastón del nigromante", "BastonMagico", 650, "Para los que hablan con los caídos."),
			arma("Dagas sedientas", "DobleDagas", 230, "Beben la sangre de tus enemigos."),
		},
		Pociones = {
			pocion("Poción de maná", 30, "Recupera maná."),
			pocion("Antídoto del pantano", 25, "Cura el veneno."),
			pocion("Elixir burbujeante", 90, "Recupera vida y maná a la vez."),
		},
		Establo = {
			montura("Lobo sombrío", 600, "Rápido y silencioso entre los árboles."),
			montura("Caballo espectral", 1200, "Medio vivo, medio sombra."),
		},
	},
	Norte = {
		Herrero = {
			servicio("Martillo de Kaldheim", 50, "Mejora cualquier arma (+1)."),
			servicio("Forjar hierro rúnico", 400, "La mejor mejora de todas las herrerías."),
			servicio("Reparar armadura", 30, "Deja tu armadura como nueva."),
		},
		Armaduras = {
			armadura("Abrigo de pieles", "Ligera", 90, "Abriga: aguantas mejor el frío."),
			armadura("Armadura de hierro rúnico", "Pesada", 600, "La armadura más dura del mundo."),
			armadura("Cota norteña", "Media", 260, "Malla de hierro con pieles de oso."),
		},
		Armas = {
			arma("Espada y escudo norteño", "EspadaYEscudo", 230, "Escudo redondo y espada ancha."),
			arma("Lanza del cazador de osos", "Lanza", 210, "Para mantener a las bestias lejos."),
			arma("Arco de tejo", "Arco", 190, "Potente incluso con el viento de la montaña."),
		},
		Pociones = {
			pocion("Hidromiel curativa", 25, "Recupera vida y calienta el cuerpo."),
			pocion("Raíz de montaña", 35, "Recupera estamina."),
			pocion("Elixir contra el frío", 40, "Aguantas mucho más el frío."),
		},
		Establo = {
			montura("Carnero de montaña", 400, "Trepa donde ningún caballo se atreve."),
			montura("Caballo de las nieves", 800, "Pelaje grueso, nunca resbala en el hielo."),
		},
	},
}

-- Lo que vende una tienda concreta (cultura + tipo)
function TiendasConfig.Objetos(cultura, tipo)
	local deCultura = TiendasConfig.CATALOGO[cultura]
	return deCultura and deCultura[tipo] or {}
end

return TiendasConfig

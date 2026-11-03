-- Constantes globales del juego. Fuente única de verdad.
-- Ruta en Studio: ReplicatedStorage/Config/Constantes

local Constantes = {}

Constantes.NIVEL_MAXIMO = 499
Constantes.MAX_JUGADORES = 20

-- Atributos base de todos los personajes
Constantes.ATRIBUTOS = { "Vida", "Fuerza", "Destreza", "Inteligencia" }

-- Armas del juego (según diseño)
Constantes.ARMAS = {
	"DobleDagas",
	"DobleEspadas",
	"Katana",
	"EspadaYEscudo",
	"Arco",
	"BastonMagico",
	"Lanza",
}

return Constantes

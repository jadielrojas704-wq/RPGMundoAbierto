-- Constantes globales del juego. Fuente única de verdad.
-- Ruta en Studio: ReplicatedStorage/Config/Constantes

local Constantes = {}

Constantes.NIVEL_MAXIMO = 499
Constantes.MAX_JUGADORES = 20

-- Atributos en los que el jugador reparte puntos (decidido el 4 nov 2026).
-- Maná, Estamina y Defensa NO se reparten: se calculan solas (ver Progresion/Formulas).
--   VIT = Vitalidad (vida)      STR = Fuerza         DEX = Destreza
--   INT = Inteligencia          LUK = Suerte         SPD = Velocidad
Constantes.ATRIBUTOS = { "VIT", "STR", "DEX", "INT", "LUK", "SPD" }

-- Las 10 armas del juego (según diseño, 4 nov 2026). "SinArmas" es lo que usas sin arma.
Constantes.ARMAS = {
	"SinArmas",
	"DobleDagas",
	"DobleEspadas",
	"Katana",
	"EspadaYEscudo",
	"Arco",
	"BastonMagico",
	"Lanza",
	"Guadana",
	"Guantes",
}

return Constantes

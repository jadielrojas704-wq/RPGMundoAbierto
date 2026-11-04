-- Valores de la progresión del personaje (niveles, atributos, maestrías, profesiones...).
-- Ruta en Studio: ReplicatedStorage/Config/ProgresionConfig
-- Cambia los números aquí para ajustar el ritmo del juego. Los usan el servidor
-- (para calcular de verdad) y el cliente (para mostrar vistas previas en el menú).

local Constantes = require(script.Parent.Constantes)

local ProgresionConfig = {}

ProgresionConfig.NIVEL_MAXIMO = Constantes.NIVEL_MAXIMO -- 499
ProgresionConfig.PUNTOS_POR_NIVEL = 3
ProgresionConfig.ATRIBUTO_INICIAL = 5 -- todos los atributos empiezan en 5

-- Experiencia necesaria para pasar del nivel n al n + 1  (propuesta: 100 × n^1.5)
function ProgresionConfig.ExpParaSubir(nivel)
	return math.floor(100 * nivel ^ 1.5)
end

-- Elementos de las afinidades (PROVISIONAL: el usuario puede cambiar la lista).
-- Una afinidad sube usando ese elemento y lo hace más fuerte.
ProgresionConfig.ELEMENTOS = { "Fuego", "Hielo", "Rayo", "Viento", "Tierra", "Luz", "Sombra" }

-- Profesiones del CharacterData
ProgresionConfig.PROFESIONES = { "Herreria", "Alquimia", "Mineria", "Encantamiento" }

-- Niveles máximos de cada cosa
ProgresionConfig.MAESTRIA_MAXIMA = 50
ProgresionConfig.AFINIDAD_MAXIMA = 50
ProgresionConfig.DOMINIO_MAXIMO = 50
ProgresionConfig.PROFESION_MAXIMA = 100

-- Experiencia para subir una maestría, afinidad, dominio o profesión del nivel n al n + 1
function ProgresionConfig.ExpParaSubirOficio(nivel)
	return math.floor(50 * (nivel + 1) ^ 1.35)
end

-- Rendimientos decrecientes: los primeros 40 puntos cuentan enteros, de 40 a 100 cuentan
-- la mitad y a partir de 100 cuentan un cuarto. Así nadie rompe el juego en el nivel 499.
ProgresionConfig.TRAMOS = {
	{ hasta = 40, valor = 1 },
	{ hasta = 100, valor = 0.5 },
	{ hasta = math.huge, valor = 0.25 },
}

-- Cuánto da cada punto "efectivo" de atributo (ver Progresion/Formulas)
ProgresionConfig.EFECTOS = {
	VIDA_BASE = 100,
	VIDA_POR_VIT = 18,
	ESTAMINA_BASE = 100,
	ESTAMINA_POR_VIT = 1.2,
	ESTAMINA_POR_SPD = 1.0,
	REGEN_ESTAMINA_POR_SPD = 0.004, -- +0.4 % de recuperación por punto
	MANA_BASE = 100,
	MANA_POR_INT = 6,
	REGEN_MANA_BASE = 5, -- maná por segundo
	REGEN_MANA_POR_INT = 0.05,
	DEFENSA_POR_VIT = 2,
	DEFENSA_K = 200, -- reducción de daño = Defensa / (Defensa + DEFENSA_K)
	DANO_POR_STR = 0.02, -- +2 % de daño físico (armas de fuerza)
	DANO_POR_DEX = 0.02, -- +2 % de daño físico (armas de destreza)
	DANO_POR_INT = 0.025, -- +2.5 % de daño mágico
	VELOCIDAD_ATAQUE_POR_DEX = 0.002,
	VELOCIDAD_ATAQUE_MAXIMA = 0.15,
	VELOCIDAD_POR_SPD = 0.004,
	VELOCIDAD_MAXIMA = 0.25, -- +25 % de velocidad de movimiento como mucho
	CRITICO_BASE = 0.05,
	CRITICO_POR_LUK = 0.003,
	CRITICO_MAXIMO = 0.40,
	BOTIN_POR_LUK = 0.004, -- +0.4 % de objetos raros y oro por punto
}

-- Qué atributo hace más fuerte a cada arma (como en el documento de arquitectura)
ProgresionConfig.ESCALADO_ARMAS = {
	SinArmas = { DEX = 0.6, SPD = 0.4 },
	DobleDagas = { DEX = 1 },
	DobleEspadas = { DEX = 0.6, STR = 0.4 },
	Katana = { DEX = 1 },
	EspadaYEscudo = { STR = 1 },
	Arco = { DEX = 1 },
	BastonMagico = { INT = 1 },
	Lanza = { STR = 0.5, DEX = 0.5 },
	Guadana = { STR = 0.6, INT = 0.4 },
	Guantes = { STR = 1 },
}

-- Lugar donde aparece un personaje nuevo (o si su ubicación guardada no vale)
ProgresionConfig.APARICION_INICIAL = Vector3.new(-110, 60, 560)

-- Guardado
ProgresionConfig.AUTOGUARDADO = 120 -- segundos entre guardados automáticos
ProgresionConfig.GUARDAR_UBICACION = 10 -- cada cuánto se apunta la última posición segura

return ProgresionConfig

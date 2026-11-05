-- Datos de los golpes de cada arma (tiempos, alcance, daño...). Los usan el SERVIDOR
-- (para comprobar y medir los golpes de verdad) y el cliente (para animar a tiempo).
-- Ruta en Studio: ReplicatedStorage/Config/ArmasConfig
--
-- Cada golpe:
--   Duracion   segundos que dura la animación entera
--   Activo     segundo en el que el golpe "conecta" (el servidor mide ahí)
--   Alcance    hasta dónde llega por delante (studs); Ancho y Alto de la caja de golpe
--   Dano       daño base (luego se multiplica por los atributos: ProgresionConfig.ESCALADO_ARMAS)
--   Postura    cuánta postura le quita al enemigo
--   Empuje     velocidad del empujón (studs/s); Elevar = lanzarlo hacia arriba
--   Reaccion   "Leve", "Fuerte", "Lanzado" (cómo reacciona el que lo recibe)
--   Tipo       "Puno", "Patada", "Pesado" (cambia el sonido y el efecto del impacto)
--   Estamina   lo que cuesta
--   Avance     cuánto avanza el atacante con el golpe (studs)

local ArmasConfig = {}

ArmasConfig.SinArmas = {
	Nombre = "Sin armas",
	VentanaCombo = 0.6, -- al terminar un golpe, tiempo que tienes para seguir el combo
	Combo = {
		{
			Id = "Jab",
			Duracion = 0.42,
			Activo = 0.15,
			Alcance = 5.5,
			Ancho = 4.5,
			Alto = 5.5,
			Dano = 9,
			Postura = 5,
			Empuje = 7,
			Elevar = 0,
			Reaccion = "Leve",
			Tipo = "Puno",
			Estamina = 5,
			Avance = 2,
		},
		{
			Id = "Directo",
			Duracion = 0.5,
			Activo = 0.2,
			Alcance = 6,
			Ancho = 4.5,
			Alto = 5.5,
			Dano = 12,
			Postura = 7,
			Empuje = 10,
			Elevar = 0,
			Reaccion = "Leve",
			Tipo = "Puno",
			Estamina = 6,
			Avance = 3,
		},
		{
			Id = "Gancho",
			Duracion = 0.52,
			Activo = 0.21,
			Alcance = 5.5,
			Ancho = 6,
			Alto = 5.5,
			Dano = 14,
			Postura = 9,
			Empuje = 12,
			Elevar = 0,
			Reaccion = "Fuerte",
			Tipo = "Puno",
			Estamina = 7,
			Avance = 2.5,
		},
		{
			Id = "Patada",
			Duracion = 0.62,
			Activo = 0.3,
			Alcance = 7.5,
			Ancho = 7.5,
			Alto = 6,
			Dano = 18,
			Postura = 13,
			Empuje = 22,
			Elevar = 0,
			Reaccion = "Fuerte",
			Tipo = "Patada",
			Estamina = 9,
			Avance = 2,
		},
		{
			Id = "Uppercut",
			Duracion = 0.68,
			Activo = 0.3,
			Alcance = 5.5,
			Ancho = 5,
			Alto = 6,
			Dano = 22,
			Postura = 16,
			Empuje = 6,
			Elevar = 42,
			Reaccion = "Lanzado",
			Tipo = "Puno",
			Estamina = 10,
			Avance = 3,
		},
	},
	-- Mantener el ataque: carga un puñetazo enorme (más carga = más daño y empuje)
	Pesado = {
		Id = "GolpeCargado",
		Duracion = 0.62,
		Activo = 0.14,
		Alcance = 8,
		Ancho = 5.5,
		Alto = 6,
		Dano = 30,
		Postura = 32,
		Empuje = 55,
		Elevar = 8,
		Reaccion = "Fuerte",
		Tipo = "Pesado",
		Estamina = 20,
		Avance = 8,
		CargaMinima = 0.25, -- segundos manteniendo para que sea golpe cargado
		CargaMaxima = 1.2, -- a partir de aquí ya no carga más
		Multiplicador = 1.2, -- a carga máxima hace Dano × (1 + 1.2)
	},
}

-- Congelado de impacto (hitstop) según el tipo de golpe, en segundos
ArmasConfig.HITSTOP = { Leve = 0.05, Fuerte = 0.075, Lanzado = 0.09, Pesado = 0.13 }

-- Cuánto tiempo sigues "en combate" (postura de guardia) tras pelear
ArmasConfig.TIEMPO_EN_COMBATE = 6

return ArmasConfig

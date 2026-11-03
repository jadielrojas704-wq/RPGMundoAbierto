-- Valores de combate compartidos por servidor y cliente.
-- Ruta en Studio: ReplicatedStorage/Config/CombateConfig
-- Cambia los números aquí para ajustar cómo se siente el combate.

local CombateConfig = {}

CombateConfig.Estamina = {
	MAXIMA = 100,
	REGEN_POR_SEGUNDO = 30, -- cuánta estamina recupera por segundo
	RETRASO_REGEN = 0.8, -- segundos sin gastar antes de empezar a recuperar
	FRECUENCIA_ACTUALIZACION = 0.1, -- cada cuánto el servidor actualiza la estamina
}

CombateConfig.Esquiva = {
	COSTO_ESTAMINA = 20,
	INVULNERABILIDAD = 0.35, -- segundos en los que no recibes daño (i-frames)
	ENFRIAMIENTO = 0.75, -- tiempo mínimo entre esquivas
	TECLA = Enum.KeyCode.Q,
	BOTON_MANDO = Enum.KeyCode.ButtonB,

	-- Tipos de esquiva:
	--   Rodar     -> caminando hacia delante o atrás (W/S + Q)
	--   Lateral   -> caminando de lado (A/D + Q): voltereta lateral acrobática
	--   PasoAtras -> sin moverte (solo Q): salto corto hacia atrás
	-- DURACION: segundos que dura | VELOCIDAD: impulso inicial (studs/s)
	-- FRENADO: cuánto frena al final (0 = nada, 1 = se detiene del todo)
	TIPOS = {
		Rodar = { DURACION = 0.55, VELOCIDAD = 44, FRENADO = 0.75 },
		Lateral = { DURACION = 0.6, VELOCIDAD = 40, FRENADO = 0.7 },
		PasoAtras = { DURACION = 0.38, VELOCIDAD = 34, FRENADO = 0.9 },
	},
}

return CombateConfig

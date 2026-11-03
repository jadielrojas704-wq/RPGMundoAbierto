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
	DURACION = 0.55, -- cuánto dura la voltereta completa
	INVULNERABILIDAD = 0.35, -- segundos en los que no recibes daño (i-frames)
	ENFRIAMIENTO = 0.75, -- tiempo mínimo entre esquivas
	VELOCIDAD = 44, -- velocidad al lanzarse (studs por segundo)
	FRENADO = 0.75, -- cuánto frena al final (0 = nada, 1 = se detiene del todo)
	TECLA = Enum.KeyCode.Q,
	BOTON_MANDO = Enum.KeyCode.ButtonB,
}

return CombateConfig

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
	TECLA = Enum.KeyCode.LeftShift, -- de fábrica; el jugador la cambia en Menú M > Ajustes (ControlesConfig)
	BOTON_MANDO = Enum.KeyCode.ButtonB,

	-- Tipos de esquiva:
	--   Rodar     -> caminando hacia delante o atrás (W/S + Q)
	--   Lateral   -> caminando de lado (A/D + Q): voltereta lateral acrobática
	--   PasoAtras -> sin moverte (solo Q): salto corto hacia atrás
	-- DURACION: segundos que dura | VELOCIDAD: impulso inicial (studs/s)
	-- FRENADO: cuánto frena al final (0 = nada, 1 = se detiene del todo)
	TIPOS = {
		Rodar = { DURACION = 0.62, VELOCIDAD = 42, FRENADO = 0.8 },
		Lateral = { DURACION = 0.72, VELOCIDAD = 38, FRENADO = 0.85 },
		PasoAtras = { DURACION = 0.42, VELOCIDAD = 32, FRENADO = 0.9 },
	},
}

CombateConfig.Correr = {
	VELOCIDAD_CAMINAR = 16, -- velocidad normal (la de Roblox por defecto)
	VELOCIDAD_CORRER = 26, -- velocidad al correr
	VELOCIDAD_PASEO = 8, -- caminar tranquilo (tecla Caminar): se ve la animación de andar
	COSTO_POR_SEGUNDO = 14, -- estamina que gasta correr cada segundo (solo si te mueves)
	MINIMO_PARA_REANUDAR = 30, -- si te quedas sin estamina, vuelves a correr al llegar a esto
	VENTANA_DOBLE_W = 0.3, -- segundos máximos entre los dos toques de W
	TECLAS = { Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl }, -- mantener para correr
	BOTON_MANDO = Enum.KeyCode.ButtonL3, -- en mando: pulsar el stick izquierdo
	FOV_CORRER = 78, -- la cámara se abre un poco al correr
}

return CombateConfig

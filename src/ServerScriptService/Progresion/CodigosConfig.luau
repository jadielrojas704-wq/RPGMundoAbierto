-- Códigos que los jugadores pueden canjear en la pantalla de inicio (Códigos).
-- Ruta en Studio: ServerScriptService/Progresion/CodigosConfig
-- Está en el SERVIDOR a propósito: así nadie puede leer los códigos desde su ordenador.
--
-- Para añadir uno: copia una línea. Escribe el código en MAYÚSCULAS (el jugador puede
-- escribirlo como quiera). "activo = false" lo desactiva sin borrarlo.
-- Recompensas posibles: GirosRaza, GirosAfinidad, Oro.

return {
	BIENVENIDO = { activo = true, GirosRaza = 5, GirosAfinidad = 5, Oro = 100 },
	ARTESMARCIALES = { activo = true, GirosRaza = 3 },
	REINOS = { activo = true, GirosAfinidad = 3 },
}

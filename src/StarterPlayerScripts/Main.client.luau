-- Arranque del cliente.
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/Main

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constantes = require(ReplicatedStorage.Config.Constantes)

print("[CLIENTE] Conectado. Máximo de jugadores:", Constantes.MAX_JUGADORES)

-- Copia de los datos del personaje (solo lectura). De momento lo enseña en la consola;
-- el HUD y el menú M la usarán más adelante.
local DatosLocal = require(ReplicatedStorage.Progresion.DatosLocal)
local ultimoResumen = ""
DatosLocal.Cambio:Connect(function(datos)
	local a = datos.Atributos
	local resumen = string.format(
		"[CLIENTE] %s | Nivel %d (%d EXP) | Oro %d | Puntos libres %d | VIT %d STR %d DEX %d INT %d LUK %d SPD %d",
		datos.Nombre, datos.Nivel, datos.Experiencia, datos.Oro, datos.PuntosLibres, a.VIT, a.STR, a.DEX, a.INT, a.LUK, a.SPD
	)
	if resumen ~= ultimoResumen then
		ultimoResumen = resumen
		print(resumen)
	end
end)

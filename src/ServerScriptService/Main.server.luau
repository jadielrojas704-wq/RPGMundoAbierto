-- Arranque del servidor: inicia todos los servicios en orden.
-- Ruta en Studio: ServerScriptService/Main

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constantes = require(ReplicatedStorage.Config.Constantes)

local Combate = script.Parent.Combate
local EstaminaServicio = require(Combate.EstaminaServicio)
local EsquivaServicio = require(Combate.EsquivaServicio)

EstaminaServicio.Iniciar()
EsquivaServicio.Iniciar()

print("[SERVIDOR] Juego iniciado. Nivel máximo:", Constantes.NIVEL_MAXIMO)
print("[SERVIDOR] Armas cargadas:", #Constantes.ARMAS)
print("[SERVIDOR] Combate listo: estamina y esquiva activas")

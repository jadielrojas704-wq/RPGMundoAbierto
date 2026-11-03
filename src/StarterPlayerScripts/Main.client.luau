-- Arranque del cliente.
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/Main

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constantes = require(ReplicatedStorage.Config.Constantes)

print("[CLIENTE] Conectado. Máximo de jugadores:", Constantes.MAX_JUGADORES)

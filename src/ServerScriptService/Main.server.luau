-- Arranque del servidor: inicia todos los servicios en orden.
-- Ruta en Studio: ServerScriptService/Main

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Constantes = require(ReplicatedStorage.Config.Constantes)

local Combate = script.Parent.Combate
local EstaminaServicio = require(Combate.EstaminaServicio)
local EsquivaServicio = require(Combate.EsquivaServicio)
local CorrerServicio = require(Combate.CorrerServicio)
local CombateServicio = require(Combate.CombateServicio)
local EntrenamientoServicio = require(Combate.EntrenamientoServicio)

local Progresion = script.Parent.Progresion
local DatosServicio = require(Progresion.DatosServicio)
local PersonajeServicio = require(Progresion.PersonajeServicio)
local AparienciaServicio = require(Progresion.AparienciaServicio)
local InicioServicio = require(Progresion.InicioServicio)
local RazaServicio = require(Progresion.RazaServicio)
local MisionesServicio = require(script.Parent.Historia.MisionesServicio)

local ClimaServicio = require(script.Parent.Mundo.ClimaServicio)
local NPCServicio = require(script.Parent.Mundo.NPCServicio)

-- El Shift Lock de Roblox usa Shift (que aquí es esquivar): se apaga y se usa el del juego
-- (StarterPlayerScripts/ShiftLockCliente, tecla configurable, de fábrica Bloq Mayús).
StarterPlayer.EnableMouseLockOption = false
local function sinShiftLockRoblox(jugador)
	jugador.DevEnableMouseLock = false
end
Players.PlayerAdded:Connect(sinShiftLockRoblox)
for _, jugador in Players:GetPlayers() do
	sinShiftLockRoblox(jugador)
end

EstaminaServicio.Iniciar()
EsquivaServicio.Iniciar()
CorrerServicio.Iniciar()
PersonajeServicio.Iniciar() -- antes que DatosServicio, para no perderse el primer "Cargado"
AparienciaServicio.Iniciar() -- antes que DatosServicio, por lo mismo
InicioServicio.Iniciar()
MisionesServicio.Iniciar() -- antes que DatosServicio (escucha "Cargado"); construye santuarios y Custodio
DatosServicio.Iniciar()
CombateServicio.Iniciar()
EntrenamientoServicio.Iniciar()
ClimaServicio.Iniciar()
NPCServicio.Iniciar()
RazaServicio.Iniciar()

print("[SERVIDOR] Juego iniciado. Nivel máximo:", Constantes.NIVEL_MAXIMO)
print("[SERVIDOR] Armas cargadas:", #Constantes.ARMAS)
print("[SERVIDOR] Combate listo: estamina, esquiva, correr y Sin armas activos")
print("[SERVIDOR] Clima y ciclo de día y noche activos")
print("[SERVIDOR] Datos de personaje (CharacterData) activos")

-- Arranque del servidor: inicia todos los servicios en orden.
-- Ruta en Studio: ServerScriptService/Main

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constantes = require(ReplicatedStorage.Config.Constantes)

local Combate = script.Parent.Combate
local EstaminaServicio = require(Combate.EstaminaServicio)
local EsquivaServicio = require(Combate.EsquivaServicio)
local CorrerServicio = require(Combate.CorrerServicio)

local Progresion = script.Parent.Progresion
local DatosServicio = require(Progresion.DatosServicio)
local PersonajeServicio = require(Progresion.PersonajeServicio)

local ClimaServicio = require(script.Parent.Mundo.ClimaServicio)
local NPCServicio = require(script.Parent.Mundo.NPCServicio)

EstaminaServicio.Iniciar()
EsquivaServicio.Iniciar()
CorrerServicio.Iniciar()
PersonajeServicio.Iniciar() -- antes que DatosServicio, para no perderse el primer "Cargado"
DatosServicio.Iniciar()
ClimaServicio.Iniciar()
NPCServicio.Iniciar()

print("[SERVIDOR] Juego iniciado. Nivel máximo:", Constantes.NIVEL_MAXIMO)
print("[SERVIDOR] Armas cargadas:", #Constantes.ARMAS)
print("[SERVIDOR] Combate listo: estamina, esquiva y correr activos")
print("[SERVIDOR] Clima y ciclo de día y noche activos")
print("[SERVIDOR] Datos de personaje (CharacterData) activos")

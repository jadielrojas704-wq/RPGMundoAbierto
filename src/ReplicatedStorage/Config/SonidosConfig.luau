-- Lista de sonidos del juego. Cambia los números para probar otros.
-- Ruta en Studio: ReplicatedStorage/Config/SonidosConfig
-- Todos son de "Pro Sound Effects" (biblioteca con licencia de Roblox),
-- así que se pueden usar en cualquier juego sin problemas de derechos.

local function id(numero)
	return "rbxassetid://" .. numero
end

local SonidosConfig = {}

SonidosConfig.Esquiva = {
	-- Quejido de impulso al empezar la voltereta (se elige uno al azar)
	IMPULSO = {
		id(9120415873), -- Video Game Effects 4 (0.5 s)
		id(9120415958), -- Video Game Effects 5 (0.5 s)
		id(9120417141), -- Video Game Effects 21 (0.4 s)
	},
	-- Exhalación al terminar, como acomodándose
	ACOMODARSE = {
		id(9120439971), -- Vocal Blows 3 (0.7 s)
	},
	-- Golpe suave del cuerpo contra el suelo (sonido interno de Roblox)
	CAIDA = "rbxasset://sounds/action_jump_land.mp3",

	VOLUMEN_VOZ = 0.7,
	VOLUMEN_CAIDA = 0.35,
}

return SonidosConfig

-- Lista de sonidos del juego. Cambia los números para probar otros.
-- Ruta en Studio: ReplicatedStorage/Config/SonidosConfig
-- Todos son de "Pro Sound Effects" (biblioteca con licencia de Roblox),
-- así que se pueden usar en cualquier juego sin problemas de derechos.

local function id(numero)
	return "rbxassetid://" .. numero
end

local SonidosConfig = {}

SonidosConfig.Esquiva = {
	-- Roce de la ropa al rodar por el suelo (se elige uno al azar)
	ROPA = {
		id(9113824230), -- Cloth Movement 24: deslizar, roce, golpe suave (1.0 s)
		id(9113823745), -- Cloth Movement 15: deslizar, roce, golpe suave (1.0 s)
		id(9113822732), -- Cloth Movement 1: deslizar, roce, golpe suave (0.8 s)
	},
	-- Golpe sordo del cuerpo al apoyarse en el suelo (sonido interno de Roblox)
	CAIDA = "rbxasset://sounds/action_jump_land.mp3",
	-- Respiración suave al levantarse (no siempre suena)
	RESPIRACION = {
		id(9120439971), -- Vocal Blows 3: exhalación (0.7 s)
	},
	PROBABILIDAD_RESPIRACION = 0.5,

	VOLUMEN_ROPA = 0.6,
	VOLUMEN_CAIDA = 0.25,
	VOLUMEN_RESPIRACION = 0.25,
}

return SonidosConfig

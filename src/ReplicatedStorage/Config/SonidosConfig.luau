-- Catálogo de SONIDOS y MÚSICA del juego (IDs públicos de la tienda de Roblox).
-- Ruta en Studio: ReplicatedStorage/Config/SonidosConfig
-- Si un sonido deja de funcionar, basta con cambiar aquí su número.

local SonidosConfig = {}

local function id(numero)
	return "rbxassetid://" .. tostring(numero)
end

-- ===== ESQUIVA (voltereta) =====
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

-- ===== MÚSICA DE CINEMÁTICAS =====
SonidosConfig.MUSICA = {
	Prologo = id(90147915477570), -- "Dark Epic Orchestral Cinematic Reveal"
	Guardian = id(86559939287210), -- "Guardian of the Forbidden Realm" (santuarios, revelaciones)
	Jefe = id(89392587443822), -- "Climactic Boss Fight" (presentación de jefes)
	Batalla = id(93280557270748), -- "Epic Battle Momentum" (orquesta y coros)
}

-- ===== EFECTOS DE CINEMÁTICA =====
SonidosConfig.CINE = {
	Coro = id(9125603319), -- coro celestial oscuro (fondo)
	Corte = id(9120698420), -- ráfaga de viento entre tomas
	Golpe = id(9120015146), -- trueno sordo (cartel final, temblores)
	Eclipse = id(9114795437), -- rugido infernal grave (aparece el Eclipse)
	Zumbido = id(9114353038), -- dron grave que crece
}

-- ===== EL DRAGÓN OCULTO DE LAS MONTAÑAS =====
SonidosConfig.DRAGON = {
	Rugidos = {
		id(9113987603), -- rugido gigante (se baja de tono: suena enorme)
		id(9113980680), -- rugido largo con gruñidos
		id(104003579725868), -- "dragon roar"
	},
	Grunido = id(9113985466), -- gruñido grave constante (el eco de después)
	Trueno = id(9120015146), -- retumbar de la montaña
}

-- ===== ANIMALES =====
SonidosConfig.LOBO = {
	Aullido = { id(9120789596), id(9120789309), id(9120790308) },
	Grunido = { id(9120788137), id(9120789017), id(9120788662) },
}

return SonidosConfig

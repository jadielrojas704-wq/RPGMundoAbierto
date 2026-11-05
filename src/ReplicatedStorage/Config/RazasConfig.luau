-- Razas y afinidad mágica que se consiguen GIRANDO (en Personalizar > Raza y magia).
-- Ruta en Studio: ReplicatedStorage/Config/RazasConfig
-- La tirada la hace SIEMPRE el servidor (ServerScriptService/Progresion/InicioServicio);
-- el cliente solo enseña las probabilidades y la animación.
--
-- PROVISIONAL: la lista de razas y sus bonos es una propuesta. Se cambia aquí sin tocar
-- nada más. "probabilidad" es el % de salir en un giro (entre todas suman 100).
-- "bonos" son puntos de atributo extra que da la raza (se suman a los repartidos).

local RazasConfig = {}

RazasConfig.RAZAS = {
	{
		id = "Humano",
		nombre = "Humano",
		rareza = "Comun",
		probabilidad = 40,
		bonos = { LUK = 2, VIT = 1 },
		texto = "Adaptable. Un poco más de suerte y aguante.",
	},
	{
		id = "Elfo",
		nombre = "Elfo",
		rareza = "PocoComun",
		probabilidad = 18,
		bonos = { DEX = 3, INT = 2 },
		texto = "Ágil y sabio: más destreza e inteligencia.",
	},
	{
		id = "Enano",
		nombre = "Enano",
		rareza = "PocoComun",
		probabilidad = 18,
		bonos = { VIT = 4, STR = 1 },
		texto = "Duro como la roca: mucha más vida.",
	},
	{
		id = "Bestia",
		nombre = "Hombre bestia",
		rareza = "Raro",
		probabilidad = 12,
		bonos = { STR = 3, SPD = 3 },
		texto = "Fuerza y velocidad salvajes.",
	},
	{
		id = "Vampiro",
		nombre = "Vampiro",
		rareza = "Epico",
		probabilidad = 6,
		bonos = { INT = 3, DEX = 3, LUK = 1 },
		texto = "Hijo de la noche: magia y reflejos.",
	},
	{
		id = "Draconido",
		nombre = "Dracónido",
		rareza = "Epico",
		probabilidad = 4.5,
		bonos = { STR = 4, VIT = 4 },
		texto = "Sangre de dragón: fuerza y escamas.",
	},
	{
		id = "Celestial",
		nombre = "Celestial",
		rareza = "Legendario",
		probabilidad = 1.2,
		bonos = { INT = 5, VIT = 3, LUK = 3 },
		texto = "Bendecido por la luz.",
	},
	{
		id = "Demonio",
		nombre = "Demonio",
		rareza = "Mitico",
		probabilidad = 0.3,
		bonos = { STR = 6, SPD = 5, VIT = 4 },
		texto = "Un cuerpo nacido para pelear sin descanso.",
	},
}

-- Afinidad mágica principal (los 7 elementos del juego)
RazasConfig.AFINIDADES = {
	{ id = "Fuego", nombre = "Fuego", rareza = "Comun", probabilidad = 20, color = Color3.fromRGB(255, 120, 50) },
	{ id = "Tierra", nombre = "Tierra", rareza = "Comun", probabilidad = 20, color = Color3.fromRGB(170, 130, 80) },
	{ id = "Viento", nombre = "Viento", rareza = "Comun", probabilidad = 20, color = Color3.fromRGB(150, 230, 190) },
	{ id = "Hielo", nombre = "Hielo", rareza = "Raro", probabilidad = 14, color = Color3.fromRGB(150, 220, 255) },
	{ id = "Rayo", nombre = "Rayo", rareza = "Raro", probabilidad = 14, color = Color3.fromRGB(255, 230, 90) },
	{ id = "Luz", nombre = "Luz", rareza = "Epico", probabilidad = 6, color = Color3.fromRGB(255, 245, 200) },
	{ id = "Sombra", nombre = "Sombra", rareza = "Epico", probabilidad = 6, color = Color3.fromRGB(150, 90, 220) },
}

RazasConfig.NOMBRES_RAREZA = {
	Comun = "Común",
	PocoComun = "Poco común",
	Raro = "Raro",
	Epico = "Épico",
	Legendario = "Legendario",
	Mitico = "Mítico",
}

-- Giros con los que empieza un personaje nuevo (además de la primera tirada gratis)
RazasConfig.GIROS_INICIALES = { Raza = 3, Afinidad = 3 }

-- Búsqueda por id
local function indexar(lista)
	local t = {}
	for _, e in lista do
		t[e.id] = e
	end
	return t
end
RazasConfig.RAZA_POR_ID = indexar(RazasConfig.RAZAS)
RazasConfig.AFINIDAD_POR_ID = indexar(RazasConfig.AFINIDADES)

-- Elige al azar según las probabilidades (lo llama el servidor)
function RazasConfig.Tirar(lista, aleatorio)
	local total = 0
	for _, e in lista do
		total += e.probabilidad
	end
	local x = aleatorio:NextNumber() * total
	for _, e in lista do
		x -= e.probabilidad
		if x <= 0 then
			return e
		end
	end
	return lista[1]
end

return RazasConfig

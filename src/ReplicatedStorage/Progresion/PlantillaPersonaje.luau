-- CharacterData: la ficha completa de un personaje tal como se guarda en el DataStore.
-- Ruta en Studio: ReplicatedStorage/Progresion/PlantillaPersonaje
--
-- Es la plantilla de un personaje NUEVO. Si más adelante se añade un campo aquí,
-- los personajes que ya existen lo reciben solo al cargar (ver Completar).
-- Si se cambia el FORMATO de algo que ya existe, sube VERSION y añade una migración
-- en ServerScriptService/Progresion/DatosServicio.
--
-- Formato de los objetos:
--   Armas, Armaduras y Monturas: lista de { Uid = "único", Id = "KatanaDeAcero", Rareza = "Raro", Mejora = 0 }
--   Materiales y Consumibles:    diccionario { [Id] = cantidad }, por ejemplo { MineralDeHierro = 12 }

local Constantes = require(script.Parent.Parent.Config.Constantes)
local ProgresionConfig = require(script.Parent.Parent.Config.ProgresionConfig)
local AparienciaConfig = require(script.Parent.Parent.Config.AparienciaConfig)
local RazasConfig = require(script.Parent.Parent.Config.RazasConfig)

local Plantilla = {}

Plantilla.VERSION = 1

local function nivelYExp(nivel)
	return { Nivel = nivel, Exp = 0 }
end

-- Devuelve un CharacterData nuevo (una copia, para poder modificarla)
function Plantilla.Nueva()
	local atributos = {}
	for _, nombre in Constantes.ATRIBUTOS do
		atributos[nombre] = ProgresionConfig.ATRIBUTO_INICIAL
	end
	local afinidades = {}
	for _, elemento in ProgresionConfig.ELEMENTOS do
		afinidades[elemento] = nivelYExp(0)
	end
	local maestrias = {}
	for _, arma in Constantes.ARMAS do
		maestrias[arma] = nivelYExp(0)
	end
	local profesiones = {}
	for _, profesion in ProgresionConfig.PROFESIONES do
		profesiones[profesion] = nivelYExp(1)
	end

	return {
		Version = Plantilla.VERSION,

		-- Identidad
		Nombre = "", -- se elegirá al crear el personaje (de momento, el nombre de Roblox)
		Nivel = 1,
		Experiencia = 0,
		PuntosLibres = 0, -- puntos de atributo sin repartir
		Clase = "Ninguna",
		Subclase = "Ninguna",
		Raza = "Ninguna", -- se gira en Personalizar (Config/RazasConfig)
		AfinidadMagica = "Ninguna", -- elemento principal, también se gira
		Oro = 0,
		Ubicacion = {}, -- { X, Y, Z, Region } de la última posición segura (vacío = aparición inicial)

		-- Atributos (los que reparte el jugador)
		Atributos = atributos, -- VIT, STR, DEX, INT, LUK, SPD

		-- Mochila
		Inventario = {
			Armas = {},
			Armaduras = {},
			Materiales = {},
			Consumibles = {},
			Monturas = {},
		},
		-- Lo que lleva puesto (Uid de un objeto de la mochila; vacío = nada).
		-- Sin arma equipada se pelea con "SinArmas".
		Equipo = {
			Arma1 = "",
			Arma2 = "",
			Cabeza = "",
			Torso = "",
			Piernas = "",
			Accesorio = "",
			Montura = "",
		},

		-- Progreso del personaje
		Talentos = { Puntos = 0, Rangos = {} }, -- árbol general: { [IdTalento] = rango }
		Afinidades = afinidades, -- { Fuego = { Nivel, Exp }, ... }
		Maestrias = maestrias, -- una por arma: { Katana = { Nivel, Exp }, ... }
		DominioClase = {}, -- uno por clase jugada: { [Clase] = { Nivel, Exp } }

		-- Profesiones
		Profesiones = profesiones, -- Herreria, Alquimia, Mineria, Encantamiento

		-- Ajustes del jugador (teclas reasignadas, etc.)
		Ajustes = { Teclas = {}, Idioma = "Auto" }, -- Idioma: "Auto" (el de Roblox), "es" o "en"

		-- Aspecto (editor Personalizar, opciones en Config/AparienciaConfig)
		Apariencia = AparienciaConfig.PorDefecto(),
		-- Giros que le quedan para raza y afinidad mágica
		Giros = { Raza = RazasConfig.GIROS_INICIALES.Raza, Afinidad = RazasConfig.GIROS_INICIALES.Afinidad },
		CodigosUsados = {}, -- { [CODIGO] = true }
		Creado = false, -- pasa a true la primera vez que pulsa Jugar

		-- Historia principal (El Eclipse Eterno): misión actual, contador y textos leídos
		Historia = { Mision = 1, Progreso = 0, Textos = {}, PrologoVisto = false },

		-- Datos internos
		Registro = { Creado = os.time(), TiempoJugado = 0, UltimaConexion = os.time() },
	}
end

local function esLista(t)
	return #t > 0 or next(t) == nil
end

-- Rellena lo que le falte a "datos" con los valores de la plantilla (sin borrar nada).
-- Sirve para que un personaje viejo reciba los campos nuevos.
function Plantilla.Completar(datos, base)
	base = base or Plantilla.Nueva()
	for clave, valor in base do
		if datos[clave] == nil then
			datos[clave] = valor
		elseif type(valor) == "table" and type(datos[clave]) == "table" and not esLista(valor) then
			Plantilla.Completar(datos[clave], valor)
		end
	end
	return datos
end

return Plantilla

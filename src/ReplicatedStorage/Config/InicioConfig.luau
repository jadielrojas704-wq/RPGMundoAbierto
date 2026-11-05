-- Pantalla de carga y pantalla de inicio (Jugar / Personalizar / Códigos).
-- Ruta en Studio: ReplicatedStorage/Config/InicioConfig

local InicioConfig = {}

-- PROVISIONAL: el nombre del juego lo eliges tú. Cámbialo aquí.
InicioConfig.NOMBRE_JUEGO = "Reinos del Velo"
InicioConfig.SUBTITULO = "Un mundo abierto de reinos, magia y artes marciales"
InicioConfig.VERSION = "Versión de desarrollo"

-- Consejos que salen en la pantalla de carga
InicioConfig.CONSEJOS = {
	"Mantén el clic izquierdo para cargar un golpe de Ki.",
	"Shift para esquivar: en el momento justo no te tocan.",
	"Pulsa M para abrir el menú: mapa, mochila y estadísticas.",
	"Habla con los aldeanos con G. Algunos tienen historias.",
	"Cambia cualquier tecla en M > Ajustes.",
	"En Personalizar puedes girar tu raza y tu afinidad mágica.",
	"Los códigos dan giros extra. ¡Atento a las novedades!",
}

-- Capital que se ve de fondo en la pantalla de inicio (por su nombre)
InicioConfig.CIUDAD_FONDO = "Valdoria"

return InicioConfig

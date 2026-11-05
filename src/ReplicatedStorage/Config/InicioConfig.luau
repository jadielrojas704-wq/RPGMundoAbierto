-- Pantalla de carga y pantalla de inicio (Jugar / Personalizar / Códigos).
-- Ruta en Studio: ReplicatedStorage/Config/InicioConfig

local InicioConfig = {}

-- Nombre del juego (decidido por el usuario el 4 nov 2026).
InicioConfig.NOMBRE_JUEGO = "El Eclipse Eterno"
InicioConfig.SUBTITULO = "El sello se rompe. El Eclipse despierta."
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
	"Los Guardianes dejaron inscripciones en sus santuarios. Léelas con G.",
	"Los vampiros se queman al sol, pero de noche son más fuertes.",
	"Dicen que la piedra del Altar del Ascenso sangra luz morada...",
}

-- Capital que se ve de fondo en la pantalla de inicio (por su nombre)
InicioConfig.CIUDAD_FONDO = "Valdoria"

return InicioConfig

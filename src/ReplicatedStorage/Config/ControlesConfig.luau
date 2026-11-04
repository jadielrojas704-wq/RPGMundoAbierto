-- Teclas del juego (las de fábrica). Cada jugador puede cambiarlas en Menú M > Ajustes;
-- sus cambios se guardan en su CharacterData (Ajustes.Teclas).
-- Ruta en Studio: ReplicatedStorage/Config/ControlesConfig
--
-- Los valores son nombres de Enum.KeyCode ("LeftShift", "G"...) o de botones del ratón
-- ("MouseButton1", "MouseButton2", "MouseButton3").

local ControlesConfig = {}

-- Orden en el que salen en el menú de Ajustes
ControlesConfig.ORDEN = {
	"Ataque",
	"Bloqueo",
	"Esquiva",
	"Correr",
	"HabilidadQ",
	"HabilidadE",
	"HabilidadR",
	"HabilidadF",
	"Ultimate",
	"FijarObjetivo",
	"Interactuar",
	"Menu",
	"ShiftLock",
}

ControlesConfig.ACCIONES = {
	Ataque = { nombre = "Atacar (mantener = golpe cargado)", tecla = "MouseButton1" },
	Bloqueo = { nombre = "Bloquear / parry", tecla = "MouseButton2" },
	Esquiva = { nombre = "Esquivar", tecla = "LeftShift" },
	Correr = { nombre = "Correr (mantener; también doble W)", tecla = "LeftControl" },
	HabilidadQ = { nombre = "Habilidad 1", tecla = "Q" },
	HabilidadE = { nombre = "Habilidad 2", tecla = "E" },
	HabilidadR = { nombre = "Habilidad 3", tecla = "R" },
	HabilidadF = { nombre = "Habilidad 4", tecla = "F" },
	Ultimate = { nombre = "Ultimate", tecla = "V" },
	FijarObjetivo = { nombre = "Fijar objetivo", tecla = "MouseButton3" },
	Interactuar = { nombre = "Hablar / interactuar", tecla = "G" },
	Menu = { nombre = "Abrir el menú", tecla = "M" },
	ShiftLock = { nombre = "Shift Lock (cámara fija)", tecla = "CapsLock", soloTeclado = true },
}

-- Teclas que no se pueden usar (moverse, saltar, chat, salir...)
ControlesConfig.PROHIBIDAS = {
	W = true,
	A = true,
	S = true,
	D = true,
	Space = true,
	Escape = true,
	Slash = true,
	Return = true,
	Tab = true,
	Backquote = true,
	Unknown = true,
}

-- Botones del ratón permitidos
ControlesConfig.RATON = { MouseButton1 = true, MouseButton2 = true, MouseButton3 = true }

-- ¿Es válido este nombre de tecla para esta acción? (lo usan cliente y servidor)
function ControlesConfig.EsValida(accion, nombreTecla)
	local datos = ControlesConfig.ACCIONES[accion]
	if not datos or type(nombreTecla) ~= "string" or #nombreTecla > 30 then
		return false
	end
	if ControlesConfig.PROHIBIDAS[nombreTecla] then
		return false
	end
	if ControlesConfig.RATON[nombreTecla] then
		return not datos.soloTeclado
	end
	local ok, tecla = pcall(function()
		return Enum.KeyCode[nombreTecla]
	end)
	return ok and tecla ~= nil
end

return ControlesConfig

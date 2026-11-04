-- Teclas del jugador en el CLIENTE: mezcla las de fábrica (Config/ControlesConfig) con las
-- que el jugador cambió (guardadas en su CharacterData, Ajustes.Teclas).
-- Ruta en Studio: ReplicatedStorage/Combate/Controles
--
-- Uso en un LocalScript:
--   local Controles = require(ReplicatedStorage.Combate.Controles)
--   if Controles.Es("Esquiva", entrada) then ... end
--   Controles.Nombre("Menu")  -- texto para mostrar, p. ej. "M"
-- El Shift Lock del juego (StarterPlayerScripts/ShiftLockCliente) usa la acción "ShiftLock"
-- (de fábrica Bloq Mayús), porque Shift se usa para esquivar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ControlesConfig = require(ReplicatedStorage.Config.ControlesConfig)

local Controles = {}

local evento = Instance.new("BindableEvent")
Controles.Cambio = evento.Event

local personalizadas = {} -- [accion] = nombre de tecla

function Controles.TeclaDe(accion)
	local nombre = personalizadas[accion]
	if nombre and ControlesConfig.EsValida(accion, nombre) then
		return nombre
	end
	local datos = ControlesConfig.ACCIONES[accion]
	return datos and datos.tecla
end

-- ¿Esta entrada (InputObject) corresponde a la acción?
function Controles.Es(accion, entrada)
	local nombre = Controles.TeclaDe(accion)
	if not nombre then
		return false
	end
	if ControlesConfig.RATON[nombre] then
		return entrada.UserInputType.Name == nombre
	end
	if entrada.KeyCode.Name == nombre then
		return true
	end
	-- Shift, Ctrl y Alt: vale el izquierdo y el derecho
	if nombre == "LeftShift" and entrada.KeyCode == Enum.KeyCode.RightShift then
		return true
	elseif nombre == "LeftControl" and entrada.KeyCode == Enum.KeyCode.RightControl then
		return true
	end
	return false
end

local NOMBRES_BONITOS = {
	MouseButton1 = "Clic izq.",
	MouseButton2 = "Clic der.",
	MouseButton3 = "Rueda",
	LeftShift = "Shift",
	RightShift = "Shift der.",
	LeftControl = "Ctrl",
	RightControl = "Ctrl der.",
	LeftAlt = "Alt",
	RightAlt = "Alt der.",
	CapsLock = "Bloq Mayús",
	One = "1",
	Two = "2",
	Three = "3",
	Four = "4",
	Five = "5",
}

function Controles.Nombre(accion)
	local nombre = Controles.TeclaDe(accion) or "?"
	return NOMBRES_BONITOS[nombre] or nombre
end

-- Teclas actuales (para guardarlas): solo las que difieren de las de fábrica
function Controles.Personalizadas()
	local copia = {}
	for accion, nombre in personalizadas do
		copia[accion] = nombre
	end
	return copia
end

-- Cambia una tecla en el cliente (el menú luego lo guarda en el servidor)
function Controles.Asignar(accion, nombre)
	if not ControlesConfig.EsValida(accion, nombre) then
		return false
	end
	-- Si otra acción ya usaba esa tecla, se intercambian
	local anterior = Controles.TeclaDe(accion)
	for _, otra in ControlesConfig.ORDEN do
		if otra ~= accion and Controles.TeclaDe(otra) == nombre then
			personalizadas[otra] = anterior
		end
	end
	personalizadas[accion] = nombre
	Controles.Aplicar()
	evento:Fire()
	return true
end

function Controles.Restablecer()
	personalizadas = {}
	Controles.Aplicar()
	evento:Fire()
end

-- El Shift Lock de Roblox está desactivado (usaba Shift). El juego tiene el suyo:
-- StarterPlayerScripts/ShiftLockCliente, que lee la tecla "ShiftLock" con Controles.Es.
function Controles.Aplicar()
	-- Las teclas se leen en el momento con Controles.Es, no hay nada más que aplicar
end

if RunService:IsClient() then
	-- Las teclas guardadas llegan con la copia del CharacterData
	local DatosLocal = require(ReplicatedStorage.Progresion.DatosLocal)
	local function cargar(datos)
		local guardadas = datos and datos.Ajustes and datos.Ajustes.Teclas
		if type(guardadas) == "table" then
			local nuevas = {}
			for accion, nombre in guardadas do
				if ControlesConfig.EsValida(accion, nombre) then
					nuevas[accion] = nombre
				end
			end
			personalizadas = nuevas
		end
		Controles.Aplicar()
		evento:Fire()
	end
	local primera = true
	DatosLocal.Cambio:Connect(function(datos)
		if primera then
			primera = false
			cargar(datos) -- solo la primera vez; después manda lo que cambie el jugador aquí
		end
	end)
	if DatosLocal.Obtener() then
		primera = false
		cargar(DatosLocal.Obtener())
	end
	Controles.Aplicar()
end

return Controles

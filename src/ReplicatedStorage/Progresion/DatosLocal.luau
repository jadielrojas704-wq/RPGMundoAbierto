-- Copia de SOLO LECTURA del CharacterData en el cliente, para dibujar la interfaz.
-- Ruta en Studio: ReplicatedStorage/Progresion/DatosLocal
-- La manda el servidor (ServerScriptService/Progresion/DatosServicio). Cambiarla aquí
-- no cambia nada de verdad: todo cambio real se pide al servidor y él decide.
--
-- Uso en un LocalScript:
--   local DatosLocal = require(ReplicatedStorage.Progresion.DatosLocal)
--   local datos = DatosLocal.Obtener()            -- nil hasta que llegue la primera copia
--   DatosLocal.Cambio:Connect(function(datos) ... end)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DatosLocal = {}

local evento = Instance.new("BindableEvent")
DatosLocal.Cambio = evento.Event

local datos = nil

function DatosLocal.Obtener()
	return datos
end

if RunService:IsClient() then
	local remoto = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DatosPersonaje")
	remoto.OnClientEvent:Connect(function(nuevos)
		datos = nuevos
		evento:Fire(datos)
	end)
	remoto:FireServer() -- pide la copia por si llegó antes de estar escuchando
end

return DatosLocal

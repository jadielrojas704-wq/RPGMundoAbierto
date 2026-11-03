-- Velo de la Isla Celestial (cliente).
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/VeloIsla (LocalScript)
--
-- Desde el suelo la isla solo se ve como una silueta lejana y azulada entre la bruma
-- (como las montañas muy lejanas en la vida real). Sus detalles (ruinas, árboles
-- dorados, cascada) se esconden en la pantalla de este jugador hasta que la desbloquee:
-- así desde abajo no se puede ver casi nada de lo que hay arriba.
--
-- Se revela cuando los TRES sellos del Altar del Ascenso están encendidos,
-- o cuando el jugador tiene el atributo "IslaRevelada" = true.
-- (Cómo se encienden los sellos aún no está decidido: jefe, reliquia o ambos.)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local jugador = Players.LocalPlayer
local SELLOS = { "Sello_Bosque", "Sello_Desierto", "Sello_Oscuro" }
local REVISAR_CADA = 3 -- segundos

local revelada = false
local guardados = {} -- objeto -> valor original de Enabled

local function esconderObjeto(objeto)
	if revelada then
		return
	end
	if objeto:IsA("BasePart") then
		objeto.LocalTransparencyModifier = 1
	elseif objeto:IsA("ParticleEmitter") or objeto:IsA("Light") or objeto:IsA("Beam") then
		-- Las nubes de alrededor se quedan: nubes en el cielo son naturales
		local esNube = objeto.Parent and objeto.Parent.Name == "EmisorNubes"
		if not esNube then
			if guardados[objeto] == nil then
				guardados[objeto] = objeto.Enabled
			end
			objeto.Enabled = false
		end
	end
end

local function revelar(carpeta)
	revelada = true
	for _, objeto in carpeta:GetDescendants() do
		if objeto:IsA("BasePart") then
			objeto.LocalTransparencyModifier = 0
		end
	end
	for objeto, valor in guardados do
		if objeto.Parent then
			objeto.Enabled = valor
		end
	end
	table.clear(guardados)
	print("[ISLA] La Isla Celestial se ha revelado")
end

local function sellosEncendidos()
	local mundo = Workspace:FindFirstChild("Mundo")
	local altar = mundo and mundo:FindFirstChild("AltarDelAscenso")
	if not altar then
		return 0
	end
	local encendidos = 0
	for _, nombre in SELLOS do
		local sello = altar:FindFirstChild(nombre)
		if sello and sello:GetAttribute("Encendido") == true then
			encendidos += 1
		end
	end
	return encendidos
end

local mundo = Workspace:WaitForChild("Mundo", 60)
local carpetaIsla = mundo and mundo:WaitForChild("IslaCelestial", 60)
if not carpetaIsla then
	return
end

for _, objeto in carpetaIsla:GetDescendants() do
	esconderObjeto(objeto)
end
-- Con "streaming" las piezas llegan poco a poco: también se esconden al llegar
carpetaIsla.DescendantAdded:Connect(esconderObjeto)

while not revelada do
	if sellosEncendidos() >= #SELLOS or jugador:GetAttribute("IslaRevelada") == true then
		revelar(carpetaIsla)
	end
	task.wait(REVISAR_CADA)
end

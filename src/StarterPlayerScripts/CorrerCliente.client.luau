-- Lee las teclas de correr y avisa al servidor.
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/CorrerCliente
-- Formas de correr:
--   * Mantener Ctrl (izquierdo o derecho)
--   * Tocar W dos veces seguidas y mantenerla
--   * Mando: pulsar el stick izquierdo (activa/desactiva)
-- Este script SOLO maneja input y el efecto de cámara. La velocidad y la
-- estamina las decide el servidor (ServerScriptService/Combate/CorrerServicio).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Config.CombateConfig).Correr
local RemotoCorrer = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Correr")

local jugador = Players.LocalPlayer
local FOV_BASE = 70

local ctrlPulsado = false
local dobleW = false -- corriendo por doble toque de W
local mandoActivo = false
local ultimoToqueW = 0
local enviado = false -- último valor mandado al servidor

local esTeclaCorrer = {}
for _, tecla in Config.TECLAS do
	esTeclaCorrer[tecla] = true
end

local function actualizar()
	local quiere = ctrlPulsado or dobleW or mandoActivo
	if quiere ~= enviado then
		enviado = quiere
		RemotoCorrer:FireServer(quiere)
	end
end

UserInputService.InputBegan:Connect(function(entrada, procesado)
	if procesado then
		return -- escribiendo en el chat o en una ventana
	end
	local tecla = entrada.KeyCode
	if esTeclaCorrer[tecla] then
		ctrlPulsado = true
	elseif tecla == Enum.KeyCode.W then
		local ahora = os.clock()
		if ahora - ultimoToqueW <= Config.VENTANA_DOBLE_W then
			dobleW = true
		end
		ultimoToqueW = ahora
	elseif tecla == Config.BOTON_MANDO then
		mandoActivo = not mandoActivo
	end
	actualizar()
end)

UserInputService.InputEnded:Connect(function(entrada)
	local tecla = entrada.KeyCode
	if esTeclaCorrer[tecla] then
		-- Solo paramos si ya no queda ninguna tecla Ctrl pulsada
		local alguna = false
		for t in esTeclaCorrer do
			if UserInputService:IsKeyDown(t) then
				alguna = true
			end
		end
		ctrlPulsado = alguna
	elseif tecla == Enum.KeyCode.W then
		dobleW = false
	end
	actualizar()
end)

-- Si se pierde el foco de la ventana, soltamos todo
UserInputService.WindowFocusReleased:Connect(function()
	ctrlPulsado, dobleW = false, false
	actualizar()
end)

-- Efecto: la cámara se abre un poco cuando el servidor confirma que corres
local function vigilarPersonaje(personaje)
	enviado = false
	mandoActivo = false
	actualizar()
	personaje:GetAttributeChangedSignal("Corriendo"):Connect(function()
		local camara = Workspace.CurrentCamera
		if not camara then
			return
		end
		local fov = personaje:GetAttribute("Corriendo") and Config.FOV_CORRER or FOV_BASE
		TweenService:Create(camara, TweenInfo.new(0.35, Enum.EasingStyle.Sine), { FieldOfView = fov }):Play()
	end)
end

if jugador.Character then
	vigilarPersonaje(jugador.Character)
end
jugador.CharacterAdded:Connect(vigilarPersonaje)

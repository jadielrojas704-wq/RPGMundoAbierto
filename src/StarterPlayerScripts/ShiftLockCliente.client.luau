-- Shift Lock PROPIO del juego (el de Roblox usa Shift, y Shift es para esquivar).
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/ShiftLockCliente
--
-- Pulsa la tecla "ShiftLock" (de fábrica Bloq Mayús; se cambia en M > Ajustes; Alt no se
-- recomienda en Studio porque abre el menú de la ventana) para
-- activarlo o quitarlo. Con él activo:
--   - el ratón queda fijo en el centro y mueve la cámara
--   - el personaje mira siempre hacia donde mira la cámara
--   - la cámara se desplaza un poco a la derecha (sobre el hombro)
-- Se suspende solo mientras el menú M está abierto o la cámara está fijada a un enemigo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Controles = require(ReplicatedStorage:WaitForChild("Combate"):WaitForChild("Controles"))

local jugador = Players.LocalPlayer

local DESPLAZAMIENTO = Vector3.new(1.75, 0.25, 0) -- cámara sobre el hombro derecho
local SUAVIDAD = 14

local activo = false
local aplicando = false -- si este frame lo estamos aplicando de verdad
local desplazamientoActual = Vector3.zero

-- Un pequeño punto en el centro de la pantalla mientras está activo
local pantalla = Instance.new("ScreenGui")
pantalla.Name = "ShiftLock"
pantalla.ResetOnSpawn = false
pantalla.IgnoreGuiInset = true
pantalla.DisplayOrder = 5
pantalla.Parent = jugador:WaitForChild("PlayerGui")
local mira = Instance.new("Frame")
mira.AnchorPoint = Vector2.new(0.5, 0.5)
mira.Position = UDim2.fromScale(0.5, 0.5)
mira.Size = UDim2.fromOffset(6, 6)
mira.BackgroundColor3 = Color3.fromRGB(240, 230, 210)
mira.BackgroundTransparency = 0.15
mira.BorderSizePixel = 0
mira.Visible = false
mira.Parent = pantalla
local esquina = Instance.new("UICorner")
esquina.CornerRadius = UDim.new(1, 0)
esquina.Parent = mira
local borde = Instance.new("UIStroke")
borde.Color = Color3.new(0, 0, 0)
borde.Transparency = 0.4
borde.Parent = mira

local function suspendido()
	if jugador:GetAttribute("MenuAbierto") or jugador:GetAttribute("EnMenu") then
		return true
	end
	local camara = Workspace.CurrentCamera
	return camara == nil or camara.CameraType ~= Enum.CameraType.Custom -- fijado a enemigo, cinemáticas...
end

local function soltar(humanoide)
	if aplicando then
		aplicando = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		if humanoide then
			humanoide.AutoRotate = true
		end
	end
end

UserInputService.InputBegan:Connect(function(entrada, procesado)
	if game:GetService("Players").LocalPlayer:GetAttribute("EnMenu") then
		return -- en la pantalla de inicio no se juega
	end
	if procesado or UserInputService:GetFocusedTextBox() then
		return
	end
	if Controles.Es("ShiftLock", entrada) then
		activo = not activo
		jugador:SetAttribute("ShiftLock", activo)
	end
end)

RunService:BindToRenderStep("ShiftLockPropio", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local personaje = jugador.Character
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")

	local quiere = activo and humanoide ~= nil and raiz ~= nil and humanoide.Health > 0 and not suspendido()
	mira.Visible = quiere

	-- Desplazamiento suave de la cámara
	local destino = if quiere then DESPLAZAMIENTO else Vector3.zero
	desplazamientoActual = desplazamientoActual:Lerp(destino, math.min(1, dt * SUAVIDAD))
	if humanoide then
		humanoide.CameraOffset = desplazamientoActual
	end

	if not quiere then
		soltar(humanoide)
		return
	end

	aplicando = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

	-- Durante la esquiva o el ataque, otros scripts orientan al personaje
	if personaje:GetAttribute("AnimacionExterna") or personaje:GetAttribute("Atacando") then
		return
	end
	humanoide.AutoRotate = false
	local mirada = Workspace.CurrentCamera.CFrame.LookVector
	local plano = Vector3.new(mirada.X, 0, mirada.Z)
	if plano.Magnitude > 0.01 then
		raiz.CFrame = CFrame.lookAt(raiz.Position, raiz.Position + plano.Unit)
	end
end)

jugador.CharacterAdded:Connect(function()
	aplicando = false
	desplazamientoActual = Vector3.zero
end)

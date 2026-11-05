-- Motor de CINEMÁTICAS (solo CLIENTE): cámara por tomas, franjas negras de cine,
-- subtítulos, fundidos y botón para saltar. Lo usan el prólogo y, más adelante,
-- las presentaciones de los jefes.
-- Ruta en Studio: ReplicatedStorage/Interfaz/Cinematica
--
--   Cinematica.Reproducir({
--       { desde = CFrame, hasta = CFrame, duracion = 6, texto = "...", fov = 60, efecto = "Temblor",
--         preparar = function() end },  -- preparar: se llama justo antes de la toma (con la pantalla negra)
--       ...
--   }, { titulo = "EL ECLIPSE ETERNO", subtitulo = "..." })   -- espera hasta que acaba
-- Mientras dura, el personaje no se puede mover.

local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Cinematica = {}

local ORO = Color3.fromRGB(228, 184, 96)

local function tween(objeto, tiempo, metas, estilo, direccion)
	local t = TweenService:Create(
		objeto,
		TweenInfo.new(tiempo, estilo or Enum.EasingStyle.Quad, direccion or Enum.EasingDirection.InOut),
		metas
	)
	t:Play()
	return t
end

local function suave(x)
	return x * x * (3 - 2 * x)
end

local TECLAS_BLOQUEADAS = {
	Enum.KeyCode.W,
	Enum.KeyCode.A,
	Enum.KeyCode.S,
	Enum.KeyCode.D,
	Enum.KeyCode.Space,
	Enum.KeyCode.Up,
	Enum.KeyCode.Down,
	Enum.KeyCode.Left,
	Enum.KeyCode.Right,
	Enum.KeyCode.LeftShift,
	Enum.KeyCode.Thumbstick1,
}

local reproduciendo = false

-- Esconde (o vuelve a enseñar) el chat y la lista de jugadores de Roblox
local function interfazRoblox(visible)
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, visible)
	end)
	pcall(function()
		local chat = game:GetService("TextChatService")
		local ventana = chat:FindFirstChildOfClass("ChatWindowConfiguration")
		local barra = chat:FindFirstChildOfClass("ChatInputBarConfiguration")
		if ventana then
			ventana.Enabled = visible
		end
		if barra then
			barra.Enabled = visible
		end
	end)
end

function Cinematica.Reproduciendo()
	return reproduciendo
end

function Cinematica.Reproducir(tomas, opciones)
	if reproduciendo then
		return
	end
	opciones = opciones or {}
	reproduciendo = true
	local jugador = Players.LocalPlayer
	jugador:SetAttribute("EnCinematica", true)
	interfazRoblox(false)
	local camara = Workspace.CurrentCamera
	local fovAntes = camara.FieldOfView

	-- no moverse durante la escena
	ContextActionService:BindActionAtPriority("BloqueoCinematica", function()
		return Enum.ContextActionResult.Sink
	end, false, 3000, table.unpack(TECLAS_BLOQUEADAS))

	-- ===== interfaz =====
	local pantalla = Instance.new("ScreenGui")
	pantalla.Name = "Cinematica"
	pantalla.IgnoreGuiInset = true
	pantalla.DisplayOrder = 60
	pantalla.ResetOnSpawn = false
	pantalla.Parent = jugador:WaitForChild("PlayerGui")

	local function franja(arriba)
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0, if arriba then 1 else 0)
		f.Position = UDim2.fromScale(0, if arriba then 0 else 1)
		f.Size = UDim2.fromScale(1, 0.12)
		f.ZIndex = 2
		f.Parent = pantalla
		return f
	end
	local arriba, abajo = franja(true), franja(false)
	tween(arriba, 0.8, { AnchorPoint = Vector2.new(0, 0) })
	tween(abajo, 0.8, { AnchorPoint = Vector2.new(0, 1) })

	local negro = Instance.new("Frame")
	negro.Size = UDim2.fromScale(1, 1)
	negro.BackgroundColor3 = Color3.new(0, 0, 0)
	negro.BackgroundTransparency = 1
	negro.BorderSizePixel = 0
	negro.ZIndex = 5
	negro.Parent = pantalla

	local subtitulo = Instance.new("TextLabel")
	subtitulo.AnchorPoint = Vector2.new(0.5, 1)
	subtitulo.Position = UDim2.new(0.5, 0, 1, -24)
	subtitulo.Size = UDim2.new(0.8, 0, 0.1, -8)
	subtitulo.BackgroundTransparency = 1
	subtitulo.Font = Enum.Font.Garamond
	subtitulo.TextScaled = true
	subtitulo.TextColor3 = Color3.fromRGB(240, 232, 214)
	subtitulo.TextStrokeTransparency = 0.6
	subtitulo.TextTransparency = 1
	subtitulo.Text = ""
	subtitulo.ZIndex = 6
	subtitulo.Parent = pantalla
	local limite = Instance.new("UITextSizeConstraint")
	limite.MaxTextSize = 30
	limite.Parent = subtitulo

	local saltar = Instance.new("TextButton")
	saltar.AnchorPoint = Vector2.new(1, 0)
	saltar.Position = UDim2.new(1, -24, 0, 18)
	saltar.Size = UDim2.fromOffset(130, 34)
	saltar.BackgroundColor3 = Color3.fromRGB(16, 14, 20)
	saltar.BackgroundTransparency = 0.3
	saltar.BorderSizePixel = 0
	saltar.Font = Enum.Font.GothamBold
	saltar.TextSize = 14
	saltar.TextColor3 = ORO
	saltar.Text = "SALTAR  ▸"
	saltar.ZIndex = 7
	saltar.Parent = pantalla
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, 5)
	esquina.Parent = saltar

	local saltado = false
	saltar.MouseButton1Click:Connect(function()
		saltado = true
	end)
	local conexionTecla = UserInputService.InputBegan:Connect(function(entrada)
		if entrada.KeyCode == Enum.KeyCode.Return or entrada.KeyCode == Enum.KeyCode.Escape then
			saltado = true
		end
	end)

	local correccion = Instance.new("ColorCorrectionEffect")
	correccion.Name = "CinematicaColor"
	correccion.Contrast = 0.08
	correccion.Saturation = -0.1
	correccion.Parent = Lighting

	-- ===== tomas =====
	camara.CameraType = Enum.CameraType.Scriptable
	for i, toma in tomas do
		if saltado then
			break
		end
		if toma.preparar then
			pcall(toma.preparar) -- p. ej. cargar esa zona del mapa antes de enseñarla
		end
		camara.FieldOfView = toma.fov or 60
		camara.CFrame = toma.desde
		if i > 1 then
			tween(negro, 0.45, { BackgroundTransparency = 1 })
		end
		-- texto
		subtitulo.Text = toma.texto or ""
		subtitulo.TextTransparency = 1
		tween(subtitulo, 0.8, { TextTransparency = 0 })
		local inicio = os.clock()
		local duracion = toma.duracion or 5
		local temblando = toma.efecto == "Temblor"
		if toma.efecto == "Eclipse" or temblando then
			correccion.TintColor = Color3.fromRGB(220, 190, 255)
			tween(correccion, duracion, { TintColor = Color3.new(1, 1, 1) })
		end
		while os.clock() - inicio < duracion and not saltado do
			local x = suave(math.clamp((os.clock() - inicio) / duracion, 0, 1))
			local cf = toma.desde:Lerp(toma.hasta, x)
			if temblando then
				local f = 0.25 * (1 - x * 0.5)
				cf *= CFrame.Angles(
					math.rad(math.noise(os.clock() * 18, 1) * f * 4),
					math.rad(math.noise(os.clock() * 18, 2) * f * 4),
					0
				)
			end
			camara.CFrame = cf
			if toma.fovFinal then
				camara.FieldOfView = (toma.fov or 60) + ((toma.fovFinal - (toma.fov or 60)) * x)
			end
			-- el texto se va un poco antes del corte
			if duracion - (os.clock() - inicio) < 0.7 and subtitulo.TextTransparency == 0 then
				tween(subtitulo, 0.6, { TextTransparency = 1 })
			end
			RunService.RenderStepped:Wait()
		end
		if i < #tomas and not saltado then
			tween(negro, 0.4, { BackgroundTransparency = 0 }).Completed:Wait()
		end
	end

	-- ===== cartel final =====
	if opciones.titulo and not saltado then
		tween(negro, 0.8, { BackgroundTransparency = 0 }).Completed:Wait()
		local titulo = Instance.new("TextLabel")
		titulo.AnchorPoint = Vector2.new(0.5, 0.5)
		titulo.Position = UDim2.fromScale(0.5, 0.46)
		titulo.Size = UDim2.new(0.9, 0, 0, 90)
		titulo.BackgroundTransparency = 1
		titulo.Font = Enum.Font.Garamond
		titulo.TextSize = 72
		titulo.TextColor3 = Color3.new(1, 1, 1)
		titulo.TextTransparency = 1
		titulo.Text = opciones.titulo
		titulo.ZIndex = 8
		titulo.Parent = pantalla
		local degradado = Instance.new("UIGradient")
		degradado.Rotation = 90
		degradado.Color = ColorSequence.new(Color3.fromRGB(255, 244, 214), ORO)
		degradado.Parent = titulo
		local sub = titulo:Clone()
		sub.Position = UDim2.fromScale(0.5, 0.56)
		sub.Size = UDim2.new(0.9, 0, 0, 30)
		sub.TextSize = 22
		sub.Text = opciones.subtitulo or ""
		sub.Parent = pantalla
		tween(titulo, 1.4, { TextTransparency = 0 })
		tween(sub, 1.8, { TextTransparency = 0.2 })
		local espera = os.clock()
		while os.clock() - espera < 3.6 and not saltado do
			RunService.RenderStepped:Wait()
		end
		tween(titulo, 0.8, { TextTransparency = 1 })
		tween(sub, 0.8, { TextTransparency = 1 }).Completed:Wait()
	else
		tween(negro, 0.5, { BackgroundTransparency = 0 }).Completed:Wait()
	end

	-- ===== volver al juego =====
	conexionTecla:Disconnect()
	ContextActionService:UnbindAction("BloqueoCinematica")
	correccion:Destroy()
	camara.CameraType = Enum.CameraType.Custom
	camara.FieldOfView = fovAntes
	local personaje = jugador.Character
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	if humanoide then
		camara.CameraSubject = humanoide
	end
	subtitulo.Visible = false
	saltar.Visible = false
	tween(arriba, 0.6, { AnchorPoint = Vector2.new(0, 1) })
	tween(abajo, 0.6, { AnchorPoint = Vector2.new(0, 0) })
	tween(negro, 0.9, { BackgroundTransparency = 1 }).Completed:Wait()
	pantalla:Destroy()
	jugador:SetAttribute("EnCinematica", nil)
	interfazRoblox(true)
	reproduciendo = false
end

return Cinematica

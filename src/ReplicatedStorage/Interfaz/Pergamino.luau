-- Ventana de PERGAMINO para leer los textos antiguos (solo CLIENTE).
-- Ruta en Studio: ReplicatedStorage/Interfaz/Pergamino
--   Pergamino.Abrir(idTexto, nuevo)  -- nuevo = true: "añadido a tus Crónicas"
-- Los textos están en ReplicatedStorage/Config/HistoriaConfig.TEXTOS.
-- Lo usan StarterPlayerScripts/HistoriaCliente y el menú M (Crónicas).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local HistoriaConfig = require(ReplicatedStorage.Config.HistoriaConfig)

local Pergamino = {}

local TINTA = Color3.fromRGB(58, 38, 20)
local actual = nil

function Pergamino.Cerrar()
	if actual then
		local gui = actual
		actual = nil
		local ventana = gui:FindFirstChild("Ventana")
		if ventana then
			TweenService:Create(ventana, TweenInfo.new(0.2), { Position = UDim2.fromScale(0.5, 0.54) }):Play()
		end
		task.delay(0.15, function()
			gui:Destroy()
		end)
	end
end

function Pergamino.Abrir(idTexto, nuevo)
	local datos = HistoriaConfig.TEXTOS[idTexto]
	if not datos then
		return
	end
	Pergamino.Cerrar()
	local jugador = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Pergamino"
	gui.DisplayOrder = 40
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = jugador:WaitForChild("PlayerGui")
	actual = gui

	local velo = Instance.new("TextButton")
	velo.Text = ""
	velo.AutoButtonColor = false
	velo.Modal = true
	velo.Size = UDim2.fromScale(1, 1)
	velo.BackgroundColor3 = Color3.new(0, 0, 0)
	velo.BackgroundTransparency = 0.45
	velo.Parent = gui

	local ventana = Instance.new("Frame")
	ventana.Name = "Ventana"
	ventana.AnchorPoint = Vector2.new(0.5, 0.5)
	ventana.Position = UDim2.fromScale(0.5, 0.54)
	ventana.Size = UDim2.fromOffset(600, 440)
	ventana.BackgroundColor3 = Color3.fromRGB(234, 216, 178)
	ventana.BorderSizePixel = 0
	ventana.Parent = gui
	local escala = Instance.new("UIScale")
	local camara = workspace.CurrentCamera
	escala.Scale = math.clamp((camara and camara.ViewportSize.Y or 900) / 900, 0.6, 1.2)
	escala.Parent = ventana
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, 6)
	esquina.Parent = ventana
	local borde = Instance.new("UIStroke")
	borde.Color = Color3.fromRGB(120, 86, 46)
	borde.Thickness = 3
	borde.Parent = ventana
	local degradado = Instance.new("UIGradient")
	degradado.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(205, 182, 140)),
		ColorSequenceKeypoint.new(0.15, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.85, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(205, 182, 140)),
	})
	degradado.Parent = ventana

	local function texto(propiedades)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.TextColor3 = TINTA
		t.TextXAlignment = Enum.TextXAlignment.Center
		for k, v in propiedades do
			t[k] = v
		end
		t.Parent = ventana
		return t
	end
	texto({
		Position = UDim2.fromOffset(30, 24),
		Size = UDim2.new(1, -60, 0, 38),
		Font = Enum.Font.Garamond,
		TextSize = 34,
		Text = datos.titulo,
	})
	texto({
		Position = UDim2.fromOffset(30, 62),
		Size = UDim2.new(1, -60, 0, 18),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(120, 86, 46),
		Text = datos.subtitulo or "",
	})
	local adorno = Instance.new("Frame")
	adorno.AnchorPoint = Vector2.new(0.5, 0)
	adorno.Position = UDim2.new(0.5, 0, 0, 90)
	adorno.Size = UDim2.fromOffset(240, 1)
	adorno.BackgroundColor3 = Color3.fromRGB(120, 86, 46)
	adorno.BorderSizePixel = 0
	adorno.Parent = ventana
	local cuerpo = texto({
		Position = UDim2.fromOffset(40, 104),
		Size = UDim2.new(1, -80, 1, -190),
		Font = Enum.Font.Garamond,
		TextSize = 21,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = datos.texto,
		MaxVisibleGraphemes = 0,
	})
	if nuevo then
		texto({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 30, 1, -62),
			Size = UDim2.new(1, -60, 0, 18),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = Color3.fromRGB(130, 60, 170),
			Text = "✦ Añadido a tus Crónicas (menú M > Misiones)",
		})
	end
	local cerrar = Instance.new("TextButton")
	cerrar.AnchorPoint = Vector2.new(0.5, 1)
	cerrar.Position = UDim2.new(0.5, 0, 1, -16)
	cerrar.Size = UDim2.fromOffset(160, 38)
	cerrar.BackgroundColor3 = Color3.fromRGB(120, 86, 46)
	cerrar.BorderSizePixel = 0
	cerrar.Font = Enum.Font.GothamBold
	cerrar.TextSize = 15
	cerrar.TextColor3 = Color3.fromRGB(250, 238, 210)
	cerrar.Text = "CERRAR"
	cerrar.Parent = ventana
	local e2 = Instance.new("UICorner")
	e2.CornerRadius = UDim.new(0, 5)
	e2.Parent = cerrar
	cerrar.MouseButton1Click:Connect(Pergamino.Cerrar)

	TweenService:Create(ventana, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) })
		:Play()

	-- el texto aparece como si se escribiera
	local total = utf8.len(datos.texto) or #datos.texto
	task.spawn(function()
		local inicio = os.clock()
		while gui.Parent and cuerpo.MaxVisibleGraphemes < total and cuerpo.MaxVisibleGraphemes ~= -1 do
			cuerpo.MaxVisibleGraphemes = math.floor((os.clock() - inicio) * 70)
			RunService.RenderStepped:Wait()
		end
		cuerpo.MaxVisibleGraphemes = -1
	end)
	-- clic en el texto: lo enseña entero; Esc: cerrar
	velo.MouseButton1Click:Connect(function()
		if cuerpo.MaxVisibleGraphemes ~= -1 then
			cuerpo.MaxVisibleGraphemes = -1
		else
			Pergamino.Cerrar()
		end
	end)
	local conexion
	conexion = UserInputService.InputBegan:Connect(function(entrada)
		if not gui.Parent then
			conexion:Disconnect()
			return
		end
		if entrada.KeyCode == Enum.KeyCode.Escape then
			Pergamino.Cerrar()
			conexion:Disconnect()
		end
	end)
end

return Pergamino

-- Muñecos de entrenamiento para probar el combate. SOLO servidor.
-- Ruta en Studio: ServerScriptService/Combate/EntrenamientoServicio
-- Aparecen cerca del punto de inicio. No mueren: cuando su vida llega a 0 dicen
-- "¡Derrotado!" y se recuperan. Tienen vida, postura (al romperla se tambalean),
-- vuelven a su sitio si los empujas y se curan si dejas de pegarles.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ProgresionConfig = require(ReplicatedStorage.Config.ProgresionConfig)

local EntrenamientoServicio = {}

local VIDA = 3000
local POSTURA_MAX = 100
local ESPERA_CURAR = 4 -- segundos sin recibir golpes para curarse y volver a su sitio

-- Posiciones respecto al punto de inicio (en fila, mirando hacia el inicio)
local DESPLAZAMIENTOS = { Vector3.new(-10, 0, -26), Vector3.new(0, 0, -30), Vector3.new(10, 0, -26) }

local parametrosSuelo = RaycastParams.new()
parametrosSuelo.FilterType = Enum.RaycastFilterType.Include
parametrosSuelo.FilterDescendantsInstances = { Workspace.Terrain }

local function suelo(x, z)
	local r = Workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0), parametrosSuelo)
	return r and r.Position.Y or 50
end

-- Barra de vida y postura sobre la cabeza
local function crearBarras(modelo)
	local cabeza = modelo:FindFirstChild("Head")
	local cartel = Instance.new("BillboardGui")
	cartel.Name = "Barras"
	cartel.Size = UDim2.fromOffset(170, 46)
	cartel.StudsOffset = Vector3.new(0, 2.6, 0)
	cartel.MaxDistance = 80
	cartel.AlwaysOnTop = true
	cartel.Parent = cabeza

	local nombre = Instance.new("TextLabel")
	nombre.BackgroundTransparency = 1
	nombre.Size = UDim2.new(1, 0, 0, 16)
	nombre.Font = Enum.Font.GothamBold
	nombre.TextSize = 13
	nombre.TextColor3 = Color3.fromRGB(240, 230, 210)
	nombre.TextStrokeTransparency = 0.4
	nombre.Text = "Muñeco de entrenamiento"
	nombre.Parent = cartel

	local function barra(y, alto, color, nombreBarra)
		local fondo = Instance.new("Frame")
		fondo.Name = nombreBarra
		fondo.Position = UDim2.fromOffset(10, y)
		fondo.Size = UDim2.new(1, -20, 0, alto)
		fondo.BackgroundColor3 = Color3.fromRGB(20, 18, 22)
		fondo.BorderSizePixel = 0
		fondo.Parent = cartel
		local esquina = Instance.new("UICorner")
		esquina.CornerRadius = UDim.new(0, 3)
		esquina.Parent = fondo
		local relleno = Instance.new("Frame")
		relleno.Name = "Relleno"
		relleno.Size = UDim2.fromScale(1, 1)
		relleno.BackgroundColor3 = color
		relleno.BorderSizePixel = 0
		relleno.Parent = fondo
		local esquina2 = esquina:Clone()
		esquina2.Parent = relleno
		return relleno
	end
	local vida = barra(19, 9, Color3.fromRGB(210, 55, 50), "Vida")
	local postura = barra(32, 5, Color3.fromRGB(240, 190, 60), "Postura")
	postura.Size = UDim2.fromScale(0, 1)
	return vida, postura
end

local function crearMuneco(posicion, mirarA)
	local descripcion = Instance.new("HumanoidDescription")
	descripcion.HeadColor = Color3.fromRGB(196, 168, 120)
	descripcion.TorsoColor = Color3.fromRGB(150, 118, 78)
	descripcion.LeftArmColor = Color3.fromRGB(196, 168, 120)
	descripcion.RightArmColor = Color3.fromRGB(196, 168, 120)
	descripcion.LeftLegColor = Color3.fromRGB(120, 92, 60)
	descripcion.RightLegColor = Color3.fromRGB(120, 92, 60)
	local ok, modelo = pcall(function()
		return Players:CreateHumanoidModelFromDescription(descripcion, Enum.HumanoidRigType.R15)
	end)
	if not ok or not modelo then
		warn("[ENTRENAMIENTO] No se pudo crear el muñeco:", modelo)
		return nil
	end
	modelo.Name = "MunecoEntrenamiento"
	local humanoide = modelo:FindFirstChildOfClass("Humanoid")
	humanoide.MaxHealth = VIDA
	humanoide.Health = VIDA
	humanoide.WalkSpeed = 10
	humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoide.BreakJointsOnDeath = false
	humanoide.RequiresNeck = false
	humanoide:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoide:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoide:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	modelo:SetAttribute("PosturaMax", POSTURA_MAX)
	modelo:SetAttribute("Postura", 0)
	modelo:SetAttribute("ReduccionDano", 0)
	modelo:SetAttribute("EsMuneco", true)
	CollectionService:AddTag(modelo, "Enemigo")

	local inicio = CFrame.lookAt(posicion, Vector3.new(mirarA.X, posicion.Y, mirarA.Z))
	modelo:PivotTo(inicio)
	modelo.Parent = Workspace:FindFirstChild("Entrenamiento") or Workspace
	local raiz = modelo:FindFirstChild("HumanoidRootPart")
	raiz:SetNetworkOwner(nil) -- el servidor mueve al muñeco (nadie puede hacer trampas con él)

	local barraVida, barraPostura = crearBarras(modelo)
	local function refrescar()
		barraVida.Size = UDim2.fromScale(math.clamp(humanoide.Health / humanoide.MaxHealth, 0, 1), 1)
		barraPostura.Size = UDim2.fromScale(math.clamp((modelo:GetAttribute("Postura") or 0) / POSTURA_MAX, 0, 1), 1)
		barraPostura.BackgroundColor3 = if modelo:GetAttribute("Tambaleando") then Color3.fromRGB(255, 120, 40) else Color3.fromRGB(240, 190, 60)
	end
	humanoide.HealthChanged:Connect(function(vida)
		if vida <= 1 then
			-- "derrotado": se recupera enseguida
			humanoide.Health = humanoide.MaxHealth
			modelo:SetAttribute("Derrotado", os.clock())
		end
		refrescar()
	end)
	modelo:GetAttributeChangedSignal("Postura"):Connect(refrescar)
	modelo:GetAttributeChangedSignal("Tambaleando"):Connect(refrescar)

	-- se cura, baja la postura y vuelve a su sitio cuando lo dejas en paz
	task.spawn(function()
		while modelo.Parent do
			task.wait(0.5)
			local quieto = os.clock() - (modelo:GetAttribute("UltimoGolpe") or 0)
			if quieto > 1.5 and not modelo:GetAttribute("Tambaleando") then
				local postura = modelo:GetAttribute("Postura") or 0
				if postura > 0 then
					modelo:SetAttribute("Postura", math.max(0, postura - 8))
				end
			end
			if quieto > ESPERA_CURAR then
				if humanoide.Health < humanoide.MaxHealth then
					humanoide.Health = humanoide.MaxHealth
				end
				if (raiz.Position - inicio.Position).Magnitude > 3 then
					humanoide:MoveTo(inicio.Position)
					humanoide.MoveToFinished:Wait()
					modelo:PivotTo(inicio)
				end
			end
		end
	end)
	return modelo
end

function EntrenamientoServicio.Iniciar()
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Entrenamiento"
	carpeta.Parent = Workspace
	task.spawn(function()
		local base = ProgresionConfig.APARICION_INICIAL
		local centro = Vector3.new(base.X, suelo(base.X, base.Z), base.Z)
		for _, desplazamiento in DESPLAZAMIENTOS do
			local x, z = base.X + desplazamiento.X, base.Z + desplazamiento.Z
			local posicion = Vector3.new(x, suelo(x, z) + 3, z)
			crearMuneco(posicion, centro)
		end
		print("[ENTRENAMIENTO] Muñecos de entrenamiento listos cerca del inicio")
	end)
end

return EntrenamientoServicio

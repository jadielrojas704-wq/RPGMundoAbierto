-- ESCULTOR: crea estatuas de piedra con cuerpo humano real (del catálogo de Roblox),
-- con su ropa, su pelo y una pose propia. SOLO servidor.
-- Ruta en Studio: ServerScriptService/Historia/Escultor
-- Lo usa RuinasServicio para las estatuas de los Guardianes.
--
--   Escultor.Estatua({
--       apariencia = { Genero = "Mujer", Cara = 17, Pelo = 18, Ropa = "Reina" },
--       pose = { RightShoulder = CFrame.Angles(...), ... },   -- giros por articulación
--       escala = 2.4, material = Enum.Material.Marble, color = Color3...,
--   }, padre, cframe)   -> modelo de la estatua (anclado) y una función para colocar objetos en sus manos

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local AparienciaServicio = require(script.Parent.Parent.Progresion.AparienciaServicio)

local Escultor = {}

-- Convierte todo el modelo en piedra
local function petrificar(modelo, material, color)
	for _, objeto in modelo:GetDescendants() do
		if objeto:IsA("BasePart") then
			objeto.Material = material
			objeto.Color = color
			objeto.CastShadow = true
			objeto.CanCollide = objeto.Name ~= "HumanoidRootPart"
			if objeto:IsA("MeshPart") then
				objeto.TextureID = ""
			end
		elseif objeto:IsA("SurfaceAppearance") or objeto:IsA("Decal") or objeto:IsA("Texture") then
			objeto:Destroy()
		elseif objeto:IsA("Shirt") or objeto:IsA("Pants") or objeto:IsA("ShirtGraphic") then
			objeto:Destroy()
		elseif objeto:IsA("Script") or objeto:IsA("LocalScript") then
			objeto:Destroy()
		end
	end
	local raiz = modelo:FindFirstChild("HumanoidRootPart")
	if raiz then
		raiz.Transparency = 1
	end
end

function Escultor.Estatua(datos, padre, cframe)
	local descripcion = AparienciaServicio.Descripcion(datos.apariencia, true)
	local ok, modelo = pcall(function()
		return Players:CreateHumanoidModelFromDescription(descripcion, Enum.HumanoidRigType.R15)
	end)
	descripcion:Destroy()
	if not ok or not modelo then
		warn("[ESCULTOR] No pude crear la estatua", modelo)
		return nil
	end
	local humanoide = modelo:FindFirstChildOfClass("Humanoid")
	humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoide.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoide.PlatformStand = true
	local raiz = modelo:WaitForChild("HumanoidRootPart")
	raiz.Anchored = true

	-- pose: se gira cada articulación (como en las animaciones de combate)
	for nombre, giro in datos.pose or {} do
		local articulacion = modelo:FindFirstChild(nombre, true)
		if articulacion and articulacion:IsA("Motor6D") then
			articulacion.C0 = articulacion.C0 * giro
		end
	end

	-- se coloca un momento en el mundo para que las articulaciones muevan las piezas
	modelo:PivotTo(CFrame.new(cframe.Position + Vector3.new(0, 2000, 0)))
	modelo.Parent = Workspace
	task.wait(0.15)
	if datos.escala and datos.escala ~= 1 then
		modelo:ScaleTo(datos.escala)
	end
	task.wait(0.1)

	petrificar(modelo, datos.material or Enum.Material.Marble, datos.color or Color3.fromRGB(220, 214, 202))
	for _, parte in modelo:GetDescendants() do
		if parte:IsA("BasePart") then
			parte.Anchored = true
		end
	end
	-- apoya los pies en el pedestal
	local _, tamano = modelo:GetBoundingBox()
	local abajo = modelo:GetPivot().Position.Y - tamano.Y / 2
	local desplazamiento = modelo:GetPivot().Position.Y - abajo
	modelo:PivotTo(cframe * CFrame.new(0, desplazamiento - 0.05, 0))
	modelo.Name = datos.nombre or "Estatua"
	modelo.Parent = padre

	-- para colgar objetos de las manos (espada, orbe, guadaña...)
	local function enMano(mano, crear)
		local parte = modelo:FindFirstChild(mano)
		if parte then
			crear(parte.CFrame, datos.escala or 1)
		end
	end
	return modelo, enMano
end

return Escultor

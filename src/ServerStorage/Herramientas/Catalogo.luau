-- Herramienta para probar modelos de la tienda de Roblox de forma segura.
-- Ruta en Studio: ServerStorage/Herramientas/Catalogo
--
-- Carga cada modelo, BORRA todos los scripts que traiga (seguridad),
-- cuenta sus piezas y lo coloca en fila con un cartel con su número.
-- Uso desde la barra de comandos de Studio:
--     require(game.ServerStorage.Herramientas.Catalogo).Probar({ 123, 456 }, Vector3.new(0, 50, 0))

local InsertService = game:GetService("InsertService")
local Workspace = game:GetService("Workspace")

local Catalogo = {}

local CLASES_PELIGROSAS = { "Script", "LocalScript", "ModuleScript" }

-- Quita todo lo que pueda ejecutar código. Devuelve cuántas cosas borró.
function Catalogo.Limpiar(objeto)
	local borrados = 0
	for _, hijo in objeto:GetDescendants() do
		for _, clase in CLASES_PELIGROSAS do
			if hijo:IsA(clase) then
				hijo:Destroy()
				borrados += 1
				break
			end
		end
	end
	return borrados
end

-- Carga un modelo de la tienda ya limpio. Devuelve el modelo y un informe.
function Catalogo.Cargar(id)
	-- GetObjects sirve para modelos gratuitos públicos; LoadAsset solo para los tuyos
	local ok, contenedor = pcall(function()
		local objetos = game:GetObjects("rbxassetid://" .. id)
		local modelo = Instance.new("Model")
		for _, objeto in objetos do
			objeto.Parent = modelo
		end
		return modelo
	end)
	if not ok or not contenedor or #contenedor:GetChildren() == 0 then
		ok, contenedor = pcall(function()
			return InsertService:LoadAsset(id)
		end)
	end
	if not ok or not contenedor then
		return nil, "no se pudo cargar"
	end
	local borrados = Catalogo.Limpiar(contenedor)
	local piezas, mallas = 0, 0
	for _, hijo in contenedor:GetDescendants() do
		if hijo:IsA("BasePart") then
			piezas += 1
			if hijo:IsA("MeshPart") then
				mallas += 1
			end
		end
	end
	local modelo = Instance.new("Model")
	modelo.Name = "Modelo_" .. id
	for _, hijo in contenedor:GetChildren() do
		hijo.Parent = modelo
	end
	contenedor:Destroy()
	local _, tamano = modelo:GetBoundingBox()
	return modelo, string.format("%d piezas (%d mallas), %d scripts borrados, tamaño %.0f x %.0f x %.0f", piezas, mallas, borrados, tamano.X, tamano.Y, tamano.Z)
end

function Catalogo.Probar(ids, origen)
	local anterior = Workspace:FindFirstChild("Catalogo")
	if anterior then
		anterior:Destroy()
	end
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Catalogo"
	carpeta.Parent = Workspace

	local x = 0
	for _, id in ids do
		local modelo, informe = Catalogo.Cargar(id)
		print("[CATALOGO]", id, informe)
		if modelo then
			local cframe, tamano = modelo:GetBoundingBox()
			local ancho = math.max(tamano.X, tamano.Z)
			x += ancho / 2 + 6
			for _, p in modelo:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored = true
				end
			end
			modelo:PivotTo(CFrame.new(origen + Vector3.new(x, tamano.Y / 2, 0)) * (cframe - cframe.Position))
			modelo.Parent = carpeta

			-- Cartel con el número
			local cartel = Instance.new("BillboardGui")
			cartel.Size = UDim2.fromOffset(160, 40)
			cartel.StudsOffsetWorldSpace = Vector3.new(0, tamano.Y / 2 + 4, 0)
			cartel.AlwaysOnTop = true
			local texto = Instance.new("TextLabel")
			texto.Size = UDim2.fromScale(1, 1)
			texto.BackgroundTransparency = 0.3
			texto.BackgroundColor3 = Color3.new(0, 0, 0)
			texto.TextColor3 = Color3.new(1, 1, 1)
			texto.TextScaled = true
			texto.Text = tostring(id)
			texto.Parent = cartel
			cartel.Adornee = modelo.PrimaryPart or modelo:FindFirstChildWhichIsA("BasePart", true)
			cartel.Parent = modelo

			x += ancho / 2 + 6
		end
		task.wait()
	end
end

return Catalogo

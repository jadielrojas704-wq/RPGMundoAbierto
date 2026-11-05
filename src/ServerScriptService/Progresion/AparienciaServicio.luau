-- Viste al personaje según su CharacterData.Apariencia (pelo, cara, piel, ropa...). SOLO servidor.
-- Ruta en Studio: ServerScriptService/Progresion/AparienciaServicio
-- Las opciones posibles están en ReplicatedStorage/Config/AparienciaConfig.
-- Se aplica al aparecer el personaje y cada vez que el jugador cambia algo en Personalizar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AparienciaConfig = require(ReplicatedStorage.Config.AparienciaConfig)
local DatosServicio = require(script.Parent.DatosServicio)

local AparienciaServicio = {}

local TIPOS_CAPA = {
	Shirt = Enum.AccessoryType.Shirt,
	Pants = Enum.AccessoryType.Pants,
	Jacket = Enum.AccessoryType.Jacket,
	Sweater = Enum.AccessoryType.Sweater,
	DressSkirt = Enum.AccessoryType.DressSkirt,
}

local pendientes = {} -- [jugador] = true si hay que volver a vestirlo
local vistiendo = {} -- [jugador] = true mientras se aplica

-- Crea la HumanoidDescription completa a partir de la apariencia guardada
function AparienciaServicio.Descripcion(apariencia)
	local a = apariencia or AparienciaConfig.PorDefecto()
	local genero = if a.Genero == "Mujer" then "Mujer" else "Hombre"
	local ropa = AparienciaConfig.ROPA_POR_ID[a.Ropa] or AparienciaConfig.ROPA[1]
	local descripcion = Instance.new("HumanoidDescription")

	-- cuerpo (o la armadura entera del caballero)
	local cuerpo = AparienciaConfig.CUERPOS[ropa.cuerpo or genero] or AparienciaConfig.CUERPOS.Hombre
	for parte, id in cuerpo do
		descripcion[parte] = id
	end

	-- cara: cabeza realista que gesticula
	local cara = AparienciaConfig.CARAS[a.Cara] or AparienciaConfig.CARAS[1]
	descripcion.Head = cara.cabeza
	descripcion.MoodAnimation = cara.gesto

	-- piel
	local piel = AparienciaConfig.PIELES[a.Piel] or AparienciaConfig.PIELES[3]
	for _, parte in { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" } do
		descripcion[parte] = piel
	end
	descripcion.HeightScale = math.clamp(a.Altura or 1, 0.92, 1.08)

	-- accesorios rígidos (pelo, barba, sombrero, capa)
	local deCara = {} -- pelos y barbas que van en el hueco de la cara
	local sombreros = {}
	local pelo = AparienciaConfig.PELOS[a.Pelo]
	if pelo then
		if pelo.tipo == "Face" then
			table.insert(deCara, tostring(pelo.id))
		elseif pelo.tipo == "Hat" then
			table.insert(sombreros, tostring(pelo.id))
		else
			descripcion.HairAccessory = tostring(pelo.id)
		end
	end
	local barba = AparienciaConfig.BARBAS[a.Barba]
	if barba and genero == "Hombre" then
		table.insert(deCara, tostring(barba))
	end
	if ropa.sombrero then
		table.insert(sombreros, tostring(ropa.sombrero))
	end
	descripcion.FaceAccessory = table.concat(deCara, ",")
	descripcion.HatAccessory = table.concat(sombreros, ",")
	if ropa.espalda then
		descripcion.BackAccessory = tostring(ropa.espalda)
	end

	-- ropa 3D por capas
	local capas = {}
	for orden, capa in ropa.capas do
		local tipo = TIPOS_CAPA[capa[2]]
		if tipo then
			table.insert(capas, { AssetId = capa[1], AccessoryType = tipo, IsLayered = true, Order = orden })
		end
	end
	pcall(function()
		descripcion:SetAccessories(capas, false)
	end)
	return descripcion
end

local function vestir(jugador)
	if vistiendo[jugador] then
		pendientes[jugador] = true -- ya hay uno en marcha: al acabar, se repite con lo último
		return
	end
	vistiendo[jugador] = true
	repeat
		pendientes[jugador] = nil
		local datos = DatosServicio.Obtener(jugador)
		local personaje = jugador.Character
		local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
		if datos and humanoide and personaje.Parent then
			local descripcion = AparienciaServicio.Descripcion(datos.Apariencia)
			local ok, err = pcall(function()
				humanoide:ApplyDescription(descripcion)
			end)
			if not ok then
				warn("[APARIENCIA] No pude vestir a", jugador.Name, err)
			end
			descripcion:Destroy()
		end
	until not pendientes[jugador] or not jugador.Parent
	vistiendo[jugador] = nil
end

-- Pide vestir al jugador (se puede llamar muchas veces seguidas: se junta)
function AparienciaServicio.Aplicar(jugador)
	task.spawn(vestir, jugador)
end

function AparienciaServicio.Iniciar()
	local function alEntrar(jugador)
		jugador.CharacterAppearanceLoaded:Connect(function()
			if DatosServicio.Obtener(jugador) then
				AparienciaServicio.Aplicar(jugador)
			end
		end)
	end
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		alEntrar(jugador)
	end
	DatosServicio.Cargado.Event:Connect(function(jugador)
		if jugador.Character then
			AparienciaServicio.Aplicar(jugador)
		end
	end)
	Players.PlayerRemoving:Connect(function(jugador)
		pendientes[jugador] = nil
		vistiendo[jugador] = nil
	end)
end

return AparienciaServicio

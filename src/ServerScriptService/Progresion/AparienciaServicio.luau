-- Viste al personaje según su CharacterData.Apariencia (peinado, cara, piel, ropa...). SOLO servidor.
-- El aspecto lo construye ReplicatedStorage/Personaje/Vestuario (el mismo que usan los NPC).
-- Ruta en Studio: ServerScriptService/Progresion/AparienciaServicio
-- Las opciones posibles están en ReplicatedStorage/Config/AparienciaConfig.
-- Se aplica al aparecer el personaje y cada vez que el jugador cambia algo en Personalizar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AparienciaConfig = require(ReplicatedStorage.Config.AparienciaConfig)
local RazasConfig = require(ReplicatedStorage.Config.RazasConfig)
local Vestuario = require(ReplicatedStorage.Personaje.Vestuario)
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

-- (ANTIGUO: solo para las estatuas de los santuarios, con cuerpo realista y ropa 3D.
-- Los jugadores y los NPC usan ReplicatedStorage/Personaje/Vestuario.)
-- Crea la HumanoidDescription completa a partir de la apariencia guardada
-- humano = true: cuerpo realista (NPC, Custodio, estatuas). Los jugadores siempre son blocky.
-- raza: añade el físico de esa raza (orejas, cola, alas, cuernos...: RazasConfig.RASGOS).
-- semilla: número que elige la variante de la raza (para que siempre sea la misma).
function AparienciaServicio.Descripcion(apariencia, humano, raza, semilla)
	local a = apariencia or AparienciaConfig.PorDefecto()
	local genero = if a.Genero == "Mujer" then "Mujer" else "Hombre"
	local ropa = AparienciaConfig.ROPA_POR_ID[a.Ropa] or AparienciaConfig.ROPA[1]
	local descripcion = Instance.new("HumanoidDescription")

	-- cuerpo: blocky para los jugadores (partes en 0); realista para los NPC
	if humano then
		local cuerpo = AparienciaConfig.CUERPOS[genero] or AparienciaConfig.CUERPOS.Hombre
		for parte, id in cuerpo do
			descripcion[parte] = id
		end
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
	-- físico de la raza
	local rasgos = RazasConfig.Rasgos(raza, semilla)
	local espalda, cintura = {}, {}
	if ropa.espalda then
		table.insert(espalda, tostring(ropa.espalda))
	end
	for _, id in rasgos.sombrero or {} do
		table.insert(sombreros, tostring(id))
	end
	for _, id in rasgos.cara or {} do
		table.insert(deCara, tostring(id))
	end
	for _, id in rasgos.espalda or {} do
		table.insert(espalda, tostring(id))
	end
	for _, id in rasgos.cintura or {} do
		table.insert(cintura, tostring(id))
	end
	descripcion.FaceAccessory = table.concat(deCara, ",")
	descripcion.HatAccessory = table.concat(sombreros, ",")
	descripcion.BackAccessory = table.concat(espalda, ",")
	descripcion.WaistAccessory = table.concat(cintura, ",")
	if rasgos.altura then
		descripcion.HeightScale *= rasgos.altura
	end
	if rasgos.ancho then
		descripcion.WidthScale *= rasgos.ancho
		descripcion.DepthScale *= rasgos.ancho
	end
	if rasgos.piel then
		for _, parte in { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" } do
			descripcion[parte] = rasgos.piel
		end
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

	-- animaciones de movimiento fluidas (las mismas para todos) y gestos de descanso
	for propiedad, id in AparienciaConfig.ANIMACIONES do
		descripcion[propiedad] = id
	end
	pcall(function()
		local emotes, puestos = {}, {}
		for nombre, id in AparienciaConfig.DESCANSO do
			emotes[nombre] = { id }
			table.insert(puestos, { Name = nombre, Slot = #puestos + 1 })
		end
		descripcion:SetEmotes(emotes)
		descripcion:SetEquippedEmotes(puestos)
	end)
	return descripcion
end

-- pendientes[jugador] = "completo" (hay que volver a aplicar la descripción: peinado, raza...)
--                      o "ropa" (solo ropa, colores, cara y piezas: mucho más rápido)
local function vestir(jugador, modo)
	if vistiendo[jugador] then
		-- ya hay uno en marcha: al acabar, se repite con lo último
		if pendientes[jugador] ~= "completo" then
			pendientes[jugador] = modo
		end
		return
	end
	vistiendo[jugador] = true
	repeat
		pendientes[jugador] = nil
		local datos = DatosServicio.Obtener(jugador)
		local personaje = jugador.Character
		local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
		if datos and humanoide and personaje.Parent then
			local apariencia = AparienciaConfig.Completar(datos.Apariencia)
			local ok, err = pcall(function()
				-- (el color natural del pelo vuelve con la descripción: el accesorio se vuelve a poner)
				if modo ~= "ropa" or not personaje:FindFirstChild("Vestuario") or apariencia.PeloColor == "" then
					local descripcion = Vestuario.Descripcion(apariencia, datos.Raza, jugador.UserId)
					if apariencia.PeloColor == "" then
						-- "Reset" vuelve a poner el peinado con su textura original
						humanoide:ApplyDescriptionReset(descripcion)
					else
						humanoide:ApplyDescription(descripcion)
					end
					descripcion:Destroy()
				end
				Vestuario.Vestir(personaje, apariencia)
			end)
			if not ok then
				warn("[APARIENCIA] No pude vestir a", jugador.Name, err)
			end
		end
		modo = pendientes[jugador]
	until not modo or not jugador.Parent
	vistiendo[jugador] = nil
end

-- Campos que solo cambian la ropa, los colores, la cara o las piezas (no hace falta
-- volver a aplicar la HumanoidDescription entera)
local SOLO_ROPA = {
	Rostro = true, PeloColor = true, Camisa = true, CamisaColor = true, Pantalon = true,
	PantalonColor = true, Cinturon = true, CinturonColor = true, Botas = true, BotasColor = true,
	Capa = true, CapaColor = true,
}
AparienciaServicio.SOLO_ROPA = SOLO_ROPA

-- Pide vestir al jugador (se puede llamar muchas veces seguidas: se junta).
-- campo (opcional): lo que ha cambiado; si es solo ropa o color, se viste más rápido.
function AparienciaServicio.Aplicar(jugador, campo)
	task.spawn(vestir, jugador, if campo and SOLO_ROPA[campo] then "ropa" else "completo")
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

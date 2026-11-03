-- Materiales realistas (PBR) para el terreno y las piezas.
-- Ruta en Studio: ServerStorage/Herramientas/Materiales
--
-- Un "MaterialVariant" es una textura de alta calidad (color, relieve y rugosidad)
-- que sustituye a la textura de serie de Roblox. Se guardan en MaterialService.
--
-- Inspeccionar paquetes de la tienda (solo mira, no cambia nada):
--     require(game.ServerStorage.Herramientas.Materiales).Inspeccionar({ 123, 456 })
--
-- SEGURIDAD: de cada paquete solo se copian objetos MaterialVariant
-- (que son solo texturas). Todo lo demás, incluidos scripts, se ignora.

local MaterialService = game:GetService("MaterialService")

local Materiales = {}

local function cargar(id)
	local ok, objetos = pcall(function()
		return game:GetObjects("rbxassetid://" .. id)
	end)
	if not ok then
		return nil
	end
	return objetos
end

local function variantesDe(objetos)
	local lista = {}
	for _, objeto in objetos do
		if objeto:IsA("MaterialVariant") then
			table.insert(lista, objeto)
		end
		for _, hijo in objeto:GetDescendants() do
			if hijo:IsA("MaterialVariant") then
				table.insert(lista, hijo)
			end
		end
	end
	return lista
end

function Materiales.Inspeccionar(ids)
	for _, id in ids do
		local objetos = cargar(id)
		if not objetos then
			print("[MATERIALES]", id, "no se pudo cargar")
		else
			local variantes = variantesDe(objetos)
			print(string.format("[MATERIALES] %d: %d materiales", id, #variantes))
			for _, v in variantes do
				print(
					string.format(
						"[MATERIALES]    %s | base %s | %d studs | relieve %s",
						v.Name,
						v.BaseMaterial.Name,
						v.StudsPerTile,
						if v.NormalMap ~= "" then "sí" else "no"
					)
				)
			end
			for _, objeto in objetos do
				objeto:Destroy()
			end
		end
		task.wait()
	end
end

-- Copia un material de un paquete a MaterialService con un nombre nuestro
-- y lo pone como textura principal de un material de Roblox (terreno incluido).
-- elegidos = { { id = paquete, nombre = "nombre en el paquete", base = Enum.Material.Grass, escala = 12 }, ... }
function Materiales.Aplicar(elegidos)
	local paquetes = {}
	local aplicados = 0
	for _, eleccion in elegidos do
		paquetes[eleccion.id] = paquetes[eleccion.id] or cargar(eleccion.id)
		local objetos = paquetes[eleccion.id]
		local origen = nil
		if objetos then
			for _, v in variantesDe(objetos) do
				if v.Name == eleccion.nombre then
					origen = v
					break
				end
			end
		end
		if origen then
			local nombreNuevo = "Realista_" .. eleccion.base.Name
			local anterior = MaterialService:FindFirstChild(nombreNuevo)
			if anterior then
				anterior.Parent = nil
			end
			-- Copiamos solo las propiedades de textura (nada de código)
			local v = Instance.new("MaterialVariant")
			v.Name = nombreNuevo
			v.BaseMaterial = eleccion.base
			v.ColorMap = origen.ColorMap
			v.NormalMap = origen.NormalMap
			v.RoughnessMap = origen.RoughnessMap
			v.MetalnessMap = origen.MetalnessMap
			v.StudsPerTile = eleccion.escala or origen.StudsPerTile
			pcall(function()
				v.Pattern = origen.Pattern
			end)
			v.Parent = MaterialService
			MaterialService:SetBaseMaterialOverride(eleccion.base, nombreNuevo)
			aplicados += 1
			print("[MATERIALES] Aplicado", eleccion.nombre, "->", eleccion.base.Name)
		else
			warn("[MATERIALES] No encontré", eleccion.nombre, "en", eleccion.id)
		end
	end
	for _, objetos in paquetes do
		for _, objeto in objetos do
			objeto:Destroy()
		end
	end
	return aplicados
end

return Materiales

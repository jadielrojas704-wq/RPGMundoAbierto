-- MAPA del mundo (SOLO servidor): "fotografía" el terreno desde arriba una vez al arrancar
-- y se lo da a cada jugador para el minimapa (StarterPlayerScripts/Minimapa).
-- Ruta en Studio: ServerScriptService/Mundo/MapaServicio
--
-- Cada píxel son unos 5,3 studs del mundo (384 x 384 píxeles para todo el mapa de 2048 studs).
-- El color sale del material real del terreno (hierba, arena, nieve, agua...), con sombras
-- según el relieve para que se vean las montañas y los valles; los tejados de los pueblos
-- también salen. Además manda la lista de lugares (pueblos, santuarios, altar, cabaña).
-- Remotes/Mapa (RemoteFunction): el cliente pide ("Imagen") y recibe { tam, datos, lugares }.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Regiones = require(ReplicatedStorage.Config.RegionesConfig)
local HistoriaConfig = require(ReplicatedStorage.Config.HistoriaConfig)

local Remoto = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Mapa")

local MapaServicio = {}

local TAM = 384 -- píxeles por lado (unos 5,3 studs por píxel)
local ALTURA_RAYO = 650 -- por debajo de la isla flotante

local imagen = nil -- buffer RGB (TAM * TAM * 3)
local lugares = {}
local listo = false

local function color(c)
	return math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)
end

local function mezclar(r, g, b, r2, g2, b2, t)
	return r + (r2 - r) * t, g + (g2 - g) * t, b + (b2 - b) * t
end

local function fotografiar()
	local mitad = Regiones.MITAD
	local paso = Regiones.TAMANO / TAM
	local terreno = Workspace.Terrain
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local fuera = {}
	local mundo = Workspace:FindFirstChild("Mundo")
	if mundo then
		for _, nombre in { "BosqueNormal", "BosqueOscuro", "Desierto", "Montanas", "IslaCelestial" } do
			local f = mundo:FindFirstChild(nombre)
			if f then
				table.insert(fuera, f)
			end
		end
	end
	params.FilterDescendantsInstances = fuera
	params.IgnoreWater = false

	local alturas = table.create(TAM * TAM, 0)
	local colores = table.create(TAM * TAM * 3, 0)
	local cacheMaterial = {}
	local agua = { color(terreno.WaterColor) }
	for j = 0, TAM - 1 do
		for i = 0, TAM - 1 do
			local x = -mitad + (i + 0.5) * paso
			local z = -mitad + (j + 0.5) * paso
			local rayo = Workspace:Raycast(Vector3.new(x, ALTURA_RAYO, z), Vector3.new(0, -ALTURA_RAYO - 100, 0), params)
			local r, g, b, h = 40, 44, 52, 0
			if rayo then
				h = rayo.Position.Y
				if rayo.Instance == terreno then
					if rayo.Material == Enum.Material.Water then
						r, g, b = agua[1], agua[2], agua[3]
					else
						local c = cacheMaterial[rayo.Material]
						if not c then
							local ok, valor = pcall(function()
								return terreno:GetMaterialColor(rayo.Material)
							end)
							c = { color(if ok then valor else Color3.fromRGB(110, 110, 100)) }
							cacheMaterial[rayo.Material] = c
						end
						r, g, b = c[1], c[2], c[3]
					end
				else
					-- tejados y suelos de los pueblos: su color, un poco tostado
					local cr, cg, cb = color(rayo.Instance.Color)
					r, g, b = mezclar(cr, cg, cb, 150, 96, 72, 0.35)
				end
			end
			local k = j * TAM + i
			alturas[k + 1] = h
			colores[k * 3 + 1], colores[k * 3 + 2], colores[k * 3 + 3] = r, g, b
		end
		if j % 16 == 0 then
			task.wait() -- no congelar el servidor
		end
	end

	-- relieve: luz desde el noroeste (como en los mapas antiguos)
	imagen = buffer.create(TAM * TAM * 3)
	for j = 0, TAM - 1 do
		for i = 0, TAM - 1 do
			local k = j * TAM + i
			local h = alturas[k + 1]
			local hNO = alturas[math.max(j - 1, 0) * TAM + math.max(i - 1, 0) + 1]
			local hSE = alturas[math.min(j + 1, TAM - 1) * TAM + math.min(i + 1, TAM - 1) + 1]
			local luz = math.clamp(1 + (hNO - hSE) * 0.035, 0.62, 1.32)
			local alto = math.clamp((h - 30) / 260, 0, 1) * 0.12 -- lo alto, un poco más claro
			local r, g, b = colores[k * 3 + 1], colores[k * 3 + 2], colores[k * 3 + 3]
			r, g, b = r * luz, g * luz, b * luz
			r, g, b = mezclar(r, g, b, 255, 250, 240, alto)
			buffer.writeu8(imagen, k * 3, math.clamp(math.floor(r), 0, 255))
			buffer.writeu8(imagen, k * 3 + 1, math.clamp(math.floor(g), 0, 255))
			buffer.writeu8(imagen, k * 3 + 2, math.clamp(math.floor(b), 0, 255))
		end
	end
end

local function listarLugares()
	table.clear(lugares)
	local mundo = Workspace:FindFirstChild("Mundo")
	local pueblos = mundo and mundo:FindFirstChild("Pueblos")
	if pueblos then
		for _, p in pueblos:GetChildren() do
			local centro = p:GetAttribute("Centro")
			if typeof(centro) == "Vector3" then
				table.insert(lugares, {
					tipo = if p:GetAttribute("Tipo") == "Capital" then "Capital" else "Aldea",
					nombre = p:GetAttribute("Nombre") or p.Name,
					x = centro.X,
					z = centro.Z,
				})
			end
		end
	end
	for _, s in HistoriaConfig.SANTUARIOS do
		table.insert(lugares, { tipo = "Santuario", nombre = s.nombre, x = s.posicion.X, z = s.posicion.Y, guardian = s.guardian })
	end
	table.insert(lugares, { tipo = "Altar", nombre = "Altar del Ascenso", x = Regiones.ALTAR.X, z = Regiones.ALTAR.Y })
	local historia = Workspace:FindFirstChild("Historia")
	local cabana = historia and historia:FindFirstChild("CabanaEldren")
	local centro = cabana and cabana:GetAttribute("Centro")
	if typeof(centro) == "Vector3" then
		table.insert(lugares, { tipo = "Cabana", nombre = "Cabaña de Eldren", x = centro.X, z = centro.Z })
	end
end

function MapaServicio.Iniciar()
	Remoto.OnServerInvoke = function(_jugador, accion)
		if accion == "Imagen" then
			local espera = os.clock()
			while not listo and os.clock() - espera < 30 do
				task.wait(0.25)
			end
			if not listo then
				return nil
			end
			listarLugares()
			return { tam = TAM, mundo = Regiones.TAMANO, datos = imagen, lugares = lugares }
		end
		return nil
	end
	task.spawn(function()
		task.wait(3) -- que se termine de montar el mundo (santuarios, cabaña...)
		local inicio = os.clock()
		local ok, err = pcall(fotografiar)
		if not ok then
			warn("[MAPA] No pude hacer el mapa:", err)
			return
		end
		listo = true
		print(string.format("[MAPA] Mapa del mundo listo en %.1f s", os.clock() - inicio))
	end)
end

return MapaServicio

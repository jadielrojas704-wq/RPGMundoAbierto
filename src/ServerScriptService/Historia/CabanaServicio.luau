-- LA CABAÑA DE ELDREN: donde el jugador despierta tras dos días dormido. SOLO servidor.
-- Ruta en Studio: ServerScriptService/Historia/CabanaServicio
--
-- Se construye al arrancar el servidor, junto al punto de aparición (no hace falta regenerar
-- el mundo). Es de troncos, con cama, chimenea encendida, mesa con vela, estantes con
-- frascos y hierbas, porche con farol y leñera.
-- Deja en el modelo (Workspace/Historia/CabanaEldren) unos atributos para la cinemática
-- del despertar (ReplicatedStorage/Interfaz/Despertar):
--   Cama    CFrame del personaje TUMBADO en la cama
--   Salida  CFrame del personaje DE PIE junto a la cama
--   Hogar   CFrame de Eldren junto a la chimenea (a ras de suelo, mirando a la cama)
--   Puerta  CFrame de la puerta (mirando hacia fuera)
--   Porche  CFrame del sitio de Eldren en el porche (mirando hacia los muñecos)
--   Ventana CFrame de la ventana de la fachada (mirando hacia fuera, al norte: allí está el Eclipse)

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local RegionesConfig = game:GetService("ReplicatedStorage").Config.RegionesConfig
local Regiones = require(RegionesConfig)
local C = require(ServerStorage.Herramientas.Mundo.Construccion)

local M = Enum.Material

local CabanaServicio = {}

-- Medidas (en studs). Los ejes "locales": X = de oeste a este, -Z = hacia la puerta (norte)
local ANCHO, FONDO = 22, 16
local ALTO_MURO = 9
local SUBIR_SUELO = 1.35 -- el suelo de madera va sobre unos cimientos de piedra
local DESPLAZAMIENTO = Vector3.new(-6, 0, 28) -- desde el punto de aparición (al sur)

local MADERA = Color3.fromRGB(112, 78, 50)
local MADERA_OSCURA = Color3.fromRGB(72, 50, 34)
local PIEDRA = Color3.fromRGB(116, 112, 106)

local modelo = nil
local listo = Instance.new("BindableEvent")

local function sueloEn(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local r = Workspace:Raycast(Vector3.new(x, 800, z), Vector3.new(0, -1000, 0), params)
	return r and r.Position.Y
end

-- Quita árboles y rocas de alrededor
local function despejar(centro, radio)
	local mundo = Workspace:FindFirstChild("Mundo")
	if not mundo then
		return
	end
	for _, nombre in { "BosqueNormal", "BosqueOscuro", "Desierto", "Montanas" } do
		local carpeta = mundo:FindFirstChild(nombre)
		if carpeta then
			for _, cosa in carpeta:GetChildren() do
				local p = if cosa:IsA("Model") then cosa:GetPivot().Position elseif cosa:IsA("BasePart") then cosa.Position else nil
				if p and (Vector2.new(p.X, p.Z) - Vector2.new(centro.X, centro.Z)).Magnitude < radio then
					cosa:Destroy()
				end
			end
		end
	end
end

-- Allana el terreno: quita lo que sobra por arriba y rellena por abajo
local function allanar(centro, ancho, fondo)
	local terreno = Workspace.Terrain
	local tam = Vector3.new(ancho, 30, fondo)
	terreno:FillBlock(CFrame.new(centro + Vector3.new(0, 15.2, 0)), tam, M.Air)
	terreno:FillBlock(CFrame.new(centro + Vector3.new(0, -4, 0)), Vector3.new(ancho, 8, fondo), M.Ground)
	-- un borde de hierba un poco más ancho para que no quede un escalón brusco
	terreno:FillBlock(CFrame.new(centro + Vector3.new(0, -0.5, 0)), Vector3.new(ancho + 6, 1, fondo + 6), M.Grass)
	terreno:FillBlock(CFrame.new(centro + Vector3.new(0, 4.6, 0)), Vector3.new(ancho + 6, 9, fondo + 6), M.Air)
end

-- Tronco horizontal entre dos puntos (cilindro)
local function tronco(padre, desde, hasta, diametro, color)
	local largo = (hasta - desde).Magnitude
	if largo < 0.3 then
		return nil
	end
	local p = C.parte({
		Name = "Tronco",
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.lookAt((desde + hasta) / 2, hasta) * CFrame.Angles(0, math.pi / 2, 0),
		Size = Vector3.new(largo, diametro, diametro),
		Material = M.Wood,
		Color = C.variar(color or MADERA, 0.05),
		Parent = padre,
	})
	return p
end

-- Muro de troncos de A a B (en local), con huecos { u0, u1, v0, v1 } (u a lo largo del muro, v altura)
local function muroTroncos(padre, cf, a, b, huecos, sobresale)
	local direccion = (b - a).Unit
	local largo = (b - a).Magnitude
	local filas = ALTO_MURO
	for fila = 0, filas - 1 do
		local v = SUBIR_SUELO + 0.5 + fila
		-- los troncos de las esquinas sobresalen en filas alternas (como las cabañas de verdad)
		local extra = if (fila % 2 == 0) == sobresale then 0.7 else -0.45
		local tramos = { { -extra, largo + extra } }
		for _, h in huecos do
			if h[3] < v + 0.45 and h[4] > v - 0.45 then
				local nuevos = {}
				for _, t in tramos do
					if h[2] <= t[1] or h[1] >= t[2] then
						table.insert(nuevos, t)
					else
						if h[1] > t[1] then
							table.insert(nuevos, { t[1], h[1] })
						end
						if h[2] < t[2] then
							table.insert(nuevos, { h[2], t[2] })
						end
					end
				end
				tramos = nuevos
			end
		end
		for _, t in tramos do
			local p0 = a + direccion * t[1] + Vector3.new(0, v, 0)
			local p1 = a + direccion * t[2] + Vector3.new(0, v, 0)
			tronco(padre, (cf * CFrame.new(p0)).Position, (cf * CFrame.new(p1)).Position, 1.05)
		end
	end
end

local function bloque(cf, tam, material, color, nombre, colisiona)
	local p = C.bloque(modelo, cf, tam, material, color, nombre)
	if colisiona == false then
		p.CanCollide = false
	end
	return p
end

local function construir()
	local inicio = Regiones.INICIO
	local x, z = inicio.X + DESPLAZAMIENTO.X, inicio.Y + DESPLAZAMIENTO.Z
	-- altura: la media del terreno bajo la cabaña
	local suma, cuenta = 0, 0
	for _, dx in { -ANCHO / 2, 0, ANCHO / 2 } do
		for _, dz in { -FONDO / 2, 0, FONDO / 2 } do
			local y = sueloEn(x + dx, z + dz)
			if y then
				suma += y
				cuenta += 1
			end
		end
	end
	local y = if cuenta > 0 then suma / cuenta else 40
	local centro = Vector3.new(x, y, z)
	despejar(centro, 26)
	allanar(centro, ANCHO + 8, FONDO + 14)

	modelo = Instance.new("Model")
	modelo.Name = "CabanaEldren"
	-- la puerta mira al norte (hacia el punto de aparición y los muñecos)
	local cf = CFrame.lookAt(centro, centro + Vector3.new(0, 0, -1))
	local suelo = SUBIR_SUELO
	local mx, mz = ANCHO / 2, FONDO / 2

	-- ===== cimientos y suelo =====
	bloque(cf * CFrame.new(0, suelo / 2 - 0.3, 0), Vector3.new(ANCHO + 1.6, suelo + 0.6, FONDO + 1.6), M.Cobblestone, PIEDRA, "Cimientos")
	bloque(cf * CFrame.new(0, suelo - 0.05, 0), Vector3.new(ANCHO - 0.6, 0.2, FONDO - 0.6), M.WoodPlanks, Color3.fromRGB(128, 92, 60), "Suelo")

	-- ===== muros de troncos (con huecos: puerta, ventanas y chimenea) =====
	local PUERTA_X = 3 -- la puerta, un poco a la derecha de la fachada
	local frente = {
		{ mx + PUERTA_X - 2.2, mx + PUERTA_X + 2.2, suelo, suelo + 7.2 }, -- puerta
		{ 4.6, 8.0, suelo + 3, suelo + 6.2 }, -- ventana de la fachada (x = -mx + 6.3)
	}
	muroTroncos(modelo, cf, Vector3.new(-mx, 0, -mz), Vector3.new(mx, 0, -mz), frente, true)
	muroTroncos(modelo, cf, Vector3.new(-mx, 0, mz), Vector3.new(mx, 0, mz), {
		{ mx - 1.8, mx + 1.8, suelo + 3.2, suelo + 6.2 }, -- ventana del fondo, junto a la cama
	}, true)
	muroTroncos(modelo, cf, Vector3.new(-mx, 0, -mz), Vector3.new(-mx, 0, mz), {
		{ mz - 1.6, mz + 1.6, suelo + 3, suelo + 6.2 }, -- ventana del oeste
	}, false)
	muroTroncos(modelo, cf, Vector3.new(mx, 0, -mz), Vector3.new(mx, 0, mz), {
		{ mz - 2.4, mz + 2.4, -1, 99 }, -- la chimenea de piedra ocupa este trozo
	}, false)

	-- ventanas con marco (el cristal deja pasar una luz fría de fuera)
	local opcionesVentana = { luz = Color3.fromRGB(200, 214, 240), transparencia = 0.78, contraventanas = MADERA_OSCURA }
	C.ventana(modelo, cf * CFrame.new(-mx + 6.3, suelo + 4.6, -mz), 3.2, 3, opcionesVentana)
	C.ventana(modelo, cf * CFrame.new(0, suelo + 4.7, mz) * CFrame.Angles(0, math.pi, 0), 3.4, 2.8, opcionesVentana)
	C.ventana(modelo, cf * CFrame.new(-mx, suelo + 4.6, 0) * CFrame.Angles(0, math.pi / 2, 0), 3, 3, opcionesVentana)

	-- marco de la puerta y la hoja ABIERTA (pegada a la pared de dentro, para poder salir)
	local cfPuerta = cf * CFrame.new(PUERTA_X, suelo, -mz)
	bloque(cfPuerta * CFrame.new(0, 7.45, 0), Vector3.new(5.2, 0.6, 1.3), M.Wood, MADERA_OSCURA, "Dintel")
	for _, s in { -1, 1 } do
		bloque(cfPuerta * CFrame.new(s * 2.45, 3.6, 0), Vector3.new(0.5, 7.2, 1.3), M.Wood, MADERA_OSCURA, "Jamba")
	end
	local hoja = cfPuerta * CFrame.new(-2.2, 0, 0.6) * CFrame.Angles(0, math.rad(-100), 0) * CFrame.new(2.05, 3.5, 0)
	bloque(hoja, Vector3.new(4.1, 7, 0.3), M.WoodPlanks, Color3.fromRGB(96, 64, 40), "HojaPuerta", false)
	bloque(hoja * CFrame.new(0, 1.8, -0.2), Vector3.new(3.8, 0.18, 0.08), M.Metal, Color3.fromRGB(40, 38, 36), "Herraje", false)
	bloque(hoja * CFrame.new(0, -1.8, -0.2), Vector3.new(3.8, 0.18, 0.08), M.Metal, Color3.fromRGB(40, 38, 36), "Herraje", false)

	-- ===== tejado a dos aguas (cumbrera de este a oeste) con vigas por dentro =====
	C.tejado(modelo, cf * CFrame.new(0, suelo + ALTO_MURO, 0), ANCHO + 0.6, FONDO + 0.6, 0.72, {
		voladizo = 1.8,
		grosor = 0.6,
		material = M.WoodPlanks,
		color = Color3.fromRGB(70, 54, 42),
		materialFronton = M.Wood,
		colorFronton = MADERA,
	})
	for _, vx in { -7, 0, 7 } do
		bloque(cf * CFrame.new(vx, suelo + ALTO_MURO - 0.4, 0), Vector3.new(0.8, 0.8, FONDO - 0.4), M.Wood, MADERA_OSCURA, "Viga")
	end

	-- ===== chimenea de piedra (pared del este) con el fuego encendido =====
	local cumbre = suelo + ALTO_MURO + (FONDO / 2) * 0.72
	bloque(cf * CFrame.new(mx + 0.9, (cumbre + 2.5) / 2, 0), Vector3.new(2.6, cumbre + 2.5, 5.2), M.Slate, PIEDRA, "Chimenea")
	bloque(cf * CFrame.new(mx - 0.6, suelo + 1.7, 0), Vector3.new(1.2, 3.4, 4.6), M.Slate, Color3.fromRGB(70, 66, 62), "Hogar")
	bloque(cf * CFrame.new(mx - 1.05, suelo + 1.6, 0), Vector3.new(0.2, 2.6, 3.2), M.Slate, Color3.fromRGB(26, 22, 20), "Fondo", false)
	bloque(cf * CFrame.new(mx - 1.6, suelo + 3.7, 0), Vector3.new(1.6, 0.5, 5.6), M.Wood, MADERA_OSCURA, "Repisa")
	bloque(cf * CFrame.new(mx - 1.8, suelo + 0.2, 0), Vector3.new(2.6, 0.4, 5.4), M.Slate, PIEDRA, "PiedraHogar")
	for k = -1, 1 do
		tronco(modelo, (cf * CFrame.new(mx - 1.9, suelo + 0.6, k * 0.7 - 0.9)).Position, (cf * CFrame.new(mx - 1.4, suelo + 0.6, k * 0.7 + 0.9)).Position, 0.45, MADERA_OSCURA)
	end
	C.fuego(modelo, (cf * CFrame.new(mx - 1.7, suelo + 0.9, 0)).Position, 2.4)
	C.humo(modelo, (cf * CFrame.new(mx + 0.9, cumbre + 3.2, 0)).Position)
	-- objetos de la repisa
	for k, color in { Color3.fromRGB(70, 120, 90), Color3.fromRGB(130, 60, 140), Color3.fromRGB(170, 130, 60) } do
		C.parte({ Name = "Frasco", Shape = Enum.PartType.Cylinder, CFrame = cf * CFrame.new(mx - 1.6, suelo + 4.35, -2 + k * 0.9) * CFrame.Angles(0, 0, math.pi / 2), Size = Vector3.new(0.8, 0.5, 0.5), Material = M.Glass, Color = color, Transparency = 0.25, CanCollide = false, Parent = modelo })
	end
	-- caldero junto al fuego
	C.parte({ Name = "Caldero", Shape = Enum.PartType.Ball, CFrame = cf * CFrame.new(mx - 2.2, suelo + 0.95, -4.2), Size = Vector3.new(2.2, 1.9, 2.2), Material = M.Metal, Color = Color3.fromRGB(34, 32, 32), Parent = modelo })

	-- ===== la cama (esquina del fondo, al oeste), con la cabecera contra la pared del fondo =====
	local camaX, camaZ0, camaZ1 = -mx + 3.2, 0.4, mz - 0.7
	local camaZ = (camaZ0 + camaZ1) / 2
	local largoCama = camaZ1 - camaZ0
	bloque(cf * CFrame.new(camaX, suelo + 0.55, camaZ), Vector3.new(4.3, 1.1, largoCama), M.Wood, MADERA_OSCURA, "Cama")
	bloque(cf * CFrame.new(camaX, suelo + 1.45, camaZ), Vector3.new(3.9, 0.7, largoCama - 0.3), M.Fabric, Color3.fromRGB(226, 214, 190), "Colchon")
	bloque(cf * CFrame.new(camaX, suelo + 1.95, camaZ1 - 1.1), Vector3.new(3, 0.45, 1.3), M.Fabric, Color3.fromRGB(240, 236, 226), "Almohada", false)
	bloque(cf * CFrame.new(camaX, suelo + 1.88, camaZ0 + (largoCama - 2.2) / 2), Vector3.new(4.1, 0.25, largoCama - 2.2), M.Fabric, Color3.fromRGB(122, 44, 40), "Manta", false)
	bloque(cf * CFrame.new(camaX, suelo + 1.6, camaZ1 + 0.1), Vector3.new(4.6, 3.2, 0.5), M.Wood, MADERA_OSCURA, "Cabecero")
	bloque(cf * CFrame.new(camaX, suelo + 1, camaZ0 - 0.1), Vector3.new(4.6, 2, 0.4), M.Wood, MADERA_OSCURA, "Piecero")
	-- baúl a los pies de la cama y alfombra
	bloque(cf * CFrame.new(camaX, suelo + 0.85, camaZ0 - 1.6), Vector3.new(3.4, 1.7, 1.9), M.WoodPlanks, Color3.fromRGB(104, 70, 44), "Baul")
	bloque(cf * CFrame.new(camaX, suelo + 1.72, camaZ0 - 1.6), Vector3.new(3.5, 0.12, 2), M.Metal, Color3.fromRGB(60, 56, 52), "HerrajeBaul", false)
	C.disco(modelo, (cf * CFrame.new(-1.5, suelo + 0.02, 1)).Position, 7, M.Fabric, Color3.fromRGB(120, 70, 50), "Alfombra")

	-- ===== mesa con vela, cuenco y libro; dos taburetes =====
	local mesa = cf * CFrame.new(2.5, suelo, 4.6)
	bloque(mesa * CFrame.new(0, 3, 0), Vector3.new(5, 0.3, 3), M.WoodPlanks, Color3.fromRGB(120, 84, 52), "Mesa")
	for _, sx in { -2.1, 2.1 } do
		for _, sz in { -1.1, 1.1 } do
			bloque(mesa * CFrame.new(sx, 1.42, sz), Vector3.new(0.35, 2.85, 0.35), M.Wood, MADERA_OSCURA, "Pata")
		end
	end
	for _, sx in { -3.6, 3.6 } do
		C.columna(modelo, (mesa * CFrame.new(sx, 0, 0)).Position, 1.9, 1.4, M.Wood, MADERA, "Taburete")
	end
	local vela = C.parte({ Name = "Vela", Shape = Enum.PartType.Cylinder, CFrame = mesa * CFrame.new(-1, 3.55, 0) * CFrame.Angles(0, 0, math.pi / 2), Size = Vector3.new(0.8, 0.35, 0.35), Material = M.SmoothPlastic, Color = Color3.fromRGB(240, 230, 200), Parent = modelo })
	local llama = Instance.new("Fire")
	llama.Size = 0.6
	llama.Heat = 2
	llama.Parent = vela
	C.luz(vela, Color3.fromRGB(255, 190, 120), 1.1, 14)
	C.parte({ Name = "Cuenco", Shape = Enum.PartType.Ball, CFrame = mesa * CFrame.new(1, 3.3, 0.2), Size = Vector3.new(1.3, 0.6, 1.3), Material = M.Wood, Color = Color3.fromRGB(140, 100, 64), Parent = modelo })
	bloque(mesa * CFrame.new(0.4, 3.25, -0.8) * CFrame.Angles(0, 0.4, 0), Vector3.new(1.4, 0.25, 1.8), M.Fabric, Color3.fromRGB(110, 30, 34), "Libro", false)

	-- ===== estantes con frascos (pared del oeste) y hierbas colgando de las vigas =====
	for k, altura in { 3.2, 5 } do
		local estante = bloque(cf * CFrame.new(-mx + 0.9, suelo + altura, -4), Vector3.new(1.2, 0.2, 5), M.WoodPlanks, MADERA, "Estante")
		for j = 1, 4 do
			local color = ({ Color3.fromRGB(80, 140, 110), Color3.fromRGB(160, 80, 60), Color3.fromRGB(90, 90, 160), Color3.fromRGB(200, 170, 90) })[(j + k) % 4 + 1]
			C.parte({ Name = "Frasco", Shape = Enum.PartType.Cylinder, CFrame = estante.CFrame * CFrame.new(0, 0.5, -2.4 + j * 1.05) * CFrame.Angles(0, 0, math.pi / 2), Size = Vector3.new(C.n(0.7, 1), 0.55, 0.55), Material = M.Glass, Color = color, Transparency = 0.2, CanCollide = false, Parent = modelo })
		end
	end
	for k = 1, 5 do
		local cfHierba = cf * CFrame.new(-7, suelo + ALTO_MURO - 1.4, -5 + k * 1.6)
		bloque(cfHierba, Vector3.new(0.5, 1.4, 0.5), M.Grass, Color3.fromRGB(90, 120 + k * 8, 70), "Hierbas", false)
		bloque(cfHierba * CFrame.new(0, 0.95, 0), Vector3.new(0.06, 0.6, 0.06), M.Fabric, Color3.fromRGB(180, 160, 120), "Cuerda", false)
	end
	-- el bastón de Eldren apoyado junto a la puerta
	C.parte({ Name = "Baston", Shape = Enum.PartType.Cylinder, CFrame = cf * CFrame.new(PUERTA_X + 3.4, suelo + 3, -mz + 1) * CFrame.Angles(0, 0, math.rad(80)), Size = Vector3.new(6, 0.35, 0.35), Material = M.Wood, Color = MADERA_OSCURA, CanCollide = false, Parent = modelo })

	-- una luz suave para que dentro se vea (el fuego y la vela hacen el resto)
	local luzTecho = bloque(cf * CFrame.new(0, suelo + 7, 0), Vector3.new(0.2, 0.2, 0.2), M.SmoothPlastic, MADERA, "LuzTecho", false)
	luzTecho.Transparency = 1
	C.luz(luzTecho, Color3.fromRGB(255, 200, 150), 0.6, 24)

	-- ===== porche: tarima, dos postes, tejadillo y farol =====
	local porche = cf * CFrame.new(0, suelo, -mz - 2.6)
	bloque(porche * CFrame.new(0, -0.15, 0), Vector3.new(ANCHO + 1, 0.3, 4.4), M.WoodPlanks, Color3.fromRGB(122, 88, 56), "Tarima")
	bloque(porche * CFrame.new(PUERTA_X, -0.75, -2.9), Vector3.new(5, 0.4, 1.6), M.WoodPlanks, Color3.fromRGB(122, 88, 56), "Escalon")
	for _, sx in { -mx + 0.4, mx - 0.4 } do
		bloque(porche * CFrame.new(sx, 3.6, -1.8), Vector3.new(0.7, 7.4, 0.7), M.Wood, MADERA_OSCURA, "Poste")
	end
	bloque(porche * CFrame.new(0, 7.55, -0.4) * CFrame.Angles(math.rad(-14), 0, 0), Vector3.new(ANCHO + 1.4, 0.4, 5), M.WoodPlanks, Color3.fromRGB(70, 54, 42), "Tejadillo")
	local farol = C.bloque(modelo, porche * CFrame.new(PUERTA_X - 3.4, 6, -1.6), Vector3.new(0.8, 1.1, 0.8), M.Neon, Color3.fromRGB(255, 190, 110), "Farol")
	farol.CanCollide = false
	C.luz(farol, Color3.fromRGB(255, 180, 100), 1.4, 20)

	-- ===== fuera: leñera, barril y sacos =====
	for fila = 0, 2 do
		for k = 0, 4 - fila do
			local base = cf * CFrame.new(mx + 3, 0.5 + fila * 0.9, -7.6 + k * 1.0 + fila * 0.5)
			tronco(modelo, (base * CFrame.new(-1.5, 0, 0)).Position, (base * CFrame.new(1.5, 0, 0)).Position, 0.9, Color3.fromRGB(130, 92, 58))
		end
	end
	C.barril(modelo, (cf * CFrame.new(-mx - 1.8, 0, -mz + 1.5)).Position)
	C.saco(modelo, (cf * CFrame.new(-mx - 1.6, 0, -mz + 4.2)).Position)

	-- ===== datos para la cinemática y para Eldren =====
	local alto = cf * CFrame.new(0, suelo, 0)
	local cabeza = cf:VectorToWorldSpace(Vector3.new(0, 0, 1)) -- hacia la cabecera
	local posCama = (cf * CFrame.new(camaX, suelo + 2.45, camaZ1 - 3.2)).Position
	-- tumbado boca arriba: mira al techo, con la cabeza hacia la cabecera
	local cama = CFrame.fromMatrix(posCama, cabeza:Cross(Vector3.new(0, 0, 0) - Vector3.yAxis), cabeza)
	modelo:SetAttribute("Cama", cama)
	local salida = (cf * CFrame.new(camaX + 3.6, suelo, camaZ - 1)).Position
	local hogar = (cf * CFrame.new(mx - 4.5, suelo, -1.4)).Position
	modelo:SetAttribute("Salida", CFrame.lookAt(salida, Vector3.new(hogar.X, salida.Y, hogar.Z)))
	modelo:SetAttribute("Hogar", CFrame.lookAt(hogar, Vector3.new(salida.X, hogar.Y, salida.Z)))
	modelo:SetAttribute("Puerta", cf * CFrame.new(PUERTA_X, suelo, -mz))
	modelo:SetAttribute("Ventana", cf * CFrame.new(-mx + 6.3, suelo + 4.6, -mz)) -- ventana de la fachada (mira al norte)
	local porcheEldren = (cf * CFrame.new(PUERTA_X + 5, suelo, -mz - 2.4)).Position
	modelo:SetAttribute("Porche", CFrame.lookAt(porcheEldren, porcheEldren + Vector3.new(0, 0, -1)))
	modelo:SetAttribute("Centro", alto.Position)
	modelo:SetAttribute("Nombre", "Cabaña de Eldren")

	-- siempre cargada en todos los clientes (la cinemática del despertar la necesita)
	modelo.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	modelo.WorldPivot = alto
	local carpeta = Workspace:FindFirstChild("Historia") or Workspace
	modelo.Parent = carpeta
	listo:Fire()
	print("[HISTORIA] Cabaña de Eldren lista")
end

function CabanaServicio.Modelo()
	if not modelo then
		listo.Event:Wait()
	end
	return modelo
end

function CabanaServicio.Iniciar()
	local ok, err = pcall(construir)
	if not ok then
		warn("[HISTORIA] No pude construir la cabaña:", err)
		listo:Fire()
	end
end

return CabanaServicio

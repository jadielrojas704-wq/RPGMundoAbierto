-- Estructuras del mundo: fogata, puentes, Altar del Ascenso e Isla Celestial.
-- Ruta en Studio: ServerStorage/Herramientas/Mundo/Estructuras
-- Lo usa ServerStorage/Herramientas/GenerarMundo. No se ejecuta solo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Regiones = require(ReplicatedStorage.Config.RegionesConfig)
local Terreno = require(script.Parent.Terreno)
local Vegetacion = require(script.Parent.Vegetacion)

local Estructuras = {}

local M = Enum.Material
local NIVEL_AGUA = Regiones.NIVEL_AGUA
local TEXTURA_HUMO = "rbxasset://textures/particles/smoke_main.dds"

local rng = Random.new(Terreno.SEMILLA + 100)

local function n(a, b)
	return rng:NextNumber(a, b)
end

local function variarColor(color, cantidad)
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, math.clamp(s + n(-cantidad, cantidad), 0, 1), math.clamp(v + n(-cantidad, cantidad), 0, 1))
end

local function parte(propiedades)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	for nombre, valor in propiedades do
		if nombre ~= "Parent" then
			p[nombre] = valor
		end
	end
	p.Parent = propiedades.Parent
	return p
end

local function alturaEn(x, z)
	return Terreno.muestrear(x, z).altura
end

-- ===== FOGATA (zona de inicio) =====

function Estructuras.Fogata(posicion, padre)
	local modelo = Instance.new("Model")
	modelo.Name = "Fogata"

	for i = 1, 9 do
		local angulo = (i / 9) * math.pi * 2
		parte({
			Name = "Piedra",
			Size = Vector3.new(1.2, 0.8, 1),
			CFrame = CFrame.new(posicion + Vector3.new(math.cos(angulo) * 2.4, 0.3, math.sin(angulo) * 2.4))
				* CFrame.Angles(0, -angulo + n(-0.3, 0.3), n(-0.2, 0.2)),
			Material = M.Slate,
			Color = variarColor(Color3.fromRGB(95, 92, 88), 0.05),
			Parent = modelo,
		})
	end
	for i = 1, 3 do
		parte({
			Name = "Lena",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.4, 0.6, 0.6),
			CFrame = CFrame.new(posicion + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, i * math.pi / 3, math.rad(12)),
			Material = M.Wood,
			Color = Color3.fromRGB(60, 45, 34),
			CanCollide = false,
			Parent = modelo,
		})
	end

	local centro = parte({
		Name = "Fuego",
		Size = Vector3.one,
		CFrame = CFrame.new(posicion + Vector3.new(0, 1, 0)),
		Transparency = 1,
		CanCollide = false,
		Parent = modelo,
	})
	local fuego = Instance.new("Fire")
	fuego.Size = 4
	fuego.Heat = 8
	fuego.Color = Color3.fromRGB(255, 140, 50)
	fuego.SecondaryColor = Color3.fromRGB(255, 70, 20)
	fuego.Parent = centro

	local chispas = Instance.new("ParticleEmitter")
	chispas.Name = "Chispas"
	chispas.Rate = 6
	chispas.Lifetime = NumberRange.new(1, 2)
	chispas.Speed = NumberRange.new(3, 6)
	chispas.SpreadAngle = Vector2.new(20, 20)
	chispas.Acceleration = Vector3.new(0, 2, 0)
	chispas.WindAffectsDrag = true
	chispas.Drag = 1
	chispas.Size = NumberSequence.new(0.12, 0)
	chispas.LightEmission = 1
	chispas.Color = ColorSequence.new(Color3.fromRGB(255, 170, 60))
	chispas.Parent = centro

	local humo = Instance.new("ParticleEmitter")
	humo.Name = "Humo"
	humo.Texture = TEXTURA_HUMO
	humo.Rate = 3
	humo.Lifetime = NumberRange.new(4, 6)
	humo.Speed = NumberRange.new(2, 3)
	humo.SpreadAngle = Vector2.new(10, 10)
	humo.WindAffectsDrag = true
	humo.Drag = 0.5
	humo.LightInfluence = 1
	humo.Size = NumberSequence.new(1, 5)
	humo.Transparency = NumberSequence.new(0.75, 1)
	humo.Color = ColorSequence.new(Color3.fromRGB(110, 105, 100))
	humo.Parent = centro

	local luz = Instance.new("PointLight")
	luz.Color = Color3.fromRGB(255, 150, 70)
	luz.Brightness = 2
	luz.Range = 22
	luz.Shadows = true
	luz.Parent = centro

	modelo.Parent = padre
end

-- ===== PUENTES (donde los caminos cruzan el río) =====

local function construirPuente(desde, hasta, padre)
	local modelo = Instance.new("Model")
	modelo.Name = "Puente"
	local yDesde = alturaEn(desde.X, desde.Y)
	local yHasta = alturaEn(hasta.X, hasta.Y)
	local altura = math.max(yDesde, yHasta, NIVEL_AGUA + 3) + 0.6
	local a = Vector3.new(desde.X, altura, desde.Y)
	local b = Vector3.new(hasta.X, altura, hasta.Y)
	local largo = (b - a).Magnitude
	local orientacion = CFrame.lookAt(a, b)
	local colorMadera = Color3.fromRGB(96, 74, 52)

	-- Tablones
	local numeroTablas = math.floor(largo / 1.6)
	for i = 0, numeroTablas do
		parte({
			Name = "Tabla",
			Size = Vector3.new(7, 0.5, 1.4),
			CFrame = orientacion * CFrame.new(0, 0, -i * 1.6) * CFrame.Angles(0, n(-0.02, 0.02), n(-0.02, 0.02)),
			Material = M.WoodPlanks,
			Color = variarColor(colorMadera, 0.05),
			Parent = modelo,
		})
	end
	-- Vigas y postes con barandilla
	for _, lado in { -3.2, 3.2 } do
		parte({
			Name = "Viga",
			Size = Vector3.new(0.6, 0.7, largo),
			CFrame = orientacion * CFrame.new(lado, -0.5, -largo / 2),
			Material = M.Wood,
			Color = colorMadera,
			Parent = modelo,
		})
		parte({
			Name = "Baranda",
			Size = Vector3.new(0.3, 0.3, largo),
			CFrame = orientacion * CFrame.new(lado, 2.6, -largo / 2),
			Material = M.Wood,
			Color = colorMadera,
			Parent = modelo,
		})
		for i = 0, math.floor(largo / 6) do
			local poste = orientacion * CFrame.new(lado, 0, -i * 6)
			parte({
				Name = "Poste",
				Size = Vector3.new(0.5, 3, 0.5),
				CFrame = poste * CFrame.new(0, 1.3, 0),
				Material = M.Wood,
				Color = colorMadera,
				Parent = modelo,
			})
			-- Pilar hasta el fondo del río
			parte({
				Name = "Pilar",
				Size = Vector3.new(0.8, 14, 0.8),
				CFrame = poste * CFrame.new(0, -7.5, 0),
				Material = M.Wood,
				Color = Color3.fromRGB(70, 56, 42),
				Parent = modelo,
			})
		end
	end
	modelo.Parent = padre
end

function Estructuras.Puentes(padre)
	local puentes = 0
	for _, puntos in Terreno.PuntosCaminos(2) do
		local dentro = nil
		for i, punto in puntos do
			local d = Terreno.muestrear(punto.X, punto.Y)
			local enAgua = d.rio > 0.35 and d.altura < NIVEL_AGUA + 3
			if enAgua and not dentro then
				dentro = i
			elseif not enAgua and dentro then
				local desde = puntos[math.max(1, dentro - 3)]
				local hasta = puntos[math.min(#puntos, i + 2)]
				construirPuente(desde, hasta, padre)
				puentes += 1
				dentro = nil
			end
		end
	end
	return puentes
end

-- ===== ALTAR DEL ASCENSO (al pie de las montañas) =====
-- Ruinas con tres sellos, uno por región. Por ahora están apagados:
-- más adelante se encenderán al completar cada región y abrirán el camino a la isla.

function Estructuras.Altar(padre)
	local modelo = Instance.new("Model")
	modelo.Name = "AltarDelAscenso"
	local centro2 = Regiones.ALTAR
	local base = Vector3.new(centro2.X, alturaEn(centro2.X, centro2.Y), centro2.Y)
	local colorPiedra = Color3.fromRGB(150, 144, 132)

	-- Plataforma circular
	parte({
		Name = "Plataforma",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 34, 34),
		CFrame = CFrame.new(base + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Material = M.Cobblestone,
		Color = colorPiedra,
		Parent = modelo,
	})

	-- Pilares rotos alrededor
	for i = 1, 10 do
		local angulo = i / 10 * math.pi * 2
		local alto = if rng:NextNumber() < 0.4 then n(3, 7) else n(12, 18)
		parte({
			Name = "Pilar",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(alto, 2.6, 2.6),
			CFrame = CFrame.new(base + Vector3.new(math.cos(angulo) * 15, alto / 2 + 1, math.sin(angulo) * 15))
				* CFrame.Angles(n(-0.05, 0.05), 0, math.pi / 2 + n(-0.05, 0.05)),
			Material = M.Limestone,
			Color = variarColor(colorPiedra, 0.04),
			Parent = modelo,
		})
	end
	-- Algún trozo de pilar caído
	for _ = 1, 3 do
		local angulo = n(0, 6.28)
		parte({
			Name = "PilarCaido",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(n(4, 7), 2.4, 2.4),
			CFrame = CFrame.new(base + Vector3.new(math.cos(angulo) * n(18, 24), 1.4, math.sin(angulo) * n(18, 24)))
				* CFrame.Angles(0, n(0, 6.28), 0),
			Material = M.Limestone,
			Color = variarColor(colorPiedra, 0.04),
			Parent = modelo,
		})
	end

	-- Tres sellos (uno por región), apagados
	local sellos = { "Bosque", "Desierto", "Oscuro" }
	for i, region in sellos do
		local angulo = (i / 3) * math.pi * 2 + math.pi / 2
		local posicion = base + Vector3.new(math.cos(angulo) * 7, 1.4, math.sin(angulo) * 7)
		local pedestal = parte({
			Name = "Sello_" .. region,
			Size = Vector3.new(2.4, 2.4, 2.4),
			CFrame = CFrame.new(posicion + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, -angulo, 0),
			Material = M.Slate,
			Color = Color3.fromRGB(80, 78, 74),
			Parent = modelo,
		})
		pedestal:SetAttribute("Region", region)
		pedestal:SetAttribute("Encendido", false)
	end

	modelo.Parent = padre
	return modelo
end

-- ===== ISLA CELESTIAL =====

local function nubeGrande(posicion, tamano, padre)
	local nube = parte({
		Name = "Nube",
		Size = tamano,
		CFrame = CFrame.new(posicion) * CFrame.Angles(0, n(0, 6.28), 0),
		Color = Color3.fromRGB(246, 242, 236),
		Material = M.SmoothPlastic,
		Transparency = n(0.25, 0.4),
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = padre,
	})
	local malla = Instance.new("SpecialMesh")
	malla.MeshType = Enum.MeshType.Sphere
	malla.Parent = nube
	return nube
end

function Estructuras.Isla(padre)
	local isla = Regiones.ISLA
	local modelo = Instance.new("Folder")
	modelo.Name = "IslaCelestial"
	modelo.Parent = padre

	-- Ruinas en lo alto: anillo de columnas y un arco
	local cima = Terreno.alturasIsla(isla.X, isla.Z) or isla.Y
	local centro = Vector3.new(isla.X, cima, isla.Z)
	local colorPiedra = Color3.fromRGB(226, 218, 200)
	for i = 1, 12 do
		local angulo = i / 12 * math.pi * 2
		local x, z = centro.X + math.cos(angulo) * 26, centro.Z + math.sin(angulo) * 26
		local suelo = Terreno.alturasIsla(x, z) or cima
		local alto = if i % 3 == 0 then n(5, 9) else n(16, 22)
		parte({
			Name = "Columna",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(alto, 3, 3),
			CFrame = CFrame.new(x, suelo + alto / 2 - 0.5, z) * CFrame.Angles(0, 0, math.pi / 2),
			Material = M.Marble,
			Color = variarColor(colorPiedra, 0.03),
			Parent = modelo,
		})
	end
	-- Arco central
	for _, lado in { -6, 6 } do
		parte({
			Name = "Arco",
			Size = Vector3.new(3, 20, 3),
			CFrame = CFrame.new(centro + Vector3.new(lado, 10, 0)),
			Material = M.Marble,
			Color = colorPiedra,
			Parent = modelo,
		})
	end
	parte({
		Name = "Arco",
		Size = Vector3.new(16, 3, 3.4),
		CFrame = CFrame.new(centro + Vector3.new(0, 21, 0)),
		Material = M.Marble,
		Color = colorPiedra,
		Parent = modelo,
	})

	-- Árboles dorados
	for _ = 1, 10 do
		local angulo, distancia = n(0, 6.28), n(40, 85)
		local x, z = isla.X + math.cos(angulo) * distancia, isla.Z + math.sin(angulo) * distancia
		local suelo = Terreno.alturasIsla(x, z)
		if suelo then
			Vegetacion.ArbolDorado(Vector3.new(x, suelo, z), modelo)
		end
	end

	-- Cascada que cae por el borde al vacío
	local angulo = 0.6
	local bordeX, bordeZ = isla.X + math.cos(angulo) * 100, isla.Z + math.sin(angulo) * 100
	local alturaBorde = Terreno.alturasIsla(isla.X + math.cos(angulo) * 92, isla.Z + math.sin(angulo) * 92) or isla.Y
	local caida = parte({
		Name = "Cascada",
		Size = Vector3.new(10, 1, 2),
		CFrame = CFrame.lookAt(Vector3.new(bordeX, alturaBorde - 1, bordeZ), Vector3.new(isla.X, alturaBorde - 1, isla.Z)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = modelo,
	})
	local agua = Instance.new("ParticleEmitter")
	agua.Name = "Agua"
	agua.Texture = TEXTURA_HUMO
	agua.Rate = 45
	agua.Lifetime = NumberRange.new(5, 7)
	agua.Speed = NumberRange.new(1, 3)
	agua.SpreadAngle = Vector2.new(5, 5)
	agua.Acceleration = Vector3.new(0, -35, 0)
	agua.Size = NumberSequence.new(4, 12)
	agua.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.7, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	agua.Color = ColorSequence.new(Color3.fromRGB(220, 238, 248))
	agua.LightInfluence = 1
	agua.Parent = caida

	-- Banco de nubes que la tapa casi entera desde abajo
	for _ = 1, 30 do
		local a, r = n(0, 6.28), n(40, 200)
		nubeGrande(
			Vector3.new(isla.X + math.cos(a) * r, isla.Y - n(50, 130), isla.Z + math.sin(a) * r),
			Vector3.new(n(70, 150), n(25, 45), n(70, 150)),
			modelo
		)
	end
	-- Nubes suaves alrededor (partículas) para que el borde no sea duro
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local emisorParte = parte({
			Name = "EmisorNubes",
			Size = Vector3.new(60, 20, 60),
			CFrame = CFrame.new(isla.X + math.cos(a) * 150, isla.Y - 70, isla.Z + math.sin(a) * 150),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			Parent = modelo,
		})
		local nubes = Instance.new("ParticleEmitter")
		nubes.Name = "Nubes"
		nubes.Texture = TEXTURA_HUMO
		nubes.Rate = 0.5
		nubes.Lifetime = NumberRange.new(25, 35)
		nubes.Speed = NumberRange.new(0.3, 1)
		nubes.Rotation = NumberRange.new(0, 360)
		nubes.RotSpeed = NumberRange.new(-3, 3)
		nubes.Size = NumberSequence.new(60, 100)
		nubes.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.45),
			NumberSequenceKeypoint.new(0.8, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		nubes.Color = ColorSequence.new(Color3.fromRGB(250, 245, 238))
		nubes.LightInfluence = 1
		nubes.Parent = emisorParte
	end

	return modelo
end

return Estructuras

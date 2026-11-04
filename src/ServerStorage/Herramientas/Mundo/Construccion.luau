-- Piezas básicas para construir edificios: muros, tejados, ventanas, puertas,
-- faroles, toldos, estandartes, barriles, carteles...
-- Ruta en Studio: ServerStorage/Herramientas/Mundo/Construccion
-- Lo usa ServerStorage/Herramientas/Mundo/Pueblos. No se ejecuta solo.
--
-- Todo se construye "en local": cada función recibe un CFrame de referencia
-- (el centro del suelo del edificio mirando hacia su puerta, que es -Z)
-- y coloca las piezas respecto a él.

local Construccion = {}

local M = Enum.Material
local TEXTURA_HUMO = "rbxasset://textures/particles/smoke_main.dds"
local MALLA_CONO = "rbxassetid://1033714" -- cono (2 de ancho, 1 de alto)

local rng = Random.new(77)
Construccion.rng = rng

function Construccion.n(a, b)
	return rng:NextNumber(a, b)
end

function Construccion.variar(color, cantidad)
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(
		h,
		math.clamp(s + rng:NextNumber(-cantidad, cantidad), 0, 1),
		math.clamp(v + rng:NextNumber(-cantidad, cantidad), 0, 1)
	)
end

-- Pieza anclada básica
function Construccion.parte(propiedades, clase)
	local p = Instance.new(clase or "Part")
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
local parte = Construccion.parte

-- Bloque: cf = centro del bloque
function Construccion.bloque(padre, cf, tamano, material, color, nombre)
	return parte({
		Name = nombre or "Bloque",
		CFrame = cf,
		Size = tamano,
		Material = material,
		Color = color,
		Parent = padre,
	})
end

-- Cilindro vertical: base = centro del pie
function Construccion.columna(padre, base, alto, grosor, material, color, nombre)
	return parte({
		Name = nombre or "Columna",
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(base + Vector3.new(0, alto / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Size = Vector3.new(alto, grosor, grosor),
		Material = material,
		Color = color,
		Parent = padre,
	})
end

-- Viga cilíndrica entre dos puntos
function Construccion.viga(padre, desde, hasta, grosor, material, color, nombre)
	local largo = (hasta - desde).Magnitude
	return parte({
		Name = nombre or "Viga",
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.lookAt((desde + hasta) / 2, hasta) * CFrame.Angles(0, math.pi / 2, 0),
		Size = Vector3.new(largo, grosor, grosor),
		Material = material,
		Color = color,
		Parent = padre,
	})
end

-- Listón cuadrado entre dos puntos (vigas de madera de las casas)
function Construccion.liston(padre, desde, hasta, grosor, material, color, nombre)
	local largo = (hasta - desde).Magnitude
	return parte({
		Name = nombre or "Liston",
		CFrame = CFrame.lookAt((desde + hasta) / 2, hasta),
		Size = Vector3.new(grosor, grosor, largo),
		Material = material,
		Color = color,
		Parent = padre,
	})
end

-- Esfera (o media esfera si se hunde en otra pieza)
function Construccion.bola(padre, centro, diametro, material, color, nombre)
	return parte({
		Name = nombre or "Bola",
		Shape = Enum.PartType.Ball,
		CFrame = CFrame.new(centro),
		Size = Vector3.new(diametro, diametro, diametro),
		Material = material,
		Color = color,
		Parent = padre,
	})
end

-- Cono (tejados de torres): base = centro de la base del cono
function Construccion.cono(padre, base, diametro, alto, material, color, nombre)
	local p = parte({
		Name = nombre or "Cono",
		CFrame = CFrame.new(base + Vector3.new(0, alto / 2, 0)),
		Size = Vector3.new(diametro, alto, diametro),
		Material = material,
		Color = color,
		Parent = padre,
	})
	local malla = Instance.new("SpecialMesh")
	malla.MeshType = Enum.MeshType.FileMesh
	malla.MeshId = MALLA_CONO
	malla.Scale = Vector3.new(diametro / 2, alto, diametro / 2)
	malla.Parent = p
	return p
end

-- Tejado a dos aguas. cf = centro de la parte de arriba de los muros.
-- La cumbrera va a lo largo del eje X local. ancho = medida en Z.
-- Devuelve la altura de la cumbrera.
function Construccion.tejado(padre, cf, largo, ancho, inclinacion, opciones)
	opciones = opciones or {}
	local voladizo = opciones.voladizo or 1.2
	local grosor = opciones.grosor or 0.7
	local material = opciones.material or M.Slate
	local color = opciones.color or Color3.fromRGB(80, 90, 110)
	local subida = (ancho / 2) * inclinacion -- altura de la cumbrera sobre los muros
	local angulo = math.atan(inclinacion)
	local mitad = ancho / 2 + voladizo
	local largoFaldon = mitad / math.cos(angulo)
	local cumbrera = cf * CFrame.new(0, subida, 0)

	for _, lado in { -1, 1 } do
		-- vector "arriba" del faldón (perpendicular a la pendiente)
		local normal = Vector3.new(0, math.cos(angulo), lado * math.sin(angulo))
		local bajada = Vector3.new(0, -math.sin(angulo), lado * math.cos(angulo)) -- de la cumbrera al alero
		local centroLocal = bajada * (largoFaldon / 2) + normal * (grosor / 2)
		local derecha = Vector3.new(1, 0, 0)
		local cfLocal = CFrame.fromMatrix(centroLocal, derecha, normal)
		local faldon = parte({
			Name = "Tejado",
			CFrame = cumbrera * cfLocal,
			Size = Vector3.new(largo + voladizo * 2, grosor, largoFaldon),
			Material = material,
			Color = color,
			Parent = padre,
		})
		if opciones.nieve then
			parte({
				Name = "Nieve",
				CFrame = faldon.CFrame * CFrame.new(0, grosor / 2 + 0.15, -largoFaldon * 0.08),
				Size = Vector3.new(largo + voladizo * 2 - 0.4, 0.3, largoFaldon * 0.8),
				Material = M.Snow,
				Color = Color3.fromRGB(236, 240, 246),
				CanCollide = false,
				Parent = padre,
			})
		end
	end

	-- Frontones (los triángulos de los extremos)
	local colorFronton = opciones.colorFronton or Color3.fromRGB(220, 210, 190)
	local materialFronton = opciones.materialFronton or M.Plaster
	for _, extremo in { -1, 1 } do
		for _, lado in { -1, 1 } do
			-- una cuña es un triángulo rectángulo: dos forman el frontón
			local cfCuna = cf
				* CFrame.new(extremo * (largo / 2 - 0.3), subida / 2, lado * ancho / 4)
				* CFrame.Angles(0, if lado > 0 then math.pi else 0, 0)
			parte({
				Name = "Fronton",
				CFrame = cfCuna,
				Size = Vector3.new(0.6, subida, ancho / 2),
				Material = materialFronton,
				Color = colorFronton,
				Parent = padre,
			}, "WedgePart")
		end
	end

	-- Viga de la cumbrera
	parte({
		Name = "Cumbrera",
		CFrame = cumbrera * CFrame.new(0, grosor * 0.6, 0),
		Size = Vector3.new(largo + voladizo * 2 + 0.2, 0.6, 0.6),
		Material = opciones.materialCumbrera or M.Wood,
		Color = opciones.colorCumbrera or Color3.fromRGB(60, 44, 32),
		Parent = padre,
	})
	return subida
end

-- Ventana en una pared. cf = centro de la ventana, mirando hacia fuera (-Z del cf = fuera)
function Construccion.ventana(padre, cf, ancho, alto, opciones)
	opciones = opciones or {}
	local marco = opciones.colorMarco or Color3.fromRGB(70, 50, 34)
	local luz = opciones.luz or Color3.fromRGB(255, 196, 120)
	-- Cristal con luz cálida de dentro (de noche parece que hay vida dentro)
	parte({
		Name = "Cristal",
		CFrame = cf * CFrame.new(0, 0, -0.05),
		Size = Vector3.new(ancho, alto, 0.2),
		Material = M.Neon,
		Color = luz,
		Transparency = opciones.transparencia or 0.55,
		CanCollide = false,
		CastShadow = false,
		Parent = padre,
	})
	-- Marco
	local g = 0.3
	for _, datos in {
		{ CFrame.new(0, alto / 2 + g / 2, -0.15), Vector3.new(ancho + g * 2, g, 0.35) },
		{ CFrame.new(0, -alto / 2 - g / 2, -0.25), Vector3.new(ancho + g * 2 + 0.3, g, 0.55) }, -- alféizar
		{ CFrame.new(-ancho / 2 - g / 2, 0, -0.15), Vector3.new(g, alto, 0.35) },
		{ CFrame.new(ancho / 2 + g / 2, 0, -0.15), Vector3.new(g, alto, 0.35) },
	} do
		parte({
			Name = "Marco",
			CFrame = cf * datos[1],
			Size = datos[2],
			Material = M.Wood,
			Color = marco,
			CanCollide = false,
			Parent = padre,
		})
	end
	if opciones.cruz ~= false then
		parte({
			Name = "Parteluz",
			CFrame = cf * CFrame.new(0, 0, -0.18),
			Size = Vector3.new(0.15, alto, 0.15),
			Material = M.Wood,
			Color = marco,
			CanCollide = false,
			Parent = padre,
		})
		parte({
			Name = "Parteluz",
			CFrame = cf * CFrame.new(0, 0, -0.18),
			Size = Vector3.new(ancho, 0.15, 0.15),
			Material = M.Wood,
			Color = marco,
			CanCollide = false,
			Parent = padre,
		})
	end
	if opciones.contraventanas then
		for _, lado in { -1, 1 } do
			parte({
				Name = "Contraventana",
				CFrame = cf * CFrame.new(lado * (ancho / 2 + g + ancho * 0.28), 0, -0.15),
				Size = Vector3.new(ancho * 0.5, alto + 0.2, 0.2),
				Material = M.WoodPlanks,
				Color = opciones.contraventanas,
				CanCollide = false,
				Parent = padre,
			})
		end
	end
end

-- Puerta. cf = centro de la base de la puerta en la pared, mirando hacia fuera (-Z)
function Construccion.puerta(padre, cf, ancho, alto, opciones)
	opciones = opciones or {}
	parte({
		Name = "Puerta",
		CFrame = cf * CFrame.new(0, alto / 2, -0.1),
		Size = Vector3.new(ancho, alto, 0.35),
		Material = M.WoodPlanks,
		Color = opciones.color or Color3.fromRGB(96, 64, 40),
		Parent = padre,
	})
	-- Marco de la puerta
	local marco = opciones.colorMarco or Color3.fromRGB(64, 46, 32)
	local materialMarco = opciones.materialMarco or M.Wood
	for _, datos in {
		{ CFrame.new(0, alto + 0.25, -0.2), Vector3.new(ancho + 1, 0.5, 0.5) },
		{ CFrame.new(-ancho / 2 - 0.25, alto / 2, -0.2), Vector3.new(0.5, alto, 0.5) },
		{ CFrame.new(ancho / 2 + 0.25, alto / 2, -0.2), Vector3.new(0.5, alto, 0.5) },
	} do
		parte({
			Name = "MarcoPuerta",
			CFrame = cf * datos[1],
			Size = datos[2],
			Material = materialMarco,
			Color = marco,
			Parent = padre,
		})
	end
	-- Herrajes
	for _, y in { alto * 0.25, alto * 0.75 } do
		parte({
			Name = "Herraje",
			CFrame = cf * CFrame.new(0, y, -0.3),
			Size = Vector3.new(ancho * 0.9, 0.18, 0.06),
			Material = M.Metal,
			Color = Color3.fromRGB(40, 38, 36),
			CanCollide = false,
			Parent = padre,
		})
	end
	parte({
		Name = "Pomo",
		Shape = Enum.PartType.Ball,
		CFrame = cf * CFrame.new(ancho * 0.32, alto * 0.48, -0.35),
		Size = Vector3.new(0.3, 0.3, 0.3),
		Material = M.Metal,
		Color = Color3.fromRGB(150, 120, 60),
		CanCollide = false,
		Parent = padre,
	})
end

-- Luz (sin sombras: hay muchas y así va más rápido)
function Construccion.luz(padre, color, brillo, alcance)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brillo or 1.2
	l.Range = alcance or 14
	l.Shadows = false
	l.Parent = padre
	return l
end

-- Farol sobre un poste. base = pie del poste
function Construccion.farol(padre, base, color, opciones)
	opciones = opciones or {}
	local alto = opciones.alto or 7
	local colorPoste = opciones.colorPoste or Color3.fromRGB(36, 34, 32)
	local modelo = Instance.new("Model")
	modelo.Name = "Farol"
	Construccion.columna(modelo, base, alto, 0.35, M.Metal, colorPoste, "Poste")
	parte({
		Name = "Brazo",
		CFrame = CFrame.new(base + Vector3.new(0.6, alto - 0.3, 0)),
		Size = Vector3.new(1.4, 0.2, 0.2),
		Material = M.Metal,
		Color = colorPoste,
		Parent = modelo,
	})
	local lampara = parte({
		Name = "Lampara",
		CFrame = CFrame.new(base + Vector3.new(1.2, alto - 1.1, 0)),
		Size = Vector3.new(0.8, 1.1, 0.8),
		Material = M.Neon,
		Color = color,
		Transparency = 0.15,
		CanCollide = false,
		CastShadow = false,
		Parent = modelo,
	})
	parte({
		Name = "Tapa",
		CFrame = CFrame.new(base + Vector3.new(1.2, alto - 0.45, 0)),
		Size = Vector3.new(1.1, 0.25, 1.1),
		Material = M.Metal,
		Color = colorPoste,
		CanCollide = false,
		Parent = modelo,
	})
	Construccion.luz(lampara, color, opciones.brillo or 1.3, opciones.alcance or 16)
	modelo.Parent = padre
	return modelo
end

-- Toldo de tela inclinado. cf = centro del borde pegado a la pared, mirando hacia fuera
function Construccion.toldo(padre, cf, ancho, fondo, color, rayas)
	local angulo = math.rad(22)
	local centro = cf * CFrame.new(0, -math.sin(angulo) * fondo / 2, -math.cos(angulo) * fondo / 2)
	local tela = parte({
		Name = "Toldo",
		CFrame = centro * CFrame.Angles(-angulo, 0, 0),
		Size = Vector3.new(ancho, 0.2, fondo),
		Material = M.Fabric,
		Color = color,
		CanCollide = false,
		Parent = padre,
	})
	if rayas then
		local numero = math.max(2, math.floor(ancho / 2))
		for i = 1, numero, 2 do
			parte({
				Name = "Raya",
				CFrame = tela.CFrame * CFrame.new(-ancho / 2 + (i - 0.5) * (ancho / numero), 0.12, 0),
				Size = Vector3.new(ancho / numero, 0.05, fondo),
				Material = M.Fabric,
				Color = rayas,
				CanCollide = false,
				Parent = padre,
			})
		end
	end
	return tela
end

-- Estandarte colgando de un mástil. base = pie del mástil
function Construccion.estandarte(padre, base, alto, color, detalle, mirando)
	local modelo = Instance.new("Model")
	modelo.Name = "Estandarte"
	Construccion.columna(modelo, base, alto, 0.4, M.Wood, Color3.fromRGB(60, 44, 32), "Mastil")
	local giro = CFrame.lookAt(base, base + (mirando or Vector3.new(0, 0, -1)) * Vector3.new(1, 0, 1))
	local cfTela = giro * CFrame.new(0, alto - 3.6, -0.3)
	parte({
		Name = "Travesano",
		CFrame = giro * CFrame.new(0, alto - 0.6, -0.3),
		Size = Vector3.new(3.4, 0.25, 0.25),
		Material = M.Wood,
		Color = Color3.fromRGB(60, 44, 32),
		Parent = modelo,
	})
	parte({
		Name = "Tela",
		CFrame = cfTela,
		Size = Vector3.new(3, 5.6, 0.1),
		Material = M.Fabric,
		Color = color,
		CanCollide = false,
		Parent = modelo,
	})
	parte({
		Name = "Ribete",
		CFrame = cfTela * CFrame.new(0, -2.9, 0),
		Size = Vector3.new(3, 0.4, 0.12),
		Material = M.Fabric,
		Color = detalle,
		CanCollide = false,
		Parent = modelo,
	})
	parte({
		Name = "Emblema",
		CFrame = cfTela * CFrame.new(0, 0.4, -0.06) * CFrame.Angles(0, 0, math.rad(45)),
		Size = Vector3.new(1.2, 1.2, 0.05),
		Material = M.Fabric,
		Color = detalle,
		CanCollide = false,
		Parent = modelo,
	})
	modelo.Parent = padre
	return modelo
end

-- Barril de madera
function Construccion.barril(padre, base)
	local modelo = Instance.new("Model")
	modelo.Name = "Barril"
	Construccion.columna(modelo, base, 3, 2.2, M.WoodPlanks, Construccion.variar(Color3.fromRGB(110, 76, 46), 0.05), "Duelas")
	for _, y in { 0.5, 2.5 } do
		Construccion.columna(modelo, base + Vector3.new(0, y - 0.1, 0), 0.2, 2.3, M.Metal, Color3.fromRGB(50, 48, 46), "Aro")
	end
	modelo.Parent = padre
	return modelo
end

-- Caja de madera
function Construccion.caja(padre, base, tamano)
	tamano = tamano or Construccion.n(1.8, 2.6)
	return parte({
		Name = "Caja",
		CFrame = CFrame.new(base + Vector3.new(0, tamano / 2, 0)) * CFrame.Angles(0, Construccion.n(0, 6.28), 0),
		Size = Vector3.new(tamano, tamano, tamano),
		Material = M.WoodPlanks,
		Color = Construccion.variar(Color3.fromRGB(140, 104, 66), 0.06),
		Parent = padre,
	})
end

-- Saco
function Construccion.saco(padre, base, color)
	return parte({
		Name = "Saco",
		Shape = Enum.PartType.Ball,
		CFrame = CFrame.new(base + Vector3.new(0, 0.7, 0)),
		Size = Vector3.new(1.8, 1.6, 1.8),
		Material = M.Fabric,
		Color = color or Color3.fromRGB(176, 150, 110),
		Parent = padre,
	})
end

-- Humo que sale de una chimenea (pieza invisible encima de la chimenea)
function Construccion.humo(padre, posicion, color)
	local emisor = parte({
		Name = "Humo",
		CFrame = CFrame.new(posicion),
		Size = Vector3.new(1, 1, 1),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = padre,
	})
	local humo = Instance.new("ParticleEmitter")
	humo.Texture = TEXTURA_HUMO
	humo.Rate = 2
	humo.Lifetime = NumberRange.new(5, 8)
	humo.Speed = NumberRange.new(1.5, 2.5)
	humo.SpreadAngle = Vector2.new(8, 8)
	humo.WindAffectsDrag = true
	humo.Drag = 0.4
	humo.LightInfluence = 1
	humo.Size = NumberSequence.new(1.2, 6)
	humo.Transparency = NumberSequence.new(0.7, 1)
	humo.Color = ColorSequence.new(color or Color3.fromRGB(120, 116, 112))
	humo.Parent = emisor
	return emisor
end

-- Fuego (brasero, forja, hoguera)
function Construccion.fuego(padre, posicion, tamano, color)
	local centro = parte({
		Name = "Fuego",
		CFrame = CFrame.new(posicion),
		Size = Vector3.new(1, 1, 1),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = padre,
	})
	local fuego = Instance.new("Fire")
	fuego.Size = tamano or 3
	fuego.Heat = 7
	fuego.Color = color or Color3.fromRGB(255, 140, 50)
	fuego.SecondaryColor = Color3.fromRGB(255, 70, 20)
	fuego.Parent = centro
	Construccion.luz(centro, color or Color3.fromRGB(255, 150, 70), 1.8, 18)
	return centro
end

-- Cartel de madera con texto (el nombre de la tienda). cf = centro, mirando hacia fuera
function Construccion.cartel(padre, cf, texto, opciones)
	opciones = opciones or {}
	local tabla = parte({
		Name = "Cartel",
		CFrame = cf,
		Size = Vector3.new(opciones.ancho or 6, opciones.alto or 1.6, 0.3),
		Material = opciones.material or M.WoodPlanks,
		Color = opciones.color or Color3.fromRGB(96, 66, 42),
		CanCollide = false,
		Parent = padre,
	})
	local superficie = Instance.new("SurfaceGui")
	superficie.Face = Enum.NormalId.Front
	superficie.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	superficie.PixelsPerStud = 40
	superficie.LightInfluence = 1
	superficie.MaxDistance = 120
	superficie.Parent = tabla
	local etiqueta = Instance.new("TextLabel")
	etiqueta.Size = UDim2.fromScale(1, 1)
	etiqueta.BackgroundTransparency = 1
	etiqueta.Font = Enum.Font.Garamond
	etiqueta.TextScaled = true
	etiqueta.Text = texto
	etiqueta.TextColor3 = opciones.colorTexto or Color3.fromRGB(240, 214, 150)
	etiqueta.TextStrokeTransparency = 0.6
	etiqueta.Parent = superficie
	return tabla
end

-- Suelo de plaza: disco plano. centro = centro a ras de suelo
function Construccion.disco(padre, centro, diametro, material, color, nombre)
	return parte({
		Name = nombre or "Plaza",
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(centro + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Size = Vector3.new(0.5, diametro, diametro),
		Material = material,
		Color = color,
		Parent = padre,
	})
end

return Construccion

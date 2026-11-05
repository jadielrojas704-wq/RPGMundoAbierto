-- Estética del Ki (Sin armas): luces, estelas y ondas. Solo en el CLIENTE y solo visual.
-- Ruta en Studio: ReplicatedStorage/Combate/EstiloKi
-- Lo usa StarterPlayerScripts/CombateCliente.
--
--   EstiloKi.Estela(personaje, "RightHand", 0.3)   estela de luz en una mano o pie
--   EstiloKi.Onda(personaje, "RightHand", grande)  onda de aire que sale del golpe
--   EstiloKi.Fantasma(personaje)                   imagen residual del cuerpo
--   EstiloKi.EnCombate(personaje, true/false)      manos que brillan + aura suave
--   EstiloKi.Sello(personaje, carga 0..1 / nil)    sello de luz en el suelo al cargar
--   EstiloKi.Estallido(posicion, fuerza)           sello que estalla + destello de pantalla
--
-- Paleta: azul hielo, celeste y blanco (el Ki de Sin armas).

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local EstiloKi = {}

EstiloKi.COLOR = Color3.fromRGB(120, 210, 255) -- celeste
EstiloKi.COLOR_FUERTE = Color3.fromRGB(60, 120, 255) -- azul profundo
EstiloKi.BLANCO = Color3.fromRGB(235, 250, 255)

local C = EstiloKi

-- ===== utilidades =====
local carpeta = nil
local function contenedor()
	if not carpeta or not carpeta.Parent then
		carpeta = Instance.new("Folder")
		carpeta.Name = "EfectosKi"
		carpeta.Parent = Workspace
	end
	return carpeta
end

local function pieza(propiedades)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in propiedades do
		p[k] = v
	end
	p.Parent = contenedor()
	return p
end

local function tween(objeto, tiempo, metas, estilo)
	local t = TweenService:Create(
		objeto,
		TweenInfo.new(tiempo, estilo or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		metas
	)
	t:Play()
	return t
end

local datosPorPersonaje = setmetatable({}, { __mode = "k" })
local function datos(personaje)
	local d = datosPorPersonaje[personaje]
	if not d then
		d = { estelas = {}, fines = {} }
		datosPorPersonaje[personaje] = d
	end
	return d
end

-- ===== ESTELAS (cintas de luz que siguen a la mano o al pie) =====
local function crearEstela(parte)
	local a0 = Instance.new("Attachment")
	a0.Name = "EstelaKiA"
	a0.Position = Vector3.new(0.32, 0, 0)
	a0.Parent = parte
	local a1 = Instance.new("Attachment")
	a1.Name = "EstelaKiB"
	a1.Position = Vector3.new(-0.32, 0, 0)
	a1.Parent = parte

	-- cinta exterior azul
	local estela = Instance.new("Trail")
	estela.Attachment0 = a0
	estela.Attachment1 = a1
	estela.Lifetime = 0.2
	estela.MinLength = 0.02
	estela.FaceCamera = true
	estela.LightEmission = 0.7
	estela.LightInfluence = 0
	estela.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.COLOR),
		ColorSequenceKeypoint.new(0.4, C.COLOR_FUERTE),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 60, 200)),
	})
	estela.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	estela.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.15) })
	estela.Enabled = false
	estela.Parent = parte

	-- núcleo blanco fino
	local b0 = Instance.new("Attachment")
	b0.Position = Vector3.new(0.1, 0, 0)
	b0.Parent = parte
	local b1 = Instance.new("Attachment")
	b1.Position = Vector3.new(-0.1, 0, 0)
	b1.Parent = parte
	local nucleo = estela:Clone()
	nucleo.Attachment0 = b0
	nucleo.Attachment1 = b1
	nucleo.Lifetime = 0.12
	nucleo.Color = ColorSequence.new(C.BLANCO, C.COLOR)
	nucleo.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	nucleo.Parent = parte
	return { estela, nucleo }
end

function EstiloKi.Estela(personaje, miembro, duracion)
	local parte = personaje:FindFirstChild(miembro)
	if not parte then
		return
	end
	local d = datos(personaje)
	local cintas = d.estelas[miembro]
	if not cintas or not cintas[1].Parent then
		cintas = crearEstela(parte)
		d.estelas[miembro] = cintas
	end
	for _, cinta in cintas do
		cinta.Enabled = true
	end
	local marca = os.clock() + (duracion or 0.3)
	d.fines[miembro] = marca
	task.delay(duracion or 0.3, function()
		if d.fines[miembro] == marca then
			for _, cinta in cintas do
				cinta.Enabled = false
			end
		end
	end)
end

-- ===== ONDA de aire que sale del golpe =====
function EstiloKi.Onda(personaje, miembro, grande)
	local parte = personaje:FindFirstChild(miembro)
	local raiz = personaje:FindFirstChild("HumanoidRootPart")
	if not (parte and raiz) then
		return
	end
	local frente = raiz.CFrame.LookVector
	local origen = parte.Position + frente * 0.6
	local orientado = CFrame.lookAt(origen, origen + frente)
	local escala = if grande then 2 else 1

	-- anillos que viajan hacia delante (el aire que rompe el golpe)
	for i = 1, (if grande then 3 else 2) do
		task.delay((i - 1) * 0.035, function()
			local anillo = pieza({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.06, 0.8, 0.8),
				CFrame = orientado * CFrame.Angles(0, math.pi / 2, 0),
				Color = if i == 1 then C.BLANCO else C.COLOR,
				Transparency = 0.15,
			})
			local destino = 3.2 * escala + i * 0.8
			tween(anillo, 0.22, {
				Size = Vector3.new(0.02, (2.6 + i * 0.9) * escala, (2.6 + i * 0.9) * escala),
				CFrame = (orientado + frente * destino) * CFrame.Angles(0, math.pi / 2, 0),
				Transparency = 1,
			})
			Debris:AddItem(anillo, 0.3)
		end)
	end

	-- "lanza" de aire: una raya larga y brillante en la dirección del golpe
	local largo = 5 * escala
	local lanza = pieza({
		Size = Vector3.new(0.18 * escala, 0.18 * escala, 0.5),
		CFrame = orientado * CFrame.new(0, 0, -0.25),
		Color = C.BLANCO,
		Transparency = 0.1,
	})
	tween(lanza, 0.16, {
		Size = Vector3.new(0.02, 0.02, largo),
		CFrame = orientado * CFrame.new(0, 0, -largo / 2 - 1),
		Transparency = 1,
	})
	Debris:AddItem(lanza, 0.2)

	-- polvo de luz
	local emisor = pieza({ Size = Vector3.one * 0.1, CFrame = orientado, Transparency = 1 })
	local polvo = Instance.new("ParticleEmitter")
	polvo.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	polvo.Color = ColorSequence.new(C.BLANCO, C.COLOR)
	polvo.LightEmission = 1
	polvo.Lifetime = NumberRange.new(0.2, 0.4)
	polvo.Speed = NumberRange.new(10 * escala, 22 * escala)
	polvo.SpreadAngle = Vector2.new(18, 18)
	polvo.EmissionDirection = Enum.NormalId.Front
	polvo.Size = NumberSequence.new(0.22 * escala, 0)
	polvo.Drag = 5
	polvo.Rate = 0
	polvo.Parent = emisor
	polvo:Emit(if grande then 26 else 10)
	Debris:AddItem(emisor, 0.6)
end

-- ===== FANTASMA: imagen residual de luz del cuerpo =====
local PARTES_CUERPO = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}

function EstiloKi.Fantasma(personaje)
	for _, nombre in PARTES_CUERPO do
		local parte = personaje:FindFirstChild(nombre)
		if parte and parte:IsA("BasePart") then
			local copia = pieza({
				Size = parte.Size,
				CFrame = parte.CFrame,
				Color = C.COLOR,
				Transparency = 0.45,
				Material = Enum.Material.ForceField,
			})
			if parte:IsA("MeshPart") then
				-- misma forma que la parte real
				local ok, malla = pcall(function()
					local m = parte:Clone()
					m:ClearAllChildren()
					return m
				end)
				if ok and malla then
					copia:Destroy()
					copia = malla
					copia.Anchored = true
					copia.CanCollide = false
					copia.CanQuery = false
					copia.CanTouch = false
					copia.CastShadow = false
					copia.Material = Enum.Material.ForceField
					copia.Color = C.COLOR
					copia.Transparency = 0.45
					copia.TextureID = ""
					copia.Parent = contenedor()
				end
			end
			tween(copia, 0.32, { Transparency = 1 })
			Debris:AddItem(copia, 0.36)
		end
	end
end

-- ===== EN COMBATE: manos que brillan y aura suave alrededor del cuerpo =====
local function crearBrillo(personaje)
	local d = datos(personaje)
	if d.brillo and d.brillo.raiz.Parent then
		return d.brillo
	end
	local raiz = personaje:FindFirstChild("HumanoidRootPart")
	if not raiz then
		return nil
	end
	local brillo = { raiz = raiz, luces = {}, emisores = {} }
	for _, mano in { "LeftHand", "RightHand" } do
		local parte = personaje:FindFirstChild(mano)
		if parte then
			local luz = Instance.new("PointLight")
			luz.Name = "LuzKi"
			luz.Color = C.COLOR
			luz.Range = 7
			luz.Brightness = 0
			luz.Shadows = false
			luz.Parent = parte
			table.insert(brillo.luces, luz)
			local chispas = Instance.new("ParticleEmitter")
			chispas.Name = "ChispasKi"
			chispas.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			chispas.Color = ColorSequence.new(C.BLANCO, C.COLOR)
			chispas.LightEmission = 1
			chispas.Lifetime = NumberRange.new(0.25, 0.5)
			chispas.Speed = NumberRange.new(0.5, 1.5)
			chispas.SpreadAngle = Vector2.new(180, 180)
			chispas.Acceleration = Vector3.new(0, 3, 0)
			chispas.Size = NumberSequence.new(0.18, 0)
			chispas.Rate = 0
			chispas.Parent = parte
			table.insert(brillo.emisores, chispas)
		end
	end
	-- aura: humo de luz que sube desde los pies
	local adjunto = Instance.new("Attachment")
	adjunto.Name = "AuraCombateKi"
	adjunto.Position = Vector3.new(0, -2.2, 0)
	adjunto.Parent = raiz
	local humo = Instance.new("ParticleEmitter")
	humo.Texture = "rbxasset://textures/particles/smoke_main.dds"
	humo.Color = ColorSequence.new(C.COLOR, C.COLOR_FUERTE)
	humo.LightEmission = 0.8
	humo.LightInfluence = 0
	humo.Lifetime = NumberRange.new(0.6, 1)
	humo.Speed = NumberRange.new(2, 4)
	humo.EmissionDirection = Enum.NormalId.Top
	humo.Shape = Enum.ParticleEmitterShape.Disc
	humo.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	humo.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.8) })
	humo.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.82),
		NumberSequenceKeypoint.new(1, 1),
	})
	humo.RotSpeed = NumberRange.new(-40, 40)
	humo.Rate = 0
	humo.Parent = adjunto
	table.insert(brillo.emisores, humo)
	brillo.humo = humo
	brillo.adjunto = adjunto
	d.brillo = brillo
	return brillo
end

function EstiloKi.EnCombate(personaje, encendido)
	local brillo = if encendido then crearBrillo(personaje) else datos(personaje).brillo
	if not brillo then
		return
	end
	if brillo.encendido == encendido then
		return
	end
	brillo.encendido = encendido
	for _, luz in brillo.luces do
		tween(luz, 0.35, { Brightness = if encendido then 1.6 else 0 })
	end
	for _, emisor in brillo.emisores do
		if emisor == brillo.humo then
			emisor.Rate = if encendido then 9 else 0
		else
			emisor.Rate = if encendido then 7 else 0
		end
	end
end

-- ===== SELLO DE LUZ EN EL SUELO (mientras cargas) =====
-- Diseño propio: tres aros, ocho rayos y cuatro marcas en rombo que giran y crecen con la carga.
local function suelo(posicion)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { contenedor() }
	local rayo = Workspace:Raycast(posicion + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), params)
	return if rayo then rayo.Position + Vector3.new(0, 0.08, 0) else posicion - Vector3.new(0, 3, 0)
end

-- Aro hecho con segmentos (un aro de verdad, no un disco)
local function aro(modelo, radio, segmentos, grosor, color, transparencia)
	for i = 1, segmentos do
		local angulo = (i / segmentos) * math.pi * 2
		local largo = (2 * math.pi * radio / segmentos) * 1.08
		local p = pieza({
			Size = Vector3.new(grosor, 0.05, largo),
			CFrame = CFrame.Angles(0, angulo, 0) * CFrame.new(radio, 0, 0),
			Color = color,
			Transparency = transparencia,
		})
		p.Parent = modelo
	end
end

local function crearSello()
	local modelo = Instance.new("Model")
	modelo.Name = "SelloKi"
	local centro = pieza({ Size = Vector3.new(0.2, 0.05, 0.2), CFrame = CFrame.identity, Transparency = 1 })
	centro.Parent = modelo
	modelo.PrimaryPart = centro
	aro(modelo, 5, 28, 0.16, C.COLOR, 0.25)
	aro(modelo, 4.4, 24, 0.06, C.BLANCO, 0.45)
	aro(modelo, 2, 16, 0.12, C.BLANCO, 0.2)
	-- ocho rayos entre los aros y cuatro marcas en rombo
	for i = 1, 8 do
		local angulo = i * math.pi / 4
		local rayo = pieza({
			Size = Vector3.new(0.1, 0.05, 2.2),
			CFrame = CFrame.Angles(0, angulo, 0) * CFrame.new(0, 0, -3.2),
			Color = if i % 2 == 0 then C.BLANCO else C.COLOR,
			Transparency = 0.2,
		})
		rayo.Parent = modelo
	end
	for i = 1, 4 do
		local marca = pieza({
			Size = Vector3.new(0.5, 0.05, 0.5),
			CFrame = CFrame.Angles(0, i * math.pi / 2 + math.pi / 4, 0)
				* CFrame.new(0, 0, -5.6)
				* CFrame.Angles(0, math.pi / 4, 0),
			Color = C.BLANCO,
			Transparency = 0.15,
		})
		marca.Parent = modelo
	end
	local luz = Instance.new("PointLight")
	luz.Color = C.COLOR
	luz.Range = 12
	luz.Brightness = 1
	luz.Shadows = false
	luz.Parent = centro
	modelo.Parent = contenedor()
	return { modelo = modelo, luz = luz, escala = 1 }
end

local function colocarSello(sello, centro, carga, giro)
	local escala = 0.5 + 0.65 * carga
	if math.abs(escala - sello.escala) > 0.02 then
		sello.modelo:ScaleTo(escala)
		sello.escala = escala
	end
	sello.modelo:PivotTo(CFrame.new(centro) * CFrame.Angles(0, giro, 0))
	sello.luz.Brightness = 0.6 + 2.4 * carga
end

function EstiloKi.Sello(personaje, carga)
	local d = datos(personaje)
	local raiz = personaje:FindFirstChild("HumanoidRootPart")
	if carga == nil or not raiz then
		if d.sello then
			for _, p in d.sello.modelo:GetChildren() do
				if p:IsA("BasePart") and p ~= d.sello.modelo.PrimaryPart then
					tween(p, 0.25, { Transparency = 1 })
				end
			end
			Debris:AddItem(d.sello.modelo, 0.3)
			d.sello = nil
		end
		return
	end
	local centro = suelo(raiz.Position)
	if not d.sello then
		d.sello = crearSello()
		d.giro = 0
	end
	d.giro += 0.04 + 0.1 * carga
	colocarSello(d.sello, centro, carga, d.giro)
end

-- ===== ESTALLIDO: el sello revienta + destello de pantalla =====
local correccion = nil
local resplandor = nil
local function efectosPantalla()
	if not correccion or not correccion.Parent then
		correccion = Instance.new("ColorCorrectionEffect")
		correccion.Name = "KiPantalla"
		correccion.Parent = Lighting
	end
	if not resplandor or not resplandor.Parent then
		resplandor = Instance.new("BloomEffect")
		resplandor.Name = "KiResplandor"
		resplandor.Intensity = 0
		resplandor.Size = 30
		resplandor.Threshold = 0.9
		resplandor.Parent = Lighting
	end
	return correccion, resplandor
end

function EstiloKi.Pantalla(fuerza)
	local cc, bloom = efectosPantalla()
	cc.TintColor = Color3.fromRGB(200, 230, 255):Lerp(Color3.new(1, 1, 1), 1 - fuerza)
	cc.Brightness = 0.12 * fuerza
	cc.Contrast = 0.25 * fuerza
	cc.Saturation = -0.2 * fuerza
	bloom.Intensity = 1.2 * fuerza
	tween(cc, 0.35, { TintColor = Color3.new(1, 1, 1), Brightness = 0, Contrast = 0, Saturation = 0 })
	tween(bloom, 0.4, { Intensity = 0 })
end

function EstiloKi.Estallido(posicion, fuerza)
	fuerza = fuerza or 1
	local centro = suelo(posicion)
	for i = 1, 3 do
		task.delay((i - 1) * 0.05, function()
			local anillo = pieza({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.08, 2, 2),
				CFrame = CFrame.new(centro + Vector3.new(0, 0.05 * i, 0)) * CFrame.Angles(0, 0, math.pi / 2),
				Color = if i == 2 then C.BLANCO else C.COLOR,
				Transparency = 0.1,
			})
			local radio = (10 + i * 6) * fuerza
			tween(anillo, 0.45, { Size = Vector3.new(0.02, radio, radio), Transparency = 1 })
			Debris:AddItem(anillo, 0.5)
		end)
	end
	-- columnas de luz que suben
	for i = 1, 6 do
		local angulo = i * math.pi / 3
		local base = centro + Vector3.new(math.cos(angulo), 0, math.sin(angulo)) * 3 * fuerza
		local columna =
			pieza({ Size = Vector3.new(0.3, 0.4, 0.3), CFrame = CFrame.new(base), Color = C.COLOR, Transparency = 0.2 })
		tween(columna, 0.35, {
			Size = Vector3.new(0.05, 9 * fuerza, 0.05),
			CFrame = CFrame.new(base + Vector3.new(0, 4.5 * fuerza, 0)),
			Transparency = 1,
		})
		Debris:AddItem(columna, 0.4)
	end
	EstiloKi.Pantalla(math.clamp(fuerza, 0, 1))
end

return EstiloKi

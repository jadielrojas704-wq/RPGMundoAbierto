-- Trazado de las capitales: cada una con una forma y una estructura muy distinta.
-- Ruta en Studio: ServerStorage/Herramientas/Mundo/Ciudades
-- Lo usa ServerStorage/Herramientas/Mundo/Pueblos (no se ejecuta solo).
--
--   Valdoria (Reino)  -> ciudadela de 9 lados: calle mayor, plaza del mercado, calles de
--                        los gremios, barrio noble y castillo dentro de una segunda muralla.
--   Solkhar  (Sol)    -> medina rectangular: gran avenida con canal de agua y puestos,
--                        gran bazar, manzanas apretadas y palacio en un jardín amurallado.
--   Nocthar  (Brujos) -> ciudad orgánica: una calle en espiral baja hasta la Torre del
--                        Nigromante, cementerio, empalizada torcida.
--   Kaldheim (Norte)  -> fortaleza alargada: calle principal, filas de casas largas,
--                        barrio de las forjas y el gran salón al fondo.
--
-- Coordenadas locales de cada ciudad: u = hacia la puerta (+) o hacia el fondo (-),
-- v = de lado (derecha +). Así el mismo trazado sirve mire hacia donde mire la puerta.
-- Todas tienen callejones sin salida (puntos "Callejon") para las escenas de los NPC.

local Ciudades = {}

local K -- herramientas que nos pasa Pueblos (casas, edificios, tiendas...)
local C, M, n, rng, bloque, variar

local ESTILO = {
	Reino = {
		calle = { Enum.Material.Cobblestone, Color3.fromRGB(138, 134, 126) },
		callejon = { Enum.Material.Cobblestone, Color3.fromRGB(110, 106, 100) },
		muro = { Enum.Material.Cobblestone, Color3.fromRGB(164, 158, 146) },
		alto = 15,
		anchos = { 12, 15 },
		fondos = { 10, 12 },
		separacion = { 0.3, 1.4 },
		giro = 1.5,
	},
	Sol = {
		calle = { Enum.Material.Pavement, Color3.fromRGB(206, 184, 148) },
		callejon = { Enum.Material.Sandstone, Color3.fromRGB(190, 164, 124) },
		muro = { Enum.Material.Sandstone, Color3.fromRGB(222, 194, 150) },
		alto = 13,
		anchos = { 10, 13 },
		fondos = { 10, 12 },
		separacion = { 0, 0.4 },
		giro = 0,
	},
	Brujos = {
		calle = { Enum.Material.Slate, Color3.fromRGB(78, 72, 86) },
		callejon = { Enum.Material.Slate, Color3.fromRGB(44, 40, 48) },
		muro = { Enum.Material.WoodPlanks, Color3.fromRGB(40, 32, 30) },
		alto = 12,
		anchos = { 9, 11 },
		fondos = { 9, 10 },
		separacion = { 1.2, 3.5 },
		giro = 6,
	},
	Norte = {
		calle = { Enum.Material.Cobblestone, Color3.fromRGB(120, 120, 124) },
		callejon = { Enum.Material.Slate, Color3.fromRGB(98, 98, 102) },
		muro = { Enum.Material.Slate, Color3.fromRGB(112, 112, 116) },
		alto = 13,
		anchos = { 19, 23 },
		fondos = { 11, 11.5 },
		separacion = { 5, 7 },
		giro = 0,
	},
}

local MAX_CASAS = 72 -- límite por capital (rendimiento con 20 jugadores)

-- ===================================================================
-- ===== FORMAS DE OCUPACIÓN: rectángulos girados y círculos =====
-- ===================================================================

local function rectangulo(cf, ancho, fondo)
	local r, l = cf.RightVector, cf.LookVector
	return {
		c = Vector2.new(cf.X, cf.Z),
		a = Vector2.new(r.X, r.Z).Unit,
		b = Vector2.new(l.X, l.Z).Unit,
		ha = ancho / 2,
		hb = fondo / 2,
	}
end

local function circulo(p, radio)
	return { c = Vector2.new(p.X, p.Z), r = radio }
end

local function proyeccion(o, eje)
	return o.ha * math.abs(o.a:Dot(eje)) + o.hb * math.abs(o.b:Dot(eje))
end

local function circuloRect(ci, o)
	local d = ci.c - o.c
	local x = math.clamp(d:Dot(o.a), -o.ha, o.ha)
	local z = math.clamp(d:Dot(o.b), -o.hb, o.hb)
	return (d - o.a * x - o.b * z).Magnitude < ci.r
end

local function chocan(p, q)
	if p.r and q.r then
		return (p.c - q.c).Magnitude < p.r + q.r
	elseif p.r then
		return circuloRect(p, q)
	elseif q.r then
		return circuloRect(q, p)
	end
	local d = q.c - p.c
	for _, eje in { p.a, p.b, q.a, q.b } do
		if math.abs(d:Dot(eje)) > proyeccion(p, eje) + proyeccion(q, eje) then
			return false
		end
	end
	return true
end

local function esquinas(o)
	if o.r then
		return { o.c }, o.r
	end
	local lista = {}
	for _, sa in { -1, 1 } do
		for _, sb in { -1, 1 } do
			table.insert(lista, o.c + o.a * o.ha * sa + o.b * o.hb * sb)
		end
	end
	return lista, 0
end

-- ===================================================================
-- ===== LA CIUDAD =====
-- ===================================================================

local Ciudad = {}
Ciudad.__index = Ciudad

-- datos = { modelo, sitio, pueblo, cultura, culturaId, centro (Vector3), punto (función) }
function Ciudades.Nueva(kit, datos)
	K = kit
	C = kit.C
	M = Enum.Material
	n = C.n
	rng = C.rng
	bloque = C.bloque
	variar = C.variar
	local self = setmetatable({}, Ciudad)
	for clave, valor in datos do
		self[clave] = valor
	end
	local e = datos.sitio.entrada or Vector2.new(0, 1)
	self.F = Vector3.new(e.X, 0, e.Y) -- hacia la puerta
	self.R = Vector3.new(-e.Y, 0, e.X) -- hacia la derecha
	self.estilo = ESTILO[datos.culturaId]
	self.ocupados = {}
	self.casas = {} -- puertas de las casas (ahí viven los NPC)
	self.npcs = {} -- tenderos y guardias
	self.numeroCalle = 0
	self.margen = 8 -- distancia mínima a la muralla
	return self
end

-- ===== Posiciones =====

function Ciudad:suelo(p)
	return Vector3.new(p.X, K.sueloEn(p.X, p.Z, self.centro.Y), p.Z)
end

-- Punto del suelo en coordenadas locales (u hacia la puerta, v a la derecha)
function Ciudad:P(u, v)
	return self:suelo(self.centro + self.F * u + self.R * v)
end

-- Dirección en coordenadas locales
function Ciudad:D(du, dv)
	local d = self.F * du + self.R * dv
	return if d.Magnitude > 0 then d.Unit else self.F
end

-- CFrame en el suelo mirando hacia "direccion"
local function mirando(p, direccion)
	return CFrame.lookAt(p, p + Vector3.new(direccion.X, 0, direccion.Z))
end

function Ciudad:CF(u, v, du, dv)
	return mirando(self:P(u, v), self:D(du, dv))
end

-- Distancia al borde de la ciudad (negativa dentro)
function Ciudad:borde(p)
	return K.distanciaForma(self.sitio, p.X, p.Y)
end

function Ciudad:dentro(o, margen)
	local lista, radio = esquinas(o)
	for _, p in lista do
		if self:borde(p) > -(margen + radio) then
			return false
		end
	end
	return true
end

function Ciudad:libre(o, margen, ignorar)
	if not self:dentro(o, margen or self.margen) then
		return false
	end
	for _, otro in self.ocupados do
		if not (ignorar and ignorar[otro.tipo]) and chocan(o, otro) then
			return false
		end
	end
	return true
end

function Ciudad:ocupar(o, tipo)
	o.tipo = tipo or "edificio"
	table.insert(self.ocupados, o)
	return o
end

-- Acorta el tramo (u0,v0)-(u1,v1) para que quede dentro de la muralla
function Ciudad:recortar(u0, v0, u1, v1, margen)
	margen = margen or 12
	local a = Vector2.new(u0, v0)
	local b = Vector2.new(u1, v1)
	local function local2(p)
		local w = self.centro + self.F * p.X + self.R * p.Y
		return Vector2.new(w.X, w.Z)
	end
	local largo = (b - a).Magnitude
	if largo < 1 then
		return nil
	end
	local d = (b - a) / largo
	for _ = 1, 60 do
		if self:borde(local2(b)) <= -margen then
			break
		end
		b -= d * 4
	end
	for _ = 1, 60 do
		if self:borde(local2(a)) <= -margen then
			break
		end
		a += d * 4
	end
	if (b - a):Dot(d) < 10 then
		return nil
	end
	return self:P(a.X, a.Y), self:P(b.X, b.Y)
end

-- ===== Calles =====

-- Recorre una línea de puntos: devuelve posición y dirección a una distancia "t"
local function recorrer(puntos, t)
	local acumulado = 0
	for i = 1, #puntos - 1 do
		local a, b = puntos[i], puntos[i + 1]
		local largo = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
		if t <= acumulado + largo or i == #puntos - 1 then
			local f = if largo > 0 then math.clamp((t - acumulado) / largo, 0, 1) else 0
			local direccion = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			return a:Lerp(b, f), if direccion.Magnitude > 0 then direccion.Unit else Vector3.zAxis
		end
		acumulado += largo
	end
	return puntos[1], Vector3.zAxis
end

local function largoTotal(puntos)
	local total = 0
	for i = 1, #puntos - 1 do
		local a, b = puntos[i], puntos[i + 1]
		total += (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
	end
	return total
end

local function derecha(direccion)
	return Vector3.new(-direccion.Z, 0, direccion.X)
end

-- Pavimenta una calle siguiendo una línea de puntos. Devuelve la línea.
function Ciudad:calle(puntos, ancho, opciones)
	opciones = opciones or {}
	self.numeroCalle += 1
	local subida = 0.2 + (self.numeroCalle % 10) * 0.012 -- evita parpadeos donde se cruzan calles
	local material = opciones.material or self.estilo.calle[1]
	local color = opciones.color or self.estilo.calle[2]
	local total = largoTotal(puntos)
	local trozos = math.max(1, math.ceil(total / 12))
	for k = 0, trozos - 1 do
		local t0, t1 = k / trozos * total, (k + 1) / trozos * total
		local a = recorrer(puntos, t0)
		local b = recorrer(puntos, t1)
		local medio = self:suelo((a + b) / 2)
		local direccion = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		if direccion.Magnitude > 0.1 then
			local cf = mirando(medio + Vector3.new(0, subida - 0.5, 0), direccion)
			local largo = direccion.Magnitude + 1.2
			bloque(self.modelo, cf, Vector3.new(ancho, 1, largo), material, variar(color, 0.015), "Calle")
			self:ocupar(rectangulo(cf, ancho + 1.2, largo), "calle")
		end
	end
	-- puntos de paseo a lo largo de la calle (un poco a un lado y al otro)
	if opciones.puntos ~= false then
		local lado = 1
		for t = 10, total - 6, opciones.cadaPunto or 18 do
			local p, direccion = recorrer(puntos, t)
			self.punto("Calle", p + derecha(direccion) * lado * ancho * 0.22)
			lado = -lado
		end
	end
	return puntos
end

-- Casas a un lado de una calle, con la puerta mirando a la calle.
-- lado = 1 derecha / -1 izquierda (según el sentido de la línea)
function Ciudad:fila(puntos, anchoCalle, lado, opciones)
	opciones = opciones or {}
	local e = self.estilo
	local anchos = opciones.anchos or e.anchos
	local fondos = opciones.fondos or e.fondos
	local separacion = opciones.separacion or e.separacion
	local total = largoTotal(puntos)
	local t = opciones.desde or 2
	local hasta = total - (opciones.hastaFinal or 2)
	local puestas = 0
	while t < hasta and #self.casas < MAX_CASAS do
		local ancho, fondo = n(anchos[1], anchos[2]), n(fondos[1], fondos[2])
		if t + ancho > hasta then
			break
		end
		local p, direccion = recorrer(puntos, t + ancho / 2)
		local fuera = derecha(direccion) * lado
		local centro = self:suelo(p + fuera * (anchoCalle / 2 + 1.2 + (opciones.retiro or 0) + fondo / 2))
		local cf = mirando(centro, -fuera) * CFrame.Angles(0, math.rad(n(-e.giro, e.giro)), 0)
		local extra = if self.culturaId == "Norte" then 3.5 else 0.8 -- la leña del norte va a un lado
		local forma = rectangulo(cf * CFrame.new(if self.culturaId == "Norte" then 1.6 else 0, 0, 0), ancho + extra, fondo + 0.8)
		if self:libre(forma) then
			local casa, _, _, puerta = K.Casas[self.culturaId](self.modelo, cf, {
				ancho = ancho,
				fondo = fondo,
				pisos = opciones.pisos,
			})
			casa.Name = "Casa" .. (#self.casas + 1)
			self:ocupar(forma)
			table.insert(self.casas, puerta.Position)
			self.punto("Puerta", puerta.Position)
			if anchoCalle >= 8 and rng:NextNumber() < 0.35 then
				local junto = (cf * CFrame.new((if rng:NextNumber() < 0.5 then -1 else 1) * (ancho / 2 - 1.2), 0, -fondo / 2 - 1.2)).Position
				if rng:NextNumber() < 0.5 then
					C.barril(self.modelo, self:suelo(junto))
				else
					C.caja(self.modelo, self:suelo(junto))
				end
			end
			puestas += 1
			t += ancho + n(separacion[1], separacion[2])
		else
			t += 2.5
		end
	end
	return puestas
end

-- Tienda con la fachada mirando a "direccion" (hacia la plaza o la calle)
function Ciudad:tienda(cf, tipo)
	local anchoTienda = if self.culturaId == "Norte" then 19 else 15
	self:ocupar(rectangulo(cf * CFrame.new(0, 0, -3.7), anchoTienda, 19))
	local tendero = K.tienda(self.modelo, cf, tipo, self.culturaId, self.cultura)
	table.insert(self.npcs, { oficio = tipo, cf = tendero, tienda = tipo, rol = "Tendero", clase = "Plebeyo" })
	self.punto("Tienda", (tendero * CFrame.new(0, 0, -6.5)).Position)
end

-- Tiendas en fila a un lado de una calle (el mostrador da a la calle)
function Ciudad:filaTiendas(puntos, anchoCalle, lado, tipos, desde, paso)
	for i, tipo in tipos do
		local p, direccion = recorrer(puntos, desde + (i - 1) * paso)
		local fuera = derecha(direccion) * lado
		local cf = mirando(self:suelo(p + fuera * (anchoCalle / 2 + 13.4)), -fuera)
		self:tienda(cf, tipo)
	end
end

-- Plaza redonda con el monumento de la cultura en el centro
function Ciudad:plaza(centro, radio, opciones)
	opciones = opciones or {}
	local suelo = K.SUELO_PLAZA[self.culturaId]
	C.disco(self.modelo, centro, radio * 2, suelo[1], suelo[2])
	if opciones.monumento ~= false then
		K.Centros[self.culturaId](self.modelo, centro, opciones.grande ~= false, self.cultura)
	end
	self:ocupar(circulo(centro, radio), "plaza")
	for _, anillo in { 0.5, 0.82 } do
		local r = radio * anillo
		if r > 7 then
			local cuantos = math.max(4, math.floor(2 * math.pi * r / 11))
			local giro = rng:NextNumber() * math.pi
			for k = 1, cuantos do
				local angulo = k / cuantos * math.pi * 2 + giro
				self.punto("Plaza", centro + Vector3.new(math.cos(angulo), 0, math.sin(angulo)) * r)
			end
		end
	end
end

-- Plaza rectangular (mercados). cf = centro mirando hacia la puerta de la ciudad
function Ciudad:plazaRect(cf, largo, ancho, opciones)
	opciones = opciones or {}
	local suelo = K.SUELO_PLAZA[self.culturaId]
	local losa = bloque(self.modelo, cf * CFrame.new(0, -0.1, 0), Vector3.new(ancho, 1, largo), opciones.material or suelo[1], opciones.color or suelo[2], "Plaza")
	losa.Name = "Plaza"
	if opciones.monumento ~= false then
		K.Centros[self.culturaId](self.modelo, cf.Position, opciones.grande ~= false, self.cultura)
	end
	self:ocupar(rectangulo(cf, ancho, largo), "plaza")
	for x = -ancho / 2 + 8, ancho / 2 - 8, 11 do
		for z = -largo / 2 + 7, largo / 2 - 7, 11 do
			if math.abs(x) + math.abs(z) > 13 then
				self.punto("Plaza", (cf * CFrame.new(x + n(-2, 2), 0, z + n(-2, 2))).Position)
			end
		end
	end
end

-- ===== Callejones sin salida =====
-- boca = punto del borde de la calle; direccion = hacia dentro del callejón
function Ciudad:callejon(boca, direccion, largo, ancho)
	ancho = ancho or 6
	direccion = Vector3.new(direccion.X, 0, direccion.Z).Unit
	local centro = self:suelo(boca + direccion * largo / 2)
	local cf = mirando(centro, direccion)
	-- la forma empieza un poco dentro (el borde de la calle ya está ocupado por la propia calle)
	local forma = rectangulo(mirando(self:suelo(boca + direccion * (largo / 2 + 0.6)), direccion), ancho + 3.4, largo - 1.2)
	if not self:libre(forma, 3) then
		return false
	end
	self:ocupar(forma, "callejon")
	local modelo = Instance.new("Model")
	modelo.Name = "Callejon"
	local e = self.estilo
	local alto = if self.culturaId == "Brujos" then 12 else 10
	-- suelo más oscuro y gastado
	bloque(modelo, cf * CFrame.new(0, 0.15 - 0.5, 0), Vector3.new(ancho, 1, largo), e.callejon[1], e.callejon[2], "SueloCallejon")
	-- paredes a los lados y al fondo (sin salida)
	local materialMuro = if self.culturaId == "Brujos" then M.Basalt else e.muro[1]
	local colorMuro = if self.culturaId == "Brujos" then Color3.fromRGB(56, 50, 56) else variar(e.muro[2], 0.04)
	for _, s in { -1, 1 } do
		bloque(modelo, cf * CFrame.new(s * (ancho / 2 + 0.6), alto / 2 - 2, 0), Vector3.new(1.2, alto + 4, largo), materialMuro, colorMuro, "ParedCallejon")
	end
	-- (ojo: en un CFrame, -Z es "hacia delante": el fondo está en -Z)
	local fondo = cf * CFrame.new(0, alto / 2 - 2, -(largo / 2 + 0.6))
	bloque(modelo, fondo, Vector3.new(ancho + 2.4, alto + 4, 1.2), materialMuro, colorMuro, "FondoCallejon")
	-- trastos contra las paredes (dejan libre el centro para caminar)
	for k, z in { -(largo / 2 - 2), -(largo / 2 - 5.5), largo / 2 - 5 } do
		local s = if k % 2 == 0 then 1 else -1
		local p = self:suelo((cf * CFrame.new(s * (ancho / 2 - 1.1), 0, z)).Position)
		local tirada = rng:NextNumber()
		if tirada < 0.4 then
			C.barril(modelo, p)
		elseif tirada < 0.75 then
			C.caja(modelo, p, n(1.6, 2.1))
			if rng:NextNumber() < 0.5 then
				C.caja(modelo, p + Vector3.new(0, 1.9, 0), 1.3)
			end
		else
			C.saco(modelo, p)
		end
	end
	-- farolillo tenue en el fondo
	local farol = C.parte({
		Name = "FarolCallejon",
		CFrame = fondo * CFrame.new(0, alto / 2 - 4.5, 0.9),
		Size = Vector3.new(0.7, 1, 0.7),
		Material = M.Neon,
		Color = if self.culturaId == "Brujos" then Color3.fromRGB(150, 90, 230) else Color3.fromRGB(255, 170, 90),
		CanCollide = false,
		CastShadow = false,
		Parent = modelo,
	})
	C.luz(farol, farol.Color, 0.7, 14)
	-- ropa tendida de pared a pared (o cadenas, en la ciudad de los brujos)
	local cuerda = cf * CFrame.new(0, alto - 3, n(-largo / 4, largo / 4))
	bloque(modelo, cuerda, Vector3.new(ancho + 1, 0.08, 0.08), M.Fabric, Color3.fromRGB(90, 80, 70), "Cuerda").CanCollide = false
	for x = -ancho / 2 + 1, ancho / 2 - 1, 1.6 do
		local tela = bloque(modelo, cuerda * CFrame.new(x, -0.7, 0), Vector3.new(1.1, 1.3, 0.05), M.Fabric,
			if self.culturaId == "Brujos" then Color3.fromRGB(40, 34, 40) else variar(K.elegir({ Color3.fromRGB(220, 214, 200), Color3.fromRGB(150, 60, 50), Color3.fromRGB(70, 100, 140) }), 0.05), "Ropa")
		tela.CanCollide = false
	end
	-- charco
	if self.culturaId ~= "Sol" then
		local charco = bloque(modelo, cf * CFrame.new(n(-1, 1), 0.17, n(-largo / 4, 0)), Vector3.new(n(2, 3), 0.05, n(2.5, 4)), M.Glass, Color3.fromRGB(60, 70, 80), "Charco")
		charco.Transparency = 0.35
		charco.CanCollide = false
	end
	modelo.Parent = self.modelo
	-- punto de la escena: el fondo del callejón (y dónde está su boca)
	local valor = self.punto("Callejon", (cf * CFrame.new(0, 0, -(largo / 2 - 4.5))).Position)
	valor:SetAttribute("Boca", self:suelo(boca + direccion * 1.5))
	return true
end

-- ===== Faroles =====
function Ciudad:faroles(puntos, anchoCalle, cada)
	local total = largoTotal(puntos)
	local lado = 1
	local color = K.COLOR_FAROL[self.culturaId]
	for t = 6, total - 4, cada do
		local p, direccion = recorrer(puntos, t)
		local sitio = p + derecha(direccion) * lado * math.max(anchoCalle / 2 - 0.6, 1.8)
		local forma = circulo(sitio, 0.4)
		if self:libre(forma, 3, { calle = true, plaza = true }) then
			C.farol(self.modelo, self:suelo(sitio), color)
			self:ocupar(forma, "farol")
		end
		lado = -lado
	end
end

-- ===== Relleno: huertos, palmerales, tumbas, leñeras... en los huecos que quedan =====
local lapidaSuelta, arbolSuelto -- se definen más abajo (ciudad de los brujos)
local RELLENOS = {}

function RELLENOS.Reino(self, cf)
	if rng:NextNumber() < 0.65 then
		-- huerto con surcos verdes
		bloque(self.modelo, cf * CFrame.new(0, -0.15, 0), Vector3.new(12, 0.8, 9), M.Ground, Color3.fromRGB(92, 70, 48), "Huerto")
		for x = -4.5, 4.5, 2.25 do
			bloque(self.modelo, cf * CFrame.new(x, 0.45, 0), Vector3.new(0.9, 0.6, 8), M.LeafyGrass, variar(Color3.fromRGB(96, 140, 60), 0.06), "Surco").CanCollide = false
		end
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				C.columna(self.modelo, (cf * CFrame.new(sx * 6.2, 0, sz * 4.7)).Position, 2.4, 0.35, M.Wood, Color3.fromRGB(100, 72, 46), "PosteValla")
			end
		end
	else
		-- almiar de heno y carreta
		C.cono(self.modelo, (cf * CFrame.new(-2.5, 0, 0)).Position, 5, 5, M.Grass, Color3.fromRGB(204, 178, 96), "Heno")
		bloque(self.modelo, cf * CFrame.new(3, 1.6, 0), Vector3.new(3.4, 1, 5), M.WoodPlanks, Color3.fromRGB(116, 82, 52), "Carreta")
		for _, sz in { -1, 1 } do
			C.parte({ Name = "Rueda", Shape = Enum.PartType.Cylinder, CFrame = cf * CFrame.new(3, 1.3, sz * 1.6), Size = Vector3.new(0.4, 2.6, 2.6), Material = M.Wood, Color = Color3.fromRGB(80, 56, 36), Parent = self.modelo })
		end
	end
end

function RELLENOS.Sol(self, cf)
	if rng:NextNumber() < 0.5 then
		for _, x in { -3, 3 } do
			K.Vegetacion.Palmera((cf * CFrame.new(x, -0.5, n(-2, 2))).Position, self.modelo)
		end
	else
		-- tienda de lona de los mercaderes
		bloque(self.modelo, cf * CFrame.new(0, 0.08, 0), Vector3.new(8, 0.1, 6), M.Fabric, K.elegir({ Color3.fromRGB(150, 40, 40), Color3.fromRGB(40, 90, 150) }), "Alfombra").CanCollide = false
		C.cono(self.modelo, (cf * CFrame.new(0, 0, 0)).Position, 7, 6, M.Fabric, Color3.fromRGB(226, 210, 176), "Lona")
		for k = -1, 1 do
			C.columna(self.modelo, (cf * CFrame.new(k * 1.6, 0, 3.6)).Position, 1.4, 1, M.Slate, Color3.fromRGB(176, 96, 60), "Tinaja")
		end
	end
end

function RELLENOS.Brujos(self, cf)
	if rng:NextNumber() < 0.6 then
		for _ = 1, 4 do
			lapidaSuelta(self, cf * CFrame.new(n(-4, 4), 0, n(-3, 3)) * CFrame.Angles(0, n(-0.3, 0.3), 0))
		end
	else
		arbolSuelto(self, cf.Position)
	end
end

function RELLENOS.Norte(self, cf)
	-- leñera con tejadillo nevado
	for _, sx in { -1, 1 } do
		C.columna(self.modelo, (cf * CFrame.new(sx * 3.6, 0, 1.6)).Position, 4.4, 0.5, M.Wood, Color3.fromRGB(90, 66, 44), "Poste")
	end
	bloque(self.modelo, cf * CFrame.new(0, 4.6, 0.8) * CFrame.Angles(math.rad(-14), 0, 0), Vector3.new(8.4, 0.4, 4), M.WoodPlanks, Color3.fromRGB(66, 50, 38), "Tejadillo")
	bloque(self.modelo, cf * CFrame.new(0, 4.95, 0.8) * CFrame.Angles(math.rad(-14), 0, 0), Vector3.new(8.4, 0.3, 4), M.Snow, Color3.fromRGB(236, 240, 246), "Nieve")
	for i = 0, 11 do
		C.parte({
			Name = "Lena",
			Shape = Enum.PartType.Cylinder,
			CFrame = cf * CFrame.new(-3 + (i % 6) * 1.2, 0.5 + math.floor(i / 6) * 0.9, 1.6),
			Size = Vector3.new(2.6, 0.9, 0.9),
			Material = M.Wood,
			Color = variar(Color3.fromRGB(130, 96, 62), 0.05),
			Parent = self.modelo,
		}).CFrame *= CFrame.Angles(0, math.pi / 2, 0)
	end
end

function Ciudad:rellenar(maximo)
	local r = self.sitio.radio
	local puestos = 0
	for u = -r, r, 17 do
		for v = -r, r, 17 do
			if puestos >= maximo then
				return
			end
			local cf = self:CF(u + n(-3, 3), v + n(-3, 3), n(-1, 1), n(-1, 1))
			local forma = rectangulo(cf, 14, 11)
			if self:libre(forma, 9) then
				self:ocupar(forma, "relleno")
				RELLENOS[self.culturaId](self, cf)
				puestos += 1
			end
		end
	end
end

-- ===== Plantas sueltas =====
function Ciudad:plantas(cuantas, plantar)
	local puestas, intentos = 0, 0
	local r = self.sitio.radio
	while puestas < cuantas and intentos < cuantas * 30 do
		intentos += 1
		local p = self.centro + self.F * n(-r, r) + self.R * n(-r, r)
		local forma = circulo(p, 3)
		if self:libre(forma, 10) then
			plantar(self:suelo(p))
			self:ocupar(forma, "planta")
			puestas += 1
		end
	end
end

-- ===== Murallas siguiendo el contorno =====

local function torre(self, base, alto, ancho)
	local material, color = self.estilo.muro[1], self.estilo.muro[2]
	local id = self.culturaId
	if id == "Sol" then
		-- torre cuadrada con cúpula
		bloque(self.modelo, CFrame.new(base + Vector3.new(0, (alto + 3) / 2, 0)), Vector3.new(ancho, alto + 3, ancho), material, variar(color, 0.03), "Torre")
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				bloque(self.modelo, CFrame.new(base + Vector3.new(sx * (ancho / 2 - 0.7), alto + 3.9, sz * (ancho / 2 - 0.7))), Vector3.new(1.4, 1.8, 1.4), material, color, "Almena")
			end
		end
		C.bola(self.modelo, base + Vector3.new(0, alto + 3, 0), ancho * 0.62, M.Foil, self.cultura.detalle, "Cupulita")
	elseif id == "Brujos" then
		-- atalaya torcida de troncos negros con tejado puntiagudo
		local giro = CFrame.Angles(math.rad(n(-4, 4)), 0, math.rad(n(-4, 4)))
		local cf = CFrame.new(base) * giro
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				C.liston(self.modelo, (cf * CFrame.new(sx * ancho * 0.42, 0, sz * ancho * 0.42)).Position, (cf * CFrame.new(sx * ancho * 0.34, alto + 4, sz * ancho * 0.34)).Position, 0.9, M.Wood, Color3.fromRGB(34, 28, 26), "Poste")
			end
		end
		bloque(self.modelo, cf * CFrame.new(0, alto + 4, 0), Vector3.new(ancho * 0.9, 0.8, ancho * 0.9), M.WoodPlanks, Color3.fromRGB(44, 36, 34), "Plataforma")
		bloque(self.modelo, cf * CFrame.new(0, alto + 5.4, 0), Vector3.new(ancho * 0.9, 2, ancho * 0.9), M.WoodPlanks, Color3.fromRGB(38, 30, 28), "Baranda")
		C.cono(self.modelo, (cf * CFrame.new(0, alto + 6.4, 0)).Position, ancho * 1.05, 8, M.Slate, Color3.fromRGB(38, 32, 46), "TejadoTorre")
		local brasa = C.parte({ Name = "LuzTorre", CFrame = cf * CFrame.new(0, alto + 5.4, 0), Size = Vector3.new(0.8, 0.8, 0.8), Material = M.Neon, Color = self.cultura.detalle, CanCollide = false, CastShadow = false, Parent = self.modelo })
		C.luz(brasa, self.cultura.detalle, 1.2, 20)
	elseif id == "Norte" then
		-- base de piedra y torreón de madera con nieve
		C.columna(self.modelo, base, alto + 4, ancho, material, variar(color, 0.03), "Torre")
		bloque(self.modelo, CFrame.new(base + Vector3.new(0, alto + 6, 0)), Vector3.new(ancho + 1, 4, ancho + 1), M.WoodPlanks, Color3.fromRGB(92, 66, 44), "Torreon")
		C.cono(self.modelo, base + Vector3.new(0, alto + 8, 0), ancho + 3, 6, M.WoodPlanks, Color3.fromRGB(70, 52, 38), "TejadoTorre")
		C.cono(self.modelo, base + Vector3.new(0, alto + 9.5, 0), ancho + 0.5, 4.4, M.Snow, Color3.fromRGB(236, 240, 246), "Nieve")
	else
		-- Reino: torre redonda de piedra con tejado cónico azul
		C.columna(self.modelo, base, alto + 8, ancho, material, variar(color, 0.03), "Torre")
		for k = 1, 8 do
			local angulo = k / 8 * math.pi * 2
			bloque(self.modelo, CFrame.new(base + Vector3.new(math.cos(angulo) * (ancho / 2 - 0.5), alto + 8.8, math.sin(angulo) * (ancho / 2 - 0.5))), Vector3.new(1.3, 1.6, 1.3), material, color, "Almena")
		end
		C.cono(self.modelo, base + Vector3.new(0, alto + 9, 0), ancho + 1.4, 9, M.Slate, Color3.fromRGB(70, 86, 116), "TejadoTorre")
	end
end

-- Muro de "a" a "b" (Vector3 del suelo). fuera = vector hacia fuera de la ciudad
local function muroTramo(self, a, b, alto, fuera, grosor)
	local material, color = self.estilo.muro[1], self.estilo.muro[2]
	local direccion = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local largo = direccion.Magnitude
	if largo < 0.5 then
		return
	end
	local medio = self:suelo((a + b) / 2)
	local cf = mirando(medio + Vector3.new(0, alto / 2 - 3, 0), direccion)
	bloque(self.modelo, cf, Vector3.new(grosor, alto + 6, largo + 0.8), material, variar(color, 0.02), "Muro")
	local haciaFuera = if cf.RightVector:Dot(fuera) > 0 then 1 else -1
	if self.culturaId == "Brujos" then
		for t = -largo / 2 + 0.8, largo / 2 - 0.8, 2.2 do
			local p = (cf * CFrame.new(0, alto / 2 + 3, t)).Position
			C.cono(self.modelo, p, 1.4, n(2, 3.2), M.Wood, Color3.fromRGB(34, 28, 26), "Punta")
		end
	else
		for t = -largo / 2 + 1, largo / 2 - 1, 2.6 do
			bloque(self.modelo, cf * CFrame.new(haciaFuera * (grosor / 2 - 0.6), alto / 2 + 3.9, t), Vector3.new(1.2, 1.8, 1.3), material, color, "Almena")
		end
		-- adarve por dentro
		bloque(self.modelo, cf * CFrame.new(-haciaFuera * (grosor / 2 + 0.9), alto / 2 + 2.4, 0), Vector3.new(1.8, 0.6, largo + 0.8), M.WoodPlanks, Color3.fromRGB(90, 66, 44), "Adarve")
	end
end

-- Murallas exteriores siguiendo el polígono, con torres y la puerta principal
function Ciudad:muralla()
	local poligono = self.sitio.poligono
	local puerta2 = self.sitio.puerta
	local alto = self.estilo.alto
	local grosor = if self.culturaId == "Brujos" then 2 else 3.2
	local anchoTorre = if self.culturaId == "Sol" then 10 elseif self.culturaId == "Brujos" then 7 else 9
	local hueco = 12
	local modeloMuralla = Instance.new("Model")
	modeloMuralla.Name = "Muralla"
	local modeloOriginal = self.modelo
	self.modelo = modeloMuralla
	local puerta = Vector3.new(puerta2.X, 0, puerta2.Y)
	local function alSuelo(v)
		return self:suelo(Vector3.new(v.X, 0, v.Y))
	end
	local cada = if self.culturaId == "Brujos" then 3 else 1 -- torres en cada esquina (o cada 3 en la empalizada)
	for i = 1, #poligono do
		local a = alSuelo(poligono[i])
		local b = alSuelo(poligono[i % #poligono + 1])
		local plano = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local largo = plano.Magnitude
		local direccion = plano.Unit
		local normal = derecha(direccion)
		local medio2 = Vector2.new((a.X + b.X) / 2, (a.Z + b.Z) / 2)
		local fuera = if self:borde(medio2 + Vector2.new(normal.X, normal.Z) * 4) > self:borde(medio2) then normal else -normal
		local trozos = math.max(1, math.ceil(largo / 7))
		for k = 0, trozos - 1 do
			local p0 = a + plano * (k / trozos)
			local p1 = a + plano * ((k + 1) / trozos)
			local medio = (p0 + p1) / 2
			if (Vector3.new(medio.X, 0, medio.Z) - puerta).Magnitude > hueco then
				muroTramo(self, p0, p1, alto, fuera, grosor)
			end
		end
		if (i - 1) % cada == 0 then
			torre(self, a - Vector3.new(0, 3, 0), alto, anchoTorre)
		end
		-- torres intermedias en los lados largos
		local intermedias = math.floor(largo / 64)
		for k = 1, intermedias do
			local p = a + plano * (k / (intermedias + 1))
			if (Vector3.new(p.X, 0, p.Z) - puerta).Magnitude > hueco + 10 then
				torre(self, self:suelo(p) - Vector3.new(0, 3, 0), alto, anchoTorre)
			end
		end
	end

	-- Puerta principal: dos torres, arco y estandartes
	local p = self:suelo(puerta)
	local F, R = self.F, self.R
	local material, color = self.estilo.muro[1], self.estilo.muro[2]
	local altoPuerta = alto + (if self.culturaId == "Sol" then 10 else 5)
	for _, s in { -1, 1 } do
		local base = p + R * s * (hueco - 1) - Vector3.new(0, 3, 0)
		if self.culturaId == "Sol" then
			torre(self, base, altoPuerta, 13)
		else
			torre(self, base, altoPuerta, anchoTorre + 2)
		end
		C.estandarte(self.modelo, p + R * s * 7 + F * 3, 11, self.cultura.bandera, self.cultura.detalle, F)
	end
	local arco = CFrame.lookAt(p + Vector3.new(0, alto + 1, 0), p + Vector3.new(0, alto + 1, 0) + R)
	bloque(self.modelo, arco, Vector3.new(grosor + 1, 6, hueco * 2 - 2), material, color, "Arco")
	if self.culturaId == "Sol" then
		-- puerta monumental: arco de herradura con franja dorada y gran estandarte
		bloque(self.modelo, arco * CFrame.new(0, 4, 0), Vector3.new(grosor + 1.4, 3, hueco * 2 + 4), material, variar(color, 0.03), "Coronacion")
		bloque(self.modelo, arco * CFrame.new(0, 2.2, 0), Vector3.new(grosor + 1.6, 0.6, hueco * 2 + 4.2), M.Foil, self.cultura.detalle, "Franja")
		C.parte({
			Name = "ArcoHerradura",
			Shape = Enum.PartType.Cylinder,
			CFrame = CFrame.lookAt(p + Vector3.new(0, alto - 2, 0), p + Vector3.new(0, alto - 2, 0) + F) * CFrame.Angles(0, math.pi / 2, 0),
			Size = Vector3.new(grosor + 1.2, 14, 14),
			Material = material,
			Color = variar(color, 0.05),
			CanCollide = false,
			Parent = self.modelo,
		})
	elseif self.culturaId == "Norte" then
		-- cráneos de bestia y cuernos sobre la puerta
		for _, s in { -1, 1 } do
			C.liston(self.modelo, p + Vector3.new(0, alto + 4, 0) + R * s * 1.2, p + Vector3.new(0, alto + 8, 0) + R * s * 4, 0.6, M.Marble, Color3.fromRGB(230, 224, 206), "Cuerno")
		end
	end
	modeloMuralla.Parent = modeloOriginal
	self.modelo = modeloOriginal

	-- guardias fuera de la puerta, mirando al camino
	for _, s in { -1, 1 } do
		local g = self:suelo(p + R * s * 4.5 + F * 3)
		table.insert(self.npcs, { oficio = "Guardia", cf = mirando(g, F), rol = "Guardia", clase = "Plebeyo" })
	end
	return p
end

-- Murete interior (ciudadelas y jardines). esquinasLocales = {{u,v}...}; hueco = {u, v, ancho}
function Ciudad:murete(esquinasLocales, hueco, alto, opciones)
	opciones = opciones or {}
	local material = opciones.material or self.estilo.muro[1]
	local color = opciones.color or self.estilo.muro[2]
	local puntosMuro = {}
	for _, e in esquinasLocales do
		table.insert(puntosMuro, self:P(e[1], e[2]))
	end
	local centroHueco = self:P(hueco[1], hueco[2])
	for i = 1, #puntosMuro do
		local a, b = puntosMuro[i], puntosMuro[i % #puntosMuro + 1]
		local plano = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local trozos = math.max(1, math.ceil(plano.Magnitude / 12))
		for k = 0, trozos - 1 do
			local p0 = a + plano * (k / trozos)
			local p1 = a + plano * ((k + 1) / trozos)
			local medio = (p0 + p1) / 2
			if (Vector3.new(medio.X - centroHueco.X, 0, medio.Z - centroHueco.Z)).Magnitude > hueco[3] / 2 + 3 then
				local cf = mirando(self:suelo(medio) + Vector3.new(0, alto / 2 - 2, 0), plano)
				bloque(self.modelo, cf, Vector3.new(2.4, alto + 4, (p1 - p0).Magnitude + 0.6), material, variar(color, 0.02), "Murete")
				if opciones.remate then
					bloque(self.modelo, cf * CFrame.new(0, alto / 2 + 2.2, 0), Vector3.new(2.8, 0.5, (p1 - p0).Magnitude + 0.8), opciones.remate[1], opciones.remate[2], "Remate")
				end
			end
		end
		if opciones.torres then
			opciones.torres(a)
		end
	end
	-- pilares de la entrada
	for _, s in { -1, 1 } do
		local base = centroHueco + self.R * s * (hueco[3] / 2 + 1.5)
		bloque(self.modelo, CFrame.new(base + Vector3.new(0, alto / 2 + 0.5, 0)), Vector3.new(3.2, alto + 5, 3.2), material, color, "Pilar")
		if opciones.pilar then
			opciones.pilar(base + Vector3.new(0, alto + 3, 0))
		end
	end
end

-- ===================================================================
-- ===== VALDORIA: ciudadela del Reino =====
-- ===================================================================

local Trazados = {}

function Trazados.Reino(c, pueblo)
	local G = (Vector3.new(c.sitio.puerta.X, 0, c.sitio.puerta.Y) - Vector3.new(c.centro.X, 0, c.centro.Z)):Dot(c.F)
	local cultura = c.cultura

	-- 1) La ciudadela del fondo: segunda muralla y castillo
	local frente, fondoC, mitad = -60, -122, 38
	c:ocupar(rectangulo(c:CF((frente + fondoC) / 2, 0, 1, 0), mitad * 2 + 3, frente - fondoC + 3), "ciudadela")
	c:murete({ { frente, -mitad }, { frente, mitad }, { fondoC, mitad }, { fondoC, -mitad } }, { frente, 0, 12 }, 10, {
		torres = function(base)
			C.columna(c.modelo, base - Vector3.new(0, 3, 0), 19, 6, M.Cobblestone, Color3.fromRGB(170, 164, 152), "TorreCiudadela")
			C.cono(c.modelo, base + Vector3.new(0, 16, 0), 7.4, 7, M.Slate, Color3.fromRGB(70, 86, 116), "TejadoTorre")
		end,
		pilar = function(cima)
			C.fuego(c.modelo, cima + Vector3.new(0, 0.8, 0), 2.2)
		end,
	})
	K.Principales.Reino(c.modelo, c:CF(-98, 0, 1, 0), cultura)
	-- patio de armas delante del castillo
	bloque(c.modelo, c:CF(-69, 0, 1, 0) * CFrame.new(0, -0.15, 0), Vector3.new(mitad * 2 - 4, 1, 16), M.Cobblestone, Color3.fromRGB(150, 146, 138), "PatioArmas")
	for _, v in { -24, -12, 12, 24 } do
		c.punto("Plaza", c:P(-68, v))
	end
	for _, s in { -1, 1 } do
		table.insert(c.npcs, { oficio = "Guardia", cf = c:CF(frente - 3, s * 8, 1, 0), rol = "Guardia", clase = "Plebeyo" })
		C.estandarte(c.modelo, c:P(-76, s * 18), 12, cultura.bandera, cultura.detalle, c.F)
	end

	-- 2) Calles: la calle mayor (puerta -> ciudadela) y las calles que la cruzan
	local mayor = c:calle({ c:P(G - 2, 0), c:P(frente + 1, 0) }, 10)
	local cruces = {}
	for _, u in { 112, 80, -20 } do
		local _, b = c:recortar(u, 0, u, -200)
		local _, b2 = c:recortar(u, 0, u, 200)
		if b and b2 then
			table.insert(cruces, { u = u, izquierda = c:calle({ c:P(u, -6), b }, 9), derecha = c:calle({ c:P(u, 6), b2 }, 9) })
		end
	end
	-- calles de los gremios (paralelas a la mayor)
	local gremios = {}
	for _, s in { -1, 1 } do
		table.insert(gremios, c:calle({ c:P(-20, s * 70), c:P(80, s * 70) }, 7))
		-- pozo en los cruces de los gremios
		local pozo = c:P(80, s * 70)
		C.columna(c.modelo, pozo, 2.6, 5, M.Cobblestone, Color3.fromRGB(150, 146, 138), "Pozo")
		C.disco(c.modelo, pozo + Vector3.new(0, 2.2, 0), 3.8, M.Glass, Color3.fromRGB(40, 60, 70), "AguaPozo").CanCollide = false
		for _, k in { -1, 1 } do
			C.columna(c.modelo, pozo + c.R * k * 2.2, 5.6, 0.4, M.Wood, Color3.fromRGB(80, 56, 36), "PostePozo")
		end
		bloque(c.modelo, CFrame.new(pozo + Vector3.new(0, 5.8, 0)) * CFrame.lookAt(Vector3.zero, c.R), Vector3.new(3.6, 1.6, 5.6), M.WoodPlanks, Color3.fromRGB(74, 88, 116), "TejadoPozo")
		c:ocupar(circulo(pozo, 4), "plaza")
		c.punto("Plaza", pozo + c.F * 6)
		c.punto("Plaza", pozo - c.F * 6)
	end

	-- 3) Plaza del mercado con la fuente y las tiendas alrededor
	local cfMercado = c:CF(38, 0, 1, 0)
	c:plazaRect(cfMercado, 46, 54)
	local tiendas = pueblo.tiendas
	local izquierda = math.ceil(#tiendas / 2)
	for i, tipo in tiendas do
		if i <= izquierda then
			local u = 38 + ((i - 1) / math.max(izquierda - 1, 1) - 0.5) * 36
			c:tienda(c:CF(u, -36, 0, 1), tipo)
		else
			local k = i - izquierda
			local total = #tiendas - izquierda
			local u = 38 + (if total == 1 then 0 else ((k - 1) / (total - 1) - 0.5) * 26)
			c:tienda(c:CF(u, 36, 0, -1), tipo)
		end
	end

	-- 4) Callejones sin salida (antes que las casas, para que las casas los rodeen)
	c:callejon(c:P(80 + 4.5, -42), c.F, 18)
	c:callejon(c:P(-20 - 4.5, 52), -c.F, 15)
	c:callejon(c:P(-20 - 4.5, -54), -c.F, 15)
	c:callejon(c:P(30, -70 - 3.5), -c.R, 16)
	c:callejon(c:P(112 - 4.5, 34), -c.F, 14)

	-- 5) Casas: barrio noble primero (más grandes), luego calle mayor, cruces y gremios
	for _, cruce in cruces do
		local noble = cruce.u == -20
		local opciones = if noble then { anchos = { 15, 18 }, fondos = { 12, 13 }, pisos = 2, separacion = { 2, 4 } } else nil
		for _, linea in { cruce.izquierda, cruce.derecha } do
			c:fila(linea, 9, 1, opciones)
			c:fila(linea, 9, -1, opciones)
		end
	end
	for _, tramo in { { G - 12, 117 }, { 107, 85 }, { 12, -15 }, { -26, frente + 2 } } do
		local linea = { c:P(tramo[1], 0), c:P(tramo[2], 0) }
		c:fila(linea, 10, 1)
		c:fila(linea, 10, -1)
	end
	for _, linea in gremios do
		c:fila(linea, 7, 1)
		c:fila(linea, 7, -1)
	end

	-- 6) Faroles, árboles del barrio noble y murallas
	c:faroles(mayor, 10, 16)
	for _, cruce in cruces do
		c:faroles(cruce.izquierda, 9, 20)
		c:faroles(cruce.derecha, 9, 20)
	end
	c:plantas(10, function(p)
		K.Vegetacion.Plantar("HayaJoven", p, c.modelo)
	end)
	c:rellenar(26)
	c:muralla()
end

-- ===================================================================
-- ===== SOLKHAR: medina del Imperio del sol =====
-- ===================================================================

-- Puesto de mercado con toldo de colores (cf mira hacia los clientes)
local function puesto(c, cf)
	local colores = { Color3.fromRGB(36, 120, 132), Color3.fromRGB(190, 64, 46), Color3.fromRGB(226, 160, 50), Color3.fromRGB(110, 40, 90), Color3.fromRGB(40, 90, 150) }
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			C.columna(c.modelo, (cf * CFrame.new(sx * 2.3, 0, sz * 1.7)).Position, 5.6, 0.3, M.Wood, Color3.fromRGB(110, 76, 46), "Poste")
		end
	end
	C.bloque(c.modelo, cf * CFrame.new(0, 5.7, 0) * CFrame.Angles(math.rad(-8), 0, 0), Vector3.new(5.4, 0.15, 4.2), M.Fabric, K.elegir(colores), "Tela").CanCollide = false
	C.bloque(c.modelo, cf * CFrame.new(0, 1.3, -1.2), Vector3.new(4.4, 2.6, 1.1), M.WoodPlanks, Color3.fromRGB(150, 110, 70), "Mostrador")
	C.bloque(c.modelo, cf * CFrame.new(0, 0.08, -3.4), Vector3.new(3.8, 0.1, 2.4), M.Fabric, K.elegir(colores), "Alfombra").CanCollide = false
	for s = -1, 1 do
		local tirada = rng:NextNumber()
		local p = (cf * CFrame.new(s * 1.3, 2.6, -1.2)).Position
		if tirada < 0.5 then
			C.saco(c.modelo, p - Vector3.new(0, 0.7, 0), K.elegir({ Color3.fromRGB(200, 120, 40), Color3.fromRGB(170, 40, 30), Color3.fromRGB(220, 190, 70) }))
		else
			C.columna(c.modelo, p, 1.2, 0.9, M.Slate, Color3.fromRGB(176, 96, 60), "Vasija")
		end
	end
end

function Trazados.Sol(c, pueblo)
	local forma = pueblo.forma
	local hu, hv = forma.largo / 2, forma.ancho / 2 -- 125, 100
	local cultura = c.cultura

	-- 1) Recinto del palacio: jardín amurallado al fondo
	local frente, fondoP, mitad = -40, -hu + 9, 56
	c:ocupar(rectangulo(c:CF((frente + fondoP) / 2, 0, 1, 0), mitad * 2 + 3, frente - fondoP + 3), "palacio")
	local cfJardin = c:CF((frente + fondoP) / 2, 0, 1, 0)
	local cesped = bloque(c.modelo, cfJardin * CFrame.new(0, -0.32, 0), Vector3.new(mitad * 2 - 2, 1, frente - fondoP - 2), M.Grass, Color3.fromRGB(96, 142, 70), "Jardin")
	cesped.Name = "Jardin"
	c:murete({ { frente, -mitad }, { frente, mitad }, { fondoP, mitad }, { fondoP, -mitad } }, { frente, 0, 14 }, 7, {
		remate = { M.Foil, cultura.detalle },
		torres = function(base)
			bloque(c.modelo, CFrame.new(base + Vector3.new(0, 6, 0)), Vector3.new(5, 12, 5), M.Sandstone, Color3.fromRGB(226, 198, 154), "Torrecilla")
			C.bola(c.modelo, base + Vector3.new(0, 12, 0), 4.4, M.Foil, cultura.detalle, "Cupulita")
		end,
		pilar = function(cima)
			C.bola(c.modelo, cima + Vector3.new(0, 1, 0), 3, M.Foil, cultura.detalle, "Remate")
		end,
	})
	K.Principales.Sol(c.modelo, c:CF(-92, 0, 1, 0), cultura)
	-- paseo de mármol del jardín, estanque y palmeras en fila
	bloque(c.modelo, c:CF(-56, 0, 1, 0) * CFrame.new(0, -0.1, 0), Vector3.new(8, 1, 34), M.Marble, Color3.fromRGB(240, 234, 222), "Paseo")
	K.Centros.Sol(c.modelo, c:P(-58, 0), true, cultura)
	for u = fondoP + 8, frente - 8, 13 do
		for _, s in { -1, 1 } do
			K.Vegetacion.Palmera(c:P(u, s * (mitad - 8)) - Vector3.new(0, 0.5, 0), c.modelo)
		end
	end
	for _, v in { -36, -22, 22, 36 } do
		c.punto("Plaza", c:P(-52, v))
		-- parterres de flores
		local cf = c:CF(-70, v, 1, 0)
		bloque(c.modelo, cf * CFrame.new(0, 0.3, 0), Vector3.new(6, 0.6, 10), M.Grass, Color3.fromRGB(70, 120, 60), "Parterre")
		for _ = 1, 6 do
			C.bola(c.modelo, (cf * CFrame.new(n(-2.4, 2.4), 0.8, n(-4.4, 4.4))).Position, 0.9, M.Grass, K.elegir({ Color3.fromRGB(220, 60, 90), Color3.fromRGB(240, 200, 70), Color3.fromRGB(240, 240, 230) }), "Flor")
		end
	end
	for _, s in { -1, 1 } do
		table.insert(c.npcs, { oficio = "Guardia", cf = c:CF(frente + 3, s * 9.5, 1, 0), rol = "Guardia", clase = "Plebeyo" })
	end

	-- 2) La gran avenida con su canal de agua
	local avenida = c:calle({ c:P(hu - 2, 0), c:P(frente + 1, 0) }, 20, { cadaPunto = 14 })
	for _, tramo in { { hu - 14, 68 }, { 12, frente + 10 } } do
		local canal = c:CF((tramo[1] + tramo[2]) / 2, 0, 1, 0)
		local largoCanal = tramo[1] - tramo[2]
		bloque(c.modelo, canal * CFrame.new(0, 0.35, 0), Vector3.new(3.4, 0.35, largoCanal), M.Marble, Color3.fromRGB(240, 234, 222), "BordeCanal")
		local aguaCanal = bloque(c.modelo, canal * CFrame.new(0, 0.55, 0), Vector3.new(2.2, 0.1, largoCanal), M.Glass, Color3.fromRGB(60, 140, 160), "Canal")
		aguaCanal.Transparency = 0.25
		aguaCanal.CanCollide = false
	end
	-- puestos del zoco a los dos lados de la avenida (entre la puerta y el bazar)
	for u = 74, hu - 16, 9.5 do
		for _, s in { -1, 1 } do
			puesto(c, c:CF(u, s * 6.6, 0, -s))
		end
	end

	-- 3) Gran bazar: plaza con las tiendas a los lados
	c:plazaRect(c:CF(40, 0, 1, 0), 50, 56, { grande = false })
	local tiendas = pueblo.tiendas
	local izquierda = math.ceil(#tiendas / 2)
	for i, tipo in tiendas do
		if i <= izquierda then
			local u = 40 + ((i - 1) / math.max(izquierda - 1, 1) - 0.5) * 36
			c:tienda(c:CF(u, -37, 0, 1), tipo)
		else
			local k = i - izquierda
			local total = #tiendas - izquierda
			local u = 40 + (if total == 1 then 0 else ((k - 1) / (total - 1) - 0.5) * 24)
			c:tienda(c:CF(u, 37, 0, -1), tipo)
		end
	end
	for _, s in { -1, 1 } do
		for _, k in { -1, 1 } do
			K.Vegetacion.Palmera(c:P(40 + k * 21, s * 22) - Vector3.new(0, 0.5, 0), c.modelo)
		end
	end

	-- 4) Calles de la medina: dos paralelas a la avenida y dos que la cruzan
	local calles = {}
	for _, s in { -1, 1 } do
		table.insert(calles, c:calle({ c:P(hu - 8, s * 70), c:P(-hu + 8, s * 70) }, 8))
	end
	for _, u in { 92, -6 } do
		for _, s in { -1, 1 } do
			table.insert(calles, c:calle({ c:P(u, s * 11), c:P(u, s * (hv - 8)) }, 8))
		end
	end

	-- 5) Callejones estrechos dentro de las manzanas
	c:callejon(c:P(40, -70 + 4), c.R, 20, 5)
	c:callejon(c:P(60, 70 - 4), -c.R, 20, 5)
	c:callejon(c:P(-80, -70 - 4), -c.R, 18, 5)
	c:callejon(c:P(-60, 70 + 4), c.R, 18, 5)
	c:callejon(c:P(92 - 4, 40), -c.F, 18, 5)
	c:callejon(c:P(-6 + 4, -40), c.F, 12, 5)

	-- 6) Casas apretadas: la avenida, las calles y los cruces
	for _, tramo in { { hu - 10, 98 }, { 86, 68 }, { 12, 0 }, { -12, frente + 2 } } do
		local linea = { c:P(tramo[1], 0), c:P(tramo[2], 0) }
		c:fila(linea, 20, 1)
		c:fila(linea, 20, -1)
	end
	for _, linea in calles do
		c:fila(linea, 8, 1)
		c:fila(linea, 8, -1)
	end

	c:faroles(avenida, 2, 18) -- a los lados del canal
	c:rellenar(16)
	c:muralla()
end

-- ===================================================================
-- ===== NOCTHAR: la espiral de los brujos =====
-- ===================================================================

local function lapida(c, cf)
	local tipo = rng:NextNumber()
	if tipo < 0.55 then
		bloque(c.modelo, cf * CFrame.new(0, 1.3, 0) * CFrame.Angles(math.rad(n(-8, 8)), 0, math.rad(n(-8, 8))), Vector3.new(2, 2.8, 0.5), M.Slate, variar(Color3.fromRGB(96, 94, 100), 0.05), "Lapida")
	elseif tipo < 0.85 then
		-- cruz torcida
		local base = cf * CFrame.Angles(0, 0, math.rad(n(-10, 10)))
		bloque(c.modelo, base * CFrame.new(0, 1.8, 0), Vector3.new(0.5, 3.6, 0.5), M.Slate, Color3.fromRGB(80, 78, 84), "Cruz")
		bloque(c.modelo, base * CFrame.new(0, 2.6, 0), Vector3.new(2, 0.5, 0.5), M.Slate, Color3.fromRGB(80, 78, 84), "Cruz")
	else
		-- tumba con losa y vela
		bloque(c.modelo, cf * CFrame.new(0, 0.4, 1.6), Vector3.new(2.4, 0.8, 4.2), M.Slate, Color3.fromRGB(70, 68, 74), "Losa")
		local vela = C.parte({ Name = "Vela", CFrame = cf * CFrame.new(0.6, 1.2, 0.2), Size = Vector3.new(0.3, 0.8, 0.3), Material = M.Neon, Color = Color3.fromRGB(255, 220, 150), CanCollide = false, CastShadow = false, Parent = c.modelo })
		C.luz(vela, Color3.fromRGB(255, 190, 120), 0.6, 8)
	end
end

local function arbolMuerto(c, base)
	local alto = n(9, 14)
	local inclinado = CFrame.new(base) * CFrame.Angles(math.rad(n(-8, 8)), n(0, 6), math.rad(n(-8, 8)))
	local cima = (inclinado * CFrame.new(0, alto, 0)).Position
	C.liston(c.modelo, base - Vector3.new(0, 1, 0), cima, 1.2, M.Wood, Color3.fromRGB(46, 40, 38), "Tronco")
	for _ = 1, 5 do
		local desde = base:Lerp(cima, n(0.45, 0.95))
		local hasta = desde + Vector3.new(n(-4, 4), n(1, 3.5), n(-4, 4))
		C.liston(c.modelo, desde, hasta, 0.45, M.Wood, Color3.fromRGB(46, 40, 38), "Rama")
	end
end

lapidaSuelta, arbolSuelto = lapida, arbolMuerto

function Trazados.Brujos(c, pueblo)
	local G = (Vector3.new(c.sitio.puerta.X, 0, c.sitio.puerta.Y) - Vector3.new(c.centro.X, 0, c.centro.Z)):Dot(c.F)
	local cultura = c.cultura
	local function polar(angulo, r)
		return c:P(math.cos(angulo) * r, math.sin(angulo) * r)
	end

	-- 1) El centro: plaza oscura con la torre sobre un pedestal escalonado
	local radioPlaza = 48
	c:plaza(c.centro, radioPlaza, { monumento = false })
	local basalto = Color3.fromRGB(50, 46, 54)
	C.columna(c.modelo, c.centro - Vector3.new(0, 1, 0), 2.6, 40, M.Basalt, basalto, "Pedestal")
	C.columna(c.modelo, c.centro - Vector3.new(0, 1, 0), 4.2, 32, M.Basalt, variar(basalto, 0.03), "Pedestal")
	for k = 0, 2 do
		-- escalones hacia la puerta de la ciudad
		bloque(c.modelo, c:CF(16 + 4 - k * 1.4, 0, 1, 0) * CFrame.new(0, 0.2 + k * 1.05, 0), Vector3.new(10, 1.1, 1.6), M.Basalt, basalto, "Escalon")
	end
	K.Principales.Brujos(c.modelo, c:CF(0, 0, 1, 0) * CFrame.new(0, 3.2, 0), cultura)
	c:ocupar(circulo(c.centro, 22), "torre")
	-- el círculo ritual, a un lado de la torre
	K.Centros.Brujos(c.modelo, c:P(-33, 0), true, cultura)
	for _, s in { -1, 1 } do
		table.insert(c.npcs, { oficio = "Guardia", cf = c:CF(24, s * 6, 1, 0), rol = "Guardia", clase = "Plebeyo" })
	end

	-- 2) La espiral: baja desde la entrada rodeando la torre hasta la plaza
	local inicio = math.min(97, G - 22)
	local final = radioPlaza + 10
	local vueltas = math.pi * 1.62
	local espiral = {}
	for angulo = 0, vueltas, 0.09 do
		table.insert(espiral, polar(angulo, inicio - (inicio - final) * angulo / vueltas))
	end
	local function radioEn(angulo)
		return inicio - (inicio - final) * angulo / vueltas
	end
	c:calle({ c:P(G - 2, 0), c:P(inicio, 0) }, 9)
	c:calle(espiral, 8, { cadaPunto = 16 })
	c:calle({ espiral[#espiral], polar(vueltas, radioPlaza - 2) }, 8, { puntos = false })

	-- 3) Las tiendas: la "calle de los mercaderes", al principio de la espiral (lado de dentro)
	c:filaTiendas(espiral, 8, 1, pueblo.tiendas, 18, 19)

	-- 4) El cementerio, detrás de la torre (lado de fuera de la espiral)
	local desdeA, hastaA = math.pi * 0.85, math.pi * 1.28
	local medio = (desdeA + hastaA) / 2
	local cripta = polar(medio, radioEn(medio) + 18)
	local cfCripta = mirando(cripta, c.centro - cripta)
	c:ocupar(circulo(cripta, 8), "cementerio")
	bloque(c.modelo, cfCripta * CFrame.new(0, 4, 0), Vector3.new(9, 8, 9), M.Basalt, basalto, "Cripta")
	C.cono(c.modelo, (cfCripta * CFrame.new(0, 8, 0)).Position, 11, 7, M.Slate, Color3.fromRGB(38, 32, 46), "TejadoCripta")
	C.puerta(c.modelo, cfCripta * CFrame.new(0, 0, -4.55), 3, 5.6, { color = Color3.fromRGB(30, 24, 28), colorMarco = Color3.fromRGB(30, 26, 32) })
	local ojo = C.parte({ Name = "LuzCripta", CFrame = cfCripta * CFrame.new(0, 6.8, -4.7), Size = Vector3.new(1, 1, 0.2), Material = M.Neon, Color = cultura.detalle, CanCollide = false, Parent = c.modelo })
	C.luz(ojo, cultura.detalle, 1.6, 18)
	for angulo = desdeA, hastaA, 0.07 do
		local r0 = radioEn(angulo) + 4 + 3
		for r = r0, r0 + 24, 4 do
			local p = polar(angulo, r)
			local forma = circulo(p, 2.2)
			if c:libre(forma, 7) then
				c:ocupar(forma, "cementerio")
				if rng:NextNumber() < 0.55 then
					lapida(c, mirando(p, c.centro - p))
				end
			end
		end
	end
	for k = 1, 4 do
		local angulo = desdeA + (hastaA - desdeA) * (k - 0.5) / 4
		arbolMuerto(c, polar(angulo, radioEn(angulo) + n(12, 30)))
	end
	for _, f in { 0.25, 0.75 } do
		c.punto("Rasgo", polar(desdeA + (hastaA - desdeA) * f, radioEn(desdeA) + 9))
	end

	-- 5) Callejones: ramales sin salida que salen de la espiral
	for _, datos in { { 2.2, 1, 14 }, { 4.6, -1, 16 }, { 3.9, 1, 12 }, { 1.2, -1, 12 } } do
		local angulo, sentido, largo = datos[1], datos[2], datos[3]
		local r = radioEn(angulo)
		local haciaFuera = (polar(angulo, r + 1) - polar(angulo, r))
		haciaFuera = Vector3.new(haciaFuera.X, 0, haciaFuera.Z).Unit
		local direccion = haciaFuera * -sentido -- sentido 1 = hacia dentro
		c:callejon(polar(angulo, r) + direccion * 4, direccion, largo, 5.5)
	end

	-- 6) Ronda de la empalizada: una calle circular por dentro de la muralla
	local ronda = {}
	for angulo = 0.32, math.pi * 2 - 0.32, 0.08 do
		local p = polar(angulo, 113)
		if c:borde(Vector2.new(p.X, p.Z)) <= -7 then
			table.insert(ronda, p)
		elseif #ronda > 0 then
			break
		end
	end
	if #ronda > 3 then
		c:calle(ronda, 7, { cadaPunto = 22 })
	end

	-- 7) Casas torcidas a los dos lados de la espiral, de la entrada y de la ronda
	-- (retiro: en las curvas las casas se apartan un poco más para no pisar la calle)
	local puestas = c:fila(espiral, 8, -1, { desde = 6, retiro = 0.6 })
	puestas += c:fila(espiral, 8, 1, { desde = 18 + 19 * #pueblo.tiendas, retiro = 1.2 })
	local entrada = { c:P(G - 10, 0), c:P(inicio + 6, 0) }
	puestas += c:fila(entrada, 9, 1)
	puestas += c:fila(entrada, 9, -1)
	if #ronda > 3 then
		puestas += c:fila(ronda, 7, 1, { retiro = 1 })
	end
	local _ = puestas

	c:faroles(espiral, 8, 15)
	c:plantas(8, function(p)
		K.Vegetacion.Plantar("Helecho", p, c.modelo)
	end)
	c:rellenar(22)
	c:muralla()
end

-- ===================================================================
-- ===== KALDHEIM: la fortaleza alargada del norte =====
-- ===================================================================

local function fragua(c, cf)
	bloque(c.modelo, cf * CFrame.new(0, 1.5, 0), Vector3.new(5, 3, 4), M.Slate, Color3.fromRGB(86, 84, 86), "Fragua")
	bloque(c.modelo, cf * CFrame.new(0, 3.05, 0), Vector3.new(3.6, 0.2, 2.6), M.Neon, Color3.fromRGB(255, 110, 30), "Brasas").CanCollide = false
	C.fuego(c.modelo, (cf * CFrame.new(0, 3.6, 0)).Position, 2.6)
	bloque(c.modelo, cf * CFrame.new(0, 7, 1.4), Vector3.new(2, 8, 1.6), M.Slate, Color3.fromRGB(80, 80, 84), "Chimenea")
	C.humo(c.modelo, (cf * CFrame.new(0, 11.4, 1.4)).Position, Color3.fromRGB(80, 78, 76))
	local yunque = cf * CFrame.new(3.6, 0, -2)
	bloque(c.modelo, yunque * CFrame.new(0, 0.9, 0), Vector3.new(1.4, 1.8, 1.4), M.Wood, Color3.fromRGB(90, 64, 40), "Tocon")
	bloque(c.modelo, yunque * CFrame.new(0, 2.15, 0), Vector3.new(2.4, 0.8, 1), M.Metal, Color3.fromRGB(46, 46, 50), "Yunque")
	C.columna(c.modelo, (cf * CFrame.new(-3.6, 0, -1.6)).Position, 2, 2.2, M.WoodPlanks, Color3.fromRGB(100, 70, 44), "Tina")
end

function Trazados.Norte(c, pueblo)
	local forma = pueblo.forma
	local hu, hv = forma.largo / 2, forma.ancho / 2 -- 145, 62
	local cultura = c.cultura
	c.margen = 5

	-- 1) El gran salón al fondo y la plaza del juramento delante
	local cfSalon = c:CF(-hu + 23, 0, 1, 0)
	K.Principales.Norte(c.modelo, cfSalon, cultura)
	c:ocupar(rectangulo(cfSalon * CFrame.new(10, 0, -2), 72, 32), "salon")
	c:plaza(c:P(-88, 0), 18)
	for _, s in { -1, 1 } do
		table.insert(c.npcs, { oficio = "Guardia", cf = c:CF(-hu + 23 + 16, s * 8, 1, 0), rol = "Guardia", clase = "Plebeyo" })
	end

	-- 2) Calle principal y dos calles traseras, unidas por callejas
	local principal = c:calle({ c:P(hu - 2, 0), c:P(-hu + 42, 0) }, 11)
	local traseras = {}
	for _, s in { -1, 1 } do
		table.insert(traseras, c:calle({ c:P(hu - 12, s * 40), c:P(-hu + 48, s * 40) }, 7))
	end
	for _, u in { 104, 18, -58 } do
		for _, s in { -1, 1 } do
			c:calle({ c:P(u, s * 6), c:P(u, s * 37) }, 6, { puntos = false })
		end
	end

	-- 3) Barrio de las forjas: tiendas a los dos lados de la calle principal
	local tiendas = pueblo.tiendas
	local izquierda = math.ceil(#tiendas / 2)
	for i, tipo in tiendas do
		if i <= izquierda then
			c:tienda(c:CF(32 + (i - 1) * 24, -(5.5 + 13.4), 0, 1), tipo)
		else
			c:tienda(c:CF(44 + (i - izquierda - 1) * 24, 5.5 + 13.4, 0, -1), tipo)
		end
	end
	for _, datos in { { 46, -1 }, { 70, 1 }, { 30, 1 } } do
		local cf = c:CF(datos[1], datos[2] * 31, 0, -datos[2])
		local f = rectangulo(cf, 10, 8)
		if c:libre(f) then
			c:ocupar(f)
			fragua(c, cf)
			c.punto("Rasgo", (cf * CFrame.new(0, 0, -5)).Position)
		end
	end

	-- 4) Callejones que mueren contra la muralla
	for _, datos in { { -40, -1 }, { 60, 1 }, { 122, -1 }, { 0, 1 }, { 84, -1 } } do
		local u, s = datos[1], datos[2]
		c:callejon(c:P(u, s * 43.5), c.R * s, hv - 43.5 - 3.5, 6)
	end

	-- 5) Casas largas en filas: a los lados de la principal y de las traseras
	local tramos = { { hu - 10, 110 }, { 98, 24 }, { 12, -52 }, { -64, -76 } }
	for _, tramo in tramos do
		local linea = { c:P(tramo[1], 0), c:P(tramo[2], 0) }
		c:fila(linea, 11, 1)
		c:fila(linea, 11, -1)
	end
	for _, linea in traseras do
		c:fila(linea, 7, 1)
		c:fila(linea, 7, -1)
	end

	-- 6) Braseros por la calle principal y murallas
	c:faroles(principal, 11, 20)
	c:rellenar(12)
	c:muralla()
end

-- Construye la capital entera. Devuelve la ciudad (con sus npcs, casas y puntos).
function Ciudades.Construir(kit, datos)
	local c = Ciudades.Nueva(kit, datos)
	local trazado = Trazados[datos.culturaId]
	trazado(c, datos.pueblo)
	return c
end

-- Para las aldeas: añade un callejón sin salida en algún hueco libre.
-- ocupados = { {posicion, radio} } (lo que ya hay construido en la aldea)
function Ciudades.CallejonAldea(kit, datos, ocupados, plaza, radio)
	local c = Ciudades.Nueva(kit, datos)
	for _, o in ocupados do
		c:ocupar(circulo(o[1], o[2]))
	end
	c.margen = 4
	local e = datos.sitio.entrada or Vector2.new(0, 1)
	local haciaPuerta = Vector3.new(e.X, 0, e.Y)
	for _ = 1, 80 do
		local angulo = n(0, math.pi * 2)
		local fuera = Vector3.new(math.cos(angulo), 0, math.sin(angulo))
		if fuera:Dot(haciaPuerta) > 0.75 then
			continue -- no tapar la calle que va a la entrada
		end
		local boca = plaza + fuera * n(radio * 0.35, radio * 0.6)
		if c:callejon(c:suelo(boca), fuera, 14, 5.5) then
			return true
		end
	end
	return false
end

return Ciudades

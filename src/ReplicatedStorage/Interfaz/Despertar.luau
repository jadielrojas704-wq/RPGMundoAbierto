-- Cinemática del DESPERTAR (solo CLIENTE): el jugador despierta en la cabaña de Eldren.
-- Ruta en Studio: ReplicatedStorage/Interfaz/Despertar
--
-- Sale después del prólogo, la primera vez que se juega (misión 1 de la historia).
-- El jugador abre los ojos tumbado en la cama de la cabaña de Eldren
-- (ServerScriptService/Historia/CabanaServicio). Eldren le habla junto al fuego, por la
-- ventana se ve el Eclipse, el jugador se levanta, recibe el amuleto y sale a entrenar.
-- Lo que se dice está en ReplicatedStorage/Config/HistoriaConfig.DESPERTAR.
-- Al terminar avisa al servidor ("Desperto") y la misión 1 se completa.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local HistoriaConfig = require(ReplicatedStorage.Config.HistoriaConfig)
local SonidosConfig = require(ReplicatedStorage.Config.SonidosConfig)
local Cinematica = require(script.Parent.Cinematica)
local Voz = require(script.Parent.Voz)

local Despertar = {}

local ANIM = {
	Respirar = "rbxassetid://507766388", -- reposo de Roblox (R15)
	Senalar = "rbxassetid://507770453", -- señalar (R15)
	Saludar = "rbxassetid://507770239", -- saludar con la mano (R15)
}

local function tween(objeto, tiempo, metas, estilo, direccion)
	local t = TweenService:Create(
		objeto,
		TweenInfo.new(tiempo, estilo or Enum.EasingStyle.Sine, direccion or Enum.EasingDirection.InOut),
		metas
	)
	t:Play()
	return t
end

local function mirar(desde, hacia)
	return CFrame.lookAt(desde, hacia)
end

-- Pantalla negra mientras se prepara la escena (sin cartel: el jugador simplemente abre los ojos)
local function cartel(jugador)
	local gui = Instance.new("ScreenGui")
	gui.Name = "NegroDespertar"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 70
	gui.ResetOnSpawn = false
	gui.Parent = jugador:WaitForChild("PlayerGui")
	local negro = Instance.new("Frame")
	negro.Size = UDim2.fromScale(1, 1)
	negro.BackgroundColor3 = Color3.new(0, 0, 0)
	negro.BorderSizePixel = 0
	negro.Parent = gui
	local inicio = os.clock()
	-- un silencio breve en negro (como cuando uno despierta) y se aclara
	return gui, function()
		local falta = 1.5 - (os.clock() - inicio)
		if falta > 0 then
			task.wait(falta)
		end
		task.spawn(function()
			tween(negro, 1.6, { BackgroundTransparency = 1 }).Completed:Wait()
			gui:Destroy()
		end)
	end
end

-- Párpados: dos franjas negras que se abren, se cierran (parpadeo) y se abren del todo
local function parpados(jugador, duracion)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Parpados"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 65
	gui.ResetOnSpawn = false
	gui.Parent = jugador:WaitForChild("PlayerGui")
	local function parpado(arriba)
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0, if arriba then 0 else 1)
		f.Position = UDim2.fromScale(0, if arriba then 0 else 1)
		f.Size = UDim2.fromScale(1, 0.5)
		f.Parent = gui
		local borde = Instance.new("UIGradient")
		borde.Rotation = if arriba then 90 else -90
		borde.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.82, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		borde.Parent = f
		return f
	end
	local arriba, abajo = parpado(true), parpado(false)
	local borroso = Instance.new("BlurEffect")
	borroso.Name = "DespertarBorroso"
	borroso.Size = 28
	borroso.Parent = Lighting
	task.spawn(function()
		local function abrir(cuanto, tiempo)
			local alto = (1 - cuanto) * 0.5 + 0.06
			tween(arriba, tiempo, { Size = UDim2.fromScale(1, alto) })
			tween(abajo, tiempo, { Size = UDim2.fromScale(1, alto) }).Completed:Wait()
		end
		task.wait(0.4)
		abrir(0.35, 1.1) -- se entreabren
		tween(borroso, duracion, { Size = 0 })
		task.wait(0.3)
		abrir(0, 0.35) -- se cierran otra vez (le pesan los párpados)
		task.wait(0.35)
		abrir(0.7, 0.9)
		task.wait(0.25)
		abrir(0.55, 0.2) -- parpadeo
		abrir(1.25, 1.1) -- ojos abiertos
		gui:Destroy()
	end)
	task.delay(duracion + 0.5, function()
		borroso:Destroy()
	end)
end

-- Copia de Eldren solo para esta escena (el de verdad espera en el porche)
local function actorEldren(cabana)
	local historia = Workspace:FindFirstChild("Historia")
	local original = historia and historia:FindFirstChild("Custodio Eldren")
	if not original then
		return nil
	end
	local actor = original:Clone()
	for _, cosa in actor:GetDescendants() do
		if cosa:IsA("ProximityPrompt") or cosa:IsA("BillboardGui") or cosa:IsA("ParticleEmitter") or cosa:IsA("BaseScript") then
			cosa:Destroy()
		end
	end
	local humanoide = actor:FindFirstChildOfClass("Humanoid")
	local raiz = actor:FindFirstChild("HumanoidRootPart")
	if not humanoide or not raiz then
		actor:Destroy()
		return nil
	end
	raiz.Anchored = true
	local hogar = cabana:GetAttribute("Hogar")
	actor:PivotTo(hogar * CFrame.new(0, humanoide.HipHeight + raiz.Size.Y / 2, 0))
	actor.Name = "EldrenEscena"
	actor.Parent = Workspace.CurrentCamera
	-- el de verdad se esconde mientras dura la escena
	local escondidas = {}
	for _, p in original:GetDescendants() do
		if p:IsA("BasePart") or p:IsA("Decal") then
			table.insert(escondidas, p)
			p.LocalTransparencyModifier = 1
		end
	end
	local animador = humanoide:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animador.Parent = humanoide
	local pistas = {}
	local function cargar(nombre)
		if pistas[nombre] == nil then
			local anim = Instance.new("Animation")
			anim.AnimationId = ANIM[nombre]
			local ok, pista = pcall(function()
				return animador:LoadAnimation(anim)
			end)
			pistas[nombre] = if ok then pista else false
		end
		return pistas[nombre]
	end
	local respirar = cargar("Respirar")
	if respirar then
		respirar.Looped = true
		respirar:Play(0.4)
	end
	return {
		modelo = actor,
		cabeza = function()
			local h = actor:FindFirstChild("Head")
			return if h then h.Position else raiz.Position + Vector3.new(0, 1.6, 0)
		end,
		mano = function()
			local m = actor:FindFirstChild("RightHand")
			return m
		end,
		gesto = function(nombre, velocidad)
			local pista = cargar(nombre)
			if pista then
				pista:Play(0.3, 1, velocidad or 1)
			end
		end,
		girarHacia = function(punto)
			local p = raiz.Position
			tween(raiz, 0.8, { CFrame = CFrame.lookAt(p, Vector3.new(punto.X, p.Y, punto.Z)) })
		end,
		quitar = function()
			for _, p in escondidas do
				if p.Parent then
					p.LocalTransparencyModifier = 0
				end
			end
			actor:Destroy()
		end,
	}
end

-- El amuleto: una piedra morada que brilla, en la mano de Eldren
local function amuleto(mano)
	local piedra = Instance.new("Part")
	piedra.Name = "Amuleto"
	piedra.Shape = Enum.PartType.Ball
	piedra.Size = Vector3.new(0.55, 0.55, 0.55)
	piedra.Material = Enum.Material.Neon
	piedra.Color = HistoriaConfig.COLOR_ECLIPSE
	piedra.CanCollide = false
	piedra.Anchored = true
	piedra.CFrame = mano.CFrame * CFrame.new(0, -0.6, -0.3)
	piedra.Parent = Workspace.CurrentCamera
	local luz = Instance.new("PointLight")
	luz.Color = HistoriaConfig.COLOR_ECLIPSE
	luz.Brightness = 2
	luz.Range = 8
	luz.Parent = piedra
	local brillo = Instance.new("ParticleEmitter")
	brillo.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	brillo.Color = ColorSequence.new(Color3.fromRGB(210, 150, 255))
	brillo.LightEmission = 1
	brillo.Size = NumberSequence.new(0.15, 0)
	brillo.Lifetime = NumberRange.new(0.6, 1.2)
	brillo.Speed = NumberRange.new(0.4, 1)
	brillo.SpreadAngle = Vector2.new(180, 180)
	brillo.Rate = 14
	brillo.Parent = piedra
	local cordon = Instance.new("Part")
	cordon.Name = "Cordon"
	cordon.Size = Vector3.new(0.08, 1.1, 0.08)
	cordon.Material = Enum.Material.Fabric
	cordon.Color = Color3.fromRGB(60, 40, 24)
	cordon.CanCollide = false
	cordon.Anchored = true
	cordon.Parent = piedra
	local vivo = true
	task.spawn(function()
		while vivo and piedra.Parent do
			if mano.Parent then
				local t = os.clock()
				piedra.CFrame = mano.CFrame * CFrame.new(0, -0.7 + math.sin(t * 2) * 0.05, -0.25)
				cordon.CFrame = mano.CFrame * CFrame.new(0, -0.2, -0.25)
			end
			task.wait()
		end
	end)
	return function()
		vivo = false
		piedra:Destroy()
	end
end

function Despertar.Reproducir()
	local jugador = Players.LocalPlayer
	local remoto = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Historia")
	local guiCartel, quitarCartel = cartel(jugador)

	local historia = Workspace:WaitForChild("Historia", 20)
	local cabana = historia and historia:WaitForChild("CabanaEldren", 20)
	local personaje = jugador.Character or jugador.CharacterAdded:Wait()
	local raiz = personaje:WaitForChild("HumanoidRootPart", 10)
	local humanoide = personaje:FindFirstChildOfClass("Humanoid")
	if not (cabana and raiz and humanoide and typeof(cabana:GetAttribute("Cama")) == "CFrame") then
		-- sin cabaña no hay escena, pero la historia sigue
		warn("[DESPERTAR] No encuentro la cabaña; me salto la escena")
		quitarCartel()
		remoto:FireServer("Desperto")
		return
	end
	pcall(function()
		jugador:RequestStreamAroundAsync(cabana:GetAttribute("Centro"), 3)
	end)

	-- ===== el jugador, tumbado en la cama =====
	local cama = cabana:GetAttribute("Cama")
	local salida = cabana:GetAttribute("Salida")
	local puerta = cabana:GetAttribute("Puerta")
	local ventana = cabana:GetAttribute("Ventana")
	-- el servidor lo tumba en la cama (así su posición es la de verdad para todos)
	remoto:FireServer("Cama")
	humanoide.PlatformStand = true
	local espera = os.clock()
	while (raiz.Position - cama.Position).Magnitude > 2 and os.clock() - espera < 3 do
		task.wait(0.05)
	end
	local alturaPie = humanoide.HipHeight + raiz.Size.Y / 2
	local depie = salida * CFrame.new(0, alturaPie, 0)

	-- la cámara empieza en los ojos del jugador: su cabeza y su pelo no se dibujan mientras tanto
	local function verCabeza(visible)
		for _, cosa in personaje:GetDescendants() do
			if cosa:IsA("BasePart") and (cosa.Name == "Head" or cosa:FindFirstAncestorOfClass("Accessory")) then
				cosa.LocalTransparencyModifier = if visible then 0 else 1
			elseif cosa:IsA("Decal") and cosa.Parent and cosa.Parent.Name == "Head" then
				cosa.LocalTransparencyModifier = if visible then 0 else 1
			end
		end
	end
	verCabeza(false)

	local eldren = actorEldren(cabana)
	local cabezaJugador = cama.Position + cama.UpVector * 1.7 + Vector3.new(0, 0.35, 0)
	local cabezaEldren = if eldren then eldren.cabeza() else cabana:GetAttribute("Hogar").Position + Vector3.new(0, 4.6, 0)
	local fuego = cabana:GetAttribute("Hogar").Position
		+ (cabana:GetAttribute("Hogar").LookVector * -2.6)
		+ Vector3.new(0, 1.2, 0)
	local quitarAmuleto = nil

	-- ===== tomas =====
	local tomas = {}
	for _, linea in HistoriaConfig.DESPERTAR.lineas do
		local toma = { duracion = linea.duracion or 4, fov = 62 }
		if linea.texto then
			toma.voz = linea.texto -- la voz lo dice en inglés
			toma.texto = linea.texto -- el subtítulo sale en el idioma del jugador
			toma.quien = linea.quien
			toma.perfil = Voz.PERFILES[linea.quien or "Eldren"]
		end
		if linea.toma == "Ojos" then
			-- primera persona: el techo de vigas, y la mirada que baja hasta el anciano
			toma.fov = 70
			toma.camino = function(x)
				local techo = cabezaJugador + Vector3.new(0, 10, 0) + cama.UpVector * 2
				local objetivo = techo:Lerp(cabezaEldren, math.clamp((x - 0.35) / 0.65, 0, 1) ^ 1.4)
				local balanceo = Vector3.new(math.sin(x * 5) * 0.05, math.cos(x * 4) * 0.04, 0)
				return mirar(cabezaJugador, objetivo + balanceo)
			end
			toma.alEmpezar = function()
				quitarCartel()
				parpados(jugador, toma.duracion)
			end
		elseif linea.toma == "Eldren" then
			-- por encima del hombro del jugador, hacia Eldren junto a la chimenea
			local hacia = (cabezaEldren - cabezaJugador).Unit
			toma.camino = function(x)
				local desde = cabezaJugador - hacia * 1.2 + Vector3.new(0, 1.4, 0) + hacia * (x * 1.6)
				return mirar(desde, cabezaEldren + Vector3.new(0, -0.3, 0))
			end
			toma.fov = 50
			toma.alEmpezar = function()
				if eldren then
					eldren.girarHacia(cabezaJugador)
				end
			end
		elseif linea.toma == "Fuego" then
			-- el fuego crepitando, y luego la cara de Eldren a la luz de las llamas
			-- (desde dentro de la sala, mirando a la chimenea; luego primer plano del anciano)
			local haciaSala = Vector3.new(cabezaJugador.X - fuego.X, 0, cabezaJugador.Z - fuego.Z).Unit
			local lado = haciaSala:Cross(Vector3.yAxis).Unit
			toma.camino = function(x)
				local a = mirar(fuego + haciaSala * 7.5 + lado * 1.5 + Vector3.new(0, 2.2, 0), fuego + Vector3.new(0, 0.6, 0))
				local b = mirar(cabezaEldren + haciaSala * 4 + lado * 1.6 + Vector3.new(0, 0.1, 0), cabezaEldren)
				return a:Lerp(b, x)
			end
			toma.fov = 45
		elseif linea.toma == "Ventana" then
			-- por la ventana se ve el Eclipse sobre las montañas del norte
			toma.camino = function(x)
				local dentro = ventana.Position - ventana.LookVector * (5.5 - x * 2.5) + Vector3.new(0, -0.8, 0)
				local cielo = ventana.Position + HistoriaConfig.ECLIPSE_DIRECCION * 200
				return mirar(dentro, ventana.Position:Lerp(cielo, 0.25 + x * 0.15))
			end
			toma.fov = 55
			toma.efecto = "Eclipse"
		elseif linea.toma == "Levantarse" then
			-- corte: el jugador ya está de pie junto a la cama, frente a Eldren
			toma.alEmpezar = function()
				humanoide.PlatformStand = false
				verCabeza(true)
				remoto:FireServer("DePie")
				if eldren then
					eldren.girarHacia(depie.Position)
				end
			end
			toma.camino = function(x)
				local entre = (depie.Position + cabezaEldren) / 2
				local lado = (cabezaEldren - depie.Position):Cross(Vector3.yAxis).Unit
				return mirar(entre + lado * (8 - x * 1.5) + Vector3.new(0, 1.5, 0), entre + Vector3.new(0, 0.4, 0))
			end
			toma.fov = 50
		elseif linea.toma == "Amuleto" then
			toma.alEmpezar = function()
				if eldren and eldren.mano() then
					eldren.gesto("Saludar", 0.6)
					quitarAmuleto = amuleto(eldren.mano())
				end
			end
			toma.camino = function(x)
				local mano = if eldren and eldren.mano() then eldren.mano().Position else cabezaEldren
				local desde = depie.Position + Vector3.new(0, 2.6, 0) + (mano - depie.Position).Unit * (1 + x * 1.2)
				return mirar(desde, mano + Vector3.new(0, -0.5, 0))
			end
			toma.fov = 40
		elseif linea.toma == "Puerta" then
			-- la puerta abierta: fuera esperan los muñecos de paja
			toma.alEmpezar = function()
				if quitarAmuleto then
					quitarAmuleto()
					quitarAmuleto = nil
				end
				if eldren then
					eldren.girarHacia(puerta.Position)
					eldren.gesto("Senalar", 0.8)
				end
			end
			toma.camino = function(x)
				local dentro = puerta.Position - puerta.LookVector * (7 - x * 3) + Vector3.new(0, 4.6, 0)
				return mirar(dentro, puerta.Position + puerta.LookVector * 30 + Vector3.new(0, 2, 0))
			end
			toma.fov = 58
		end
		table.insert(tomas, toma)
	end

	-- ===== reproducir =====
	local ok, err = pcall(Cinematica.Reproducir, tomas, {
		musica = SonidosConfig.MUSICA.Guardian,
		volumen = 0.16,
		sinBrasas = true,
		sinCoro = true,
		alTerminar = function()
			if quitarAmuleto then
				quitarAmuleto()
			end
			if eldren then
				eldren.quitar()
			end
			-- de pie junto a la cama, mirando a la puerta, y libre para moverse (lo hace el servidor)
			verCabeza(true)
			humanoide.PlatformStand = false
			remoto:FireServer("Desperto")
			humanoide:ChangeState(Enum.HumanoidStateType.GettingUp)
		end,
	})
	if not ok then
		warn("[DESPERTAR]", err)
		if guiCartel.Parent then
			guiCartel:Destroy()
		end
		if eldren then
			eldren.quitar()
		end
		verCabeza(true)
		humanoide.PlatformStand = false
		Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		remoto:FireServer("Desperto")
	end
end

return Despertar

-- Mueve árboles y arbustos con el viento (solo visual, en tu pantalla).
-- Ruta en Studio: StarterPlayer/StarterPlayerScripts/VientoVegetacion
-- Mueve todo lo que tenga la etiqueta "Vegetacion". Cuánto se mueve cada
-- planta lo dice su atributo "Balanceo" (en grados).
-- Para no gastar rendimiento, solo mueve las plantas cercanas a la cámara.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DISTANCIA = 170 -- solo se mueven las plantas a menos de esta distancia
local FRECUENCIA = 1 / 30 -- actualizaciones por segundo

local plantas = {} -- [modelo] = { base, fase, amplitud, movida }

local function registrar(modelo)
	if not modelo:IsA("Model") then
		return
	end
	plantas[modelo] = {
		base = modelo:GetPivot(),
		fase = math.random() * 100,
		rapidez = 0.8 + math.random() * 0.5,
		amplitud = math.rad(modelo:GetAttribute("Balanceo") or 1),
		movida = false,
	}
end

for _, modelo in CollectionService:GetTagged("Vegetacion") do
	registrar(modelo)
end
CollectionService:GetInstanceAddedSignal("Vegetacion"):Connect(registrar)
CollectionService:GetInstanceRemovedSignal("Vegetacion"):Connect(function(modelo)
	plantas[modelo] = nil
end)

-- Eje de balanceo: perpendicular a la dirección del viento
local function ejeDelViento()
	local viento = Workspace.GlobalWind
	local plano = Vector3.new(viento.X, 0, viento.Z)
	if plano.Magnitude < 0.01 then
		return Vector3.xAxis, 0.3
	end
	return Vector3.yAxis:Cross(plano.Unit), math.clamp(plano.Magnitude / 10, 0.2, 2)
end

local acumulado = 0
RunService.Heartbeat:Connect(function(dt)
	acumulado += dt
	if acumulado < FRECUENCIA then
		return
	end
	acumulado = 0

	local camara = Workspace.CurrentCamera
	if not camara then
		return
	end
	local posicionCamara = camara.CFrame.Position
	local t = os.clock()
	local eje, fuerzaViento = ejeDelViento()
	-- Ráfagas: el viento sube y baja poco a poco
	local rafaga = (0.55 + 0.45 * math.noise(t * 0.12, 4.2, 0)) * fuerzaViento

	for modelo, datos in plantas do
		local distancia = (datos.base.Position - posicionCamara).Magnitude
		if distancia < DISTANCIA then
			local tiempo = t * datos.rapidez + datos.fase
			-- Vaivén principal + temblor pequeño + inclinación constante a favor del viento
			local angulo = datos.amplitud
				* rafaga
				* (0.4 + 0.45 * math.sin(tiempo * 1.3) + 0.15 * math.sin(tiempo * 3.7))
			local giro = CFrame.fromAxisAngle(eje, angulo)
			modelo:PivotTo(CFrame.new(datos.base.Position) * giro * datos.base.Rotation)
			datos.movida = true
		elseif datos.movida then
			modelo:PivotTo(datos.base)
			datos.movida = false
		end
	end
end)

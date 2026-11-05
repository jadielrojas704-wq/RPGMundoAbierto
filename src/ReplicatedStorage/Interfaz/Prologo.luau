-- Cinemática del PRÓLOGO de "El Eclipse Eterno" (solo CLIENTE).
-- Ruta en Studio: ReplicatedStorage/Interfaz/Prologo
-- Sale la primera vez que el jugador pulsa Jugar. Los textos están en
-- ReplicatedStorage/Config/HistoriaConfig.PROLOGO; aquí se decide dónde va la cámara.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HistoriaConfig = require(ReplicatedStorage.Config.HistoriaConfig)
local InicioConfig = require(ReplicatedStorage.Config.InicioConfig)
local RegionesConfig = require(ReplicatedStorage.Config.RegionesConfig)
local SonidosConfig = require(ReplicatedStorage.Config.SonidosConfig)
local Cinematica = require(script.Parent.Cinematica)
local Voz = require(script.Parent.Voz)

local Prologo = {}

local function suelo(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local rayo = Workspace:Raycast(Vector3.new(x, 1000, z), Vector3.new(0, -1200, 0), params)
	return rayo and rayo.Position.Y or 40
end

local function centroDe(nombre)
	for _, objeto in Workspace:GetDescendants() do
		if objeto:IsA("Model") and objeto:GetAttribute("Nombre") == nombre then
			local centro = objeto:GetAttribute("Centro")
			if typeof(centro) == "Vector3" then
				return centro
			end
		end
	end
	return nil
end

local function mirar(desde, hacia)
	return CFrame.lookAt(desde, hacia)
end

-- Cada "lugar" del guion: de dónde a dónde va la cámara
local function tomas()
	local jugador = Players.LocalPlayer
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart")
	local inicio = if raiz then raiz.Position else Vector3.new(RegionesConfig.INICIO.X, 60, RegionesConfig.INICIO.Y)
	local altar = Vector3.new(
		RegionesConfig.ALTAR.X,
		suelo(RegionesConfig.ALTAR.X, RegionesConfig.ALTAR.Y),
		RegionesConfig.ALTAR.Y
	)
	local capital = centroDe(InicioConfig.CIUDAD_FONDO) or Vector3.new(-150, 40, 170)
	local eclipse = HistoriaConfig.ECLIPSE_DIRECCION

	local LUGARES = {
		Cielo = function()
			return mirar(Vector3.new(-200, 520, 900), Vector3.new(0, 380, 0)),
				mirar(Vector3.new(150, 560, 780), Vector3.new(0, 400, -100)),
				70
		end,
		Cielo2 = function()
			local a = Vector3.new(0, 420, 300)
			return mirar(a, a + eclipse * 100 + Vector3.new(-40, 0, 0)),
				mirar(a + Vector3.new(0, 40, -120), a + eclipse * 100),
				60
		end,
		Altar = function()
			return mirar(altar + Vector3.new(80, 45, 90), altar + Vector3.new(0, 8, 0)),
				mirar(altar + Vector3.new(-35, 20, 50), altar + Vector3.new(0, 6, 0)),
				55,
				nil,
				"Destello" -- el sacrificio de los Guardianes: relámpago blanco
		end,
		Eclipse = function()
			local desde = altar + Vector3.new(0, 140, 260)
			return mirar(desde, desde + eclipse * 100),
				mirar(desde + Vector3.new(0, 4, -10), desde + eclipse * 100),
				50,
				26,
				"Eclipse"
		end,
		Picos = function()
			local picos = Vector3.new(-200, suelo(-200, -760) + 60, -760)
			return mirar(Vector3.new(260, picos.Y + 160, -320), picos),
				mirar(Vector3.new(60, picos.Y + 120, -420), picos),
				60,
				nil,
				"Dragon" -- la montaña tiembla y el dragón oculto ruge unos segundos
		end,
		Capital = function()
			return mirar(capital + Vector3.new(260, 140, 160), capital + Vector3.new(0, 15, 0)),
				mirar(capital + Vector3.new(150, 90, 240), capital + Vector3.new(0, 10, 0)),
				60
		end,
		Inicio = function()
			-- la cabaña de Eldren, de noche, con luz en la ventana: ahí despertará el jugador
			local historia = Workspace:FindFirstChild("Historia")
			local cabana = historia and historia:FindFirstChild("CabanaEldren")
			local centro = cabana and cabana:GetAttribute("Centro")
			if typeof(centro) == "Vector3" then
				return mirar(centro + Vector3.new(-40, 34, -62), centro + Vector3.new(0, 4, 0)),
					mirar(centro + Vector3.new(-10, 9, -26), centro + Vector3.new(0, 5, 0)),
					55,
					48,
					"Temblor"
			end
			return mirar(inicio + Vector3.new(30, 60, 70), inicio),
				mirar(inicio + Vector3.new(6, 6, 14), inicio + Vector3.new(0, 2, 0)),
				60,
				nil,
				"Temblor"
		end,
	}

	local lista = {}
	for _, linea in HistoriaConfig.PROLOGO do
		local calcular = LUGARES[linea.lugar]
		if calcular then
			local desde, hasta, fov, fovFinal, efecto = calcular()
			-- el mundo llega por zonas (streaming): pedimos la zona que se va a ver
			local foco = hasta.Position + hasta.LookVector * 60
			local function preparar()
				jugador:RequestStreamAroundAsync(foco, 2)
			end
			table.insert(lista, {
				desde = desde,
				hasta = hasta,
				duracion = linea.duracion,
				texto = linea.texto,
				fov = fov,
				fovFinal = fovFinal,
				efecto = efecto,
				preparar = preparar,
			})
		end
	end
	return lista
end

function Prologo.Reproducir()
	Cinematica.Reproducir(
		tomas(),
		{
			titulo = string.upper(InicioConfig.NOMBRE_JUEGO),
			subtitulo = HistoriaConfig.ACTO,
			musica = SonidosConfig.MUSICA.Prologo,
			volumen = 0.38,
			narrador = Voz.PERFILES.Narrador, -- la voz grave que cuenta la historia
		}
	)
end

return Prologo

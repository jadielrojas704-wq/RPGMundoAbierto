-- Forma de la Isla Celestial (el terreno flotante).
-- Ruta en Studio: ReplicatedStorage/Mundo/IslaForma
--
-- La usa el generador del mundo (ServerStorage/Herramientas/Mundo/Terreno).
-- Está en ReplicatedStorage para que más adelante el cliente también pueda usarla
-- (por ejemplo, para efectos al revelar la isla). math.noise siempre da el mismo
-- resultado, así que la isla sale idéntica en cualquier lado.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Regiones = require(ReplicatedStorage.Config.RegionesConfig)

local IslaForma = {}

local RES = 4 -- tamaño de cada "voxel" del terreno en studs
local SEMILLA = 11 -- la misma semilla que el resto del terreno
local RADIO_ISLA = 110
local TAMANO = 256 -- lado de la caja que contiene la isla
local ALTO = 192 -- alto de esa caja
local M = Enum.Material

-- Ruido en capas (igual que en Terreno)
local function ruido(x, z, capas, escala, semilla)
	local total, amplitud, frecuencia, maximo = 0, 1, 1 / escala, 0
	for _ = 1, capas do
		total += math.noise(x * frecuencia, z * frecuencia, semilla) * amplitud
		maximo += amplitud
		amplitud *= 0.5
		frecuencia *= 2
	end
	return total / maximo
end

-- Arriba plana con hierba; abajo una roca en forma de cono invertido.
-- Devuelve la altura de arriba y la de abajo en (x, z), o nil si ahí no hay isla.
function IslaForma.alturas(x, z)
	local centro = Regiones.ISLA
	local dx, dz = x - centro.X, z - centro.Z
	local r = math.sqrt(dx * dx + dz * dz)
	local radio = RADIO_ISLA * (1 + ruido(x, z, 2, 70, SEMILLA + 30) * 0.25)
	if r > radio then
		return nil
	end
	local f = r / radio
	local arriba = centro.Y + ruido(x, z, 3, 60, SEMILLA + 31) * 10 - f ^ 3 * 10
	local abajo = centro.Y - (1 - f) ^ 1.2 * 140 - math.abs(ruido(x, z, 3, 25, SEMILLA + 32)) * 25
	return arriba, abajo
end

-- La caja (Region3) que ocupa la isla, alineada a la rejilla del terreno
function IslaForma.caja()
	local centro = Regiones.ISLA
	local x0 = math.floor((centro.X - TAMANO / 2) / RES) * RES
	local z0 = math.floor((centro.Z - TAMANO / 2) / RES) * RES
	local y0 = math.floor((centro.Y - 150) / RES) * RES
	return Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + TAMANO, y0 + ALTO, z0 + TAMANO)), x0, y0, z0
end

-- Escribe la isla en el terreno
function IslaForma.Construir()
	local region, x0, y0, z0 = IslaForma.caja()
	local nx, ny, nz = TAMANO / RES, ALTO / RES, TAMANO / RES

	local materiales, ocupacion = {}, {}
	for a = 1, nx do
		materiales[a], ocupacion[a] = {}, {}
		for k = 1, ny do
			materiales[a][k], ocupacion[a][k] = {}, {}
		end
		for b = 1, nz do
			local x = x0 + (a - 0.5) * RES
			local z = z0 + (b - 0.5) * RES
			local arriba, abajo = IslaForma.alturas(x, z)
			for k = 1, ny do
				local fondo = y0 + (k - 1) * RES
				local techo = fondo + RES
				local lleno = 0
				if arriba then
					lleno = math.clamp(math.min(arriba - fondo, techo - abajo) / RES, 0, 1)
				end
				ocupacion[a][k][b] = lleno
				if lleno > 0 then
					if arriba - fondo < 6 then
						materiales[a][k][b] = M.Grass
					elseif ruido(x, fondo, 1, 20, SEMILLA + 33) > 0.1 then
						materiales[a][k][b] = M.Slate
					else
						materiales[a][k][b] = M.Rock
					end
				else
					materiales[a][k][b] = M.Air
				end
			end
		end
	end

	Workspace.Terrain:WriteVoxels(region, RES, materiales, ocupacion)
end

return IslaForma

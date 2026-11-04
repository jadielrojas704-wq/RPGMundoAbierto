-- Fórmulas del personaje: convierten los atributos en valores reales de juego.
-- Ruta en Studio: ReplicatedStorage/Progresion/Formulas
-- El SERVIDOR las usa para aplicar los valores de verdad. El cliente solo las usa
-- para enseñar vistas previas en el menú ("Vida 1200 -> 1260").
--
-- Maná, Estamina y Defensa no se reparten: salen de los atributos.
--   Maná      <- INT
--   Estamina  <- VIT y SPD
--   Defensa   <- VIT (y la armadura, cuando exista)

local ProgresionConfig = require(script.Parent.Parent.Config.ProgresionConfig)

local Formulas = {}

local E = ProgresionConfig.EFECTOS

-- Puntos "efectivos" con rendimientos decrecientes (ver ProgresionConfig.TRAMOS)
function Formulas.Efectivo(puntos)
	local total, desde = 0, 0
	puntos = math.max(0, puntos)
	for _, tramo in ProgresionConfig.TRAMOS do
		local enTramo = math.min(puntos, tramo.hasta) - desde
		if enTramo <= 0 then
			break
		end
		total += enTramo * tramo.valor
		desde = tramo.hasta
	end
	return total
end

-- Puntos que el jugador ha metido en un atributo (sin contar los 5 iniciales)
local function extra(atributos, nombre)
	return Formulas.Efectivo((atributos[nombre] or ProgresionConfig.ATRIBUTO_INICIAL) - ProgresionConfig.ATRIBUTO_INICIAL)
end

-- Calcula todos los valores derivados. "bonos" (opcional) suma lo que dé el equipo:
-- { Defensa = n, Vida = n, ... }
function Formulas.Calcular(atributos, bonos)
	bonos = bonos or {}
	local vit, str, dex = extra(atributos, "VIT"), extra(atributos, "STR"), extra(atributos, "DEX")
	local int, luk, spd = extra(atributos, "INT"), extra(atributos, "LUK"), extra(atributos, "SPD")
	local defensa = E.DEFENSA_POR_VIT * vit + (bonos.Defensa or 0)
	return {
		VidaMax = math.floor(E.VIDA_BASE + E.VIDA_POR_VIT * vit + (bonos.Vida or 0)),
		EstaminaMax = math.floor(E.ESTAMINA_BASE + E.ESTAMINA_POR_VIT * vit + E.ESTAMINA_POR_SPD * spd),
		RegenEstamina = 1 + E.REGEN_ESTAMINA_POR_SPD * spd, -- multiplicador
		ManaMax = math.floor(E.MANA_BASE + E.MANA_POR_INT * int),
		RegenMana = E.REGEN_MANA_BASE + E.REGEN_MANA_POR_INT * int,
		Defensa = math.floor(defensa),
		ReduccionDano = defensa / (defensa + E.DEFENSA_K), -- 0 a casi 1, nunca 100 %
		DanoFuerza = 1 + E.DANO_POR_STR * str,
		DanoDestreza = 1 + E.DANO_POR_DEX * dex,
		DanoMagico = 1 + E.DANO_POR_INT * int,
		VelocidadAtaque = 1 + math.min(E.VELOCIDAD_ATAQUE_MAXIMA, E.VELOCIDAD_ATAQUE_POR_DEX * dex),
		MultVelocidad = 1 + math.min(E.VELOCIDAD_MAXIMA, E.VELOCIDAD_POR_SPD * spd),
		Critico = math.min(E.CRITICO_MAXIMO, E.CRITICO_BASE + E.CRITICO_POR_LUK * luk),
		BonoBotin = E.BOTIN_POR_LUK * luk,
	}
end

-- Multiplicador de daño de un arma según los atributos (ver ProgresionConfig.ESCALADO_ARMAS)
function Formulas.EscaladoArma(arma, atributos)
	local reparto = ProgresionConfig.ESCALADO_ARMAS[arma] or { STR = 1 }
	local multiplicador = 0
	for nombre, peso in reparto do
		local porPunto = if nombre == "INT" then E.DANO_POR_INT elseif nombre == "STR" then E.DANO_POR_STR else E.DANO_POR_DEX
		multiplicador += peso * porPunto * extra(atributos, nombre)
	end
	return 1 + multiplicador
end

return Formulas

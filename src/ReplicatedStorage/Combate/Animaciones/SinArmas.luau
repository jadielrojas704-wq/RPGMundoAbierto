-- Animaciones de combate SIN ARMAS (artes marciales demoníacas: rápidas, fluidas y con
-- mucha preparación visible del brazo), hechas pose a pose.
-- Ruta en Studio: ReplicatedStorage/Combate/Animaciones/SinArmas
-- Las reproduce ReplicatedStorage/Combate/Animador.
--
-- Cada golpe tiene 4 tiempos, como en la animación de verdad:
--   1. PREPARACIÓN: el brazo sube y se va hacia atrás, el pecho gira al revés (se "carga").
--   2. GOLPE: sale como un látigo y se pasa un poco (curva "rebote").
--   3. PAUSA: se queda un instante extendido (se lee el impacto).
--   4. VUELTA: regresa suave a la guardia.
--
-- Cómo leer una pose (giros en grados, en el espacio de cada articulación R15):
--   Hombro  X+ = brazo hacia delante · Z = abrir/cerrar el brazo (derecho Z+ abre, izquierdo Z- abre)
--   Codo    X+ = doblar el brazo
--   Cadera  X+ = pierna hacia delante · Z = abrir la pierna (derecha Z+, izquierda Z-)
--   Rodilla X- = doblar
--   Cintura X- = inclinarse adelante · Y+ = girar el pecho a la izquierda (adelanta el hombro derecho)
--   Root    mueve el cuerpo entero: CFrame.new(0, -bajar, -adelante) y giros
-- Tiempos en segundos. El momento del GOLPE coincide con "Activo" de Config/ArmasConfig.
--
-- Eventos que usa StarterPlayerScripts/CombateCliente:
--   silbido   sonido de aire (fuerte = más grave)
--   estela    enciende la estela de luz de una mano o pie { miembro, duracion }
--   onda      onda de aire que sale del puño o pie { miembro }
--   fantasma  imagen residual del cuerpo
--   golpe     momento del impacto · pisada  sonido de apoyo

local Animaciones = {}

local function g(x, y, z)
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

local function cuerpo(bajar, adelante, x, y, z)
	return CFrame.new(0, -(bajar or 0), -(adelante or 0)) * g(x, y, z)
end

-- Copia una pose cambiando solo algunas articulaciones
local function con(base, cambios)
	local nueva = table.clone(base)
	for nombre, valor in cambios do
		nueva[nombre] = valor
	end
	return nueva
end

-- ===== GUARDIA: postura baja y abierta, mano izquierda adelante y puño derecho en la cadera =====
local GUARDIA = {
	Root = cuerpo(0.42, 0, -3, 0, 0),
	Waist = g(-6, -26, 0),
	Neck = g(-4, 24, 0),
	LeftShoulder = g(68, 0, 10),
	LeftElbow = g(58),
	LeftWrist = g(-12),
	RightShoulder = g(-8, 0, 10),
	RightElbow = g(102),
	RightWrist = g(-6),
	LeftHip = g(26, 0, -12),
	RightHip = g(-6, 0, 12),
	LeftKnee = g(-34),
	RightKnee = g(-26),
	LeftAnkle = g(8),
	RightAnkle = g(16),
}
Animaciones.GUARDIA = GUARDIA

-- Respiración de la guardia (pequeño balanceo, en bucle)
local GUARDIA_BAJA = con(GUARDIA, {
	Root = cuerpo(0.5, 0, -4, 2, 0),
	LeftShoulder = g(64, 0, 12),
	LeftElbow = g(62),
	RightShoulder = g(-10, 0, 12),
})
Animaciones.Guardia = {
	duracion = 1.8,
	bucle = true,
	claves = {
		{ t = 0, pose = GUARDIA },
		{ t = 0.9, pose = GUARDIA_BAJA, curva = "suave" },
		{ t = 1.8, pose = GUARDIA, curva = "suave" },
	},
}

-- ===== COMBO M1 =====

-- 1) Jab de izquierda: el brazo sube y se recoge junto a la oreja, y sale recto
local JAB_PREPARA = con(GUARDIA, {
	Root = cuerpo(0.4, -0.1, 0, 6, 0),
	Waist = g(-2, -6, 0),
	Neck = g(-4, 10, 0),
	LeftShoulder = g(80, 0, -75),
	LeftElbow = g(135),
	LeftWrist = g(-20),
})
local JAB_GOLPE = con(GUARDIA, {
	Root = cuerpo(0.46, 0.35, -9, -6, 0),
	Waist = g(-10, -40, 0),
	Neck = g(-6, 34, 0),
	LeftShoulder = g(92, 0, 8),
	LeftElbow = g(0),
	LeftWrist = g(0),
	RightShoulder = g(-14, 0, 8),
	RightElbow = g(108),
})
Animaciones.Jab = {
	duracion = 0.42,
	mezcla = 0.04,
	claves = {
		{ t = 0, pose = GUARDIA },
		{ t = 0.09, pose = JAB_PREPARA, curva = "salida" },
		{ t = 0.15, pose = JAB_GOLPE, curva = "rebote" },
		{ t = 0.22, pose = con(JAB_GOLPE, { LeftShoulder = g(90, 0, 8), LeftElbow = g(6) }), curva = "suave" },
		{ t = 0.42, pose = GUARDIA, curva = "suave" },
	},
	eventos = {
		{ t = 0.01, nombre = "estela", miembro = "LeftHand", duracion = 0.24 },
		{ t = 0.06, nombre = "silbido" },
		{ t = 0.15, nombre = "onda", miembro = "LeftHand" },
		{ t = 0.15, nombre = "golpe" },
	},
}

-- 2) Directo de derecha: el puño sale de la cadera, sube por detrás del hombro y entra
--    con todo el giro de cadera (el peso pasa al pie delantero)
local DIRECTO_PREPARA = con(GUARDIA, {
	Root = cuerpo(0.4, -0.2, 2, -10, 0),
	Waist = g(-2, -46, 0),
	Neck = g(-4, 40, 0),
	RightShoulder = g(78, 0, 85),
	RightElbow = g(140),
	RightWrist = g(-15),
	LeftShoulder = g(76, 0, 16),
	LeftElbow = g(30),
	RightKnee = g(-34),
})
local DIRECTO_GOLPE = con(GUARDIA, {
	Root = cuerpo(0.5, 0.7, -13, 14, 0),
	Waist = g(-12, 44, 0),
	Neck = g(-6, -30, 0),
	RightShoulder = g(94, 0, -4),
	RightElbow = g(0),
	RightWrist = g(0),
	LeftShoulder = g(-10, 0, 10),
	LeftElbow = g(105),
	RightHip = g(-14, 0, 10),
	RightKnee = g(-8),
	RightAnkle = g(-22),
	LeftKnee = g(-44),
})
Animaciones.Directo = {
	duracion = 0.5,
	mezcla = 0.04,
	claves = {
		{ t = 0, pose = GUARDIA },
		{ t = 0.12, pose = DIRECTO_PREPARA, curva = "salida" },
		{ t = 0.2, pose = DIRECTO_GOLPE, curva = "rebote" },
		{
			t = 0.28,
			pose = con(
				DIRECTO_GOLPE,
				{ RightShoulder = g(91, 0, -4), RightElbow = g(8), Root = cuerpo(0.5, 0.65, -12, 12, 0) }
			),
			curva = "suave",
		},
		{ t = 0.5, pose = GUARDIA, curva = "suave" },
	},
	eventos = {
		{ t = 0.02, nombre = "estela", miembro = "RightHand", duracion = 0.3 },
		{ t = 0.1, nombre = "silbido" },
		{ t = 0.2, nombre = "onda", miembro = "RightHand" },
		{ t = 0.2, nombre = "golpe" },
	},
}

-- 3) Gancho de izquierda: el brazo se abre muy atrás y barre en horizontal
local GANCHO_PREPARA = con(GUARDIA, {
	Root = cuerpo(0.5, -0.1, -2, 16, 0),
	Waist = g(-4, 20, 0),
	Neck = g(-4, -4, 0),
	LeftShoulder = g(36, 0, -96),
	LeftElbow = g(80),
	LeftWrist = g(-10),
	RightShoulder = g(50, 0, -10),
	RightElbow = g(120),
})
local GANCHO_GOLPE = con(GUARDIA, {
	Root = cuerpo(0.5, 0.35, -8, -24, 0),
	Waist = g(-10, -50, 0),
	Neck = g(-6, 46, 0),
	LeftShoulder = g(86, 0, 34),
	LeftElbow = g(88),
	LeftWrist = g(0),
	RightShoulder = g(-12, 0, 10),
	RightElbow = g(108),
	LeftKnee = g(-42),
	LeftAnkle = g(-8),
})
Animaciones.Gancho = {
	duracion = 0.52,
	mezcla = 0.04,
	claves = {
		{ t = 0, pose = GUARDIA },
		{ t = 0.12, pose = GANCHO_PREPARA, curva = "salida" },
		{ t = 0.21, pose = GANCHO_GOLPE, curva = "rebote" },
		{
			t = 0.29,
			pose = con(GANCHO_GOLPE, { Waist = g(-10, -54, 0), LeftShoulder = g(84, 0, 38) }),
			curva = "suave",
		},
		{ t = 0.52, pose = GUARDIA, curva = "suave" },
	},
	eventos = {
		{ t = 0.03, nombre = "estela", miembro = "LeftHand", duracion = 0.3 },
		{ t = 0.11, nombre = "silbido" },
		{ t = 0.21, nombre = "onda", miembro = "LeftHand" },
		{ t = 0.21, nombre = "golpe" },
	},
}

-- 4) Patada circular de derecha: los brazos se abren para equilibrar, recoge la rodilla,
--    gira sobre el pie de apoyo y barre con la espinilla
local RECOGER = con(GUARDIA, {
	Root = cuerpo(0.2, 0, 2, 30, 8),
	Waist = g(-4, -14, -8),
	Neck = g(0, -10, 6),
	RightHip = g(92, 0, 30),
	RightKnee = g(-120),
	RightAnkle = g(-24),
	LeftHip = g(6, 0, -6),
	LeftKnee = g(-18),
	LeftShoulder = g(40, 0, -60),
	LeftElbow = g(70),
	RightShoulder = g(30, 0, 60),
	RightElbow = g(70),
})
local PATADA_GOLPE = con(GUARDIA, {
	Root = cuerpo(-0.1, 0.15, 0, 82, 30),
	Waist = g(-2, 14, -16),
	Neck = g(4, -48, 12),
	RightHip = g(72, 0, 84),
	RightKnee = g(-4),
	RightAnkle = g(-28),
	LeftHip = g(-6, 0, -8),
	LeftKnee = g(-8),
	LeftShoulder = g(30, 0, -40),
	LeftElbow = g(90),
	RightShoulder = g(10, 0, 70),
	RightElbow = g(40),
})
Animaciones.Patada = {
	duracion = 0.62,
	mezcla = 0.05,
	claves = {
		{ t = 0, pose = GUARDIA },
		{ t = 0.15, pose = RECOGER, curva = "salida" },
		{ t = 0.3, pose = PATADA_GOLPE, curva = "rebote" },
		{
			t = 0.38,
			pose = con(PATADA_GOLPE, { Root = cuerpo(-0.05, 0.15, 0, 88, 26), RightHip = g(70, 0, 80) }),
			curva = "suave",
		},
		{
			t = 0.48,
			pose = con(RECOGER, { Root = cuerpo(0.15, 0.05, 0, 60, 12), RightHip = g(80, 0, 36), RightKnee = g(-100) }),
			curva = "suave",
		},
		{ t = 0.62, pose = GUARDIA, curva = "suave" },
	},
	eventos = {
		{ t = 0.08, nombre = "estela", miembro = "RightFoot", duracion = 0.34 },
		{ t = 0.17, nombre = "silbido", fuerte = true },
		{ t = 0.28, nombre = "fantasma" },
		{ t = 0.3, nombre = "onda", miembro = "RightFoot" },
		{ t = 0.3, nombre = "golpe" },
		{ t = 0.56, nombre = "pisada" },
	},
}

-- 5) Uppercut final: se agacha con el puño abajo y atrás y sale disparado hacia arriba
local AGACHADO = con(GUARDIA, {
	Root = cuerpo(1.05, 0.05, -18, -16, 0),
	Waist = g(-18, -34, 0),
	Neck = g(12, 26, 0),
	RightShoulder = g(-42, 0, 26),
	RightElbow = g(60),
	RightWrist = g(-10),
	LeftShoulder = g(76, 0, 18),
	LeftElbow = g(100),
	LeftHip = g(52, 0, -10),
	RightHip = g(40, 0, 10),
	LeftKnee = g(-82),
	RightKnee = g(-76),
	LeftAnkle = g(24),
	RightAnkle = g(28),
})
local UPPER_GOLPE = con(GUARDIA, {
	Root = cuerpo(-0.45, 0.4, 12, 24, 0),
	Waist = g(16, 32, 0),
	Neck = g(24, -16, 0),
	RightShoulder = g(170, 0, -12),
	RightElbow = g(28),
	RightWrist = g(0),
	LeftShoulder = g(-14, 0, 14),
	LeftElbow = g(100),
	LeftHip = g(6, 0, -6),
	RightHip = g(-12, 0, 6),
	LeftKnee = g(-4),
	RightKnee = g(-10),
	LeftAnkle = g(-22),
	RightAnkle = g(-34),
})
Animaciones.Uppercut = {
	duracion = 0.68,
	mezcla = 0.05,
	claves = {
		{ t = 0, pose = GUARDIA },
		{ t = 0.16, pose = AGACHADO, curva = "salida" },
		{ t = 0.3, pose = UPPER_GOLPE, curva = "rebote" },
		{
			t = 0.4,
			pose = con(
				UPPER_GOLPE,
				{ Root = cuerpo(-0.4, 0.38, 10, 22, 0), RightShoulder = g(166, 0, -12), RightElbow = g(34) }
			),
			curva = "suave",
		},
		{ t = 0.68, pose = GUARDIA, curva = "suave" },
	},
	eventos = {
		{ t = 0.08, nombre = "estela", miembro = "RightHand", duracion = 0.36 },
		{ t = 0.17, nombre = "silbido", fuerte = true },
		{ t = 0.28, nombre = "fantasma" },
		{ t = 0.3, nombre = "onda", miembro = "RightHand" },
		{ t = 0.3, nombre = "golpe" },
	},
}

Animaciones.COMBO = { "Jab", "Directo", "Gancho", "Patada", "Uppercut" }

-- ===== GOLPE CARGADO =====

-- Cargando (en bucle mientras mantienes): el puño derecho sube por detrás de la cabeza,
-- el cuerpo se hunde y se tuerce, la mano izquierda apunta al enemigo
local CARGA = con(GUARDIA, {
	Root = cuerpo(0.75, -0.3, -4, -36, 0),
	Waist = g(-6, -50, 0),
	Neck = g(-8, 44, 0),
	RightShoulder = g(70, 0, 100),
	RightElbow = g(135),
	RightWrist = g(-20),
	LeftShoulder = g(86, 0, 12),
	LeftElbow = g(12),
	LeftWrist = g(-30),
	LeftHip = g(40, 0, -14),
	RightHip = g(22, 0, 14),
	LeftKnee = g(-58),
	RightKnee = g(-48),
	LeftAnkle = g(16),
	RightAnkle = g(16),
})
local CARGA_PULSO = con(CARGA, { Root = cuerpo(0.82, -0.3, -5, -38, 0), RightShoulder = g(66, 0, 104) })
Animaciones.Carga = {
	duracion = 0.75,
	bucle = true,
	repetirDesde = 0.25,
	mezcla = 0.08,
	claves = {
		{ t = 0, pose = GUARDIA },
		{ t = 0.25, pose = CARGA, curva = "salida" },
		{ t = 0.5, pose = CARGA_PULSO, curva = "suave" },
		{ t = 0.75, pose = CARGA, curva = "suave" },
	},
}

-- Soltar la carga: estocada enorme hacia delante con todo el cuerpo
local CARGADO_GOLPE = con(GUARDIA, {
	Root = cuerpo(0.6, 1.25, -18, 20, 0),
	Waist = g(-14, 50, 0),
	Neck = g(-10, -32, 0),
	RightShoulder = g(96, 0, -2),
	RightElbow = g(0),
	RightWrist = g(0),
	LeftShoulder = g(-20, 0, 20),
	LeftElbow = g(110),
	LeftHip = g(52, 0, -10),
	LeftKnee = g(-56),
	RightHip = g(-24, 0, 10),
	RightKnee = g(-4),
	RightAnkle = g(-30),
})
Animaciones.GolpeCargado = {
	duracion = 0.62,
	mezcla = 0.02,
	claves = {
		{ t = 0, pose = CARGA },
		{ t = 0.05, pose = con(CARGA, { RightShoulder = g(64, 0, 110), Waist = g(-6, -56, 0) }), curva = "salida" },
		{ t = 0.14, pose = CARGADO_GOLPE, curva = "rebote" },
		{
			t = 0.32,
			pose = con(
				CARGADO_GOLPE,
				{ Root = cuerpo(0.55, 1.15, -16, 18, 0), RightShoulder = g(93, 0, -2), RightElbow = g(5) }
			),
			curva = "suave",
		},
		{ t = 0.62, pose = GUARDIA, curva = "suave" },
	},
	eventos = {
		{ t = 0, nombre = "estela", miembro = "RightHand", duracion = 0.3 },
		{ t = 0, nombre = "silbido", fuerte = true },
		{ t = 0.12, nombre = "fantasma" },
		{ t = 0.14, nombre = "onda", miembro = "RightHand", grande = true },
		{ t = 0.14, nombre = "golpe" },
	},
}

-- ===== REACCIONES (las usa cualquier personaje al recibir un golpe) =====

local NEUTRA = {}
Animaciones.ReaccionLeve = {
	duracion = 0.34,
	mezcla = 0.02,
	claves = {
		{ t = 0, pose = NEUTRA },
		{
			t = 0.05,
			curva = "latigo",
			pose = {
				Root = cuerpo(0.05, -0.2, 8, 0, 0),
				Waist = g(12, 0, 0),
				Neck = g(22, 0, 0),
				LeftShoulder = g(-12, 0, -18),
				RightShoulder = g(-12, 0, 18),
			},
		},
		{ t = 0.34, pose = NEUTRA, curva = "suave" },
	},
}

Animaciones.ReaccionFuerte = {
	duracion = 0.6,
	mezcla = 0.02,
	claves = {
		{ t = 0, pose = NEUTRA },
		{
			t = 0.06,
			curva = "latigo",
			pose = {
				Root = cuerpo(0.25, -0.4, 16, 8, 0),
				Waist = g(20, 10, 0),
				Neck = g(30, -10, 0),
				LeftShoulder = g(-20, 0, -40),
				RightShoulder = g(-10, 0, 35),
				LeftElbow = g(30),
				RightElbow = g(25),
				LeftKnee = g(-25),
				RightKnee = g(-15),
				LeftHip = g(10),
			},
		},
		{
			t = 0.25,
			pose = {
				Root = cuerpo(0.35, -0.2, 6, 4, 0),
				Waist = g(-6, 4, 0),
				Neck = g(-10, 0, 0),
				LeftKnee = g(-30),
				RightKnee = g(-30),
				LeftHip = g(20),
				RightHip = g(20),
			},
			curva = "suave",
		},
		{ t = 0.6, pose = NEUTRA, curva = "suave" },
	},
}

Animaciones.ReaccionLanzado = {
	duracion = 1.1,
	mezcla = 0.02,
	claves = {
		{ t = 0, pose = NEUTRA },
		{
			t = 0.08,
			curva = "latigo",
			pose = {
				Root = cuerpo(0, 0, 35, 0, 0),
				Waist = g(25, 0, 0),
				Neck = g(35, 0, 0),
				LeftShoulder = g(20, 0, -70),
				RightShoulder = g(20, 0, 70),
				LeftHip = g(30),
				RightHip = g(-10),
				LeftKnee = g(-50),
				RightKnee = g(-20),
			},
		},
		{
			t = 0.6,
			pose = {
				Root = cuerpo(0, 0, 20, 0, 0),
				Waist = g(15, 0, 0),
				Neck = g(20, 0, 0),
				LeftShoulder = g(40, 0, -50),
				RightShoulder = g(40, 0, 50),
				LeftHip = g(40),
				RightHip = g(20),
				LeftKnee = g(-60),
				RightKnee = g(-40),
			},
			curva = "suave",
		},
		{
			t = 0.85,
			pose = {
				Root = cuerpo(0.6, 0, -10, 0, 0),
				Waist = g(-15, 0, 0),
				LeftHip = g(50),
				RightHip = g(45),
				LeftKnee = g(-80),
				RightKnee = g(-75),
				LeftShoulder = g(30, 0, -20),
				RightShoulder = g(30, 0, 20),
			},
			curva = "salida",
		},
		{ t = 1.1, pose = NEUTRA, curva = "suave" },
	},
}

-- Tambaleo (postura rota): cabeza colgando, brazos caídos, se balancea
local TAMBALEO_A = {
	Root = cuerpo(0.45, 0.1, -12, 8, 6),
	Waist = g(-22, 6, 4),
	Neck = g(-30, 10, 0),
	LeftShoulder = g(5, 0, 8),
	RightShoulder = g(8, 0, -6),
	LeftElbow = g(15),
	RightElbow = g(20),
	LeftKnee = g(-35),
	RightKnee = g(-25),
	LeftHip = g(25),
	RightHip = g(15),
}
local TAMBALEO_B = {
	Root = cuerpo(0.5, 0.15, -14, -6, -6),
	Waist = g(-24, -6, -4),
	Neck = g(-28, -12, 0),
	LeftShoulder = g(8, 0, 6),
	RightShoulder = g(5, 0, -8),
	LeftElbow = g(20),
	RightElbow = g(15),
	LeftKnee = g(-25),
	RightKnee = g(-35),
	LeftHip = g(15),
	RightHip = g(25),
}
Animaciones.Tambaleo = {
	duracion = 2.2,
	mezcla = 0.08,
	claves = {
		{ t = 0, pose = NEUTRA },
		{ t = 0.2, pose = TAMBALEO_A, curva = "salida" },
		{ t = 0.8, pose = TAMBALEO_B, curva = "suave" },
		{ t = 1.4, pose = TAMBALEO_A, curva = "suave" },
		{ t = 1.9, pose = TAMBALEO_B, curva = "suave" },
		{ t = 2.2, pose = NEUTRA, curva = "suave" },
	},
}

return Animaciones

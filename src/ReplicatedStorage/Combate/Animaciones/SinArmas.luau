-- Animaciones de combate SIN ARMAS (artes marciales), hechas pose a pose.
-- Ruta en Studio: ReplicatedStorage/Combate/Animaciones/SinArmas
-- Las reproduce ReplicatedStorage/Combate/Animador.
--
-- Cómo leer una pose (giros en grados, en el espacio de cada articulación R15):
--   Hombro  X+ = brazo hacia delante · Z = abrir/cerrar el brazo (derecho Z+ abre, izquierdo Z- abre)
--   Codo    X+ = doblar el brazo
--   Cadera  X+ = pierna hacia delante · Z = abrir la pierna (derecha Z+, izquierda Z-)
--   Rodilla X- = doblar
--   Cintura X- = inclinarse adelante · Y+ = girar el pecho a la izquierda
--   Root    mueve el cuerpo entero: CFrame.new(0, -bajar, -adelante) y giros
-- Tiempos en segundos. Los golpes conectan en el tiempo "Activo" de Config/ArmasConfig.

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

-- ===== GUARDIA: postura de combate (izquierda adelantada, puños a la altura de la cara) =====
local GUARDIA = {
	Root = cuerpo(0.22, 0, -4, 0, 0),
	Waist = g(-6, -20, 0),
	Neck = g(-5, 18, 0),
	LeftShoulder = g(72, 0, 16),
	LeftElbow = g(108),
	LeftWrist = g(-10),
	RightShoulder = g(58, 0, -22),
	RightElbow = g(122),
	RightWrist = g(-10),
	LeftHip = g(14, 0, -4),
	RightHip = g(6, 0, 4),
	LeftKnee = g(-18),
	RightKnee = g(-14),
	LeftAnkle = g(5),
	RightAnkle = g(8),
}
Animaciones.GUARDIA = GUARDIA

-- Respiración de la guardia (pequeño balanceo, en bucle)
local GUARDIA_BAJA = con(GUARDIA, {
	Root = cuerpo(0.3, 0, -5, 2, 0),
	LeftShoulder = g(68, 0, 18),
	RightShoulder = g(55, 0, -24),
})
Animaciones.Guardia = {
	duracion = 1.6,
	bucle = true,
	claves = {
		{ t = 0, pose = GUARDIA },
		{ t = 0.8, pose = GUARDIA_BAJA, curva = "suave" },
		{ t = 1.6, pose = GUARDIA, curva = "suave" },
	},
}

-- ===== COMBO M1 =====

-- 1) Jab de izquierda: rápido, el hombro se adelanta y el cuerpo entra un poco
Animaciones.Jab = {
	duracion = 0.34,
	claves = {
		{ t = 0, pose = GUARDIA },
		{ t = 0.05, pose = con(GUARDIA, { LeftShoulder = g(62, 0, 20), LeftElbow = g(122), Waist = g(-6, -26, 0) }), curva = "salida" },
		{
			t = 0.11,
			curva = "latigo",
			pose = con(GUARDIA, {
				Root = cuerpo(0.3, 0.3, -8, -4, 0),
				Waist = g(-9, -34, 0),
				Neck = g(-6, 26, 0),
				LeftShoulder = g(93, 0, 6),
				LeftElbow = g(3),
				LeftWrist = g(0),
				RightShoulder = g(62, 0, -24),
				RightElbow = g(126),
			}),
		},
		{ t = 0.19, pose = con(GUARDIA, { Root = cuerpo(0.28, 0.25, -7, -3, 0), Waist = g(-8, -32, 0), LeftShoulder = g(88, 0, 8), LeftElbow = g(12) }), curva = "suave" },
		{ t = 0.34, pose = GUARDIA, curva = "suave" },
	},
	eventos = { { t = 0.02, nombre = "silbido" }, { t = 0.11, nombre = "golpe" } },
}

-- 2) Directo de derecha: giro de cadera completo, el peso pasa al pie delantero
Animaciones.Directo = {
	duracion = 0.4,
	claves = {
		{ t = 0, pose = GUARDIA },
		{
			t = 0.06,
			curva = "salida",
			pose = con(GUARDIA, { Root = cuerpo(0.34, 0, -5, -6, 0), Waist = g(-5, -32, 0), RightShoulder = g(48, 0, -26), RightElbow = g(132) }),
		},
		{
			t = 0.14,
			curva = "latigo",
			pose = con(GUARDIA, {
				Root = cuerpo(0.36, 0.5, -11, 10, 0),
				Waist = g(-11, 40, 0),
				Neck = g(-6, -22, 0),
				RightShoulder = g(94, 0, -3),
				RightElbow = g(2),
				RightWrist = g(0),
				LeftShoulder = g(52, 0, 26),
				LeftElbow = g(128),
				RightHip = g(-6, 0, 4),
				RightKnee = g(-8),
				RightAnkle = g(-18),
				LeftKnee = g(-30),
			}),
		},
		{ t = 0.24, pose = con(GUARDIA, { Root = cuerpo(0.34, 0.42, -10, 8, 0), Waist = g(-10, 36, 0), RightShoulder = g(88, 0, -5), RightElbow = g(10) }), curva = "suave" },
		{ t = 0.4, pose = GUARDIA, curva = "suave" },
	},
	eventos = { { t = 0.05, nombre = "silbido" }, { t = 0.14, nombre = "golpe" } },
}

-- 3) Gancho de izquierda: el brazo en ángulo recto barre en horizontal
Animaciones.Gancho = {
	duracion = 0.44,
	claves = {
		{ t = 0, pose = GUARDIA },
		{
			t = 0.08,
			curva = "salida",
			pose = con(GUARDIA, {
				Root = cuerpo(0.42, 0, -6, -12, 0),
				Waist = g(-8, -42, 0),
				LeftShoulder = g(55, 0, -50),
				LeftElbow = g(95),
			}),
		},
		{
			t = 0.17,
			curva = "latigo",
			pose = con(GUARDIA, {
				Root = cuerpo(0.4, 0.25, -8, 18, 0),
				Waist = g(-10, 34, 0),
				Neck = g(-6, -16, 0),
				LeftShoulder = g(90, 0, -22),
				LeftElbow = g(92),
				LeftWrist = g(0, 0, 0),
				RightShoulder = g(55, 0, -26),
				RightElbow = g(126),
				LeftKnee = g(-26),
				LeftAnkle = g(-10),
			}),
		},
		{ t = 0.27, pose = con(GUARDIA, { Root = cuerpo(0.38, 0.2, -7, 22, 0), Waist = g(-9, 40, 0), LeftShoulder = g(82, 0, -10), LeftElbow = g(100) }), curva = "suave" },
		{ t = 0.44, pose = GUARDIA, curva = "suave" },
	},
	eventos = { { t = 0.07, nombre = "silbido" }, { t = 0.17, nombre = "golpe" } },
}

-- 4) Patada circular de derecha: recoge la rodilla, gira sobre el pie de apoyo y barre
local RECOGER = con(GUARDIA, {
	Root = cuerpo(0.1, 0, 0, 25, 10),
	Waist = g(-4, -10, -8),
	RightHip = g(88, 0, 28),
	RightKnee = g(-115),
	RightAnkle = g(-20),
	LeftKnee = g(-12),
	LeftShoulder = g(60, 0, 25),
	RightShoulder = g(40, 0, 20),
	RightElbow = g(90),
})
Animaciones.Patada = {
	duracion = 0.56,
	claves = {
		{ t = 0, pose = GUARDIA },
		{ t = 0.12, pose = RECOGER, curva = "salida" },
		{
			t = 0.27,
			curva = "latigo",
			pose = con(GUARDIA, {
				Root = cuerpo(-0.15, 0.1, 0, 75, 28),
				Waist = g(-2, 12, -14),
				Neck = g(4, -40, 10),
				RightHip = g(70, 0, 80),
				RightKnee = g(-6),
				RightAnkle = g(-25),
				LeftHip = g(-6, 0, -8),
				LeftKnee = g(-6),
				LeftShoulder = g(35, 0, -35),
				LeftElbow = g(85),
				RightShoulder = g(20, 0, 55),
				RightElbow = g(50),
			}),
		},
		{ t = 0.37, pose = con(RECOGER, { Root = cuerpo(0.05, 0.05, 0, 50, 15), RightHip = g(78, 0, 35), RightKnee = g(-100) }), curva = "suave" },
		{ t = 0.56, pose = GUARDIA, curva = "suave" },
	},
	eventos = { { t = 0.15, nombre = "silbido", fuerte = true }, { t = 0.27, nombre = "golpe" }, { t = 0.5, nombre = "pisada" } },
}

-- 5) Uppercut final: se agacha mucho y sale disparado hacia arriba (lanza al enemigo)
local AGACHADO = con(GUARDIA, {
	Root = cuerpo(0.95, 0.1, -16, -12, 0),
	Waist = g(-16, -28, 0),
	Neck = g(10, 20, 0),
	RightShoulder = g(18, 0, -12),
	RightElbow = g(100),
	LeftShoulder = g(70, 0, 20),
	LeftElbow = g(115),
	LeftHip = g(48, 0, -6),
	RightHip = g(42, 0, 6),
	LeftKnee = g(-75),
	RightKnee = g(-70),
	LeftAnkle = g(22),
	RightAnkle = g(25),
})
Animaciones.Uppercut = {
	duracion = 0.62,
	claves = {
		{ t = 0, pose = GUARDIA },
		{ t = 0.13, pose = AGACHADO, curva = "salida" },
		{
			t = 0.26,
			curva = "latigo",
			pose = con(GUARDIA, {
				Root = cuerpo(-0.4, 0.35, 10, 22, 0),
				Waist = g(14, 28, 0),
				Neck = g(22, -14, 0),
				RightShoulder = g(168, 0, -14),
				RightElbow = g(32),
				RightWrist = g(0),
				LeftShoulder = g(40, 0, 30),
				LeftElbow = g(110),
				LeftHip = g(4),
				RightHip = g(-10),
				LeftKnee = g(-4),
				RightKnee = g(-8),
				LeftAnkle = g(-20),
				RightAnkle = g(-30),
			}),
		},
		{ t = 0.42, pose = con(GUARDIA, { Root = cuerpo(-0.25, 0.3, 8, 20, 0), Waist = g(10, 24, 0), RightShoulder = g(160, 0, -14), RightElbow = g(40) }), curva = "suave" },
		{ t = 0.62, pose = GUARDIA, curva = "suave" },
	},
	eventos = { { t = 0.14, nombre = "silbido", fuerte = true }, { t = 0.26, nombre = "golpe" } },
}

Animaciones.COMBO = { "Jab", "Directo", "Gancho", "Patada", "Uppercut" }

-- ===== GOLPE CARGADO =====

-- Cargando (en bucle mientras mantienes): puño derecho atrás, peso abajo, temblor de energía
local CARGA = con(GUARDIA, {
	Root = cuerpo(0.6, -0.25, -6, -32, 0),
	Waist = g(-8, -44, 0),
	Neck = g(-8, 36, 0),
	RightShoulder = g(-25, 0, -30),
	RightElbow = g(112),
	LeftShoulder = g(82, 0, 8),
	LeftElbow = g(35),
	LeftWrist = g(-15),
	LeftHip = g(36, 0, -8),
	RightHip = g(24, 0, 10),
	LeftKnee = g(-50),
	RightKnee = g(-42),
	LeftAnkle = g(14),
	RightAnkle = g(14),
})
local CARGA_PULSO = con(CARGA, { Root = cuerpo(0.66, -0.25, -7, -34, 0), RightShoulder = g(-30, 0, -32) })
Animaciones.Carga = {
	duracion = 0.7,
	bucle = true,
	repetirDesde = 0.2,
	mezcla = 0.08,
	claves = {
		{ t = 0, pose = GUARDIA },
		{ t = 0.2, pose = CARGA, curva = "salida" },
		{ t = 0.45, pose = CARGA_PULSO, curva = "suave" },
		{ t = 0.7, pose = CARGA, curva = "suave" },
	},
}

-- Soltar la carga: estocada enorme hacia delante
Animaciones.GolpeCargado = {
	duracion = 0.58,
	mezcla = 0.02,
	claves = {
		{ t = 0, pose = CARGA },
		{
			t = 0.13,
			curva = "latigo",
			pose = con(GUARDIA, {
				Root = cuerpo(0.5, 1.1, -16, 16, 0),
				Waist = g(-14, 46, 0),
				Neck = g(-10, -26, 0),
				RightShoulder = g(95, 0, -2),
				RightElbow = g(0),
				RightWrist = g(0),
				LeftShoulder = g(35, 0, 38),
				LeftElbow = g(120),
				LeftHip = g(45, 0, -6),
				LeftKnee = g(-48),
				RightHip = g(-18, 0, 6),
				RightKnee = g(-6),
				RightAnkle = g(-25),
			}),
		},
		{ t = 0.3, pose = con(GUARDIA, { Root = cuerpo(0.45, 1, -14, 14, 0), Waist = g(-13, 44, 0), RightShoulder = g(92, 0, -2), RightElbow = g(4) }), curva = "suave" },
		{ t = 0.58, pose = GUARDIA, curva = "suave" },
	},
	eventos = { { t = 0, nombre = "silbido", fuerte = true }, { t = 0.13, nombre = "golpe" } },
}

-- ===== REACCIONES (las usa cualquier personaje al recibir un golpe) =====

local NEUTRA = {}
Animaciones.ReaccionLeve = {
	duracion = 0.32,
	mezcla = 0.02,
	claves = {
		{ t = 0, pose = NEUTRA },
		{
			t = 0.05,
			curva = "latigo",
			pose = { Root = cuerpo(0.05, -0.2, 8, 0, 0), Waist = g(12, 0, 0), Neck = g(22, 0, 0), LeftShoulder = g(-12, 0, -18), RightShoulder = g(-12, 0, 18) },
		},
		{ t = 0.32, pose = NEUTRA, curva = "suave" },
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
		{ t = 0.25, pose = { Root = cuerpo(0.35, -0.2, 6, 4, 0), Waist = g(-6, 4, 0), Neck = g(-10, 0, 0), LeftKnee = g(-30), RightKnee = g(-30), LeftHip = g(20), RightHip = g(20) }, curva = "suave" },
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
			pose = { Root = cuerpo(0, 0, 35, 0, 0), Waist = g(25, 0, 0), Neck = g(35, 0, 0), LeftShoulder = g(20, 0, -70), RightShoulder = g(20, 0, 70), LeftHip = g(30), RightHip = g(-10), LeftKnee = g(-50), RightKnee = g(-20) },
		},
		{ t = 0.6, pose = { Root = cuerpo(0, 0, 20, 0, 0), Waist = g(15, 0, 0), Neck = g(20, 0, 0), LeftShoulder = g(40, 0, -50), RightShoulder = g(40, 0, 50), LeftHip = g(40), RightHip = g(20), LeftKnee = g(-60), RightKnee = g(-40) }, curva = "suave" },
		{ t = 0.85, pose = { Root = cuerpo(0.6, 0, -10, 0, 0), Waist = g(-15, 0, 0), LeftHip = g(50), RightHip = g(45), LeftKnee = g(-80), RightKnee = g(-75), LeftShoulder = g(30, 0, -20), RightShoulder = g(30, 0, 20) }, curva = "salida" },
		{ t = 1.1, pose = NEUTRA, curva = "suave" },
	},
}

-- Tambaleo (postura rota): cabeza colgando, brazos caídos, se balancea
local TAMBALEO_A = { Root = cuerpo(0.45, 0.1, -12, 8, 6), Waist = g(-22, 6, 4), Neck = g(-30, 10, 0), LeftShoulder = g(5, 0, 8), RightShoulder = g(8, 0, -6), LeftElbow = g(15), RightElbow = g(20), LeftKnee = g(-35), RightKnee = g(-25), LeftHip = g(25), RightHip = g(15) }
local TAMBALEO_B = { Root = cuerpo(0.5, 0.15, -14, -6, -6), Waist = g(-24, -6, -4), Neck = g(-28, -12, 0), LeftShoulder = g(8, 0, 6), RightShoulder = g(5, 0, -8), LeftElbow = g(20), RightElbow = g(15), LeftKnee = g(-25), RightKnee = g(-35), LeftHip = g(15), RightHip = g(25) }
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

-- AUDITORÍA del mundo: busca edificios que se pisan, que flotan, que se hunden
-- en el terreno y vegetación metida dentro de edificios. Solo informa (no cambia nada).
-- Ruta en Studio: ServerStorage/Herramientas/Auditoria
-- Uso (barra de comandos, mejor con Play en la pestaña Server para incluir los santuarios):
--     require(game.ServerStorage.Herramientas.Auditoria).Auditar()

local Auditoria = {}

function Auditoria.Auditar()
	local W = workspace
	local params = RaycastParams.new() params.FilterType = Enum.RaycastFilterType.Include params.FilterDescendantsInstances = { W.Terrain }
	local function sueloY(x, z) local r = W:Raycast(Vector3.new(x, 900, z), Vector3.new(0, -1200, 0), params) return r and r.Position.Y end
	local objs = {}
	local function add(m, grupo, muro)
		local ok, cf, t = pcall(function()
			if m:IsA("BasePart") then return m.CFrame, m.Size end
			local a, b = m:GetBoundingBox() return a, b
		end)
		if not ok or not cf then return end
		if t.X * t.Z < 30 or t.Y < 2 then return end
		if t.X > 400 or t.Z > 400 then return end
		local yaw = select(2, cf:ToEulerAnglesYXZ())
		table.insert(objs, { m = m, g = grupo, cf = CFrame.new(cf.Position) * CFrame.Angles(0, yaw, 0), t = t, n = grupo .. "/" .. (if muro then "Muro:" else "") .. m.Name, muro = muro })
	end
	for _, p in W.Mundo.Pueblos:GetChildren() do
		for _, c in p:GetChildren() do
			if c.Name == "Muralla" or c.Name == "Valla" then
				for _, tramo in c:GetChildren() do if tramo:IsA("Model") or tramo:IsA("BasePart") then add(tramo, p.Name, true) end end
			elseif c:IsA("Model") and not c:FindFirstChildOfClass("Humanoid") then add(c, p.Name) end
		end
	end
	for _, n in { "Fogata", "Altar", "AltarDelAscenso" } do local m = W.Mundo:FindFirstChild(n, true) if m and m:IsA("Model") then add(m, "Estructura") end end
	local h = W:FindFirstChild("Historia") if h then for _, c in h:GetChildren() do if c:IsA("Model") and not c:FindFirstChildOfClass("Humanoid") then add(c, "Historia") end end end
	local function esquinas(o) local cs = {} for _, s in { { 1, 1 }, { 1, -1 }, { -1, -1 }, { -1, 1 } } do table.insert(cs, (o.cf * CFrame.new(s[1] * o.t.X / 2, 0, s[2] * o.t.Z / 2)).Position) end return cs end
	local function ejes(o) return { o.cf.RightVector, o.cf.LookVector } end
	local function solapa(a, b)
		local ca, cb = esquinas(a), esquinas(b)
		local minimo = math.huge
		for _, e in { ejes(a)[1], ejes(a)[2], ejes(b)[1], ejes(b)[2] } do
			local e2 = Vector3.new(e.X, 0, e.Z).Unit
			local a0, a1, b0, b1 = math.huge, -math.huge, math.huge, -math.huge
			for _, p in ca do local d = p:Dot(e2) a0 = math.min(a0, d) a1 = math.max(a1, d) end
			for _, p in cb do local d = p:Dot(e2) b0 = math.min(b0, d) b1 = math.max(b1, d) end
			local s = math.min(a1, b1) - math.max(a0, b0)
			if s <= 0 then return 0 end
			minimo = math.min(minimo, s)
		end
		local ay0, ay1 = a.cf.Y - a.t.Y / 2, a.cf.Y + a.t.Y / 2
		local by0, by1 = b.cf.Y - b.t.Y / 2, b.cf.Y + b.t.Y / 2
		if math.min(ay1, by1) - math.max(ay0, by0) <= 0 then return 0 end
		return minimo
	end
	local choques = {}
	for i = 1, #objs do for j = i + 1, #objs do
		local a, b = objs[i], objs[j]
		if not (a.muro and b.muro) and (a.cf.Position - b.cf.Position).Magnitude < (a.t.Magnitude + b.t.Magnitude) / 2 then
			local s = solapa(a, b)
			if s > 1.5 then table.insert(choques, { s, a.n, b.n, a.cf.Position }) end
		end
	end end
	table.sort(choques, function(x, y) return x[1] > y[1] end)
	print("AUD objetos", #objs, "choques", #choques)
	for k = 1, math.min(40, #choques) do local c = choques[k] print(string.format("AUD CHOQUE %.1f %s <> %s @ %d,%d", c[1], c[2], c[3], c[4].X, c[4].Z)) end
	local flotan, hundidos = {}, {}
	for _, o in objs do
		if o.muro then continue end
		local base = o.cf.Y - o.t.Y / 2
		local ys = {}
		for _, p in esquinas(o) do local y = sueloY(p.X, p.Z) if y then table.insert(ys, y) end end
		if #ys == 4 then
			local mn, mx = math.min(table.unpack(ys)), math.max(table.unpack(ys))
			if base - mn > 2.5 then table.insert(flotan, { base - mn, o.n, o.cf.Position }) end
			if mx - base > 6 then table.insert(hundidos, { mx - base, o.n, o.cf.Position }) end
		end
	end
	table.sort(flotan, function(x, y) return x[1] > y[1] end) table.sort(hundidos, function(x, y) return x[1] > y[1] end)
	print("AUD flotan", #flotan, "hundidos", #hundidos)
	for k = 1, math.min(15, #flotan) do local c = flotan[k] print(string.format("AUD FLOTA %.1f %s @ %d,%d", c[1], c[2], c[3].X, c[3].Z)) end
	for k = 1, math.min(15, #hundidos) do local c = hundidos[k] print(string.format("AUD HUNDE %.1f %s @ %d,%d", c[1], c[2], c[3].X, c[3].Z)) end
	local arboles = 0 local ej = {}
	for _, nombre in { "BosqueNormal", "BosqueOscuro", "Desierto", "Montanas" } do
		local f = W.Mundo:FindFirstChild(nombre)
		if f then for _, v in f:GetChildren() do
			local p = v:GetPivot().Position
			for _, o in objs do
				if o.muro then continue end
				local l = o.cf:PointToObjectSpace(p)
				if math.abs(l.X) < o.t.X / 2 - 1 and math.abs(l.Z) < o.t.Z / 2 - 1 and math.abs(l.Y) < o.t.Y / 2 + 8 then arboles += 1 if #ej < 12 then table.insert(ej, v.Name .. " en " .. o.n) end break end
			end
		end end
	end
	print("AUD vegetacion dentro de edificios", arboles) for _, e in ej do print("AUD VEG", e) end
	return choques, flotan, hundidos
end

return Auditoria

-- PLUGIN para subir a Roblox las texturas del juego (ropa y caras) que dibuja Claude.
-- Ruta en Studio: ServerStorage/Herramientas/PluginSubidor (este Script NO se ejecuta en el juego:
-- los Script dentro de ServerStorage nunca corren).
--
-- Cómo se instala (una sola vez): en el Explorer, clic derecho sobre este Script >
-- "Save as Local Plugin...". Studio lo guarda en tu carpeta de plugins y lo activa.
--
-- Cómo se usa: en la barra de comandos de Studio:
--     workspace:SetAttribute("SubirTexturas", os.clock())
-- El plugin sube cada textura de ServerStorage/Herramientas/Texturas como imagen de tu cuenta
-- y escribe en la salida (Output) una línea "TEXTURAS_JSON:" con los números (ids) de cada imagen.
-- Esos ids se copian en ReplicatedStorage/Config/TexturasConfig.
--
-- Por qué hace falta un plugin: Roblox solo deja subir imágenes desde código en un plugin
-- local (AssetService:CreateAssetAsync), no desde la barra de comandos.

if not plugin then
	return -- es un Script normal dentro del juego: no hace nada
end

local AssetService = game:GetService("AssetService")
local EncodingService = game:GetService("EncodingService") -- Base64Decode
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	return -- solo en modo edición (no al darle a Play)
end

local subiendo = false

-- Formato "rle": u16 número de colores, los colores (RGBA), y luego pares
-- (índice del color, cuántos píxeles seguidos) recorriendo la imagen fila a fila.
local function decodificar(datos)
	local bytes = EncodingService:Base64Decode(buffer.fromstring(datos.datos))
	local salida = buffer.create(datos.ancho * datos.alto * 4)
	local colores = buffer.readu16(bytes, 0)
	local paleta = table.create(colores)
	for i = 0, colores - 1 do
		paleta[i] = buffer.readu32(bytes, 2 + i * 4)
	end
	local pos = 0
	local fin = buffer.len(salida)
	local i = 2 + colores * 4
	local largo = buffer.len(bytes)
	while i < largo and pos < fin do
		local color = paleta[buffer.readu8(bytes, i)]
		for _ = 1, buffer.readu8(bytes, i + 1) do
			buffer.writeu32(salida, pos, color)
			pos += 4
		end
		i += 2
	end
	return salida
end

local function subirUna(modulo)
	local datos = require(modulo:Clone())
	local pixeles = decodificar(datos)
	local tam = Vector2.new(datos.ancho, datos.alto)
	local imagen = AssetService:CreateEditableImage({ Size = tam })
	imagen:WritePixelsBuffer(Vector2.zero, tam, pixeles)
	local ok, resultado, id = pcall(function()
		return AssetService:CreateAssetAsync(imagen, Enum.AssetType.Image, {
			Name = "EclipseEterno_" .. datos.nombre,
			Description = "Textura de El Eclipse Eterno",
		})
	end)
	imagen:Destroy()
	if ok and resultado == Enum.CreateAssetResult.Success then
		return id
	end
	warn("[SUBIDOR] No se pudo subir", datos.nombre, ok, resultado, id)
	return nil
end

local function subirTodas()
	if subiendo then
		return
	end
	subiendo = true
	local carpeta = game:GetService("ServerStorage"):FindFirstChild("Herramientas")
	carpeta = carpeta and carpeta:FindFirstChild("Texturas")
	if not carpeta then
		warn("[SUBIDOR] No encuentro ServerStorage/Herramientas/Texturas")
		subiendo = false
		return
	end
	-- solo las que pida el atributo "SoloTexturas" (lista separada por comas), o todas
	local solo = workspace:GetAttribute("SoloTexturas")
	local filtro = nil
	if type(solo) == "string" and solo ~= "" then
		filtro = {}
		for nombre in string.gmatch(solo, "[^,]+") do
			filtro[nombre] = true
		end
	end
	local ids = {}
	local modulos = carpeta:GetChildren()
	table.sort(modulos, function(a, b)
		return a.Name < b.Name
	end)
	print(string.format("[SUBIDOR] Subiendo %d texturas...", #modulos))
	for _, modulo in modulos do
		if modulo:IsA("ModuleScript") and (not filtro or filtro[modulo.Name]) then
			local ok, id = pcall(subirUna, modulo)
			if ok and id then
				ids[modulo.Name] = id
				print("[SUBIDOR] ok", modulo.Name, id)
			else
				warn("[SUBIDOR] fallo", modulo.Name, id)
			end
			task.wait(0.4)
		end
	end
	-- se guardan también en el lugar (atributo de Workspace "TexturasIds"), sumados a los anteriores
	local anteriores = {}
	pcall(function()
		anteriores = HttpService:JSONDecode(workspace:GetAttribute("TexturasIds") or "{}")
	end)
	for nombre, id in ids do
		anteriores[nombre] = id
	end
	workspace:SetAttribute("TexturasIds", HttpService:JSONEncode(anteriores))
	print("TEXTURAS_JSON:" .. HttpService:JSONEncode(ids))
	subiendo = false
end

workspace:GetAttributeChangedSignal("SubirTexturas"):Connect(function()
	task.spawn(subirTodas)
end)
print("[SUBIDOR] Plugin de texturas listo")

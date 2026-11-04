-- NPC de los pueblos (servidor): les da vida con una animación de estar de pie.
-- Ruta en Studio: ServerScriptService/Mundo/NPCServicio
--
-- Los NPC los crea el generador del mundo (ServerStorage/Herramientas/Mundo/NPCs)
-- con la etiqueta "NPC". El diálogo y la tienda se muestran en el cliente
-- (StarterPlayerScripts/PueblosCliente). Más adelante, aquí irá la compra con oro
-- (siempre en el servidor: el cliente nunca decide si algo se compra).

local CollectionService = game:GetService("CollectionService")

local NPCServicio = {}

-- Animación de estar de pie de Roblox (respira y se mueve un poco)
local ANIMACION_QUIETO = "rbxassetid://507766388"
local rng = Random.new()

local function animar(npc)
	local humanoide = npc:FindFirstChildOfClass("Humanoid")
	if not humanoide then
		return
	end
	local animador = humanoide:FindFirstChildOfClass("Animator")
	if not animador then
		animador = Instance.new("Animator")
		animador.Parent = humanoide
	end
	local animacion = Instance.new("Animation")
	animacion.AnimationId = ANIMACION_QUIETO
	local ok, pista = pcall(function()
		return animador:LoadAnimation(animacion)
	end)
	if ok and pista then
		pista.Looped = true
		-- cada NPC a su ritmo, para que no se muevan todos a la vez
		pista:Play(0.3, 1, rng:NextNumber(0.85, 1.1))
		task.defer(function()
			if pista.Length > 0 then
				pista.TimePosition = rng:NextNumber(0, pista.Length)
			end
		end)
	end
end

function NPCServicio.Iniciar()
	for _, npc in CollectionService:GetTagged("NPC") do
		task.spawn(animar, npc)
	end
	CollectionService:GetInstanceAddedSignal("NPC"):Connect(animar)
	print("[SERVIDOR] NPC listos:", #CollectionService:GetTagged("NPC"))
end

return NPCServicio

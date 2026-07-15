--!strict
--[[
	TrackQuality (cliente)
	-----------------------
	Reduz o custo visual (luzes e partículas) dos elementos da pista
	(TrackElements: placas de boost, rolo móvel, ventilador lateral) em
	mobile/console, plataformas com GPU mais limitada. PC/Mac com
	teclado+mouse mantém a qualidade cheia — não mexe em nada lá.

	Detecção:
	  - Mobile = tela de toque SEM teclado/mouse (celular/tablet real;
	    notebook touch-screen tem teclado, então fica de fora).
	  - Console = interface "dez pés" (GuiService:IsTenFootInterface()).

	Cada instância de servidor roda UMA corrida só (modelo sessão única —
	ver RaceManager), então o TrackElements só é criado uma vez; este
	módulo só precisa aplicar a redução uma vez também.

	Não mexe em geometria (pads, muros) nem em lógica de jogo — só em
	PointLight.Range/Brightness e ParticleEmitter.Rate, puramente visual.
]]

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local TrackQuality = {}

local FOLDER_NAME = "TrackElements"

-- Fatores de redução aplicados em mobile/console.
local LIGHT_RANGE_SCALE = 0.5
local LIGHT_BRIGHTNESS_SCALE = 0.6
local PARTICLE_RATE_SCALE = 0.4

local function isReducedQualityPlatform(): boolean
	local isTenFoot = false
	pcall(function()
		isTenFoot = GuiService:IsTenFootInterface()
	end)
	local isMobile = UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
		and not UserInputService.MouseEnabled
	return isMobile or isTenFoot
end

local function reduceInstance(inst: Instance)
	if inst:IsA("PointLight") or inst:IsA("SpotLight") then
		inst.Range *= LIGHT_RANGE_SCALE
		inst.Brightness *= LIGHT_BRIGHTNESS_SCALE
	elseif inst:IsA("ParticleEmitter") then
		inst.Rate *= PARTICLE_RATE_SCALE
	end
end

local function reduceFolder(folder: Instance)
	for _, descendant in folder:GetDescendants() do
		reduceInstance(descendant)
	end
	-- Defensivo: cobre qualquer luz/partícula que chegue via replicação um pouco depois.
	folder.DescendantAdded:Connect(reduceInstance)
end

-- Chama uma vez no início do cliente.
function TrackQuality.Start()
	if not isReducedQualityPlatform() then
		return -- PC/console "de mesa" com teclado+mouse: mantém qualidade cheia
	end
	local existing = workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		reduceFolder(existing)
		return
	end
	local connection
	connection = workspace.ChildAdded:Connect(function(child)
		if child.Name == FOLDER_NAME then
			connection:Disconnect()
			reduceFolder(child)
		end
	end)
end

return TrackQuality

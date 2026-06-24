--!strict
--[[
	PrizeService
	------------
	Entrega prêmios aos jogadores. Por enquanto, usa leaderstats "Coins"
	(placeholder visível na lista de jogadores).

	>>> PONTO DE INTEGRAÇÃO com o JOGO PRINCIPAL <<<
	Quando ligar os dois places, troque/expanda o Award() pra creditar no
	sistema real (DataStore compartilhado, atributo no teleporte de volta, etc.).
]]

local Players = game:GetService("Players")

local PrizeService = {}

local function ensureCoins(player: Player): IntValue
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	local coins = leaderstats:FindFirstChild("Coins")
	if not coins then
		coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Parent = leaderstats
	end
	return coins :: IntValue
end

function PrizeService.Setup()
	Players.PlayerAdded:Connect(ensureCoins)
	for _, player in Players:GetPlayers() do
		ensureCoins(player)
	end
end

function PrizeService.Award(player: Player, coins: number)
	if coins <= 0 then
		return
	end
	local stat = ensureCoins(player)
	stat.Value += coins
end

return PrizeService

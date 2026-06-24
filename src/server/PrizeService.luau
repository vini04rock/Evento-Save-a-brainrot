--[[
	PrizeService (lado da CORRIDA)
	------------------------------
	Grava o prêmio do jogador num DataStore COMPARTILHADO (mesmo experience do lobby),
	como "prêmio pendente". O LOBBY entrega quando o player volta (RaceRewardGrantService).

	Por que não entregar aqui: os dados do player (Braincoins, pacotes) vivem no sistema
	de progresso do LOBBY. Entregar a partir daqui (servidor da corrida) arriscaria conflito
	de save. O padrão seguro é: corrida GRAVA pendente → lobby LÊ + concede + limpa.

	DataStore: "PendingRaceRewards_v1", chave = "u_<userId>".
	Valor: { Packs = { "BrainrotPack2", ... }, Braincoins = N }  (acumula).
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RaceConfig = require(ReplicatedStorage.Shared.RaceConfig)

local PrizeService = {}

local STORE_NAME = "PendingRaceRewards_v1"
local store: DataStore? = nil

function PrizeService.Setup()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Evento] DataStore indisponível (prêmios não serão gravados):", result)
		store = nil
	end
end

-- Resolve o prêmio de uma colocação. place > #PrizeByPlace = consolação (só Braincoins).
function PrizeService.ResolveReward(place: number): { Pack: string?, Braincoins: number }
	local podium = RaceConfig.PrizeByPlace[place]
	if podium then
		return { Pack = podium.Pack, Braincoins = tonumber(podium.Braincoins) or 0 }
	end
	return { Pack = nil, Braincoins = tonumber(RaceConfig.FinishConsolationBraincoins) or 0 }
end

-- Grava o prêmio da colocação como pendente (acumula com o que já houver).
function PrizeService.AwardPlace(player: Player, place: number)
	if not store then
		return
	end
	local reward = PrizeService.ResolveReward(place)
	if (not reward.Pack) and reward.Braincoins <= 0 then
		return
	end

	local key = "u_" .. tostring(player.UserId)
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key, function(old)
			local data = (typeof(old) == "table") and old or { Packs = {}, Braincoins = 0 }
			data.Packs = (typeof(data.Packs) == "table") and data.Packs or {}
			data.Braincoins = tonumber(data.Braincoins) or 0
			if reward.Pack then
				table.insert(data.Packs, reward.Pack)
			end
			data.Braincoins += reward.Braincoins
			return data
		end)
	end)
	if not ok then
		warn("[Evento] Falha ao gravar prêmio pendente de " .. tostring(player.Name) .. ":", err)
	end
end

return PrizeService
